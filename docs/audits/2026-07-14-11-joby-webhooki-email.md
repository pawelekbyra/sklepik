# Audyt 11: joby, eventy, webhooki i e-maile

Data: 2026-07-14
Zakres: repozytoria `sklepik` i `sklepikFront`
Werdykt: **warstwa asynchroniczna nie jest gotowa do obsługi pieniędzy ani gwarantowanej komunikacji transakcyjnej.** Fundament ma sensowne elementy — osobny worker Sidekiq, nazwane kolejki, podpisy HMAC z ochroną czasową, tenantowe endpointy, trwałe rekordy dostaw i część idempotentnych handlerów — ale kilka ścieżek potwierdza przyjęcie pracy przed zapewnieniem jej trwałości, a część deklarowanych retry nie wykonuje się w praktyce.

## Podsumowanie wykonawcze

Najpoważniejszy problem dotyczy webhooka płatniczego: endpoint może odpowiedzieć `200`, mimo że nie zapisał trwałego inboxu i nawet nie zdołał zakolejkować pracy; późniejszy job może również zakończyć się „sukcesem” po błędzie domenowym. Jest to asynchroniczny wymiar `MONEY-007` i blokuje realne płatności.

Outbound webhooki mają trwały rekord `WebhookDelivery`, lecz timeout, błąd sieciowy i HTTP 5xx nie są ponawiane automatycznie: serwis zapisuje porażkę i nie rzuca wyjątku, więc `retry_on StandardError` w jobie jest faktycznie martwy. Równolegle zdarzenia domenowe są efemeryczne (`ActiveSupport::Notifications` + enqueue do Redis), bez transactional outbox; awaria w krótkim oknie po commicie może bezpowrotnie zgubić e-mail, webhook lub aktualizację metryk.

Kanał e-mail jest kodowo przygotowany na Resend, ale bez `RESEND_API_KEY` produkcja przechodzi do funkcji developerskiej zapisującej HTML do `.next/emails/`. Nie wysyła wiadomości i nie failuje jawnie jako „provider nie skonfigurowany”. Dodatkowo idempotencja konsumenta jest check-then-act, więc równoległe dostawy mogą wysłać duplikat, a flaga `notify_customer` nie jest respektowana.

Bilans: **1 × P0, 6 × P1, 4 × P2, 1 × P3**.

## Metoda i pokrycie

Przejrzano:

- wszystkie klasy jobów w `spree/core/app/jobs` i `spree/api/app/jobs`, bazową politykę retry oraz konfigurację nazw kolejek;
- adapter eventów, registry/subscriber dispatch, lifecycle callbacks i aktywne subskrybery;
- cały outbound webhook pipeline: event → delivery row → Sidekiq → HTTP → auto-disable/redelivery;
- inbound webhook płatności oraz usługę finalizującą płatność;
- Store Factory provisioning i jego trwałe statusy/kroki;
- storefrontowy endpoint webhooków, weryfikację podpisu/replay, handlery cache/e-mail, idempotencję i szablony Resend/react-email;
- runtime Docker Compose, dokumentację Oracle, runbooki i dostępne testy;
- wcześniejsze raporty 01–09, w szczególności `ARCH-003/009/010`, `TENANT-004`, `AUTH-006`, `MONEY-002/003/007`, `ORDER-006/011` i `DB-008`.

Próba uruchomienia dwóch zestawów Vitest storefrontu (`handlers.test.ts`, `idempotency.test.ts`) nie wystartowała, ponieważ w środowisku audytu nie ma polecenia `pnpm` (`exit 127`). Nie wykonywano testów produkcyjnych ani operacji na zewnętrznych providerach.

## Mapa rzeczywistego przepływu

```text
commit modelu
  → after_commit / jawne publish_event
  → ActiveSupport::Notifications (tylko w procesie)
  → SubscriberJob w Redis
  → WebhookEventSubscriber
  → WebhookDelivery w Postgres
  → WebhookDeliveryJob w Redis
  → HTTP do storefrontu
  → podpis + timestamp
  → handler cache lub Resend

PSP
  → endpoint webhooka płatności
  → parse/verify synchronicznie
  → odpowiedź 200
  → opóźniony HandleWebhookJob w Redis
  → mutacja PaymentSession / Payment / Order
```

Nie ma trwałego outboxu między commitem domenowym a Redis ani trwałego inboxu przed `200` dla PSP.

## Findings

### ASYNC-001 — P0 — webhook płatniczy może potwierdzić zdarzenie, którego system nigdy nie przetworzy

