# Audyt 07: pieniądze i checkout

**Data:** 2026-07-14
**Baseline:** `sklepik` `9a4f693147`, `sklepikFront` `0f83b94`
**Charakter:** statyczny audyt bezpieczeństwa pieniędzy i gotowości produkcyjnej; bez zmian kodu i bez prawdziwych transakcji
**Werdykt:** **nie uruchamiać płatności online ani fulfillmentu opłaconych zamówień**, dopóki MONEY-001–005 nie zostaną zamknięte testami na rzeczywistym adapterze płatności.

## Streszczenie wykonawcze

Fundament commerce jest znacznie mocniejszy niż sama integracja płatnicza. Ceny, podatki, promocje, wysyłka i sumy zamówienia są liczone po stronie backendu. Koszyk jest tenant-scoped, metoda płatności jest pobierana z bieżącego sklepu, checkout ma blokadę rekordu, a sklep `draft` nie może utworzyć płatności ani ukończyć zamówienia. Silnik waliduje maksymalną kwotę zwykłego rekordu płatności i nie kończy zamówienia z samą nieudaną lub brakującą płatnością.

Największe ryzyko leży na granicy przyszłego operatora płatności. Store API pozwala klientowi podać dowolną dodatnią kwotę sesji płatniczej, a `PaymentSession` nie sprawdza jej względem salda koszyka. Adapter może więc utworzyć u operatora obciążenie na kwotę inną niż kanoniczne `amount_due`. Dodatkowo kanoniczny `webhook_url` wskazuje domenę storefrontu, choć kontroler webhooka żyje w backendzie, i rozpoznaje tenant przez `current_store` przed odnalezieniem metody płatności. Dla osobnych domen storefrontów i wspólnego backendu jest to dziś niespójne.

Kod Stripe po stronie storefrontu jest przygotowany, lecz backend nie zawiera produkcyjnego adaptera `spree_stripe`, konfiguracji Stripe/Connect ani potwierdzonej ścieżki webhooków. To oznacza „interfejs gotowy do integracji”, nie „płatności gotowe”.

## Skala i metoda

- **P0** — możliwa utrata pieniędzy / błędne obciążenie / przekazanie towaru bez prawidłowej zapłaty; blokuje płatności produkcyjne.
- **P1** — duże ryzyko finansowe lub operacyjne; musi być zamknięte przed pierwszym prawdziwym zamówieniem.
- **P2** — istotne utwardzenie przed skalowaniem albo szerszym self-service.
- **P3** — jakość i redukcja długu.
- **Fakt** wynika bezpośrednio z kodu lub wykonanego testu. **Inferencja** opisuje prawdopodobny efekt wymagający adaptera/runtime do ostatecznego potwierdzenia. **Nieweryfikowane** oznacza brak dostępu do produkcyjnej konfiguracji operatora albo środowiska testowego.

Prześledzono: produkt/cena → koszyk → adres → shipping rate → podatki/promocje → wybór metody → payment session/direct payment → completion/webhook → capture/void/refund oraz tenant, walutę, rounding i idempotencję. Objęto backend Rails, Store/Admin API v3, SDK, panel i storefront Next.js.

## Znaleziska

### MONEY-001 — P0 — klient kontroluje kwotę sesji u operatora bez ograniczenia do salda

**Status dowodu:** fakt w kontrakcie i modelu; wpływ na operatora jest inferencją do potwierdzenia na docelowym adapterze.

Store API permituje `amount` dla payment session i przekazuje ją bezpośrednio do metody płatności (`spree/api/app/controllers/spree/api/v3/store/carts/payment_sessions_controller.rb:18-24,87-92`). Model wymaga jedynie `amount > 0`; nie wymaga zgodności waluty/kwoty z `order.amount_due` ani nie ogranicza kwoty maksymalnej (`spree/core/app/models/spree/payment_session.rb:21-23,124-130`). Storefront uczciwie nie wysyła `amount` (`sklepikFront/src/lib/data/payment.ts:18-24`), ale publiczne API może wywołać dowolny klient.

**Wpływ:** adapter, który tworzy PaymentIntent/session z przekazanej kwoty, może obciążyć za mało albo — groźniej — za dużo. Nawet jeśli późniejsze ukończenie zamówienia odrzuci niedopłatę, klient może zostać obciążony bez ukończonego zamówienia. To granica pieniędzy i nie może zależeć od poprawności klienta.

