# Sklepik — kanoniczna macierz funkcji produktu

**Stan audytu:** 2026-07-14  
**Repo backend/admin:** `/home/pawe-perfect/Dokumenty/sklepik`, HEAD `055a1eb5f9`, z lokalnymi zmianami  
**Repo storefront:** `/home/pawe-perfect/Dokumenty/sklepikFront`, HEAD `558ecab`, z lokalnymi zmianami  
**Zasada:** kod jest dowodem istnienia; dokumentacja i pliki planów nie są dowodem. Obecność modelu Spree nie oznacza, że właściciel lub klient może użyć funkcji.

## Executive summary

Sklepik ma już szeroki, dojrzały rdzeń commerce: katalog, warianty, inventory, ceny, promocje, koszyk, zamówienia, podatki, wysyłkę, klientów, rynki, gift cards i refundy. Nowy Store API oraz nowy panel właściciela pokrywają dużą część codziennej sprzedaży. Storefront ma prawdziwy checkout, konta klientów, katalog, filtry, polityki, SEO, Stripe/Adyen/PayPal adapters oraz e-maile przez Resend wyzwalane webhookami.

Najbardziej unikatowa część produktu — **Store Factory** — istnieje w kodzie: publiczny signup tworzy administratora, sklep, prywatne repo z template, projekt Vercel, zmienne środowiskowe i czeka na deploy. To nie jest jednak jeszcze bezpieczna, w pełni zweryfikowana fabryka publiczna. Provisioning nie był w tym audycie wykonany end-to-end przeciw GitHub + Vercel, nie konfiguruje domeny, Resend, webhooka, Redis, Sentry ani GTM, nie ma kompensacji po częściowym błędzie, a publiczny signup nie weryfikuje e-maila i może generować koszt infrastruktury.

Największa pułapka interpretacyjna: backend zawiera więcej możliwości niż aktualny produkt. Zwroty, wymiany, reimbursements, importy, raporty, wishlists, digitale, newsletter, pickup i data feeds mają kod po stronie rdzenia lub legacy admina, ale część nie jest podłączona do nowego panelu/storefrontu. Nie mogą być sprzedawane jako gotowe self-service.

### Ocena gotowości

| Obszar | Ocena | Najważniejszy wniosek |
|---|---|---|
| Rdzeń commerce | mocny | duże pokrycie modeli i API Spree, ale potrzebna kontrola konkretnej konfiguracji PL |
| Panel właściciela | dobry dla katalogu i zamówień | brak pełnej obsługi zwrotów, reklamacji, importu, faktur i supportu |
| Storefront | dobry pilotowo | 97/97 unit/integration tests przeszło; tylko jeden checkout E2E i nie przeciw temu forkowi backendu |
| Store Factory | częściowy | wartościowy wyróżnik, lecz wymaga hardeningu, pełnego E2E i lifecycle/handoff |
| Editor/CMS | MVP lokalne | tylko hero + product grid; kod obecnie niecommitowany, brak uploadu tła i pełnego themingu |
| Produkcja/operacje | częściowe | Sentry/Vercel Analytics istnieją warunkowo; backup/restore, alerty i SLO niezweryfikowane |
| Polski baseline | luka P0/P1 | brak dowodu na BLIK/P24/InPost, faktury/paragony, returns portal i consent management |
| Frontier/AI | prawie całkowity brak | nie jest blockerem pierwszych sprzedaży; wybierać dopiero po danych i przez partnerów/flags |

## Legenda

Statusy w komórkach:

- **PROD** — kompletna ścieżka w kodzie, odpowiednie testy i brak znanej koniecznej konfiguracji; nie oznacza automatycznie live na serwerze.
- **CFG** — działa po prawidłowej konfiguracji zewnętrznej lub danych sklepu.
- **PART** — istotna część działa, ale brakuje elementu ścieżki lub standardu operacyjnego.
- **BE** — tylko core/model lub backend; użytkownik nie ma kompletnego UI.
- **HIDDEN** — kod istnieje, ale jest niepodłączony, legacy, niecommitowany albo nieudostępniony w bieżącym produkcie.
- **MISS** — brak dowodu implementacji w przeszukanym kodzie.
- **UNVER** — ścieżka wygląda na zaimplementowaną, ale nie została uruchomiona end-to-end lub stan produkcyjny jest nieznany.
- **—** — warstwa nie jest właściwa dla danej funkcji.

Priorytet:

- **P0** — blocker bezpiecznej pierwszej realnej sprzedaży lub publicznego onboardingu;
- **P1** — standard dobrego sklepu i powtarzalnej obsługi;
- **P2** — wzrost, automatyzacja i skala;
- **P3** — opcjonalne, frontier albo zależne od verticalu.

Skróty dowodów: `B:` = repo `sklepik`, `F:` = repo `sklepikFront`. „Test” oznacza test istniejący; tylko wynik jawnie opisany jako uruchomiony jest wynikiem tego audytu.

## 1. Signup, onboarding, Store Factory i role

| Funkcja | Priorytet | Core/model | Admin API | Store API | Panel właściciela | Storefront klienta | Konfiguracja prod | Testy | E2E | Dowód w kodzie |
|---|---|---|---|---|---|---|---|---|---|---|
| Signup właściciela: sklep + admin | P0 | PROD | CFG | — | PROD | — | `STORE_SIGNUP_ENABLED` | spec | UNVER | `B:spree/api/app/controllers/spree/api/v3/admin/signups_controller.rb`; `B:packages/dashboard/src/routes/signup.tsx` |
| Walidacja hasła i unikalności e-mail | P0 | PROD | PROD | — | PROD | — | — | spec | PART | `B:spree/api/app/services/spree/api/v3/admin/signup_password_validator.rb`; `B:packages/dashboard/src/schemas/auth.ts` |
| Weryfikacja e-mail signup | P0-public | MISS | MISS | — | MISS | — | MISS | MISS | MISS | komentarz „no email verification yet” w `B:spree/api/config/routes.rb` |
| Ochrona signup przed botami/kosztem | P0-public | PART | PART | — | MISS | — | Rails cache/rate limit | spec częściowy | UNVER | rate limit w `B:spree/api/app/controllers/spree/api/v3/admin/signups_controller.rb`; brak CAPTCHA/approval/billing |
| Utworzenie repo z template | P0-factory | PROD | CFG | — | status/polling | — | GitHub token/owner/template | service spec | UNVER live w tym audycie | `B:spree/core/app/services/spree/provisioning/github_client.rb`; `.../provision_store.rb` |
| Utworzenie projektu Vercel | P0-factory | PROD | CFG | — | status/polling | — | Vercel token/team | service spec | UNVER pełnego linku Git | `B:spree/core/app/services/spree/provisioning/vercel_client.rb` |
| Env nowego storefrontu | P0-factory | PART | CFG | — | status | — | ustawia tylko API URL, key, name | service spec | UNVER | `B:spree/core/app/services/spree/provisioning/provision_store.rb` |
| Domena własna + DNS/SSL | P1 | core custom domain istnieje | MISS w factory | — | MISS | czyta site URL | MISS | MISS | MISS | `B:spree/core/db/migrate/20250119165904_create_spree_custom_domains.rb`; brak w provisioning |
| Retry/resume/rollback provisioningu | P0-public | PART | tworzy nowy run | — | można ponowić nowy run | — | Sidekiq | service spec | MISS | `B:spree/core/app/services/spree/provisioning/provision_store.rb` jawnie bez persisted resume; brak cleanup repo/project |
| Widoczny status etapów | P1 | PROD | PROD | — | PROD | — | worker | spec/model | UNVER | `B:spree/core/app/models/spree/provisioning_run.rb`; `B:packages/dashboard/src/components/store-factory/provisioning-status-card.tsx` |
| Readiness i launch gating | P0 | HIDDEN | HIDDEN | HIDDEN | HIDDEN | HIDDEN | migracja + deploy | specs istnieją | UNVER | lokalne, niecommitowane: `B:spree/core/app/services/spree/stores/readiness_check.rb`; `B:.../requires_live_store.rb`; `B:.../store-readiness-card.tsx` |
| Dodanie kolejnego sklepu przez admina | P1-agency | PROD | PROD | — | PROD | — | provisioning credentials opcjonalne | E2E store settings, bez factory | UNVER factory | `B:packages/dashboard/src/routes/_authenticated/$storeId/new-store.tsx`; admin `stores_controller.rb` |
| Multi-store switcher i store scoping | P0 | PROD | PROD | — | PROD | — | poprawne role per store | liczne specs | PART | `B:packages/dashboard-core/src/components/store-switcher.tsx`; `B:spree/core/app/models/spree/role_user.rb` |
| Zaproszenia pracowników | P1 | PROD | PROD | — | PROD | — | ActionMailer transport | dashboard E2E istnieje | UNVER email prod | `B:spree/api/.../admin/invitations_controller.rb`; `B:packages/dashboard/src/routes/.../settings/staff.tsx` |
| Role i permission sets | P0 | PROD | read roles + enforcement | — | przypisanie roli | — | seeded roles | model/API specs | PART | `B:spree/core/app/models/spree/permission_sets/*`; `B:packages/dashboard-core/src/providers/permission-provider.tsx` |
| Audit log działań właścicieli | P1 | PART: state/log entries domenowe | MISS unified | — | MISS | — | MISS | modele testowane punktowo | MISS | `B:spree/core/app/models/spree/log_entry.rb`; brak centralnego merchant audit trail |
| Billing abonamentu Sklepika | P1-scale | MISS | MISS | — | MISS | — | MISS | MISS | MISS | brak modelu/subskrypcji SaaS dla właściciela |
| Deprovision/delete/transfer ownership | P1 | PART klientów API, nie infrastruktury | MISS lifecycle | — | MISS | — | MISS | MISS | MISS | `VercelClient#delete_project` istnieje, lecz nie jest ścieżką produktu |

