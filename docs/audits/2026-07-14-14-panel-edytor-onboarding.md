# Audyt 14: panel, edytor i onboarding

**Data:** 2026-07-14
**Baseline:** `sklepik` `9a4f693147`, `sklepikFront` `0f83b94`
**Charakter:** statyczny audyt pełnej ścieżki właściciela; bez zmian kodu, deployu i produkcji
**Werdykt:** fundament nadaje się do pilotów wspieranych przez operatora, ale nie do szerokiego self-service. Signup, tenant, panel, katalog, draft/publish i launch gate istnieją. Właściciel nie może jednak odzyskać konta ani poprawnie skonfigurować dostawy i podatku wyłącznie z panelu. Krytyczna ścieżka ownera nie ma E2E, a edytor nie ma ochrony niezapisanej pracy, historii ani rollbacku.

## Zakres i metoda

Prześledzono `signup → provisioning → login → wybór sklepu → produkty/media → ustawienia → dostawa/podatki/płatności/prawo → edytor → readiness → launch`. Sprawdzono dashboard, dashboard-core/UI, Admin API, modele/serwisy Rails, admin SDK, testy oraz efekt dokumentu w `sklepikFront`. Kod istniejący odróżniono od runtime-verified. Priorytety i status dowodu są zgodne z `docs/audits/README.md`.

## Mapa flow

| Etap | Stan |
|---|---|
| signup | istnieje, transakcyjny; produkcyjny smoke historycznie potwierdzony |
| provisioning | job + polling; brak kompletnego retry/cleanup E2E |
| login | działa i ma Playwright E2E |
| potwierdzenie/recovery ownera | brak |
| wybór sklepów | realna lista sklepów usera; dobry fundament |
| produkty/media | rozbudowane CRUD i szeroka suite E2E; najmocniejszy fragment |
| dostawa/podatki | ekrany istnieją, ale nie konfigurują poprawnie modelu |
| płatności | generyczny formularz, brak adaptera/Connect |
| prawo | cztery seedowane dokumenty i edycja; brak owner E2E |
| edytor | MVP hero/product grid, draft/publish, lokalny preview |
| launch | sześć kontroli i backendowy gate; brak pełnego owner E2E |

## Znaleziska

### PANEL-001 — P1 — brak potwierdzenia i odzyskiwania konta ownera

**Dowód:** fakt. Signup od razu ustanawia sesję (`packages/dashboard/src/routes/signup.tsx:25-63`; `dashboard-core/src/providers/auth-provider.tsx:139-155`) i jest opisany jako prototyp bez weryfikacji e-mail (`auth-provider.tsx:16-20`; `schemas/auth.ts:45`). Login nie ma „nie pamiętam hasła” (`routes/login.tsx:71-117`). Customer password reset istnieje, odpowiednika admin/owner i tras panelu nie znaleziono. Backend tworzy user/store/run bez potwierdzenia (`signups_controller.rb:20-65`).

**Wpływ:** literówka lub utrata hasła może trwale odciąć mikroprzedsiębiorcę; ręczny recovery nie skaluje i zwiększa ryzyko socjotechniki.

**Naprawa/test:** neutralny wobec enumeracji reset, token TTL/single-use, potwierdzenie e-mail przed launch/pieniędzmi. Playwright: signup→confirm→logout→reset→login; stare tokeny odrzucone.

### PANEL-002 — P1 — dostawy nie da się poprawnie skonfigurować z panelu

**Dowód:** fakt. Readiness kieruje do shipping methods (`store-readiness-card.tsx:18-25`), ale formularz wysyła tylko `name/display_on` (`shipping-methods.tsx:131-220,229-330`). API obsługuje kalkulator, kategorie i strefy (`shipping_methods_controller.rb:16-23`), a model wymaga kategorii (`shipping_method.rb:36-40,142-144`). UI stref nie dodaje krajów/regionów (`zones.tsx:121-210,218-323`). Edit wysyła wartości `"1"/"2"` (`shipping-methods.tsx:302-307`), model rozpoznaje `both/front_end/back_end` (`shipping_method.rb:135-140`).