**Rekomendacja:** Store API nie powinno przyjmować kwoty sesji od klienta. Kwotę i walutę wyliczać wyłącznie po blokadzie zamówienia z aktualnego `amount_due`; aktualizacja sesji ma ponownie wyliczać sumę. Jeśli częściowe płatności są potrzebne administracyjnie, wystawić je w oddzielnym, uprawnionym kontrakcie Admin API. Adapter ma otrzymać stabilny klucz idempotencji związany z cart/session i walidować odczytaną od operatora kwotę oraz walutę przed oznaczeniem sukcesu.

**Test zamykający:** request spec wysyła `amount: 1`, `amount: total*100` i inną walutę, a fake gateway zawsze otrzymuje dokładnie aktualne `order.amount_due`/`order.currency`. Test wyścigu zmienia koszyk między create/update/complete i dowodzi, że stara sesja nie może zostać zatwierdzona.

### MONEY-002 — P0 — kanoniczny URL webhooka płatności prowadzi do niewłaściwej aplikacji

**Status dowodu:** fakt.

`PaymentMethod#webhook_url` buduje adres z `store.url_or_custom_domain` (`spree/core/app/models/spree/payment_method.rb:103-109`). W modelu Store Factory jest to domena storefrontu. Kontroler odbierający `/api/v3/webhooks/payments/:payment_method_id` istnieje natomiast wyłącznie w Rails (`spree/api/app/controllers/spree/api/v3/webhooks/payments_controller.rb:19-48`); w `sklepikFront` nie ma proxy/trasy dla tego endpointu.

**Wpływ:** operator skonfigurowany wartością zwracaną przez model wyśle zdarzenie do Vercela i otrzyma 404. Płatność może zostać pobrana, ale sesja/zamówienie pozostaną nieukończone, a automatyczne retry nie naprawi złego adresu.

**Rekomendacja:** kanoniczny webhook URL ma używać publicznego originu backendu z konfiguracji platformy, nie domeny sklepu. Nie ujawniać ani nie wymagać od merchanta ręcznego składania URL. Provisioning płatności ma utworzyć endpoint operatora i zapisać jego identyfikator.

**Test zamykający:** test konfiguracji tenanta generuje HTTPS URL backendu, trafia nim do Rails webhook controller i przechodzi podpisany webhook adaptera; test negatywny potwierdza, że domena storefrontu nigdy nie jest zwracana jako endpoint backendowy.

### MONEY-003 — P0 — webhook nie potrafi niezawodnie rozpoznać metody płatności drugiego tenanta

**Status dowodu:** fakt architektoniczny; zachowanie produkcyjnego hosta nieweryfikowane runtime.

Kontroler najpierw wyznacza `current_store` z hosta, potem szuka metody tylko w `current_store.payment_methods` (`spree/api/app/controllers/spree/api/v3/webhooks/payments_controller.rb:5-7,24`). Webhook operatora nie niesie publishable key storefrontu, którym Store API zwykle wyznacza tenant. Na wspólnym hoście API host nie identyfikuje sklepu; dla metody innego niż domyślny tenant wyszukanie kończy się 404.

**Wpływ:** nawet po poprawieniu MONEY-002 płatności dalszych tenantów mogą nie aktualizować sesji i zamówień. To jest krytyczne dla modelu „każdy sklep ma własne płatności”.

**Rekomendacja:** identyfikator endpointu/metody w ścieżce powinien bezpiecznie i globalnie wskazać aktywną metodę, a następnie ustawić `Spree::Current.store` z jej `store_id`; dopiero potem zweryfikować podpis sekretem tego tenanta. Alternatywnie stosować losowy, nierozgadywalny endpoint ID niezależny od publicznego prefixed ID. Nigdy nie wybierać sekretu tylko po niesprawdzonym polu payloadu.

**Test zamykający:** dwa sklepy, dwie metody i wspólny host backendu; poprawnie podpisane webhooki aktualizują wyłącznie własne sesje. Podpis sklepu A dla URL sklepu B daje 401 i nie zmienia żadnych rekordów.

### MONEY-004 — P1 — frontend może pokazać sukces po dowolnym 403/422

**Status dowodu:** fakt.

