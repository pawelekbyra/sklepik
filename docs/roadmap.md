# Roadmapa

Kolejność prac dla całego systemu (oba repozytoria). Agent bierze zadania od góry: P0 przed P1, P1 przed P2. Zadania w tej samej grupie mogą iść równolegle, jeśli dotyczą różnych repo/plików. Po zamknięciu zadania: zaktualizuj jego status tutaj i stan w [`stan-projektu.md`](stan-projektu.md).

Jeśli któryś opis okaże się nieaktualny w chwili pracy — sprawdź kod, nie ufaj samemu opisowi.

**Zewnętrzne blokery sprzedaży:** konfiguracja realnego operatora płatności, prawdziwe dane i treści prawne merchanta oraz produkcyjny test zamówienia. Panel pozwala już edytować dokumenty i checklista wymusza ich uzupełnienie, ale platforma nie może wymyślić za właściciela danych prawnych ani zaakceptować umowy z operatorem płatności. Po audytach 2026-07-14 obowiązują również wewnętrzne P0/P1 poniżej; zewnętrzna konfiguracja nie może ich przykryć.

## Program napraw po audytach 2026-07-14 — aktywny blok przed dalszą roadmapą

Piętnaście raportów obszarowych objęło 4 859/4 859 śledzonych ścieżek na baseline'ach backend/admin `9a4f693147` i storefront `0f83b94`. Zdeduplikowaną ocenę, mapowanie findings i kryteria zamknięcia prowadzi raport nadrzędny [`docs/audits/2026-07-14-00-stan-fundamentu-sklepika.md`](audits/2026-07-14-00-stan-fundamentu-sklepika.md). Raporty 01–15 pozostają dowodem szczegółowym; nie kopiujemy każdego findingu jako osobnego projektu i nie uznajemy statycznego audytu za test runtime.

**Zasada wykonania:** poniższe etapy wyprzedzają otwarte F9/F11/F20/F22/F23/F28/F29 oraz nowe funkcje. Wyjątkiem są wyłącznie minimalne hotfixy i prace konieczne do wykonania testu zamykającego. Finding jest zamknięty dopiero po implementacji, teście wskazanym w raporcie i aktualizacji raportu nadrzędnego, `stan-projektu.md` oraz tego pliku.

### Etap A — natychmiastowe ograniczenie ryzyka

**A0. Zamrożenie niebezpiecznej ekspozycji** — oba repo + operacje — `[P0, natychmiast]`

- publiczny signup pozostaje wyłączony dla szerokiego ruchu; do wspólnego backendu nie wpuszczamy niezależnych merchantów z realnymi klientami;
- płatności online i automatyczny fulfillment pozostają wyłączone; dozwolone są wyłącznie kontrolowane sandboxy bez realnego capture;
- zatrzymać automatyczną promocję produkcji, dopóki `INFRA-001` nie blokuje deployu przy czerwonym teście/buildzie; awaryjny hotfix wymaga jawnego operatora i zapisanego SHA;
- zrotować znany credential produkcyjnego admina, unieważnić wszystkie refresh sessions, usunąć wartość z bieżących dokumentów/historii i wymusić jawne produkcyjne credentials seeda (`AUTH-001`);
- zachować dowody i baseline'y audytu; nie wykonywać globalnego rename'u Spree ani destrukcyjnych migracji jako „porządków”.

_Zamknięte gdy:_ stare hasło zwraca 401, sesje sprzed rotacji są nieważne, signup/payment gates są potwierdzone na produkcji, a celowo czerwony test i Docker build nie mogą uruchomić deployu.

### Etap B — P0: granice danych, pieniędzy i release'u

Zadania B1–B4 mogą iść równolegle w różnych obszarach, ale publiczny pilot z realnymi danymi wymaga wszystkich.

**B1. Izolacja klientów i konta per sklep** — `sklepik` + `sklepikFront` — `[P0/P1; TENANT-001/002/003, AUTH-002/003]`

- wdrożyć zatwierdzony model per-store customer identity/membership: tenantowy login, rejestracja, JWT, refresh, reset i profil; admin identity pozostaje globalna z rolami per store;
- scope'ować Admin Customers, agregaty, adresy, cards, credits, groups, tags, exporty, nested resources i `OrdersController#resolve_user` przed authorization; `SuperUser` nie może omijać tenant scope;
- zastąpić fail-open `Base.for_store` jawną klasyfikacją modeli globalnych/tenantowych; dodać constraints i reconciliation tam, gdzie to możliwe;
- zbudować black-box E2E na prawdziwym Rails/Postgres dla dwóch sklepów/adminów/kluczy/klientów, bez mocków.

_Zamknięte gdy:_ admin A nie może listować/czytać/modyfikować PII B ani utworzyć zamówienia dla klienta B; ten sam e-mail może mieć niezależne konto w A i B; token/reset/profile A nie działają w B; celowe usunięcie scope'u czerwieni CI.

**B2. Bezpieczny kontrakt płatności i tenantowy webhook PSP** — `sklepik` + `sklepikFront` — `[P0; MONEY-001/002/003, ASYNC-001]`

- usunąć `amount`/currency jako zaufane wejście Store API; gateway zawsze otrzymuje aktualne `order.amount_due` i currency pod lockiem;
- generować URL webhooka z kanonicznego publicznego originu backendu, nie domeny storefrontu;
- rozwiązywać tenant z nierozgadywalnego endpoint/payment-method bindingu, następnie weryfikować podpis sekretem tego sklepu;
- przed `2xx` zapisywać tenantowy payment inbox z unikalnym `provider + event_id`; worker ma mieć retry, DLQ, idempotentny efekt i reconciliation;
- usunąć fałszywy sukces frontendowy dla dowolnego 403/422 (`MONEY-004`).

_Zamknięte gdy:_ dwa tenanty i wspólny host przechodzą signed webhook sandbox; manipulacja kwotą/walutą nie zmienia gateway amount; Redis/worker crash, duplikat i reorder kończą się dokładnie jedną płatnością i jednym ukończonym zamówieniem; nieprzetworzone zdarzenie jest widoczne i retryowalne.

**B3. Trwały i powtarzalny artefakt bazy** — `sklepik` — `[P0/P1; DB-001/002/006]`

- wersjonować host-app albo przypiąć ją do SHA; migracje i ich checksum manifest muszą być częścią immutable obrazu/release'u;
- PostgreSQL `structure.sql` jako źródło prawdy, jeden idempotentny upgrade: migrate → wszystkie backfille tenantów → post-condition/orphan scan;
- PR gate na produkcyjnej major PostgreSQL: fresh install, upgrade z poprzedniego release, double-run efemerycznego flow i schema diff;
- wdrażać expand/backfill/contract z lock timeoutami i bez destrukcyjnego DDL bez dry-run/backup.

_Zamknięte gdy:_ ten sam release artifact przechodzi fresh/upgrade/double-run bez powtórnego DDL, wszystkie wymagane ownership backfille mają zero niedozwolonych NULL-i, a produkcja raportuje ten sam migration manifest co CI.

**B4. Build once, test, promote digest** — `sklepik` + infra — `[P0/P1; INFRA-001/002/003, SEC-004]`

- wymagane testy na PR i chroniony `main`; build bez `continue-on-error`; jedna serializowana ścieżka deployu z environment approval;
- przypiąć actions, starter i obrazy; budować raz w CI, generować SBOM/provenance/podpis i promować dokładny digest;
- release: restore point → migracje/post-conditions → nowy stack → readiness przez publiczne HTTPS → cutover; zachować poprzedni digest i przećwiczyć rollback/forward-fix;
- produkcja zapisuje commit, digest, starter SHA, migration manifest i contract version.

_Zamknięte gdy:_ zepsuty test/build/migracja/start/HTTPS nie promuje wersji ani nie wyłącza poprzedniej; host uruchamia dokładnie digest z CI; dwa buildy commita mają ten sam manifest; rollback drill mieści się w zaakceptowanym MTTR.

### Etap C — P1: bezpieczny pierwszy pilot sprzedażowy

**C1. Auth i lifecycle sesji** — `sklepik` + oba UI — `[P1; AUTH-004..010, PANEL-001]`

- digest refresh tokenów zamiast raw w DB, atomowa rotacja/token family i reuse detection;
- zmiana/reset hasła unieważnia stare sesje, a owner/customer ma „wyloguj wszędzie”;
- owner signup z potwierdzeniem e-mail, resend limitami i pełnym forgot/reset/recovery; niepotwierdzony owner nie uruchamia sklepu;
- dla admin cookie poprawna granica SameSite/Origin/CSRF; MFA/step-up przed operacjami wysokiego ryzyka.

_Zamknięte gdy:_ E2E signup→confirm→login→reset, równoległy refresh, revoke i browser CSRF przechodzą; DB/backup/log nie zawiera raw refresh; stare tokeny nie działają po recovery.