**Dowód:** `spree/api/app/controllers/spree/api/v3/webhooks/payments_controller.rb:19-48` po weryfikacji planuje job z opóźnieniem 30 sekund i od razu odpowiada `200`; ogólny `rescue StandardError` także raportuje błąd i odpowiada `200`. Nie powstaje trwały rekord inbox/event przed potwierdzeniem. `spree/core/app/jobs/spree/payments/handle_webhook_job.rb:10-18` nie ma identyfikatora zdarzenia PSP ani deduplikacji. `spree/core/app/services/spree/payments/handle_webhook.rb:41-61` zamienia wyjątek finalizacji w obiekt `failure`, którego job nie sprawdza i nie rzuca ponownie.

**Wpływ:** chwilowa awaria Redis przy enqueue, restart, błąd DB lub wyjątek podczas finalizacji może zostawić PSP z przekonaniem, że webhook przyjęto, podczas gdy zamówienie pozostaje nieukończone. Gateway nie ma powodu ponowić dostawy. Jest to potwierdzenie i rozszerzenie `MONEY-007`; w połączeniu z `MONEY-002/003` jest bezwzględnym blokerem realnych płatności.

**Naprawa:** zapisać zweryfikowane zdarzenie PSP w tenantowym inboxie w transakcji (unikalny `provider + event_id`), odpowiedzieć 2xx dopiero po trwałym zapisie, a job przetwarzać z inboxu i atomowo oznaczać wynik. Nieznane/błędne stany przechodzą do retry albo DLQ, nie do cichego sukcesu.

**Test domykający:** zatrzymać Redis podczas requestu, wymusić wyjątek domenowy po enqueue i wysłać ten sam event wielokrotnie; po przywróceniu zależności dokładnie jedna płatność i jedno ukończenie zamówienia muszą zostać zapisane, a każdy nieprzetworzony inbox ma być widoczny i retryowalny.

### ASYNC-002 — P1 — automatyczny retry outbound webhooków nie działa dla timeoutów, błędów sieci ani HTTP 5xx

**Dowód:** `spree/api/app/jobs/spree/webhook_delivery_job.rb:7-21` deklaruje pięć prób dla `StandardError`. Jednak `spree/api/app/services/spree/webhooks/deliver_webhook.rb:20-47` zapisuje timeout i każdy `StandardError` przez `complete!`, po czym kończy normalnie. Odpowiedź HTTP, również 429/5xx, także tylko trafia do `complete!` (`:23-30`) i nie jest wyjątkiem. W efekcie ActiveJob uznaje wykonanie za udane. Ręczne `redeliver!` istnieje, lecz tworzy nową dostawę i wymaga operatora.

**Wpływ:** pojedynczy chwilowy błąd storefrontu może bezpowrotnie zgubić potwierdzenie zamówienia, reset hasła, powiadomienie wysyłkowe lub inwalidację cache. `AUTO_DISABLE_THRESHOLD = 15` nie zastępuje retry — może jedynie wyłączyć endpoint po piętnastu osobnych zdarzeniach.

**Naprawa:** rozdzielić wynik próby od terminalnego wyniku dostawy; retryować timeouty, 408, 425, 429 i 5xx z jitter/backoff oraz limitem, respektować `Retry-After`, nie retryować większości 4xx. Zapisywać numer próby i next-attempt, a po wyczerpaniu przenieść do jawnej DLQ/failed state.

**Test domykający:** endpoint zwraca kolejno 500, timeout, 429 z `Retry-After`, a potem 204; jedna delivery kończy się sukcesem po czterech zarejestrowanych próbach bez ręcznej akcji. Stałe 400 kończy się bez retry, stałe 500 w DLQ.

### ASYNC-003 — P1 — event bus nie jest trwały i nie ma transactional outbox

**Dowód:** `spree/core/lib/spree/events/adapters/active_support_notifications.rb:25-38` publikuje wyłącznie przez procesowe `ActiveSupport::Notifications`. Lifecycle eventy są wywoływane po commicie (`spree/core/app/models/concerns/spree/publishable.rb:57-78`), a następnie subskryber enqueue'uje `SubscriberJob` do Redis. Nie istnieje tabela outbox ani dispatcher odtwarzający brakujące eventy. `WebhookEventSubscriber` dodatkowo połyka błędy zarówno całego eventu, jak i tworzenia/enqueue dostawy (`spree/api/app/subscribers/spree/webhook_event_subscriber.rb:20-65`).

