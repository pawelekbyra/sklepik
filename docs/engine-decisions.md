# Decyzje dotyczące silnika

Ten plik służy do dokumentowania świadomych zmian w silniku commerce, backendzie, checkoutcie, modelu zamówień, płatnościach, adminie lub API.

## Zasada główna

Najpierw rozszerzamy Spree. Core modyfikujemy dopiero wtedy, gdy jest to naprawdę uzasadnione.

## Zasada pracy z agentami

Agent nie może zmieniać silnika commerce bez decyzji zapisanej w tym dokumencie.

Jeśli zmiana wpływa na Store API używane przez storefront (`sklepikFront`), musi to być opisane wprost: które endpointy, formaty danych albo nagłówki się zmieniają i jaki jest wpływ na `@spree/sdk` oraz kod storefrontu.

Jeśli zmiana jest tylko konfiguracją albo rozszerzeniem, też trzeba opisać, dlaczego nie ruszano core Spree. Taka notatka ma ułatwić kolejnym agentom zrozumienie, że brak modyfikacji core był świadomą decyzją, a nie przypadkiem.

Decyzje mają być czytelne dla kolejnych agentów: krótki kontekst, jednoznaczna decyzja, uzasadnienie, wpływ na upstream i praktyczne notatki są ważniejsze niż długi opis.

Każda modyfikacja core powinna mieć krótki wpis w tym pliku, żeby po czasie było jasne:

- co zostało zmienione,
- dlaczego zostało zmienione,
- czy była rozważana alternatywa przez konfigurację lub rozszerzenie,
- jaki jest wpływ na aktualizacje upstreamowego Spree.

## Szablon wpisu

```md
## YYYY-MM-DD — Tytuł decyzji

### Status

Proponowana / zaakceptowana / wdrożona / wycofana

### Kontekst

Krótki opis problemu lub potrzeby.

### Decyzja

Co zmieniamy i gdzie.

### Uzasadnienie

Dlaczego ta decyzja jest lepsza niż alternatywy.

### Wpływ na upstream

Czy zmiana utrudnia aktualizację Spree? Jeśli tak, w jaki sposób.

### Notatki

Dodatkowe informacje, linki do PR, issue lub commitów.
```

## Log decyzji

## 2026-07-13 — `RoleUser#store` derywowany z `resource`, gdy resource jest sklepem

### Status

Wdrożona.

### Kontekst

Po zmergowaniu Fazy 1 wielosklepowości (poprzedni wpis niżej) CI faktycznie uruchomił pełny RSpec (wcześniej tylko napisany, nieuruchomiony) i poczerwieniał. Zamiast zgadywać z kodu, postawiono lokalne środowisko (Postgres + `bundle install` + `rake test_app`) i odtworzono błąd empirycznie. Po odsłonięciu maskowanego przez zbyt szeroki stub testu (patrz commit `cc4709f`) ujawnił się realny bug: `Spree::RoleUser` ma dwie kolumny wskazujące na sklep — polimorficzny `resource` (przez `Spree::SingleStoreResource#ensure_store`) i bezpośredni `store` (FK, używany przez `AdminAuthentication#require_store_membership!` do autoryzacji). `ensure_store` domyślnie ustawia `store ||= Spree::Current.store` — **nigdy z `resource`**, nawet gdy `resource` samo jest tym `Store`em (najczęstszy przypadek: rola admina bezpośrednio na sklepie). Efekt: `store.add_user(current_user)` wywołane po utworzeniu nowego sklepu (`Admin::StoresController#create`) wiązało nowo utworzony `RoleUser` z `Spree::Current.store` — czyli sklepem *bieżącym* w kontekście danego żądania — a nie z nowo utworzonym sklepem, na który rola faktycznie została nadana. Admin, który dopiero co założył sklep, dostawał 403 przy pierwszej próbie wejścia do niego.

Zweryfikowane empirycznie dwukrotnie przez `rails runner` na produkcyjnej ścieżce `Store#add_user` (nie przez spekulację o kolejności `before_action`/callbacków): bez poprawki `RoleUser.store_id` = sklep ustawiony jako `Spree::Current.store` w skrypcie (nie sklep przekazany jako `resource`); z poprawką `RoleUser.store_id` poprawnie równy `resource.id`.

