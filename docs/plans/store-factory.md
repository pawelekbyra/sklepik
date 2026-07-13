# Store Factory — niezależna aplikacja per sklep (repo + Vercel per sklep)

**Status:** Active — Etap 0 wdrożony produkcyjnie i lokalnie utwardzony; Etap 1 wdrożony i naprawiony; Etap 2 (ręczny pilot) następny
**Target:** `sklepik` (control plane + provisioning), nowe repozytoria per sklep (starter wydzielony z `sklepikFront`)
**Depends on:** [`multi-store-support.md`](multi-store-support.md) — Faza 1 (zaimplementowana, fundament ról/store w Admin API)
**Supersedes:** docelowy model niezależności z [`storefront-composition-system.md`](storefront-composition-system.md) — patrz sekcja "Relacja do composition-system" niżej
**Author:** właściciel + agent (sesja 2026-07-13, na podstawie dokumentu strategicznego "Store Factory 2026" dostarczonego przez właściciela)
**Last updated:** 2026-07-13

## Summary

Decyzja właściciela (2026-07-13): docelowym, przyszłościowym modelem niezależności sklepu jest **osobna aplikacja per sklep**, nie jeden wspólny storefront z warstwą kompozycji danych. Każdy nowy sklep dostaje docelowo: własne prywatne repozytorium GitHub, własny projekt Vercel, własną domenę, własne sekrety i niezależny kod Next.js. Aplikacja nie jest kopią całego `sklepikFront`, tylko korzysta z cienkiego startera oraz wersjonowanych, wymiennych pakietów commerce (`@sklepik/*`). Centralny backend Spree (`sklepik`) pozostaje wspólnym systemem commerce i control plane; osobny backend/baza per sklep to wyższy, opcjonalny poziom izolacji (enterprise), nie standard.

To rozstrzyga pytanie postawione w `storefront-composition-system.md` ("czy pełna niezależność wizualna wymaga forka repo") na korzyść **repo per sklep jako modelu domyślnego dla niezależnych sklepów**, a nie jako "wyjątku premium". Uzasadnienie: prawdziwa niezależność (kod, deployment, własność, możliwość przekazania klientowi) wymaga osobnej aplikacji — page builder/system kompozycji ogranicza zawsze do zestawu komponentów i zachowań przewidzianych wcześniej przez platformę, niezależnie jak elastyczny.

## Relacja do composition-system

`storefront-composition-system.md` zakładał "jeden storefront, jedna baza kodu, wszystkie sklepy" jako model domyślny, z forkiem repo jako rzadkim wyjątkiem premium. Ta decyzja jest **uchylona** jako cel docelowy. System kompozycji (layout/theme jako dane) pozostaje użyteczną koncepcją, ale przesuwa się do roli **opcjonalnego, szybkiego trybu "Managed"** wewnątrz drabiny izolacji Store Factory (patrz niżej) — dla sklepów, którym wystarczy szybkie uruchomienie bez własnego kodu, nie dla docelowego modelu niezależności. `storefront-composition-system.md` zostaje zaktualizowany, żeby to odzwierciedlać, zamiast usunięty — jego szczegóły projektowe (model danych sekcji, design tokens, draft/publish) są nadal potencjalnie przydatne dla trybu Managed, gdyby ten tryb miał kiedyś powstać.

## Key Decisions (do not deviate without discussion)

1. **Repozytorium per sklep** dla trybu `independent_storefront` — właściwy model, gdy kod i wdrożenia mają być faktycznie niezależne i przekazywalne klientowi.
2. **Cienki starter, nie pełny fork.** Template (`sklepik-store-template`) tworzy tylko strukturę wyjściową. Wspólna logika (kontrakt API, SDK, headless cart/checkout) jest konsumowana jako wersjonowane pakiety `@sklepik/*`, nigdy kopiowana plik-po-pliku.
3. **Własny projekt Vercel per sklep** w trybie independent — izolowane buildy, env, domeny, preview, historia deploymentów.
4. **AI nigdy nie jest provisionerem infrastruktury.** Tworzenie repo/Vercel/env/domen/sekretów jest deterministycznym kodem platformowym. AI generuje/modyfikuje kod aplikacji sklepu wyłącznie przez branch → sandbox → testy → PR, nigdy bezpośrednim zapisem do produkcji ani wywołaniem API providerów.
5. **Aktualizacje przez wersjonowane pakiety i boty otwierające PR, nigdy przez nadpisywanie plików z template.** Update Bot otwiera PR-y aktualizujące `@sklepik/*`; nie ma prawa nadpisać indywidualnego kodu sklepu bez PR/review.
6. **Niezależność jest stopniowana (drabina izolacji), nie binarna:**
   - `managed` — wspólny/generowany standard, wspólny backend i baza. Szybkie wdrożenie bez własnego repo (dawna wizja `storefront-composition-system.md`, teraz opcja pomocnicza).
   - `independent_storefront` — własne repo + Vercel, wspólny Spree z twardym store scope. **Model docelowy/domyślny** dla sklepów chcących realną niezależność.
   - `dedicated_data` — jw. + osobna baza/storage, wspólna wersja backendu.
   - `dedicated_stack` — pełny osobny backend/DB/Redis/storage/release. Enterprise/compliance.