**C2. Bezpieczne treści, pliki i storefront runtime** — oba repo — `[P1; SEC-001/002/003, FRONT-001]`

- kanoniczna allowlistowa sanitizacja rich text w backendzie plus defence in depth w rendererze; CSP i nagłówki storefrontu;
- produkcyjnie wyłączyć `dangerouslyAllowLocalIP`, ograniczyć hosty Image Optimizer i przetestować SSRF redirects/rebinding;
- limity byte size/MIME/magic bytes/CSV, streaming i signed downloads zamiast pełnego blobu w RAM;
- odróżniać prawdziwe empty/404 od config/401/timeout/5xx; outage daje kontrolowany błąd/alert, nie pusty sklep.

_Zamknięte gdy:_ browser payload suite nie wykonuje JS, SSRF matrix jest odrzucana, pliki ponad limitem nie obciążają procesu, a pięć klas błędu API daje właściwe zachowanie i sygnał operacyjny.

**C3. Realny adapter PSP i operacje money** — `sklepik` + panel/storefront — `[P1; MONEY-005/006/008/010]`

- wybrać model Stripe Connect/oddzielne konta albo inny PSP i zapisać decyzję; klucze test/live, capabilities, webhook health i onboarding per tenant;
- trwała atomowa idempotencja dla money endpoints i przekazanie klucza do providera;
- command/outbox dla capture/void/refund z aktorem, powodem, statusem, audit trail i reconciliation;
- readiness rozróżnia „metoda istnieje” od „gotowa do live orders”.

_Zamknięte gdy:_ sandbox dwóch tenantów przechodzi onboarding, 3DS, webhook, capture, void, full/partial refund, timeout, duplikat i reconciliation bez sekretów w API/logach.

**C4. Trwałe eventy, e-mail i rozdział kolejek** — `sklepik` + `sklepikFront` — `[P1; ASYNC-002..008]`

- transactional outbox dla zdarzeń commerce; trwałe inbox/delivery states, poprawne retry 429/5xx/timeout, DLQ i idempotentni konsumenci;
- produkcja bez skonfigurowanego mailera ma status `blocked_configuration`, nie developerski sukces; provider message ID i reconciliation;
- respektować `notify_customer`; rozdzielić event faktu od komendy wiadomości;
- kolejki co najmniej `critical`, `webhooks/email`, `default`, `bulk/provisioning/media`, z osobnym concurrency/SLO.

_Zamknięte gdy:_ kill między DB commit a enqueue niczego nie gubi; transient webhook dochodzi po retry; 20 równoległych dostaw daje jeden mail; pięć zablokowanych provisioningów nie opóźnia payment inbox/resetu poza SLO.

**C5. Minimalny operacyjny cykl zamówienia** — `sklepik` + oba UI — `[P1; ORDER-001..006, MONEY-008]`

- jeden typowany command anulowania z aktorem, powodem, stockiem, void/refundem i zgodnym audit trail;
- `fulfill` wyłącznie z poprawnego stanu; `canceled → resume → fulfill` ponownie rezerwuje/zdejmuje stock; polityka resume płatności;
- pierwsza wersja zwrotu/reklamacji może być operator-assisted, ale musi łączyć sprawę, pozycje, przyjęcie towaru, decyzję, refund/replacement, komunikację i timeline;
- concurrency constraints/idempotency dla receive/refund oraz tenant invariants dla order/return/stock/payment.

_Zamknięte gdy:_ state/concurrency E2E paid/offline × unshipped/partial/shipped × cancel/return/refund daje dokładnie jeden efekt pieniędzy i stocku; klient widzi status sprawy, a merchant ma pełny actor/reason/gateway audit.

**C6. Guided shipping/tax i poprawna gotowość właściciela** — `sklepik` — `[P1; PANEL-002/003/004/008]`

- jeden prowadzony flow tworzy strefę z krajami, kategorię wysyłki, metodę, kalkulator i cenę;
- kontrakt podatku jednoznacznie rozróżnia procent/ułamek i wymaga strefy; 23% round-tripuje poprawnie i nalicza się w koszyku;
- readiness pokazuje error+retry i sprawdza provider live health, wymagane prawo, domenę/SSL, e-mail i test order; launch zapisuje snapshot i aktora;
- required E2E ownera: verified signup → provision → relogin → produkt/media → shipping/tax → PSP sandbox → prawo → publish → launch → sandbox order.

_Zamknięte gdy:_ świeży właściciel bez terminala przechodzi cały flow, readiness zmienia się wyłącznie po działającej konfiguracji, a kontrolowane 401/403/404/422/500/offline mają działanie naprawcze.

**C7. DR, alerty i odtworzenie hosta** — infra + `sklepik` — `[P1; DR-001..005, INFRA-004..007]`

- wersjonowane skrypty backup/restore, manifest/checksum, zewnętrzny heartbeat i alert wieku/rozmiaru/testu restore;
- izolowany pełny restore DB + próbka originals + DB↔R2↔provider reconciliation; zatwierdzić RPO/RTO;
- niezależna immutable/off-provider kopia DB i originals z osobnymi minimalnymi credentials;
- idempotentny bootstrap/IaC czystej VM, trwały firewall, TLS, cron/timers, monitoring i secrets recovery; web bez tokenów provisioningowych.

_Zamknięte gdy:_ utrata hosta i restore na czystej infrastrukturze przechodzą schema/tenant/money/media checks w RPO/RTO; przerwany backup/web/worker/DB/dysk/cert wysyła alert poza host; credential aplikacji nie usuwa backupu.

**C8. Storefront jako bramka sprzedaży** — `sklepikFront` + kontrakty backendu — `[P1; FRONT-002..005]`

- default-deny consent manager i Consent Mode; immutable snapshoty dokumentów oraz dowód akceptacji per customer/order/version/locale;
- publiczny profil sprzedawcy, kontakt i wejście do obsługi posprzedażowej z danych Store API;
- zastąpić stare `/us/en` E2E aktualnym PL golden path; Chromium/Firefox/WebKit mobile/desktop oraz canary po deployu;
- contract/renderer runtime validation i pełna obsługa każdego publikowalnego pola.

_Zamknięte gdy:_ przed zgodą nie ma opcjonalnego trackingu; zamówienie wskazuje dokładne wersje dokumentów; każdy nowy tenant ma publiczne dane i kontakt; aktualny checkout/order/mail przechodzi w wymaganym CI i canary.

### Etap D — P1/P2: bezpieczny self-service i skalowanie

**D1. Provisioning jako durable control plane** — `sklepik` — `[ARCH-003/004, ASYNC-006, INFRA-008, PANEL-007]`

Persisted state per krok, idempotency/adoption/compensation, retry od niedomkniętego kroku, reconcile providerów, GitHub App, pełny manifest wymaganych env i routowalna strona status/retry. Zapis template SHA, contract/release version i wszystkich resource IDs. Chaos po każdym callu kończy się jednym repo/projektem/deployem albo kontrolowanym rollbackiem.

**D2. Edytor revisions/preview/rollback** — oba repo — `[PANEL-005/006/009/015]`

Immutable revisions, publish z expected revision, actor/diff, rollback jako nowa rewizja, dirty guard/autosave oraz podpisany tenantowy draft preview używający tego samego renderera. AI dopiero nad typed commands, dry-run, approval i auditem.

**D3. Observability, capacity, scheduler i retencja** — infra + oba repo — `[ASYNC-009..011, DB-008/009, INFRA-005/009/010/014]`

Zewnętrzne synthetic tests, centralne logi/metryki/tracing, queue age/DLQ, scheduler z missed-run alertem, SQL budgets, load/noisy-tenant tests, resource/log limits oraz zatwierdzona polityka PII/backup retention z tombstone replay.

**D4. Kompletny kontrakt API i flota storefrontów** — oba repo — `[API-001..007, INFRA-011/012]`

Niepuste, deterministyczne OpenAPI Store/Admin; generated types/Zod/SDK i clean-diff gate; consumer-driven contracts na realnym Rails dla obecnej i najstarszej wspieranej wersji; version/deprecation/capability policy oraz canary→cohort→rollback floty.

### Etap E — publiczna warstwa Sklepika, bez globalnego rename'u

Ten etap realizuje F29 równolegle z naprawami tylko tam, gdzie nie dotyka krytycznej ścieżki bez jej testów. Celem jest zatrzymanie nowych przecieków i migracja konsumentów, nie kosmetyczne przepisywanie silnika.

