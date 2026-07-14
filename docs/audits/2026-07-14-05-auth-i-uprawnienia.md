# Audyt 05: uwierzytelnianie i uprawnienia

**Data:** 2026-07-14
**Baseline:** `sklepik` `9a4f693147`; `sklepikFront` `0f83b94`
**Zakres:** signup, login, logout, refresh, reset i zmiana hasła/e-maila, sesje/JWT/cookies/CSRF/CORS, role i permissions, owner/admin/customer, wybór sklepu, IDOR, brute force/rate limits, cykl życia sekretów i tokenów, dashboard oraz flow klienta w storefroncie/checkout.
**Tryb:** read-only; bez zmian kodu i bez destrukcyjnych prób produkcyjnych.

## Werdykt

**Nie dopuszczać jeszcze systemu do obsługi prawdziwych klientów ani płatności.** Granica admin → sklep jest w kodzie znacznie lepsza niż w typowym prototypie: JWT admina ma osobne `aud`, 5-minutowy TTL, membership per store, CanCanCan, API keys per store, ochronę ostatniego administratora i refresh cookie `HttpOnly`. Jednak jedna jawna produkcyjna pozycja P0 oraz problemy P1 powodują, że fundament auth nie jest obecnie wystarczający dla platformy wielosklepowej.

Najpilniejsze są: natychmiastowa rotacja znanego hasła produkcyjnego admina, rozdzielenie kont klientów per sklep, unieważnianie sesji przy zmianie hasła, zahashowanie refresh tokenów i domknięcie weryfikacji/odzyskiwania kont właścicieli.

| Priorytet | Liczba |
|---|---:|
| P0 | 1 |
| P1 | 5 |
| P2 | 4 |
| P3 | 2 |

## Potwierdzone mocne strony

- JWT rozdziela odbiorców `store_api` i `admin_api`, sprawdza podpis HS256, `iss`, `aud` i `exp`; admin ma domyślnie 5 minut, klient 1 godzinę (`spree/api/app/controllers/concerns/spree/api/v3/jwt_authentication.rb:12-14,51-60,74-89`; `spree/api/lib/spree/api/configuration.rb:12-15`).
- Admin API po JWT wymaga membership na wybranym sklepie; secret API key jest dodatkowo porównywany po `store_id` (`spree/api/app/controllers/concerns/spree/api/v3/admin_authentication.rb:32-68`).
- Role w `Spree::Ability` są liczone tylko z `RoleUser` bieżącego sklepu (`spree/core/app/models/spree/ability.rb:47-69`), a `RoleUser#ensure_store` wiąże rolę z właściwym zasobem sklepu (`spree/core/app/models/spree/role_user.rb:41-52`).
- `AdminUsersController` scope'uje personel do sklepu, osobno chroni grant ról i nie pozwala usunąć ostatniego admina (`spree/api/app/controllers/spree/api/v3/admin/admin_users_controller.rb:23-53,69-83,112-141`).
- Dashboard trzyma access token tylko w pamięci, refresh token w podpisanym cookie `HttpOnly`; współbieżny refresh w jednej karcie jest serializowany (`packages/dashboard-core/src/providers/auth-provider.tsx:35-41,50-53,86-104`). Storefront przechowuje access/refresh/cart tokeny w cookies `HttpOnly`, `Secure` w production i `SameSite=Lax` (`sklepikFront/src/lib/spree/cookies.ts:43-59,76-84,106-114`).
- Login zwraca jednolity błąd dla nieznanego e-maila i złego hasła, reset zawsze `202`, więc podstawowa enumeracja kont jest ograniczona (`spree/core/app/models/spree/authentication/strategies/email_password_strategy.rb:9-18`; `spree/api/app/controllers/spree/api/v3/store/customer/password_resets_controller.rb:32-42`).
- Login/register/reset mają limity, globalny API limit używa publishable key lub IP (`spree/api/lib/spree/api/configuration.rb:17-23`; `spree/api/app/controllers/spree/api/v3/base_controller.rb:35-38`).
- Zmiana e-maila lub hasła klienta wymaga aktualnego hasła (`spree/api/app/controllers/spree/api/v3/store/customers_controller.rb:38-53,80-95`).
- Link resetu dopuszcza tylko origin sklepu, a token resetu jest podpisany, wygasa i unieważnia się po zmianie hasła (`spree/api/app/controllers/spree/api/v3/store/customer/password_resets_controller.rb:19-39`; `spree/core/app/models/concerns/spree/user_methods.rb:47-51`).

