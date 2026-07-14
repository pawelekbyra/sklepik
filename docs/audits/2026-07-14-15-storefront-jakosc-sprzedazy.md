# Audyt 15: storefront i jakość sprzedaży

**Data:** 2026-07-14
**Zakres:** `sklepikFront` przy rewizji `0f83b94`, kontrakty Store API i kanon repo `sklepik` przy rewizji bazowej `9a4f693147`.
**Charakter:** audyt kodu, UX i zdolności sprzedażowej; bez zmian produktu, checkoutu, danych i produkcji.

## Werdykt

Storefront ma szeroki fundament: katalog, wyszukiwanie/facety, PDP z wariantami i galerią, koszyk, wielobramkowy checkout, konto, zamówienia, polityki, podstawowe schema.org, sitemapę, e-maile i renderer opublikowanego layoutu. Lint, TypeScript, parytet locale i 97 testów jednostkowych są zielone.

**Nie jest jeszcze powtarzalnie gotowy dla prawdziwych klientów.** Awaria lub brak konfiguracji API często wygląda jak pusty sklep albo 404; nie ma zgodnego z obecnym routingiem E2E checkoutu; analityka uruchamia się bez mechanizmu zgody; akceptacja dokumentów jest tylko checkboxem w pamięci przeglądarki. Istotne są też luki SEO/i18n, brak realnego cache mimo komentarzy oraz renderer ignorujący część publikowanego kontraktu.

Nie dubluję `MONEY-001..003`, `SEC-001/002`, `ASYNC-004/008` ani `ORDER-002/009/010`; pokazuję ich skutek w storefront UX.

| Priorytet | Liczba nowych findings |
|---|---:|
| P0 | 0 |
| P1 | 5 |
| P2 | 9 |
| P3 | 1 |

## Findings

### FRONT-001 — P1 — awaria commerce wygląda jak pusty sklep albo nieistniejący produkt

**Dowód: fakt.** `getProducts()` łapie każdy błąd Store API i zwraca pustą listę; `getProduct()` zwraca `undefined` (`sklepikFront/src/lib/data/products.ts:58-68,89-107`). PDP zamienia to na `notFound()` (`src/app/[locale]/(storefront)/products/[slug]/page.tsx:52-62`). Layout analogicznie zeruje kategorie/store info (`src/app/[locale]/(storefront)/layout.tsx:48-61`), a polityki każdy błąd zamieniają na brak dokumentu (`src/lib/data/policies.ts:6-8`). Brak konfiguracji SDK także zwraca puste dane. Jest to sprzeczne z komentarzem `ProductListing`, według którego błąd miał trafić do boundary (`src/components/products/ProductListing.tsx:126-130`).

**Wpływ:** outage, zły klucz tenanta i timeout udają legalne empty/404; klient odchodzi, crawler może utrwalić zniknięcie stron, a monitoring nie ma wiarygodnego sygnału.

**Naprawa/test zamykający:** klasyfikować 404/empty osobno od timeout/401/403/5xx/config; dla drugiej klasy kontrolowany 5xx, alert i ewentualny ostatni bezpieczny snapshot. Contract/E2E pięciu klas błędu ma dowieść, że tylko prawdziwy brak daje empty/404.

### FRONT-002 — P1 — pomiar marketingowy uruchamia się bez zgody użytkownika

**Dowód: fakt.** Root montuje GTM, Vercel Analytics i Speed Insights bez stanu consent (`src/app/layout.tsx:1-3,43-58`). GA4 wysyła zdarzenia katalogu, wyszukiwania, PDP, koszyka, checkoutu i zakupu bez bramki (`src/lib/analytics/gtm.ts`). Brak CMP, Consent Mode i centrum preferencji; checkbox checkoutu dotyczy dokumentów, nie analityki.

**Wpływ:** brak technicznej kontroli opcjonalnego trackingu/cookies i dowodu preferencji dla każdego sklepu.

**Naprawa/test:** platformowy consent manager per tenant/region, default deny, wersjonowanie/wycofanie i Google Consent Mode v2. Czysta przeglądarka przed zgodą nie może wysłać ani zapisać danych opcjonalnych; accept/reject/revoke muszą przejść E2E.

### FRONT-003 — P1 — checkbox dokumentów nie tworzy dowodu akceptacji ani wersji

