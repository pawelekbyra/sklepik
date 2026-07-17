# System kompozycji storefrontu — Fabryka Sklepów (model docelowy)

**Status:** Active — model docelowy, decyzja właściciela z 2026-07-17 (patrz nota niżej). Zastępuje `store-factory.md` jako cel Fazy 3.
**Target:** `sklepikFront` (ewoluuje w współdzielony, wielosklepowy storefront + panel `/admin`), `sklepik` (backend, źródło danych konfiguracji), `edytor-sklepu` (dostarcza silnik edytora jako pakiety `@sklepik/*`)
**Depends on:** [`multi-store-support.md`](multi-store-support.md) — Faza 1 (zaimplementowana), rozszerza/precyzuje Fazę 2 tamtego planu
**Supersedes:** [`store-factory.md`](store-factory.md) — patrz nota niżej i nota w tamtym dokumencie
**Author:** właściciel + agent (sesja 2026-07-13, zmiana decyzji 2026-07-17 po dziewięciu niezależnych research-passach)
**Last updated:** 2026-07-17

## Nota o zmianie decyzji (2026-07-17)

Ten dokument pierwotnie proponował dokładnie ten model (jeden storefront, layout jako dane), został **odwrócony 2026-07-13** na rzecz `store-factory.md` (repo + projekt Vercel per sklep), a teraz **właściciel odwrócił tę decyzję z powrotem, świadomie i definitywnie** ("chcę z tego pomysłu [repo per sklep] zrezygnować, to była zła decyzja i chcę ją uciąć"). Różnica względem 2026-07-13: tym razem decyzja jest poparta dziewięcioma niezależnymi research-passami (branżowe wzorce multi-tenant, page builderów, fleet-update, auth, CI/CD, headless commerce, personalizacji i bezpiecznego custom code — pełne ustalenia w historii sesji 2026-07-17, kluczowe wnioski wplecione niżej), nie tylko intuicją.

Kluczowe ustalenie badawcze uzasadniające powrót: branżowe wzorce (Shopify, Vercel Platforms Starter Kit, duże wdrożenia WordPress) **domyślnie renderują wielu najemców z jednego wspólnego runtime'u** — repo-per-tenant jest kosztownym wyjątkiem (case study Spotify: bez dedykowanego narzędzia propagacja jednej zmiany na 70% repo we flocie zajmowała 6+ miesięcy), nie standardem. Obawa z 2026-07-13 ("page builder zawsze ogranicza do zestawu komponentów przewidzianych przez platformę") jest realna, ale rozwiązywalna głębią systemu (patrz sekcja "Personalizacja" niżej) — Shopify Online Store 2.0 dowodzi, że współdzielony runtime może dać bardzo głęboką personalizację (theme/section/block settings, Custom Liquid, App Blocks, Metaobjects) bez oddawania kodu.

**Ważna dobra wiadomość:** `edytor-sklepu` (osobne repo, budowane 2026-06-29 → 2026-07-17 jako spike) już implementuje dużą część tego, co ten dokument opisywał wizyjnie w 2026-07-13 — realny rejestr komponentów, drzewo sekcji jako dane (Zod schema), edytor z undo/redo, tryb edit/live. To nie jest praca od zera — to gotowy silnik czekający na osadzenie. Szczegóły integracji: `edytor-sklepu/docs/ROADMAPA.md` i `ARCHITEKTURA.md` w tamtym repo.

`store-factory.md` **nie jest usuwany** — zostaje jako opis odrzuconej ścieżki i materiał referencyjny (część jego elementów, np. drabina izolacji `managed`/`dedicated_data`/`dedicated_stack` dla enterprise, może kiedyś wrócić jako opcjonalny, płatny tier ponad tym modelem, nie jako model domyślny).

## Summary