## Findings

### AUTH-001 — P0 — Produkcyjne hasło administratora jest jawne i słabe

**Dowód:** kanoniczna dokumentacja zapisuje dokładny, prosty credential produkcyjnego konta i fakt jego świadomego przywrócenia (`docs/stan-projektu.md:40-43`; wartość celowo zredagowana w tym raporcie). Panel jest publiczny, a login dopuszcza 5 prób/IP/minutę (`spree/api/app/controllers/spree/api/v3/admin/auth_controller.rb:10-13`). Seed ma dodatkowo stałe, powszechnie znane fallback credentials, jeśli operator nie ustawi env (`spree/core/app/services/spree/seeds/admin_user.rb:7-13`; wartości również celowo zredagowane).

**Wpływ:** przejęcie panelu daje kontrolę nad produktami, zamówieniami, danymi klientów, kluczami API, webhookami i ustawieniami sklepów. Rate limit per IP nie chroni przed użyciem już znanego poprawnego hasła.

**Rekomendacja:** natychmiast zrotować konto produkcyjne na losowe hasło z managera sekretów; wylogować wszystkie jego refresh sessions; usunąć sekret z dokumentacji i historii, uznać go za skompromitowany; produkcyjny seed ma odmawiać startu bez jawnych `ADMIN_EMAIL` i `ADMIN_PASSWORD`, nigdy używać fallbacku. Dodać MFA/WebAuthn dla operatorów przed skalowaniem.

**Zamknięcie:** próba starym hasłem zwraca 401; baza nie ma aktywnych refresh tokenów sprzed rotacji; skan gita nie znajduje hasła; production seed bez env kończy się kontrolowanym błędem; MFA ma E2E login/recovery.

### AUTH-002 — P1 — Tożsamość klienta, login, JWT i reset są globalne, nie per sklep

**Dowód:** `User.for_store` jawnie zwraca pełny scope (`spree/core/app/models/concerns/spree/user_methods.rb:189-192`); e-mail jest globalnie unikalny (`spree/core/app/models/spree/legacy_user.rb:14`); strategia loginu szuka globalnie po e-mailu, a kontroler nie przekazuje sklepu (`spree/core/app/models/spree/authentication/strategies/email_password_strategy.rb:5-18`; `spree/api/app/controllers/spree/api/v3/store/auth_controller.rb:115-123`); rejestracja nie przypisuje sklepu (`spree/api/app/controllers/spree/api/v3/store/customers_controller.rb:13-16`); JWT odnajduje usera globalnie i nie zawiera `store_id` (`spree/api/app/controllers/concerns/spree/api/v3/jwt_authentication.rb:51-60,99-108`); refresh token również wiąże się tylko z userem (`spree/core/app/models/spree/refresh_token.rb:5-7,34-41`). Istniejący plan sam potwierdza nierozpoczęty stan (`docs/plans/per-store-customer-accounts.md:15-23`).

**Wpływ:** klient sklepu A może zalogować się tym samym credentialem w sklepie B i ujawnić tam globalny profil/e-mail; nie może niezależnie założyć tego samego e-maila z innym hasłem. To łamie deklarowaną niezależność white-label tenantów i stwarza ryzyko IDOR przy każdym zasobie klienta, który przypadkiem nie będzie doscope'owany do store.

**Rekomendacja:** wdrożyć zatwierdzony plan per-store customer accounts: `store_id` na customer identity, unikalność `[store_id,email]`, store-aware login/register/JWT validation/refresh/reset oraz trwały override produkcyjnego host-app Devise. Admin identity pozostawić globalną z rolami per store.

**Zamknięcie:** E2E na dwóch realnych tenantach: ten sam e-mail ma dwa różne hasła; token A nie działa na Store API B; login/reset/profile/cart/orders/addresses/cards/credits A nie ujawniają ani nie modyfikują B. Test negatywny obejmuje każdy customer controller.

### AUTH-003 — P1 — Reset hasła jest globalny i może być uruchomiony z obcego sklepu

