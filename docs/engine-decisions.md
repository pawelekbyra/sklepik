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

## 2026-07-13 — Atomowe utworzenie sklepu i przypisanie właściciela

### Status

Wdrożona.

### Kontekst

`Admin::StoresController#create` najpierw zapisywał `Store`, a dopiero potem wywoływał `Store#add_user`. Jeżeli utworzenie `RoleUser` nie powiodło się, endpoint kończył się błędem, ale zapisany sklep wraz z rekordami bootstrapu pozostawał bez właściciela. Dodatkowo zwykłe `store.save` gubiło szczegóły błędu, gdy `after_create` odrzucał zagnieżdżony `Market` albo `MarketCountry`, ponieważ kontroler renderował wyłącznie puste w takim przypadku `store.errors`.

### Decyzja

Zapis sklepu przez `save!` i przypisanie twórcy przez `add_user` wykonują się w jednej `ApplicationRecord.transaction`. Każdy `ActiveRecord::RecordInvalid` wycofuje cały bootstrap i trafia do istniejącego wspólnego handlera API, który renderuje błędy faktycznie niepoprawnego rekordu.

### Uzasadnienie

Sklep bez właściciela jest stanem nieużytecznym i blokuje późniejszy dostęp przez kontrolę membershipu. Jedna transakcja daje prostą, bazodanową gwarancję all-or-nothing bez wprowadzania nowego serwisu dla krótkiej orkiestracji dwóch istniejących operacji. Test requestowy wymusza awarię `add_user` i sprawdza rollback rekordu sklepu.

### Wpływ na upstream

Zmiana jest lokalna dla nowego kontrolera Admin API tego forka. Nie zmienia schematu odpowiedzi sukcesu, Store API, `@spree/sdk` ani kodu `sklepikFront`; przy błędzie 422 poprawia treść istniejącej koperty błędu.

### Notatki

Nie zmieniono modeli core ani schematu bazy. Rozszerzenie korzysta wyłącznie z transakcji Active Record i istniejącego `ErrorHandler` API v3.

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

Naprawione w tej samej sesji: `store_controller_spec.rb` (zbyt szeroki `include_context` maskujący ten bug + brakująca seed roli `'admin'` w teście z traitem `:without_admin_role`), `admin_user_methods_spec.rb` (ten sam wzorzec brakującej roli), `stores_spec.rb` (fałszywa deklaracja `security [api_key: []]` + brakujący fixture strefy wysyłkowej wymagany przez `ensure_default_market`). Pełne podsumowanie weryfikacji (333 przykłady, 0 failures łącznie) w `docs/roadmap.md` F25. Opisany wtedy dług pustego 422 z błędu `Market`/`MarketCountry` został zamknięty przez atomowy bootstrap sklepu z 2026-07-13 (wpis wyżej).

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

## 2026-07-13 — Etap 0 Store Factory: bezpieczne rozpoznawanie sklepu i izolacja cache

### Status

Wdrożona baza oraz lokalne utwardzenie gotowe do publikacji. Zweryfikowane 2026-07-13 na Postgresie: 50 przykładów RSpec obejmujących Store API controller, resolving, cache, admin create i finder — 0 failures. Pełny kontekst: `docs/plans/store-factory.md` (Etap 0).

### Kontekst

Audyt kodu (2026-07-13) potwierdził, że storefront (Store API) nie rozpoznaje sklepu po domenie: `Spree::Stores::FindDefault` przyjmował `url:`, ale go ignorował i zawsze zwracał `default: true` store. Fork świadomie uprościł upstreamowy finder (który dopasowuje po hoście) do „zawsze default" na czas jednego sklepu. Dopóki jest jeden sklep, niewidoczne; przy drugim niezależnym storefroncie **każdy** request dostawał dane pierwszego sklepu — a `authenticate_api_key!` (szukające klucza wewnątrz `current_store.api_keys`) dawało 401 dla klucza drugiego sklepu (fail-closed). Dodatkowo cache kolekcji (`HttpCaching#collection_cache_key`) nie zawierał `store_id` — dwa sklepy o tych samych parametrach dawały identyczny ETag (ryzyko przecieku przez wspólny CDN po naprawie resolvingu).

### Decyzja

