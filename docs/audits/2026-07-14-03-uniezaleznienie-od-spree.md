# Audyt 03 — uniezależnienie Sklepika od Spree

**Data:** 2026-07-14
**Zakres:** `sklepik` (`9a4f6931473592cf50f782b602e8a8b34d9e482e`) i `sklepikFront` (`0f83b941f345734b3bce2163a2329bae22a40b2d`)
**Tryb:** statyczny audyt kodu, kontraktów i dokumentacji; bez zmian kodu produktu
**Powiązanie:** F29 z `docs/roadmap.md`

## Wniosek wykonawczy

Spree jest dziś jednocześnie silnikiem, publicznym protokołem, SDK, modelem uprawnień i słownikiem kodu UI. Nie jest jeszcze wymiennym komponentem za kontrolowaną granicą. Największym problemem nie są jednak tabele `spree_*` ani namespace Ruby `Spree::`: one stanowią wewnętrzny, działający silnik i ich globalne przemianowanie byłoby operacją wysokiego ryzyka bez wartości dla użytkownika. Problemem są przecieki silnika do storefrontu, dashboardu, publicznych nagłówków/cookies/webhooków, zmiennych wdrożeniowych oraz nowych modułów Store Factory.

Rekomendowana droga to wprowadzenie kontraktów `Sklepik` i dwóch adapterów (`commerce-store` oraz `commerce-admin`), a następnie migracja konsumentów od zewnątrz do środka. Stare nazwy muszą pozostać obsługiwane przez wersjonowane okresy zgodności. Nie wykonywać globalnego rename namespace'ów, tabel, gemów ani protokołu na działającej produkcji.

## Metoda i ograniczenia

Przeszukano śledzone pliki obu repozytoriów przez `rg`, z pominięciem lockfile'ów przy liczeniu wystąpień zależności. Wyniki obejmują kod, testy i dokumentację, więc liczby opisują powierzchnię migracji, nie liczbę niezależnych błędów. Nazwy tabel policzono osobno z deklaracji `create_table` w migracjach. Audyt nie wykonywał zapytań do produkcyjnej bazy, rejestru npm, Vercela ani działających webhooków; okresy kompatybilności trzeba potwierdzić telemetrycznie przed usunięciem aliasów.

## Inwentaryzacja i klasyfikacja

