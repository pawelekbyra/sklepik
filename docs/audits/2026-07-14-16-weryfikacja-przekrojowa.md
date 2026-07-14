# Audyt 16 — weryfikacja przekrojowa programu audytów

**Data:** 2026-07-14
**Baseline backend/admin:** `9a4f6931473592cf50f782b602e8a8b34d9e482e`
**Baseline storefront:** `0f83b941f345734b3bce2163a2329bae22a40b2d`
**Charakter:** weryfikacja read-only; bez zmian produktu, źródeł, danych i produkcji
**Repozytoria:** `/home/pawe-perfect/Dokumenty/sklepik`, `/home/pawe-perfect/Dokumenty/sklepikFront`

## Werdykt

Program audytów jest spójny merytorycznie i mechanicznie na poziomie treści: istnieje 15 raportów obszarowych, mają 170 unikalnych findings, poprawny bilans `9 × P0 + 68 × P1 + 77 × P2 + 16 × P3`, a raport nadrzędny przypisuje wszystkie 170 findings do 14 kanonicznych ryzyk. Wszystkie raporty mają zakres i ograniczenia. Skan popularnych formatów credentiali nie znalazł ujawnionej wartości.

Nie jest to jeszcze skonsolidowany stan repozytoryjny do merge bez dwóch operacji porządkowych:

1. raporty 14, 15 i 00 nie były podczas kontroli w docelowym `sklepik/docs/audits/`, a rejestr nadal oznaczał 13–15 jako `w toku`;
2. raporty świadomie używają końcowych dwóch spacji jako Markdown hard breaks. `git diff --no-index --check` raportuje ten styl; przed commitem zostanie on znormalizowany mechanicznie zgodnie z decyzją integratora.

Testy lokalne potwierdzają zielony frontend i ważny wycinek backendu, ale nie zamykają launch gates. Nie wykonano prawdziwego E2E, PostgreSQL upgrade/double-install, restore, browser matrix ani pełnych suite backendu.

## Artefakty wejściowe

### Program i playbook

- `sklepik/docs/audits/README.md` — przeczytany;
- `sklepik/docs/audit-playbook.md` — przeczytany; jest wcześniejszym playbookiem panelowym i mapą trzech wzorców, nie zastępuje programu fundamentu;
- `sklepik/CLAUDE.md`, `sklepikFront/CLAUDE.md`, oba `AGENTS.md` — przeczytane w zakresie zasad testów i dokumentacji.

### Raporty

**PASS — 15/15 treści dostępnych.**

- 01–13: `sklepik/docs/audits/2026-07-14-*.md`;
- 14: `sklepikFront/2026-07-14-14-panel-edytor-onboarding.md`;
- 15: `/tmp/2026-07-14-15-storefront-jakosc-sprzedazy.md`;
- master 00: `/tmp/2026-07-14-00-stan-fundamentu-sklepika.md`.

**FAIL — docelowe rozmieszczenie/rejestr w chwili kontroli.** Raporty 14/15/00 nie były jeszcze w katalogu audytów backendu, a `docs/audits/README.md` wskazywał status `w toku` dla 13–15. To kontrola stanu przed konsolidacją, nie błąd treści tych raportów.

## Frontend — testy lokalne

| Kontrola | Komenda | Wynik | Dowód / uwaga |
|---|---|---|---|
| lint | `npm run lint` | **PASS** | Biome: 218 plików, bez poprawek |
| TypeScript | `./node_modules/.bin/tsc --noEmit --pretty false` | **PASS** | exit 0 |
| unit | `npm test` | **PASS** | 9 plików, 97/97 testów |
| locale — standardowa komenda | `npm run check:locales` | **NOT RUN technicznie** | `tsx` dostał `EPERM` przy otwarciu `/tmp/tsx-1000/14.pipe`; to blokada IPC sandboxa |
| locale — równoważne uruchomienie bez IPC | `node --import tsx scripts/check-locale-parity.ts` | **PASS** | `de/es/fr/pl` zgodne z `en` |
| kolekcja Playwright | `./node_modules/.bin/playwright test --list` | **PASS** | znaleziono 1 test w 1 pliku, projekt Chromium |
| Playwright runtime | `npm run test:e2e` | **NOT RUN** | wymaga Docker backendu, env i Stripe; bez uruchomień sieciowych/instalacji |
| build | — | **NOT RUN** | poza zleconym minimum; audyt 15 zapisuje wcześniejszy build jako nieweryfikowany po zawieszeniu |

### Aktualność E2E

**FAIL.** Jedyny test otwiera `/us/en/products`, a `playwright.config.ts` czeka na `/us/en`. Aktualny router ma `[locale]`, bez segmentu kraju, zaś polski default nie ma prefiksu. Suite obejmuje tylko Desktop Chrome i jeden guest Stripe checkout dla USA; nie ma dwóch tenantów, owner flow, mobile/cross-browser, błędów płatności ani renderer/policy/consent.

Komendy dowodowe:

```text
./node_modules/.bin/playwright test --list
git log --oneline -- e2e playwright.config.ts scripts/e2e e2e-backend .github/workflows/ci.yml
find src/app -maxdepth 5 -type f -name page.tsx -o -name layout.tsx
rg -n '/us/en|\[country\]' e2e playwright.config.ts src docs README.md CLAUDE.md
```

Residual: samo poprawienie URL nie zamknie `FRONT-005`, `TENANT-003`, `PANEL-004` ani gate'ów G2/G7/G11.

## Backend — wybrane testy w izolowanej kopii

Źródła backendu nie były zapisywane. Utworzono lokalny clone baseline w `/tmp/sklepik-audit-05EtKt/repo`, użyto istniejącego `/tmp/sklepik-bundle`, lokalnego lockfile i wygenerowanej dummy app. Nie wykonano `bundle install` ani pobrania zależności.

Pierwsze `bundle check` z rootowego Gemfile bez lockfile próbowało rozwiązać indeks i zakończyło się błędem DNS. Nie zainstalowało niczego. Dalsze testy używały lokalnego `spree/api/Gemfile.lock` oraz `BUNDLE_PATH=/tmp/sklepik-bundle`; `bundle check` wtedy przeszedł.

### Tenant, auth i money API

**PASS — 218 examples, 0 failures, seed 8223.**

```text
bundle exec rspec \
  spec/controllers/concerns/spree/api/v3/store_resolution_spec.rb \
  spec/controllers/concerns/spree/api/v3/admin_authentication_spec.rb \
  spec/controllers/concerns/spree/api/v3/jwt_authentication_spec.rb \
  spec/controllers/spree/api/v3/scoped_authorization_spec.rb \
  spec/controllers/spree/api/v3/admin/base_controller_spec.rb \
  spec/controllers/spree/api/v3/admin/admin_users_controller_spec.rb \
  spec/controllers/spree/api/v3/admin/prices_controller_spec.rb \
  spec/controllers/spree/api/v3/store/carts_controller_spec.rb \
  spec/controllers/spree/api/v3/store/carts/payment_sessions_controller_spec.rb \
  spec/controllers/spree/api/v3/admin/orders/payments_controller_spec.rb \
  spec/controllers/spree/api/v3/webhooks/payments_controller_spec.rb
```

Wynik zawiera istniejące warningi deprecacyjne `Spree::PaymentMethod#stores=` oraz ostrzeżenie o przyszłej zmianie domyślnej waluty; nie były failure.

### Core money

**PASS — 38 examples, 0 failures, seed 3741** dla:

```text
../core/spec/lib/spree/money_spec.rb
../core/spec/models/spree/concerns/display_money_spec.rb
../core/spec/models/spree/concerns/vat_price_calculation_spec.rb
../core/spec/models/spree/price_history_spec.rb
```

**NOT RUN poprawnym core harness:** `payment_spec.rb` i `price_spec.rb` wymagają core shared examples `lifecycle events`; uruchomienie ich przez API spec helper zakończyło kolekcję błędem przed przykładami. `sync_eur_from_pln_spec.rb` pod API helperem wykonał 43 examples z 2 failure wynikającymi z niezaładowanej metody `.call`/próby niestubowanego NBP. Nie klasyfikuję tych dwóch jako regresji produktu; ten plik wymaga właściwej core dummy app/harness.

### Migracje

**PASS w ograniczonym zakresie SQLite.**

```text
BUNDLE_GEMFILE=.../spree/api/Gemfile RAILS_ENV=test \
  bundle exec ruby bin/rails db:drop db:create db:migrate
BUNDLE_GEMFILE=.../spree/api/Gemfile RAILS_ENV=test \
  bundle exec ruby bin/rails db:migrate
BUNDLE_GEMFILE=.../spree/api/Gemfile RAILS_ENV=test \
  bundle exec ruby bin/rails db:abort_if_pending_migrations
```

Wynik: 174/174 migracje `up`, drugi migrate bez zmian, brak pending migrations.

Residual: to nie symuluje efemerycznego ponownego skopiowania tych samych migracji pod nowymi timestampami; nie używa PostgreSQL, poprzedniej wersji danych, dwóch tenantów ani backfill post-conditions. Nie zamyka `DB-001..006`, `INFRA-001..003` ani T-04.

## Kontrole mechaniczne raportów

### Kompletność i identyfikatory

| Kontrola | Wynik | Dowód |
|---|---|---|
| liczba raportów obszarowych | **PASS** | 15/15 |
| pojedynczy H1 | **PASS** | każdy z 15 raportów i master ma dokładnie jeden H1 |
| zakres i ograniczenia | **PASS** | 15/15 zawiera jawny zakres oraz ograniczenia/nieweryfikowane elementy |
| finding IDs | **PASS** | 170 definicji headingów |
| unikalność IDs | **PASS** | 170 unikalnych, brak duplikatów |
| priorytet każdego findingu | **PASS** | 170/170 ma P0–P3; raport 03 podaje go w polu pod headingiem |
| bilans master | **PASS** | 9 P0 + 68 P1 + 77 P2 + 16 P3 = 170 |
| bilanse lokalne | **PASS** | jawne tabele 05/06/09/10/12/15 zgodne z headingami; INV podaje 0/2/4/2 |
| inwentaryzacja baseline | **PASS** | `git ls-tree`: backend 4 606, storefront 253, razem 4 859 |
| deduplikacja master | **PASS** | 14 ryzyk K-01..K-14; mapa obejmuje 170/170 findingów, brak nieznanych ID |
| P0/P1 owner/kolejność/test | **PASS na poziomie kanonicznym** | każde K ma role, etapy realizacji, gate G0–G12 i pakiet T-01–T-14 |