`completeCheckoutOrder` traktuje każdy HTTP 403 lub 422 jako „zamówienie już ukończone”; jeżeli późniejszy `getOrder` zwróci `null`, nadal zwraca `{ success: true, order: null }` (`sklepikFront/src/lib/data/payment.ts:71-96`). 422 jest normalnym kodem wielu błędów walidacji checkoutu, a komentarz zawęża go do konfliktu `state_lock_version`, choć kod nie sprawdza error code ani stanu zamówienia.

**Wpływ:** klient może zostać przekierowany na stronę „order placed” mimo odrzuconego ukończenia (brak płatności, zmiana ceny/stocku, brak wymagań). To fałszuje potwierdzenie transakcji i utrudnia support/reconciliation.

**Rekomendacja:** sukces tylko po otrzymaniu kompletnego zamówienia ze stanem `complete`. Dla konfliktu rozpoznawać konkretny `error.code`, pobrać zamówienie i zweryfikować `completed_at/current_step`. Inne 403/422 pokazać jako błąd i utrzymać checkout.

**Test zamykający:** osobne testy 422 `cart_cannot_complete`, 422 lock conflict, 403 unauthorized i już ukończonego cartu; tylko ostatni przypadek kończy się sukcesem i zawsze zawiera completed order.

### MONEY-005 — P1 — brak produkcyjnego adaptera i modelu onboardingowego Stripe/Connect

**Status dowodu:** fakt w repo; konfiguracja zewnętrzna nieweryfikowana.

Repo nie zawiera zależności ani klasy `SpreeStripe::Gateway`; wzmianki występują tylko w testowych `stub_const`. Dokumentacja stanu mówi wprost, że Stripe nie jest skonfigurowany. Storefront zawiera Stripe Elements i rozpoznaje typ `stripe` (`sklepikFront/src/components/checkout/StripePaymentForm.tsx:1-147`, `PaymentSection.tsx:183-241`), a panel ma generyczny formularz provider preferences i slot przewidziany na przyszły OAuth Connect (`packages/dashboard/src/components/spree/payment-method-editors/payment-method-form.tsx:69-75`). To nie zapewnia adaptera, webhook signature, refundów ani rozdziału rachunków merchantów.

**Wpływ:** sklep może wyglądać na bliski gotowości, ale nie ma ścieżki przyjęcia prawdziwej płatności. Samodzielny mydlarz musiałby dziś dostać ręcznie skonfigurowaną metodę albo użyć metody offline.

**Rekomendacja:** podjąć decyzję platformową: Stripe Connect Express/Standard (onboarding OAuth/account link, status capabilities, per-tenant account ID, platform fee, liability) albo jawnie oddzielne konto i klucze per sklep. Nie wpisywać sekretnych kluczy w zwykły formularz preferencji, jeśli można użyć Connect. Dodać test/live separation, webhook provisioning, health/capability status i reconciliation.

**Test zamykający:** pełny sandbox E2E dla dwóch tenantów: onboarding, test payment, 3DS redirect, webhook, jedno completed order, capture/void/refund, izolacja rachunków i brak sekretu w odpowiedzi API/logach.

### MONEY-006 — P1 — idempotencja mutacji ma okno wyścigu i zależy od niepotwierdzonego cache

**Status dowodu:** fakt w algorytmie; rodzaj produkcyjnego `Rails.cache` nieweryfikowany.

SDK automatycznie generuje stabilny klucz dla retry pojedynczego wywołania (`packages/sdk-core/src/request.ts:192-227`), a API replayuje zapisany wynik (`spree/api/app/controllers/concerns/spree/api/v3/idempotent.rb:19-61`). Mechanizm wykonuje jednak osobne `read`, całą mutację i dopiero `write`; nie rezerwuje klucza atomowo. Dwa równoległe requesty z tym samym kluczem mogą oba wykonać efekt. Klucz gościa jest dodatkowo scope'owany publishable key (a nie cart token), choć fingerprint ścieżki ogranicza kolizje (`idempotent.rb:69-77`). Nie znaleziono repozytoryjnej gwarancji współdzielonego, trwałego cache produkcyjnego.

Najbardziej wrażliwy przykład to refund: `Refund#after_create :perform!` natychmiast wywołuje operatora (`spree/core/app/models/spree/refund.rb:20-31,76-106`), a odpowiedź idempotency zostaje zapisana dopiero po powrocie kontrolera. `with_order_lock` serializuje zmiany zamówienia, ale nie daje semantyki „ten sam request tylko raz” dla dwóch dopuszczalnych częściowych refundów.