**Dowód:** request resetu robi `Spree.user_class.find_by(email:)`, a update `find_by_password_reset_token`, bez `current_store` (`spree/api/app/controllers/spree/api/v3/store/customer/password_resets_controller.rb:32-39,45-65`). `redirect_url` jest wprawdzie sprawdzany względem bieżącego sklepu, ale zdarzenie publikuje globalny user (`:25-38`).

**Wpływ:** sklep B może zainicjować reset globalnego konta utworzonego w A i wysłać link brandowany/obsłużony przez B. Po przyszłym rozdzieleniu tenantów lookup bez scope może zmienić hasło złego konta.

**Rekomendacja:** naprawić razem z AUTH-002; request i consume tokenu muszą weryfikować `[store,user]`, a event/webhook musi być jednoznacznie przypisany do sklepu.

**Zamknięcie:** reset e-maila istniejącego tylko w A wywołany kluczem/hostem B nie publikuje eventu; token A użyty w B jest odrzucony; dwa konta z tym samym e-mailem resetują się niezależnie.

### AUTH-004 — P1 — Zmiana/reset hasła nie unieważnia istniejących refresh tokenów

**Dowód:** model oferuje `RefreshToken.revoke_all_for`, lecz poza specem nie ma żadnego wywołania (`spree/core/app/models/spree/refresh_token.rb:44-47`; wynik `rg "revoke_all_for"` znajduje tylko model i test). `CustomersController#update` zapisuje nowe hasło bez revocation (`spree/api/app/controllers/spree/api/v3/store/customers_controller.rb:38-53`), a reset natychmiast tworzy kolejny refresh token, również nie usuwając poprzednich (`spree/api/app/controllers/spree/api/v3/store/customer/password_resets_controller.rb:57-65`).

**Wpływ:** skradziona 30-dniowa sesja pozostaje zdolna mintować nowe JWT mimo zmiany/resetu hasła przez właściciela. Odzyskanie konta nie odzyskuje wyłącznej kontroli.

**Rekomendacja:** atomowo revoke all sessions przy zmianie/resetowaniu hasła, następnie wystawić dokładnie jedną nową sesję bieżącemu klientowi. Dodać ekran urządzeń/sesji i „wyloguj wszędzie”; analogiczny mechanizm dla admin password reset.

**Zamknięcie:** dwa refresh tokeny → zmiana/reset → oba stare zwracają 401, nowy działa; test transakcyjny nie zostawia konta bez hasła lub z częściowo zrewokowanymi sesjami.

### AUTH-005 — P1 — Refresh tokeny są przechowywane w bazie w postaci jawnej

**Dowód:** migracja ma kolumnę `token` i unikalny indeks (`spree/core/db/migrate/20260317000000_create_spree_refresh_tokens.rb:3-14`); model używa `has_secure_token`, a lookup wykonuje `find_by(token:)` (`spree/core/app/models/spree/refresh_token.rb:5-12`; admin `auth_controller.rb:48-60`; store `auth_controller.rb:50-66`). W przeciwieństwie do API keys nie ma digestu.

**Wpływ:** odczyt bazy, backupu lub logu/debug dumpu daje gotowe 30-dniowe credentials. Dla admina oznacza możliwość odnawiania uprzywilejowanych JWT.

**Rekomendacja:** przechowywać tylko SHA-256/HMAC digest losowego tokenu, raw wartość pokazywać wyłącznie przy wydaniu; zrobić migrację/revocation istniejących tokenów i indeks digestu. Nie logować cookie/body.

**Zamknięcie:** baza nie zawiera raw tokenu; token z odpowiedzi/cookie mapuje się wyłącznie przez digest; skan logów i backupu nie znajduje surowych wartości cookie; stare tokeny są unieważnione po migracji.

### AUTH-006 — P1 — Publiczny signup właściciela nie potwierdza e-maila i nie ma pełnego recovery

**Dowód:** `SignupsController` tworzy admina, sklep, rolę i sesję natychmiast po podaniu e-maila/hasła (`spree/api/app/controllers/spree/api/v3/admin/signups_controller.rb:22-31,38-69,93-97`). Dashboard opisuje flow jako „prototype, no email verification” (`packages/dashboard-core/src/providers/auth-provider.tsx:15-20`). W v3 admin routes/controllers brak endpointu forgot/reset password i email confirmation; zaproszenie dla istniejącego usera wymaga aktualnego hasła (`spree/api/app/controllers/spree/api/v3/admin/invitation_acceptances_controller.rb:64-82`).

