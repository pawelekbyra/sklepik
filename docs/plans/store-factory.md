# Store Factory — niezależna aplikacja per sklep (repo + Vercel per sklep)

**Status:** Superseded (2026-07-17) — patrz nota niżej. Zachowany jako materiał historyczny/referencyjny, nie jako aktywny plan.
**Target (historyczny):** `sklepik` (control plane + provisioning), nowe repozytoria per sklep (starter wydzielony z `sklepikFront`)
**Depends on:** [`multi-store-support.md`](multi-store-support.md) — Faza 1 (zaimplementowana, fundament ról/store w Admin API)
**Superseded by:** [`storefront-composition-system.md`](storefront-composition-system.md) — model docelowy od 2026-07-17
**Author:** właściciel + agent (sesja 2026-07-13, na podstawie dokumentu strategicznego "Store Factory 2026" dostarczonego przez właściciela)
**Last updated:** 2026-07-17 (nota o odrzuceniu)

## Nota o zmianie decyzji (2026-07-17)

**Właściciel odrzucił model "repo + Vercel per sklep" jako domyślną ścieżkę** — decyzja świadoma i definitywna ("to była zła decyzja, chcę ją uciąć"), podjęta po dziewięciu niezależnych research-passach nad branżowymi wzorcami multi-tenant SaaS. Kluczowe ustalenie: główne realne wzorce (Shopify, Vercel Platforms Starter Kit, duże wdrożenia WordPress) domyślnie renderują wielu najemców z jednego wspólnego runtime'u — separacja kodu per klient jest kosztownym wyjątkiem (case study Spotify: bez dedykowanego narzędzia propagacja jednej zmiany na 70% repo zajmowała 6+ miesięcy), nie standardem, a ten projekt nie ma zasobów jednego zespołu Spotify.

**Nowy model docelowy:** [`storefront-composition-system.md`](storefront-composition-system.md) — jeden współdzielony storefront, layout jako dane, `/admin` jako chroniona trasa tej samej aplikacji. Ten dokument zostaje jako:
1. materiał historyczny (uzasadnienie tamtej decyzji, do zrozumienia dlaczego coś zostało napisane tak jak zostało),
2. potencjalne źródło pomysłów na przyszły, opcjonalny, płatny tier izolacji (`dedicated_data`/`dedicated_stack` z drabiny niżej) dla klientów enterprise, którzy realnie potrzebują osobnego backendu — ale **nie jako model domyślny**.

**Kod napisany pod ten plan** (`Spree::ProvisioningRun`/`ProvisioningStep`, `Spree::Provisioning::{GithubClient,VercelClient,ProvisionStore}`, Sidekiq job, endpoint `.../stores/:id/provisioning_run`, UI w `/$storeId/new-store`) **zostaje legacy** — nie rozwijać dalej, nie usuwać od razu (uprzątnięcie po ustabilizowaniu nowego modelu, żeby nie tracić działającego kodu na wypadek, gdyby jednak przydał się jako fundament przyszłego tieru enterprise). Nie kontynuować Etapu 2 (ręczny pilot) ani żadnego dalszego etapu tego planu.

Reszta tego dokumentu opisuje odrzuconą decyzję z 2026-07-13 — zachowana bez zmian jako zapis historyczny.

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

**Etap 2 — ręczny sklep pilotażowy (w toku, przygotowanie 2026-07-13).** Utworzyć drugi sklep z osobnym repo, osobnym projektem Vercel, osobną domeną i kluczem, wyraźnie innym wyglądem. Sprawdzić: katalog, koszyk, checkout, wdrożenie, aktualizację przez PR, **prawdziwie wykonany rollback** (nie tylko przetestowany teoretycznie).

_Sesja 2026-07-13 — właściciel chce od razu zautomatyzować provisioning (przeskoczyć czysto ręczny pilot), ale uruchomienie się nie powiodło z sesji zdalnej (Claude Code na webie) — właściciel dokończy lokalnie. Co zostało ustalone i przygotowane:_