1. **`Spree::Stores::FindDefault` rozwiązuje sklep po hoście.** `store_for_url` normalizuje `@url` (schemat/port/ścieżka odcięte, lower-case) i dopasowuje do znormalizowanego `Store#url`; brak dopasowania → fallback na `default: true` (zachowuje zachowanie jednego sklepu, gdzie host backendu ≠ `Store#url`). Zaktualizowany `find_default_spec.rb` (dawny `context 'with url argument (ignored)'` kodował bug — teraz asertuje rozwiązywanie po hoście + fallback).
2. **Cache kolekcji scope'owany po sklepie.** `collection_cache_key` dostał `current_store&.id` na początku klucza; `set_vary_headers` dołożył `x-spree-api-key` do `Vary` (klucz publishable jest per-sklep) — wspólny cache pośredni nie poda odpowiedzi jednego sklepu drugiemu.
3. **`Spree::Base.for_store` — ostry brzeg udokumentowany, nie zmieniony.** Cichy fallback „zwróć wszystko bez scope" jest load-bearing (userzy są globalni świadomie, `UserMethods.for_store` zwraca `self`); zmiana na „rzucaj błąd" złamałaby wiele modeli. Dodano komentarz-ostrzeżenie w kodzie: nowy model tenant-scoped musi mieć relację na `Store`, inaczej przecieka tu bez błędu.
4. **`Admin::StoresController#create` atomowe.** `store.save!` + `store.add_user` w jednej transakcji (`add_user` używa `find_or_create_by!`, może rzucić) — koniec ryzyka sklepu bez właściciela.
5. **Publishable API key wyznacza tenant przed autoryzacją.** `StoreResolution` znajduje aktywny klucz globalnie (token jest unikalny), ustawia `Spree::Current.store`, a następnie wymaga spójności jawnego `X-Spree-Store-Id` i hosta, jeśli host należy do innego aktywnego sklepu. Dzięki temu wspólny host API obsługuje wiele niezależnych storefrontów bez polegania na domenie backendu.
6. **Cache uwzględnia cały kontekst tenantowy.** ETag obejmuje store, market, channel, currency i locale; `Vary` jest scalany bez niszczenia wcześniejszych wartości i zawiera odpowiadające nagłówki requestu.

### Uzasadnienie

`FindDefault` to jedyne miejsce rozwiązywania sklepu na storefroncie — nie da się tego obejść konfiguracją, więc zmiana core jest konieczna (hierarchia z `kierunek-projektu.md`). Fallback na default zachowuje kompatybilność jednego sklepu, więc zmiana jest bezpieczna dla dzisiejszej produkcji. Zmiany cache i transakcji są czysto obronne.

### Wpływ na upstream

Częściowo przywraca upstreamowe zachowanie (host-based resolution), które fork wcześniej usunął — zbliża do upstream, nie oddala.

### Notatki

Storefront (`sklepikFront`) może korzystać ze wspólnego hosta API: publishable key wybiera sklep, a domena/`X-Spree-Store-Id` są dodatkowymi kontrolami spójności. Podczas testów poprawiono też `FindDefault`: scope może być klasą modelu, więc iteracja wymaga `@scope.all.detect`, nie `@scope.detect`. Osobne konta klientów per sklep (decyzja właściciela) pozostają osobnym planem: `docs/plans/per-store-customer-accounts.md`.

## 2026-07-13 — Synchronizacja cen EUR przeniesiona do backendu (z cronu storefrontu)

### Status

Backend (serwis + rake + spec) napisany na gałęzi `claude/plan-review-improvement-cpj6fw`, testy nieuruchomione lokalnie. Pozostały krok (poza tym repo): usunięcie trasy `src/app/api/cron/sync-eur-prices/route.ts` i zmiennej `SPREE_ADMIN_SECRET_KEY` z `sklepikFront` + zaplanowanie taska po stronie backendu.

### Kontekst