## 2. Katalog, warianty, media, kategorie i inventory

| Funkcja | Priorytet | Core/model | Admin API | Store API | Panel właściciela | Storefront klienta | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| CRUD produktu + status draft/active/archived | P0 | PROD | PROD | odczyt aktywnych | PROD | PDP/listing | CFG dane | specs + dashboard E2E | dashboard E2E istnieje | `B:.../admin/products_controller.rb`; `B:packages/dashboard/src/routes/.../products/$productId.tsx`; `F:src/app/.../products/[slug]/page.tsx` |
| Warianty i opcje | P0 | PROD | PROD | PROD | PROD, macierz wariantów | picker PDP | — | unit + E2E istnieją | UNVER razem | `B:.../products/variants_controller.rb`; `B:.../variants-matrix.ts`; `F:src/components/products/VariantPicker.tsx` |
| SKU/barcode/waga/wymiary | P1 | PROD | PROD | serializowane | PROD | częściowo niewidoczne | — | specs | UNVER | `B:spree/core/app/models/spree/variant.rb`; `B:.../variant-edit-sheet.tsx` |
| Media produktu | P0 | PROD | PROD + direct upload | PROD | upload/order/edit | galeria/lightbox | storage/CDN | E2E media istnieją | UNVER storage prod | `B:.../admin/media_controller.rb`; `B:.../product-form-cards.tsx`; `F:src/components/products/MediaGallery.tsx` |
| Media przypisane do wariantu | P1 | PROD | PROD | PROD | PROD | galeria wariantu | storage | E2E istnieje | UNVER | `B:spree/core/app/models/spree/variant_media.rb`; `B:.../variant-media-picker.tsx` |
| Kategorie/drzewo/kolejność | P0 | PROD | PROD | PROD | PROD, drag/drop | nawigacja + category page | — | unit + E2E | UNVER | `B:.../categories_controller.rb`; `B:.../category-tree.tsx`; `F:src/app/.../c/[...permalink]/page.tsx` |
| Automatyczne kategorie/reguły | P2 | PROD | PART | Store odczytuje wynik | PART/niepełne | wynik widoczny | — | model specs | MISS | `B:spree/core/app/models/spree/taxon_rule.rb`; brak pełnego edytora reguł w nowym panelu |
| Tagi i custom fields/metafields | P2 | PROD | PROD | częściowo serializowane | PROD dla produktów/klientów/zamówień | product custom fields | — | specs/E2E custom fields | UNVER | `B:spree/core/app/models/concerns/spree/metafields.rb`; `F:src/components/products/ProductCustomFields.tsx` |
| Inventory per lokalizacja | P0 | PROD | PROD | dostępność/stock | PROD | availability/filter | seed lokalizacji | specs + E2E | UNVER | `B:spree/core/app/models/spree/stock_item.rb`; `B:.../inventory-section.tsx`; `F:.../AvailabilityDropdownContent.tsx` |
| Rezerwacje stanów | P1 | PROD | read admin | egzekwowane w cart | bez pełnego UI lifecycle | pośrednio | job/timeouts config | model specs | UNVER concurrency | `B:spree/core/app/models/spree/stock_reservation.rb`; services `stock_reservations/*` |
| Transfery magazynowe | P2 | PROD | PROD | — | PROD | — | — | dashboard E2E | UNVER | `B:.../admin/stock_transfers_controller.rb`; `B:.../products/transfers.tsx` |
| Preorder | P3-vertical | core pola | PART/serializer zależny | UNVER | brak jawnego pełnego UI | MISS badge/flow | MISS | specs punktowe | MISS | `B:spree/core/db/migrate/20260630000001_add_preorder_fields_to_spree_variants.rb` |
| Import produktów CSV | P1-onboarding | PROD core/legacy | brak v3 route | — | HIDDEN: legacy admin | — | worker/storage | model specs | MISS nowy panel | `B:spree/core/app/models/spree/imports/products.rb`; legacy `spree/admin/.../imports_controller.rb` |
| Export produktów CSV | P1 | PROD | PROD | — | PROD | — | job/storage/email | specs | UNVER | `B:packages/dashboard/src/routes/.../products/index.tsx` `ExportButton`; API exports |
| Bulk status/category/channel/tag/delete | P1 | PROD | PROD | — | PROD | — | — | API/E2E częściowo | UNVER | collection routes w `B:spree/api/config/routes.rb`; products route panelu |

## 3. Ceny, waluty, podatki, faktury i promocje

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Cena bazowa i sale price | P0 | PROD | PROD | PROD | PROD | PROD | waluta sklepu | specs/E2E | UNVER | `B:spree/core/app/models/spree/price.rb`; `B:.../bulk-price-editor`; `F:src/components/products/ProductCard.tsx` |
| Multi-currency/markets | P2 | PROD | PROD | PROD | PROD | selekcja rynku/kraju | kursy/ceny per market | SDK/E2E markets | UNVER PL/EU | `B:spree/core/app/models/spree/market.rb`; `F:src/contexts/StoreContext.tsx` |
| Price lists i reguły segmentowe/volume | P2/B2B | PROD | PROD | ceny rozwiązywane | PROD | cena końcowa | — | model + dashboard E2E | UNVER | `B:spree/core/app/models/spree/price_list.rb`; panel `products/price-lists/*` |
| Historia cen/Omnibus | P1-PL | core model | MISS public/admin UI | MISS prezentacji lowest-30 | MISS | MISS | MISS | model obecność | MISS | `B:spree/core/app/models/spree/price_history.rb`; brak prezentacji wymaganej promocji |
| Tax categories/rates/zones | P0 | PROD | PROD | naliczane | PROD | totals | wymaga poprawnej konfiguracji | specs + E2E config | UNVER jurysdykcji PL | `B:.../tax_rates_controller.rb`; `B:.../settings/tax-rates.tsx`; checkout totals |
| Ceny brutto/netto i VAT UE | P0-PL | PART w Spree | CFG | wynik totals | ustawienia częściowe | display totals | audyt księgowy | specs core | UNVER | `B:spree/core/app/models/spree/tax_rate.rb`; brak dowodu kompletnej polskiej konfiguracji |
| NIP/faktura/paragon/KSeF | P0-PL operacyjny | MISS produktowy | MISS | MISS | MISS | MISS | partner księgowy potrzebny | MISS | MISS | brak sensownych trafień w kodzie; `checkout requirement` tylko abstrakcyjny komentarz |
| Promocje automatyczne i kody | P1 | PROD | PROD | apply/remove | rozbudowany editor | checkout coupon | CFG reguły | specs + E2E | UNVER razem | `B:.../promotion-editors/promotion-form.tsx`; `F:src/components/checkout/CouponCode.tsx` |
| Darmowa wysyłka/warunki produktu/kategorii/rynku | P1 | PROD | PROD | egzekwowane | PROD | wynik ceny | — | core + E2E promotions | UNVER | promotion rules/actions w core i panelu |
| Gift cards | P2 | PROD | PROD | apply + konto | PROD | checkout + konto | mail/delivery config | SDK/dashboard E2E | UNVER | `B:spree/core/app/models/spree/gift_card.rb`; `F:src/components/account/GiftCardList.tsx` |
| Store credit | P2 | PROD | PROD | apply + konto | klient/order UI | checkout/account data | — | core/API | UNVER | `B:.../store_credit.rb`; Store API carts/store_credits |
| Loyalty points/referrals | P2 | MISS | MISS | MISS | MISS | MISS | — | MISS | MISS | brak modeli programu lojalnościowego/referral |

