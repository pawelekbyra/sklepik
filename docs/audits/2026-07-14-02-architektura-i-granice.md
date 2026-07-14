# Audyt 02 — architektura i granice systemu

**Data:** 2026-07-14
**Zakres:** repozytoria `sklepik` i `sklepikFront`; Rails/Spree, Store API, Admin API, dashboard, storefront, PostgreSQL, Redis/Sidekiq, Cloudflare R2, Oracle VPS, Vercel i provisioning GitHub→Vercel.
**Charakter audytu:** statyczny — kod i dokumentacja w lokalnych checkoutach. Bez dostępu do Oracle, Vercel, GitHub, R2, DNS, logów, metryk i sekretów produkcyjnych; deklaracje o stanie runtime oznaczono jako nieweryfikowane.

## Podsumowanie wykonawcze

Architektura ma czytelny podział na wspólny control/data plane (`sklepik`) oraz osobne storefronty (`sklepikFront`) i dobrze zdefiniowaną zasadę, że commerce pozostaje w Store API. Najmocniejszą granicą jest rozwiązanie tenantu z publishable key przed autoryzacją, jawny wybór sklepu w Admin API oraz tenant-aware `Vary`/ETag. Draft/published layout również ma właściwy kierunek: publiczny storefront konsumuje tylko opublikowany snapshot.

Największe ryzyko nie wynika z podziału aplikacji, lecz z topologii produkcyjnej: Rails, Sidekiq, PostgreSQL i Redis współdzielą jedną małą VM oraz jeden Compose host. Awaria hosta, dysku, sieci lub błędny deploy jednocześnie zatrzymuje API, checkout, panel, joby i bazę. Backup jest deklarowany, lecz restore nie został wykonany. Drugim krytycznym obszarem jest Store Factory: kod tworzy zasoby GitHub i Vercel sekwencyjnie, bez idempotentnego wznowienia i kompensacji; częściowa awaria pozostawia orphan resources, a świeża próba może kolidować z poprzednimi zasobami. Nie rekomenduję otwierania publicznego signup przed domknięciem tych granic.

**Wynik:** 0 × P0, 5 × P1, 7 × P2, 4 × P3. P0 nie stwierdzono statycznie; brak P0 nie jest potwierdzeniem bezpieczeństwa runtime ani tenant isolation end-to-end.

## Metoda i poziom dowodu

- **Fakt** — bezpośrednio wynika z kodu lub wersjonowanej konfiguracji.
- **Deklaracja** — stan opisany w docs, bez weryfikacji środowiska produkcyjnego.
- **Inferencja** — skutek architektoniczny wyprowadzony z faktów.
- **Nieweryfikowane runtime** — wymaga dostępu do środowiska, logów lub kontrolowanego testu awarii.

Przejrzano kanon i instrukcje obu repo, konfigurację Docker/Nginx/Vercel, kontrolery rozwiązywania store, cache HTTP, modele i serwisy provisioningu, konfigurację SDK storefrontu, ścieżki webhooków oraz dokumentację Oracle/Store Factory. Nie wykonywano zmian kodu ani testów destrukcyjnych.

## Mapa komponentów i ownership

| Komponent | Odpowiedzialność / dane | Granica wejściowa | Trwałość / failure domain |
|---|---|---|---|
| Storefront Next.js (Vercel, repo `sklepikFront`) | rendering, UX, SEO, checkout UI, cookie token koszyka, publikowany layout | Store API + publishable key; webhook HMAC | deployment per sklep; zależny od Vercel i Oracle API |
| Dashboard React (Vercel, `packages/dashboard`) | back-office i edytor | same-origin rewrite `/api/*` → Oracle; JWT + refresh cookie | Vercel; bez backendu panel jest nieoperacyjny |
| Rails API / Puma (Oracle) | kanoniczna logika i dane commerce, auth, tenant context, control plane | HTTPS przez Nginx | pojedynczy kontener/host |
| Sidekiq (Oracle) | webhooki, provisioning i async jobs | Redis + PostgreSQL + zewnętrzne API | ten sam host co API i dane |
| PostgreSQL (Oracle volume) | źródło prawdy commerce, tenantów, provisioning runs | prywatna sieć Compose | pojedynczy volume/host; backup deklarowany do R2 |
| Redis (Oracle volume) | kolejki i cache/idempotency API | prywatna sieć Compose | pojedynczy volume/host; utrata wpływa na joby/cache |
| Cloudflare R2 | Active Storage media; deklaratywnie także kopie dumpów | S3 API, sekrety w env | zewnętrzny provider; brak testu restore |
| GitHub | źródła i repo per sklep | długowieczny token w obecnym kodzie | zewnętrzny provider/control-plane dependency |
| Vercel | dashboard, storefronty, env i deploy per sklep | REST API + GitHub integration | zewnętrzny provider; projekt per sklep |

