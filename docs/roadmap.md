# Roadmapa

Kolejność prac dla całego systemu (oba repozytoria). Agent bierze zadania od góry: P0 przed P1, P1 przed P2. Zadania w tej samej grupie mogą iść równolegle, jeśli dotyczą różnych repo/plików. Po zamknięciu zadania: zaktualizuj jego status tutaj i stan w [`stan-projektu.md`](stan-projektu.md).

Jeśli któryś opis okaże się nieaktualny w chwili pracy — sprawdź kod, nie ufaj samemu opisowi.

**Świadomie odłożone (decyzja właściciela, nie techniczna):** konfiguracja Stripe/płatności, strony prawne (regulamin, polityka prywatności, odstąpienie) i Admin API/panel dla shipping methods/zones/tax rates. Wszystkie trzy są blokerami sprzedażowymi z audytu `docs/audits/2026-07-08-system-wide-production-readiness-audit.md`, ale wymagają zewnętrznych kont/treści albo osobnej decyzji projektowej zanim zaczniemy kodować — patrz F21 w Fazie 1 i sekcja Faza 2. Cała reszta znalezisk z audytów F12/F13/system-wide jest w zakresie poniżej.

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

**F19. Drobne luki katalogu i pieniędzy klienta** — `sklepik` (`spree/api` + panel) — `[częściowo zamknięte 2026-07-10]`
Zbiór mniejszych znalezisk z F13: (1) ✅ CRUD dla `store_credit_categories` zamiast tylko read-only — API kompletna (routes + permitted_params); (2)-(5) UI pola (produktu, wariantu, opcji, kategorii) — pending, wymaga panel forms. Następne: dodać UI inputy dla pól lub czekaj na dedykowaną sesję UI.

**F20. Hardening pipeline'u media/R2** — `sklepik` — `[otwarte, bez pre-generowania w tle]`
Znalezisko systemowego audytu (SYS-018): limity rozmiaru/typu uploadu, cleanup unattached Active Storage blobs, przegląd cache headers/R2 bucket policy. Sidekiq worker jest już dostępny (F7, zamknięte 2026-07-09) — pre-generowanie wariantów zaraz po uploadzie nie jest już blokowane brakiem workera, tylko brakiem samego joba; do zaimplementowania w ramach tego zadania.

**F21. Admin API/panel dla shipping methods/zones/tax rates** — `sklepik` — `[zamknięte 2026-07-10]`
Money-critical luka z F13 prompt 2 (SYS-002): brak jakiejkolwiek panelowej/API konfiguracji metod wysyłki, kategorii wysyłki, stref i stawek podatkowych. Backend (hooki, kontrolery, serializery) ukończony w sesji wcześniejszej (F21 część 1). Frontend ukończony 2026-07-10: dwie nowe strony `settings/shipping-methods.tsx` i `settings/tax-rates.tsx` i `settings/zones.tsx` z pełną implementacją ResourceTable, create/edit sheets, react-hook-form, mapSpreeErrorsToForm error handling, dashboard-ui komponenty, proper loading/disabled states. Każda strona ma dedykowany hook (use-shipping-methods, use-tax-rates, use-zones) z CRUD operacjami.

**F22. Pełny lifecycle zwrotów/reimbursements** — `sklepik` — `[otwarte, świadomie odłożone]`
Znalezisko F13 prompt 4: działają tylko proste order-level refundy; brak Admin API/UI dla `reimbursement_types`, `refund_reasons`, `return_authorization_reasons`, `customer_returns`. **Świadomie odłożone** — właściciel zdecydował, że prosty zwrot na razie wystarcza.

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

### P3 — siatka bezpieczeństwa

**F9. Testy e2e łańcucha rynek → waluta → publikacja → cache** — oba repo — `[otwarte]`
Minimalny pakiet: (1) produkt aktywny + publikacja + cena PLN → widoczny w Store API; (2) usunięcie publikacji/ceny → admin pokazuje "niegotowy" (F3), nie cichy sukces; (3) `24,99`/`24.99` → w bazie zawsze `24.99` (F2); (4) edycja ceny → webhook → storefront pokazuje nową wartość bez TTL (F4); (5) zmiana domyślnego locale/currency rynku nie ukrywa produktów bez jawnego komunikatu.
_Zamknięte gdy:_ te scenariusze przechodzą w CI przed merge do main.

## Faza 2 — Kakao MVP

Start dopiero po zamknięciu P0 i P1 z Fazy 1.

Zakres:

- Realne produkty kakao (na start ~5: kakao ceremonialne klasyczne i intensywne, zestaw degustacyjny, kakao z przyprawami, akcesoria) — mogą być fikcyjne, ale mają wyglądać realistycznie.
- Kategorie produktów.
- Branding premium storefrontu (strona główna, strona produktu) — ton marki opisany w `sklepikFront/docs/kierunek-frontu.md`.
- Strony informacyjne: O nas, Dostawa, Zwroty, Kontakt.
- Strony prawne: regulamin, polityka prywatności, prawo odstąpienia.
- Konfiguracja płatności (Stripe przez `spree_stripe`).
- Konfiguracja wysyłki/stref/stawek podatkowych w Admin API/panelu (F21).
- Własna domena (storefront + admin + backend; docelowo admin pod `/admin/*` tej samej domeny przez rewrite Vercela).
- Weryfikacja pełnego flow zakupowego end-to-end.

Poza zakresem MVP (świadomie później): gry, VOD, subskrypcje, program lojalnościowy, AI, rozbudowany CMS.

## Faza 3 — moduły premium

Storytelling, edukacja produktowa, quizy, subskrypcje, lojalność, integracje AI — jako osobne moduły nad stabilnym corem, nigdy w krytycznej ścieżce checkoutu.

---

## Zamknięte

- **F0. Wielkie porządki repo i dokumentacji** — oba repo — `[zamknięte 2026-07-06]`
  Usunięta upstreamowa dokumentacja Spree (~1100 plików), README-y przepisane pod projekt, jedno źródło prawdy governance (`kierunek-projektu.md`), nowy komplet żywych dokumentów (`architektura`, `stan-projektu`, `roadmap`), protokół aktualizacji dokumentacji przez agentów w CLAUDE.md obu repo. Kierunek "Vercel Commerce" formalnie odrzucony.