## 4. Wyszukiwanie, filtry, CMS/editor i SEO

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Wyszukiwanie tekstowe produktów | P0 | database + Meilisearch provider | — | PROD | global admin search | search bar/listing | database działa; Meili CFG | provider specs | UNVER Meili | `B:spree/core/app/models/spree/search_provider/*`; `F:src/components/search/SearchBar.tsx` |
| Filtry cena/opcja/dostępność/sort | P0 | PROD | — | PROD `/products/filters` | — | PROD | — | utils/unit | PART E2E | `B:.../products/filters_controller.rb`; `F:src/components/products/filters/*` |
| Semantic/visual search | P3 | MISS | MISS | MISS | MISS | MISS | provider/AI wymagany | MISS | MISS | brak embeddings/image search |
| Homepage editor draft/publish | P1 | HIDDEN lokalnie | HIDDEN | HIDDEN | HIDDEN | HIDDEN renderer | migracja/deploy | specs istnieją, panel nieuruchomiony | UNVER | lokalne: `B:.../storefront_page.rb`; `B:.../editor.tsx`; `F:.../StorefrontPageRenderer.tsx` |
| Sekcja hero | P1 | PART | PART | PART | heading/subheading/button | renderuje | — | model/API specs | UNVER | editor obsługuje tekst i button; background ID bez upload UI |
| Product grid section | P1 | PART | PART | PART | heading + limit; taxon UI brak | render category ID jeśli istnieje | — | specs | UNVER | `B:.../editor.tsx`; `F:.../FeaturedProductsSection.tsx` |
| Pełny theme/design tokens | P1 | MISS w nowym editorze | MISS | store branding częściowy | MISS | CSS stały/template | per-repo ręcznie | MISS | MISS | `F:src/app/globals.css`; brak merchant theme controls |
| Strony treści/blog/landing pages | P2 | tylko homepage model | tylko singleton homepage | tylko homepage | MISS | policies + homepage | — | MISS | MISS | routes ograniczone do `resource :storefront_page` |
| SEO produktu/kategorii | P1 | pola meta/slug | PROD | PROD | PROD | metadata + JSON-LD | site URL/brand env | unit częściowe | UNVER crawl | `B:.../product-form-cards.tsx` SEOCard; `F:src/lib/metadata/*`; `F:src/components/seo/JsonLd.tsx` |
| Sitemap/robots/canonical/hreflang | P1 | — | — | dane katalogu | — | PART/PROD | site URL | build/unit pośrednie | UNVER crawl | `F:src/app/sitemap.ts`; `F:src/app/robots.ts`; metadata files |
| AEO/generatywne SEO | P3 | MISS | MISS | MISS | MISS | MISS | AI/approval potrzebne | MISS | MISS | brak |

## 5. Konta klientów, koszyk i checkout

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Guest cart add/update/remove | P0 | PROD | — | PROD | — | PROD | cookie/security | 97 testów storefront: zielone | checkout E2E istnieje | `B:.../store/carts/*`; `F:src/contexts/CartContext.tsx`; cart tests |
| Cart persistence/associate po login | P1 | PROD | — | PROD | — | PART | cookie | SDK tests | UNVER | `B:spree/api/config/routes.rb` `carts#associate`; auth/cart helpers frontu |
| Rejestracja klienta | P1 | PROD | — | PROD | — | PROD | mail nie jest wymagany | unit/API | PART | `F:src/app/.../account/register/page.tsx`; Store customers controller |
| Login/logout/refresh | P1 | PROD | — | PROD | — | PROD | JWT/cookies | SDK/unit | PART | `B:.../store/auth_controller.rb`; `F:src/contexts/AuthContext.tsx` |
| Reset hasła | P1 | PROD | — | PROD | — | PROD | webhook + Resend | handler tests | UNVER email prod | `B:.../password_resets_controller.rb`; `F:.../forgot-password`; webhook handler |
| Profil/adresy/historia zamówień | P1 | PROD | admin customers | PROD | zarządzanie klientem | PROD | — | SDK/unit | UNVER | `F:src/app/.../account/*`; `B:.../customer/addresses_controller.rb` |
| Zapisane karty | P2 | PROD | admin read/delete | Store read/delete/setup | panel klienta admin | PROD | gateway vault config | payment tests | UNVER gateway | `F:src/app/.../account/credit-cards/page.tsx`; payment setup sessions |
| Wishlist | P2 | PROD | MISS new admin | PROD | MISS | MISS | — | SDK tests | MISS | Store API routes + `B:spree/core/app/models/spree/wishlist.rb`; brak front UI |
| One-page checkout adres/dostawa/płatność | P0 | PROD | — | PROD | — | PROD | konkretne metody | unit + checkout data tests zielone | jeden Stripe E2E istnieje, nieuruchomiony | `F:src/app/.../checkout/[id]/CheckoutPageContent.tsx`; components checkout |
| Akceptacja polityk | P0 | order consent fields/policies | policies admin | policies + cart params | lokalny legal UI HIDDEN | checkbox checkout | polityki muszą być uzupełnione | unit | checkout E2E zaznacza | `F:src/components/policy/PolicyConsent.tsx`; `B:spree/core/app/models/spree/policy.rb` |
| Express checkout | P2 | sessions | — | sessions | — | przycisk/utility | gateway config | tests utils | UNVER | `F:src/components/checkout/ExpressCheckoutButton.tsx` |
| Abandoned cart recovery | P2 | MISS workflow | MISS | MISS | MISS | MISS | email/consent | MISS | MISS | brak cron/event campaign |

## 6. Płatności

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Manual/COD/bank transfer | P0 fallback | PROD | payment method CRUD | direct payment | konfiguracja | generic direct | CFG | API/unit | UNVER | `B:spree/core/app/models/spree/payment_method/check.rb`; `F:src/lib/data/payment.ts` |
| Stripe card/3DS | P0 | gateway przez gem/config | payment method CRUD | payment sessions/webhooks | preferences | Payment Element | keys + webhook | payment tests | E2E plik używa real test Stripe, nieuruchomiony | `F:src/components/checkout/StripePaymentForm.tsx`; `F:e2e/checkout.spec.ts` |
| Adyen | P2 | gateway zewnętrzny | config | sessions | preferences | adapter | keys/webhook | unit częściowe | UNVER | `F:src/components/checkout/AdyenPaymentForm.tsx` |
| PayPal | P2 | gateway zewnętrzny | config | sessions | preferences | adapter | client ID/webhook | unit częściowe | UNVER | `F:src/components/checkout/PayPalPaymentForm.tsx` |
| Razorpay | P3 | typ rozpoznany | config potencjalna | sessions potencjalne | — | MISS form | keys | MISS | MISS | mapowanie w `F:src/lib/utils/payment-gateway.ts`, brak komponentu checkout |
| BLIK/Przelewy24/PayU/Apple Pay PL | P0-PL | brak dowodu konkretnej integracji | MISS | MISS/pośrednio przez gateway nieudowodnione | MISS | MISS | operator potrzebny | MISS | MISS | brak nazw/adapterów w istotnym kodzie |
| Saved card checkout | P2 | PROD | — | PROD | — | PROD Stripe/gateway | vault/customer config | unit | UNVER | `F:src/components/checkout/PaymentSection.tsx` |
| Capture/void płatności | P1 | PROD | PROD | webhook | PROD | status | gateway | core/API | UNVER live | `B:packages/dashboard/src/routes/.../orders/$orderId.tsx` PaymentsCard |
| Refund płatności | P0 obsługa | PROD | endpoint create | — | MISS w nowym order UI | MISS self-service | gateway | core/API specs | MISS | `B:spree/api/.../admin/orders/refunds_controller.rb`; brak wywołania w panelu |
| Fraud/risk/chargebacks | P1 | PART `considered_risky/approve` | approve order | MISS | approve flag | MISS | provider fraud portal | specs częściowe | MISS | risk UI w order header; brak scoring/chargeback case management |
| Idempotency płatności/order complete | P0 | PART/PROD locks | PART | PART | — | obsługa 403/422 | Redis/gateway | controller/unit | UNVER concurrency | `B:.../order_lock.rb`; `F:src/lib/data/payment.ts` |

## 7. Shipping, orders i post-purchase

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Shipping methods/zones/rates | P0 | PROD | PROD | rates w fulfillment | PROD | wybór rate | wymaga konfiguracji | core + dashboard E2E | checkout E2E sample | `B:.../shipping_methods_controller.rb`; `F:.../DeliveryMethodSection.tsx` |
| Integracje kurierów/InPost labels | P0-PL/P1 | tracking generic | MISS carrier API | MISS | MISS labels | MISS parcel locker | partner required | MISS | MISS | brak adapterów InPost/DPD/DHL w przeszukanym kodzie |
| Pickup/click&collect | P2 | pola lokalizacji + routing | admin stock location fields | PART rate potencjalny | konfiguracja lokalizacji | MISS locator/UX | — | schema/E2E stock location | MISS | `B:packages/dashboard/src/schemas/stock-location.ts`; brak front pickup UI |
| Draft/manual orders | P1 | PROD | PROD | — | PROD | payment link potencjalny | mail transport | dashboard E2E | UNVER | `B:packages/dashboard/src/routes/.../orders/new.tsx`; API orders |
| Lista/detail/status order | P0 | PROD | PROD | customer/guest show | PROD | konto + thank-you | — | liczne | PART | panel order route; `F:src/components/account/OrderDetail.tsx` |
| Fulfillment/split/cancel/resume/tracking | P0/P1 | PROD | PROD | status w order | PROD częściowo bez split UI | status/tracking display | carrier URL config | core/API | UNVER | admin fulfillments routes; panel ShipmentsCard |
| Cancel order przez właściciela | P0 | PROD | PROD | — | PROD | e-mail/status | email CFG | specs | UNVER | order header cancel + admin controller |
| Cancel przez klienta | P1 | core możliwe | — | MISS | — | MISS | — | MISS | MISS | Store customer orders są read-only |
| Post-purchase tracking page | P1 | tracking fields | — | order show | panel tracking edit | account/order detail | tracking URL | unit | UNVER | `F:src/components/order/FulfillmentBlock.tsx` |
| Powiadomienie shipment shipped | P1 | event/subscriber | — | webhook event | action fulfill | Resend template | webhook + Resend | handler tests zielone | UNVER prod | `B:spree/emails/.../shipment_mailer.rb`; `F:src/lib/emails/shipment-shipped.tsx` |