### Decyzja

`Spree::RoleUser#ensure_store` nadpisuje `SingleStoreResource#ensure_store` (nazwa metody identyczna, więc Ruby method resolution wybiera wersję z `RoleUser` — żadnej zmiany w rejestracji callbacków, żadnego ryzyka rozjazdu kolejności): `self.store ||= resource.is_a?(Spree::Store) ? resource : Spree::Current.store`. Gdy `resource` nie jest sklepem (np. przyszłe role na innych typach zasobów), zachowanie identyczne jak wcześniej.

### Uzasadnienie

`SingleStoreResource` jest współdzielonym mixinem używanym przez ~19 modeli (Order, Promotion, Channel, itd.), z których żaden poza `RoleUser` nie ma polimorficznego `resource` obok `store`. Zmiana samego mixina byłaby niepotrzebnie szeroka i ryzykowna dla niepowiązanych modeli. Nadpisanie w `RoleUser` jest precyzyjne, lokalne i nie zmienia zachowania dla żadnego innego includera.

### Wpływ na upstream

Brak wpływu na Store API konsumowane przez `sklepikFront` — to zmiana modelu Admin-side (autoryzacja panelu), nie kontraktu Store API.

### Notatki

Naprawione w tej samej sesji: `store_controller_spec.rb` (zbyt szeroki `include_context` maskujący ten bug + brakująca seed roli `'admin'` w teście z traitem `:without_admin_role`), `admin_user_methods_spec.rb` (ten sam wzorzec brakującej roli), `stores_spec.rb` (fałszywa deklaracja `security [api_key: []]` + brakujący fixture strefy wysyłkowej wymagany przez `ensure_default_market`). Pełne podsumowanie weryfikacji (333 przykłady, 0 failures łącznie) w `docs/roadmap.md` F25. Znany, nienaprawiony jeszcze dług UX: `StoresController#create` zwraca puste `message` w 422, gdy błąd pochodzi z `Market`/`MarketCountry` (zagnieżdżone w `after_create`), nie z samego `Store` — patrz `docs/technical-debt.md`.

## 2026-07-12 — Admin API rozwiązuje `current_store` z nagłówka, nie z hosta (wielosklepowość, Faza 1)

### Status

Wdrożona.

### Kontekst

Właściciel chce zarządzać kilkoma sklepami z jednego panelu (pełny plan: `docs/plans/multi-store-support.md`). Fundament pod to już istniał (`Spree::RoleUser` wiąże usera ze store'em, `Spree::Ability` liczy role per store), ale `current_store` dla **każdego** requestu Admin API (tak samo jak dla storefrontu klienta) rozwiązywał się przez `Spree::Stores::FindDefault` po `request.env['SERVER_NAME']` — finder, który w tym forku **ignoruje** hosta i zawsze zwraca jedyny `default: true` store. Dashboard od dawna wysyłał nagłówek `X-Spree-Store-Id` (`admin-sdk`'s `setStore()`), ale backend go nie czytał.

### Decyzja

`Spree::Api::V3::Admin::BaseController` dostał `prepend_before_action :resolve_store_from_header`, który — gdy nagłówek `X-Spree-Store-Id` jest obecny — wypełnia `@current_store` (ivar, który `current_store` z `ControllerHelpers::Store` memoizuje przez `||=`) sklepem znalezionym po prefixed ID; brak dopasowania → jawny `ActiveRecord::RecordNotFound` (404). Storefront (Store API, klient końcowy) **bez zmian** — dalej rozwiązuje store po hoście, bo to osobna publiczność (jedna domena na sklep).