- **Ograniczenie środowiska zdalnego (ważne dla każdego agenta pracującego z sesji web/cloud):** ta konkretna sesja miała proxy blokujące GitHub API do repozytoriów spoza jej skonfigurowanego zasięgu (`sklepik`, `sklepikFront`) — **łącznie z tworzeniem nowych repo**, zarówno przez dedykowane narzędzie GitHub tej platformy (403 "Resource not accessible by integration" — brak uprawnień integracji), jak i przez surowe API z tokenem właściciela (403 "sessions are bound to their configured repositories"). To ograniczenie sesji, nie tokena ani konta. **Lokalny Claude Code (terminal) tego nie ma** — łączy się z internetu bezpośrednio.
- **Token GitHub (fine-grained PAT) i token Vercel od właściciela zweryfikowane działające** w tamtej sesji: GitHub token poprawnie autoryzował się jako `pawelekbyra` (ale operacje poza whitelistą i tak blokowało proxy, nie token). Vercel token ma pełny dostęp bez ograniczeń — potwierdzone realnymi wywołaniami API (patrz niżej).
- **Zmapowane i zweryfikowane API Vercela** (live test, projekt utworzony i natychmiast skasowany):
  - `POST https://api.vercel.com/v11/projects?teamId={team}` z body `{"name":..., "framework":"nextjs"}` → `200`, tworzy projekt. Team właściciela: `team_sc16PptMTGc4ip47phctR79J` (`pawelperfect-5617's projects`, plan hobby).
  - `DELETE https://api.vercel.com/v9/projects/{id}?teamId={team}` → `204`.
  - Istniejące projekty `sklepik_back`/`sklepik_front` potwierdzają konwencję nazewnictwa i pokazują kształt `link` dla repo podpiętego przez GitHuba: `{"type":"github","repo":"sklepikFront","repoId":...,"org":"pawelekbyra","repoOwnerId":...,"gitCredentialId":...}` — **niezweryfikowane, czy tworzenie projektu z gołym `{"type":"github","repo":"owner/repo"}` (bez `gitCredentialId`) samo się rozwiąże względem istniejącej instalacji GitHub App Vercela, czy wymaga dodatkowego kroku.**
  - **Praktyczna pułapka do sprawdzenia przed pierwszym realnym uruchomieniem:** integracja GitHub App Vercela na koncie właściciela może być ograniczona do wybranych repozytoriów ("Only select repositories") zamiast wszystkich — jeśli tak, nowo utworzone repo trzeba ręcznie dodać w `https://github.com/settings/installations` → Vercel → Configure, zanim Vercel API zdoła je podpiąć pod projekt.
- **Gotowy skrypt do uruchomienia lokalnie:** [`scripts/provision-store.sh`](../../scripts/provision-store.sh) — kopiuje `sklepikFront` jako template do nowego repo (`gh repo create ... --push`), tworzy powiązany projekt Vercel, ustawia `SPREE_API_URL`/`SPREE_PUBLISHABLE_KEY`/`NEXT_PUBLIC_STORE_NAME`. Wymaga lokalnie: `gh auth login`, `VERCEL_TOKEN`, `SPREE_PUBLISHABLE_KEY` nowego sklepu (założyć wcześniej w adminie). Krok 5 (wyzwolenie deploya przez API) jest **niezweryfikowany** — dziś skrypt polega na auto-deployu Vercela po pushu albo na ręcznym kliknięciu w dashboardzie; payload `POST /v13/deployments` do dograna, jeśli automatyczny trigger zawiedzie.
- **Cienki starter (`sklepik-store-template`) nadal nie istnieje** — świadomy skrót: kopiujemy cały `sklepikFront` jako template, refaktor do wersjonowanych pakietów `@sklepik/*` zostaje na później (zgodnie z pierwotnym planem — nie budować z wyprzedzeniem).

_Tej samej sesji, później 2026-07-13 — właściciel poprosił o przeskoczenie prostego skryptu i napisanie od razu docelowego mechanizmu (Etap 3 lite) w backendzie, mimo że skrypt (wyżej) nigdy nie został uruchomiony na żywo. Zaimplementowane, zcommitowane, **całkowicie nieprzetestowane end-to-end** (to samo ograniczenie sesji — zero możliwości utworzenia realnego repo z tej sesji):_