## 8. Zwroty, reklamacje, e-maile i support

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Return authorization/RMA | P1 | PROD | legacy admin, brak v3 | MISS | HIDDEN legacy | MISS | — | core/legacy specs | MISS | `B:spree/core/app/models/spree/return_authorization.rb`; legacy controllers |
| Customer return/received items | P1 | PROD | legacy admin | MISS | HIDDEN legacy | MISS | — | core specs | MISS | `B:spree/core/app/models/spree/customer_return.rb`; legacy admin |
| Exchange | P1-vertical | PROD | legacy/reimbursement | MISS | HIDDEN | MISS | — | model specs | MISS | `B:spree/core/app/models/spree/exchange.rb` |
| Reimbursement/refund orchestration | P1 | PROD | refund endpoint tylko część | — | HIDDEN legacy | MISS | gateway/mail | core specs | MISS | `B:spree/core/app/models/spree/reimbursement.rb`; legacy reimbursements controller |
| Self-service returns portal | P1 | core częściowy | MISS | MISS | MISS | MISS | — | MISS | MISS | brak Store API/UI |
| Reklamacje i rękojmia workflow | P0-PL operacyjny/P1 produkt | MISS | MISS | MISS | MISS | MISS | proces poza systemem wymagany | MISS | MISS | brak complaint/case model |
| Order confirmation email | P0 | Spree mailer + event | resend endpoint | webhook | owner resend | Resend React template | `RESEND_API_KEY`, `EMAIL_FROM`, webhook | handler tests zielone | UNVER prod | `F:src/lib/emails/send.ts`; `F:src/lib/webhooks/handlers.ts` |
| Cancel/shipped/password reset emails | P0/P1 | events | — | webhook | działania wyzwalają | templates | Resend + secret | handler tests zielone | UNVER prod | `F:src/lib/emails/*`; webhook route |
| Resend konfiguracja automatyczna per factory | P0-factory | — | — | — | MISS | code fallback nie wysyła bez key | MISS w provisioning | unit fallback | MISS | provisioning ustawia tylko 3 env; `F:send.ts` zapisuje plik zamiast wysyłki bez key |
| Merchant new-order notification | P1 | Spree mailer istnieje | email settings | event | settings UI | — | Rails ActionMailer transport | mailer specs | UNVER | `B:spree/emails/app/mailers/spree/order_mailer.rb`; `B:.../settings/emails.tsx` |
| Newsletter double opt-in | P2 | PROD | legacy admin | create/verify | HIDDEN | MISS form | mail transport | SDK/core | MISS | `B:.../newsletter_subscribers_controller.rb`; brak front form |
| Helpdesk/tickets/SLA | P1-scale | MISS | MISS | MISS | MISS | MISS | partner | MISS | MISS | brak |
| Chatbot/conversational support | P2 | MISS | MISS | MISS | MISS | MISS | AI/KB/handoff | MISS | MISS | brak |

## 9. Analytics, marketing, feeds, integrations i dane

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Dashboard sales/orders/AOV/top products | P1 | reports queries | analytics endpoint | — | PROD | — | poprawne event/order dane | controller/route | UNVER | `B:packages/dashboard/src/routes/_authenticated/$storeId/index.tsx`; dashboard controller |
| Zaawansowane raporty | P2 | sales/products reports | brak nowej route | — | HIDDEN: nav `/reports` bez route | — | jobs | core specs | MISS | `B:spree/core/app/models/spree/reports/*`; `B:packages/dashboard/src/nav/default.ts` |
| Vercel Analytics/Speed Insights | P1 | — | — | — | — | CFG | automatycznie components | build | UNVER prod project | `F:src/app/layout.tsx` |
| Sentry error/performance | P0 ops | — | — | — | — | CFG | DSN/token | build | UNVER alerting | `F:src/instrumentation.ts`; `F:src/instrumentation-client.ts`; `F:next.config.ts` |
| GTM | P1 growth | — | — | — | — | CFG | `GTM_ID`; brak consent gate | build | UNVER | `F:src/app/layout.tsx` |
| Cookie/consent management + Consent Mode | P0 jeśli tracking | MISS | MISS | MISS | MISS | MISS | nie włączać GTM bez rozwiązania | MISS | MISS | brak banner/CMP; GTM wstrzykiwany bez warstwy zgody |
| Product listing analytics events | P2 | base handler core | — | — | — | PART component | GTM/dataLayer | unit brak | MISS | `F:src/components/products/ListingAnalytics.tsx`; `B:.../base_analytics_event_handler.rb` |
| Google product feed | P1 growth | core `DataFeed::Google` | legacy settings | public feed show | HIDDEN | endpoint możliwy | konfiguracja/feed mapping | model specs | MISS | `B:spree/core/app/models/spree/data_feed/google.rb`; Store API `data_feeds_controller.rb` |
| Meta/marketplace feeds Allegro/Amazon | P1/P2 | MISS concrete | MISS | MISS | MISS | MISS | partner | MISS | MISS | brak |
| Webhook management/delivery/retry | P1 | PROD | PROD | receiver events | PROD | secure receiver | secret/endpoint/Redis | dashboard E2E + front tests | UNVER cross-repo | `B:.../webhook_endpoints_controller.rb`; `F:src/app/api/webhooks/spree/route.ts` |
| Webhook idempotency | P0 | delivery model | delivery/retry | signed webhook | — | receiver guard | Upstash required dla durable | tests zielone | UNVER prod | `F:src/lib/webhooks/idempotency.ts` |
| API keys/scopes/allowed origins | P0 security | PROD | PROD | auth enforcement | PROD | uses publishable key | origins/key rotation | E2E/API specs | UNVER prod config | API keys/allowed origins routes + panel settings |
| Import customers/translations | P2 | PROD core | legacy | — | HIDDEN | — | jobs | specs | MISS | `B:spree/core/app/models/spree/imports/*` |
| Export customers/orders/coupons/newsletter | P2 | PROD | generic exports | — | PART tylko wybrane UI | — | job/storage/mail | specs | UNVER | `B:spree/core/app/models/spree/exports/*`; `ExportButton` usage |
| Public/open integration marketplace | P3 | integration model legacy | MISS new API/catalog | — | HIDDEN | — | governance | MISS | MISS | `B:spree/core/app/models/spree/integration.rb`; legacy integrations controller |

## 10. I18n, legal, security i operacje

| Funkcja | Priorytet | Core | Admin API | Store API | Panel | Storefront | Prod | Testy | E2E | Dowód |
|---|---|---|---|---|---|---|---|---|---|---|
| Języki storefront PL/EN/DE/FR/ES | P1 | translations/markets | translations batch | locale-aware | panel ma kilka locale | next-intl messages | locale env/market | parity script + tests | UNVER pełna treść | `F:messages/*`; `F:scripts/check-locale-parity.ts`; translation models/API |
| Języki panelu | P2 | user selected locale | me/locales | — | EN/PL/DE/FR/AR/ZH | — | — | locale files | UNVER parity | `B:packages/dashboard/src/locales/*` |
| Rynki, domeny, waluty, locale | P2 international | PROD | PROD | PROD | PROD | PART | DNS/prices/tax | E2E markets | UNVER international checkout | market model/routes/context |
| Polityki: privacy/terms/returns/shipping | P0 | PROD | HIDDEN lokalnie admin update | read | HIDDEN local legal UI | policy pages + checkout | treść prawnika | specs istnieją | UNVER | `B:.../policy.rb`; `F:src/app/.../policies/[slug]/page.tsx` |
| GDPR: access/export/delete customer | P1 | PART delete/anonymize możliwości core | admin customer CRUD/export | profile update | PART | MISS self-service delete/export | procedura operatora | specs częściowe | MISS | brak kompletnego DSAR workflow |
| Cookie consent | P0 przy analytics | MISS | MISS | MISS | MISS | MISS | CMP | MISS | MISS | brak |
| EAA/accessibility | P0 quality | semantyka częściowa | — | — | shadcn częściowo | komponenty semantyczne | audyt WCAG wymagany | brak axe suite | MISS | dostępne aria w wielu komponentach, brak systemowego audytu |
| GPSR dane produktu/producent/ostrzeżenia | P1-vertical | custom fields mogą przechować | custom fields | product fields | konfigurowalne | generic custom fields | schema per vertical | custom-field tests | MISS compliance | brak dedykowanego modelu/checklisty GPSR |
| Security headers | P0 | concern API | stosowane | stosowane | — | Next headers niezweryfikowane | proxy/nginx/Vercel | controller specs częściowe | UNVER scan | `B:spree/api/app/controllers/concerns/.../security_headers.rb`; `B:nginx.conf` |
| Auth JWT/refresh/revocation | P0 | PROD | PROD | PROD | PROD | PROD | secret/cookie HTTPS | API/SDK/unit | PART | auth controllers + `refresh_token.rb` |
| Rate limiting | P0 | Rails rate limit | login/signup | login etc. | — | — | shared Rails cache | specs częściowe | UNVER distributed | signup/auth controllers |
| CSRF/CORS/allowed origins | P0 | PART | config | enforcement | settings | publisher key | poprawna lista origins | E2E allowed origins | UNVER | allowed origin model/API/panel |
| Backups i restore drill | P0 ops | Postgres/Redis volumes | — | — | MISS | — | wolumen to nie backup | MISS | MISS | `B:docker-compose.yml` ma volumes, brak polityki/restore job w kodzie |
| Job durability/queues | P0 factory/email | ActiveJob/Sidekiq | — | — | status częściowy | — | Redis + Sidekiq | job specs | UNVER restart | `B:docker-compose.yml`; provisioning job |
| Health checks/readiness infrastruktury | P0 ops | PART container DB/Redis | MISS app health | — | — | Vercel health implicit | monitoring | MISS | UNVER | compose healthchecks tylko DB/Redis |
| Structured logs/metrics/alerts/SLO | P1 ops | Rails.error + Sentry front | — | — | — | Sentry CFG | alert rules MISS | unit brak | MISS | punktowy `Rails.error.report`; Sentry config front |
| Disaster recovery per store repo | P1 | GitHub repo kopia kodu | — | — | MISS | Vercel | Git/Vercel | MISS | MISS | repo per store pomaga kodowi, nie chroni DB/commerce danych |