**Dowód: fakt.** Rejestracja i checkout wymagają lokalnego boolean (`PolicyConsent.tsx:11-31`, register `:42,70-77`, checkout `:120,542-548`). `register()` wysyła tylko dane konta, bez ID/wersji dokumentów, czasu i źródła (`src/lib/data/customer.ts:106-125`). Zalogowany klient nie widzi checkboxa checkoutu na założeniu, że zaakceptował treść przy rejestracji.

**Wpływ:** nie da się odtworzyć zaakceptowanej treści ani wymusić reconsent po zmianie.

**Naprawa/test:** immutable policy snapshots i rekord store/customer-or-order/policy hash/version/time/locale/source. E2E ma utrwalić dokładny snapshot i wymusić reconsent po publikacji nowej wymaganej wersji.

### FRONT-004 — P1 — brak pełnej tożsamości sprzedawcy i ścieżki obsługi klienta

**Dowód: fakt.** Routing nie ma strony kontaktu/danych przedsiębiorcy/FAQ/guest order lookup/rozpoczęcia zwrotu lub reklamacji. Footer pokazuje nazwę z enva, kategorie, konto i generyczne polityki, bez profilu firmy (`src/components/layout/Footer.tsx`). Organization może opcjonalnie dodać tylko e-mail z enva (`src/lib/seo.ts:134-179`). Readiness wymaga danych kontaktowych, ale renderer ich nie konsumuje. Cross-reference `ORDER-002/009/010`.

**Wpływ:** sklep `live` może nie pokazać sygnałów zaufania ani kanału pomocy, obniżając konwersję i zostawiając ręczną obsługę poza systemem.

**Naprawa/test:** publiczny profil sprzedawcy ze Store API, obowiązkowy footer/contact/dostawa/FAQ oraz guest order support i wejście do zwrotu/reklamacji. E2E nowego tenanta ma potwierdzić dane, działający kontakt i brak 404.

### FRONT-005 — P1 — brak aktualnego regression gate krytycznej ścieżki sprzedaży

**Dowód: fakt repo; pełnego E2E nie uruchomiono.** Jedyny Playwright test otwiera usunięty routing `/us/en/products` (`e2e/checkout.spec.ts:23`) i testuje USA/Stripe po angielsku; obecny routing to `/products`, rynek PL. Health URL także wskazuje `/us/en` (`playwright.config.ts:38-45`). Brak E2E konta, search/filter, polityk, renderer, mobile, alternatywnych bramek i production canary. Build w audycie utknął na kompilacji i został przerwany po ok. 120 s.

**Wpływ:** checkout może regresować mimo 97 zielonych unit tests; niechronione są granice Next↔API↔provider↔webhook.

**Naprawa/test:** aktualny hermetyczny golden path jako required PR gate + kontrolowany Stripe test-mode canary po deployu; matryca mobile/desktop Chromium, Firefox, WebKit i negatywne scenariusze płatności. Celowa regresja route/API musi czerwienić gate.

### FRONT-006 — P2 — locale nie dociera do HTML i awarii

**Dowód: fakt.** Root zawsze ma `<html lang="en">` (`src/app/layout.tsx:43`); global error również i ma angielskie teksty (`src/app/global-error.tsx:19-26`). Metadata fallbacki i breadcrumb zawierają `Shop`, `Product/Category Not Found`, `Home`. Parytet kluczy tłumaczeń nie dowodzi jakości ani poprawnego języka dokumentu.

**Wpływ:** błędne sygnały dla screen readerów, tłumaczeń i SEO; awarie wypadają z marki.

**Naprawa/test:** `lang` z route locale i wszystkie publiczne fallbacki przez i18n. Dla każdej aktywnej wersji axe ma potwierdzić zgodność `html[lang]`, title, aria i widocznych tekstów.

### FRONT-007 — P2 — sitemap publikuje 404 i pomija ważne strony

**Dowód: fakt.** Generator dodaje `${basePath}/c` (`src/app/sitemap.ts:200-217`), lecz istnieje tylko `c/[...permalink]`. Nie zawiera opublikowanych polityk/stron informacyjnych, a przy błędzie API pomija całe locale (`:188-196`).

**Wpływ:** oficjalna sitemap wskazuje 404, a outage może ją opróżnić.