**Wpływ:** właściciel fizycznego sklepu nie przejdzie shipping readiness; create może dać 422, a edit ukryć metodę.

**Naprawa/test:** prowadzony flow „gdzie i za ile wysyłasz?” atomowo tworzący strefę z członkami, kategorię, metodę, kalkulator i cenę. E2E dla polskiego adresu zmienia readiness na true i zwraca właściwą stawkę.

### PANEL-003 — P1 — ekran podatku ma błędne jednostki i brak strefy

**Dowód:** fakt, runtime naliczenia niewykonany. UI podpisuje `amount` jako procent, ale wysyła `Number(values.amount)` bez `/100` (`tax-rates.tsx:144-154,187-196`). Modelowa metoda procentowa dzieli przez 100, API przyjmuje surowy ułamek (`tax_rate.rb:33-45`; `tax_rates_controller.rb:15-21`). UI nie wysyła `zone_id`, choć dopasowanie odbywa się po strefie (`tax_rate.rb:28-31,50-67`).

**Wpływ:** reguła może nie naliczać VAT albo po dopięciu strefy naliczyć wielokrotność oczekiwanej stawki.

**Naprawa/test:** jawny kontrakt procent/ułamek, wymagany zone, Zod. Wpisanie 23 round-tripuje jako 23%, backend ma 0.23 i koszyk nalicza dokładnie 23%; testy 0/5/8/23%.

### PANEL-004 — P1 — brak automatycznego E2E pełnej ścieżki ownera

**Dowód:** fakt. Playwright ma login i rozbudowany katalog, ale nie signup, provisioning, editor, legal/readiness ani launch (`e2e/auth.spec.ts:1-36`; lista `e2e/*.spec.ts`). `stan-projektu.md` jawnie potwierdza tę lukę. Specs API nie składają systemu w całość.

**Wpływ:** regresja cookie/proxy/tenant/provisioning/SDK może przejść CI mimo niedziałającej najważniejszej obietnicy produktu.

**Naprawa/test:** staging z fake GitHub/Vercel/mail/PSP. Jeden E2E: owner+tenant→provision→relogin→produkt/media→shipping/tax/payment sandbox→prawo→publish→launch→storefront→sandbox order.

### PANEL-005 — P1 — publish może opublikować niewidzianą wersję; brak historii/rollbacku

**Dowód:** fakt; dwie sesje wymagają E2E. Save wysyła `lock_version` i backend daje 409 (`editor.tsx:147-165`; `storefront_pages_controller.rb:13-27`). Publish nie przyjmuje oczekiwanej wersji, tylko kopiuje aktualny draft pod lockiem (`controller:29-32`; `storefront_page.rb:23-31`). Model ma wyłącznie aktualny draft/published snapshot.

**Wpływ:** stara, czysta sesja A może opublikować draft zapisany później przez B. Nie ma jednego kliknięcia powrotu do dobrej wersji; to szczególnie ryzykowne z partnerami/AI.

**Naprawa/test:** immutable revisions, publish z expected revision, diff/aktor, rollback jako nowa rewizja. Dwa browser contexts dowodzą, że stale sesja nie zapisze ani nie opublikuje niewidzianej wersji.

### PANEL-006 — P2 — edytor bez ostrzeżenia gubi niezapisane zmiany

**Dowód:** fakt. Edytor zapisuje jawnie/skrótem (`editor.tsx:147-187`), ale nie używa istniejącego dirty guard (`dashboard-ui/src/spree/form-actions.tsx:110-139`). Brak autosave/router blocker/beforeunload w trasie.

**Wpływ:** sidebar, store switch lub reload porzuca pracę.

**Naprawa/test:** guard nawigacji, docelowo debounce autosave ze stanami saved/offline/error i conflict-safe retry. Test reload/offline/nawigacja bez utraty potwierdzonego draftu.