**Wpływ:** crash procesu po commicie, niedostępność Redis lub błąd serializacji może zostawić poprawny stan domenowy bez odpowiadającego webhooka/e-maila/cache invalidation/metryki. Sam `WebhookDelivery` jest trwały dopiero w późniejszym etapie, więc nie zamyka pierwszego okna utraty. Powiązane: `ARCH-009`, `MONEY-007`.

**Naprawa:** w tej samej transakcji co zmiana domenowa zapisywać wersjonowany outbox z `event_id`, `store_id`, typem agregatu i payloadem; osobny dispatcher publikuje go co najmniej raz i oznacza dopiero po trwałym przyjęciu. Webhook delivery tworzyć idempotentnie z unikalnością DB, a błędów enqueue nie połykać bez stanu do wznowienia.

**Test domykający:** kill procesu w każdym punkcie między commitem a enqueue; po restarcie każdy committed event ma dokładnie jeden rekord outbox i co najmniej jedną próbę delivery, bez zgubienia i bez podwójnego efektu u konsumenta.

### ASYNC-004 — P1 — brak Resend w produkcji nie zatrzymuje kanału, tylko udaje wysyłkę developerską

**Dowód:** `sklepikFront/src/lib/emails/send.ts:14-27` kieruje do `sendEmailDev` zarówno w development, jak i zawsze wtedy, gdy brakuje `RESEND_API_KEY`. Ta funkcja zapisuje HTML do `.next/emails/` i loguje lokalną ścieżkę (`:30-54`), ale niczego nie wysyła. Po jej powodzeniu handler oznacza event jako przetworzony (`handlers.ts:48-74`, analogicznie anulowanie, wysyłka i reset hasła). `EMAIL_FROM` bez konfiguracji ma produkcyjny fallback, o którym kod sam ostrzega, że prawdopodobnie zostanie odrzucony (`send.ts:63-68`).

**Wpływ:** w obecnej konfiguracji bez Resend klient nie dostaje potwierdzeń ani resetu hasła, a system może uznać zdarzenie za obsłużone. Dla serverless zapis do drzewa aplikacji może też skończyć się 500, ale żadna z dwóch gałęzi nie stanowi kontrolowanej degradacji. Powiązane: `AUTH-006`, `ARCH-009`.

**Naprawa:** produkcyjnie fail-closed przy braku provider credentials albo — lepiej — kierować e-mail do trwałej platformowej kolejki/outboxu i oznaczać `blocked_configuration`. Resend i zweryfikowany `EMAIL_FROM` muszą być elementem readiness per sklep; mailer nie powinien żyć we współdzielonym request-cyklu cache webhooka.

**Test domykający:** deployment production bez klucza nie przechodzi readiness i nie oznacza eventu jako wysłany; z sandboxowym Resend zapisuje provider message ID, delivered/failed status i pozwala bezpiecznie ponowić.

### ASYNC-005 — P1 — wszystkie logiczne kolejki są jedną kolejką `default`, współdzieloną z pięciominutowym provisioningiem

**Dowód:** `spree/core/lib/spree/core.rb:96-117` mapuje `events`, `webhooks`, `payment_webhooks`, `imports`, `images`, `search` i pozostałe nazwy na `:default`. Produkcja uruchamia jeden proces `bundle exec sidekiq -c 5` bez wag/priorytetów (`docker-compose.yml:60-89`). Provisioning także używa default (`provision_store_job.rb:3-19`) i blokująco czeka do 20 sekund na GitHub oraz do 300 sekund na Vercel (`provision_store.rb:55-63,106-117`).

**Wpływ:** pięć równoległych signupów lub ciężkie importy/obrazy mogą zająć cały worker i opóźnić webhook płatności, e-mail resetu hasła oraz krytyczne eventy. Poison job i burst jednego tenanta wpływa na wszystkie sklepy (`ARCH-001`).

**Naprawa:** fizycznie rozdzielić co najmniej `critical` (payment inbox), `webhooks/email`, `default` i `bulk/provisioning/media`; nadać osobne concurrency, timeouty i limity per tenant/provider. Provisioning przebudować na krótkie kroki lub durable workflow bez `sleep` zajmującego wątek.

**Test domykający:** przy pięciu zablokowanych provisioningach syntetyczny webhook płatności i reset hasła zaczynają pracę w zdefiniowanym SLO; bulk queue może się nasycić bez wzrostu latency kolejki critical.