| Powierzchnia | Pomiar na audytowanym commicie | Klasyfikacja | Decyzja |
|---|---:|---|---|
| Ruby `Spree::` w `sklepik` | 10 476 wystąpień / 1 968 plików | `ISOLATE` | Pozostawić wewnątrz engine; nowe moduły domenowe nie mogą importować namespace'u bez adaptera. |
| Ruby `Spree::` w `sklepikFront` | 10 wystąpień / 4 pliki | `REPLACE` | Usunąć klasy Ruby z kontraktów/komentarzy i mapowania gatewayów; API ma zwracać stabilne identyfikatory. |
| Gemy i pakiety `spree-*`, `spree_*`, `@spree/*` | backend: co najmniej 8 własnych pakietów `@spree/*`; storefront: `@spree/sdk` i `@spree/cli` | `ISOLATE` + `REPLACE` | Gemy pozostają implementacją engine; konsumenckie pakiety zastąpić `@sklepik/*`, początkowo jako fasady nad istniejącymi klientami. |
| Tabele `spree_*` | 131 unikalnych tabel tworzonych w 145/170 migracjach core | `KEEP` + `HARDEN` | Bez rename. Dostęp z nowych modułów tylko przez repozytoria/porty; przyszła wymiana silnika przez migrację danych, nie kosmetykę. |
| Migracje | 170 plików w `spree/core/db/migrate` | `KEEP` + `HARDEN` | Zachować kompatybilność i idempotencję; dodać test instalacji/upgrade/rollback przed zmianą schematu. |
| Eventy | `Spree::Event`/event infrastructure: 209 trafień w 49 plikach; publiczne nazwy typu `order.completed`, `product.updated` są już domenowe | `ISOLATE` + `KEEP` | Zachować domenowe nazwy eventów, ukryć klasę/event store i wersjonować payloady w kontrakcie Sklepika. |
| Publiczne nagłówki | 12 rozpoznanych nazw `X-Spree-*` | `REPLACE` z aliasem | Wprowadzić `X-Sklepik-*`; przez okres zgodności przyjmować oba, emitować deprecation/telemetrię, potem wyłączyć stare. |
| Cookies/local storage | m.in. `_spree_cart_token`, `_spree_jwt`, `_spree_refresh_token`, `spree_country`, `spree_locale`, `spree-admin-locale`, `spree_completed_order_` | `REPLACE` z dual-read | Nowe zapisy pod nazwami Sklepika, odczyt stary→nowy z migracją przy request/login; nie wylogowywać klientów ani nie gubić koszyków. |
| Zmienne env | storefront: 4 nazwy i 46 wystąpień (`SPREE_API_URL`, `SPREE_PUBLISHABLE_KEY`, `SPREE_URL`, `SPREE_WEBHOOK_SECRET`); backend m.in. 18 unikalnych nazw | `REPLACE` z fallbackiem | `SKLEPIK_*` jako kanon; przez co najmniej dwa cykle deployu fallback do `SPREE_*` i ostrzeżenie bez wypisywania wartości. |
| Storefront SDK/importy | `@spree/sdk` w 82 plikach `src`; cały wzorzec `@spree/` w 91 plikach repo | `REFACTOR` | Jeden port `src/lib/commerce` i typy domenowe; komponenty nie importują SDK. |
| Backend dashboard SDK/importy | zależności `@spree/admin-sdk`, `@spree/dashboard-core`, `@spree/dashboard-ui` przenikają aplikację | `REFACTOR` | `@sklepik/admin-client`, `@sklepik/dashboard-*`; najpierw aliasy workspace/export maps, później fizyczne przeniesienie. |
| Nazwy katalogów | backend: 3 501 ścieżek z segmentem Spree; w tym 54 pliki `dashboard/src/components/spree` i 37 w `dashboard-ui/src/spree`; storefront: 10 ścieżek, w tym 8 plików `src/lib/spree` | engine `KEEP`, konsumenci `REPLACE` | Nie ruszać `spree/core`/`spree/api`; nowe/adaptowane katalogi UI przenosić modułami do `commerce`/`sklepik`. |
| Public branding i docs | architektura, README, CLAUDE i deploy jawnie instruują użytkowników/operatorów nazwami Spree | `REFACTOR` | Dokumentacja silnikowa może nazywać implementację; onboarding, public API, UI i runbooki operatora mają używać języka Sklepika. |
| Webhooki | route `/api/webhooks/spree`; nagłówki `X-Spree-Webhook-*`; SDK verifier `@spree/sdk/webhooks` | `REPLACE` z równoległą obsługą | Nowy endpoint `/api/webhooks/sklepik`, nowy zestaw nagłówków i wersja payloadu; stary endpoint deleguje do tego samego handlera. |

### Dowody reprezentatywne

- `sklepikFront/src/lib/spree/config.ts` tworzy klienta bezpośrednio z `@spree/sdk` i czyta `SPREE_API_URL`/`SPREE_PUBLISHABLE_KEY`.
- `sklepikFront/src/lib/spree/cookies.ts` ustala produkcyjne nazwy `_spree_cart_token`, `_spree_jwt`, `_spree_refresh_token`.
- `sklepikFront/src/lib/utils/payment-gateway.ts` mapuje publiczną wartość API `Spree::Gateway::StripeGateway` na typ UI. Jest to bezpośredni przeciek klasy Ruby do checkoutu.
- `sklepikFront/src/app/api/webhooks/spree/route.ts` oraz `src/lib/spree/webhooks.ts` utrwalają nazwę engine w URL i protokole webhooka.
- `sklepik/packages/dashboard-core/src/lib/permissions.ts` koduje 33 subjecty w postaci klas `Spree::*`, np. `Spree::Product`, `Spree::Order`, `Spree::Store`.
- `sklepik/packages/dashboard/src/components/spree/categories/category-form.tsx` wysyła `resourceType="Spree::Taxon"`; backendowy model autoryzacji/metafields przecieka do formularza produktu.
- `sklepik/spree/api/app/services/spree/webhooks/deliver_webhook.rb` emituje `X-Spree-Webhook-Signature`, `Timestamp` i `Event`.
- `sklepik/docs/architektura.md` definiuje publiczny Store API przez `X-Spree-API-Key`, a wdrożenie storefrontu przez `SPREE_*`.
- Manifesty `packages/{sdk,admin-sdk,dashboard,dashboard-core,dashboard-ui,sdk-core,cli,docs}/package.json` publikują namespace `@spree/*` jako kontrakt modułowy platformy.

## Docelowa granica adaptera