- **Backend:** `Spree::ProvisioningRun`/`Spree::ProvisioningStep` (migracje `20260714000001`/`002`), `Spree::Provisioning::GithubClient`/`VercelClient` (Net::HTTP, wzorowane na `Spree::Nbp::EurPlnRate` i `Spree::Webhooks::DeliverWebhook`), `Spree::Provisioning::ProvisionStore` (orkiestrator, synchroniczny w obrębie joba — nie osobna maszyna stanów z resumpcją, to świadomie uproszczone względem pełnego modelu `ProvisioningRun`/`ProvisioningStep` z sekcji "Design Details" wyżej), `Spree::Provisioning::ProvisionStoreJob` (Sidekiq). Nowy endpoint: `POST`/`GET /api/v3/admin/stores/:store_id/provisioning_run` (singleton, nie kolekcja — jeden aktywny attempt na raz).
- **Sekrety wymagane na serwerze** (`ENV`, nie `Spree::Config` — patrz `Spree::Provisioning::Settings`): `GITHUB_PROVISIONING_TOKEN`, `VERCEL_TOKEN`, `VERCEL_TEAM_ID` (domyślnie `team_sc16PptMTGc4ip47phctR79J` jeśli nieustawione — **to jest team właściciela z tej sesji, nadpisać jeśli inny**), opcjonalnie `GITHUB_PROVISIONING_OWNER`/`GITHUB_PROVISIONING_TEMPLATE_REPO`/`SPREE_API_URL`.
- **Ważna różnica względem `scripts/provision-store.sh`:** kod backendu NIE robi `git clone`+`push` — używa endpointu GitHub „generate a repository from a template” (`POST /repos/{owner}/{repo}/generate`), czystsze z Rails (bez procesu `git`/tempdirów), ale **wymaga, żeby `sklepikFront` miał w Ustawieniach → General włączony przełącznik „Template repository”** na GitHubie. To jednorazowa ręczna zmiana, którą trzeba zrobić przed pierwszym uruchomieniem — kod nie potrafi (i nie próbuje) włączyć tego sam.
- **Frontend:** `adminClient.provisioningRun.{start,status}` w `@spree/admin-sdk` (typy ręczne w `packages/admin-sdk/src/types/provisioning.ts` — **do przeniesienia do `generated/` po uruchomieniu `rake typelizer:generate` w środowisku z działającym Railsem**, ta sesja tego nie miała), hooki `useProvisioningStatus`/`useStartProvisioning` (`dashboard-core`, polling co 3s aż do stanu `active`/`failed`), formularz `/$storeId/new-store` ma nowy checkbox „utwórz automatycznie storefront” i po zaznaczeniu przełącza się na `ProvisioningStatusCard` (checklista 4 kroków + link do gotowego `*.vercel.app`) zamiast nawigować od razu do panelu sklepu.
- **Publiczny onboarding (2026-07-13):** `/signup` w dashboardzie wywołuje `adminClient.auth.signup`; publiczny `POST /api/v3/admin/auth/signup` atomowo tworzy konto admina, sklep, rolę właściciela i provisioning run, ustawia sesję JWT/refresh cookie oraz enqueue'uje Sidekiq. Endpoint jest domyślnie wyłączony przez `STORE_SIGNUP_ENABLED=false`, ma ten sam rate limit co logowanie i waliduje hasło po stronie serwera (minimum 8 znaków + potwierdzenie). Sklep dostaje startowo `<code>.vercel.app`, a `ProvisionStore` po gotowym deploymencie podmienia URL na rzeczywisty host.
- **Zweryfikowane lokalnie:** test kontraktu SDK, typecheck dashboardu oraz 4 przykłady RSpec (wyłączona flaga, atomowy sukces i rola admina, rollback przy złym haśle, aktualizacja URL po deploymencie). To nie zastępuje realnego E2E z zewnętrznymi API.
- **Przed publicznym włączeniem:** potwierdzić `GITHUB_PROVISIONING_TOKEN`, `VERCEL_TOKEN`, `VERCEL_TEAM_ID`, `SPREE_API_URL`, template repo, wykonać jeden kontrolowany provisioning i ustalić ochronę przed automatycznym zakładaniem kont (weryfikacja e-mail/CAPTCHA). Do tego czasu flagę pozostawić wyłączoną.
- **Co jest zweryfikowane:** `pnpm --filter @spree/admin-sdk build` i `pnpm --filter @spree/dashboard build` przechodzą bez błędów (TypeScript się kompiluje, routing/i18n też) — **to nie jest test funkcjonalny**, tylko potwierdzenie, że kod się buduje. Klucze i18n dodane do wszystkich 6 języków panelu.
- **Co NIE jest zweryfikowane i wymaga pierwszego realnego uruchomienia lokalnie:**
  1. Czy `POST /repos/{template}/generate` faktycznie działa z fine-grained PAT (może wymagać innego zestawu uprawnień niż zwykłe repo-create).
  2. Czy `gitRepository: {type: "github", repo: "owner/repo"}` w `POST /v11/projects` Vercela samo się linkuje bez `gitCredentialId` (patrz pułapka wyżej — dodanie repo do instalacji GitHub App Vercela może być wymagane ręcznie za każdym razem, dopóki nie ma GitHub App z instalacją na całą organizację).
  3. Czy `GET /v6/deployments?projectId=...` faktycznie zwraca gotowy deployment po auto-deployu z pusha, i w jakim czasie (`wait_for_deployment` w `ProvisionStore` odpytuje co 10s, 30 razy = 5 minut limitu — może wymagać dostrojenia).
  4. Publishable API key generowany przez `publishable_key_for_store` — logika nie testowana pod RSpec w tej sesji (brak zbudowanego `test_app`/bazy).
- **Następny krok dla lokalnego agenta:** (1) ustawić sekrety w `.env` serwera, (2) włączyć „Template repository” na `sklepikFront`, (3) uruchomić migracje, (4) kliknąć „Załóż sklep” z zaznaczonym checkboxem w panelu na prawdziwym środowisku, (5) obserwować które z czterech niezweryfikowanych punktów wyżej faktycznie pękają i poprawić `Spree::Provisioning::GithubClient`/`VercelClient` na podstawie rzeczywistych odpowiedzi API — to jedyny sposób, żeby to zweryfikować, zdalna sesja nie mogła tego zrobić.

**Etap 3 — minimalna automatyzacja (kod napisany 2026-07-13, nieprzetestowany; patrz wyżej).** `ProvisioningRun`/`ProvisioningStep` + Sidekiq job istnieją. **Pozostaje z pierwotnego zakresu Etapu 3:** GitHub App z krótkotrwałymi, ograniczonymi tokenami instalacyjnymi zamiast dzisiejszego długowiecznego PAT w `GITHUB_PROVISIONING_TOKEN` — świadomy skrót na start, do zamiany przed otwarciem tego na kogokolwiek spoza właściciela.

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