Jeden współdzielony storefront (dziś `sklepikFront`, ewoluujący w miejscu, nie przepisywany od zera), obsługujący wielu najemców przez routing po domenie/`store_id` (jak Vercel Platforms Starter Kit). Layout i styl sklepu to dane (drzewo sekcji + design tokens), nie kod — renderowane przez rejestr komponentów współdzielony przez wszystkie sklepy. Właściciel sklepu edytuje przez chronioną trasę `/admin` tej samej aplikacji (silnik dostarcza `edytor-sklepu`). Personalizacja jest stopniowana i realna (nie "te same cegiełki") — patrz sekcja niżej. Custom code jest możliwy, ale bezpieczny z definicji (bez pełnego sandboxa server-side na start).

## Key Decisions (do not deviate without discussion)

- **Jeden storefront, jedna baza kodu, wszystkie sklepy.** Żadnych repozytoriów/deploymentów per sklep jako domyślnego mechanizmu. `sklepikFront` ewoluuje w to repo w miejscu — nie jest przepisywany od zera (zachowuje pracę produkcyjną: Oracle VPS, SSL, idempotencja webhooków).
- **Nowy sklep = rekord + domena, nie repo + deployment.** Store Factory (patrz `store-factory.md`, historyczny) się kurczy: nowy sklep to wiersz w bazie (`store_id`) + jedno wywołanie Vercel Domains API podpinające domenę klienta do jednego wspólnego deploymentu. `GithubClient`/`VercelClient`/`ProvisioningRun` z `store-factory.md` stają się legacy — zostają w kodzie jako nieużywana ścieżka do czasu uprzątnięcia (patrz "Legacy" w `stan-projektu.md`), nie rozwijać dalej.
- **Layout i styl sklepu to dane, nie kod.** Strona sklepu to drzewo sekcji (schema Zod, już zaprojektowana w `edytor-sklepu/packages/schema`), przechowywane w bazie `sklepik` scoped po `store_id`, renderowane przez rejestr komponentów (`edytor-sklepu/packages/component-library` + `renderer`) współdzielony przez wszystkie sklepy. Nowy komponent w rejestrze staje się dostępny dla wszystkich sklepów natychmiast.
- **`/admin` to chroniona sekcja jednej aplikacji, nie osobny deployment.** Auth przez zwykłą sesję/RBAC przeciw już istniejącemu `RoleUser`+`store_id` w `sklepik` — bez federacyjnego JWT/JWKS między niezależnymi deploymentami (to było potrzebne tylko w odrzuconym modelu repo-per-sklep).
- **Personalizacja jest stopniowana, budowana od najtańszego kroku (patrz sekcja niżej):** design tokens → warianty stylu sekcji → jeden poziom zagnieżdżenia (kontenery) → (odłożone) pełny swobodny grid.
- **Custom code bezpieczny z definicji, nie przez zaufanie.** JSON-Logic dla warunkowej widoczności/logiki (zero ryzyka wykonania kodu) + custom HTML/CSS/JS w `<iframe sandbox="allow-scripts">` ze ścisłym CSP dla realnych widgetów klienta (kod klienta wykonuje się wyłącznie w przeglądarce odwiedzającego, nigdy na współdzielonym serwerze). Serwerowy sandbox (QuickJS-WASM, docelowo ew. Shopify-Functions-style WASM) tylko jeśli realna potrzeba to uzasadni — **nigdy `vm2`** (deprecated, świeże krytyczne CVE).
- **Dokumenty stron w bazie `sklepik`, scoped po `store_id`.** `edytor-sklepu`'s `GitHubPageRepository` (git-based CMS, budowany pod odrzucony model repo-per-sklep) zostaje w kodzie jako opcja/materiał referencyjny, ale główną ścieżką jest nowy `PageRepository` oparty o bazę.

## Design Details

### Backend (`sklepik`)