```text
Storefront UI / Dashboard UI / Agenci / Store Factory
                │ wyłącznie typy i operacje Sklepika
                ▼
 @sklepik/contracts + @sklepik/store-client + @sklepik/admin-client
                │
     ┌──────────┴──────────┐
     │ porty domenowe      │ Products, Cart, Checkout, Orders,
     │                     │ Payments, Stores, Identity, Webhooks
     └──────────┬──────────┘
                ▼
      adapters/spree (jedyna dozwolona strefa przecieku)
      - mapowanie typów i błędów
      - mapowanie subjectów uprawnień
      - tłumaczenie nagłówków/cookies/env
      - mapowanie gateway identifiers
      - wersjonowanie eventów i webhooków
                ▼
        Spree API / Spree::* / spree_* tables
```

Kontrakt Sklepika powinien mieć własne identyfikatory domenowe (`product`, `order`, `stripe`, `store`), kopertę błędów, pagination, prefixed IDs i wersję webhook payloadu. Adapter może początkowo delegować 1:1 do obecnych SDK; ważne jest, by żaden komponent, agent ani nowy moduł nie znał `@spree/*`, `Spree::*` ani `spree_*`.

### Reguły egzekwowania

1. `@spree/*` dozwolone tylko w pakietach/katalogach adaptera i kodzie samego engine.
2. `Spree::*` niedozwolone w JSON, TypeScript, UI, promptach agentów i nowych publicznych eventach.
3. Tabele `spree_*` dostępne wyłącznie przez modele/repozytoria engine; bez SQL z modułów Sklepika.
4. CI blokuje nowe wystąpienia według allowlisty z właścicielem i datą przeglądu, zamiast wymagać natychmiastowego zera.
5. Każda zmiana kontraktu ma test consumer-driven dla storefrontu i dashboardu oraz fixture kompatybilności poprzedniej wersji.

## Etapowa migracja bez przerwy dla sklepów

### Etap 0 — zamrożenie i obserwowalność

- utrwalić dwa commity z nagłówka jako baseline;
- dodać allowlistę istniejących przecieków i regułę „brak nowych”;
- mierzyć użycie starych nagłówków, env, webhook URL-i i cookies bez logowania tokenów;
- zamrozić publiczne payloady jako fixtures kontraktowe.

### Etap 1 — kontrakty i fasady

- utworzyć `@sklepik/contracts`, `@sklepik/store-client`, `@sklepik/admin-client` jako cienkie fasady;
- wystawić własne typy, błędy, subjecty i identyfikatory gatewayów;
- zachować obecne endpointy i payloady pod adapterem;
- nowe funkcje mogą importować wyłącznie fasady Sklepika.

### Etap 2 — migracja konsumentów

- storefront: przenieść `src/lib/spree` do `src/lib/commerce/adapters/spree`, a komponenty przełączyć domenami: katalog → konto → koszyk → checkout;
- dashboard: najpierw permissions/metafields, potem hooks i formularze, następnie pakiety UI;
- utrzymać krytyczną ścieżkę checkoutu za flagą i testować stary/nowy adapter równolegle na tych samych fixtures.

### Etap 3 — kompatybilny protokół publiczny

- nagłówki: przyjmować `X-Sklepik-*` i `X-Spree-*`; konflikt wartości ma kończyć się 400, nigdy cichym wyborem;
- cookies: dual-read, write-new, rotacja po udanym odczycie; stare sesje i koszyki zachowują ważność;
- env: `SKLEPIK_*` ma pierwszeństwo, `SPREE_*` fallback; konflikt blokuje boot;
- webhooki: oba URL-e i oba zestawy nagłówków kierują do jednego verifiera; dostawy mają idempotency key niezależny od aliasu;
- co najmniej jeden pełny cykl aktualizacji floty i 30 dni bez użycia legacy przed wyłączeniem aliasu; rzeczywisty próg zatwierdzić na podstawie telemetryki.

### Etap 4 — pakiety, katalogi i branding

- publikować `@sklepik/*`; `@spree/*` pozostawić jako deprecated re-export przez ustalony okres;
- zmieniać katalogi UI modułami, bez jednego globalnego commita;
- usunąć Spree z UI, onboardingów, komunikatów błędów i dokumentacji operatora;
- pozostawić jawne „Spree adapter/engine” w dokumentacji technicznej i rejestrze decyzji.

### Etap 5 — izolacja silnika i opcjonalna wymiana

- namespace Ruby i tabele pozostają bez zmian, dopóki realna wymiana engine nie ma uzasadnienia biznesowego;
- przed wymianą zbudować eksport/import kanonicznego modelu Sklepika, reconciliation pieniędzy i zamówień, dry-run oraz rollback;
- migrować bounded contextami, nigdy globalnym rename; księgowe dane historyczne pozostają audytowalne.

## Findings

### SPREE-001 — Brak jednej granicy SDK w storefroncie

