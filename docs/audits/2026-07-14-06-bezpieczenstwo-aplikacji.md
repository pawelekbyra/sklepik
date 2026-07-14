# Audyt 06: bezpieczeństwo aplikacji

**Data:** 2026-07-14
**Zakres:** repozytoria `sklepik` i `sklepikFront`, stan lokalny odpowiednio przy bazowych rewizjach `9a4f693147` i `0f83b94` oraz niecommitowanych raportach audytowych 01–05/07.
**Charakter:** przegląd defensywny kodu i konfiguracji; bez zmian produktu, bez testów destrukcyjnych i bez odczytu wartości sekretów.

## Werdykt

**Nie udostępniać jeszcze platformy prawdziwym klientom.** Audyt nie znalazł nowej, niezależnej pozycji P0, ale potwierdził cztery P1: wykonywalny HTML właściciela na publicznym storefroncie, produkcyjnie aktywną powierzchnię SSRF przez optymalizator obrazów, nieograniczone wejścia plikowe ładowane w całości do pamięci oraz mutowalny łańcuch dostaw prowadzący aż do deployu produkcji. Brak nowego P0 nie zmienia istniejących blokerów `TENANT-001`, `AUTH-001` oraz `MONEY-001..003`.

| Priorytet | Liczba nowych findings |
|---|---:|
| P0 | 0 |
| P1 | 4 |
| P2 | 4 |
| P3 | 0 |

## Metoda i granice duplikacji

- Przejrzano kontrolery Store/Admin API, wspólne concerns, modele wejść plikowych, webhooks, konfigurację Next.js, miejsca renderowania HTML, workflow CI/deploy, manifesty i lockfile'y.
- Wykonano statyczne wyszukiwania wzorców: wykonanie poleceń/deserializacja, dynamiczne klasy, surowy HTML, URL/redirect/fetch, upload/Active Storage, logowanie tokenów i danych, CORS/CSRF/headers, rate limiting oraz sygnatury sekretów. Skan nie wypisał wartości sekretów.
- Sprawdzono wcześniejsze raporty. Ustalenia o globalnych klientach, JWT/refresh, haśle produkcyjnym, idempotencji/webhookach płatności i izolacji tenantów są tylko cross-reference, nie są ponownie liczone.
- Status dowodu: **fakt** oznacza bezpośredni dowód w kodzie; **fakt konfiguracyjny** — aktywną konfigurację repo; **nieweryfikowane runtime** — wymaga środowiska produkcyjnego lub zewnętrznego skanera.

## Findings

### SEC-001 — P1 — właściciel może zapisać JavaScript wykonywany klientom storefrontu

**Status dowodu:** fakt.

Storefront wstawia bez sanitizacji `product.description` oraz wartość custom field typu `rich_text` przez `dangerouslySetInnerHTML` (`sklepikFront/src/app/[locale]/(storefront)/products/[slug]/ProductDetails.tsx:208-218`, `sklepikFront/src/components/products/ProductCustomFields.tsx:15-29`). Admin API przyjmuje `description` jako zwykły parametr (`spree/api/app/controllers/spree/api/v3/admin/products_controller.rb:183-188`), model produktu przechowuje go jako tłumaczone rich text, ale Store serializer zwraca źródłowy HTML (`spree/api/app/serializers/spree/api/v3/product_serializer.rb:48-56`). W ścieżce produktu nie znaleziono allowlistowej sanitizacji przed persystencją ani przed renderem. Komentarz „trusted source” nie jest granicą bezpieczeństwa w platformie, w której konto właściciela może zostać przejęte, a tenant nie powinien móc wykonywać dowolnego kodu w przeglądarce kupującego.

Polityki także używają `dangerouslySetInnerHTML`, lecz `body_html` pochodzi z Action Text (`sklepikFront/src/app/[locale]/(storefront)/policies/[slug]/page.tsx:56-63`, `spree/api/app/serializers/spree/api/v3/policy_serializer.rb:12-16`); ta ścieżka wymaga osobnego testu allowlisty, nie jest podstawą findingu.