**Zamierzony przepływ kupującego:** browser → Vercel storefront → Store API/Nginx/Rails → PostgreSQL; koszyk gościa identyfikowany tokenem, tenant publishable key. Media: browser/Next Image → URL Active Storage/R2.
**Zamierzony przepływ operatora:** browser → Vercel dashboard → same-origin rewrite → Admin API → PostgreSQL/R2.
**Publikacja layoutu:** dashboard → Admin API draft/publish → PostgreSQL snapshot → Store API → renderer storefrontu.
**Provisioning:** signup/Admin API → transakcja DB → Sidekiq → GitHub template → Vercel project → env → deployment polling → zmiana `Store#url`.
**Webhook/e-mail/cache:** Rails event → Sidekiq/webhook → endpoint Vercel storefrontu → Resend i/lub rewalidacja cache.

## Granice trust i tenant

1. **Internet → Nginx/Rails:** TLS kończy Nginx. Wersjonowany config wystawia 80/443, ustawia forwarding headers i limit body 100 MB (`nginx.conf:42-102`). Firewall hosta pozostaje poza repo.
2. **Storefront → Store API:** publishable key jest publicznym identyfikatorem i selektorem tenantu, nie sekretem. `StoreResolution` globalnie wyszukuje aktywny klucz, ustawia `@current_store`/`Spree::Current.store` i odrzuca jawny konflikt header/host (`spree/api/app/controllers/concerns/spree/api/v3/store_resolution.rb:7-66`).
3. **Dashboard → Admin API:** dashboard wybiera sklep nagłówkiem `X-Spree-Store-Id`; kontroler rozwiązuje go przed auth, a authorization ma dalej potwierdzić członkostwo (`.../admin/base_controller.rb:9-33`). Sam nagłówek nie jest dowodem uprawnienia.
4. **Shared cache:** publiczne odpowiedzi różnicują m.in. API key, store, market, channel, currency i locale; tenant records są w ETag (`http_caching.rb:14-21, 101-139`). To właściwa obrona na granicy CDN, ale nie zastępuje scope'owania zapytań.
5. **Rails → GitHub/Vercel/R2:** są to granice wysokiego zaufania oparte na sekretach procesu. Kompromitacja web/worker daje możliwość tworzenia repo/projektów i dostępu do storage w zakresie przyznanych tokenów.
6. **Rails → storefront webhook:** HMAC i kontrola timestampu są implementowane w `sklepikFront/src/lib/spree/webhooks.ts`; poprawność wymaga identycznego sekretu per endpoint i poprawnej konfiguracji subskrypcji.

## Findings

### ARCH-001 — P1 — wspólny pojedynczy failure domain dla API, jobów i danych

**Fakt:** `docker-compose.yml:1-105` uruchamia PostgreSQL, Redis, web, Sidekiq i Nginx na jednym hoście i lokalnych named volumes. Dokumentacja deklaruje jedną VM `VM.Standard.E4.Flex`, 1 OCPU/8 GB (`docs/deployment-oracle.md:92-123`).
**Inferencja:** awaria VM, boot volume, Docker daemon, host network, wyczerpanie dysku lub błędny deploy zatrzyma jednocześnie sprzedaż, panel, checkout, joby i dostęp do źródła prawdy. Nie ma failoveru ani oddzielnego blast radius dla data plane.
**Nieweryfikowane runtime:** SLA Oracle, wykorzystanie dysku/RAM/CPU, automatyczny restart VM, alarmy i czas ręcznego odtworzenia.
**Naprawa:** najpierw udokumentować i przećwiczyć rebuild hosta; następnie oddzielić co najmniej bazę/backup od compute albo zapewnić warm replacement, monitoring zasobów i automatyzowany bootstrap.
**Kryterium zamknięcia:** kontrolowany loss-of-host drill odtwarza usługę oraz dane w zatwierdzonym RTO/RPO.