**Wpływ:** retry po timeoutach lub double-click może stworzyć zdublowaną sesję, płatność albo częściowy refund. Restart/procesowy cache może utracić replay.

**Rekomendacja:** trwały rejestr idempotency w bazie/Redis z atomowym `SET NX`/unikalnym indeksem, stanami processing/completed, hashem requestu i odzyskiwaniem po crashu. Money endpoints powinny mieć domenowe, stabilne klucze przekazywane również do operatora.

**Test zamykający:** dwa równoległe requesty z identycznym kluczem do payment session i refund; fake gateway odnotowuje dokładnie jedno wywołanie. Restart procesu przed replay nie zmienia wyniku. Ten sam klucz z innym body daje deterministyczny błąd.

### MONEY-007 — P1 — webhook może zostać bezpowrotnie zgubiony po zaakceptowaniu 200

**Status dowodu:** fakt.

Po weryfikacji podpisu kontroler planuje job z arbitralnym opóźnieniem 30 s i natychmiast odpowiada 200 (`payments_controller.rb:27-40`). Każdy nieoczekiwany błąd kontrolera jest raportowany, ale także dostaje 200 (`:45-47`), więc operator nie ponowi. Job retry'uje wyłącznie deadlock/lock timeout trzy razy, `RecordNotFound` odrzuca, a wyniku failure z serwisu nie sprawdza (`spree/core/app/jobs/spree/payments/handle_webhook_job.rb:3-18`). Serwis łapie każdy wyjątek i zwraca failure, co dla ActiveJob wygląda jak sukces (`handle_webhook.rb:45-53`).

**Wpływ:** chwilowa awaria bazy, błąd adaptera lub błąd completion może zostawić pobraną płatność bez ukończonego zamówienia i bez retry. Klient może zapłacić, a operator platformy nie ma kolejki naprawczej.

**Rekomendacja:** po poprawnej sygnaturze najpierw trwale zapisać unikalne gateway event ID/payload hash, dopiero potem 2xx. Job ma rzucać przy failure retryowalnym, mieć kontrolowaną politykę retry/backoff i dead-letter/alert. Unsupported event może mieć 2xx; wewnętrzny błąd przed trwałym zapisem powinien dawać 5xx.

**Test zamykający:** awaria bazy i błąd completion po pierwszym przyjęciu; zdarzenie jest ponawiane i finalnie daje jedną płatność/jedno zamówienie. Duplikat gateway event ID nie wykonuje efektu ponownie. Wyczerpanie retry tworzy alarm/rekord do ręcznej obsługi.

### MONEY-008 — P1 — refund jest synchronicznym efektem ubocznym bez pełnej operacyjnej ścieżki

**Status dowodu:** fakt.

Admin API buduje refund i `save` uruchamia połączenie z gatewayem w `after_create` (`spree/api/app/controllers/spree/api/v3/admin/orders/refunds_controller.rb:9-28`; `spree/core/app/models/spree/refund.rb:30,76-106`). Kontroler nie przypisuje `refunder`, mimo że model ma to pole. Istnieje order-level create/list, ale brak pełnego panelowego lifecycle return authorization/customer return/reimbursement, co jest też jawnie zapisane w stanie projektu.

**Wpływ:** timeout HTTP może pozostawić niejasność „refund wykonany czy nie”, a operator nie ma pełnego śladu kto zatwierdził zwrot, powodów i spójnego powrotu stocku/VAT/komunikacji. Ręczne ponowienie zwiększa ryzyko duplikatu.

**Rekomendacja:** refund command/outbox z aktorem, powodem, żądanym amount/currency, idempotency key i stanami pending/succeeded/failed; wykonanie asynchroniczne z reconciliation. Zbudować pełny post-sale workflow przed sprzedażą, nawet jeśli pierwsza wersja jest operator-assisted.

**Test zamykający:** timeout operatora po skutecznym refundzie, retry i reconciliation kończą się jednym zwrotem; audit trail zawiera admina, kwotę, walutę, powód, gateway IDs i powiązane return items.

### MONEY-009 — P2 — publiczne Server Actions ignorują przekazany `cartId`

**Status dowodu:** fakt.