**Wpływ:** stored XSS na domenie sklepu: kradzież nie-HttpOnly danych/cookies i kontekstu koszyka, phishing w checkout, wykonywanie żądań w imieniu klienta oraz trwałe przejęcie treści sklepu. Wspólny renderer powiela lukę we wszystkich tenantach.

**Naprawa:** ustanowić jeden kanoniczny kontrakt bezpiecznego rich text. Sanityzować po stronie backendu allowlistą tagów/atrybutów/protokołów i ponownie po stronie renderera (defence in depth); odrzucać `script`, event handlers, `style` o niebezpiecznych wartościach, `javascript:`/`data:` i nieznane embed. Nie polegać na tym, że autor jest adminem.

**Test zamykający:** zestaw payloadów OWASP (`script`, `img onerror`, SVG, zagnieżdżone encje, `javascript:` i CSS URL) przechodzi Admin API → Store API → prawdziwą przeglądarkę; żaden marker JS nie wykonuje się, a dozwolone formatowanie pozostaje. Test obejmuje opis, custom field i politykę.

### SEC-002 — P1 — optymalizator obrazów storefrontu ma jawnie włączone pobieranie z prywatnych adresów

**Status dowodu:** fakt konfiguracyjny; exploit na Vercelu nieweryfikowany runtime.

`next.config.ts` ustawia `images.dangerouslyAllowLocalIP: true` bez warunku środowiska, mimo komentarza „in development”, oraz dopuszcza `http://localhost/rails/active_storage/**` i wildcardowe hosty zewnętrzne (`sklepikFront/next.config.ts:26-61`). To ustawienie obowiązuje również w buildzie produkcyjnym. Next image optimizer wykonuje server-side fetch URL-a wskazanego przez klienta; prywatne IP są właśnie kontrolą, którą ta flaga wyłącza.

**Wpływ:** możliwość użycia deploymentu Vercel jako SSRF/proxy do usług osiągalnych z runtime albo do zapętlenia/zużycia zasobów. Wildcardowe domeny i DNS zmieniający odpowiedź poszerzają ryzyko poza literalny `localhost`. Zakres sieci Vercela i dokładne zachowanie bieżącej wersji Next wymagają testu runtime.

**Naprawa:** `dangerouslyAllowLocalIP` wyłącznie warunkowo w development; produkcyjna allowlista dokładnych originów CDN/backendu, bez tymczasowych wildcardów i localhost. Najlepiej serwować media przez jeden kanoniczny CDN host. Dodać egress policy/timeout/limit odpowiedzi, gdzie platforma na to pozwala.

**Test zamykający:** na preview identycznym z produkcją żądania `/_next/image` do loopback, RFC1918, link-local/metadata, IPv6 loopback, redirectu na prywatny adres i domeny DNS-rebinding są odrzucane przed fetch; poprawny URL R2/CDN działa.

### SEC-003 — P1 — importy i pliki cyfrowe nie mają limitu rozmiaru, a download/CSV ładują cały blob do RAM

**Status dowodu:** fakt.

Obrazy mają content-type i limit rozmiaru (`spree/core/app/models/spree/asset.rb:38-41`), ale `Spree::Digital` wymaga tylko obecności attachmentu (`spree/core/app/models/spree/digital.rb:10-13`). Import sprawdza wyłącznie `text/csv`, bez `byte_size`; następnie `attachment.blob.download` pobiera cały plik do String i parsuje go (`spree/core/app/models/spree/import.rb:193-207,292-296`). Publiczny download produktu cyfrowego również używa `attachment.download` i `send_data`, czyli buforuje cały blob w procesie Rails (`spree/api/app/controllers/spree/api/v3/store/digitals_controller.rb:10-16`). Limit kliknięć sprawdza i inkrementuje licznik w dwóch operacjach, więc równoległe requesty mogą przekroczyć limit (`spree/core/app/models/spree/digital_link.rb:27-52`).

