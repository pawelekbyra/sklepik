# Audyt 1 — inwentaryzacja 100% repozytoriów

**Data:** 2026-07-14
**Repozytoria:** `pawelekbyra/sklepik` (`/home/pawe-perfect/Dokumenty/sklepik`) i `pawelekbyra/sklepikFront` (`/home/pawe-perfect/Dokumenty/sklepikFront`)
**Zakres:** wszystkie pliki śledzone przez Git w lokalnych checkoutach
**Charakter:** audyt statyczny, bez zmian kodu produktu i bez uruchamiania pełnych suite

## Wynik wykonawczy

Zakres ewidencyjny wynosi **4 859/4 859 tracked paths (100%)**: 4 606 w `sklepik` i 253 w `sklepikFront`. Każda ścieżka jest objęta regułą klasyfikacyjną w maszynowo odtwarzalnym dodatku na końcu raportu. Nie oznacza to ręcznej inspekcji każdej linii: klasyfikacja jest modułowa, a ryzykowne i graniczne obszary były dodatkowo sprawdzane przez manifesty, dokumentację, liczniki, wyszukiwanie referencji i identycznych treści.

Najważniejszy obraz systemu:

- aktywny produkt opiera się na `spree/core` (1 722 pliki), `spree/api` (545), dashboardzie i jego bibliotekach (411) oraz obu SDK (557);
- **1 135 plików** należy do dwóch jawnie nieaktywnych/legacy modułów: `spree/admin` (1 070) i `spree/emails` (65), mimo że pozostają tracked i kompilowalne jako gemy;
- kontrakty generowane są rozproszone między typami Store/Admin SDK, Zod i OpenAPI; wykryto co najmniej 219 ścieżek pasujących do kandydatów generated/vendor/API reference w backendzie;
- storefront jest stosunkowo mały (253 pliki), ale checkout ma dwa pliki po 960 i 792 linie oraz kolejny komponent płatności 538 linii;
- nazwy i publiczne pakiety `@spree/*` są nadal podstawowym kontraktem między repozytoriami. To zgodne ze stanem przejściowym F29, ale wymaga izolacji, nie mechanicznego rename'u.

Nie znaleziono dowodu na P0 wyłącznie w tym audycie inwentaryzacyjnym. Najwyższe findings mają P1, ponieważ legacy i bezpośrednie sprzężenie z silnikiem istotnie zwiększają powierzchnię utrzymania oraz ryzyko migracji.

## Metodologia i policzalne pokrycie

Źródłem zbioru był wyłącznie `git ls-files` w każdym repo. Dzięki temu raport nie miesza zależności z `node_modules`, buildów, lokalnego `server/`, cache ani innych untracked artefaktów z wersjonowanym produktem.

Wykonane kontrole:

1. odczytano `AGENTS.md`, `CLAUDE.md` obu repo oraz kanoniczne `docs/kierunek-projektu.md`, `docs/architektura.md`, `docs/stan-projektu.md`, `docs/roadmap.md`;
2. policzono tracked paths globalnie, według katalogu najwyższego poziomu, modułu i rozszerzenia;
3. policzono linie na poziomie głównych modułów (`wc -l`; wartość orientacyjna obejmuje kod, testy, assety tekstowe i generated);
4. wyodrębniono ścieżki testowe, generated/vendor/API reference, symlinki i największe pliki;
5. porównano SHA-256 wszystkich regularnych tracked files w celu znalezienia duplikatów dokładnych;
6. sprawdzono manifesty gemów i pakietów oraz ich zadeklarowane role;
7. przypisano pierwszą pasującą regułę klasyfikacji z dodatku. Reguła catch-all gwarantuje 100% pokrycia, ale takie ścieżki otrzymują `UNKNOWN`, nie pozornie pewną ocenę.

### Bilans

| Repo | Tracked paths | Udział | Dominujące rozszerzenia | Ścieżki testowe* |
|---|---:|---:|---|---:|
| `sklepik` | 4 606 | 94,8% | 2 300 `.rb`, 768 `.ts`, 618 `.erb`, 214 `.tsx`, 214 `.svg` | 1 003 |
| `sklepikFront` | 253 | 5,2% | 127 `.tsx`, 81 `.ts`, 11 `.json`, 8 `.md` | 12 |
| **Razem** | **4 859** | **100%** | — | **1 015** |

\* Heurystyka ścieżki/nazwy: `spec`, `test(s)`, `e2e`, `*_spec`, `*.test`, `*.spec`; nie jest miarą liczby przypadków ani pokrycia wykonawczego.