Funkcje checkoutu przyjmują `cartId`, lecz dla adresu, rynku, delivery, kodów i sesji płatniczej używają ID z cookie przez `requireCartId()` (`sklepikFront/src/lib/data/checkout.ts:34-83,90-167`; `src/lib/data/payment.ts:10-68`). Parametr bywa tylko opisem intencji. `completeCheckoutOrder` jako wyjątek używa argumentu w wywołaniu API (`payment.ts:79-83`).

**Wpływ:** dwie karty przeglądarki, stary widok po zmianie cookie lub przyszłe wielokoszykowe flow mogą mutować inny koszyk niż pokazany na ekranie. Backend nadal autoryzuje token, więc nie jest to dowód wycieku między klientami, ale może pomieszać adres, shipping lub sesję płatniczą użytkownika.

**Rekomendacja:** albo usunąć argument i jawnie projektować „jedyny cart z cookie”, albo wymagać zgodności `cartId === requireCartId()` i fail-closed. Dla offsite return używać jawnego, podpisanego kontekstu checkoutu.

**Test zamykający:** cookie wskazuje cart B, ekran/akcja cart A; żadna mutacja nie dotyka B, a klient dostaje błąd stale checkout. Test dwóch kart obejmuje payment session i delivery rate.

### MONEY-010 — P2 — checklista launch sprawdza istnienie metody, nie jej zdolność do pobrania pieniędzy

**Status dowodu:** fakt; właściwa polityka biznesowa wymaga decyzji.

`ReadinessCheck` uznaje płatności za gotowe, jeśli istnieje dowolna aktywna i dostępna metoda (`spree/core/app/services/spree/stores/readiness_check.rb:15-28,48-50`), a `launch` bez dodatkowej walidacji ustawia sklep `live` (`spree/api/app/controllers/spree/api/v3/admin/store_controller.rb:25-36`). Nie sprawdza trybu test/live, sekretów, webhook health, waluty, capabilities ani ostatniego testu. Metoda offline może być świadomym wyborem, ale nie dowodzi gotowości płatności online.

**Wpływ:** merchant może uruchomić sklep z niepełną albo testową konfiguracją. Po przejściu na `live` Store API pozwoli tworzyć payment sessions i kończyć zamówienia.

**Rekomendacja:** rozdzielić `payment_method_present` od `payment_ready_for_live_orders`. Provider powinien raportować typowane health/capability checks; metoda offline wymaga jawnego potwierdzenia modelu operacyjnego. Launch ma zapisać snapshot checklisty i aktora.

**Test zamykający:** adapter bez webhooka, z test key, wyłączonymi charges albo nieobsługiwaną walutą nie przechodzi launch; poprawny sandbox też nie jest mylony z live. Jawnie zatwierdzona metoda offline przechodzi tylko według osobnej polityki.

## Potwierdzone zabezpieczenia

1. **Backend jest źródłem cen i sum.** Storefront wywołuje Store API; nie znaleziono hardcodowania ceny transakcyjnej w checkout.
2. **Izolacja podstawowa.** Cart jest odnajdywany w bieżącym sklepie i autoryzowany tokenem/użytkownikiem; metoda płatności pochodzi z `current_store.payment_methods` (`PaymentsController:16`, `PaymentSessionsController:18`).
3. **Draft gate.** Tworzenie direct payment/session i ich complete/update wymaga `current_store.live?`, a ukończenie cartu ma tę samą blokadę (`RequiresLiveStore:10-17`; `CartsController:11,146-153`).
4. **Blokada zamówienia.** Payment sessions i completion wykonują krytyczne operacje pod order lock; `Carts::Complete` ponownie blokuje rekord (`PaymentSessionsController:17,40,60`; `spree/core/app/services/spree/carts/complete.rb:17-29`).
5. **Zwykła płatność nie może przekroczyć pozostałej sumy.** `Payment#max_amount` i walidacja ograniczają nowy rekord (`spree/core/app/models/spree/payment.rb:152-163,297-299`). To nie zamyka MONEY-001, bo zewnętrzna sesja powstaje wcześniej i ma osobny model.
6. **Waluty sklepu są allowlistowane.** Order waliduje currency w `store.supported_currencies_list` i rozwiązuje market (`spree/core/app/models/spree/order.rb:1157-1194`).
7. **Kwoty zamówienia mają precyzję do dwóch miejsc i ograniczenie zakresu.** `MONEY_VALIDATION` blokuje więcej niż dwa miejsca (`order.rb:88-101`). Jest to poprawne dla obecnego PLN; przed walutami o 0/3 cyfrach minor unit potrzebna będzie osobna decyzja.
8. **Refund nie może przekroczyć `credit_allowed`.** Model sumuje offsets i wcześniejsze refundy (`spree/core/app/models/spree/refund.rb:127-130`; `payment.rb:179-185`).
9. **Session webhook ma domenową ochronę przed powtórnym sukcesem.** `order.with_lock`, sprawdzenie `payment_session.completed?` i unikalność `Payment.response_code` ograniczają duplikaty (`handle_webhook.rb:33-48`; `payment_session.rb:79-100`; `payment.rb:43-45`).
10. **Shipping, podatki i promocje są przeliczane server-side.** State machine tworzy tax charges, shipment tax i promocje na przejściach (`spree/core/app/models/spree/order/checkout.rb:77-124`). Panel ma już Admin API/UI shipping methods i tax rates; nie jest to już luka opisana w starszym audycie F13.