7. **Provisioning aplikacji to osobny, trwały workflow** (retry, kompensacje, audyt) — nie rozbudowa synchronicznego `Store#create`. `Store#create` zostaje transakcyjną operacją domenową (już zaimplementowaną w `multi-store-support.md` Faza 1); tworzenie repo/Vercel/domeny/webhooków jest osobnym `ProvisioningRun`.
8. **Repozytoria powstają w organizacji GitHub platformy, autoryzowane przez GitHub App** (nie personal access token, nie prywatne konto).

## Design Details

### Komponenty platformy

| Komponent | Odpowiedzialność | Granica |
|---|---|---|
| Control Plane (`sklepik`) | Store, użytkownicy, billing, polityki, katalog repo/deploymentów | Nie wykonuje wygenerowanego kodu |
| Provisioning Orchestrator | Trwały proces i stan kroków (start: Rails + Sidekiq + tabele `ProvisioningRun`/`ProvisioningStep`) | Nie zawiera logiki konkretnego providera |
| GitHub Provider | Repo, branch, commit, PR, ruleset, webhook | Autoryzacja wyłącznie przez GitHub App |
| Sandbox Builder | Generowanie, instalacja, build, testy, preview | Bez sekretów produkcyjnych |
| Vercel Provider | Projekt, env, domena, deployment, rollback | Adapter wymienny na innego providera |
| Compatibility Service | Macierz wersji backend × pakiety × testy | Blokuje niezgodne release |
| Update Bot | PR-y aktualizacyjne i security rollouts | Nie nadpisuje kodu sklepu bez review |

Rekomendacja orkiestracji: start na Rails + Sidekiq z jawną maszyną stanów i idempotentnymi krokami w bazie (control plane już ma Sidekiq — najkrótsza droga bez rozdzielania źródła prawdy). Migracja do Vercel Workflows/Temporal dopiero gdy pojawią się długie oczekiwania (DNS, akceptacja klienta) lub osobny zespół platformowy.

### Pakiety `@sklepik/*` (kontrakt, nie wygląd)

| Pakiet | Zakres | Może sklep zastąpić? |
|---|---|---|
| `@sklepik/contracts` | Typy OpenAPI, eventy webhook, schema manifestu | Nie — kontrakt zgodności |
| `@sklepik/commerce-sdk` | Cienki klient Store API + tenant context | Tak |
| `@sklepik/cart-core` | Headless state/operacje koszyka | Tak |
| `@sklepik/checkout-core` | Headless checkout, adaptery płatności | Tak, po testach kontraktowych |
| `@sklepik/checkout-ui` | Opcjonalny gotowy UI checkoutu | Tak, domyślnie wymienny |
| `@sklepik/webhooks` | Weryfikacja podpisu, idempotencja | Może rozszerzyć, nie osłabić |
| `@sklepik/test-contracts` | Testy API/cart/checkout/tenant isolation | Nie — wymagane przez politykę release |
| `@sklepik/observability` | Korelacja request/deployment/store | Może podmienić, zachowując sygnały |
| `@sklepik/cli` | bootstrap/validate/doctor/compatibility report | Narzędzie platformowe |

Zasada projektowa: im większy wspólny pakiet UI, tym mniej niezależny sklep. Pakiety headless i composable są priorytetem; gotowy UI to wygodna opcja, nigdy obowiązkowa warstwa. Do wspólnego core **nie** trafiają: komponenty hompage konkretnej marki, globalny Tailwind theme, routing/treści, branding, eksperymentalne integracje pojedynczych sklepów.

### Proces tworzenia sklepu (tryb `independent_storefront`)