## 11. Agency, white-label, handoff i AI

| Funkcja | Priorytet | Core | API | Panel | Storefront | Prod | Testy/E2E | Dowód/wniosek |
|---|---|---|---|---|---|---|---|---|
| Operator tworzy wiele sklepów | P1 | PROD | store create + provisioning | PROD | oddzielny deploy | CFG | UNVER | new-store route + factory services |
| White-label panel/domena/e-mail | P2 | PART store branding | PART | logo/store settings, panel nadal Spree | env branding | custom domain/email CFG | MISS | brak kompletnego agency branding |
| Przekazanie sklepu klientowi | P1 | role/invitations | PROD | zaproszenie działa | — | mail CFG | E2E invite istnieje | brak formalnego transfer ownership/billing/credential rotation |
| Odłączenie agency/support access | P1 | role user delete | admin user delete | staff UI | — | — | PART | wymaga runbooka i audytu |
| Centralne aktualizacje wszystkich forków | P1-scale | MISS | MISS | MISS | każdy repo jest kopią | MISS | MISS | repo-per-store tworzy koszt driftu; brak upstream sync/rollout |
| Feature flags per sklep | P1-scale | MISS platformowe | MISS | MISS | env ręczne | MISS | MISS | część env działa jak flagi, brak rejestru/rollout/audytu |
| AI do generowania sklepu/treści | P3 | MISS | MISS | MISS | MISS | — | MISS | brak SDK/model calls |
| AI merchandising/rekomendacje | P3 | MISS | MISS | MISS | MISS | — | MISS | brak |
| AI support/chatbot | P2 | MISS | MISS | MISS | MISS | — | MISS | brak |

## Funkcje ukryte lub niepodłączone, których nie wolno sprzedawać jako gotowe

1. **Zwroty, exchanges i reimbursements:** dojrzały core i legacy Rails Admin, lecz brak nowego panelu i Store API portalu.
2. **Wishlist:** Store API i model istnieją, storefront nie ma UI.
3. **Digital downloads:** route tokenowa i modele istnieją, brak doświadczenia zakupowego/owner UI w nowym panelu.
4. **Newsletter:** model, verify API i mailer istnieją, brak formularza storefront i bieżącego panelu kampanii.
5. **Google data feed:** backend istnieje, brak bieżącej konfiguracji właściciela i zweryfikowanego feedu produktu.
6. **Importy:** core/legacy admin istnieją, nowy panel nie ma routingu.
7. **Zaawansowane raporty:** modele istnieją, nawigacja nowego panelu prowadzi do `/reports`, ale nie ma odpowiadającej route.
8. **Pickup/click&collect:** pola lokalizacji istnieją, brak storefront locator i pełnej ścieżki odbioru.
9. **Preorder:** pola wariantu istnieją, brak kompletnego owner/storefront lifecycle.
10. **Storefront editor i launch gating:** sensowny MVP jest w lokalnym working tree, ale w chwili audytu nie jest commitowany ani udowodniony jako wdrożony.
11. **Razorpay:** typ gatewaya jest rozpoznawany, lecz brak komponentu formularza.
12. **Custom domains:** model istnieje, ale Store Factory nie podpina domeny do Vercel/DNS.

## P0 przed pierwszą realną sprzedażą

Poniższe nie wymaga zbudowania „Shopify od zera”. Wymaga zamknięcia ryzyka albo jawnego procesu ręcznego.

| Kolejność | P0 | Dlaczego | Kryterium ukończenia |
|---:|---|---|---|
| 1 | Zamrozić i wdrożyć aktualne zmiany launch/policies/editor | lokalny kod nie jest produktem | commit, migracje, deploy; smoke test właściciel → publish → storefront; rollback opisany |
| 2 | Golden path PL: produkt → koszyk → płatność → zamówienie → fulfillment | bez tego nie ma sprzedaży | realna transakcja testowa na produkcyjnej konfiguracji, poprawny VAT/kwoty, webhook, e-mail, status i refund testowy |
| 3 | Wybrać jedną płatność produkcyjną | Stripe card może wystarczyć pilotowi; BLIK/P24 są oczekiwaniem PL | podpisany operator, 3DS, webhook replay, błędna/porzucona płatność, idempotency i refund przetestowane |
| 4 | Wybrać jedną dostawę produkcyjną | generic rate działa, lecz nie ma InPost/labels | flat/manual jako jawny pilot albo integracja; poprawny koszt/strefa, tracking i procedura etykiety |
| 5 | E-maile Resend i webhook cross-repo | bez env produkcja nie wysyła; factory ich nie ustawia | verified domain/from, Resend key, webhook secret/endpoint, Redis idempotency, test duplicate/retry i 4 szablony dostarczone |
| 6 | Legal/consent/EAA | polityki i dostępność są częścią checkoutu | treści klienta zaakceptowane; checkbox wersjonowany; GTM wyłączony albo CMP; ręczny WCAG smoke; dane GPSR dla verticalu |
| 7 | Faktura/paragon i reklamacje jako proces | funkcji nie ma w produkcie, a obowiązek biznesowy istnieje | wybrany partner/proces księgowy; NIP/faktura w checkout albo jasny follow-up; adres i SLA reklamacji; test jednej korekty/refundu |
| 8 | Hardening public signup | otwarty signup tworzy płatne zasoby bez verify | domyślnie flag off; invite/approval dla pilotów; przed publicznym on: verify email, quota, CAPTCHA/risk, cleanup i alert kosztu |
| 9 | Provisioning factory E2E | unit spec nie dowodzi GitHub App/Vercel/env/deploy | 3 kolejne sklepy od formularza do READY; błąd na każdym etapie; retry bez sierot; wszystkie konieczne env; czas i alert |
| 10 | Backup/restore i monitoring | volume nie jest backupem | automatyczny backup DB+storage, restore do izolowanego środowiska, alert web/worker/queue/webhook, właściciel incydentu |
| 11 | Refund owner flow | endpoint istnieje, nowy panel go nie daje | przycisk refund z kwotą/powodem, gateway response, e-mail, order totals, test partial/full; do czasu wdrożenia runbook API/legacy |
| 12 | Handoff i odpowiedzialność | sklep klienta potrzebuje właściciela, dostępu i supportu | klient zaproszony, role least-privilege, domena/rachunki/sekrety opisane, support channel i exit checklist |

## Rekomendowana sekwencja wdrażania

### Faza A — 0–14 dni: bezpieczny pilot

1. Domknąć P0 1–7 dla jednej konfiguracji PL i jednego verticalu.
2. Publiczny signup pozostawić za flagą; sklepy zakładać assisted.
3. Używać jednej bramki płatniczej i jednej metody dostawy.
4. Zrobić test pełnego refundu i awarii webhooka.
5. Nie budować frontier features.

### Faza B — 15–45 dni: powtarzalna fabryka

1. Provisioning E2E, retry/cleanup, domena, pełny zestaw env i observability.
2. Import katalogu w nowym panelu albo kontrolowany importer onboardingowy.
3. Refund w nowym panelu, runbook reklamacji, Resend per store.
4. Theme tokens i 3–5 stabilnych sekcji editora, nie dowolny page builder.
5. Feature flags i release channel dla storefrontów, aby ograniczyć drift repo-per-store.

### Faza C — 46–90 dni: standard dobrego sklepu

1. Polski operator płatności/BLIK i InPost, jeśli dane pilotów potwierdzają blokadę.
2. Self-service returns portal, reviews/UGC i lepsze analityki dopiero według verticalu.
3. Feed Google/Meta, consent mode i podstawowe automations lifecycle.
4. Handoff/white-label/billing Sklepika.
5. Dopiero potem pierwszy eksperyment AI/konwersacyjny z feature flag.

## Baseline profesjonalnej platformy w 2025–2026

Baseline nie oznacza, że każda funkcja musi być natywna. Shopify, Shoper i WooCommerce wygrywają często ekosystemem partnerów/aplikacji; Sklepik może świadomie **partner/buy** zamiast budować.