### ARCH-002 — P1 — backup bez zweryfikowanego restore

**Deklaracja:** dump Postgresa jest wykonywany lokalnie i wysyłany do R2, ale restore „jeszcze nie przetestowany” (`docs/deployment-oracle.md:198-200`).
**Inferencja:** istnienie pliku nie dowodzi kompletności, odszyfrowalności, wersji narzędzi, poprawności uploadu ani możliwości odtworzenia tenantów, zamówień i Active Storage. R2 jest równocześnie storage media i miejscem kopii, więc błędne uprawnienia/retencja mogą objąć oba zbiory.
**Naprawa:** cykliczny restore do izolowanego Postgresa, kontrola liczby/constraintów i próbka plików Active Storage; niezależna retencja/immutability i alarm świeżości.
**Kryterium zamknięcia:** udokumentowany restore drill z pomierzonym RPO/RTO i dowodem spójności DB↔R2.

### ARCH-003 — P1 — provisioning nie jest wznawialny, idempotentny ani kompensacyjny

**Fakt:** `ProvisionStore` wykonuje synchronicznie w jobie repo→projekt→env→poll i sam opisuje brak persisted resumption (`provision_store.rb:5-18`). Przy błędzie nowy run zaczyna od początku; job celowo nie retry'uje provider errors (`provision_store_job.rb:6-19`). Nie ma wywołania `delete_project` ani usunięcia repo w ścieżce failure. Nazwa repo/projektu pochodzi ze stałego `store.code` (`provision_store.rb:43-49, 79-83`).
**Inferencja:** awaria po utworzeniu repo lub projektu zostawia zasoby częściowe; kolejna próba może dostać konflikt nazw i nie przejść. Operator nie ma bezpiecznego resume/rollback, a stan DB nie jest źródłem prawdy o wszystkich zasobach providera.
**Naprawa:** idempotency key per store/application i persisted state per step; lookup/adopt istniejących zasobów; jawne kompensacje; retry tylko kroku; reconcile job porównujący DB z providerami.
**Kryterium zamknięcia:** fault injection po każdym kroku, ponowienie kończy jednym repo/projektem/deploymentem albo kontrolowanym rollbackiem.

### ARCH-004 — P1 — publiczny signup może zwrócić sukces mimo niezdolnego provisioningu

**Fakt:** signup commituję user/store/run i zwraca 201 po enqueue (`signups_controller.rb:22-46`), zanim zweryfikuje credentiale/providerów. `Settings::MissingCredential` nie znajduje się na liście rescue w `ProvisionStore#call` (`provision_store.rb:36-39`), więc run może pozostać w stanie pośrednim zamiast `failed`. `wait_for_repository` po 10 nieudanych próbach nie rzuca błędu (`provision_store.rb:55-63`).
**Inferencja:** użytkownik może dostać aktywną sesję i draft store, którego aplikacja nigdy nie powstanie, z mylącym statusem. Włączenie flagi bez kompletnej konfiguracji nie failuje przed utworzeniem danych.
**Naprawa:** readiness preflight przed otwarciem flagi, rescue wszystkich domenowych błędów, timeout repo jako błąd, stan `action_required/failed`, retry/reconcile i UX recovery.
**Kryterium zamknięcia:** testy brakującego secreta, timeoutu GitHub i każdej odpowiedzi 4xx/5xx kończą jednoznacznym statusem oraz możliwym retry bez orphanów.

### ARCH-005 — P1 — build produkcyjnego backendu zależy od nieprzypiętego upstream `spree-starter`