Maszyna stanów: `pending → creating_commerce_identity → creating_repository → applying_repository_policy → generating_application → validating_in_sandbox → creating_vercel_project → configuring_environment → deploying_preview → verifying → awaiting_approval|awaiting_dns → promoting_production → active`. Każdy stan może przejść do `retrying` / `failed_recoverable` / `failed_terminal` / `cancelled`.

Idempotencja per krok: repo (`store_application_id` jako klucz), Vercel project (nazwa + `project_id`), env (upsert po nazwa+target+wersja, nigdy log wartości), domena (`domain_binding_id`, `awaiting_dns` + weryfikacja cykliczna), webhook (`store_id`+endpoint, upsert + rotacja z okresem przejściowym), deployment (commit SHA + `project_id`, brak duplikatu).

### AI pipeline (dopiero po stabilnym pilocie, patrz Migration Path)

`Brief sklepu → plan zmian → ephemeral branch → izolowany sandbox (Vercel Sandbox / Firecracker microVM) → generowanie/edycja kodu → lint+typecheck+test+build → preview deployment → browser verification → raport ryzyka i diff → pull request → akceptacja polityki/człowieka → merge i production deployment`.

Tryby: `Suggest` (tylko raport/diff), `PR` (domyślny produkcyjny), `Auto-merge safe` (tylko niskie ryzyko + zielone checks), `Emergency update` (wymuszony security PR). Klasy ryzyka zmian: niska (auto-merge możliwy) → średnia (unit+E2E+review) → wysoka (koszyk/checkout/auth/płatności — CODEOWNER + contract tests + manual approval) → krytyczna (secrets/CI/deployment policy — brak AI auto-merge).

Zasady bezpieczeństwa sandboxu: brak produkcyjnych sekretów, repo-scoped GitHub token, brak direct push do `main`, kontrolowane zależności (lockfile + skan podatności), limity zasobów, pełny audyt (`GenerationRun`: prompt, model, diff, testy, preview, decyzja merge).

### Model danych control plane (szkic)

`StoreApplication` (id, store_id, mode, status, template_version, api_contract_version, release_channel, repository_id, deployment_target_id, active_release_sha), `GitRepository`, `DeploymentTarget` + `DomainBinding`, `ProvisioningRun` + `ProvisioningStep`, `GenerationRun` + `CompatibilityReport`. Interfejsy providerów (`GitProvider`, `DeploymentProvider`) zwracają stabilne referencje/błędy domenowe — control plane nigdy nie woła bezpośrednio konkretnego endpointu Vercela z kontrolera.

### Manifest aplikacji sklepu (`store.app.json`)

Jawny plik w repo sklepu: `storeId`, `name`, `runtime`, `apiContract`, `capabilities`, `routes` (home/product/cart/checkout), `health`, `webhooks`, `releaseChannel`. Weryfikowany przez `@sklepik/cli validate`/`doctor`.

## Migration Path

**Zmiana 2026-07-13:** kolejność poniżej jest przepisana względem pierwszej wersji tego planu na bardziej optymalną — front-loaduje naprawę fundamentu (bezpieczna wielosklepowość w backendzie) przed jakimkolwiek wydzielaniem pakietów czy automatyzacją, bo audyt kodu (patrz `docs/stan-projektu.md`, `docs/engine-decisions.md`) wykrył, że fundament ma krytyczny, nieznany wcześniej bug. Etap 1 jest też odchudzony — nie budujemy od razu wszystkich ośmiu pakietów `@sklepik/*`, tylko SDK/kontrakty + testy + cienki starter; reszta (`cart-core`, `checkout-core`, `checkout-ui`, `webhooks`, `observability`, `cli`) powstaje wtedy, gdy pilot z Etapu 3 faktycznie ich potrzebuje, nie z wyprzedzeniem.