**Korekta 2026-07-13 (znalezisko potwierdzone czytaniem kodu):** zdanie wyżej — "storefront dalej rozwiązuje store po hoście" — jest **nieprawdziwe względem kodu**, nie tylko nieaktualne. `Spree::Stores::FindDefault#initialize(scope: nil, url: nil)` przyjmuje `url:`, ale nigdy go nie używa — `execute` zawsze zwraca `where(default: true).first || @scope.first`, niezależnie od hosta. `find_default_spec.rb` nazywa to wprost `context 'with url argument (ignored)'` — to udokumentowane zachowanie odziedziczone z upstream Spree (założenie "jeden store"), nie regresja wprowadzona przez F25. Dziś niewidoczne (jest jeden sklep, więc `default` = jedyny sklep), ale **blokuje** cały model "Independent Storefront" z `docs/plans/store-factory.md` — drugi storefront nigdy nie zobaczy danych swojego sklepu. Efekt nie jest wyciekiem (fail-open), tylko twardą blokadą (fail-closed): `authenticate_api_key!` (`spree/api/app/controllers/concerns/spree/api/v3/api_key_authentication.rb:19`) szuka klucza publishable **wewnątrz `current_store.api_keys`**, więc klucz drugiego sklepu po prostu nie zostanie znaleziony w (zawsze domyślnym) `current_store` i request dostanie 401. Naprawa jest w zakresie Etap 0 `store-factory.md` i musi iść w parze z dwoma sąsiednimi lukami (żeby naprawa nie zamieniła fail-closed w fail-open):
- `Spree::Api::V3::HttpCaching#set_vary_headers` (`spree/api/app/controllers/concerns/spree/api/v3/http_caching.rb:25`) nie dodaje niczego identyfikującego sklep do `Vary` — dwa sklepy o tej samej walucie/locale mogą współdzielić klucz cache na CDN/proxy.
- `Spree::Base.for_store` (`spree/core/app/models/spree/base.rb:34`) cicho zwraca `self` (wszystkie rekordy, bez scope) dla modelu bez odpowiedniej relacji na `Store` — niebezpieczny domyślny kierunek (powinien raczej rzucać błąd niż milczeć).

Świadomie **nie nadpisano samej metody `current_store`** (co byłoby prostsze) — istniejący pakiet speców Admin API stubuje ją wprost (`allow_any_instance_of(Spree::Api::V3::BaseController).to receive(:current_store)`, `spree/api/lib/spree/api/testing_support/v3/base.rb`), a metoda zdefiniowana w podklasie zawsze wygrywa z `any_instance_of` na klasie nadrzędnej w Ruby — nadpisanie po cichu wyłączyłoby ten stub w każdym istniejącym teście Admin API. Wypełnienie ivara przez `before_action` omija ten problem: stub (gdy aktywny) całkowicie zastępuje metodę i ignoruje ivar, więc istniejące testy działają bez zmian; w kodzie produkcyjnym (bez stubu) `||=` w oryginalnej metodzie po prostu nie nadpisuje już ustawionej wartości.

Dodatkowo: `Spree::AdminUserMethods#admin_of_any_store?` (nowa metoda) gate'uje `POST /api/v3/admin/stores` — kto może założyć nowy sklep. Zamiast nowej flagi "super-admin", warunek to "ma już rolę admina na choć jednym sklepie" — świadomie zaprojektowane pod przyszłą Fazę 3 (self-service): ten sam endpoint zostaje, zmienia się tylko reguła autoryzacji.

### Uzasadnienie

Zero migracji bazy — cały model danych (store_id na RoleUser, role per store w `Spree::Ability`) już to obsługiwał; brakowało tylko poprawnego rozwiązywania "który to sklep" po stronie admina. Alternatywa (osobna baza/instancja per sklep) odrzucona jako niepotrzebnie kosztowna dla tej skali — patrz plan.

### Wpływ na upstream

Zmiana lokalna dla tego forka (`Admin::BaseController`, nowy `StoresController`) — nie modyfikuje żadnego upstreamowego kontraktu Store API. Storefront (`sklepikFront`) niedotknięty: konsumuje wyłącznie Store API, które nadal rozwiązuje się po hoście, bez zmian.

### Notatki

Nowe endpointy: `GET`/`POST /api/v3/admin/stores` (plural — obok istniejącego singularnego `resource :store`). RSpec napisane, ale nieuruchomione lokalnie w tej sesji (brak zbudowanego test app) — patrz `docs/roadmap.md` F25 i `docs/stan-projektu.md`.

## 2026-07-06 — Polski jako domyślny język panelu administracyjnego

### Status

Wdrożona.

### Kontekst

Panel administracyjny ma być gotowy dla Kakaowego Sklepiku, więc pierwsze wejście do aplikacji powinno uruchamiać interfejs po polsku. Istniejący mechanizm i18n dashboardu obsługuje wiele bundle’i tłumaczeń, wybór języka użytkownika przez `selected_locale`, store-wide `preferred_admin_locale`, przełącznik w menu użytkownika oraz formularz profilu.