**Naprawa/test:** generować tylko opublikowane/routowalne zasoby, uwzględnić polityki, atomowo zachować ostatnią poprawną mapę. Każdy URL sitemapy ma zwracać 200 i self-canonical; test outage nie może wyzerować mapy.

### FRONT-008 — P2 — canonicale, hreflang i noindex są niekompletne

**Dowód: fakt.** Brak `alternates.languages`/`x-default`. Polityki nie mają canonicala (`policies/[slug]/page.tsx:14-39`). Account/cart/checkout/confirm/order-placed nie ustawiają `noindex`; robots.txt tylko blokuje crawl części ścieżek i pomija confirm/order-placed (`src/app/robots.ts:14-27`). Product OG ma typ `website` (`src/lib/metadata/product.ts:64-69`).

**Wpływ:** duplikaty językowe, indeksacja technicznych/prywatnych URL-i i słabsze preview.

**Naprawa/test:** wspólny metadata builder: canonical, hreflang tylko dla realnych tłumaczeń, x-default, noindex dla prywatnych route groups i poprawne OG/Twitter. Crawler fixture ma asertować wszystkie grupy tras.

### FRONT-009 — P2 — deklarowany cache katalogu nie istnieje

**Dowód: fakt.** Funkcje opisane jako cached nie mają `"use cache"`, `unstable_cache` ani tagów (`src/lib/data/products.ts:40-55,71-86,110-115`); `cached.ts` to tylko request-local `React.cache`. `cacheComponents: false`, layout/home są `force-dynamic`. Webhook rewaliduje tagi, których fetch nie rejestruje (`src/lib/webhooks/handlers.ts:210-228`). Dokumentacja nadal obiecuje TTL/edge cache.

**Wpływ:** każdy request obciąża wspólny backend, zwiększa TTFB i failure coupling; inwalidacja jest pozorna.

**Naprawa/test:** cache publicznych snapshotów per tenant/locale/market z tagami i stale-if-error; dane użytkownika bez shared cache. Test hit/miss, tenant isolation, webhook invalidation i load test mają dowieść budżetu TTFB/QPS.

### FRONT-010 — P2 — renderer ignoruje część opublikowanego kontraktu

**Dowód: fakt.** Backend publikuje/waliduje `backgroundImageAssetId` (`sklepik/spree/core/app/models/spree/storefront_page.rb:37-63,125-145`), frontend je typuje, ale nie przekazuje do Hero, które nie obsługuje tła (`storefront-page.ts:18-27`, `StorefrontPageRenderer.tsx:25-45`, `HeroSection.tsx`). Nieznany typ sekcji jest cicho pomijany (`Renderer.tsx:64`), response nie ma runtime validation, a błąd inny niż 404 wywraca homepage. Brak testów kontraktu/renderera.

**Wpływ:** panel mówi „opublikowano”, lecz klient nie widzi zmiany; nowy schema może dać częściowo pustą stronę.

**Naprawa/test:** współdzielony schema package, runtime parse/capability negotiation, kompletna obsługa pól albo blokada publikacji, last-known-good fallback+alert. Golden fixtures i visual snapshots mają objąć każde publikowalne pole i unknown schema.

### FRONT-011 — P2 — błędy, loading i paginacja nie są odporne

**Dowód: fakt.** Brak segmentowych `error.tsx`, `loading.tsx`, `not-found.tsx`; root Suspense ma `fallback={null}`. Infinite scroll po błędzie nie pokazuje komunikatu ani retry (`InfiniteProductList.tsx:97-108,146-159`), kolejne strony nie mają URL/manual fallback. Cart/auth przy błędzie często zerują stan (`CartContext.tsx:51-58`, `AuthContext.tsx:62-69`).

**Wpływ:** biały ekran/pustka/pozorny logout; bez IntersectionObserver/JS nie da się przejść katalogu.

**Naprawa/test:** zlokalizowane boundaries z retry/correlation ID, zachowanie ostatniego stanu przy transient failure, crawlable/manual pagination z infinite scroll jako enhancement. Fault injection i test bez JS mają potwierdzić odzyskanie.

### FRONT-012 — P2 — dostępność, responsive i cross-browser nie mają bramki