**Fakt:** `Dockerfile:19-21` klonuje `https://github.com/spree/spree-starter.git` z `--depth 1`, bez commita/tagu. Każdy rebuild pobiera aktualny HEAD z sieci. Host-app nie jest wersjonowana w tym repo.
**Inferencja:** ten sam commit Sklepika może zbudować inny obraz, upstream może złamać kompatybilność lub być niedostępny; audyt kodu repo nie obejmuje faktycznie uruchamianego host-app. To także granica supply-chain bez locka źródła.
**Naprawa:** przypiąć SHA i weryfikować je albo wersjonować minimalną host-app; przechowywać digest obrazu/SBOM i testować reprodukowalny rebuild.
**Kryterium zamknięcia:** identyczny commit i locki tworzą deterministyczny, audytowalny obraz bez zależności od ruchomego HEAD.

### ARCH-006 — P2 — deploy i migracje nie są atomowe ani audytowalne razem

**Fakt/deklaracja:** migracje są kopiowane/wykonywane w jednorazowym kontenerze, a starter nie zachowuje plików; późniejszy boot może raportować missing migrations (`deployment-oracle.md:156-166`). Deploy wymaga ręcznego restartu Nginx z powodu cache IP kontenera (`:161-164`).
**Inferencja:** rollback obrazu nie musi oznaczać rollbacku schematu; ręczna sekwencja może zostawić mieszane wersje lub 502.
**Naprawa:** migration artifacts w obrazie, release command z blokadą, backward-compatible migrations, automatyczny health-gated rollout i rollback runbook.

### ARCH-007 — P2 — reguły firewalla znikają po restarcie hosta

**Deklaracja:** `iptables` dla 80/443 nie są trwałe (`deployment-oracle.md:138, 203`).
**Inferencja:** restart VM może odciąć HTTPS/certbot, choć kontenery są healthy. To operacyjny SPOF poza kodem aplikacji.
**Naprawa:** trwała polityka firewall jako kod + reboot test; ograniczyć SSH i monitorować endpoint z zewnątrz.

### ARCH-008 — P2 — adres backendu jest hardcodowany w kilku artefaktach

**Fakt:** dashboard rewrite wpisuje `https://141-253-103-172.nip.io` w `packages/dashboard/vercel.json:3-8`; provisioning ma ten sam default (`settings.rb:41-44`); docs i env storefrontu powtarzają host.
**Inferencja:** migracja domeny/backendu wymaga code deploy panelu oraz poprawnej konfiguracji kilku miejsc; drift prowadzi do częściowego cutoveru.
**Naprawa:** stabilna domena API; generowana/env-controlled konfiguracja rewrite z jednym właścicielem; automatyczny contract/smoke test wszystkich konsumentów.

### ARCH-009 — P2 — webhook storefrontu łączy cache i krytyczne e-maile z dostępnością deploymentu sklepu

**Fakt:** ten sam endpoint storefrontu obsługuje e-maile transakcyjne i inwalidację cache; wymaga ręcznej subskrypcji i wspólnego sekretu (`sklepikFront/docs/deployment-vercel.md:28-31, 47-53`). Backendowy moduł e-mail jest docelowo nieużywany.
**Inferencja:** usunięcie/błędna konfiguracja deploymentu, sekretu lub domeny sklepu powoduje jednocześnie stale cache i brak e-maili. Per-store app staje się elementem krytycznej ścieżki operacyjnej zamówienia, choć rendering powinien być od niej słabiej sprzężony.
**Naprawa:** rozdzielić typy konsumentów i ownership; centralna, durable usługa e-mail/outbox albo co najmniej osobne endpointy, health/status i automatyczny provisioning/rotation webhooku.

### ARCH-010 — P2 — trwała idempotencja webhooków frontu jest opcjonalna i fail-open

**Fakt:** bez Upstash/KV kod przechodzi na pamięć procesu; cold start/deploy zeruje stan (`docs/deployment-vercel.md:31`, `docs/technical-debt.md:65-73`).
**Inferencja:** retry webhooku może wysłać klientowi duplikat e-maila; skala deploymentów per sklep mnoży konfigurację i punkty driftu.
**Naprawa:** wymagany durable store przy production readiness albo centralny inbox/outbox z unique event id; brak konfiguracji powinien blokować launch, nie tylko ostrzegać.

### ARCH-011 — P2 — storefront maskuje brak kanonicznej konfiguracji jako pusty katalog