Lokalny worktree zawierał istniejące zmiany innych prac. Audyt ich nie modyfikował. `git ls-files` opisuje ścieżki wersjonowane w bieżącym checkout, natomiast treść analizy odpowiada bieżącej zawartości plików roboczych.

## Mapa repozytorium `sklepik`

| Moduł | Pliki | Linie (orient.) | Rola | Klasyfikacja |
|---|---:|---:|---|---|
| `spree/core` | 1 722 | 131 317 | modele, usługi, commerce, migracje, testy i assety silnika | **HARDEN** |
| `spree/api` | 545 | 55 814 | Store/Admin API v3, serializery, auth, specy integracyjne | **HARDEN** |
| `spree/admin` | 1 070 | 64 498 | legacy Rails admin, wg kanonu wyłączony na rzecz SPA | **ISOLATE** |
| `spree/emails` | 65 | 2 533 | opcjonalne maile silnika, docelowo zastąpione webhookami/storefrontem | **ISOLATE** |
| `packages/dashboard` | 258 | 61 091 | panel operatora, trasy, hooki, formularze, E2E | **HARDEN** |
| `packages/dashboard-core` | 69 | 12 785 | framework panelu, providerzy, rejestry | **REFACTOR** |
| `packages/dashboard-ui` | 84 | 9 129 | design system panelu | **KEEP** |
| `packages/sdk` | 230 | 10 345 | Store API SDK, typy/Zod generated | **REPLACE** (publiczna granica), zachować implementację w adapterze przejściowym |
| `packages/admin-sdk` | 317 | 14 490 | Admin API SDK i typy generated | **REPLACE** (publiczna granica), zachować implementację w adapterze przejściowym |
| `packages/sdk-core` | 10 | 566 | wspólny transport/retry/error SDK | **KEEP** wewnątrz adaptera |
| `packages/cli` | 67 | 5 987 | upstreamowe narzędzie Spree/Docker | **ISOLATE** |
| `packages/create-spree-app` | 28 | 1 911 | upstreamowy generator aplikacji Spree | **REMOVE** po potwierdzeniu braku użycia przez Store Factory |
| `packages/test-contracts` | 8 | 494 | kontrakty tenant isolation / Store Factory | **HARDEN** |
| `docs` | 46 | 34 286 | kanon, operacje, plany, OpenAPI | **HARDEN** (spójność i generated refs) |
| root, `.github`, `scripts`, `bin`, deploy config | pozostałe | — | workspace, CI, Docker/Oracle/Vercel tooling | **HARDEN** |
| `.agents`, `.claude`, `.zed` | 24+ | — | instrukcje i konfiguracja narzędzi deweloperskich | **KEEP**, z wyjątkiem niedziałających linków |

Ocena `REPLACE` SDK nie oznacza natychmiastowego skasowania. Oznacza zastąpienie publicznej nazwy/kontraktu kontraktem Sklepika i utrzymanie obecnego klienta jako adaptera kompatybilności do czasu migracji wszystkich konsumentów.

## Mapa repozytorium `sklepikFront`

| Moduł | Pliki | Linie (orient.) | Rola | Klasyfikacja |
|---|---:|---:|---|---|
| `src/app` | 39 | 5 515 | App Router, storefront, checkout, webhook API, SEO | **HARDEN** |
| `src/components` | 86 | 10 922 | UI storefrontu, koszyk, checkout, produkty, layout | **HARDEN**; `checkout/**` **REFACTOR** |
| `src/lib` | 67 | 6 993 | dostęp do API, store context, layout renderer, webhooki, e-mail, analytics | **REFACTOR** przy granicy `spree/**`; reszta **HARDEN** |
| `src/contexts` | 5 | 756 | stan klienta/koszyka/checkoutu | **HARDEN** |
| `src/types`, `src/hooks`, `src/i18n` | 4 | 105 | typy i cross-cutting helpers | **KEEP** |
| `messages` | 5 | 2 650 | pięć równoległych katalogów locale | **HARDEN** (parity automatyczne) |
| `public` | 10 | 436 tekstowych linii + binaria | assety statyczne | **KEEP** |
| testy `src/**/__tests__`, `e2e`, `e2e-backend` | wliczone powyżej + 3 | — | Vitest, Playwright, backend E2E | **HARDEN** |
| `docs` | 5 | 421 | dokumentacja storefrontu | **HARDEN** |
| root/config/scripts/CI | 24 | — | Next/Vitest/Playwright/Vercel/Docker | **HARDEN** |