**Dowód: fakt pokrycia.** Brak axe/pa11y/Lighthouse/visual regression. Playwright to tylko Desktop Chrome i jeden checkout (`playwright.config.ts:32-37`). Brak testów mobile, klawiatury, zoomu, reduced motion, screen reader i kontrastu. Kod ma dobre aria/alt i modal focus restore, ale koszyk ma stały poziomy flex bez wariantu mobilnego (`cart/page.tsx:98-151`) i wymaga weryfikacji 320 px/200%.

**Wpływ:** regresje mogą wykluczyć klientów na Safari/mobile mimo zielonych testów.

**Naprawa/test:** axe + ręczny WCAG 2.2 AA, WebKit mobile/Firefox/Chromium, visual 320/375/768/1440 i 200/400% zoom. Zero serious/critical, checkout klawiaturą i brak overflow są warunkiem zamknięcia.

### FRONT-013 — P2 — SEO/branding są rozdwojone między Store API i env

**Dowód: fakt.** Logo może pochodzić z Store API, ale nazwa, opis, canonical base, SEO title, sociale i support email są z env (`src/lib/store.ts`, `src/lib/seo.ts`). Product schema nie ma brand/seller, home używa wspólnego `/social-image.webp`. Factory według `INFRA-011` nie ustawia pełnego manifestu env.

**Wpływ:** sklep może mieć różne nazwy w UI/metadata/e-mail/schema, odziedziczyć obraz kakao lub nie mieć canonicali.

**Naprawa/test:** Store API jako kanon profilu/SEO/social/trust; env tylko bootstrap. Zmiana brandingu jednego tenanta ma bez deployu atomowo zmienić header, metadata, JSON-LD, e-mail i OG bez wpływu na drugi.

### FRONT-014 — P2 — prywatne routy są chronione głównie po hydracji

**Dowód: fakt; autoryzację API ocenia audyt 05.** Account layout jest client-side i redirectuje w `useEffect` (`account/layout.tsx:146-180`). Login przyjmuje `redirect` z query i przekazuje bez lokalnej allowlisty do `router.push` (`account/page.tsx:39-58`).

**Wpływ:** client round-trip/migotanie, słabe działanie bez JS i powierzchnia redirect/phishing zależna od routera. UI nie może być granicą danych.

**Naprawa/test:** server-side auth gate, lokalny parser `returnTo`, no-store/noindex. Niezalogowany request ma redirectować przed HTML danych; external/protocol-relative/encoded URL mają być odrzucone.

### FRONT-015 — P3 — brak jawnej degradacji e-maili i funkcji opcjonalnych

**Dowód: fakt; cross-reference `ASYNC-004/008`, `INFRA-011`.** Brak `RESEND_API_KEY` także w produkcji przełącza `sendEmailDev()`, zapisuje preview do `.next/emails` i wraca bez wysyłki (`src/lib/emails/send.ts:14-27,30-54`). Brak Redis przełącza idempotencję do pamięci. Order-placed bezwarunkowo obiecuje potwierdzenie e-mailem (`order-placed/[id]/page.tsx:107-109`).

**Wpływ:** sklep wygląda na sprawny, choć komunikacja jest wyłączona; sukces UI jest fałszywy.

**Naprawa/test:** capability manifest/readiness; produkcja fail-closed dla wymaganych kanałów, canary i UI zależne od potwierdzonego stanu. Sklep bez Resend/webhook/Redis nie może przejść odpowiedniej checklisty albo nie może obiecywać maila.

## Pokrycie funkcjonalne

| Obszar | Potwierdzone | Luka |
|---|---|---|
| routing/i18n | default locale bez prefiksu, locale messages | `lang`, fallbacki i E2E używają rozbieżnych kontraktów |
| SEO | canonical home/list/PDP/category, OG, JSON-LD, sitemap | hreflang/noindex, `/c`, rozdwojony kanon brandingu |
| performance | Next Image, sizes, Suspense list | brak realnego cache; SEC-002 i zimne warianty |
| katalog | SSR page 1, search, facety, sort, warianty, media | outage=empty/404, pagination bez retry/URL |
| cart/checkout | kupony, adresy, dostawa, Stripe/Adyen/PayPal, express | stary E2E i blokery `MONEY-*` |
| konto/orders | auth/reset/profile/adresy/karty/lista/detal | client guard, brak guest lookup/after-sales |
| renderer | published snapshot, hero/product grid, fallback 404 | ignorowane tło, brak runtime compatibility |
| analytics/legal | pełny GA4 funnel, polityki/checkbox | brak consent i trwałego dowodu |
| errors/offline | skeletony, global error/Sentry | brak boundaries/retry/offline policy; maskowane błędy |
| e-mail | HMAC, 4 typy, templates/idempotency adapter | produkcyjny dev fallback i opcjonalna trwałość |
| trust/conversion | ceny, dostawa checkout, polityki | profil sprzedawcy, kontakt, FAQ, after-sales |