**Priorytet:** P1
**Wpływ:** 82 pliki źródłowe importują bezpośrednio `@spree/sdk`; komponenty, data actions, analytics i testy zależą od typów konkretnego engine. Wymiana lub wersjonowanie kontraktu wymaga zmian w całej aplikacji i checkoutcie.
**Dowód:** `sklepikFront/src/components/**`, `src/lib/data/**`, `src/lib/analytics/gtm.ts`, `src/contexts/**`; `package.json`.
**Naprawa:** porty domenowe i `@sklepik/store-client`, z adapterem będącym jedynym importerem `@spree/sdk`.
**Kryterium zamknięcia:** poza katalogiem adaptera i jego testami `rg '@spree/sdk' src` nie zwraca wyników; kontrakty katalogu, koszyka, checkoutu i konta przechodzą na obu implementacjach.

### SPREE-002 — Klasy Ruby są częścią kontraktu checkoutu i panelu

**Priorytet:** P1
**Wpływ:** frontend rozpoznaje gateway po `Spree::Gateway::*`, a dashboard wysyła/porównuje 33 `Spree::*` subjecty. Rename lub wymiana engine psuje płatności, permissions i custom fields.
**Dowód:** `sklepikFront/src/lib/utils/payment-gateway.ts`; `sklepik/packages/dashboard-core/src/lib/permissions.ts`; `sklepik/packages/dashboard/src/components/spree/categories/category-form.tsx`.
**Naprawa:** API zwraca `provider: stripe|adyen|paypal` i domenowe subjecty; adapter tłumaczy je do klas engine.
**Kryterium zamknięcia:** żadna odpowiedź publiczna ani plik TS poza adapterem nie zawiera `Spree::`; testy permission matrix i wszystkich gatewayów przechodzą.

### SPREE-003 — Nazwa engine jest częścią wdrożonego protokołu klientów

**Priorytet:** P1
**Wpływ:** jednostronny rename 12 nagłówków, cookies lub webhooków wyloguje klientów, zgubi koszyki, odrzuci requesty albo zatrzyma e-maile/inwalidację cache.
**Dowód:** `sklepikFront/src/lib/spree/{cookies,middleware,webhooks}.ts`; `sklepik/spree/api/app/services/spree/webhooks/deliver_webhook.rb`; `sklepik/docs/architektura.md`.
**Naprawa:** kompatybilność dual-read/write-new, jawna obsługa konfliktu, telemetryka i wersjonowanie webhooków.
**Kryterium zamknięcia:** E2E potwierdza stary i nowy klient, zachowanie istniejącego koszyka/sesji oraz dokładnie jedną obsługę webhooka przy retry; wyłączenie legacy dopiero po uzgodnionym oknie zerowego użycia.

### SPREE-004 — Zmienne `SPREE_*` wiążą provisioning i operacje z implementacją

**Priorytet:** P2
**Wpływ:** Store Factory generuje konfigurację konkretnego engine; zmiana nazw bez fallbacku może wyłączyć wszystkie deploye floty.
**Dowód:** 46 wystąpień czterech nazw w `sklepikFront`; m.in. `Dockerfile`, `src/lib/spree/config.ts`, `docs/deployment-vercel.md`; backend używa m.in. `SPREE_PATH`, `SPREE_API_URL`, `SPREE_PUBLISHABLE_KEY`.
**Naprawa:** kanoniczne `SKLEPIK_*`, centralny resolver konfiguracji i migracja szablonów provisioningowych.
**Kryterium zamknięcia:** nowe sklepy dostają wyłącznie `SKLEPIK_*`; stare deploye bootują z legacy fallbackiem; konflikt obu nazw z różnymi wartościami bezpiecznie blokuje start.

### SPREE-005 — Publiczne pakiety `@spree/*` są platformą aplikacyjną, nie tylko adapterem

**Priorytet:** P2
**Wpływ:** SDK, admin SDK, dashboard core/UI, CLI i docs utrwalają upstreamową markę oraz pozwalają nowym modułom omijać przyszłą granicę.
**Dowód:** manifesty ośmiu pakietów oraz importy w `packages/dashboard*`.
**Naprawa:** pakiety `@sklepik/*` i okresowe deprecated re-exporty `@spree/*`; zakaz nowych zależności na stare nazwy.
**Kryterium zamknięcia:** wszystkie first-party consumers używają `@sklepik/*`; re-exporty mają test zgodności, termin i właściciela; nowe wystąpienie `@spree/*` łamie CI poza allowlistą.

### SPREE-006 — Struktura katalogów UI sugeruje, że kod produktu należy do engine