## Coverage

| Obszar | Pokrycie | Wynik |
|---|---|---|
| ceny, cenniki, waluty, rounding | kod modeli/API/SDK/storefront | backend kanoniczny; PLN bez jawnej luki krytycznej |
| promocje, gift cards, store credit | kod ścieżek Store/Admin + wcześniejszy audyt | mechanizmy obecne; idempotency wymaga utwardzenia |
| shipping i podatki | state machine, readiness, Admin API/UI | konfiguracja istnieje; brak live E2E |
| koszyk i checkout | Server Actions, Store API, services/models | lock i tenant scope dobre; false-success i cart mismatch |
| payment methods/sessions | Store/Admin API, modele, SDK, UI | P0 amount boundary; brak realnego adaptera |
| Stripe/Connect | repo + dokumentacja stanu | frontend przygotowany, backend/operator niegotowy |
| webhooki | kontroler, job, serwis, URL | P0 routing/tenant; P1 durability/retry |
| capture/void/refund | modele, Admin API i dashboard | capture/void istnieją; refund wymaga workflow/idempotency |
| duplicate charge/retry | SDK + API idempotency + domenowe locki | częściowa ochrona, brak atomowego rejestru |
| tenant ownership | current store/cart/payment method | podstawy dobre; webhook jest wyjątkiem krytycznym |
| manipulacja klienta | params, walidacje, completion | większość sum po backendzie; session amount niezabezpieczone |

## Weryfikacja i ograniczenia

- Próba uruchomienia 4 skupionych testów Vitest storefrontu nie rozpoczęła testów: globalny `pnpm` nie jest dostępny; `corepack` przy `COREPACK_HOME=/tmp` próbował pobrać pnpm, lecz sandbox nie miał dostępu do registry. Wynik: **testy frontend niewykonane w tym środowisku**, nie czerwone.
- Próba uruchomienia 3 skupionych speców Rails załadowała aplikację, ale zakończyła się przed przykładami: dummy SQLite i log leżą w repo backendu, które w tej sesji jest read-only (`SQLite3::CantOpenException`, 0 examples). Wynik: **testy backend niewykonane**, nie czerwone.
- Nie wykonano prawdziwego payment intent, charge, capture ani refundu.
- Nie sprawdzono sekretów/konfiguracji Stripe, Redis/Rails cache, kolejki ani danych produkcyjnych. Repo i kanoniczny `stan-projektu.md` wskazują, że Stripe nie jest skonfigurowany.
- Nie wykonano zalogowanego browser E2E ani testu dwóch rzeczywistych tenantów.
- Audyt nie certyfikuje zgodności PCI DSS, PSD2/SCA, księgowej ani prawnej; wskazuje granice techniczne wymagające osobnych audytów.

## Kolejność domknięcia

1. Zamknąć MONEY-001 kontraktem kwoty/waluty i testami wyścigu.
2. Wybrać model Stripe/Connect oraz dodać realny adapter testowy (MONEY-005).
3. Naprawić URL i tenant resolution webhooka (MONEY-002/003).
4. Zbudować trwałe event inbox + idempotency/retry/reconciliation (MONEY-006/007).
5. Usunąć fałszywy sukces checkoutu i cart mismatch (MONEY-004/009).
6. Utwardzić launch readiness i refund workflow (MONEY-008/010).
7. Dopiero wtedy wykonać sandbox E2E dwóch tenantów, a następnie kontrolowany test prawdziwego zamówienia o minimalnej kwocie z reconciliation w panelu operatora.