**Wpływ:** autoryzowany właściciel lub zdobyte konto może wgrać plik wyczerpujący storage/RAM/workery; posiadacz linku może równoległymi pobraniami obciążyć API. Duży lub patologiczny CSV może zablokować joby i współdzieloną VM wszystkich tenantów.

**Naprawa:** per-typ limity byte size, rozsądna allowlista MIME z weryfikacją magic bytes, limity liczby wierszy/kolumn/długości pola i kwoty per sklep. CSV przetwarzać strumieniowo. Pliki cyfrowe wydawać krótkotrwałym signed URL-em z prywatnego storage/CDN zamiast przez pamięć Rails; autoryzację/licznik wykonać atomowo. Opcjonalnie skan antymalware przed publikacją.

**Test zamykający:** pliki tuż nad limitem są odrzucane przed jobem; fałszywy MIME i CSV bomb nie są przetwarzane; pamięć procesu pozostaje ograniczona przy maksymalnym legalnym imporcie/downloadzie; N równoległych pobrań nie przekracza limitu dostępu.

### SEC-004 — P1 — produkcyjny deploy ufa mutowalnym tagom akcji i obrazów

**Status dowodu:** fakt konfiguracyjny; pokrywa supply-chain, cross-reference `ARCH-005`.

Workflow z prawem deployu na Oracle używa m.in. `actions/checkout@v4`, `docker/setup-buildx-action@v3`, `docker/login-action@v3` i `docker/build-push-action@v5` zamiast pełnych SHA (`.github/workflows/deploy-oracle.yml:20-34,54`). Następnie loguje się do GHCR, materializuje prywatny klucz SSH i wykonuje polecenia na produkcji (`:56-69`). Compose pobiera mutowalne `postgres:15-alpine`, `redis:7-alpine`, `nginx:alpine` (`docker-compose.yml:3,17,92`), a Dockerfile klonuje nieprzypięty `spree-starter` (`Dockerfile:20`; już opisane jako `ARCH-005`). Część innych workflow także używa tagów akcji i `getmeili/meilisearch:latest` (`.github/workflows/tests.yml`).

**Wpływ:** przejęcie upstreamu/tagu albo nieprzejrzysta zmiana obrazu może wykonać kod w CI z tokenem registry, odczytać sekret SSH lub trafić bezpośrednio na produkcję; odtworzenie identycznego obrazu nie jest gwarantowane.

**Naprawa:** wszystkie actions przypiąć do pełnych commit SHA (z komentarzem wersji), obrazy do digestów, starter do sprawdzonego commita/artefaktu. Rozdzielić build od deployu przez attestowany digest, ograniczyć permissions per job, użyć osobnego deploy credential/OIDC i ochrony environment z zatwierdzeniem. Dodać SBOM, provenance/signature verification i skan obrazu jako blokujący gate.

**Test zamykający:** polityka CI (np. zizmor/Scorecard + własny lint) odrzuca każdy `uses: @tag`, obraz bez digestu i clone bez commita; produkcja wdraża dokładnie digest zbudowany oraz zweryfikowany w poprzednim jobie.

### SEC-005 — P2 — storefront nie definiuje CSP ani pełnego zestawu nagłówków ochronnych

**Status dowodu:** fakt repo; nagłówki dodawane zewnętrznie przez Vercel nieweryfikowane runtime.

W `next.config.ts` nie ma `headers()`, a middleware ustawia tylko cookies/rewrites (`sklepikFront/next.config.ts:7-64`, `sklepikFront/src/lib/spree/middleware.ts:64-105`). Nie znaleziono repozytoryjnej Content-Security-Policy, `frame-ancestors`, HSTS, Referrer-Policy ani Permissions-Policy dla storefrontu. Rails API ma własne defensywne headers (`spree/api/app/controllers/concerns/spree/api/v3/security_headers.rb:13-21`), ale nie chronią one dokumentów HTML Next.js.