### ASYNC-006 — P1 — provisioning nie jest wznawialny, idempotentny ani kompensacyjny

**Dowód:** `ProvisionStore` wykonuje kolejno GitHub → Vercel → env → polling, a trwałe `ProvisioningStep` służą głównie do prezentacji stanu. Komentarz i kod jawnie wymagają nowego runu po błędzie (`provision_store_job.rb:6-15`). Repo i projekt powstają przed końcową transakcją aktywacji (`provision_store.rb:30-38,43-52,65-70,79-93`); częściowy sukces nie ma cleanup ani wznowienia od ostatniego kroku. Błędy providerów są `discard_on`.

**Wpływ:** awaria po utworzeniu repo/projektu pozostawia zasoby-sieroty, a retry może wejść w konflikt nazw lub stworzyć kolejne artefakty. Użytkownik widzi utworzony sklep, choć storefront nie musi powstać (`ARCH-003/004`, `DB-007`).

**Naprawa:** każdy krok jako idempotentna, krótka operacja z trwałym input/output, lease i kluczem idempotencji; wznowienie od pierwszego niedomkniętego kroku; kompensacja albo jawne adoption istniejącego repo/projektu. Oddzielić status utworzenia konta od statusu gotowości storefrontu.

**Test domykający:** fault injection po każdym zewnętrznym callu i przed każdym zapisem; dowolna liczba retry kończy się jednym repo, jednym projektem, kompletem envów i jednym aktywnym runem albo kontrolowanym rollbackiem.

### ASYNC-007 — P1 — flaga `notify_customer` nie steruje rzeczywistą komunikacją

**Dowód:** eventy `order.completed` i `order.canceled` dokładają `notify_customer` do payloadu (`spree/core/app/models/spree/order.rb:1217`, `spree/core/app/services/spree/orders/cancel.rb:47`). Storefrontowe handlery `handleOrderCompleted` i `handleOrderCanceled` nie odczytują tej flagi i wysyłają zawsze, gdy jest adres e-mail (`sklepikFront/src/lib/webhooks/handlers.ts:30-74,80-106`).

**Wpływ:** operator nie może wiarygodnie wyciszyć wiadomości, mimo że API/UI deklaruje taką możliwość. Może to wygenerować niechcianą lub sprzeczną komunikację przy operacjach naprawczych. Potwierdza `ORDER-006`.

**Naprawa:** zdefiniować wersjonowaną politykę komunikacji w evencie i egzekwować ją w jednym routerze; `notify_customer: false` kończy się audytowalnym `suppressed`, nie wysłaniem ani cichym returnem.

**Test domykający:** komplet/cancel z flagą true/false daje odpowiednio jeden send albo jeden rekord suppressed, we wszystkich kanałach i przy redelivery.

### ASYNC-008 — P2 — idempotencja e-maili jest nieatomowa i opcjonalnie procesowa

**Dowód:** konsument wykonuje `isAlreadyProcessed` przed sendem i `markProcessed` po sendzie. W Redis są to osobne `EXISTS` i `SET` (`sklepikFront/src/lib/webhooks/idempotency.ts:38-46`), bez claim/lease/compare-and-set. Dwa równoległe requesty mogą oba przejść check i wysłać. Bez credentials mechanizm używa lokalnego `Set`, resetowanego przez cold start/deploy (`:28-52`); dokumentacja stanu potwierdza, że produkcyjne credentials nie są ustawione.

**Wpływ:** timeout odpowiedzi, ręczne redelivery lub równoległe instancje Vercel mogą wygenerować duplikat. Z kolei crash po wysłaniu przed `markProcessed` także wyśle ponownie.

**Naprawa:** trwały inbox z atomowym unique event claim i stanami processing/sent/failed, lease dla porzuconej pracy oraz zapis provider message ID. Idempotency key przekazywać także do providera, jeśli wspiera.

**Test domykający:** 20 równoległych identycznych dostaw i crash po provider accept prowadzą do jednego provider message ID i terminalnego stanu możliwego do reconciliacji.

### ASYNC-009 — P2 — brak kanonicznego schedulera i automatycznego recovery okresowych zadań

**Dowód:** istnieją joby wymagające okresowego uruchamiania, m.in. `Spree::StockReservations::ExpireJob`, task synchronizacji kursów i cleanup mediów, ale repo nie zawiera aktywnej konfiguracji sidekiq-cron/system cron dla tych zadań. `docker-compose.yml` uruchamia wyłącznie zwykły Sidekiq. `docs/stan-projektu.md` jawnie wskazuje brak crona dla `spree:media:purge_unattached_blobs`.