**Etap 0 — bezpieczna obsługa wielu sklepów w backendzie (WDROŻONY + lokalne utwardzenie gotowe do publikacji, 2026-07-13).** Host resolution, tenant-aware cache i backendowy EUR sync są na produkcji. Bieżący zestaw dodaje rozwiązywanie sklepu bezpośrednio z aktywnego publishable API key, odrzucanie sprzecznego hosta/`X-Spree-Store-Id`, pełniejszy kontekst `Vary`/ETag oraz atomowy bootstrap sklepu. Zweryfikowane lokalnie: 50 przykładów RSpec, 0 failures.
- ✅ Rozpoznawanie po hoście: `Spree::Stores::FindDefault` normalizuje host i dopasowuje `Store#url`, z kompatybilnym fallbackiem na default.
- ✅ Klucz API wyznacza sklep niezależnie od wcześniejszego `current_store`: `StoreResolution` wyszukuje globalnie unikalny aktywny publishable key i ustawia tenant przed autoryzacją. Sprzeczny `X-Spree-Store-Id` lub host należący do innego sklepu kończy request bez przełączenia tenantów.
- ✅ Cache tenant-aware: ETag obejmuje store/market/channel/currency/locale, a `Vary` zachowuje istniejące nagłówki i rozdziela klucz, store, channel, currency oraz locale.
- 🔶 **[udokumentowane, świadomie niezmienione]** `Spree::Base.for_store` (`base.rb:34`): cichy fallback jest load-bearing (userzy globalni świadomie — `UserMethods.for_store` zwraca `self`); zmiana na „rzucaj błąd" złamałaby wiele modeli. Dodano komentarz-ostrzeżenie w kodzie zamiast zmiany zachowania — nowy model tenant-scoped musi mieć relację na `Store`.
- ✅ `Admin::StoresController#create` jest atomowe (`save!` + `add_user` w transakcji); request spec potwierdza rollback po błędzie przypisania właściciela.
- ⬜ **[pozostaje]** Dodać pełne testy dwóch tenantów: katalog, koszyk, klienci, zamówienia, cache, klucze API — żaden nie przecieka między sklepami. (Dodano testy jednostkowe: `FindDefault` po hoście, ETag per sklep; pełny integracyjny test dwóch tenantów wciąż do napisania.)
- ✅ **[decyzja podjęta 2026-07-13]** Konta klientów: **osobne per sklep** (decyzja właściciela). To osobny, większy plan — `docs/plans/per-store-customer-accounts.md` — zależny od tego Etapu 0, częściowo w host-app (`server/`).
- 🔶 Pusty 422 jest naprawiony przez `save!` i wspólny handler `RecordInvalid`; nadal pozostaje `rswag:specs:swaggerize` dla `/admin/stores`.
- 🔶 **[backend zrobiony na gałęzi, front pozostaje]** Przenieść synchronizację cen EUR z `sklepikFront` do backendu: gotowe `Spree::Prices::SyncEurFromPln` + `Spree::Nbp::EurPlnRate` + rake `spree:prices:sync_eur_from_pln` (server-side, bez sekretu API), spec napisany. **Pozostaje (poza tym repo):** usunąć trasę `src/app/api/cron/sync-eur-prices/route.ts` + `SPREE_ADMIN_SECRET_KEY` z `sklepikFront`, zaplanować rake task (sidekiq-cron/system cron).

**Etap 1 — stabilny kontrakt backend-frontend (WDROŻONY 2026-07-13).** Rozszerzono istniejący `@spree/sdk` o typy Store Factory (bez budowania odrębnego pakietu, bez zmian w konsumentach). Zrobione:
- **Store Factory contract types** w `@spree/sdk/src/types/store-factory-contracts.ts`: `TenantId`, `ApiKey`, `StoreContext`, `MultiStoreContext`, `TenantIsolationVerification`, `WebhookEvent`, `StoreFactoryManifest` — wszystkie exportowane ze SDK pod `@spree/sdk`
- **`@sklepik/test-contracts` package** — testy izolacji tenantów (`testProductIsolation`, `testCartIsolation`, `testApiKeyScope`, `testWebhookStoreContext`) + testy API kontraktu (`testStoreContract`, `testProductsContract`, `testCartContract`, `testErrorContract`)
- Gate (gotowe do Etapu 2): `sklepikFront` da się przepiąć na nowy SDK bez zmian zachowania — typy są back-compatible, front importuje je identycznie (`import type { Product, Cart } from "@spree/sdk"`) — żaden kod frontu nie dotknięty, pure type-compatibility
- Dokumentacja: sekcja "Pakiety" opisuje role każdego z nich; testy w `test-contracts` będą uruchamiane w Etapie 2 jako weryfikacja drugiego sklepu
- **Utwardzenie 2026-07-13:** dodano brakujący importer `packages/test-contracts` do `pnpm-lock.yaml`; pakiet przepisano na rzeczywisty interfejs `@spree/sdk` (SDK rzuca błędy i używa `carts`, nie wrapperów `success/data`), usunięto fikcyjne klucze/produkty z runtime testów, a wymagane fixture'y drugiego sklepu są jawne w konfiguracji. Zweryfikowane: frozen install, typecheck, build oraz 5/5 testów jednostkowych.