**Wpływ:** literówka lub cudzy e-mail tworzy sklep i zasoby z niezweryfikowanym właścicielem; właściciel po utracie hasła nie ma samoobsługowego recovery. To blokuje bezpieczny self-service i wiarygodną komunikację provisioning/billing.

**Rekomendacja:** stan konta `pending_verification`, jednorazowy wygasający token, resend z limitami, neutralne odpowiedzi anty-enumeracyjne; dopiero po potwierdzeniu publikacja/operacje ryzykowne. Dodać admin forgot/reset, revocation sessions i bezpieczny recovery. Resend jest wyborem dostawcy, nie warunkiem architektonicznym — można użyć dowolnego poprawnie skonfigurowanego mailera.

**Zamknięcie:** E2E signup → e-mail → confirm → login; niepotwierdzony owner nie uruchamia sklepu ani billing; token jest single-use i wygasa; reset admina unieważnia stare sesje; resend i brute force mają testy limitów.

### AUTH-007 — P2 — Deklarowana ochrona CSRF admin refresh cookie opiera się na błędnym założeniu o CORS

**Dowód:** produkcyjne cookie ma `SameSite=None; Secure` (`spree/api/app/controllers/concerns/spree/api/v3/admin/auth_cookies.rb:51-56`). Komentarz jawnie rezygnuje z tokenu CSRF, twierdząc, że preflight/CORS blokuje cross-origin (`:10-18`). Jednak `refresh` i `logout` przyjmują POST bez sprawdzenia `Origin`/CSRF (`spree/api/app/controllers/spree/api/v3/admin/auth_controller.rb:36-73`). CORS ogranicza odczyt odpowiedzi przez JS, nie wysłanie prostego requestu HTML/form. Repo nie zawiera konfiguracji `Rack::Cors`; istnieje tylko model allowlisty i dokumentacja, więc jej realne działanie jest dodatkowo runtime-unknown. Obecny dashboard używa same-origin Vercel rewrite (`packages/dashboard/vercel.json:3-9`), co zmniejsza potrzebę `SameSite=None`, ale backend ustawia je globalnie w całym production.

**Wpływ:** obcy origin może wymusić logout/rotację refresh cookie (session DoS), a login CSRF może próbować osadzić sesję atakującego. Przyszłe akcje cookie-auth zwiększą blast radius.

**Rekomendacja:** dla obecnej topologii użyć `SameSite=Lax` (lub Strict, jeśli flow pozwala); dla cross-origin dodać twardą walidację `Origin`/`Sec-Fetch-Site` i synchronizer/double-submit CSRF token. CORS traktować jako politykę odczytu, nie CSRF. Potwierdzić aktywny middleware na produkcji.

**Zamknięcie:** test przeglądarkowy/form POST z nieallowlistowanego originu nie rotuje/usuwa cookie i nie loguje do obcego konta; dozwolony dashboard działa; production middleware test potwierdza dokładną allowlistę i credentials.

### AUTH-008 — P2 — Logout i zmiana uprawnień nie unieważniają już wydanych JWT

**Dowód:** JWT zawiera losowy `jti`, ale decode nie sprawdza żadnej denylisty/session version (`spree/api/app/controllers/concerns/spree/api/v3/jwt_authentication.rb:51-60,74-81`). Logout usuwa tylko refresh token (`admin/auth_controller.rb:66-73`; `store/auth_controller.rb:70-80`). Usunięcie roli admina jest łagodzone membership checkiem na każdy request, lecz JWT klienta po logout pozostaje ważny do 1h.

**Wpływ:** przechwycony access token klienta działa po logout/reset do końca TTL; operator nie ma natychmiastowego kill switch. Admin membership jest sprawdzany dynamicznie, więc jego ryzyko jest mniejsze, ale globalne odebranie dostępu nie ma jednej revocation primitive.

**Rekomendacja:** utrzymać krótkie TTL, dodać `session_id`/token version powiązane z revokowalną sesją; logout/reset/recovery unieważnia sesję. Dla admina rozważyć denylistę jedynie dla incydentów, nie każdy request bez cache.

**Zamknięcie:** access token użyty po „logout all”/reset zwraca 401 w wymaganym SLA; odebranie ostatniej roli sklepu natychmiast daje 403; test obejmuje cache/replica lag.

