# Wielosklepowość (multi-store)

**Status:** Faza 1 zaimplementowana (kod + build/lint/frontend testy zielone; backendowy RSpec napisany, nieuruchomiony lokalnie — patrz `docs/roadmap.md` F25)
**Target:** obecny fork Spree (v3 API, `packages/dashboard`)
**Depends on:** —
**Author:** właściciel + agent (sesja 2026-07-12)
**Last updated:** 2026-07-12

## Summary

Właściciel chce zarządzać kilkoma sklepami (markami) z jednego panelu administracyjnego, z możliwością rozrostu w przyszłości do modelu, w którym obce osoby same zakładają sobie sklep (samoobsługowa platforma, płatna subskrypcja — "Model 2"). To nie jest jeden projekt, tylko trzy niezależne fazy o rosnącym zakresie:

- **Faza 1 (ten dokument, wdrażana teraz):** właściciel/admin tworzy kolejne sklepy i przełącza się między nimi z jednego panelu. Każdy sklep ma niezależne dane, role/dostęp i konfigurację. Storefront klienta pozostaje na dzisiejszym modelu (jeden deployment Vercel = jeden sklep, przez zmienne środowiskowe) — świadomie, patrz "Constraints on Current Work".
- **Faza 2 (przyszłość, nierozpoczęta):** storefront rozpoznaje sklep dynamicznie po domenie żądania zamiast po zmiennych środowiskowych ustalonych w buildzie — jeden deployment może obsłużyć wiele domen/sklepów.
- **Faza 3 (przyszłość, świadomie odłożona):** samoobsługowe zakładanie sklepu przez zewnętrznego użytkownika — rejestracja, płatność/subskrypcja, automatyczny provisioning. To już inny produkt (SaaS), nie tylko rozszerzenie panelu.

Kluczowe odkrycie podczas researchu: **fundament pod Fazę 1 w większości już istnieje** w tym forku i nie wymaga migracji bazy danych. `Spree::RoleUser` już wiąże użytkownika z konkretnym `Store` (`store_id`, dodane w `20260613000001_add_store_id_to_spree_role_users.rb`), `Spree::Ability#determine_role_names` już liczy role per `@store`, a dashboard (`packages/dashboard`) już ma routing `$storeId`, `StoreProvider` i wysyła nagłówek `X-Spree-Store-Id` na każdym żądaniu (`packages/admin-sdk/src/client.ts`). Brakuje jednego ogniwa: **Admin API ten nagłówek całkowicie ignoruje** — `current_store` w kontekście admina rozwiązuje się tak samo jak dla storefrontu klienta, po `SERVER_NAME` requestu, co zawsze zwraca jeden `default: true` store. Do tego brakuje endpointów do listowania/tworzenia sklepów (istnieje tylko singularny `resource :store` do odczytu/edycji *aktualnego* sklepu) oraz realnych danych w istniejącym, ale pustym wizualnie `store-switcher.tsx`.

## Key Decisions (do not deviate without discussion)

- **Admin API rozwiązuje `current_store` z nagłówka `X-Spree-Store-Id`, storefront (Store API) nadal po hoście.** To dwie różne publiczności: panel admina to jedno narzędzie zarządzające wieloma sklepami (musi umieć jawnie wybrać sklep niezależnie od domeny, na której jest hostowany), storefront to osobna domena per sklep (naturalnie rozwiązuje się po hoście — i to zostaje niezmienione w Fazie 1). Nie mieszamy tych dwóch mechanizmów.
- **Brak nowej kolumny/flagi "super-admin".** Bramka "kto może założyć nowy sklep" to `current_user.admin_of_any_store?` (nowa, mała metoda w `Spree::AdminUserMethods`) — czyli każdy, kto ma już rolę `admin` na choć jednym sklepie, może założyć kolejny i automatycznie staje się jego adminem (`store.add_user(current_user)`, metoda już istniejąca, używana dziś w seedzie). To jest świadomie zaprojektowane pod Fazę 3: gdy przyjdzie samoobsługa, ten sam endpoint zostaje — zmienia się tylko reguła autoryzacji (`create` przestaje wymagać istniejącej roli admina, zaczyna wymagać opłaconej subskrypcji), a nie mechanizm tworzenia sklepu.
- **Zero migracji w Fazie 1.** Model danych (`Store`, `RoleUser`, role per store) już to obsługuje. Jedyne zmiany to Admin API (resolving + dwa nowe endpointy) i dashboard (podpięcie UI pod dane, które już płyną przez istniejący `StoreProvider`).
- **Storefront (`sklepikFront`) nie zmienia się w Fazie 1.** Każdy nowy sklep dostaje na razie osobny deployment Vercel z własnymi zmiennymi środowiskowymi (`SPREE_API_URL`, `SPREE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_STORE_NAME`, itd.) wskazującymi na ten sam backend. To dziś już działa (tak powstał `sklepikkk.vercel.app`) — formalizujemy to jako świadomy, tymczasowy wzorzec, nie dług.
- **Kod sklepu (`Store#code`) musi być unikalny i podawany/generowany przy tworzeniu** — walidacja `presence: true` + unique index już istnieje; `set_default_code` nadałby wszystkim pusty `code` wartość `'default'`, co zderzyłoby się z unique index przy drugim sklepie. `StoresController#create` generuje `code` z `name.parameterize` (z suffixem przy kolizji), jeśli nie podano jawnie.