**Wpływ:** rezerwacje stocku mogą nie wygasać, cleanup i synchronizacje zależą od ręcznej pamięci operatora, a po deployu nie ma wykonywalnej deklaracji harmonogramu. To ryzyko narasta wraz z tenantami.

**Naprawa:** wersjonowany scheduler z leader election/unikalnym lockiem, historią runów, retry i alertem „missed schedule”; każda cykliczna operacja ma ownera, SLO i runbook.

**Test domykający:** restart workerów w oknie harmonogramu nie gubi runu i nie wykonuje go podwójnie; dashboard/metryka pokazuje last success, duration i next run.

### ASYNC-010 — P2 — operacyjność kolejki nie ma wymaganych sygnałów ani automatycznej obsługi DLQ

**Dowód:** Compose ma restart policy, ale nie ma healthchecku workera, dedykowanego endpointu/metryk Sidekiq ani alertów na queue latency, retries, dead set i wiek najstarszego joba. Runbooki polegają na ręcznym `docker compose logs sidekiq`, panelu deliveries i konsoli Rails. Wspólna kolejka uniemożliwia SLO per klasa pracy. Część jobów świadomie failuje po jednej próbie do dead set (np. eksport/raport), lecz nie znaleziono procesu triage/replay z idempotency review.

**Wpływ:** worker może działać procesowo, ale nie przetwarzać krytycznej klasy pracy; awaria jest widoczna dopiero klientowi. Poison joby i rosnący dead set nie mają ownership ani budżetu czasu reakcji.

**Naprawa:** metryki per queue/job/tenant: enqueued, started, succeeded, failed, retry count, queue latency, runtime, oldest age; heartbeat workera i alerty. DLQ z klasyfikacją retryable/non-retryable, bezpiecznym replay i powiązaniem do event/inbox/outbox.

**Test domykający:** zatrzymanie workera, poison job i wzrost latency wywołują alert w zadanym czasie; operator może zidentyfikować tenant/event, naprawić i wznowić bez podwójnego efektu.

### ASYNC-011 — P2 — payloady webhooków i logi utrwalają dane osobowe bez jawnej retencji/redakcji

**Dowód:** webhook delivery zapisuje pełny payload eventu w Postgres oraz do 10 kB odpowiedzi endpointu (`deliver_webhook.rb:26-30`; model `WebhookDelivery` nie ma polityki cleanup). Event logger loguje przefiltrowany kluczowo payload każdego eventu; order payload zawiera e-mail i adresy, których standardowy filter parametrów nie musi usuwać. Storefront loguje adres odbiorcy w dev sink (`send.ts:48-53`). Nie znaleziono TTL/purge dla deliveries ani formalnej klasyfikacji danych.

**Wpływ:** PII klienta i potencjalnie treść odpowiedzi integracji pozostają w bazie/logach dłużej niż potrzeba, są kopiowane do backupów i zwiększają zakres incydentu. Powiązane: `DB-008`, `ORDER-012`.

**Naprawa:** minimalizować payload per event, redagować logi strukturalnie, szyfrować/ograniczać dostęp, zdefiniować TTL deliveries/logów oraz purge uwzględniający obowiązki prawne i spory. Nie logować tokenów resetu; dodać automatyczny test redaction.

**Test domykający:** fixture z e-mailem, adresem, tokenem i danymi gatewaya nie pojawia się w logach; purge usuwa payload po retencji, zachowując minimalny audit metadata.

### ASYNC-012 — P3 — podpis nie wiąże nagłówka routingu z podpisanym eventem

**Dowód:** backend podpisuje `timestamp + '.' + payload_json`, a `X-Spree-Webhook-Event` jest poza HMAC (`deliver_webhook.rb:51-60,79-85`). Konsument wybiera handler jako `eventName || event.name`, czyli preferuje niepodpisany nagłówek (`sklepikFront/src/lib/spree/webhooks.ts:55-87`). Ochrona timestampu i TLS istotnie ograniczają praktyczny atak, ale kontrakt dopuszcza rozbieżność nazwy w body i headerze.

**Wpływ:** przy błędzie proxy/integracji albo możliwości replay ważnego requestu payload może zostać skierowany do niewłaściwego handlera. Dzisiaj najczęściej skończy się 500, lecz przyszłe handlery AI/operacyjne mogą mieć większe skutki.