1. **`PageRepository` oparty o bazę, scoped po `store_id`.** `edytor-sklepu` już ma interfejs `PageRepository` (dziś: `SQLitePageRepository`/`FilePageRepository`/`GitHubPageRepository` w `packages/persistence`) — dodać `SklepikPageRepository` (nazwa robocza, konsumuje Admin/Store API tego repo) jako nową implementację tego samego interfejsu, nie nowy model mentalny. Drzewo sekcji: schema Zod z `edytor-sklepu/packages/schema` (`Page`/`Section`/`Block`) jako źródło typów, kolumna `jsonb` per stronę + `store_id`, bez normalizacji na start (mniej migracji, wystarczające query'owanie — strona jest zawsze pobierana w całości).
2. **Design tokens** — osobny model `Spree::StoreTheme` (nie dorzucanie kolejnych `preference` do `Store`, żeby go nie rozdymać) — kolory, typografia, spacing, radius, cienie. Format zgodny z W3C Design Tokens Community Group (stabilna specyfikacja 2025.10), kompilowany do CSS custom properties per `store_id` (wzorzec Style Dictionary — multi-brand theming z jednego drzewa tokenów + nadpisania per sklep).
3. **Draft/publish** — `Page` ma `draft_data`/`published_data` + `published_at`; publikacja to atomowa operacja kopiująca draft → published. Uzasadnienie badawcze: TinaCMS i Decap CMS boleśnie się nauczyły, że brak tego rozdziału jest głównym źródłem skarg nietechnicznych właścicieli sklepów — jawny stan "zapisz" (draft) vs "opublikuj" jest wymagany, nie opcjonalny.
4. **Custom code — bez sandboxa server-side na start.** JSON-Logic (interpretacja danych, zero wykonania kodu) dla warunkowej logiki jako pole na sekcji/bloku. Realny custom kod (HTML/CSS/JS) trafia do `<iframe sandbox="allow-scripts">` renderowanego przez frontend — nigdy nie dotyka backendu ani współdzielonego serwera Next.js. Jeśli w przyszłości pojawi się potrzeba logiki server-side (np. własne reguły cenowe), rozważyć QuickJS-WASM (czysty WASM, działa w Node runtime Vercela) jako tani krok pośredni, zanim inwestuje się w coś jak Shopify Functions (Wasmtime).

### Frontend (`sklepikFront`)

1. **Middleware rozpoznawania tenanta** — rozwiązuje `store_id` po `Host` żądania (rozszerza to, co Faza 2 `multi-store-support.md` już zakładała), analogicznie do Vercel Platforms Starter Kit.
2. **Rejestr komponentów i renderer — już istnieją, nie budować od zera.** `edytor-sklepu/packages/component-library` (7/14 sekcji treści) + `packages/renderer` implementują dokładnie to, co ta sekcja opisywała jako "do zbudowania" w wersji z 2026-07-13. Zadanie integracyjne: zamontować je jako zależności w `sklepikFront`, nie przepisywać. Sekcje commerce (`product_grid`, `category_grid`) są już zaprojektowane jako sloty rejestru wypełniane przez hosta realnymi danymi (Store API) — wzorzec potwierdzony badawczo jako zgodny z Shopify Online Store 2.0 (dynamic sources: referencja ID, nigdy kopia danych).
3. **`/admin` jako chroniona sekcja tej samej aplikacji.** Silnik edytora (`apps/editor` z `edytor-sklepu`, undo/redo, panel właściwości generowany z Zod) montowany jako trasa, nie osobny deployment. Auth: zwykła sesja przeciw `RoleUser`+`store_id` w `sklepik` (nie federacyjny JWT/JWKS — to było potrzebne tylko przy niezależnych deploymentach, które odrzuciliśmy).
4. **Personalizacja — kolejność inwestycji (poparta badaniem porównawczym Webflow/Framer/Wix Studio/Squarespace/Shopify):**
   - **Etap 1 (tanie, dni-tygodnie):** design tokens jako CSS custom properties per `store_id` — największy zwrot za najmniejszy koszt, samo w sobie daje wrażenie "innej marki".
   - **Etap 2 (tanie-średnie, 2-4 tygodnie):** pole `variant` na sekcji (3-5 układów na typ: hero „split"/„centered"/„overlay") + drugi wymiar pól (`image_position`, `background`). To bezpośrednio rozbija problem "tych samych cegiełek" (wzorzec Shopify Theme Blocks / Webflow Component Style Variants).
   - **Etap 3 (średnie, opcjonalnie):** jeden poziom zagnieżdżenia — blok „kolumny" jako kontener na 2-4 dowolne bloki, płaska lista z `parent_id` (nie pełne drzewo).
   - **Odłożone (drogie):** pełny swobodny grid/edytor jak Wix Studio/Framer — dopiero gdy Etapy 1-3 przestaną wystarczać.

## Migration Path

1. Middleware rozpoznawania tenanta w `sklepikFront` (rozszerza Fazę 2 `multi-store-support.md`).
2. `SklepikPageRepository` (Backend, punkt 1 wyżej) — nowa implementacja istniejącego interfejsu `PageRepository` z `edytor-sklepu`.
3. Zamontowanie `component-library`/`renderer`/`editor-core` z `edytor-sklepu` jako zależności `sklepikFront`; trasa `/admin` z sesją auth przeciw `sklepik`.
4. Design tokens (Etap 1 personalizacji) — pierwsza widoczna wartość dla właściciela sklepu.
5. Warianty stylu sekcji (Etap 2 personalizacji).
6. JSON-Logic + custom code embed w iframe (bezpieczna rozszerzalność).
7. Uproszczony Store Factory: nowy sklep = rekord `store_id` + Vercel Domains API (zastępuje `GithubClient`/`VercelClient` z `store-factory.md`).
8. Nocny E2E jako siatka bezpieczeństwa: utwórz sklep → zaloguj się do `/admin` → edytuj → zweryfikuj na żywym storefroncie → posprzątaj.
9. Zagnieżdżone kontenery (Etap 3 personalizacji), media, reszta biblioteki sekcji (7/14 dziś) — na żądanie, po ustabilizowaniu 1-8.

## Constraints on Current Work

- `edytor-sklepu` pozostaje osobnym repo (dostarcza silnik jako pakiety, docelowo `@sklepik/*`), ale **przestaje budować pod model "repo per sklep"** — `GitHubPageRepository` i decyzja "`/admin` w repo każdego sklepu" (`edytor-sklepu/docs/ARCHITEKTURA.md`) są superseded przez ten dokument; nie kontynuować tamtego kierunku bez nowej decyzji.
- Nie kasować kodu Store Factory (`Spree::ProvisioningRun`, `GithubClient`, `VercelClient`) od razu — zostaje jako legacy do uprzątnięcia po ustabilizowaniu nowego modelu, nie rozwijać dalej.
- Middleware rozpoznawania tenanta (krok 1 Migration Path) powinien być zaprojektowany pod pełne wykorzystanie przez punkty 2-4, nie budowany prowizorycznie.

## Open Questions

- Format przechowywania drzewa sekcji: jeden `jsonb` per strona (prostsze na start, wybrane) vs JSON per sekcja w osobnych rekordach (badanie wskazuje mniej konfliktów przy równoczesnej edycji różnych sekcji tej samej strony — rozważyć przy pierwszych realnych konfliktach, nie budować na zapas).
- Governance: sklepy klientów zawsze na tej samej domenie platformy z custom domain attached, czy kiedyś jednak opcja "eksportu"/przekazania czegoś klientowi (jak Webflow export) jako płatny tier — nierozstrzygnięte, nie blokuje obecnego planu.
- Model cenowy warstw personalizacji (tokens/warianty/kontenery/custom code) — nierozstrzygnięte.
- Kiedy (jeśli w ogóle) inwestować w serwerowy sandbox custom code (QuickJS-WASM czy dalej) — dopiero gdy realny klient tego zażąda, nie z wyprzedzeniem.
- **Kiedy robić refaktor klienta `sklepikFront` z singletona na per-request (2026-07-17):** zbadane i świadomie odłożone. `sklepikFront`'s klient Spree jest dziś modułowym singletonem inicjowanym raz z env-varów — realny problem (wyciek configu sklepu A do żądania sklepu B) może wystąpić dopiero, gdy istnieje **drugi prawdziwy tenant** z innym configem na tym samym procesie. Refaktor dotyka ~60 miejsc w 15 plikach, w tym checkout/płatności/konto klienta — zrobić dopiero przy onboardowaniu drugiego realnego sklepu, nie na zapas (Next.js 16 wymaga wtedy `async`/`await headers()` w `getClient()`/`getConfig()`, co i tak wymusi dotknięcie tych plików — najlepiej zrobić to razem z prawdziwym drugim tenantem do przetestowania na żywo, nie w próżni).

## Zweryfikowane względem branży (2026-07-17)

Trzy niezależne research-passy sprawdziły dzisiejsze decyzje implementacyjne krytycznie (nie potwierdzająco) względem Shopify, Sanity, Contentful, Medusa.js i Vercel Platforms Starter Kit:

- **Model treści (JSONB blob per strona, draft/published, optimistic locking)** — zgodny z tym, co robi Shopify Online Store 2.0 dla tego samego problemu (JSON templates). Nie naiwne uproszczenie, sprawdzony wzorzec produkcyjny.
- **Jeden storefront dla wielu sklepów, routing po domenie** — **nie** jest to wzorzec Shopify (oni idą w osobny deployment Hydrogen per marka/rynek), ale jest dokładnie oficjalnym, udokumentowanym wzorcem Vercel Platforms Starter Kit. Świadomy wybór innego, równie uznanego modelu, nie błąd.
- **Publikacja pakietów `@pawelekbyra/*` przez GitHub Packages + Changesets** — rekomendowane zostać (koszt migracji na Verdaccio/npmjs nie opłaca się przy tej skali).

Trzy konkretne wnioski do działania: (1) monitoring rozmiaru dokumentu JSONB — **zrobione** (`Spree::StorefrontPage::WARN_DOCUMENT_SIZE_BYTES`, `engine-decisions.md` 2026-07-17), (2) cache/CDN dla odczytu treści storefrontowej — odłożone, zależy od jeszcze niezrobionego montażu renderowania z danych w `sklepikFront`, (3) `store_id` jako granica partycjonowania — już satysfakcjonujące (zapytania już dziś scope'ują po `store_id`), świadomość utrzymać przy przyszłym skalowaniu, nie wymaga nowego kodu teraz.

## References

- [`multi-store-support.md`](multi-store-support.md) — Faza 1 (zaimplementowana), Faza 2 (routing po domenie, warunek wstępny tego planu).
- [`store-factory.md`](store-factory.md) — odrzucona ścieżka (repo per sklep), zachowana jako materiał historyczny/referencyjny.
- `edytor-sklepu` (repo `pawelekbyra/edytor-sklepu`) — `docs/ROADMAPA.md`, `docs/ARCHITEKTURA.md`, `docs/MACIERZ_ZGODNOSCI.md` — silnik edytora do zamontowania, nie do zbudowania od zera.
- Wzorce referencyjne (architektura, nie kod): Shopify Online Store 2.0 (sections/blocks/theme settings/Custom Liquid/App Blocks/Metaobjects), Vercel Platforms Starter Kit (routing po domenie w jednym deploymencie), Webflow/Framer/Wix Studio (swobodny layout, custom code embed w iframe), Sanity Visual Editing (overlay zamiast wstrzykiwania atrybutów edycyjnych do komponentów — wzorzec do zastosowania przy integracji edytora, adresuje wcześniejszy błąd z error boundary blokującym import do Server Component).
- Dziewięć research-passów z sesji 2026-07-17 (multi-tenant architecture, page builder architecture, fleet update, multi-tenant auth, CI/CD testing, headless commerce, Shopify theming depth, sandboxed custom code, design tokens) — pełne ustalenia w historii tamtej sesji; kluczowe wnioski wplecione wyżej.