### PANEL-007 — P1 — provisioning nie ma kompletnego recovery

**Dowód:** fakt; częstość awarii nieweryfikowana. Status żyje w lokalnym state signup/new-store (`signup.tsx:25-38`; `new-store.tsx:52-86`), więc reload go usuwa. Komponent nie renderuje query error/retry, a failure oferuje tylko admin (`provisioning-status-card.tsx:33-94`). Backend retryuje przez nowy run, nie resume (`provision_store.rb:10-18`), lecz istniejący sklep nie ma UI retry/historii. UI pokazuje raw provider error.

**Wpływ:** chwilowy błąd GitHub/Vercel zostawia tenant bez storefrontu i bez samodzielnej naprawy.

**Naprawa/test:** trwała routowalna strona run + status na overview, klasy błędów/correlation ID, idempotent retry/cleanup i alert. Fake provider psuje każdy krok; reload zachowuje status, retry nie dubluje zasobów.

### PANEL-008 — P2 — readiness może wisieć i mierzy obecność, nie pełną gotowość

**Dowód:** fakt. Query error daje wieczny skeleton (`store-readiness-card.tsx:27-35`). Checki to support e-mail, dowolny published produkt, dowolna active payment method, coverage, dowolne 3 polityki i homepage (`readiness_check.rb:15-62`). Brak danych firmy/NIP, provider health/live mode, pełnego kompletu prawa, domeny/SSL, e-mail/test order. Po launch karta znika i brak pause (`card:37-39`). Powiązane: `MONEY-010`.

**Wpływ:** fałszywe „ready”, brak recovery i lifecycle po starcie.

**Naprawa/test:** ErrorState+retry, semantyczne health checks, snapshot+aktor, operacyjny `paused`. Każdy check ma positive/negative contract i kompletny deep link.

### PANEL-009 — P2 — preview nie odpowiada wiernie storefrontowi

**Dowód:** fakt. Panel renderuje własny markup i sześć atrap produktów (`editor.tsx:508-559`). Dokument ma background image/taxon/open-new-tab, ale UI nie oferuje uploadu tła, wyboru kategorii ani toggle (`editor.tsx:386-503`). Storefront używa taxon/open-new-tab, ignoruje background asset (`sklepikFront/src/components/home/StorefrontPageRenderer.tsx:20-66`; `HeroSection.tsx:1-64`). Brak prawdziwego draft preview URL.

**Wpływ:** owner publikuje, żeby naprawdę zobaczyć wynik.

**Naprawa/test:** wspólny renderer/tokens lub podpisany iframe draft preview, realne dane i breakpointy. Visual regression porównuje preview/public dla każdego section type; token draft wygasa i jest tenant-scoped.

### PANEL-010 — P2 — błędy sklepu/dashboardu są maskowane jako pustka/loading

**Dowód:** fakt. `StoreProvider` łapie każdy błąd i wystawia `store=null`, bez `error` (`store-provider.tsx:66-83`). Dashboard bez analytics stale pokazuje skeleton, nie error (`routes/.../$storeId/index.tsx:39-62`). Nieudana lista sklepów redirectuje do magicznego `default` (`routes/_authenticated/index.tsx:13-32`).

**Wpływ:** 403/404/500/offline wyglądają jak ładowanie; owner i support nie znają działania naprawczego.

**Naprawa/test:** typowane error states/global boundary z retry/correlation ID; browser tests 401/403/404/500/offline.

### PANEL-011 — P2 — martwe elementy nawigacji udają funkcje

**Dowód:** fakt. „View store” nie ma linku/handlera (`dashboard-core/src/components/store-switcher.tsx:96-99`). Nav rejestruje `/reports`, ale brak route (`src/nav/default.ts:91-97`). Login nadal linkuje „powered by Spree” (`routes/login.tsx:118-126`; także audyt 03).

**Wpływ:** no-op/404 obniżają zaufanie i utrudniają sprawdzenie publikacji.