| Obszar baseline | Shopify/Shoper/Woo | Stan Sklepika | Decyzja |
|---|---|---|---|
| Katalog, warianty, inventory, zamówienia, kupony | standard core; [Woo docs](https://woocommerce.com/documentation/woocommerce/) grupują products, taxes, shipping, payments, orders, reports i customers | mocny core + dobre API/panel | utrzymać, nie przepisywać |
| Płatności lokalne | Shoper komunikuje BLIK, P24/Autopay, karty, Apple/Google Pay i metody odroczone w [cenniku](https://www.shoper.pl/cennik-sklepu-shoper) i [płatnościach](https://www.shoper.pl/systemy-platnosci) | adaptery globalne, brak dowodu PL | partner/integracja P0/P1 według pilotów |
| Kurierzy/marketplaces/ERP | Shoper oferuje gotowe integracje m.in. InPost, DPD, DHL, Allegro, Amazon i ERP przez ekosystem | generic shipping/webhooks, brak gotowych adapterów | buy/partner, nie budować wszystkich |
| Analytics/reporting | Shopify Analytics dostępne na planach; [Woo Analytics](https://woocommerce.com/document/woocommerce-analytics/) ma 9 raportów, filtry, CSV i dashboard | podstawowy dashboard, ukryte raporty core | P1 podstawy, P2 raporty według decyzji |
| Returns/self-service | Shopify ma self-serve returns, także w [B2B feature set](https://help.shopify.com/en/manual/b2b/getting-started/features) | core zwrotów bez nowego UI | P1 vertical-dependent |
| International/markets | [Shopify Markets](https://help.shopify.com/en/manual/markets) personalizuje currency, language, pricing, product availability, domains, taxes i content | markets/prices/translations mocne, domeny/content niepełne | P2 po PL |
| B2B | Shopify baseline obejmuje companies, catalogs, volume pricing, payment terms, drafts i reorder | price lists/groups/drafts częściowe, brak company/terms/quotes | P3 chyba że ICP wymusi |
| Extensibility | Woo ma Marketplace z bundles, subscriptions, memberships, tracking i POS partnerem; [Woo Marketplace](https://woocommerce.com/products/) | API/webhooks mocne, brak marketplace partnerów | zaprojektować partner contracts zamiast clone |
| PWA/mobile/multichannel | Shoper podaje PWA, Allegro i marketplace integrations w cenniku | responsive web, brak manifest/service worker/push | P2/P3, nie P0 |
| Store creation/deployment isolation | platformy SaaS tworzą tenant; agency tools zapewniają handoff | repo + Vercel per sklep jest wyróżnikiem | inwestować, ale kontrolować drift i koszt |

**Wniosek baseline:** Sklepik nie powinien gonić liczby checkboxów. Powinien dowieźć lepszy onboarding, odpowiedzialność za start, lokalny golden path i edycję marki, a długi ogon funkcji kupować/integrować. Brak BLIK/InPost/faktur/refund UI jest dziś ważniejszy niż brak AR, live shopping czy voice commerce.

## Frontier capabilities — opportunity matrix

Wszystkie poniższe statusy odnoszą się do kodu, nie do potencjału Spree lub Vercel. **MISS** nie oznacza „budować teraz”.

| Capability | Stan dziś | Wartość | Zależności | Ryzyko/koszt | Build / partner / buy | Priorytet i flag |
|---|---|---|---|---|---|---|
| Voice commerce w przeglądarce | MISS | dostępność, szybsze discovery | search API, intent, cart tools, consent | błędne zamówienie, prywatność, niska adopcja | partner prototype | P3, flag per store |
| Telefoniczny agent AI inbound | MISS | odbiera pytania i statusy 24/7 | telephony, KB, order auth, human handoff | wyciek PII, halucynacje, koszt minuty | buy/partner | P3 po helpdesk |
| Telefoniczny agent outbound | MISS | odzysk leadów/abandoned carts | lawful basis, consent, CRM, suppression list | wysokie ryzyko prawne i reputacyjne | partner, domyślnie off | P3 experimental |
| Nagrywanie rozmów/zgody | MISS | QA i dowód | region policy, announcement, retention, DSAR | dane szczególne, obowiązki informacyjne | buy | P3, osobna zgoda/flag |
| Human handoff z voice/chat | MISS | redukuje ryzyko AI | helpdesk, transcript, routing, SLA | staffing | buy | P2 przed agentem autonomicznym |
| Chatbot support | MISS | deflection FAQ/order status | KB, Store API scoped tools, auth | halucynacje/PII | buy first | P2 flag |
| Conversational shopping | MISS | discovery i conversion | structured catalog, filters, recs, analytics | niepoprawne claimy/price | hybrid build on Store API | P2/P3 A/B flag |
| Semantic search | MISS | lepsze long-tail queries | clean catalog, embeddings, search provider | koszt/index freshness | buy/Meili extension | P2 po search telemetry |
| Visual search | MISS | wartość w fashion/decor | image embeddings, CDN, moderation | koszt i false matches | partner | P3 vertical flag |
| Rekomendacje | MISS | AOV/conversion | events, identity/consent, inventory | cold start/filter bubble | buy first | P2 flag + holdout |
| Personalizacja storefrontu | MISS | relevance | CDP/segments, experiment system, cache strategy | privacy i cache explosion | build minimal rules | P2 po consent |
| Generatywne landing pages | MISS | szybsze kampanie | editor schema, approval, assets, analytics | spam/brand drift | build assistant, human publish | P2/P3 flag |
| Generatywne SEO/AEO | MISS | skala treści | factual product data, review, sitemap | duplicate/thin content, hallucination | buy/build assistant | P3, no auto-publish |
| Shoppable video | MISS | discovery w visual verticals | video hosting, product hotspots, analytics | performance/CDN | buy embed | P3 vertical |
| Live shopping | MISS | event conversion/community | streaming, moderation, inventory latency | operacyjnie ciężkie | partner | P3 only validated seller |
| Social commerce | MISS konkretne | dystrybucja Meta/TikTok | catalog feed, pixels/consent, order sync | platform dependency | partner | P2 after feeds |
| Marketplace feeds/order sync | MISS konkretne | nowe kanały | SKU identity, inventory reservations, conflict policy | overselling/support | buy (Apilo/BaseLinker class) | P1/P2 dla ICP marketplace |
| AR/3D viewer | MISS | redukcja niepewności decor | 3D assets, WebXR/vendor | asset cost/performance | buy | P3 vertical |
| Virtual try-on | MISS | fashion/beauty conversion | camera consent, ML/vendor, product assets | biometric/privacy, accuracy | partner | P3 gated |
| Subscriptions | MISS | repeat/MRR merchant | recurring gateway, dunning, customer portal, tax | charge failures/cancellations | buy/partner | P2 candles/food only after demand |
| Memberships | MISS | retention/access | entitlements, recurring billing, content | support/tax | partner | P3 |
| Loyalty | MISS | repeat | ledger, identity, expiry/legal, analytics | liability/fraud | buy | P2 when repeat data exists |
| Referrals | MISS | lower CAC | attribution, rewards, anti-fraud | abuse/self-referral | buy | P2 experiment |
| Bundles/kits | MISS product model | AOV/gifting | bundle inventory allocation, pricing, returns | stock/refund complexity | build minimal fixed bundle or buy | P1/P2 vertical flag |
| Upsell/cross-sell | MISS | AOV | product relations, placement, experiment | dark patterns | build simple manual links | P2 |
| Omnichannel inventory | PART core channels/locations | spójny stock | connectors, reservations, source of truth | overselling | partner | P2 |
| POS | MISS | targi/offline ICP | payment terminal, offline sync, receipts | hardware/fiscal | partner | P2/P3 vertical |
| Click&collect | PART backend | local conversion | pickup rates/locator/notifications | stock promise | build UI on core | P2 |
| B2B/wholesale | PART groups/price lists/drafts | wyższy GMV | companies, terms, tax IDs, approvals, reorder | scope explosion | build only with ICP | P3 today |
| Quotes/RFQ | MISS | high-AOV B2B | draft orders, negotiation, expiration | custom workflow | build small if sold | P3 |
| Multi-vendor marketplace | MISS | platform GMV | seller onboarding/KYC, split payments, commissions, disputes | bardzo wysoka regulacja/ops | do not build now | P3 separate product |
| Returns portal/exchanges | MISS UI, core strong | trust i niższy support | RMA Store API, policy, labels, refund/exchange | fraud/logistics | build on core + carrier partner | P1 |
| Fraud/risk/chargebacks | PART | chroni marżę | gateway signals, case workflow, evidence | false positives | buy provider | P1 for scale |
| Helpdesk/customer service | MISS | operacyjna jakość | inbox, order context, SLA, identity | staffing/data retention | buy | P1-scale |
| Reviews/UGC | MISS | trust/SEO | verified purchase, moderation, consent, schema.org | spam/legal claims | buy | P1/P2 |
| Consent/CDP/segmentation | PART customer groups, brak consent layer | lawful personalization | CMP, event taxonomy, identity | GDPR complexity | buy CMP; build minimal segments | P0 consent/P2 CDP |
| Experimentation/A-B | MISS | learning velocity | flags, assignment, metrics, sample size | false conclusions | buy lightweight | P2 |
| Mobile/PWA | MISS manifest/SW | repeat/mobile UX | installability, offline/update strategy | maintenance, limited iOS behaviors | build later | P2/P3 |
| Push notifications | MISS | retention/status | PWA/native token, consent, provider | spam/permission fatigue | buy | P3 |
| Post-purchase tracking hub | PART account tracking | mniej „gdzie paczka” | carrier events, ETA, notifications | stale data | partner | P1 |
| Sustainability data | MISS | trust/regulatory readiness | product fields, evidence, shipping data | greenwashing | build verified fields only | P3 vertical/EU |
| International expansion automation | PART markets/i18n | nowy TAM | tax/duties, payments, carriers, returns, legal | duży ops scope | partner stack | P2 after PL fit |

### Zasada dla frontier

Każda funkcja frontier musi przejść cztery bramki: (1) co najmniej pięć kwalifikowanych próśb lub zmierzony problem, (2) właściciel metryki i kosztu, (3) human override/rollback, (4) feature flag z holdoutem. Wyjątkiem są fundamenty bezpieczeństwa, consent i handoff — je trzeba zbudować **przed** autonomicznym AI, nie po nim.

## 12. Paid AI services / entitlements

### Decyzja produktowa

Płatna usługa AI nie jest checkboxem „włącz AI”. Jest zamówieniem zdefiniowanego rezultatu, budżetu, zakresu odpowiedzialności i kryterium akceptacji. Przykład `SEO za około 200 zł` powinien znaczyć np. „audyt 20 produktów, propozycja tytułów/meta/opisów, raport błędów i jedna zatwierdzona publikacja”, a nie nieograniczone obietnice pozycjonowania.

Billing tych usług musi być całkowicie odseparowany od Store API checkoutu konsumenta. Zamówienie klienta sklepu nie może nadawać entitlementu właścicielowi, a błąd/chargeback usługi AI nie może zmieniać zamówień konsumenckich. Docelowo potrzebne są osobne bounded contexts: `merchant billing`, `service catalog`, `entitlements`, `agent runs`, `approvals` i `usage ledger`.

### Stan warstwy entitlementów

| Element | Stan dziś | Priorytet | Kryterium ukończenia | Dowód/uwaga |
|---|---|---|---|---|
| Katalog płatnych usług dla właściciela | MISS | P2 | wersjonowana definicja usługi: rezultat, wejścia, limit, cena, SLA, refund policy | brak modeli merchant service |
| Aktywacja/zakup w panelu | MISS | P2 | checkout merchant-facing, faktura, status payment, bez użycia cartu konsumenta | brak route/panelu |
| Zakup jednorazowy | MISS | P2 | jedno entitlement z okresem realizacji i limitem runów/artefaktów | brak |
| Abonament AI add-on | MISS | P2 | recurring billing, renewal, dunning, proration i cancellation | brak merchant billing |
| Plan/entitlement per store | MISS | P1-scale | store-scoped grant z capability, limitami, datami i źródłem płatności | roles nie są entitlementami komercyjnymi |
| Limity użycia i budżetu | MISS | P1-scale | atomowy usage ledger, hard/soft limit, alert 80/100%, koszt model/provider | brak token/cost ledger |
| Approval queue | MISS | P1 przed write AI | preview/diff, approve/reject/edit, role i deadline | brak |
| Audit log agent run | MISS | P1 | prompt/intencja, typed plan, narzędzia, actor, wersja modelu, input/output hash, koszt, rezultat | brak unified audit |
| Metryki rezultatu usługi | MISS | P2 | baseline, target, measurement window i disclaimer attribution | analytics podstawowe nie wystarczają |
| Pause/resume/cancel | MISS | P2 | zatrzymuje nowe runy, nie gubi in-flight state; refund/credit policy | brak workflow |
| Billing webhooks/idempotency | MISS | P1-scale | signed events, dedupe, replay, entitlement reconciliation i dead-letter | obecne payment webhooks dotyczą commerce |
| Izolacja store/tenant | core scoping PART, AI MISS | P0 dla AI | każdy run i artefakt ma store_id; negative cross-tenant tests | istniejący store scoping jest bazą, nie dowodem AI |
| Izolacja od core checkoutu | architektonicznie możliwa, brak modułu | P0 | oddzielne modele/routes/events/keys i brak współdzielonego Order/Payment | nie implementować usług jako produktów w sklepie klienta |

### Kandydaci na płatne add-ons

| Add-on | Przykładowy sprzedawalny rezultat | Model zakupu | Limity startowe | Approval | Metryka rezultatu | Ryzyko | Build/partner/buy |
|---|---|---|---|---|---|---|---|
| SEO ~200 zł | audyt do 20 produktów + propozycje meta/title + lista błędów + publikacja zatwierdzonych zmian | jednorazowy | 20 produktów, 1 iteracja | każda zmiana przed publish | pokrycie metadata, błędy crawl; ruch jako obserwacja, nie gwarancja | średnie: brand/claims | build agent + deterministic SEO validator |
| Treści produktowe | opisy dla ustalonej liczby SKU z danymi źródłowymi | pakiet jednorazowy/miesięczny | SKU, słowa, iteracje | obowiązkowo dla claimów | czas do publikacji, acceptance rate | wysokie w food/cosmetics | build assistant, human approval |
| Landing/kampania | jedna strona w istniejącym schema + wariant copy | jednorazowy | sekcje/assets/okres | preview strony | publish, conversion holdout | średnie | build po rozwoju editora |
| E-mail lifecycle | 3 szablony i deterministyczne triggery | setup + abonament | sends/miesiąc, segmenty | treść + trigger | delivery, unsubscribe, attributed conversion | consent/reputacja domeny | partner ESP + build orchestration |
| AI support | odpowiedzi draftowane dla X ticketów, agent przekazuje człowiekowi | abonament usage | tickets/tokens/SLA | auto tylko niskie ryzyko | resolution, handoff, CSAT | PII/halucynacje | buy helpdesk + constrained agent |
| Zdjęcia/obrazy | warianty tła/crop/alt dla N zdjęć | credits | obrazy/rozdzielczość | preview asset | acceptance/use rate | IP/realism/claims | buy image provider + asset pipeline |
| Import concierge | normalizacja arkusza i import do N SKU | jednorazowy | rows/variants/errors | dry-run + diff | accepted rows, corrections, time saved | stan/cena krytyczne | build deterministic importer; AI tylko mapping |
| Analityka insight | miesięczny raport z anomaliami i listą działań | abonament | źródła/raporty | rekomendacje bez auto-write | action acceptance, detected issue | błędna atrybucja | build on metric layer |
| Voice agent | X minut inbound, FAQ/status, handoff | abonament + usage | minuty, calls, intents | refund/sale zawsze gated | containment, handoff, CSAT | najwyższe PII/consent | buy telephony + constrained tools |

### Minimalny model domenowy

Docelowy kontrakt powinien rozdzielać:

- `ServiceDefinition`: wersja, cena/model billing, wymagane wejścia, deliverables, SLA, refund policy;
- `MerchantSubscription` lub `ServiceOrder`: płatność właściciela, nie `Spree::Order` konsumenta;
- `Entitlement`: `store_id`, capability, scope, hard limits, valid_from/to, state;
- `UsageLedgerEntry`: atomowa jednostka, provider cost, idempotency key, run ID;
- `AgentRun`: intencja, typed plan, status, artefakty, koszt, błędy;
- `Approval`: diff, actor, decyzja, reason, expiry;
- `OutcomeMeasurement`: baseline, window, metric, observed result i attribution caveat.

Pierwsza wersja może być sprzedawana assisted i fakturowana ręcznie, ale entitlement oraz usage muszą nadal istnieć w systemie; arkusz bez egzekwowania limitów nie jest bezpiecznym fundamentem automatyzacji.

## 13. Natural-language control plane i dwa tryby agentów

### Zasada: AI everywhere, not LLM everywhere

LLM ma rozumieć intencję właściciela i przygotowywać **typed plan**. Operacje wykonują deterministyczne serwisy domenowe przez Admin API: aktualizacja produktu, ceny, dokumentu strony, promocji, fulfillmentu czy refundu. Model nie powinien generować dowolnego kodu ani bezpośrednio pisać do bazy.

Przykładowy kontrakt planu:

```json
{
  "storeId": "store_...",
  "intent": "change_homepage_theme",
  "actions": [
    {
      "type": "storefront_page.patch",
      "resourceId": "sfpage_...",
      "expectedVersion": 7,
      "patch": [{ "op": "replace", "path": "/theme/primaryColor", "value": "#7A4B2A" }],
      "riskClass": "R1",
      "idempotencyKey": "..."
    }
  ]
}
```

Schema jest walidowane, permissions liczone dla człowieka/automatyzacji, zasoby są store-scoped, a wykonawca rejestruje before/after. Narzędzie odmawia działania, jeśli wersja zasobu się zmieniła, brakuje entitlementu albo limit został przekroczony.

### Dwa tryby

| Tryb | Opis | Stan dziś | Minimalne zabezpieczenia | Priorytet |
|---|---|---|---|---|
| Jednorazowe polecenie czatowe | właściciel prosi „zmień kolor”, „dodaj promocję”, „popraw 10 opisów”; agent przygotowuje plan i diff | MISS | authenticated actor, typed plan, dry-run, preview, approval zależne od ryzyka, audit, undo | P2 |
| Trwała automatyzacja `event → condition → action` | reguła działa po webhooku/czasie, np. niski stock → draft e-mail, shipment late → ticket | MISS | wersjonowana reguła, deterministic condition, rate/budget limits, idempotency, pause/kill switch, replay test | P2/P3 |

Automatyzacja nie jest „promptem uruchamianym zawsze”. Musi być zasobem z właścicielem, stanem `draft/active/paused/error`, wejściowym event schema, deterministycznymi warunkami, listą dozwolonych akcji, limitami i historią wykonań.

### Klasy ryzyka akcji

| Klasa | Przykłady | Preview/diff | Approval | Limity | Idempotency | Undo/compensation | Dry-run |
|---|---|---|---|---|---|---|---|
| **R0 read-only** | analiza sprzedaży, wyszukanie produktu, draft raportu | źródła i zakres danych | nie, chyba że eksport PII | query/cost/time | cache/run key | nie dotyczy | zawsze dostępny |
| **R1 reversible content** | kolor, layout, draft opisu, alt text | obowiązkowy before/after | auto możliwe po jawnej regule | liczba zasobów/run | obowiązkowa | snapshot/version rollback | obowiązkowy |
| **R2 operational** | publikacja strony, aktywacja produktu, wysłanie kampanii, zmiana stocku | pełny diff + odbiorcy | człowiek domyślnie; auto tylko allowlist | SKU/recipients/frequency | obowiązkowa | unpublish/revert/cancel job | obowiązkowy |
| **R3 money/customer-critical** | cena, promocja, capture/void, cancel, refund, credit | kwoty, zamówienia, wpływ i policy trace | obowiązkowa powyżej bardzo niskiego progu; refund policy deterministic | kwota/dzień/order, częstotliwość, actor | ledger-grade | compensating transaction, nigdy „delete history” | symulacja wymagana |
| **R4 irreversible/regulatory** | masowe usunięcie, wypłata, zmiana tax rules, publikacja health claims, outbound voice bez zgody | impact report | two-person approval | bardzo niskie/disabled | obowiązkowa | formalny recovery/runbook | obowiązkowy; często akcja zakazana |

### Macierz przykładowych akcji control plane

| Akcja | Ryzyko | Typed executor | Preview | Approval | Limit | Idempotency | Undo/compensation | Stan |
|---|---|---|---|---|---|---|---|---|
| Zmień kolor/layout homepage | R1 | `StorefrontPage` update z optimistic lock | visual + JSON patch | opcjonalne po approve-once | 1 page/run | key + lock_version | poprzedni document snapshot | executor API istnieje częściowo; AI MISS |
| Wygeneruj draft 10 opisów | R1/R2 vertical | product draft updater | diff per field + sources | przed publish | SKU/tokens | run+product+version | restore fields | API produktu istnieje; AI MISS |
| Opublikuj landing | R2 | storefront publish service | preview URL/document | obowiązkowe | pages/day | publish run key | republish previous version | publish istnieje lokalnie; history rollback MISS |
| Zmień ceny o 5% | R3 | bulk price service | lista kwot, currency, rounding, Omnibus impact | obowiązkowe | max SKU i delta | bulk operation key | compensating prices, zachować historię | bulk upsert istnieje; agent MISS |
| Utwórz promocję | R2/R3 | promotion service | eligibility + sample carts | obowiązkowe | max discount/dates | promotion key | deactivate | API/editor istnieje; simulation MISS |
| Wyślij kampanię e-mail | R2 | ESP campaign executor | recipients, content, consent counts | obowiązkowe | sends/day, suppression | campaign send key | cancel unsent; sent nieodwracalne | MISS |
| Import katalogu | R2/R3 | deterministic CSV importer | dry-run rows/errors/diff | obowiązkowe | rows/price delta | file hash+mapping version | compensation batch | core importer istnieje, new UI/AI MISS |
| Odpowiedz na ticket | R1/R2 | helpdesk draft/send | cytowane źródła i PII | auto tylko FAQ allowlist | tickets/day | ticket+message key | follow-up/correction | MISS |
| Automatyczny refund po sentymencie | R3/R4 | **nie LLM decision**; policy engine + refund service | order, reason, fraud signals, amount | człowiek; ewentualnie auto ≤ jawny niski próg | amount/order/day/customer | ledger-grade | compensating credit/recharge tylko zgodnie z prawem | refund API częściowy; policy/AI MISS |
| Voice agent zmienia zamówienie | R3 | authenticated order service | agent czyta podsumowanie klientowi | verbal confirmation + próg human | call/order/amount | call intent key | compensating change | MISS |

### Refund: twarda granica autonomii

Sentyment może otworzyć eskalację, ale nie jest wystarczającą przesłanką finansową. Bezpieczny flow:

1. LLM klasyfikuje intencję i ekstrahuje fakty, nie zatwierdza pieniędzy.
2. Deterministyczny policy engine sprawdza status zamówienia, okno zwrotu, powód, historię klienta, wcześniejsze refundy, ryzyko fraud i limit sklepu.
3. System wylicza maksymalną dozwoloną kwotę oraz wymagany poziom approval.
4. Człowiek akceptuje powyżej progu; bardzo małe goodwill credits mogą działać automatycznie tylko po jawnej polityce.
5. Refund service używa idempotency key, zapisuje ledger i wynik gatewaya.
6. Niepowodzenie prowadzi do kolejki ręcznej, nie do ponawiania przez LLM.

### Wymagane fundamenty control plane

1. centralny action registry z JSON Schema, risk class i required permission;
2. store-scoped tool credentials, nigdy globalny admin token w model context;
3. immutable agent/audit log oraz redakcja sekretów i PII;
4. versioned preview/diff i optimistic locking;
5. approval inbox z rolami i two-person rule dla R4;
6. usage/budget/rate limits per store, entitlement i automation;
7. idempotency keys, outbox/event IDs i replay-safe executors;
8. snapshots lub compensating actions oraz jawne operacje nieodwracalne;
9. dry-run/sandbox z realistycznym price/tax/inventory calculation;
10. kill switch globalny i per store, pause automations, dead-letter queue;
11. evaluation dataset dla intent→typed plan oraz adversarial prompt/tool tests;
12. feature flags i canary rollout na sklepach wewnętrznych przed klientami.

Natural-language control plane ma sens jako wspólna warstwa nad już istniejącym Admin API. Nie należy budować osobnych agentów, z których każdy omija permissions i logikę domenową. Najpierw registry i bezpieczne executors dla R0/R1; dopiero później R2. R3/R4 pozostają deterministyczne i approval-heavy nawet po osiągnięciu wysokiej jakości modeli.

## Kandydaci do feature flags

1. publiczny signup i automatyczny provisioning;
2. launch gating i nowy editor;
3. każdy gateway poza zatwierdzonym golden path;
4. gift cards/store credit/wishlist/digital products;
5. markets i nowe locale;
6. GTM, personalizacja i wszystkie marketing pixels zależne od consent;
7. nowe sekcje CMS i generatywne treści;
8. subscriptions, bundles, pickup i B2B;
9. chatbot, voice, semantic/visual search, rekomendacje i eksperymenty;
10. rollout aktualizacji template do istniejących storefront repos.

Flag musi mieć: właściciela, zakres sklepów, domyślną wartość, datę wygaśnięcia/oceny, metrykę i kill switch. Env per repo nie wystarczy przy dziesiątkach sklepów — potrzebny będzie centralny rejestr lub Edge Config/DB z audytem.

## Kryterium „gotowe produkcyjnie” dla przyszłych aktualizacji macierzy

Funkcję można awansować do **PROD** tylko wtedy, gdy:

1. istnieje kompletna ścieżka odpowiednich warstw, a brak UI jest świadomie zadeklarowany jako API-only;
2. multi-store isolation i permissions są przetestowane;
3. są testy happy path oraz najważniejszej porażki/idempotency;
4. wymagane env i zewnętrzne konta znajdują się w automatyzowanym checku readiness;
5. przeprowadzono E2E na tej wersji backendu i storefrontu;
6. jest obserwowalność, procedura rollbacku i właściciel operacyjny;
7. dokumentowane są limity, koszty, dane osobowe i odpowiedzialność klienta;
8. jeśli funkcja dotyka pieniędzy, stanów, podatków lub prawa — test obejmuje korektę/awarię, nie tylko happy path.

## Wyniki weryfikacji wykonanej podczas audytu

- Storefront `npm test -- --run`: **9 plików, 97 testów, wszystkie przeszły** 2026-07-14.
- Dashboard: znaleziono 33 pliki Playwright E2E i testy jednostkowe, ale nie uruchomiono — `pnpm` nie jest dostępny w środowisku audytu.
- Backend: znaleziono ponad 1100 plików spec, w tym signup, policies, storefront page i provisioning service; nie uruchomiono pełnego RSpec w tym środowisku.
- Storefront checkout E2E istnieje, lecz używa backendu Spree `5.4.3.1` z sample data i realnego Stripe test mode; nie jest dowodem zgodności z bieżącym forkiem `sklepik` ani produkcyjną konfiguracją.
- Nie wykonywano mutujących testów live GitHub/Vercel, płatności, Resend, domen, backup restore ani produkcyjnego refundu.

## Jak utrzymywać ten dokument

Po zmianie funkcji aktualizować jej **każdą warstwę osobno**, ścieżkę dowodu, status testu i E2E. Nie awansować statusu na podstawie planu, README, migracji bez UI albo faktu, że upstream Spree „powinien to mieć”. Przy każdym release publicznym przejrzeć najpierw P0, następnie listę ukrytych funkcji, a dopiero później frontier.