## Testy

| Test | Wynik |
|---|---|
| `npm run lint` | **PASS** — 218 plików |
| `npx tsc --noEmit` | **PASS** |
| `npm test` | **PASS** — 9 plików, 97 testów |
| `npm run check:locales` | **PASS** — `de/es/fr/pl` mają parytet z `en` (po uruchomieniu poza blokadą IPC sandboxa) |
| `npm run build` | **NIEZWERYFIKOWANY** — brak postępu po `Creating an optimized production build`; przerwany po ok. 120 s, exit 130 |
| Playwright | **NIEURUCHOMIONY** — wymaga Docker/Stripe/env, a spec ma stary routing |
| browser smoke | **NIEDOSTĘPNY** — `agent-browser: command not found` |
| Lighthouse/axe/visual | **BRAK W REPO** |

## Mocne strony

- Commerce pozostaje za Store API; brak hardcodowania cen/reguł zamówień.
- Middleware dobrze canonicalizuje default locale; filtry/sort/query są w URL, search chroni przed stale response.
- PDP ma media, warianty, stock, breadcrumbs i podstawowy Product JSON-LD.
- Checkout ma czytelne sekcje, mobile summary, wiele klas płatności i wznowienie offsite payment.
- Auth łączy guest cart, tokeny są server-side cookies; transient customer error nie czyści ich poza 401/403.
- Renderer czyta tylko published snapshot; draft nie wycieka, brak publikacji zachowuje referencyjny fallback.
- Unit tests dobrze pokrywają actions cart/checkout/payment/customer i webhooki; kod ma liczne dobre aria/alt.

## Kolejność domknięcia

1. Najpierw blokery `MONEY-*`, `SEC-*`, `TENANT-*`, `AUTH-*`.
2. Empty vs outage/config oraz tenant storefront doctor (`FRONT-001`).
3. Aktualny checkout gate i canary (`FRONT-005`).
4. Consent i wersjonowane dowody dokumentów (`FRONT-002/003`).
5. Profil sprzedawcy, kontakt, after-sales (`FRONT-004` + `ORDER-*`).
6. Cache i kontrakt renderer↔backend (`FRONT-009/010`).
7. Locale/SEO/sitemap/schema (`FRONT-006..008`, `FRONT-013`).
8. Error states, a11y/cross-browser i auth routing (`FRONT-011/012/014`).
9. Capability/readiness e-maili (`FRONT-015`, `ASYNC-*`, `INFRA-011`).

## Kryterium zamknięcia

Nowy tenant z Store Factory przechodzi automatyczny storefront doctor i aktualny E2E: profil/dokumenty są publiczne, katalog odróżnia empty od outage, published document renderuje wszystkie pola, sitemap/canonical/hreflang/schema są poprawne, consent i wersje polityk są trwałe, checkout kończy testowe zamówienie i komunikację. Flow przechodzi na mobile WebKit oraz Chromium/Firefox, axe nie ma serious/critical, build jest zielony, a fault injection nie daje fałszywego 404/sukcesu/pustki.

## Ograniczenia

- Bez dostępu do Vercel/Oracle/R2/Resend/GTM/providerów; runtime config nieweryfikowany.
- Bez prawdziwego zamówienia, load testu, Lighthouse, DAST, screen reader i urządzeń.
- To nie jest opinia prawna; raport wskazuje brak capability/dowodu do weryfikacji prawnej.
- Bez pomiaru Core Web Vitals i konwersji produkcyjnej.
- Raport niczego nie zmienia w checkoutcie; kanoniczne findings bezpieczeństwa/pieniędzy/tenantów/async/zamówień pozostają w audytach 04–12.