**Priorytet:** P3
**Wpływ:** 54 pliki dashboardu i 37 plików UI pod `src/**/spree` mieszają funkcje Sklepika z adapterem; utrudnia to ownership i automatyczne egzekwowanie granicy.
**Dowód:** `packages/dashboard/src/components/spree`, `packages/dashboard-ui/src/spree`; storefront `src/lib/spree`.
**Naprawa:** przenosić bounded contextami do `commerce`/`sklepik`, pozostawiając w `adapters/spree` tylko translację.
**Kryterium zamknięcia:** katalog adaptera nie zawiera komponentów ani reguł produktu; dependency graph zabrania importów adapter → UI.

### SPREE-007 — Schemat danych silnika ma dużą powierzchnię i nie ma bezpiecznej ścieżki globalnego rename

**Priorytet:** P1
**Wpływ:** 131 tabel `spree_*` w 145 migracjach zawiera dane zamówień, płatności i tenantów. Globalny rename grozi downtime'em, rozjazdem migracji efemerycznego startera, utratą kompatybilności oraz błędami reconciliation.
**Dowód:** `sklepik/spree/core/db/migrate` (170 plików); zasada idempotentnych migracji w `sklepik/CLAUDE.md`.
**Naprawa:** pozostawić schemat, odciąć go portami; każda przyszła migracja engine wymaga restore rehearsal, reconciliation i rollbacku.
**Kryterium zamknięcia:** nowe moduły Sklepika nie wykonują SQL ani nie deklarują powiązań do `spree_*` poza adapterem; test instalacji, upgrade i restore przechodzi na kopii danych.

### SPREE-008 — Eventy mają dobre nazwy domenowe, ale niewersjonowany payload zależy od serializerów engine

**Priorytet:** P2
**Wpływ:** nazwy `order.completed`/`product.updated` mogą pozostać, lecz payload i verifier pochodzą bezpośrednio ze Spree; zmiana serializera może po cichu złamać e-maile i cache storefrontu.
**Dowód:** `sklepik/spree/core/app/models/spree/event.rb`; `sklepik/spree/api/app/services/spree/webhooks/deliver_webhook.rb`; `sklepikFront/src/lib/webhooks/handlers.ts`.
**Naprawa:** koperta `sklepik_event_version`, stabilne schemas i adapter serializera; consumer contract fixtures.
**Kryterium zamknięcia:** każdy publiczny event ma wersję, schema i test konsumenta; zmiana serializera engine bez zmiany kontraktu nie zmienia fixture publicznego.

### SPREE-009 — Dokumentacja operacyjna nadal uczy obchodzenia planowanej granicy

**Priorytet:** P3
**Wpływ:** agenci i operatorzy będą nadal tworzyć `SPREE_*`, `X-Spree-*` i bezpośrednie importy, nawet po dodaniu adaptera.
**Dowód:** oba `CLAUDE.md`, `sklepik/docs/architektura.md`, `sklepikFront/docs/deployment-vercel.md`, README pakietów.
**Naprawa:** po wdrożeniu fasad zaktualizować instrukcje, przykłady i szablony; techniczną nazwę engine zachować wyłącznie w sekcji implementacyjnej.
**Kryterium zamknięcia:** copy/paste z dokumentacji tworzy kod korzystający z `@sklepik/*`; publiczny onboarding i runbooki nie wymagają wiedzy o Spree.

## Priorytety realizacji

1. **Teraz:** SPREE-001, SPREE-002 i reguła „brak nowych przecieków”; to zatrzymuje wzrost długu bez ruszania produkcyjnych danych.
2. **Następnie:** SPREE-003 i SPREE-008 z testami kompatybilności, bo dotyczą sesji, koszyków, checkoutu i webhooków.
3. **Potem:** SPREE-004, SPREE-005, SPREE-006 i SPREE-009, iteracyjnie wraz z aktualizacją floty.
4. **Stale:** SPREE-007 jako ograniczenie bezpieczeństwa. Rename schematu nie jest kryterium ukończenia F29.

## Warunek zamknięcia audytu / F29

Audyt jest zamknięty po przyjęciu findings do backlogu z właścicielami. F29 można uznać za zakończone dopiero, gdy UI, agenci, Store Factory i publiczne integracje używają kontraktów Sklepika; bezpośrednie zależności od Spree występują wyłącznie w jawnie nazwanym adapterze i engine; wszystkie aliasy legacy mają telemetrykę, właściciela oraz datę przeglądu; a zgodność danych, zamówień, pieniędzy, sesji i webhooków jest potwierdzona testami oraz próbą rollbacku.