Użyte mechanizmy:

```text
rg --no-filename -o '^### [A-Z]+-[0-9]+'
sort | uniq -d
git ls-tree -r --name-only <baseline> | wc -l
Node parser: finding heading -> priority -> master cross-reference ranges
```

### Credential values

**PASS dla skanowanych popularnych formatów.** W raportach 01–15 i masterze znaleziono zero wartości pasujących do:

- Stripe `sk_/rk_/pk_(live|test)_...`;
- GitHub `gh*_*` i `github_pat_*`;
- AWS access key IDs;
- Google API keys;
- PEM private key headers;
- pełnych JWT.

`AUTH-001` opisuje credential, ale jawnie redaguje jego wartość. Kontrola nie jest pełnym secret scanem entropii ani historii Git; nie potwierdza rotacji produkcyjnego credentialu.

### Markdown i diff

| Kontrola | Wynik | Uwaga |
|---|---|---|
| UTF-8/text sanity | **PASS** | brak NUL, CR i tabów |
| fenced code blocks | **PASS** | parzysta liczba fence'y w każdym pliku |
| lokalne Markdown links | **PASS/NA** | raporty nie zawierają lokalnych linków Markdown wymagających rozwiązania |
| istniejące tracked diffy | **PASS** | `git diff --check` w obu repo bez wyniku |
| nowe raporty jako diff | **STYLE / do normalizacji** | `git diff --no-index --check /dev/null <raport>` zgłasza Markdown hard-break spaces; 2–44 linii na raport, głównie dwie spacje po metadanych |

Dwuspacja jest poprawnym Markdown hard break. Integrator zadeklarował jej mechaniczne usunięcie przed commitem, dlatego nie klasyfikuję jej jako finding ani failure treści audytu.

Mechaniczna kontrola 230 dokładnie wyglądających referencji `path:line` potwierdziła 166 ścieżek bezpośrednio; żadna rozwiązana referencja nie zaczynała się poza końcem pliku. Pozostałe 47 używały świadomych skrótów (`sklepik/...`, `dashboard-core/...`, `.../controller.rb`) i nie zostały automatycznie ocenione. To residual, nie 47 potwierdzonych błędów.

## Niespójności i ostrzeżenia dokumentacyjne

1. `docs/audits/README.md` podczas kontroli nie odzwierciedlał ukończonych 13–15 ani obecności mastera.
2. Raport 15 poprawnie rozpoznaje nieaktualne E2E; niezależna kontrola to potwierdziła.
3. Master po poprawce mapuje również `ARCH-007`, `ARCH-008` i `ARCH-013`; coverage wynosi 170/170.
4. Odwołania `SYS-012/015/018` w 09/10 są zdefiniowane w starszym raporcie `2026-07-08-system-wide-production-readiness-audit.md`; nie są osieroconymi ID.
5. Zielone wybrane specy nie mogą zmienić statusu P0/P1 z audytów, bo większość findings dotyczy brakujących testów black-box, błędnego scope'u świadomie utrwalonego przez istniejące testy lub nieweryfikowanego runtime.

## Residual coverage — czego nie wykonano

**NOT RUN:**

- pełne RSpec wszystkich gemów i pełne testy workspace pnpm;
- pełny core money harness dla `Payment`, `Price` i NBP sync;
- prawdziwe Store/Admin API na PostgreSQL + Redis dla dwóch tenantów;
- E2E storefrontu, dashboardu/ownera, payment providerów i webhooków;
- build storefrontu, dashboardu i artefaktu Docker;
- upgrade migration fixture, nowe timestampy efemerycznej host-app, PostgreSQL constraints i schema diff;
- property/fuzz/mutation/load/chaos;
- dependency/license/container/IaC scan;
- backup restore i DB↔R2↔provider reconciliation;
- browser smoke, axe, Lighthouse, visual, mobile, Firefox i WebKit;
- produkcyjna rotacja credentialu, runtime config, Vercel/Oracle/R2/Resend/GitHub/PSP.

Te braki są zgodne z masterem i pozostają launch gates G0–G12 oraz testami T-01–T-14. Raport nie daje podstaw do komunikatu „audyty dowodzą braku bugów” ani „platforma gotowa”.

## Stan repo po weryfikacji

**PASS — brak zmian źródeł wykonanych przez tę weryfikację.**

Status pozostał ograniczony do zastanych, nieśledzonych raportów:

- backend: `docs/audits/README.md` i raporty 01–13;
- storefront: raport 14.

Jedynym artefaktem tej pracy jest niniejszy raport w `/tmp` oraz izolowana, testowa kopia backendu w `/tmp/sklepik-audit-05EtKt`.