**Naprawa/test:** usunąć/flagować niegotowe; view store używa zweryfikowanego HTTPS hosta tenanta. Crawler klika każdy widoczny nav item dla każdej roli, bez 404/no-op.

### PANEL-012 — P2 — UI ról jest niespójne mimo backendowej ochrony

**Dowód:** fakt; backend auth ocenia audyt 05. Sidebar filtruje `read` (`app-sidebar.tsx:28-39`), część tabel używa `<Can>`. Edytor jest widoczny po read Store, ale save/publish nie sprawdzają update (`nav/default.ts:58-65`; `editor.tsx:213-233`) i dopiero backend odrzuca.

**Wpływ:** nie jest to bypass, lecz mylący UX partner/staff.

**Naprawa/test:** centralne route/action capabilities i read-only state. Parametryzowany Playwright owner/manager/catalog/support.

### PANEL-013 — P2 — brak dowodu dostępności i mobile UX krytycznego flow

**Dowód:** część fakt, całość nieweryfikowana. Signup/login mają label/aria-invalid, ale błędy nie mają alert/describedby (`signup.tsx:73-123`; `login.tsx:78-108`). Zagnieżdżone pola edytora nie pokazują `FieldError/aria-invalid` mimo limitów Zod (`editor.tsx:386-503`; `schemas/storefront-page.ts:1-57`). Brak axe/keyboard/mobile tests signup/editor/readiness.

**Wpływ:** walidacja może zablokować zapis bez wskazania pola; ryzyko dla telefonu/klawiatury/czytnika.

**Naprawa/test:** accessible error summary/focus/live regions, axe CI i manual screen reader. Test 320/375/768/1440 oraz keyboard-only signup→launch.

### PANEL-014 — P2 — brak mierzenia lejka i pełnego audit trail

**Dowód:** fakt w flow. Nie znaleziono eventów signup→provisioned→product→ready→published→launched. Provisioning raportuje wyjątek, UI nie pokazuje correlation ID (`provision_store.rb:69-73`). Page ma tylko ostatnie `published_by`; launch ustawia status bez aktora/snapshotu (`storefront_page.rb:23-29`; `store_controller.rb:25-36`).

**Wpływ:** nie wiadomo, gdzie ownerzy odpadają; support/AI nie odtworzy decyzji.

**Naprawa/test:** typowane eventy bez PII, end-to-end correlation ID, immutable audit dla publish/launch/money/legal. Retry nie dubluje zdarzeń; trace spina request z jobem.

### PANEL-015 — P2 — dokument jest AI-ready, ale brak bezpiecznej warstwy wykonawczej

**Dowód:** fakt obecnego zakresu. Pozytyw: backend allowlistuje dwa section types, limity i linki, bez arbitrary HTML/JS (`storefront_page.rb:9-19,83-156`). Brakuje revision/diff/approval/audit/rollback i typed command API. Direct CRUD nie powinno stać się agentowym „może wszystko”.

**Wpływ:** czat dodany za wcześnie byłby nieaudytowalnym wykonawcą, szczególnie dla publikacji/podatku/prawa/płatności.

**Naprawa/test:** AI generuje plan typowanych komend; deterministyczne usługi sprawdzają tenant/role/preconditions; dry-run+diff; approval money/legal/publish; idempotency/rollback. Adversarial suite blokuje cross-tenant i akcje bez approval.

### PANEL-016 — P2 — płatności są panelem technicznym, nie onboardingiem sprzedawcy

**Dowód:** fakt; domenowy duplikat `MONEY-005`. UI pokazuje provider types i generic preferences, slot przewiduje OAuth/Connect (`payment-method-form.tsx:47-75,137-174`). Brak adaptera/Connect, capability status, test transaction i health.

**Wpływ:** „mydlarz” musi rozumieć klucze/webhooki albo czekać na operatora.

**Naprawa/test:** hosted onboarding Connect/PSP: jeden przycisk, KYC, status/actions/test/reconciliation; sandbox dwóch tenantów potwierdza rozdział kont/webhooków.