**Naprawa:** podpisywać wersję, timestamp, event ID, store ID i event name razem z body; konsument ma odrzucać rozbieżność header/body i walidować schemat per wersja.

**Test domykający:** zmiana dowolnego pola routingu unieważnia podpis; zgodnie podpisany, lecz schema-invalid payload dostaje 4xx i nie uruchamia handlera.

## Mocne strony fundamentu

- Lifecycle create/update/delete używa `after_commit`, więc nie publikuje zmian wycofanej transakcji.
- Event ma stabilny UUID, timestamp i `store_id`; webhook endpointy są filtrowane po sklepie.
- `(webhook_endpoint_id, event_id)` ma intencję deduplikacji i obsługę `RecordNotUnique`.
- Outbound HTTP ma SSRF filter poza development, timeouty, TLS verification i HMAC SHA-256.
- Storefront weryfikuje timestamp podpisu (domyślnie pięć minut), co zapewnia podstawową ochronę replay.
- Istnieje UI/API deliveries, test send, ręczne redelivery, auto-disable oraz rotacja sekretu w modelu/API.
- Payment success używa `order.with_lock`, a completed `PaymentSession` jest traktowana idempotentnie.
- Bazowa polityka jobów nie retryuje ślepo każdego wyjątku; część klas świadomie zawęża retry.
- Provisioning utrwala run i kroki, więc jest dobry punkt startu do durable workflow.

## Zalecana kolejność domknięcia

1. **Przed jakąkolwiek realną płatnością:** trwały payment inbox, idempotencja PSP, retry/DLQ i reconciliation (`ASYNC-001`).
2. **Przed pierwszym realnym zamówieniem:** naprawić outbound retry i event outbox (`ASYNC-002/003`).
3. **Przed włączeniem resetów i wiadomości klientom:** platformowa kolejka e-mail, Resend readiness, atomiczny inbox/idempotency i respektowanie `notify_customer` (`ASYNC-004/007/008`).
4. Rozdzielić kolejki critical/webhooks/bulk i usunąć blokujące polling/sleep z provisioningu (`ASYNC-005/006`).
5. Dodać scheduler, obserwowalność, DLQ runbook i retencję danych (`ASYNC-009/010/011`).
6. Wersjonować i domknąć podpis kontraktu eventowego (`ASYNC-012`, `SPREE-008`, `TENANT-004`).

## Minimalna architektura docelowa

```text
transakcja commerce
  ├─ zmiana domenowa
  └─ outbox(event_id, store_id, version, payload)
          ↓ dispatcher at-least-once
      delivery/inbox per kanał
          ├─ payment-critical queue
          ├─ webhook queue
          ├─ email queue
          └─ cache queue
              ↓
      atomic claim → attempt log → terminal state / retry / DLQ

inbound PSP
  verify → durable tenant inbox(unique provider,event_id) → 2xx
       ↓ payment-critical worker + reconciliation
```

„Exactly once” nie powinno być obietnicą transportu. Osiągalnym kontraktem jest: trwały zapis, at-least-once delivery, idempotentny efekt, pełna historia prób i reconciliation.

## Ograniczenia

- Nie zweryfikowano runtime produkcyjnego Sidekiq/Redis, rozmiaru retry/dead set, kolejki latency ani dashboardu Vercel/Resend/Upstash.
- Nie potwierdzono rzeczywistych envów poza stanem zapisanym w dokumentacji; w szczególności brak Upstash i brak wdrożonego Resend przyjęto zgodnie z kanonicznym `stan-projektu.md` oraz bieżącą decyzją właściciela.
- Nie wykonano prawdziwego webhooka PSP, e-maila ani awarii sieciowej.
- `server/` jest efemeryczny/gitignored, więc starter może wnosić runtime configuration niewidoczną w repo; nie może ona jednak zastąpić wersjonowanego kontraktu produkcyjnego.
- Testy frontendowe nie wystartowały z powodu braku `pnpm` w środowisku audytu. Wnioski są statyczne i wskazują konkretne ścieżki kodu.

## Kryterium ponownego audytu

Audyt można zamknąć dopiero po wykonaniu fault-injection matrix dla: DB commit, Redis enqueue, worker crash, provider timeout/429/5xx, duplicate/reordered event, missing configuration, parallel delivery i poison job. Dla każdego zdarzenia pieniężnego lub komunikacyjnego musi istnieć trwały stan od przyjęcia do terminalnego wyniku, tenant ownership, idempotentny efekt, retry/DLQ i mierzalne SLO.