Trasa cron w `sklepikFront` trzymała `SPREE_ADMIN_SECRET_KEY` (szeroki sekret Admin API) w env Vercela i sama wołała `POST /api/v3/admin/prices/bulk_upsert`, przeliczając ceny EUR z kursu NBP. Uzasadnienie w kodzie („Sidekiq wyłączony na Render") jest nieaktualne od migracji na Oracle (F7/F8, 2026-07-09) — Sidekiq działa. Logika biznesowa i sekret administracyjny leżały w kodzie klienta, który teoretycznie może modyfikować/przekazać się klientowi — sprzeczne z zasadą Store Factory „kod klienta nigdy nie dostaje szerokich sekretów".

### Decyzja

Nowy serwis `Spree::Prices::SyncEurFromPln` (server-side, na modelach, bez HTTP do własnego API i bez klucza) + `Spree::Nbp::EurPlnRate` (wydzielony fetch kursu, wstrzykiwalny dla testów) + rake `spree:prices:sync_eur_from_pln` (per sklep lub wszystkie, `STORE_ID`/`EUR_PLN_RATE`). Ta sama psychologiczna końcówka `.99` co wcześniej. Do zaplanowania przez sidekiq-cron/system cron na backendzie.

### Uzasadnienie

Logika cen i sekrety należą do zaufanego backendu, nie do repo storefrontu. Wydzielenie fetchu kursu od liczenia czyni serwis testowalnym bez sieci.

### Wpływ na upstream

Brak — nowy kod specyficzny dla forka (integracja NBP/PLN↔EUR).

## 2026-07-13 — Publiczny signup Store Factory za flagą

### Status

Gotowy do wdrożenia, domyślnie wyłączony.

### Kontekst

Zewnętrzny właściciel sklepu potrzebuje założyć konto i uruchomić provisioning bez wcześniejszego konta administracyjnego. Istniejący `Admin::StoresController` wymaga już zalogowanego administratora, więc nie może obsłużyć pierwszego wejścia.

### Decyzja

Dodano publiczny `POST /api/v3/admin/auth/signup`, który w jednej transakcji tworzy konto administratora, sklep, przypisanie roli i `ProvisioningRun`, a po commicie enqueue'uje job i wydaje standardową sesję admina. Dostęp kontroluje `STORE_SIGNUP_ENABLED` (domyślnie `false`), a endpoint używa limitu żądań logowania. Hasło jest walidowane niezależnie od użytej klasy admin usera: wymagane jest minimum 8 znaków i zgodne potwierdzenie. Sklep zaczyna z adresem `<code>.vercel.app`; po gotowym deploymencie serwis zapisuje rzeczywisty host Vercela.

### Uzasadnienie

To rozszerzenie Admin API i istniejącego provisioningu, bez przenoszenia logiki commerce do dashboardu. Transakcja zapobiega osieroconym kontom/sklepom, a flaga pozwala wdrożyć kod przed bezpiecznym uruchomieniem zewnętrznych integracji.

### Wpływ na upstream

Nowy endpoint i flaga są specyficzne dla tego forka. Store API i checkout nie zmieniają kontraktu; `sklepikFront` nie wymaga zmian. `@spree/admin-sdk` dostaje jedynie nową metodę `auth.signup`.

### Notatki

Przed publicznym włączeniem wymagane są realne E2E GitHub→Vercel oraz ochrona przed masowym zakładaniem kont (weryfikacja e-mail/CAPTCHA). Wyłączenie flagi zwraca 404 i nie wpływa na istniejące konta ani uruchomione joby.

## 2026-07-14 — Publikowany dokument storefrontu z izolacją draft/published

### Status

Pierwsza wersja zaimplementowana i pokryta testami modelu oraz Admin/Store API.

### Kontekst

Store Factory tworzył osobne storefronty, ale właściciel nie miał kanonicznego sposobu zmiany strony. Prototyp `edytor-sklepu` definiował ogólny schemat, lecz nie miał persystencji, autoryzacji, publikacji ani produkcyjnego renderera. Przechowywanie dowolnego HTML lub kodu w bazie zwiększałoby ryzyko XSS i uniemożliwiało kontrolowane aktualizacje floty.

### Decyzja

Backend przechowuje per sklep stronę `StorefrontPage` z walidowanym dokumentem JSON. Admin API pracuje na `draft_document`, a jawna akcja publikacji kopiuje go do niezmiennego publicznego snapshotu `published_document`. Store API zwraca wyłącznie snapshot i przed pierwszą publikacją odpowiada 404. Pierwszy kontrakt dopuszcza tylko sekcje `hero` oraz `product_grid`, ograniczone pola, bezpieczne linki i przyciski; nie przyjmuje HTML ani JavaScript. `lock_version` chroni przed nadpisaniem równoległej sesji edytora.

### Uzasadnienie

Jeden ustrukturyzowany kontrakt obsługuje edycję ręczną, przyszłe generowanie AI i wiele wersji wspólnego renderera. Oddzielenie wersji roboczej od publicznej zapobiega publikowaniu częściowych zmian. Scope przez `current_store.storefront_pages` zapewnia izolację tenantów.

### Wpływ na storefront i upstream

`sklepikFront` pobiera publiczny dokument i mapuje allowlistę sekcji na własne komponenty. Brak dokumentu zachowuje dotychczasową stronę kakao. To nowy moduł specyficzny dla forka; nie zmienia istniejących kontraktów produktów ani checkoutu.

## 2026-07-14 — Nowe sklepy jako draft i twarda bramka przyjęcia pieniędzy

### Status

Zaimplementowane; stare rekordy bez statusu pozostają aktywne dla kompatybilności.

### Kontekst

Publiczny signup potrafi utworzyć działający storefront, ale techniczny deploy nie oznacza sklepu gotowego prawnie i operacyjnie. Nowy merchant nie powinien przypadkowo przyjąć płatności bez produktu, dostawy, metody płatności, dokumentów lub opublikowanej strony.

### Decyzja

Nowe sklepy powstają ze statusem `draft`. Serwis gotowości raportuje jawne wymagania: dane kontaktowe, opublikowany produkt, aktywna metoda płatności, pokrycie wysyłki, co najmniej trzy uzupełnione polityki i opublikowana strona główna. Właściciel uruchamia sklep osobną akcją Admin API dopiero po spełnieniu wszystkich kontroli. Store API nadal pozwala oglądać katalog i konfigurować koszyk, ale kontrolery tworzenia płatności, sesji płatniczych i finalizacji koszyka odrzucają sklep nieaktywny.

### Uzasadnienie

Bramka jest po stronie zaufanego backendu i obejmuje wszystkie storefronty oraz integracje. Samo ukrycie przycisku w UI byłoby omijalne. Ograniczenie dotyczy wyłącznie money-critical końca ścieżki, więc właściciel może wcześniej przetestować sklep.

### Wpływ na storefront i upstream

Istniejący storefront nie wymaga nowej logiki. Próba checkoutu szkicu otrzymuje kontrolowany błąd `cart_cannot_complete`. Zmiana dotyka kontrolerów checkoutu forka i musi być uwzględniana przy aktualizacjach upstream.