### AUTH-009 — P2 — Rotacja refresh tokenu jest podatna na wyścig między kartami/requestami

**Dowód:** `rotate!` tworzy nowy token i niszczy stary w transakcji, ale brak row lock/idempotency/reuse detection (`spree/core/app/models/spree/refresh_token.rb:18-31`). Dashboard serializuje wyłącznie wywołania w ramach jednej instancji React (`packages/dashboard-core/src/providers/auth-provider.tsx:40-41,97-104`), nie między kartami/urządzeniami. Storefront SSR ma własny mechanizm retry/refresh z cookies (`sklepikFront/src/lib/spree/auth-helpers.ts:80-93`) bez wspólnego locka między requestami.

**Wpływ:** dwie karty lub równoległe server actions mogą odświeżyć ten sam token; jeden request wygra, drugi dostanie 401 i lokalnie wyczyści sesję. To powoduje losowe wylogowania, a bez reuse detection utrudnia odróżnienie wyścigu od kradzieży.

**Rekomendacja:** `with_lock`/atomic consume, krótki grace window z rodziną tokenów albo idempotency key; wykrywać reuse i revokować token family w podejrzanym przypadku. Testować wielokartowo i równolegle.

**Zamknięcie:** test z 10 równoległymi refreshami ma zdefiniowany deterministyczny wynik, nie pozostawia wielu aktywnych gałęzi i nie wylogowuje prawidłowej sesji; reuse poza grace revokuje rodzinę i generuje alert.

### AUTH-010 — P2 — Brak MFA i silnej polityki credentiali dla adminów

**Dowód:** signup waliduje tylko obecność/potwierdzenie i minimum 8 znaków (`spree/api/app/services/spree/api/v3/admin/signup_password_validator.rb`; wywołanie `signups_controller.rb:49-55`); repo nie zawiera TOTP/WebAuthn/recovery codes. Produkcyjny przykład AUTH-001 pokazuje, że sama polityka operacyjna nie wystarcza.

**Wpływ:** phishing/reuse jednego hasła daje pełny panel. Ryzyko rośnie wraz z personelem, partnerami i płatnościami.

**Rekomendacja:** WebAuthn/passkeys lub TOTP dla owner/admin, recovery codes, step-up auth dla kluczy, payout/refund/permissions; sprawdzanie haseł względem list skompromitowanych bez wysyłania pełnego hasła.

**Zamknięcie:** admin bez drugiego składnika nie wykona operacji wysokiego ryzyka; testy enrollment/login/recovery/revocation; audyt loguje zdarzenia bez sekretów.

### AUTH-011 — P3 — Nagłówki rate limit dla endpointów auth raportują niewłaściwy limit

**Dowód:** `RATE_LIMIT_RESPONSE` zawsze wstawia `rate_limit_per_key` (domyślnie 300), choć login ma limit 5, register/reset 3, refresh 10 (`spree/api/app/controllers/spree/api/v3/base_controller.rb:22-32`; `spree/api/lib/spree/api/configuration.rb:18-23`).

**Wpływ:** klient i operator widzą fałszywe dane diagnostyczne; automatyczny backoff może działać źle.

**Rekomendacja:** osobne response lambda lub limit przekazywany z konkretnej reguły; test każdego endpointu.

**Zamknięcie:** 429 login raportuje 5, register/reset 3, refresh 10, globalny 300; `Retry-After` zgodny z realnym oknem.

### AUTH-012 — P3 — Lifecycle sesji i zdarzenia bezpieczeństwa nie mają kompletnej obserwowalności użytkownika

**Dowód:** refresh token przechowuje IP i user-agent (`spree/core/app/models/spree/refresh_token.rb:23-27,35-41`), ale dashboard/storefront nie mają listy sesji ani akcji revoke; nie znaleziono audit events dla login success/failure, refresh reuse, password/email/role changes.

**Wpływ:** właściciel nie zobaczy obcej sesji; incydent trudno odtworzyć.

**Rekomendacja:** strukturalne security events z minimalizacją PII, retencją i korelacją; UI „aktywne sesje”; alerty na credential stuffing, reuse tokenu, zmianę e-maila/hasła/MFA/roli/API key.