**Wpływ:** brak warstwy ograniczającej skutki SEC-001 i przyszłych injection, możliwość clickjackingu stron konta/checkoutu oraz brak jawnej, testowalnej polityki zasobów zewnętrznych.

**Naprawa:** wdrożyć testowalną CSP (najpierw report-only), docelowo nonce/hash bez `unsafe-inline`, `object-src 'none'`, restrykcyjne `connect/img/frame`, `base-uri`, `form-action` i `frame-ancestors`; dodać HSTS na HTTPS, nosniff, Referrer-Policy i minimalne Permissions-Policy. CSP nie zastępuje sanitizacji.

**Test zamykający:** browser E2E i skan nagłówków na production/preview potwierdzają politykę na stronach produktu, konta i checkoutu; kontrolowany inline script/frame z obcego originu jest blokowany bez uszkodzenia Stripe/Adyen/Sentry.

### SEC-006 — P2 — rate limiting ma dwa niespójne magazyny, z czego jeden jest procesowy

**Status dowodu:** fakt; topologia i liczba procesów produkcyjnych nieweryfikowane runtime. Cross-reference `AUTH-011`.

Globalny limit API i kontrolerowe limity auth używają `Rails.cache` (`spree/api/app/controllers/spree/api/v3/base_controller.rb:22-38`), ale dodatkowe throttles login/reset/newsletter używają jawnego `ActiveSupport::Cache::MemoryStore` (`spree/api/config/initializers/rack_attack.rb:3-11`). Taki licznik resetuje się z procesem i nie jest wspólny między workerami/instancjami. Test environment wyłącza Rack::Attack, a komentarz stwierdza, że żaden spec nie asertuje throttlingu (`:7-11`). Globalny klucz limitu to wspólny publishable key albo IP (`base_controller.rb:35-38`), co umożliwia jednemu klientowi zużycie budżetu całego storefrontu.

**Wpływ:** brute force/spam może ominąć część limitów przez restart lub rozkład ruchu, a napastnik znający publiczny publishable key może wywołać odmowę usługi dla legalnych kupujących danego sklepu.

**Naprawa:** jeden współdzielony Redis-backed limiter, jawne zasady proxy IP, kompozytowe klucze tenant+endpoint+actor/IP oraz osobne limity kosztownych operacji. Nie wyłączać wszystkich testów limitera — testować zegarem i izolowanym store.

**Test zamykający:** równoległe requesty przez co najmniej dwa procesy i po restarcie nadal respektują budżet; atak jednym IP nie konsumuje całego budżetu pozostałych klientów; spoofowany forwarding header nie zmienia tożsamości limitera.

### SEC-007 — P2 — publiczny webhook storefrontu buforuje i parsuje dowolnie duże body przed ograniczeniem zasobów

**Status dowodu:** fakt w kodzie; limit request body Vercela nieweryfikowany runtime. Cross-reference durability/idempotency: `ARCH-009/010` i `MONEY-007`.

Handler wykonuje `await request.text()` przed weryfikacją sygnatury, a potem `JSON.parse` bez jawnego limitu bajtów, głębokości/schematu ani rate limitu (`sklepikFront/src/lib/spree/webhooks.ts:43-87`). Każdy internetowy klient może wysłać body; nie musi znać sekretu, aby wymusić jego odczyt i HMAC. Route nie ma własnego throttlingu (`sklepikFront/src/app/api/webhooks/spree/route.ts:12-39`).

**Wpływ:** koszt pamięci/CPU i invocationów Vercela przed odrzuceniem 401; po poprawnej sygnaturze wadliwy/głęboki payload może trafić do email templates oraz cache invalidation. Platformowy limit Vercela zmniejsza maksymalny pojedynczy request, ale nie zastępuje budżetu żądań.

**Naprawa:** odrzucać po `Content-Length` i strumieniowo egzekwować mały limit, ograniczyć częstotliwość na edge, walidować envelope i per-event payload schematem oraz limitem kolekcji/stringów. Zachować HMAC nad dokładnymi bajtami i timestamp tolerance.