### Decyzja

Ustawiono domyślny język admin UI na `pl` w warstwie i18n dashboard-core, bez usuwania istniejących języków i bez hardcodowania tekstów w komponentach. Zachowano fallback `en` w i18next. Ręczny wybór użytkownika nadal zapisuje się jako `selected_locale` przez `PATCH /me`, a przed zalogowaniem oraz podczas bootu jest wspierany przez `localStorage` pod kluczem `spree-admin-locale`.

### Uzasadnienie

To jest zmiana konfiguracji/warstwy i18n, nie zmiana core commerce, checkoutu, produktów, płatności ani Store API. Wykorzystuje istniejące extension points dashboardu: bundle’e tłumaczeń, profil użytkownika, preferencję sklepu i przełącznik języka.

### Wpływ na upstream

Wpływ na upstream Spree jest niski: zmiana dotyczy lokalnego domyślnego języka dashboardu i nie modyfikuje kontraktów API ani silnika commerce. Aktualizacje upstream mogą wymagać ponownego sprawdzenia stałej domyślnego języka, jeśli upstream zmieni bootstrap i18n.

### Notatki

Nie zmieniono Store API konsumowanego przez `KakaowySklepikFront`; adapter `lib/spree` nie wymaga zmian. Nie wprowadzono routingu `/[country]/[locale]`, bo dashboard w tym repo używa tras administracyjnych `/$storeId/...`, a storefront klienta jest oddzielony w repo `sklepikFront`.

## 2026-07-11 — Poprawka kształtu JSON przy throttlingu (F16 rate limiting)

### Status

Wdrożona.

### Kontekst

F16 (2026-07-10) dodał `Rack::Attack` z throttlingiem na `auth/login`, `password_resets`, `customers#create`, newsletter subscribe (Store i Admin API). `throttled_responder` zwracał `{ error: "Too many requests..." }` — płaski string zamiast obiektu. Kanoniczna koperta błędu API v3 (`Spree::Api::V3::ErrorHandler#render_error`, `spree/api/app/controllers/concerns/spree/api/v3/error_handler.rb`) to `{ error: { code:, message: } }`, a `SpreeError` w `@spree/sdk` czyta dokładnie `response.error.message` i `response.error.code`. Zweryfikowano empirycznie (uruchamiając realny kod `SpreeError` z zainstalowanego `@spree/sdk` w `sklepikFront`): stary kształt dawał `message: ""` (pusty string), bo `"string".message` w JS to `undefined`. Efekt w produkcji: użytkownik trafiony rate-limitem (login, reset hasła, newsletter, signup) w storefroncie i w panelu admina widziałby pusty komunikat błędu zamiast informacji o throttlingu. Nigdy niewykryte w CI, bo `Rails.env.test?` wyłącza cały rate limiting w testach.

### Decyzja

`Rack::Attack.throttled_responder` w `spree/api/config/initializers/rack_attack.rb` zwraca teraz `{ error: { code: 'rate_limited', message: 'Too many requests. Please try again later.' } }` — zgodne z resztą kontraktu API v3.

### Uzasadnienie

To poprawka zgodności kontraktu błędów, nie zmiana logiki throttlingu (limity, okna czasowe, `Retry-After` header — bez zmian). Jedyna alternatywa (zignorować) zostawiałaby cichy, mylący UX dla realnych użytkowników trafionych limitem.

### Wpływ na upstream

Brak — `rack_attack.rb` to inicjalizator specyficzny dla tego forka, nie część core Spree.

### Notatki

Wpływa na `@spree/sdk` konsumowany przez `sklepikFront` (storefront) i `packages/dashboard` (panel) — oba parsują błędy przez `SpreeError`. Osobno zanotowane podczas tego samego audytu: formularz logowania panelu (`packages/dashboard/src/routes/login.tsx`) łapie każdy błąd generycznie jako "Invalid email or password" niezależnie od treści — nawet po tej poprawce admin trafiony throttlingiem zobaczy mylący komunikat. To osobny, wcześniejszy dług UI (nie regresja tej zmiany), do rozważenia osobno.