## Generated, vendor, legacy i duplikaty

### Generated / źródła pochodne

W `sklepik` znaleziono **219 ścieżek** pasujących do jawnych kandydatów `generated`, `vendor`, `routeTree.gen` lub `docs/api-reference`: 100 w Store SDK, 61 w Admin SDK, 47 w legacy admin, 5 w core, po 2 w CLI i API reference oraz 1 w dashboardzie. Najważniejsze:

- `packages/sdk/src/types/generated/**` i `packages/sdk/src/zod/generated/**`;
- `packages/admin-sdk/src/types/generated/**`;
- `packages/dashboard/src/routeTree.gen.ts`;
- `docs/api-reference/{store,admin}.yaml`;
- `spree/*/vendor/**`.

Artefakty te powinny pozostać wersjonowane tylko tam, gdzie build/release lub konsumenci naprawdę tego wymagają, oraz mieć jednoznaczny generator i CI wykrywające drift. W storefrontcie nie ma tracked katalogu `generated`, `dist`, `vendor` ani `coverage`; `package-lock.json` jest zamierzonym lockfile npm według obecnego manifestu/scripts.

### Legacy

Dokumentacja wprost określa `spree/admin` jako wyłączony i referencyjny, a `spree/emails` jako docelowo nieużywany. To **1 135 tracked plików**, 24,6% backendowego repo. Nie należy ich traktować jak aktywnych modułów przy zmianach produktowych. Przed fizycznym usunięciem trzeba jednak sprawdzić zależności bundlera/gemspeców, assety współdzielone i zachowania używane jako referencja.

### Dokładne duplikaty

