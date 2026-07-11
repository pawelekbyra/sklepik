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