**Test zamykający:** unsigned body nad limitem jest odrzucane 413 bez alokacji całego payloadu/wywołania handlera; burst daje 429; poprawnie podpisany zbyt głęboki lub niezgodny schemat daje kontrolowany 4xx i nie wysyła maila.

### SEC-008 — P2 — automatyczny audyt zależności nie jest blokującą kontrolą i nie obejmuje pełnej Ruby surface

**Status dowodu:** fakt repo; aktualne advisory online nieweryfikowane.

Tygodniowy workflow JS uruchamia `pnpm audit` i `pnpm audit --fix` z `|| true`, więc awaria registry, samego audytu lub pozostające podatności nie czerwienią joba (`.github/workflows/security-audit.yml:35-49`). Otwarty automatycznie PR nie uruchamia CI przy domyślnym tokenie, co dokumentuje sam workflow (`:53-74`). Dependabot Bundler śledzi tylko `/spree/core`, podczas gdy osobne lockfile'y istnieją również m.in. pod `spree/api`; w CI jest Brakeman, ale nie znaleziono blokującego `bundler-audit`/OSV dla wszystkich lockfile'ów (`.github/dependabot.yml:3-11`, `.github/workflows/tests.yml:376-418`). Lokalny `brakeman` i `pnpm` nie były dostępne, więc nie można było potwierdzić bieżącego stanu advisory.

**Wpływ:** znana podatność może pozostać niewidoczna lub nierozwiązana mimo zielonego harmonogramu; automatyczna modyfikacja lockfile bez uruchomionej CI może wyglądać jak gotowa poprawka.

**Naprawa:** osobny niezmieniający lockfile gate dla każdego produkcyjnego lockfile (OSV/`pnpm audit` i `bundler-audit`) z jawnym, wersjonowanym rejestrem wyjątków i datą wygaśnięcia. PR naprawczy ma obowiązkowo uruchamiać pełne CI; bot naprawiający nie powinien maskować awarii.

**Test zamykający:** kontrolowana zależność testowa/advisory lub fixture powoduje czerwony workflow; awaria registry także nie daje zielonego wyniku; raport enumeruje wszystkie lockfile'y i obraz bazowy.

## Potwierdzone zabezpieczenia

1. Outbound webhook używa HMAC SHA-256 z timestampem i w środowisku innym niż development wykonuje request przez `ssrf_filter`; model odrzuca aktualnie rozwiązujące się prywatne IP (`spree/api/app/services/spree/webhooks/deliver_webhook.rb:51-95`, `spree/core/app/models/spree/webhook_endpoint.rb:19-22,169-178`). Runtime protection ponownie rozwiązuje host, więc sam błąd walidacji DNS nie jest dowodem obejścia.
2. Webhook storefrontu weryfikuje HMAC nad surowym body i timestamp tolerance przed `JSON.parse`/dispatch (`sklepikFront/src/lib/spree/webhooks.ts:55-87`).
3. API v3 ustawia nosniff, DENY framing, Referrer/Permissions Policy oraz HSTS dla żądań SSL (`spree/api/app/controllers/concerns/spree/api/v3/security_headers.rb:13-21`).
4. Pagination zasobów jest ograniczona do 100 (`spree/api/app/controllers/spree/api/v3/resource_controller.rb:224-234`).
5. Uploady obrazów mają allowlistę web image MIME oraz limit rozmiaru (`spree/core/app/models/spree/asset.rb:38-41`); luka SEC-003 dotyczy niespójności innych typów wejść.
6. CSV eksporty stosują ochronę przed formula injection (`spree/core/app/models/spree/export.rb:89-92`, `spree/core/app/presenters/spree/csv/formula_sanitizer.rb`).
7. Repozytoryjny skan wzorców wysokiej pewności nie znalazł commitowanego klucza prywatnego ani popularnych formatów live tokenów. Nie jest to pełny skan historii; jawny credential opisany w `AUTH-001` pozostaje P0 i wymaga rotacji.
8. `JsonLd` zamienia `<` na `\\u003c` przed osadzeniem JSON w `<script>`, co zamyka typowe wyjście `</script>` (`sklepikFront/src/components/seo/JsonLd.tsx:5-12`).