**Fakt/deklaracja:** `getEnvConfig` zwraca `null` bez URL/key (`src/lib/spree/config.ts:7-18`); dokumentacja stanu mówi, że wyższe warstwy po cichu zwracają puste odpowiedzi i katalog wygląda jak pusty.
**Inferencja:** błąd control plane/configuration plane prezentuje się jak poprawny stan biznesowy, utrudnia monitoring i może opublikować niedziałający sklep.
**Naprawa:** build/deploy/launch preflight; jawny 503/operator diagnostic przy braku wymaganej konfiguracji; synthetic catalog check.

### ARCH-012 — P2 — legacy i aktywny model deploymentu współistnieją w repo

**Fakt:** repo nadal zawiera `render.yaml`, skrypty Render i `deployment-render.md`, podczas gdy kanon deklaruje Oracle; CLAUDE nadal opisuje produkcyjny flow Render w części instrukcji.
**Inferencja:** agent/operator może zmodyfikować lub uruchomić niewłaściwą ścieżkę, a wymagania idempotentnych migracji są objaśniane przez dwa modele.
**Naprawa:** wyraźny ownership/status artefaktów legacy, usunąć je z aktywnych entrypoints CI/deploy albo przenieść do oznaczonego archiwum; ujednolicić instrukcje.

### ARCH-013 — P3 — rozwiązywanie hosta skanuje wszystkie sklepy w pamięci

**Fakt:** konflikt hosta jest sprawdzany przez `Spree::Store.all.detect` dla każdego requestu z publishable key (`store_resolution.rb:41-46`).
**Inferencja:** koszt rośnie liniowo z liczbą tenantów i ładuje rekordy; przy większej skali stanie się hotspotem, choć dziś prawdopodobnie nie jest incydentem.
**Naprawa:** znormalizowana, indeksowana domena / tabela domain bindings i pojedynczy lookup DB/cache.

### ARCH-014 — P3 — modułowy singleton SDK utrwala „jeden deployment = jeden sklep”

**Fakt:** `_client`/`_config` są module-level i inicjalizowane z env (`sklepikFront/src/lib/spree/config.ts:4-18, 45-67`).
**Ocena:** zgodne z aktualną decyzją repo/project per sklep, ale uniemożliwia bezpieczne użycie jednego runtime dla wielu hostów bez przebudowy.
**Naprawa:** zachować jako jawny invariant independent storefront; jeśli wróci managed multi-host, klient i cache muszą być request/tenant scoped.

### ARCH-015 — P3 — dokumentacja runtime ma wewnętrzny drift

**Fakt:** `docs/stan-projektu.md` nadal w jednej sekcji opisuje self-signed SSL, podczas gdy `deployment-oracle.md:127-139` i Nginx deklarują Let's Encrypt; część opisów Store Factory nazywa etap „gotowym”, jednocześnie wskazując brak realnego E2E.
**Ryzyko:** błędne decyzje diagnostyczne i zbyt wysoka ocena gotowości.
**Naprawa:** generowany manifest środowiska i data ostatniego runtime verification; słowa „wdrożone/gotowe” rozdzielić od „kod istnieje”.

### ARCH-016 — P3 — brak jawnego kontraktu SLO/ownership dla zależności zewnętrznych

**Fakt:** docs opisują GitHub/Vercel/R2/Resend/Upstash, lecz nie znaleziono macierzy właściciel→alarm→fallback→RTO ani limitów/quota.
**Inferencja:** awaria providera może krążyć między zespołem aplikacji a operatorem bez jednoznacznego runbooka i priorytetu.
**Naprawa:** service catalog z właścicielem, sekretem/rotacją, limitem, health checkiem, degradacją i procedurą exit.

## Failure modes i degradacja