Kontrola SHA-256 wykazała wiele identycznych plików. Część jest oczekiwana (LICENSE, konfiguracje Changesets, fixture'y, szablony CRUD), ale część tworzy ryzyko rozjazdu:

- `spree/admin/vendor/javascript/stimulus-reveal-controller.js` = `spree/core/vendor/javascript/stimulus-reveal-controller.js`;
- `spree/admin/app/javascript/.../address_form_controller.js` = odpowiednik w `spree/core`;
- setup/mocks i wybrane generated types są powielone między Store SDK i Admin SDK;
- `spree/emails/app/assets/images/noimage/**` zawiera powtórzone obrazy w zagnieżdżonych ścieżkach;
- liczne identyczne partiale legacy admin wynikają z generatorowego CRUD.

Nie stwierdzono dokładnych duplikatów w `sklepikFront` w porównaniu pełnych plików.

### Podejrzana ścieżka

Tracked `packages/sdk-core/packages/sdk/src/zod/index.ts` jest dokładną kopią `packages/sdk/src/zod/index.ts` i znajduje się w nienaturalnie zagnieżdżonym drzewie pod `sdk-core`. To silny kandydat na przypadkowy artefakt lub pozostałość operacji generującej. Nie należy usuwać bez sprawdzenia historii i buildów.

## Findings

### INV-001 — P1 — Nieaktywny legacy stanowi jedną czwartą backendowego repo

**Dowód:** 1 070 tracked files w `spree/admin`, 65 w `spree/emails`; `CLAUDE.md` określa admin jako wyłączony, a e-maile jako docelowo nieużywane. Razem 1 135/4 606 = 24,6%.

**Wpływ:** większa powierzchnia skanów, zależności, aktualizacji i pomyłek agentów; możliwość przypadkowego rozwijania nieaktywnej ścieżki.

**Rekomendacja:** jawnie wyłączyć oba moduły z domyślnych ścieżek build/release, oznaczyć ownership i dozwolone użycie; następnie udowodnić brak runtime dependencies i dopiero planować usunięcie.

**Kryterium zamknięcia:** dependency/build trace dowodzi, co jest wymagane; CI i dokumentacja odróżniają aktywne od legacy; każdy pozostawiony plik ma uzasadnioną kategorię.

### INV-002 — P1 — Granica produktu nadal jest publicznie granicą Spree

**Dowód:** storefront zależy od `@spree/sdk`; dashboard od `@spree/admin-sdk`, `@spree/dashboard-*`; manifesty, namespace `Spree::`, wygenerowane typy i publiczne nagłówki/cookies pozostają częścią konsumpcji. Kanon F29 wymaga własnego języka domenowego i adaptera.

**Wpływ:** frontend, panel, testy i przyszli agenci są związani z modelem silnika; wymiana lub nawet kontrolowana aktualizacja silnika ma duży blast radius.

**Rekomendacja:** najpierw zinwentaryzować kontrakty używane rzeczywiście, utworzyć `@sklepik/*` facades i anti-corruption layer, zachowując kompatybilność. Nie wykonywać globalnego rename'u.

**Kryterium zamknięcia:** nowe funkcje nie importują `@spree/*` ani namespace'ów silnika poza adapterem; wdrożone konsumery przechodzą testy kontraktowe obu wersji.

### INV-003 — P2 — Pipeline generated ma wiele źródeł dryfu

**Dowód:** co najmniej 219 kandydatów generated/vendor/API reference; typy Store i Admin, Zod, OpenAPI i `routeTree.gen.ts` są generowane różnymi narzędziami. `stan-projektu.md` już odnotowuje brak regeneracji OpenAPI dla nowego endpointu stores.

**Wpływ:** API może działać inaczej niż SDK, typy lub dokumentacja; ręczne poprawki artefaktów są łatwe do nadpisania.

**Rekomendacja:** jeden CI target regenerujący wszystkie pochodne i kończący się błędem przy diffie; nagłówki `generated — do not edit`; mapa source → generator → output.

**Kryterium zamknięcia:** czysty checkout po pełnej regeneracji i test kontraktowy API→SDK→storefront/dashboard.

### INV-004 — P2 — Prawdopodobnie przypadkowa kopia pod `sdk-core`

**Dowód:** `packages/sdk-core/packages/sdk/src/zod/index.ts` jest SHA-256-identyczny z `packages/sdk/src/zod/index.ts`; ścieżka nie odpowiada strukturze manifestu `sdk-core` (`src`, nie zagnieżdżone `packages/sdk`).

**Wpływ:** niejasne źródło prawdy i ryzyko, że generator zapisuje poza oczekiwanym katalogiem.

**Rekomendacja:** sprawdzić `git log --follow`, generator Zod i zawartość publikowanego pakietu; usunąć dopiero po zielonym build/typecheck i teście paczki.

**Kryterium zamknięcia:** istnieje tylko kanoniczny output lub duplikat ma udokumentowany cel i test.

### INV-005 — P2 — Krytyczna ścieżka checkoutu jest skoncentrowana w dużych modułach

**Dowód:** `src/components/checkout/PaymentSection.tsx` ma 960 linii, `CheckoutPageContent.tsx` 792, `ExpressCheckoutButton.tsx` 538. Są to trzy z największych ręcznie utrzymywanych plików storefrontu.

**Wpływ:** duży koszt review i wysoki promień regresji przy zmianach płatności, stanu checkoutu i providerów.

**Rekomendacja:** po audycie pieniędzy rozdzielić orkiestrację, provider adapters i czyste UI, utrzymując testy zachowania przed refaktorem.

**Kryterium zamknięcia:** mniejsze moduły z jednoznaczną odpowiedzialnością, kontrakty providerów i E2E każdej aktywnej metody płatności.

### INV-006 — P2 — Storefront ma małą siatkę testową względem liczby ścieżek krytycznych

**Dowód:** 12 ścieżek testowych według heurystyki wobec 205 plików `src`; pojedynczy tracked `e2e/storefront.spec.ts` ma 153 linie. Największe testy jednostkowe dotyczą checkout/payment, ale nie stanowią dowodu pełnego E2E prawdziwego zamówienia. `stan-projektu.md` potwierdza brak prawdziwego zamówienia.

**Wpływ:** regresje katalog→koszyk→checkout→płatność→zamówienie mogą przejść mimo lokalnych unit tests.

**Rekomendacja:** kontraktowe i przeglądarkowe scenariusze dwóch tenantów, guest/auth cart, retry/idempotency i produkcyjnie równoważne webhooki.

**Kryterium zamknięcia:** obowiązkowy w CI happy path i kontrolowane failure paths na realnym API testowym.

### INV-007 — P3 — Exact duplicates nie mają jawnej polityki

**Dowód:** identyczne kontrolery JS, fixtures, pliki konfiguracyjne i generated types w wielu modułach; szczegóły w sekcji duplikatów.

**Wpływ:** rozjazdy poprawek i niepotrzebny noise, zwłaszcza gdy kopie są aktywne.

**Rekomendacja:** rozróżnić `intentional template copy`, `generated copy`, `shared source candidate`; nie deduplikować mechanicznie legacy partiali.

**Kryterium zamknięcia:** każdy duplikat kodu wykonywalnego ma wspólne źródło albo test/politykę synchronizacji.

### INV-008 — P3 — Moduły upstreamowe nie mają decyzji keep/remove związanej ze Store Factory

**Dowód:** tracked i publikowalne `packages/create-spree-app`, `packages/cli` oraz `packages/docs` opisują produkt/upstream Spree; kanoniczny Store Factory używa własnego procesu GitHub→Vercel i efemerycznego startera Rails.

**Wpływ:** dodatkowe zależności i mylące powierzchnie utrzymania.

**Rekomendacja:** dla każdego modułu wskazać konkretnego konsumenta produkcyjnego. `create-spree-app` usunąć, jeśli nie jest częścią wspieranego workflow; CLI izolować, jeśli nadal bootstrappuje host-app.

**Kryterium zamknięcia:** decision record z ownerem, konsumentem i testem albo bezpieczne usunięcie.

## Priorytet dalszych działań

1. Audyt architektury i granic powinien wykorzystać tę mapę do oznaczenia runtime/build/deploy dependencies, szczególnie legacy i root tooling.
2. Audyt uniezależnienia od Spree powinien policzyć importy/namespace'y oraz zaprojektować adaptery dla obu SDK.
3. Audyty tenant isolation, auth i pieniędzy muszą koncentrować się na `spree/core`, `spree/api`, dashboardzie i trzech dużych modułach checkoutu.
4. Przed usuwaniem czegokolwiek wykonać pełne buildy/testy oraz trace bootu produkcyjnego; ten raport nie autoryzuje removalu.

## Dodatek A — deterministyczna klasyfikacja wszystkich tracked paths

Poniższe reguły są stosowane od góry; pierwsze dopasowanie wygrywa. `repo:path` oznacza ścieżkę z `git ls-files`. Dzięki końcowej regule żadna ścieżka nie pozostaje niepoliczona.

```yaml
schema: sklepik.inventory.classification/v1
snapshot_date: 2026-07-14
population:
  sklepik: 4606
  sklepikFront: 253
  total: 4859
rules:
  - { repo: sklepik, glob: "spree/admin/**", class: ISOLATE, reason: "disabled legacy Rails admin" }
  - { repo: sklepik, glob: "spree/emails/**", class: ISOLATE, reason: "superseded transactional email path" }
  - { repo: sklepik, glob: "packages/create-spree-app/**", class: REMOVE, reason: "no identified Sklepik runtime consumer; verify first" }
  - { repo: sklepik, glob: "packages/cli/**", class: ISOLATE, reason: "upstream/bootstrap tooling" }
  - { repo: sklepik, glob: "spree/core/**", class: HARDEN, reason: "critical commerce engine" }
  - { repo: sklepik, glob: "spree/api/**", class: HARDEN, reason: "critical public/admin API" }
  - { repo: sklepik, glob: "packages/dashboard/**", class: HARDEN, reason: "active owner/operator UI" }
  - { repo: sklepik, glob: "packages/dashboard-core/**", class: REFACTOR, reason: "remove engine naming and isolate provider boundary" }
  - { repo: sklepik, glob: "packages/dashboard-ui/**", class: KEEP, reason: "headless design system" }
  - { repo: sklepik, glob: "packages/sdk/**", class: REPLACE, reason: "replace public boundary with Sklepik facade; keep adapter during migration" }
  - { repo: sklepik, glob: "packages/admin-sdk/**", class: REPLACE, reason: "replace public boundary with Sklepik facade; keep adapter during migration" }
  - { repo: sklepik, glob: "packages/sdk-core/**", class: KEEP, reason: "reusable internal transport; investigate nested duplicate" }
  - { repo: sklepik, glob: "packages/test-contracts/**", class: HARDEN, reason: "tenant/API safety net" }
  - { repo: sklepik, glob: "packages/docs/**", class: ISOLATE, reason: "upstream reference docs" }
  - { repo: sklepik, glob: "docs/**", class: HARDEN, reason: "system canon, operations and generated API reference" }
  - { repo: sklepik, glob: ".agents/**", class: KEEP, reason: "agent workflow configuration" }
  - { repo: sklepik, glob: ".claude/**", class: KEEP, reason: "agent workflow configuration" }
  - { repo: sklepik, glob: ".zed/**", class: KEEP, reason: "developer configuration" }
  - { repo: sklepik, glob: ".github/**", class: HARDEN, reason: "CI/release boundary" }
  - { repo: sklepik, glob: "scripts/**", class: HARDEN, reason: "bootstrap/deployment tooling" }
  - { repo: sklepik, glob: "bin/**", class: HARDEN, reason: "production/deployment tooling" }
  - { repo: sklepik, glob: "*", class: HARDEN, reason: "root workspace/build/deploy configuration" }
  - { repo: sklepik, glob: "**", class: UNKNOWN, reason: "unmatched; requires manual classification" }

  - { repo: sklepikFront, glob: "src/components/checkout/**", class: REFACTOR, reason: "large critical payment/checkout modules" }
  - { repo: sklepikFront, glob: "src/lib/spree/**", class: REFACTOR, reason: "engine adapter boundary" }
  - { repo: sklepikFront, glob: "src/app/**", class: HARDEN, reason: "active routes, SEO and webhook API" }
  - { repo: sklepikFront, glob: "src/components/**", class: HARDEN, reason: "active storefront UI" }
  - { repo: sklepikFront, glob: "src/lib/**", class: HARDEN, reason: "active server/data/integration layer" }
  - { repo: sklepikFront, glob: "src/contexts/**", class: HARDEN, reason: "critical client state" }
  - { repo: sklepikFront, glob: "src/types/**", class: KEEP, reason: "local stable types" }
  - { repo: sklepikFront, glob: "src/hooks/**", class: KEEP, reason: "small reusable hooks" }
  - { repo: sklepikFront, glob: "src/i18n/**", class: KEEP, reason: "locale routing" }
  - { repo: sklepikFront, glob: "src/**", class: HARDEN, reason: "remaining active source" }
  - { repo: sklepikFront, glob: "messages/**", class: HARDEN, reason: "locale parity required" }
  - { repo: sklepikFront, glob: "public/**", class: KEEP, reason: "versioned static assets" }
  - { repo: sklepikFront, glob: "e2e/**", class: HARDEN, reason: "browser safety net" }
  - { repo: sklepikFront, glob: "e2e-backend/**", class: HARDEN, reason: "E2E environment" }
  - { repo: sklepikFront, glob: "docs/**", class: HARDEN, reason: "storefront operations and debt" }
  - { repo: sklepikFront, glob: "scripts/**", class: HARDEN, reason: "validation/bootstrap tooling" }
  - { repo: sklepikFront, glob: ".github/**", class: HARDEN, reason: "CI boundary" }
  - { repo: sklepikFront, glob: "*", class: HARDEN, reason: "root build/deploy configuration" }
  - { repo: sklepikFront, glob: "**", class: UNKNOWN, reason: "unmatched; requires manual classification" }
```

Uwaga implementacyjna: glob `*` w dodatku oznacza plik bezpośrednio w root, nie rekursywne dopasowanie. Przy tej semantyce reguły pokrywają wszystkie 4 859 ścieżek; końcowy `UNKNOWN` jest zabezpieczeniem dla przyszłych katalogów.

## Ograniczenia

- To audyt statyczny bieżących checkoutów, nie produkcyjnego runtime ani historii całego repo.
- Nie uruchomiono pełnych buildów, RSpec, Vitest, Playwright, skanów zależności ani coverage; będą dowodami w kolejnych audytach.
- Liczby linii są orientacyjne i obejmują generated, testy, dokumentację lub binarne artefakty raportowane przez `wc` zależnie od modułu; decyzje bazują na liczbie ścieżek i roli, nie na samym LOC.
- „Martwy kod” bez runtime trace/coverage nie jest dowiedziony. `spree/admin` i `spree/emails` są sklasyfikowane jako legacy na podstawie kanonicznej dokumentacji; pozostałe kandydaty wymagają build/dependency trace.
- Exact duplicate nie oznacza automatycznie błędu. Szablony, generated i fixture'y bywają celowo kopiowane.
- Klasyfikacja modułowa jest triage'em dla F29, nie zgodą na natychmiastową zmianę lub usunięcie.

## Podsumowanie liczb

- **4 859/4 859 tracked paths sklasyfikowanych regułami (100%)**.
- **4 606** plików w `sklepik`, **253** w `sklepikFront`.
- **1 015** ścieżek testowych według jawnej heurystyki (1 003 + 12).
- **1 135** plików w dwóch kanonicznie nieaktywnych modułach legacy.
- **219** backendowych kandydatów generated/vendor/API-reference.
- **8 findings:** 0 × P0, 2 × P1, 4 × P2, 2 × P3.