## Coverage i ograniczenia

| Obszar | Pokrycie | Wynik |
|---|---|---|
| injection / XSS | renderery Next, parametry/serializery Rails, dynamiczne klasy i wyszukiwanie SQL | stored XSS P1; nie znaleziono nowej potwierdzonej SQL/command injection |
| SSRF / URL / redirect | webhook delivery, Next image, reset URL, allowed origins | Next image P1; outbound webhook ma runtime filter; auth redirects opisane w audycie 05 |
| CSRF / CORS / cookies | headers, API auth concerns, AllowedOrigin | auth-cookie problem pozostaje `AUTH-007`; API jest tokenowe; brak live CORS testu |
| upload / deserialization | Asset, Digital, Import, Active Storage, JSON webhook | limity niespójne P1; brak niebezpiecznego `YAML.load`/`Marshal.load` w aktywnej ścieżce |
| secrets / logging | tracked files, popularne formaty tokenów, error logging | bez nowych wartości sekretów; historia git, Vercel/Oracle/Sentry nieweryfikowane |
| dependency / CI supply chain | workflows, Dependabot, audit workflow, Docker/Compose | mutowalny deploy P1 i advisory gate P2 |
| rate limit / DoS | Rails rate limits, Pagy, webhooki, pliki/download | procesowy limiter i nieograniczony webhook P2; pliki P1 |
| payment webhooks | podpis, tenant resolution, retry | nie dublowano `MONEY-002/003/006/007` |

Nie wykonano DAST przeciw produkcji, aktywnego SSRF, fuzzingu API, uploadu bomb, testu brute-force ani odczytu produkcyjnych env/logów. Nie uruchomiono lokalnego Brakeman/bundler-audit/pnpm audit: executable nie są zainstalowane w dostępnym środowisku, a audyt advisory wymaga aktualnego dostępu do registry. Istniejący CI deklaruje Brakeman, ale jego konkretny artefakt nie był dostępny w tym audycie. Nie audytowano bezpieczeństwa platform Vercel/Oracle/R2/Resend/Stripe jako usług; obejmuje je audyt infrastruktury i konfiguracji runtime.

## Kolejność domknięcia

1. Natychmiast zamknąć istniejące P0 `AUTH-001` i `TENANT-001`; bez tego żadna ekspozycja klientów nie jest dopuszczalna.
2. Zsanityzować cały kontrakt rich text i dodać CSP (`SEC-001`, następnie `SEC-005`).
3. Wyłączyć prywatne IP w produkcyjnym optimizerze i przetestować preview (`SEC-002`).
4. Wprowadzić limity/streaming/signed downloads dla plików (`SEC-003`).
5. Przypiąć i attestować pełny łańcuch deployu (`SEC-004`), równolegle uruchomić blokujące advisory gates (`SEC-008`).
6. Ujednolicić Redis rate limiting i ograniczyć webhook przed odczytem body (`SEC-006/007`).
7. Po naprawach wykonać autoryzowany DAST dwóch tenantów oraz testy abuse: stored XSS, SSRF, upload, webhook flood, rate-limit distributed i dependency policy.

## Kryterium akceptacji ponownego audytu

Audyt 06 można uznać za zamknięty dopiero, gdy wszystkie P1 mają testy regresji uruchamiane w CI, P2 mają właściciela i termin, aktywny DAST nie znajduje high/critical, wszystkie advisory produkcyjne są zamknięte lub mają zatwierdzony wyjątek z datą wygaśnięcia, a production-like test potwierdza nagłówki, egress i limity na dwóch tenantach.