## Design Details

### Backend (`spree/api`, `spree/core`)

1. **`Spree::Api::V3::Admin::BaseController#resolve_store_from_header`** — nowy `prepend_before_action`, nie nadpisanie metody `current_store`. Jeśli request ma nagłówek `X-Spree-Store-Id`, wypełnia `@current_store` (ivar, który `current_store` z `ControllerHelpers::Store` i tak memoizuje przez `||=`) store'em znalezionym po prefixed ID; brak dopasowania → jawny `ActiveRecord::RecordNotFound` (404), nie cichy fallback na default. **Świadomie nie nadpisujemy samej metody `current_store`** — istniejący pakiet speców Admin API stubuje `current_store` przez `allow_any_instance_of(Spree::Api::V3::BaseController).to receive(:current_store)` (`spree/api/lib/spree/api/testing_support/v3/base.rb`); nadpisanie metody w podklasie po cichu wyłączyłoby ten stub w każdym istniejącym teście (metoda podklasy zawsze wygrywa z `any_instance_of` na klasie nadrzędnej), więc zamiast tego wypełniamy tylko ivar, który stub i tak omija (bo podmienia całą metodę). Bezpieczeństwo: to *nie* jest luka — `require_store_membership!` (już istnieje w `AdminAuthentication`) sprawdza, że zalogowany user faktycznie ma `RoleUser` na tym store, więc podmiana nagłówka na cudzy sklep kończy się 403, nie wyciekiem danych.
2. **`Spree::AdminUserMethods#admin_of_any_store?`** — nowa metoda: `role_users.joins(:role).where(spree_roles: { name: Spree::Role::ADMIN_ROLE }).exists?`. Używana jako bramka do tworzenia nowych sklepów (patrz Key Decisions).
3. **`Spree::Api::V3::Admin::StoresController` (nowy, plural)** — osobny od istniejącego singularnego `StoreController`:
   - `index` — `current_user.stores` (istniejące `has_many :stores, through: :role_users` w `UserRoles`), serializowane przez `Spree.api.admin_store_serializer`. Nie wymaga wybranego `current_store` — to lista *do* wyboru, nie operacja na już wybranym sklepie, więc kontroler pomija `authenticate_admin!`'s store-membership gate i wymaga tylko ważnego JWT (`require_authentication!`).
   - `create` — autoryzacja `current_user.admin_of_any_store?` (403 jeśli nie), buduje `Spree::Store.new(permitted_params)`, auto-generuje `code` gdy brak, zapisuje, potem `store.add_user(current_user)`. Zwraca `201` + serializowany store.
4. **Routing** (`spree/api/config/routes.rb`, namespace `admin`): `resources :stores, only: [:index, :create], controller: 'stores'` obok istniejącego `resource :store, only: [:show, :update]`.
5. **RSpec:** integration spec (happy path index/create, 403 na `create` bez istniejącej roli admin, 422 na duplicate `code`/brak `name`) w `spree/api/spec/integration/`, zgodnie z konwencją repo (generuje przykłady OpenAPI). Model spec dla `admin_of_any_store?`.

### Dashboard (`packages/dashboard`, `packages/dashboard-core`, `packages/admin-sdk`)