### PANEL-017 — P3 — prawne readiness nie jest semantyczne ani wersjonowane

**Dowód:** fakt; treść wymaga osobnego audytu prawnego. Store seeduje regulamin, prywatność, zwroty, wysyłkę (`store.rb:406-419`), panel ostrzega i edytuje (`settings/legal.tsx:33-113`). Gate wymaga dowolnych trzech treści (`readiness_check.rb:56-58`), bez wersji obowiązywania/snapshotu zgody i pełnych danych firmy.

**Wpływ:** „complete” może nie odpowiadać rynkowi; późniejsza zmiana zaciera dokument obowiązujący przy zamówieniu.

**Naprawa/test:** wymagane typy per rynek, revisions/effective_at i snapshot przy order. Brak każdego wymaganego typu blokuje launch; późniejsza edycja nie zmienia historii.

## Potwierdzone mocne strony

1. Atomowy signup danych user/store/run i enqueue po sukcesie.
2. Nowy sklep startuje jako draft i ma backendowy money gate.
3. Store switcher używa realnych sklepów usera; tenant/auth szerzej w audytach 04–05.
4. Katalog, media, ceny, stock, tłumaczenia i publikacja mają realną głębokość i wiele E2E.
5. Dojrzalsze formularze używają RHF+Zod i mapowania 422.
6. Draft nie wycieka przez Store API; publiczny jest tylko snapshot.
7. Save ma optimistic locking i 409 konfliktu.
8. Schemat layoutu bez HTML/JS jest dobrym fundamentem AI.
9. Storefront pobiera commerce z API, nie z dokumentu layoutu.

## Coverage i ograniczenia

| Obszar | Pokrycie | Pozostałe ryzyko |
|---|---|---|
| signup/auth | UI/provider/controller/specs | mail/recovery/abuse runtime |
| provisioning | run/job/service/polling | real GitHub/Vercel retry/cleanup |
| products/media | routing + istniejące E2E | suite nieuruchomiona tutaj |
| shipping/tax | UI/API/model | wykryte P1; brak cart runtime |
| payments | owner UI | adapter/Connect/live — audyt 07 |
| legal/readiness | UI/service/specs | owner E2E/audyt prawny |
| editor/storefront | UI/schema/API/model/renderer | visual/multi-session E2E |
| a11y/mobile | statycznie | axe/screen reader/devices |
| observability/AI | punkty emisji/model historii | runtime/adversarial tests |

- `pnpm` nie jest dostępny (`command not found`), więc próba test/build dashboardu nie rozpoczęła testów; to ograniczenie środowiska, nie czerwony wynik.
- Nie uruchamiano Rails specs ani dev/browser: backend/test DB nie były dostępne w bezpiecznym zakresie. Nie deployowano i nie mutowano produkcji.
- Produkcyjny smoke signup/storefront i ręczny test edytora to historyczny dowód z `stan-projektu.md`, nie powtórzony tutaj.
- Nie badano jakości prawnej, PCI/PSD2/księgowości ani badań użyteczności z realnymi sprzedawcami.

## Kolejność domknięcia

1. E2E świeżego ownera jako test chroniący flow (PANEL-004).
2. Confirm/reset ownera (PANEL-001).
3. Guided shipping i tax wraz z cart tests (PANEL-002/003).
4. Connect/PSP według audytu 07 i PANEL-016.
5. Revisions, expected-version publish, audit/rollback, potem autosave/guard (PANEL-005/006).
6. Trwały provisioning recovery i poprawne error states (PANEL-007/008/010).
7. Wspólny preview, a11y/mobile i usunięcie martwej nawigacji (PANEL-009/011/013).
8. Dopiero potem AI commands z approval, telemetry i audit trail (PANEL-014/015).

Flow jest domknięty dopiero, gdy świeży zewnętrzny użytkownik bez terminala i operatora przejdzie od zweryfikowanego konta do sandbox order, a zespół odtworzy każdy błąd i decyzję publish/launch.