**Etap 2 — ręczny sklep pilotażowy (nie rozpoczęty).** Utworzyć drugi sklep z osobnym repo, osobnym projektem Vercel, osobną domeną i kluczem, wyraźnie innym wyglądem. Sprawdzić: katalog, koszyk, checkout, wdrożenie, aktualizację przez PR, **prawdziwie wykonany rollback** (nie tylko przetestowany teoretycznie).

**Etap 3 — minimalna automatyzacja (dopiero po udanym pilocie).** `StoreApplication`, `ProvisioningRun`, kroki Sidekiq. GitHub App z krótkotrwałymi, ograniczonymi tokenami instalacyjnymi (nie długowieczny PAT).

**Etap 4 — fabryka, aktualizacje i AI (dopiero gdy deterministyczny provisioning z Etapu 3 działa stabilnie).** Automatyczne repozytoria, Vercel, domeny, Update Bot, AI Store Builder. Dedykowane backendy (`dedicated_stack`) zostają na sam koniec, na żądanie płacącego klienta.

### Definition of Done — MVP Store Factory

Dwa sklepy działają na wspólnym Spree bez żadnego przecieku danych; mogą być wdrażane niezależnie; aktualizacja pakietu core przechodzi przez PR i preview; rollback został faktycznie wykonany (nie tylko przetestowany na sucho); repozytorium sklepu można przekazać klientowi i uruchomić wyłącznie z dokumentacji (README + `.env.example`).

## Constraints on Current Work

- Etapy 0-1 są wykonane. Etap 2 (ręczny pilot) można przygotować, ale promocja prawdziwego sklepu do sprzedaży nadal wymaga domknięcia Stripe, stron prawnych i pełnego checkout E2E z `roadmap.md`.
- **Wyjątek: Etap 0 (bezpieczna wielosklepowość w backendzie) nie jest wyłącznie przygotowaniem pod Store Factory — to już dziś istniejący dług/bug** (`FindDefault` ignoruje host, cache bez identyfikatora sklepu, `for_store` cichy brak scope'u, brak transakcji w `StoresController#create`), zapisany w `docs/stan-projektu.md`. Może i powinien być naprawiony niezależnie od tempa reszty planu, bo dotyczy już zaimplementowanej (F25) wielosklepowości panelu, nie tylko przyszłych niezależnych storefrontów.
- `sklepikFront` pozostaje dziś jedynym produkcyjnym storefrontem. Następne repo może powstać wyłącznie jako jawny ręczny pilot Etapu 2, z osobnym kluczem, Vercel i wykonaniem `@sklepik/test-contracts` na dwóch realnych tenantach.
- `docs/plans/storefront-composition-system.md` pozostaje jako opis trybu `managed` — nie budować go jako alternatywnego modelu docelowego dla niezależnych sklepów.

## Open Questions

- Governance: repozytoria klientów w organizacji GitHub platformy na stałe, czy transfer własności od razu przy podpisaniu umowy premium?
- Kiedy realnie zacząć Etap 3+ (control plane/orchestrator) — po ilu ręcznie utworzonych sklepach z Etapu 2 uznajemy wzorzec za sprawdzony?
- Model cenowy warstw `managed` vs `independent_storefront` vs `dedicated_*` — kto płaci za co, nierozstrzygnięte.
- Czy `managed` (dawna wizja `storefront-composition-system.md`) w ogóle zostanie zbudowany, czy zostaje tylko koncepcją "opcji szybszej" bez realnej implementacji, dopóki nie pojawi się klient, dla którego to wystarczy?
- AI Store Builder (Etap 6): jaki model/dostawca sandboxa (Vercel Sandbox vs alternatywa), budżet na iteracje agenta.

## References

- Dokument strategiczny "Store Factory 2026" (dostarczony przez właściciela, 13 lipca 2026) — źródło tej decyzji.
- [`multi-store-support.md`](multi-store-support.md) — Faza 1, zaimplementowany fundament ról/store w Admin API, na którym opiera się control plane.
- [`storefront-composition-system.md`](storefront-composition-system.md) — zawężony do opisu trybu `managed`, patrz nota na górze tego dokumentu.
- [`../ideas/multi-store-provisioning.md`](../ideas/multi-store-provisioning.md) — wcześniejszy szkic, z którego ten plan wywodzi model provisioningu; ten dokument go zastępuje jako decyzja, nie tylko pomysł.
- Vercel — Multi-Project Platforms Concepts, Workflows, Sandbox (dokumentacja zewnętrzna, stan na 2026-07-13).
- GitHub REST API — Create a repository using a template.