1. **`@spree/admin-sdk`** — nowy zasób `client.stores = { list(), create(params) }` obok istniejącego singularnego `client.store`.
2. **`packages/dashboard/src/hooks/use-stores.ts`** — `useQuery` listujący sklepy usera (wzorzec identyczny jak `use-order.ts`).
3. **`packages/dashboard/src/hooks/use-create-store.ts`** — mutacja przez `useResourceMutation`, z `mapSpreeErrorsToForm`.
4. **`packages/dashboard-core/src/components/store-switcher.tsx`** — podpięcie pod `useStores()`: lista rzeczywistych sklepów usera zamiast statycznej jednej pozycji, klik → nawigacja do `/$storeId` (routing już istnieje). Dodanie pozycji "Nowy sklep" na dole listy.
5. **Nowy route + formularz tworzenia sklepu** (RHF + Zod, `mapSpreeErrorsToForm`, wzorzec z innych formularzy `settings/*`) — pola: `name`, `code` (opcjonalne), `url`, `mail_from_address`, `default_country_iso`, `default_currency`, `default_locale`. Po sukcesie: redirect do `/$storeId` nowo utworzonego sklepu (setup checklist — `setup_tasks_list` — poprowadzi dalej: metoda płatności, produkty, itd., już istniejący mechanizm).
6. **i18n:** nowe klucze w `packages/dashboard/src/locales/*.json` (formularz nowego sklepu) i ewentualnie `dashboard-core/src/locales/*.json` (`admin.common.*` dla przełącznika) — we wszystkich językach repo.

## Migration Path

Brak migracji bazy danych. Kolejność wdrożenia (rollback-friendly, każdy krok samodzielnie deployowalny):

1. Backend: `current_store` header resolution + `admin_of_any_store?` (bez nowych endpointów — no-op dla istniejącego ruchu, bo dziś żaden klient nie wysyła nagłówka wskazującego na store inny niż default).
2. Backend: `StoresController#index`/`#create` + routing + specs.
3. Frontend: `admin-sdk` zasób `stores`, hooki, podpięcie `store-switcher.tsx`, formularz tworzenia.
4. Docs: `stan-projektu.md`, `roadmap.md`, `engine-decisions.md` (ten plik + krótki wpis, bo to zmiana Admin API resolution — core).

Faza 2 (storefront po domenie) i Faza 3 (self-service + billing) mają dostać własne plany w `docs/plans/` dopiero gdy właściciel zdecyduje się je zacząć — nie projektujemy ich szczegółowo teraz, żeby nie zgadywać wymagań (bramka płatności, regulamin platformy itd.) na zapas.

## Constraints on Current Work

- Nowe funkcje dodawane w innych zadaniach do modeli scoped po store (produkty, promocje, zamówienia itd.) **nie wymagają żadnych zmian** z powodu tego planu — scoping po `store_id`/`Spree::Current.store` już działa tak samo dla jednego i wielu sklepów.
- Jeśli ktoś doda kolejny endpoint Admin API, który zakłada dokładnie jeden istniejący `Store.default` zamiast `current_store` — to regresja względem tego planu, nie neutralna zmiana.
- Storefront (`sklepikFront`) nie potrzebuje żadnych zmian dopóki Faza 2 się nie zacznie — nowy sklep = nowy deployment Vercel ze swoimi env-varami, dokładnie jak dziś.

## Open Questions

- Faza 2: czy jeden deployment Next.js ma obsługiwać wiele domen (middleware rozpoznający `Host`), czy zostajemy przy "jeden deployment per sklep" na stałe? Nie rozstrzygamy teraz.
- Faza 3: model rozliczeń (Stripe Billing? Ile planów?), kto może zawiesić sklep za brak płatności, jak wygląda deprovisioning. Świadomie odłożone do decyzji właściciela.
- Czy sklepy mają mieć możliwość współdzielenia katalogu produktów (multi-store selling tego samego produktu) czy każdy sklep to w pełni odrębny katalog? Dzisiejszy model (`Product belongs_to :store`) zakłada to drugie — jeśli właściciel zechce współdzielony katalog, to osobna, większa decyzja architektoniczna.

## References

- `docs/roadmap.md` — F25.
- `spree/core/app/models/spree/role_user.rb`, `spree/core/app/models/concerns/spree/user_roles.rb`, `spree/core/app/models/spree/ability.rb` — istniejący fundament ról per-store.
- `packages/dashboard-core/src/providers/store-provider.tsx`, `packages/dashboard/src/routes/_authenticated/$storeId.tsx` — istniejący routing/provider po stronie panelu.