**Zamknięcie:** scenariusze bezpieczeństwa tworzą audytowalne zdarzenia bez raw credentiali; owner może odwołać wskazaną sesję; retencja i dostęp są przetestowane.

## Macierz przepływów

| Flow | Stan kodowy | Najważniejsza luka |
|---|---|---|
| Owner signup | działa, feature flag, auto-login | brak confirm/recovery; AUTH-006 |
| Admin login/logout/refresh | działa; cookie HttpOnly, JWT 5 min | P0 credential, CSRF i raw refresh |
| Admin permissions/store selection | membership + CanCanCan + per-store roles | potrzebny pełny E2E dwóch tenantów |
| Staff invitation | token, expiry, password dla istniejącego usera | brak MFA/recovery i runtime mail proof |
| Customer register/login/logout | działa w storefroncie | globalna identity; AUTH-002 |
| Customer refresh | rotacja 30 dni | plaintext, brak family/reuse, race |
| Password reset | signed expiring token, neutral 202 | globalny lookup, brak revoke sessions |
| E-mail change | current password | brak reconfirmation/notification |
| Customer dashboard | JWT + scoped API zależnie od kontrolera | brak kompletnego cross-tenant E2E |
| Checkout customer/guest | JWT i/lub guest cart token w HttpOnly cookie | pełne IDOR/payment E2E w audycie 07 |

## Ograniczenia i nieweryfikowalne elementy runtime

- Nie łączono się z produkcyjną bazą ani panelem i nie wykonywano brute force, CSRF, resetu, zmiany haseł czy destrukcyjnych testów sesji.
- Nie da się z tego repo potwierdzić produkcyjnego modułu Devise `Spree::User` w efemerycznym host-app `server/`, jego modułów (`confirmable`, `recoverable`, `lockable`) ani faktycznej konfiguracji `Rack::Cors`; repo samo wskazuje ten brak w `docs/plans/per-store-customer-accounts.md:20,29,59,71`.
- Nie potwierdzono wartości produkcyjnych `JWT_SECRET_KEY`, TTL, `Rails.cache` ani tego, czy wszystkie instancje używają wspólnego Redis. Przy cache lokalnym rate limits nie są globalne.
- Nie potwierdzono realnej dostarczalności maili reset/invitation/signup. Kod webhooka resetu istnieje w `sklepikFront`, ale konfiguracja dostawcy/secret/domena i E2E dostawy należą do audytu jobs/email.
- Próba uruchomienia 6 skupionych speców RSpec zakończyła się przed przykładami: `SQLite3::CantOpenException: unable to open database file`, ponieważ dummy DB/log w repo poza writable root nie były zapisywalne. Wynik: **0 examples**, nie zielony test. Statyczne wnioski mają podane dowody file:line; pełna regresja wymaga zapisywalnego środowiska testowego.

## Kolejność napraw

1. **Dzisiaj:** AUTH-001 — rotacja hasła, revoke sessions, usunięcie sekretu z dokumentacji; potwierdzenie produkcyjne.
2. **Przed danymi klientów:** AUTH-002 + AUTH-003 — per-store customer identity i pełne negative E2E dwóch tenantów.
3. **Przed self-service launch:** AUTH-004 + AUTH-005 + AUTH-006 — revocation, digest tokenów, verify/recovery ownera.
4. **Przed płatnościami:** AUTH-007 + AUTH-008 + AUTH-010 — CSRF boundary, session kill switch, MFA/step-up.
5. **Utwardzenie:** AUTH-009, AUTH-011, AUTH-012 — deterministyczna rotacja, poprawne headers, security observability.

## Minimalny pakiet testów zamykających audyt

- Contract/E2E dwóch tenantów dla customer i admin auth, obejmujący wszystkie credential types i negatywne IDOR.
- Równoległe testy refresh/logout/reset/revoke oraz token-family reuse.
- Browser CSRF suite z allowlisted i obcym originem, prostym form POST oraz fetch/preflight.
- Brute-force suite na wspólnym Redis, przez co najmniej dwie instancje i wiele publishable keys; limit per IP + per account z bezpieczną odpowiedzią.
- Owner signup/confirm/reset/MFA/recovery E2E z prawdziwą skrzynką testową.
- Checkout jako guest, customer A w A, token A w B; cart association, order list/detail, addresses, cards, credits.
- Secret scan DB/logs/backups/repo oraz rotacja wszystkich credential classes.