1. **Baseline i zakaz wzrostu:** allowlista istniejących `@spree/*`, `Spree::*`, `X-Spree-*`, cookies/env/routes z ownerem; CI blokuje nowe wystąpienia poza engine i `adapters/spree`.
2. **Własny kontrakt:** `@sklepik/contracts`, `@sklepik/store-client`, `@sklepik/admin-client`; domenowe IDs, errors, permission subjects, payment providers i wersjonowany event envelope. Początkowo fasady delegują do obecnych SDK.
3. **Migracja konsumentów:** storefront katalog→konto→koszyk→checkout; dashboard permissions/metafields→hooks/forms→UI. Krytyczny checkout testuje stary/nowy adapter na tych samych fixtures.
4. **Kompatybilny protokół:** `SKLEPIK_*` z fallbackiem do `SPREE_*`; `X-Sklepik-*` i `X-Spree-*` dual-read z błędem przy konflikcie; cookies dual-read/write-new bez utraty sesji/koszyka; `/api/webhooks/sklepik` i stary route do jednego verifiera/inboxu.
5. **Pakiety i branding:** first-party używa `@sklepik/*`, stare pakiety są deprecated re-exportami z terminem i telemetrią. Spree znika z UI, onboardingów, publicznych błędów i runbooków operatora, ale pozostaje jawnie opisanym adapterem technicznym.
6. **Silnik pozostaje stabilny:** namespace Ruby, gemy, 131 tabel `spree_*` i historyczne migracje nie są globalnie zmieniane. Ewentualna wymiana bounded contextu wymaga eksport/import, reconciliation pieniędzy i zamówień, dry-run, restore i rollback.

_Warunek zakończenia:_ nowe funkcje nie importują silnika poza adapterem; stare i nowe klienty przechodzą contract/E2E; telemetria potwierdza uzgodnione okno zerowego użycia legacy przed usunięciem aliasu; istniejące sesje, koszyki, webhooki i storefronty nie tracą ciągłości.

## Faza 1 — Fundament techniczny

Cel fazy: cały łańcuch działa niezawodnie — produkt dodany w adminie jest widoczny i kupowalny w storefroncie, deploy nie jest ruletką, a błędy są widoczne zamiast ciche.

### P0 — blokery produkcyjne

**F1. Rozdziel build od migracji bazy** — `sklepik` — `[zamknięte 2026-07-07]`
Migracje przeniesione do `bin/render-release.sh` (preDeployCommand); build zadaje tylko image. Wszystkie 16 migracji w forku na `if_not_exists` — idempotentne przy re-deployu. `docs/deployment-render.md` opisuje rzeczywisty flow: Build (image) → Release (migracje) → Start (puma).

**F2. Domknij kontrakt pieniędzy w Admin API** — `sklepik` — `[zamknięte 2026-07-07]`
Dodana `Spree::CanonicalNumber` parser (format `\A-?\d+(\.\d{1,4})?\z`) + concern `CanonicalMoneyParams` w PricesController, ProductsController, VariantsController. Wszystkie wpisy cen przez Admin API v3 trafiają kanoniczny format `"1234.56"` bez zależności od locale. Testy: `24.99` i `24,99` się rejektują, `"1234.56"` przechodzi. LocalizedNumber zostaje tylko w legacy admin.

### P1 — realne ryzyka biznesowe i UX

**F3. Serwerowa walidacja gotowości produktu do sprzedaży** — `sklepik` — `[zamknięte 2026-07-07]`
Serwis `Spree::Products::ReadinessCheck` sprawdza: `status: active`, publikacja na wszystkich kanałach sklepu, ceny w walutach wszystkich rynków, purchasable variant, tłumaczenia w locale'ach rynków. Endpoint `GET /api/v3/admin/products/:id/readiness` zwraca `{ ready, checks: [{key, ready, message}] }`. Testy: 6 scenariuszy (gotowy, wrong status, unpublished channel, no price, no stock, no translation). Konsument w panelu dociągnięty: `@spree/admin-sdk` (`products.readiness`), hook `useProductReadiness` i banner ostrzegawczy `ProductReadinessBanner` na stronie edycji produktu (`packages/dashboard/src/routes/.../products/$productId.tsx`) — bez tego merchant mógł zapisać niekompletny produkt (np. bez ceny — `require_master_price` domyślnie `false`) bez żadnego ostrzeżenia w panelu.

**F4. Cache invalidation on-demand w storefroncie** — `sklepikFront` + `sklepik` — `[zamknięte 2026-07-11]`
Backend już publikował `product.created`/`updated`/`deleted`/`activated`/`archived`/`out_of_stock`/`back_in_stock` (`Spree::Product` ma `publishes_lifecycle_events` + własne `publish_event` na zmianę statusu/zapasu — nie wymagało zmian). Storefront: jeden handler `handleProductChanged` w `/api/webhooks/spree` (`sklepikFront/src/lib/webhooks/handlers.ts`) busuje `products`, `product-filters`, `product:{slug}` + `revalidatePath` dla wszystkich siedmiu. Skonfigurowane w adminie (Ustawienia → Webhooks) — endpoint na `{storefront}/api/webhooks/spree` z tymi siedmioma eventami w subskrypcji.
_Zasada na przyszłość:_ nowy event produktowy dopisuje się do subskrypcji endpointu **tylko** razem z handlerem po stronie frontu — świadomie nie subskrybujemy `*` (niepotrzebny ruch webhookowy dla eventów bez handlera, patrz `sklepikFront/docs/technical-debt.md`).
_Zweryfikowane 2026-07-11:_ edycja samej ceny (`Spree::Price`) idzie przez `touch: true` (Price → Variant → Product) i `Spree::Product` ma `after_touch -> { publish_event("#{event_prefix}.updated") }, if: :should_publish_events?` (`spree/core/app/models/spree/product.rb:143`) — potwierdzone w kodzie i testem (`product_spec.rb`), że touch chain aktualizuje `product.updated_at` i odpala publikację `product.updated`. Edycja ceny/rynku jest więc widoczna w storefroncie w sekundach tak samo jak inne zmiany produktu.

**F5. Jawne stany błędów w dashboardzie** — `sklepik` (`packages/dashboard*`) — `[zamknięte 2026-07-08]`
`ResourceTable` teraz destrukturyzuje `isError`/`error`/`refetch` z `useQuery` i renderuje `ErrorState` (ten sam komponent co widoki szczegółów) zamiast pustej/wiecznie ładującej się tabeli, gdy lista nie może się załadować — sprawdzone w obu trybach renderowania (zwykłym i `reorder`).
_Powiązane znalezione i naprawione 2026-07-07 (audyt, patrz F12):_ osobna, ale tej samej rangi klasa błędu — **ciche błędy przy mutacjach**, nie przy ładowaniu list. `useOrderMutation` nie miał `onError`, więc payment capture/void/create, fulfillment, zwroty, karty podarunkowe/kredyt sklepowy, edycja adresu, notatki, tagi — wszystko failowało bez toastu (najwyższe ryzyko: capture/void płatności, sprzedawca mógł myśleć że transakcja przeszła). Edycja adresu zamówienia dodatkowo invalidowała zły klucz cache (`['order', id]` zamiast `['orders', storeId, id]`) — udany zapis nie odświeżał widoku. Usuwanie klienta z listy łykało wszystkie błędy przez `.catch(() => undefined)`. Bulk-add w pickerze mediów wariantu nie miał żadnej obsługi błędu.
_Zamknięte gdy:_ `ResourceTable` pokazuje jawny stan błędu (część list) ORAZ audyt F12 potwierdzi że nie ma więcej cichych mutacji w priorytetowych zasobach.

**F6. Trwała idempotencja webhooków e-mail** — `sklepikFront` — `[zamknięte kodowo 2026-07-11, wymaga konfiguracji właściciela]`
Ochrona przed duplikatami zdarzeń przeniesiona z `Set` w pamięci na Upstash Redis (`src/lib/webhooks/idempotency.ts`, klucz `webhook-processed:{eventId}`, TTL 7 dni; działa też z Vercel KV — te same env var, druga konwencja nazw). Bez ustawionych credentiali kod łagodnie wraca do starego zachowania in-memory (log ostrzeżenia w produkcji) — nic się nie psuje, ale ochrona nie jest jeszcze trwała. Testy: 8 przypadków (fallback in-memory, ścieżka Redis, alias nazw dla Vercel KV).
_Zamknięte gdy:_ właściciel ustawi `UPSTASH_REDIS_REST_URL`/`UPSTASH_REDIS_REST_TOKEN` (albo `KV_REST_API_URL`/`KV_REST_API_TOKEN`) na Vercelu — dopiero wtedy restart instancji faktycznie nie resetuje ochrony przed duplikatami.

### P2 — porządek operacyjny