| Awaria | Obecny skutek (statyczna inferencja) | Pożądana degradacja |
|---|---|---|
| Oracle VM/volume | brak Store/Admin API, checkoutu, panelu, jobów i DB | storefront informuje o przerwie; dane odtwarzalne; szybki replacement host |
| Redis | Sidekiq i część cache/rate limit/idempotency przestają działać; web zależy od healthy Redis przy starcie | commerce read może działać, mutacje bezpiecznie failować; kolejki odtwarzalne |
| PostgreSQL | cały commerce niedostępny | read-only nie jest realne bez repliki; szybki restore/failover |
| R2 | brak uploadów/obrazów, możliwe problemy wariantów; backup media niedostępny | placeholdery, blokada uploadu, alert; DB commerce nadal działa |
| Vercel storefront | sklep i webhook/e-mail endpoint niedostępne | API i zamówienia zachowują dane; e-maile z durable centralnego outboxa |
| Vercel dashboard | operator nie ma UI, API nadal działa | awaryjny runbook/API dla krytycznych działań |
| GitHub/Vercel API podczas provisioningu | run failed/pośredni, orphan resources | wznowienie od ostatniego kroku/reconcile/compensate |
| brak/mismatch env storefrontu | pusty katalog lub błędy webhooków | deploy/launch blocked, jawny błąd operacyjny |
| restart VM | ryzyko utraty firewall 80/443 | trwały firewall + external health alarm |

## Drift dokumentacja–kod

1. Kanon poprawnie mówi Oracle, lecz instrukcja `CLAUDE.md` nadal eksponuje Renderowy model host-app jako produkcyjną uwagę; aktywne artefakty Render pozostają w root.
2. `stan-projektu.md` wspomina self-signed certificate, a Nginx i `deployment-oracle.md` deklarują Let's Encrypt.
3. Plan Store Factory wymaga GitHub App, a implementacja i komentarze potwierdzają classic PAT (`github_client.rb:14-18`, `settings.rb:17-22`). To świadomy etap, nie spełniona granica docelowa.
4. Plan przewiduje trwały workflow, retry, kompensacje i provider interfaces; kod jawnie realizuje pojedynczą blokującą próbę.
5. Dokumentacja mówi, że Store Factory jest gotowy do wdrożenia za flagą, ale brak zweryfikowanego E2E GitHub→Vercel oraz `set_env`/git linkage są w kodzie oznaczone jako nieweryfikowane (`vercel_client.rb:8-16`).

## Elementy nieweryfikowane runtime

- faktyczna wersja obrazu/commit działający na Oracle i zgodność z checkoutem;
- stan, szyfrowanie, retencja i świeżość backupów; możliwość restore;
- reguły Oracle NSG/security list, host firewall po reboot, SSH hardening;
- alerty, log retention, disk/RAM/CPU headroom, restart policies w praktyce;
- faktyczne R2 bucket policies/CORS/versioning/lifecycle i separacja backupów;
- obecność i zakres GitHub/Vercel tokenów, rotacja, audit log oraz quotas;
- faktyczne ustawienie Upstash/KV, Resend i webhook secret per storefront;
- realny multi-tenant E2E katalog→koszyk→klient→zamówienie;
- zachowanie panelu proxy/cookies przy awarii lub zmianie domeny API;
- pełny provisioning, rollback deploymentu i cleanup po awarii każdego kroku.

## Zalecana kolejność działań

1. **Przed prawdziwą sprzedażą/publicznym signup:** restore drill, host-loss runbook, trwały firewall, provisioning preflight i poprawne fail states.
2. **Przed drugim automatycznym tenantem:** idempotentny/resumable provisioning z reconcile i cleanup; GitHub App; automatyczny webhook + durable idempotency.
3. **Przed skalowaniem ruchu:** przypięty host-app/build, stabilna domena API, monitoring/SLO, indeksowane domain bindings.
4. **Porządek governance:** usunąć drift Render/Oracle/SSL i oznaczać osobno „kod gotowy”, „wdrożone” oraz „zweryfikowane runtime”.

## Kryterium ponownego audytu

Powtórzyć audyt po: (a) realnym provisioning E2E drugiego sklepu z fault injection i rollbackiem, (b) restore drill, (c) host reboot test, (d) wdrożeniu stabilnej domeny API, (e) pierwszym pełnym scenariuszu dwóch tenantów. Wtedy dołączyć dowody z provider audit logs, metryk, backup manifestu i synthetic tests; bez nich ocena pozostaje audytem architektury deklarowanej i statycznej, nie certyfikacją produkcji.