**F7. Worker w tle** — `sklepik` — `[zamknięte 2026-07-09, dociąganie w F20]`
Sidekiq worker działa od migracji na Oracle Cloud (F8) — kontener `sidekiq` w `docker-compose.yml`, uruchomiony razem z resztą stacku. `render.yaml` (legacy, Render nieużywany od 2026-07-09) miał workera odkomentowanego wcześniej, ale to już nieaktualna ścieżka. Pre-generowanie wariantów zdjęć zaraz po uploadzie (skutek braku workera: warianty Active Storage `xlarge` 2000×2000 generowały się leniwie na pierwsze żądanie, zmierzone 12.5s zimny cache vs 1.3s scache'owane, potrafiło przekroczyć timeout Vercel Image Optimization) nadal nie jest zaimplementowane jako feature — worker istnieje, ale nic jeszcze nie enqueue'uje tego joba; patrz F20.

**F8. Decyzja o planie Render / migracja hostingu** — infra — `[zamknięte 2026-07-09]`
Starter ($7/mo) zdejmuje cold start, ale ma te same 512 MB co free (ryzyko OOM bez zmian). OOM (>512 MB) zaobserwowany dwukrotnie pod realnym ruchem (drugi raz 2026-07-07, ~14 min po deployu, Render sam podniósł instancję) — nie jest to już jednorazowy fluke.
_Sprawdzone alternatywy (2026-07-07):_ Fly.io stracił darmowy tier w 2024 — dziś pay-as-you-go, ~$8-15/mo za 1GB RAM (taniej niż Render Standard, ale nie za darmo, plus migracja configu). Oracle Cloud "Always Free" daje 4 rdzenie ARM + 24GB RAM na zawsze za $0, ale to goły VPS — trzeba samemu postawić Docker/Postgres/Redis/Nginx/SSL, brak auto-deploy z gita.
_Decyzja (2026-07-08):_ właściciel migruje na Oracle Cloud zamiast płacić za Render Standard. Always Free Ampere A1 dał `Out of capacity` w regionie Paris, zaakceptowany fallback: płatny `VM.Standard.E4.Flex` (1 OCPU / 8 GB RAM).
_Zamknięte 2026-07-09:_ backend (Rails/Puma + Postgres + Redis + Sidekiq + Nginx) działa w Docker Compose na Oracle VPS (141.253.103.172, SSL przez `nip.io` + Let's Encrypt), storefront i panel admina zaktualizowane na nowy backend. Render wycofany z produkcji (pozostaje jako `docs/deployment-render.md`, opis legacy). Szczegóły: [`deployment-oracle.md`](deployment-oracle.md), [`architektura.md`](architektura.md).

**F10. Logo sklepu — brak UI i brak konsumenta** — `sklepik` + `sklepikFront` — `[zamknięte 2026-07-07]`
`Spree::Store#logo` istniał w bazie od dawna, ale nic go nie używało. Domknięte kompletnie: nowy publiczny `GET /api/v3/store/store` (`Spree::Api::V3::StoreSerializer`, `Admin::StoreSerializer` teraz go dziedziczy zamiast duplikować pola — "Admin extends Store" z CLAUDE.md), `:logo` dopuszczony w `permitted_params` Admin API (nigdy wcześniej nie akceptował zapisu), walidacja `content_type` na `Store#logo` dociągnięta (miała ją tylko `mailer_logo`). Panel: pole uploadu w Ustawienia → Sklep (`settings/store.tsx`, wzorzec `ImageUploadField` skopiowany z `settings/emails.tsx`), zapis przez `logo_signed_id`. Storefront: `Header.tsx` renderuje `logo_url` zamiast tekstowej nazwy (fallback gdy brak), max 40px wysokości bez wymuszonego cropu; JSON-LD SEO bierze logo z API z fallbackiem na statyczny env.
_Dług techniczny:_ `@spree/sdk` na npm nie ma jeszcze opublikowanej `store.get()` (dodana w monorepie) — storefront obchodzi to udokumentowanym escape hatchem, patrz `sklepikFront/docs/technical-debt.md`.

**F11. Przełącznik kraju/waluty w storefroncie — zepsuty i koncepcyjnie pomieszany** — `sklepikFront` — `[częściowo zamknięte 2026-07-07]`
`CountrySwitcher.tsx` mieszał język i walutę w jednym dropdownie, budował linki wg starego schematu `/{country}/{locale}/...` usuniętego z routingu → wybór innego kraju dawał 404; flaga-emoji nie renderowała się na części systemów i dublowała się wizualnie z tekstem kodu kraju obok. Pełny plan rozdzielenia (Market vs Język, dwie niezależne osie jak w Amazon/ASOS/Shopify Markets) w [`docs/plans/market-language-switcher.md`](plans/market-language-switcher.md).
Kroki 0+1 wykonane: zepsuty dropdown usunięty, zastąpiony `LanguageSwitcher.tsx` (next-intl, niezależny od waluty).
_Zamknięte gdy:_ kroki 2-4 planu zrealizowane — realny drugi `Market` (np. Eurozone/EUR) w adminie, `MarketSwitcher` oparty o cookie.

**F12. Systematyczny audyt panelu — read/write symmetry, martwe endpointy, ciche błędy** — `sklepik` (`packages/dashboard*`, `spree/api`) — `[zamknięte 2026-07-07]`
Po dwóch niezależnych znaleziskach tego samego kształtu (F10 — logo istniało w API, brak UI; F3 — readiness check istniał, zero konsumentów) zlecony systematyczny audyt wg trzech wzorców: (1) pole w serializerze bez odpowiednika w `permitted_params`/UI (i odwrotnie); (2) akcja kontrolera bez żadnego odniesienia we froncie (SDK/hook/route); (3) `.mutateAsync` bez `try/catch` + `mapSpreeErrorsToForm`/`toast.error` — cichy błąd wygląda jak sukces.
_Wzorzec 3 (ciche błędy), naprawione:_ opisane w F5 powyżej — `useOrderMutation` bez `onError`, zła invalidacja cache przy adresie zamówienia, `.catch(() => undefined)` przy usuwaniu klienta, brak obsługi błędu w pickerze mediów wariantu. Reszta priorytetowych zasobów (produkty, promocje, ceny, płatności, lokalizacje magazynowe) sprawdzona — konsekwentnie korzystają z `useResourceMutation`/`mapSpreeErrorsToForm`, żadnych dodatkowych cichych błędów nie znaleziono.
_Wzorzec 2 (martwe endpointy), znaleziska nie naprawione — wymagają decyzji produktowej/UI, nie samego wpięcia:_

- `Admin::PriceListsController#prices` ("spreadsheet data feed") nie ma w ogóle trasy w `config/routes.rb` — martwy kod, nieosiągalny nawet przez API. Prawdopodobnie relikt po przejściu cen list na payload PATCH (`prices: [...]`) — do usunięcia albo faktycznego wpięcia, jeśli spreadsheet ma z niego korzystać.
- `orders/fulfillments#resume` i `#split` — w SDK (`adminClient.orders.fulfillments.resume/split`), zero użycia w `$orderId.tsx`. Panel umie fulfillment anulować, ale nie wznowić błędnie anulowanej wysyłki ani podzielić jej na dwie (częściowa wysyłka/backorder).
- `Channels#add_products` / `#remove_products` — cały mechanizm przypisywania produktów do kanału dystrybucji nie ma ŻADNEGO UI (`settings/channels.tsx`, 469 linii, zero wzmianek o produktach). Kanał da się utworzyć w panelu, ale nie da się do niego przypisać ani jednego produktu — funkcja praktycznie bezużyteczna z poziomu panelu.
  _Wzorzec 1 (read/write symmetry):_ przegoniony punktowo dla klientów, metod płatności, lokalizacji magazynowych, zamówień, promocji — symetryczne. Jedyna asymetria: `customers_controller#permitted_params` przyjmuje `:avatar`/`:selected_locale`, ale żaden serializer ich nie zwraca i żaden UI ich nie ustawia — martwe parametry, nie realna luka (nic ich nie używa z żadnej strony).
  _Rekomendacja:_ trzy znaleziska wzorca 2 wyżej to kandydaci na osobne, mniejsze zadania (każde wymaga UI/decyzji, nie tylko wpięcia) — kanały produktowe najpilniejsze biznesowo, jeśli multi-channel selling jest w planach.
  _Metodologia i mapa pokrycia (jednorazowy przebieg vs cały panel):_ [`docs/audit-playbook.md`](audit-playbook.md) — zapisany jako powtarzalny proces, nie jednorazowa notatka. Pięć gotowych do wklejenia promptów na kolejne rundy audytu (katalog, wysyłka/podatki, bezpieczeństwo panelu, pieniądze klienta, konfiguracja/integracje) czeka tam na odpalenie — patrz **F13**.

**F13. Kolejne rundy audytu panelu (kontynuacja F12)** — `sklepik` (`packages/dashboard*`, `spree/api`) — `[zamknięte audytowo 2026-07-08; znaleziska otwarte]`
F12 sprawdził punktowo priorytetowe zasoby (zamówienia, klienci, promocje, ceny, płatności, magazyny). 2026-07-08 zrealizowano wszystkie pięć gotowych promptów z `docs/audit-playbook.md`:

1. **Katalog produktów/wariantów/opcji/kategorii/media:** brak dodatkowych cichych błędów mutacji; istniejące endpointy katalogowe mają konsumentów (korekta: top-level `/api/v3/admin/variants` jest używany przez kreator transferów magazynowych); znaleziska wymagające decyzji UI/produktu to ukryte pola produktowe (`available_on`, `promotionable`, `digital`, `meta_keywords`), brak inputów `cost_price`/`cost_currency` wariantu i techniczne `metadata` opcji bez ścieżki zapisu/UI.
2. **Wysyłka/podatki/strefy/transfery:** tax categories i stock transfers są spięte i błędy mutacji są widoczne, ale Admin API v3/panel nie mają konfiguracji shipping methods, shipping categories, zones ani tax rates — money-critical luka przed sprzedażą.
3. **Bezpieczeństwo panelu:** staff, role pickery, zaproszenia i API keys są spięte, błędy są widoczne, ale staff management wymaga backendowego guardu przed usunięciem siebie albo ostatniego administratora sklepu.
4. **Pieniądze klienta:** gift cards, gift-card batches i customer store credits mają działające API/UI; w ramach audytu dodano brakujące `errorMessage` do hooków store credit klienta. Otwarte pozostają pełny lifecycle refunds/returns/reimbursements, decyzja czy `store_credit_categories` mają mieć CRUD, oraz brak Admin API/UI dla wishlist i cyfrowych pobrań.
5. **Konfiguracja/integracje:** webhooks, webhook deliveries, custom fields, translations, allowed origins, exports i markets mają konsumentów w SDK/panelu, ale brakuje rotacji sekretu webhook endpointu, Admin API/UI dla `data_feeds` oraz mapowania błędów `translations/batch` na konkretne wiersze edytora. Kod formularza rynku ma pełny picker walut/krajów, ale zgłoszony pusty przełącznik kraju/waluty w działającym dashboardzie nadal wymaga manualnej reprodukcji przed zamknięciem.

Szczegółowe raporty są w [`docs/audit-playbook.md`](audit-playbook.md). F13 jako przebieg audytowy jest zamknięte (brak `⬜` w mapie pokrycia), natomiast wiersze `⚠️` są materiałem na osobne zadania produktowo/backendowe przed sprzedażą.

**F14. Guard przed usunięciem siebie/ostatniego admina** — `sklepik` (`spree/api`) — `[zamknięte 2026-07-08]`
Znalezisko F13 prompt 3: `AdminUsersController#destroy`/`#update` pozwalały usunąć ostatniego store-scoped admina albo odebrać sobie ostatnią rolę administracyjną — realne ryzyko lockoutu ze sklepu. Dodano `reject_last_admin_removal!` — sprawdza, czy target trzyma rolę `admin` na `current_store` i czy istnieje inny użytkownik z tą rolą na tym samym store; jeśli nie, `destroy`/`update` (przy usuwaniu roli `admin` z `role_ids`) zwraca 403 zamiast wykonać operację. Nie blokuje edycji identity fields ani przypisywania innych ról. Testy: `admin_users_controller_spec.rb` (sole-admin destroy/update forbidden, identity update still allowed, multi-admin destroy/update allowed, non-admin target unaffected) + poprawiona fixtura w `admin_users_spec.rb` (integration/rswag), która wcześniej niechcący usuwała jedynego admina.

**F15. Audyt idempotentności migracji** — `sklepik` (`spree/core/db/migrate`) — `[zamknięte 2026-07-10]`
Znalezisko systemowego audytu (SYS-012): część migracji nadal bez `if_not_exists`/`if_exists` mimo efemerycznego `server/` na Renderze. Dodano guardy do 5 migracji (`create_spree_payment_sessions`, `create_spree_payment_setup_sessions`, `create_spree_api_keys`, `create_spree_refresh_tokens`, `improve_spree_webhooks`) — wszystkie create_table i add_column operacje są teraz idempotentne.

**F16. Rate limiting na auth/reset/newsletter** — `sklepik` (`spree/api`) — `[zamknięte 2026-07-10, poprawka 2026-07-11]`
Znalezisko systemowego audytu (SYS-008): brak Rack::Attack/throttlingu na `auth/login`, `password_resets`, `customers#create`, newsletter subscribe. Implementacja: nowy initializer `rack_attack.rb` z throttlami per IP i per email (5/hour login, 3/hour password reset, 10/day newsletter). Status 429 z Retry-After header. **Poprawka 2026-07-11** (znaleziona podczas audytu kompatybilności `sklepikFront`): `throttled_responder` zwracał `{ error: "string" }` zamiast kanonicznej koperty `{ error: { code, message } }`, którą czyta `SpreeError` w `@spree/sdk` — skutek: pusty komunikat błędu przy throttlingu w storefroncie i panelu. Naprawione, zweryfikowane empirycznie przez uruchomienie realnego kodu SDK. Szczegóły w `engine-decisions.md`.

**F17. Rotacja sekretu webhook endpointu** — `sklepik` (`spree/api` + panel) — `[zamknięte 2026-07-10]`
Znalezisko F13 prompt 5: `secret_key` webhook endpointu jest pokazywany tylko raz przy tworzeniu; brak endpointu/UI do rotacji istniejącego sekretu. Jedyna dzisiejsza ścieżka po wycieku to nowy endpoint + wyłączenie starego. Dodano: akcja PATCH `/webhook_endpoints/:id/rotate_secret` regeneruje sekret i oznamuje w response (z flagą `@reveal_secret_in_response`), panel wyświetla go w dedicowanym sheet z kopią i ostrzeżeniem, że stary sekret stracił ważność.

**F18. Per-wierszowe błędy w batch translations** — `sklepik` (panel) — `[zamknięte 2026-07-10]`
Znalezisko F13 prompt 5: znaleziono że backend zwraca `details.translations[index]` przy 422. Weryfikacja: kod frontendu już implementuje obsługę per-row errors (linie 190-211 w resource-translations-dialog.tsx). Backend test potwierdza że indeks jest zwracany prawidłowo. Feature jest kompletna, tylko nigdy nie była testowana E2E.

**F19. Drobne luki katalogu i pieniędzy klienta** — `sklepik` (`spree/api` + panel) — `[częściowo zamknięte 2026-07-11]`
Zbiór mniejszych znalezisk z F13: (1) ✅ CRUD dla `store_credit_categories` zamiast tylko read-only — API kompletna (routes + permitted_params); (2) ✅ pola produktu — patrz niżej; (3)-(5) UI pola wariantu (koszt własny), opcji i kategorii — nadal pending, wymaga dedykowanej sesji UI.
_Pola produktu, zamknięte 2026-07-11:_ `meta_keywords` i `promotionable` dodane do formularza edycji produktu (karty SEO/Status w `product-form-cards.tsx`). Przy okazji naprawiona realna asymetria read/write: `promotionable` był w `permitted_params` (zapisywalny), ale **żaden serializer go nie zwracał** — zapis działał, ale panel nigdy nie pokazywał aktualnej wartości. Dodany do `Admin::ProductSerializer` + przegenerowane typy (`typelizer:generate`).
_Korekta audytu — `available_on` i `digital` NIE dostały UI, świadomie:_ `available_on=` okazał się deprecated (`spree/core/app/models/spree/product/channels.rb`) — pisze do `published_at` **wszystkich** publikacji kanałów naraz i zostanie usunięty w Spree 6.0; właściwy, niededeprekowany odpowiednik (`product_publications[].published_at` per kanał) ma już pełne UI (`PublishingCard`). Budowanie nowego UI dla deprecated pola byłoby krokiem wstecz. `digital` w ogóle nie jest zapisywalnym atrybutem — `Product#digital?` to metoda liczona z `shipping_category`, nie kolumna ani setter; `:digital` w `permitted_params` było martwym, nigdy nietestowanym parametrem, które crashowałoby `ActiveModel::UnknownAttributeError`, gdyby jakikolwiek klient faktycznie je wysłał — usunięte jako sprzątanie, nie zbudowane jako feature.

**F20. Hardening pipeline'u media/R2** — `sklepik` — `[częściowo zamknięte 2026-07-11]`
Znalezisko systemowego audytu (SYS-018): limity rozmiaru/typu uploadu, cleanup unattached Active Storage blobs, przegląd cache headers/R2 bucket policy.
_Zamknięte 2026-07-11:_ nowa preferencja `Spree::Config.max_image_upload_size` (domyślnie 10 MB) egzekwowana przez `active_storage_validations` (`size: { less_than: ->(_) { ... } }` — lambda, nie stała wartość, żeby zmiana preferencji per-request/testowo faktycznie działała) na `Spree::Asset#attachment`, `Spree::Store#logo`/`#mailer_logo`, `Spree::Taxon#image`/`#square_image`. Przy okazji naprawiona realna luka: `Spree::OptionValue#image` nie miał **żadnej** walidacji typu ani rozmiaru — teraz ma obie. Nowy rake task `spree:media:purge_unattached_blobs` (`ENV['OLDER_THAN_HOURS']`, domyślnie 24h) kolejkuje `ActiveStorage::PurgeJob` dla blobów bez właściciela starszych niż cutoff — chroni przed rasą z uploadem w trakcie zapisu formularza. Testy: rozmiar (5 modeli), content-type dla `OptionValue`, 8 przypadków dla rake taska (stary/świeży/przypisany blob, custom cutoff).
_Otwarte:_ przegląd cache headers i bucket policy R2 — wymaga dostępu do konsoli Cloudflare (infra, nie kod) i/lub do `server/` (klon `spree-starter`, `.gitignored`, poza tym repo). Pre-generowanie wariantów zaraz po uploadzie w tle (worker Sidekiq już dostępny — F7, zamknięte 2026-07-09 — ale nic jeszcze nie enqueue'uje tego joba) — nadal do zrobienia. Uruchamianie `purge_unattached_blobs` na cronie (Sidekiq-cron albo system cron) — task istnieje, ale nic go jeszcze automatycznie nie wywołuje.

**F21. Admin API/panel dla shipping methods/zones/tax rates** — `sklepik` — `[backend i ekrany istnieją; owner flow ponownie otwarty po audycie 14]`
Money-critical luka z F13 prompt 2 (SYS-002): wcześniej nie było panelowej/API konfiguracji metod wysyłki, kategorii wysyłki, stref i stawek podatkowych. Backend oraz trzy ekrany CRUD (`settings/shipping-methods.tsx`, `settings/tax-rates.tsx`, `settings/zones.tsx`) powstały 2026-07-10. Audyt 14 wykazał jednak, że obecność ekranów nie zamknęła zdolności biznesowej: formularz wysyłki nie tworzy wymaganej kategorii, członków strefy, kalkulatora i ceny, ma też niespójne wartości `display_on`; ekran podatku wysyła procent bez jednoznacznej konwersji i nie wiąże strefy. Domknięcie jest teraz w C6 (`PANEL-002/003`): guided flow oraz test koszyka dla polskiego adresu i VAT 23%.

**F22. Pełny lifecycle zwrotów/reimbursements** — `sklepik` — `[otwarte; P1 przed samodzielną obsługą prawdziwych zamówień]`
Znalezisko F13 prompt 4: działają tylko proste order-level refundy; brak Admin API/UI dla `reimbursement_types`, `refund_reasons`, `return_authorization_reasons`, `customer_returns`. Audyty 07–08 wykazały, że prosty refund nie zapewnia bezpiecznego cyklu: brakuje aktora i alokacji pozycji, trwałej idempotencji, przyjęcia zwrotu, stocku, reimbursementu, reklamacji, komunikacji i reconciliation. Minimalny operator-assisted workflow jest teraz C5; pełny self-service pozostaje dalszą częścią F22.

**F23. Admin UI dla wishlist / cyfrowych pobrań / data feeds** — `sklepik` — `[otwarte, poza zakresem MVP]`
Znaleziska F13 prompt 4 i 5: Store API ma `wishlists`, `digitals/:token` i `Spree::DataFeed`, ale zero Admin API/SDK/UI, więc merchant nie ma podglądu list życzeń, zarządzania plikami cyfrowymi ani konfiguracji feedów produktowych (Google Shopping/Meta Catalog). **Świadomie poza zakresem MVP** — sklep sprzedaje produkty fizyczne, nie planuje na razie reklam produktowych ani treści cyfrowych; wrócić do tego, jeśli to się zmieni.

**F24. Runbooki observability dla typowych awarii** — `sklepik` (docs) — `[zamknięte 2026-07-10]`
Znalezisko systemowego audytu (SYS-014): brak runbooków dla awarii operacyjnych. Implementacja: stworzono `docs/runbooks.md` z 6 runbookami dla common production issues (OOM, 500 na liście, duplicate payment, empty catalog, webhook retry loop, rate limit). Każdy runbook: objawy → przyczyny → diagnostyka (z komendami) → fixes → prevention. Plus general troubleshooting procedures.

**CI Test Fixes** — `sklepik` — `[zamknięte 2026-07-10, PR #25]`
Naprawiono sześć usterek w testach zaraz po zmergowaniu F15-F24:
1. **Rack::Attack initializer brakował require** (commit 99aaaf9): `config/initializers/rack_attack.rb` powodował NameError na boot (`Rack::Attack` was undefined), co blokowało wszystkie migracje bazy na wszystkich 627 testach — zielone testy po dodaniu `require 'rack/attack'` na pierwszej linii.
2. **Test isolation issue w role_user_spec.rb** (commity 9b1a532 → 5f4a8c4 → końcowy): test „associate with different user types" używał `AdminUser.new(id: 99)` — hardcoded ID kolidował z rekordem już istniejącym w sparalelizowanej kopii bazy (`Duplicate entry '99' for key 'spree_users.PRIMARY'`). `AdminUser` to celowo minimalna klasa (tylko `include Spree::UserRoles`, tabela `spree_users`) — nie ma akcesora `password` (ten żyje w `Spree::LegacyUser` przez `attr_accessor`). Pierwsze podejścia błędnie dodały `password: 'password'`, co dawało `ActiveModel::UnknownAttributeError: unknown attribute 'password'`. Końcowa poprawka: `AdminUser.create!(email: "admin-#{SecureRandom.hex(8)}@example.com")` — bez hardcoded ID (baza auto-inkrementuje), bez nieistniejącego pola `password`, z gwarantowanie unikalnym emailem. `spree_users` nie ma kolumn NOT NULL poza polami z defaultami, więc sam email wystarcza.
3. **Flaky test w user_methods_spec.rb** (`.search` case-insensitive): plik ma na poziomie `describe` eager fixture `let!(:another_user) { create(:user) }` z losowym emailem/nazwą (FFaker), który trafia do przestrzeni wyszukiwania KAŻDEGO przykładu. Gdy losowa wartość zawierała szukaną frazę (np. email `nelle_hills@smith.info` przy `search('SMITH')`), wynik miał dodatkowy wiersz i asercja `eq([mixed])` failowała — tylko na runach, gdzie los się zderzył (MySQL trafił, PostgreSQL nie). Poprawka: `before { another_user.destroy }` w bloku `.search`, żeby przestrzeń wyszukiwania zawierała wyłącznie deklarowane w bloku fixture'y. Deterministyczne niezależnie od losowych danych.
4. **Zawieszony Dashboard E2E (2,5h) — regresja z F21 frontend**: trzy nowe pliki tras (`settings/shipping-methods.tsx`, `tax-rates.tsx`, `zones.tsx`) miały `createFileRoute('...' as any)`. Rzutowanie `as any` (dodane, żeby ominąć błąd TS wynikający z braku tras w `routeTree.gen.ts`) sprawia, że argument nie jest literałem stringa, więc generator TanStack Router **wywala się** przy transformacji tych plików (`expected route id to be a string literal`). Efekt: dev-server Vite nie generuje drzewa tras → panel się nie ładuje → wszystkie 153 testy E2E timeoutują (dot-reporter pokazywał `××T××T…` przez 2,5h, aż concurrency anulował run). Poprawka: usunięto `as any` z trzech plików i przegenerowano `routeTree.gen.ts` (dodane 3 trasy, diff czysto addytywny). `as any` był hackiem obchodzącym objaw zamiast przyczyny — właściwie trasy muszą być w wygenerowanym drzewie. **Uwaga:** to naprawiło realny błąd builda (`vite build`/typecheck), ale NIE było przyczyną zawieszki E2E — patrz #6.
5. **Rate limiting (F16) w środowisku testowym** — `Rack::Attack.enabled = false if Rails.env.test?` w initializerze. Podejrzewane jako przyczyna zawieszki E2E, ostatecznie **nie było** (patrz #6), ale zmiana jest słuszna i nieszkodliwa: rate limiting to zabezpieczenie produkcyjne, w teście nie ma prawa dławić suite (żaden spec nie asertuje throttlingu). Zweryfikowane w źródle gemu: `return @app.call(env) if !enabled` → pełny pass-through.
6. **Prawdziwa przyczyna zawieszki E2E (3,5h) — polski locale vs angielskie selektory**: E2E był czerwony **także na `main`** (nie regresja PR #25), złamany przez commit `30d2455 "…Polish language"`, który ustawił domyślny język panelu na polski (`DEFAULT_ADMIN_LOCALE = 'pl'` w `dashboard-core/src/lib/i18n.ts`, `lng: readStoredLocale()`). Świeży browser w E2E nie ma zapisanego języka → panel startuje po polsku → label to `E-mail`, tytuł `Witaj ponownie`. Selektory specków są angielskie: `getByLabel(/email/i)` NIE trafia w `E-mail` (myślnik rozbija podłańcuch `email`), `getByText(/welcome back/i)` NIE trafia w `Witaj ponownie`. Efekt: helper `login()` timeoutuje 30s na każdym ze 135 testów × 3 próby retry = ~3,5h czystych timeoutów. Diagnoza z realnego logu completed-failure (nie z domysłów): wszystkie faile na `waiting for getByLabel(/email/i)` w `helpers.ts:74`. Poprawka (zero zmian w 135 speckach): global-setup zapisuje plik `storageState` z `localStorage['spree-admin-locale'] = 'en'` dla origin Vite, a `playwright.config.ts` wskazuje go w `use.storageState` — panel startuje po angielsku dla każdego kontekstu. Klucz bez auto-markera liczy się jako „genuine choice", więc przetrwa login i strony authenticated (reconcile robi no-op: `if (stored != null && auto == null) return`). Dodatkowo `timeout-minutes: 30` na jobie `dashboard-e2e` w `packages.yml` — przyszła zawieszka pada po ~30 min zamiast po 6h (domyślny limit GitHuba).

### P3 — historyczna siatka bezpieczeństwa (zakres podniesiony przez audyty)

**F9. Testy e2e łańcucha rynek → waluta → publikacja → cache** — oba repo — `[otwarte; scenariusz zachowany, ale krytyczne E2E są teraz B1/B2/C6/C8]`
Minimalny pakiet: (1) produkt aktywny + publikacja + cena PLN → widoczny w Store API; (2) usunięcie publikacji/ceny → admin pokazuje "niegotowy" (F3), nie cichy sukces; (3) `24,99`/`24.99` → w bazie zawsze `24.99` (F2); (4) edycja ceny → webhook → storefront pokazuje nową wartość bez TTL (F4); (5) zmiana domyślnego locale/currency rynku nie ukrywa produktów bez jawnego komunikatu.
_Zamknięte gdy:_ te scenariusze przechodzą w CI przed merge do main.

**F25. Wielosklepowość — panel admina zarządza wieloma sklepami (Faza 1)** — `sklepik` + `sklepikFront` — `[zamknięte 2026-07-13, backendowy test suite uruchomiony i zielony]`
Nowa inicjatywa właściciela (2026-07-12), niezależna od Kakao MVP: docelowo właściciel ma zakładać i przełączać się między kilkoma sklepami/markami z jednego panelu, z architekturą przygotowaną pod przyszły rozrost do samoobsługowego zakładania sklepów przez zewnętrznych użytkowników (SaaS). Pełny plan, fazowanie i decyzje projektowe: [`docs/plans/multi-store-support.md`](plans/multi-store-support.md).

Zaimplementowane: `Admin::BaseController` rozwiązuje `current_store` z nagłówka `X-Spree-Store-Id` (już wysyłanego przez `admin-sdk`) przez wypełnienie ivara przed pierwszym odczytem — nie przez nadpisanie metody, żeby nie wyłączyć istniejącego stubu `current_store` w testach (`spree/api/lib/spree/api/testing_support/v3/base.rb`); brak/zła wartość nagłówka → 404, nie cichy fallback. Nowy `Admin::StoresController` (`GET`/`POST /api/v3/admin/stores`) listuje sklepy usera i tworzy nowe — tworzenie wymaga roli `admin` na choć jednym istniejącym sklepie (`Spree::AdminUserMethods#admin_of_any_store?`, świadomo zaprojektowane pod przyszłą Fazę 3 self-service), automatycznie przypisuje twórcę jako admina nowego sklepu (`Store#add_user`, istniejąca metoda). **Zero migracji bazy** — `RoleUser`/role-per-store już istniało. Panel: `@spree/admin-sdk` ma nowy zasób `client.stores.{list,create}`, `StoreSwitcher` (dashboard-core) pokazuje realną listę sklepów usera + link "Nowy sklep", nowa strona `/$storeId/new-store` (formularz RHF+Zod), strona powitalna (`_authenticated/index.tsx`) ląduje na pierwszym sklepie z `stores.list()` zamiast na host-based default. Storefront (`sklepikFront`) bez zmian w tej fazie — nowy sklep to nadal osobny deployment Vercel (patrz `sklepikFront/docs/technical-debt.md`).

_Sesja 2026-07-12:_ `pnpm build`/`typecheck`/`lint` zielone dla `admin-sdk`, `dashboard-core`, `dashboard`; `pnpm --filter @spree/admin-sdk test` — 221/221. RSpec napisane, ale nieuruchomione lokalnie (brak zbudowanego `spree:test_app`/bazy w tamtej sesji) — zmergowane do `main` bez uruchomienia.

_Sesja 2026-07-13 — weryfikacja po merge, znaleziony i naprawiony krytyczny bug:_ po zmergowaniu CI (`push` na `main`) faktycznie odpalił pełny RSpec i **poczerwieniał** — zbudowano lokalne środowisko (Postgres + `bundle install` + `rake test_app`) żeby to zbadać zamiast zgadywać. Znaleziono trzy nawarstwione przyczyny:
1. `stores_spec.rb` deklarował `security [api_key: [], bearer_auth: []]`, ale `Admin::StoresController` jest JWT-only (`skip_before_action :authenticate_admin!`) i nie obsługuje ścieżki klucza API — rswag auto-generował wymagany nagłówek `x-spree-api-key`, którego spec nigdy nie definiował → `NoMethodError` w 5/5 testów. Naprawa: `security [bearer_auth: []]` (zgodne z rzeczywistym zachowaniem kontrolera).
2. **Prawdziwy bug produkcyjny:** `store_controller_spec.rb`'s `include_context 'API v3 Admin authenticated'` był zadeklarowany na najwyższym poziomie `describe`, więc jego `before`-hook (`allow_any_instance_of(...).to receive(:current_store)`) stubował `current_store` globalnie — również w bloku `'multi-store resolution via X-Spree-Store-Id'`, mimo komentarza mówiącego, że ten blok świadomie tego unika. Po przeniesieniu `include_context` do właściwego zasięgu ujawnił się **realny bug**: `Spree::RoleUser#store` (kolumna używana przez `require_store_membership!` do autoryzacji) domyślnie ustawia się na `Spree::Current.store`, nigdy na `resource`, nawet gdy `resource` samo jest `Store`em. Efekt: `store.add_user(current_user)` po utworzeniu nowego sklepu wiązał rolę admina z sklepem *bieżącym* w danym żądaniu, nie z nowo utworzonym — **admin dostawał 403 przy próbie wejścia do własnego, dopiero co założonego sklepu**. Zweryfikowane empirycznie przez `rails runner` na produkcyjnej ścieżce `Store#add_user` (z kontrolą negatywną potwierdzającą bug bez poprawki). Naprawa: `Spree::RoleUser#ensure_store` nadpisuje `SingleStoreResource#ensure_store` — gdy `resource.is_a?(Spree::Store)`, store = resource.
3. Dwa testy (`store_controller_spec.rb`, `admin_user_methods_spec.rb`) używały `create(:admin_user, :without_admin_role)` + `add_role('admin', ...)`, ale trait `:without_admin_role` pomija efekt uboczny fabryki tworzący rolę `'admin'` w DB — `add_role` był cichym no-opem (`Spree::Role.find_by(name: 'admin')` → `nil`). Naprawa: `Spree::Role.default_admin_role` przed `add_role` w obu specach.

Dodatkowo: `stores_spec.rb`'s "201 store created" wymagał fixture'a strefy wysyłkowej dla `'US'` — `Spree::Stores::Markets#ensure_default_market` (istniejący, zamierzony wymóg rdzenia, potwierdzony przez `spree/core/spec/models/spree/store_spec.rb`) wymaga, żeby kraj miał już pokrycie shipping zone gdziekolwiek w systemie, zanim może powstać dla niego market. W produkcji to nieproblematyczne (istniejący domyślny sklep ma już skonfigurowaną wysyłkę, a zapytanie o pokrycie jest globalne, nie per-sklep). Od 2026-07-13 akcja używa `save!`, więc błąd zagnieżdżonego `Market`/`MarketCountry` trafia do wspólnego handlera `ActiveRecord::RecordInvalid` i zwraca jego szczegóły zamiast pustych `store.errors`.

_Zweryfikowane lokalnie (Postgres, `spree/api/spec/dummy`, ta sesja):_ `store_controller_spec.rb` + `stores_spec.rb` — 28/28; `role_user_spec.rb` + `store_spec.rb` + `admin_user_methods_spec.rb` + `market_spec.rb` + `market_country_spec.rb` — 198/198; `ability_spec.rb` + `invitation_spec.rb` + `user_roles_spec.rb` + `user_management_spec.rb` (regresja wokół `RoleUser`) — 107/107. **Nadal do zrobienia:** `rake typelizer:generate`/`rswag:specs:swaggerize` (kroki 3-5 pipeline'u typów, `CLAUDE.md`) — nowy endpoint `/api/v3/admin/stores` jeszcze nie trafił do `docs/api-reference/admin.yaml`; pełny `bundle exec rspec` (cały pakiet `core`+`api`, nie tylko dotknięte pliki) przed kolejnym mergem do main.

_Sesja 2026-07-13 — atomowy bootstrap sklepu:_ `Admin::StoresController#create` zapisuje teraz `Store` i przypisuje twórcę przez `Store#add_user` w jednej transakcji. `save!` kieruje walidacje samego sklepu oraz zagnieżdżonego bootstrapu do wspólnego handlera błędów API. Dodany request spec wymusza błąd przypisania roli i sprawdza, że liczba sklepów się nie zmienia oraz nie pozostaje rekord o żądanym URL.

Dynamiczne rozpoznawanie sklepu po domenie w storefroncie to Faza 2, samoobsługa zewnętrznych użytkowników (płatność, automatyczny provisioning) to Faza 3 — obie świadomie odłożone, opisane jako Open Questions w planie.

**Decyzja 2026-07-13 (poza aktywną roadmapą):** model docelowy dla Fazy 3 (niezależne sklepy) to "Store Factory" — repozytorium + projekt Vercel per sklep, nie jeden wspólny storefront z warstwą kompozycji danych. Pełny plan: [`docs/plans/store-factory.md`](plans/store-factory.md). Konta klientów: **osobne per sklep** (decyzja właściciela) — osobny plan [`docs/plans/per-store-customer-accounts.md`](plans/per-store-customer-accounts.md).

**Etap 0 Store Factory — WDROŻONY NA PRODUKCJĘ + UTWARDZENIE GOTOWE DO PUBLIKACJI (2026-07-13):** produkcja ma host resolution, cache per sklep, atomowy `StoresController#create`, backendowy EUR sync i naprawione role sklepu. Bieżący zestaw dodaje globalne rozwiązanie aktywnego publishable API key → store przed autoryzacją, odrzuca sprzeczny host/`X-Spree-Store-Id`, rozszerza tenantowy kontekst cache i naprawia pusty 422. Lokalna regresja: 50 przykładów RSpec, 0 failures. **Pozostaje:** pełny integracyjny scenariusz dwóch realnych tenantów obejmujący katalog, koszyk, klientów i zamówienia oraz `rswag:specs:swaggerize` dla `/admin/stores`.

**Etap 1 Store Factory — WDROŻONY + NAPRAWIONY (2026-07-13):** typy kontraktów są eksportowane z `@spree/sdk`; `@sklepik/test-contracts` jest w frozen lockfile i używa rzeczywistego API SDK. Typecheck, build i 5/5 testów jednostkowych przechodzą. Następny krok: Etap 2 — ręczny drugi sklep z realnym uruchomieniem kontraktów, osobnym repo/Vercel/domeną i wykonanym rollbackiem. Stripe, strony prawne i checkout E2E nadal blokują start sprzedaży, nie techniczne przygotowanie pilota.

**Publiczny signup Store Factory — GOTOWY DO WDROŻENIA ZA FLAGĄ (2026-07-13):** panel ma publiczną trasę `/signup`, SDK metodę `auth.signup`, a backend publiczny `POST /api/v3/admin/auth/signup`. Jedna transakcja tworzy administratora, sklep z tymczasowym adresem `<code>.vercel.app` i provisioning run; job po gotowym deploymencie zapisuje prawdziwy host. `STORE_SIGNUP_ENABLED=false` jest bezpiecznym ustawieniem domyślnym. Zweryfikowane lokalnie: 4/4 przykłady RSpec, test kontraktu SDK i typecheck dashboardu. Do zamknięcia przed szerokim ruchem: realny E2E GitHub→Vercel, weryfikacja e-mail/CAPTCHA oraz decyzja o płatności/limitach planu.

## Faza 2 — Store Factory: od rejestracji do bezpiecznej publikacji

**F26. Edytor storefrontu MVP** — oba repo — `[MVP wdrożone 2026-07-14; revisions/publish safety/preview/E2E otwarte w D2]`

Backend przechowuje osobne wersje draft/published walidowanego dokumentu strony, chroni zapis optimistic lockingiem i udostępnia publicznie wyłącznie snapshot. Panel właściciela edytuje, porządkuje i publikuje sekcje hero/product grid z live preview. Wspólny storefront renderuje dokument, a przed pierwszą publikacją zachowuje dotychczasowy widok kakao. Następne sekcje, preview URL, motywy i generowanie AI mają rozszerzać ten sam wersjonowany kontrakt — bez dowolnego HTML/JS.

**F27. Launch readiness i dokumenty prawne** — `sklepik` — `[pierwsza wersja wdrożona 2026-07-14; semantyczna readiness i dowody prawne otwarte w C6/C8]`

Nowy sklep zaczyna jako `draft`. Dashboard pokazuje checklistę danych firmy, produktu, płatności, wysyłki, dokumentów i opublikowanej strony. Admin ma edytor polityk z jawnym zastrzeżeniem, że nie są poradą prawną. Jawne uruchomienie przełącza sklep na `live` tylko po spełnieniu kontroli; backend blokuje tworzenie płatności, sesji i finalizację checkoutu wcześniej. Stare sklepy bez wartości kolumny pozostają aktywne.

**F28. Pierwsze płatne wdrożenia** — produkt + operacje — `[otwarte]`

- nie uruchamiać prawdziwych klientów/płatności przed zamknięciem Etapów A–C i raportu nadrzędnego; rozmowy, konfiguracja demo i sandbox pilots mogą trwać bez realnych PII/capture;
- wybrać pierwszy segment na podstawie `docs/research/`;
- przeprowadzić 20 rozmów bez udawania wyników i zdobyć 5 płatnych pilotów;
- zmierzyć czas pracy człowieka, aktywację i pierwsze prawdziwe zamówienie;
- skonfigurować płatności, prawdziwe treści, wysyłkę i domenę per pilot;
- zamieniać powtarzalne działania operatora w funkcje produktu.

**F29. Fundament Sklepika i uniezależnienie od Spree** — oba repo — `[otwarte; realizowane według Etapu E programu poaudytowego]`

Celem nie jest kosmetyczny globalny rename, tylko doprowadzenie do sytuacji, w której panel, storefronty, agenci i nowe moduły posługują się wyłącznie językiem domenowym Sklepika. Spree pozostaje przejściowo silnikiem commerce za kontrolowaną granicą; dziś ta granica jeszcze nie istnieje w pełni. Audyt 03 policzył m.in. 82 bezpośrednie importy `@spree/sdk` w źródłach storefrontu, 12 nazw publicznych nagłówków oraz 131 tabel `spree_*`. Program obejmuje:

- zamrożenie audytowanego commita po wdrożeniu F26–F27;
- klasyfikację każdego modułu i pliku jako `KEEP`, `HARDEN`, `REFACTOR`, `REPLACE`, `REMOVE`, `ISOLATE` albo `UNKNOWN`;
- pełny audyt ścieżek pieniędzy, tenant isolation, auth, callbacków/jobów, API, migracji, infrastruktury, zależności i martwego legacy;
- własne stabilne kontrakty Sklepika oraz adaptery odcinające dashboard i storefront od nazw, typów i szczegółów silnika;
- usunięcie nazwy Spree z produktu, publicznych kontraktów, nowych plików, nazw własnych zmiennych/cookies/webhooków i dokumentacji operacyjnej, z okresami kompatybilności tam, gdzie działają wdrożone sklepy;
- stopniowe zastępowanie lub izolowanie namespace'ów, tabel i komponentów silnika dopiero z testami migracji, rollbacku i zgodności danych;
- testy dynamiczne: pełne suite, E2E wielu tenantów, kontrakty, property/fuzz, mutation, obciążenie, chaos oraz odtworzenie backupu.

Warunek zakończenia: nazwa i model Spree nie przeciekają poza adapter silnika, żadna nowa funkcja Sklepika nie zależy bezpośrednio od jego wewnętrznych namespace'ów, a każda pozostawiona część legacy ma właściciela, uzasadnienie, testy i plan dalszego losu. Literalne zero wystąpień w kodzie zależności nie jest ważniejsze od bezpieczeństwa danych i zamówień.

## Faza 3 — assisted self-service i partnerzy

Import katalogów, agent gotowości/next-best-action, więcej sekcji i motywów, analityka lejka, kontrolowane aktualizacje floty, role partnerów i handoff. Funkcje AI pozostają poza krytyczną ścieżką pieniędzy i wykonują działania z zatwierdzeniem człowieka.

---

## Zamknięte

- **F0. Wielkie porządki repo i dokumentacji** — oba repo — `[zamknięte 2026-07-06]`
  Usunięta upstreamowa dokumentacja Spree (~1100 plików), README-y przepisane pod projekt, jedno źródło prawdy governance (`kierunek-projektu.md`), nowy komplet żywych dokumentów (`architektura`, `stan-projektu`, `roadmap`), protokół aktualizacji dokumentacji przez agentów w CLAUDE.md obu repo. Kierunek "Vercel Commerce" formalnie odrzucony.
