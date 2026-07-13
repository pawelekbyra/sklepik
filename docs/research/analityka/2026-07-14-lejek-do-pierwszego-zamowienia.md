# Analityka lejka do pierwszego zamówienia

**Data:** 2026-07-14  
**Zakres:** rejestracja właściciela → pierwszy produkt → layout → gotowość → publikacja → test → pierwsze prawdziwe i zrealizowane zamówienie  
**Poziom pewności:** wysoki dla kontraktu zdarzeń i prywatności; średni dla dashboardu; niski dla progów przed danymi bazowymi

## Werdykt

Sklepik potrzebuje jednego kanonicznego lejka opartego na zdarzeniach domenowych generowanych przede wszystkim przez backend. Kliknięcia w UI są pomocnicze; nie mogą być dowodem, że płatności działają, sklep został opublikowany ani zamówienie opłacone.

Najważniejsza metryka onboardingu:

> **odsetek kwalifikowanych nowych sklepów, które osiągnęły pierwsze zrealizowane prawdziwe zamówienie w 30 dni.**

Nie wolno optymalizować samej rejestracji lub generowania layoutu, jeśli sklepy nie dochodzą do sprzedaży. Instrumentację należy wdrożyć przed dużą przebudową onboardingu, z wersjonowaniem eventów, deduplikacją, testami jakości i minimalizacją danych.

## Metoda i fakty

- Google rekomenduje standardowy lejek e-commerce obejmujący m.in. `view_item`, `add_to_cart`, `begin_checkout`, `add_shipping_info`, `add_payment_info` i `purchase`. Sklepik powinien zachować te znaczenia dla zachowania kupującego, a osobno utrzymywać domenowe eventy właściciela sklepu. [Google Analytics — Ecommerce setup Q&A](https://support.google.com/analytics/answer/14143583?hl=en)
- Aktualna dokumentacja Google definiuje `begin_checkout` jako rozpoczęcie checkoutu, a `purchase` jako zakup jednego lub większej liczby produktów; wartość i waluta muszą mieć spójne znaczenie. [Google Data Manager API — recommended events](https://developers.google.com/data-manager/api/reference/analytics/recommended-events)
- RODO wymaga celowości, minimalizacji, retencji, prawidłowości i rozliczalności. Pseudonimizacja zmniejsza ryzyko, ale dane pseudonimowe pozostają danymi osobowymi, jeśli możliwe jest ponowne przypisanie. [RODO, art. 5–6](https://eur-lex.europa.eu/legal-content/PL/TXT/?uri=CELEX%3A32016R0679) i [EDPB Guidelines 01/2025 on Pseudonymisation](https://www.edpb.europa.eu/public-consultations/guidelines-012025-on-pseudonymisation_en)
- Nie każdy system analityczny automatycznie kwalifikuje się do zwolnienia z consentu. CNIL wskazuje jako warunki m.in. wyłączne mierzenie własnego serwisu, anonimowe statystyki, brak cross-site tracking i brak łączenia z innymi zbiorami; to francuska interpretacja, więc wdrożenie PL wymaga lokalnej oceny. [CNIL, 04.07.2025](https://www.cnil.fr/fr/cookies-et-autres-traceurs/regles/cookies-solutions-pour-les-outils-de-mesure-daudience)

### Wnioski i jawne założenia

- `first_fulfilled_sale_30d` jest rekomendowaną metryką północnej gwiazdy, a nie standardem narzuconym przez źródła.
- Zakładamy, że fizyczny produkt powinien zostać zrealizowany w 7 dni; inne branże wymagają wersjonowanej definicji fulfillmentu.
- Progi konwersji w raporcie są celami pilotażowymi. Nie są benchmarkiem rynku i nie powinny służyć do oceny małej próby bez kontekstu jakościowego.
- Zakładamy architekturę eventową z backendem jako źródłem prawdy. Można użyć innego transportu, o ile zachowa semantykę, idempotencję i audytowalność.

## Zasady kontraktu

1. **Past tense:** event oznacza fakt, który już zaszedł: `payment_account_enabled`, nie `enable_payment_clicked` jako sukces.
2. **Jedno znaczenie:** nazwa i wymagane pola nie zmieniają sensu bez nowej wersji.
3. **Backend jako źródło prawdy:** provisioning, publikacja, readiness, płatność i zamówienie emitowane po commit/webhooku.
4. **Idempotencja:** każde zdarzenie ma stabilny `event_id`; ponowiony webhook nie zwiększa licznika.
5. **Czas zdarzenia i ingestu:** osobno `occurred_at`, `received_at` i opcjonalnie `provider_occurred_at`.
6. **Bez PII w payloadzie analitycznym:** identyfikatory pseudonimowe zamiast e-maila, nazwiska, adresu, treści polityki lub dokumentu KYC.
7. **Provenance:** `source=backend|dashboard|storefront|payment_provider|worker`.
8. **Środowisko:** `environment=production|staging|test`; tylko produkcja trafia do głównego KPI.
9. **Wersja:** `schema_version` i `flow_version` umożliwiają porównanie eksperymentów.
10. **Waluta i pieniądze:** wartości w minor units plus kod ISO 4217, bez floatów.

## Wspólna koperta eventu

```json
{
  "event_id": "evt_...",
  "event_name": "product_first_publish_completed",
  "schema_version": 1,
  "occurred_at": "2026-07-14T10:15:00Z",
  "received_at": "2026-07-14T10:15:01Z",
  "source": "backend",
  "environment": "production",
  "store_id": "pseudonymous_stable_id",
  "owner_id": "pseudonymous_stable_id",
  "anonymous_session_id": null,
  "flow_version": "onboarding_v1",
  "acquisition_channel": "partner",
  "segment": "handmade_cosmetics",
  "plan": "assisted",
  "properties": {}
}
```

`acquisition_channel`, `segment` i `plan` powinny być snapshotem na moment zdarzenia albo pochodzić z wersjonowanej tabeli wymiarów. Nie nadpisywać historii po zmianie planu.

## Taksonomia lejka właściciela

### Rejestracja i powrót

| Event | Źródło | Warunek |
|---|---|---|
| `owner_signup_started` | dashboard | formularz pokazany po świadomej akcji |
| `owner_signup_submitted` | dashboard | poprawny formularz wysłany |
| `owner_account_created` | backend | konto zapisane |
| `store_provisioning_started` | backend/worker | utworzenie sklepu zlecone |
| `store_provisioning_completed` | backend/worker | sklep, owner role i identyfikator istnieją |
| `owner_first_dashboard_viewed` | dashboard | pierwszy poprawny widok sklepu |
| `owner_return_login_completed` | backend | właściciel loguje się w innej sesji po ≥24 h |

`owner_return_login_completed` weryfikuje, czy sklep jest realnie odzyskiwalny, a nie tylko dostępny po signupie.

### Pierwszy produkt

| Event | Warunek |
|---|---|
| `product_creation_started` | wybrano ręczny/import/AI/CSV |
| `product_import_completed` | parser stworzył draft, nie oznacza poprawności |
| `product_draft_saved` | trwały draft istnieje |
| `product_readiness_passed` | wymagane pola i wariant spełniają reguły |
| `product_first_publish_completed` | pierwszy aktywny produkt dostępny dla Store API |

Properties: `entry_method`, `missing_fields_count`, `variant_count_bucket`, `has_image`, `product_category_code`; bez tytułu/opisu/URL źródłowego w analityce.

### Layout i publikacja dokumentu

| Event | Warunek |
|---|---|
| `storefront_draft_generated` | pierwszy dokument strony zapisany |
| `storefront_editor_opened` | właściciel otworzył edytor |
| `storefront_draft_changed` | zapisana istotna zmiana; debounce/batch, nie każde naciśnięcie |
| `storefront_preview_viewed` | wyrenderowany preview zwrócił sukces |
| `storefront_first_publish_completed` | snapshot published powstał po stronie backendu |

Properties: `generation_method`, `section_count`, `template_family`, `ai_assisted`; bez pełnego JSON layoutu.

### Płatności

| Event | Warunek |
|---|---|
| `payment_onboarding_started` | utworzono hosted/embedded session |
| `payment_onboarding_submitted` | dostawca potwierdził submission |
| `payment_account_restricted` | wymaganie/ograniczenie od dostawcy |
| `payment_account_enabled` | real charges enabled i wymagany status payout zgodny z regułą |
| `payment_account_disabled` | po wcześniejszym enabled utracono możliwość |

Properties tylko kody statusu/powodu, provider, country i elapsed bucket; nigdy dokumenty, rachunek ani dane beneficjenta.

### Dostawa

| Event | Warunek |
|---|---|
| `shipping_setup_started` | pierwszy widok/akcja konfiguracji |
| `shipping_method_saved` | metoda zapisana |
| `shipping_coverage_passed` | co najmniej jeden publikowany produkt ma stawkę dla rynku domyślnego |
| `shipping_coverage_failed` | test wykrył brak, z kodem powodu |

Properties: `product_type=physical|digital|service`, `country_count_bucket`, `method_type`; bez adresu klienta.

### Informacje prawne

| Event | Warunek |
|---|---|
| `business_details_saved` | wymagane dane przedsiębiorcy zapisane |
| `legal_policy_draft_saved` | draft konkretnego typu istnieje |
| `legal_policy_owner_approved` | właściciel jawnie zatwierdził wersję |
| `legal_readiness_passed` | zestaw wymagany dla konfiguracji spełniony |

Properties: `policy_type`, `template_source`, `version`, `legal_review_claimed`; bez treści i danych firmy.

### Readiness, preview i sprzedaż live

| Event | Warunek |
|---|---|
| `store_readiness_evaluated` | backend obliczył wszystkie checks |
| `store_launch_ready_reached` | pierwszy raz wszystkie twarde checks przeszły |
| `store_public_preview_enabled` | preview dostępny według jawnej reguły |
| `store_sales_enable_requested` | owner zatwierdził uruchomienie |
| `store_sales_enabled` | status live po ponownym backendowym readiness |
| `store_sales_suspended` | checkout zablokowany z kodem kategorii |

Properties: lista kodów brakujących checks, ich liczba i `readiness_version`; bez szczegółów prawnych/KYC.

### Próba generalna

| Event | Warunek |
|---|---|
| `test_checkout_started` | sesja jawnie oznaczona test |
| `test_shipping_selected` | stawka działa w teście |
| `test_payment_completed` | provider potwierdził test success |
| `test_order_created` | zamówienie testowe zapisane |
| `test_order_refund_completed` | jeśli wymagane w flow |
| `rehearsal_passed` | cały kanoniczny test zakończony |
| `rehearsal_failed` | kod etapu/przyczyny |

Testowe rekordy nigdy nie wchodzą do GMV, real conversion ani first order.

### Prawdziwy lejek kupującego

Zachować znaczenia kompatybilne z GA4:

```text
storefront_session_started
view_item
add_to_cart
begin_checkout
add_shipping_info
add_payment_info
purchase
order_paid
order_fulfilled
refund
```

`purchase` jest frontendowo-analitycznym zdarzeniem potwierdzenia, natomiast KPI finansowy wykorzystuje backendowe/providerowe `order_paid`. Pierwszy sukces operacyjny to `order_fulfilled` dla pierwszego realnego zamówienia. Jeśli biznes sprzedaje treść cyfrową, definicja fulfillmentu musi być jawnie inna.

## Milestones wyliczane, nie emitowane ręcznie

```text
activation_at = first(product_first_publish_completed, storefront_preview_viewed)
launch_ready_at = first(store_launch_ready_reached)
live_at = first(store_sales_enabled)
first_paid_order_at = first(order_paid where is_test=false and owner_order=false)
first_fulfilled_order_at = first(order_fulfilled for first qualifying paid order)
```

Nie ufać eventowi klienta dla wyliczenia milestone. Widoki/materialized tables powinny być odbudowywalne z surowych zdarzeń.

## Definicje kohort

### Kohorta podstawowa

`store_provisioning_completed` w danym tygodniu, produkcja, unikalny owner, nie pracownik/test/bot, z wybranym zamiarem sprzedaży w ≤30 dni.

### Obowiązkowe rozcięcia

- `acquisition_channel`: partner, referral, paid, organic, founder, other;
- `seller_stage`: already_selling, products_ready, idea_only;
- `onboarding_mode`: self_service, assisted, done_for_you;
- `segment` i `country`;
- `flow_version` i wariant eksperymentu;
- `storefront_source`: generated, template, imported;
- `plan_at_signup` i `plan_at_live`.

### Wykluczenia jawne

- sklepy demo/QA/staging;
- wielokrotne próby tego samego właściciela — osobno `attempt_no`;
- fraud/abuse przed aktywacją;
- sklepy utworzone przez migrację administracyjną bez onboardingu;
- zamówienia właściciela, pracownika, zero-value oraz wszystkie test mode.

Raport powinien pokazywać wyniki także z wykluczeniami i bez nich, by reguły nie służyły poprawianiu KPI.

## Dashboard

### 1. Executive funnel

Tygodniowe kohorty i konwersja:

```text
store provisioned
→ first product ready
→ storefront published
→ payment enabled
→ shipping passed
→ legal passed
→ launch ready
→ rehearsal passed
→ sales enabled
→ first paid order
→ first fulfilled order
```

Dla każdego etapu: liczba, %, mediana czasu od poprzedniego i od provisioning, P75/P90.

### 2. Readiness matrix

Ile sklepów blokuje: produkt, płatność, dostawa, prawo, storefront, dane firmy. Pokazać najstarszy stan i możliwość interwencji.

### 3. First-sale health

- live bez sesji;
- sesje bez view_item;
- view_item bez cart;
- cart bez checkout;
- checkout bez paid;
- paid bez fulfillment;
- refund/fraud po pierwszej sprzedaży.

### 4. Jakość danych

- event lag i ingestion failures;
- duplikaty event_id;
- brak wymaganych properties;
- niespójne sekwencje, np. `store_sales_enabled` bez readiness;
- provider/backend reconciliation dla płatności i zamówień;
- udział `unknown` w wymiarach.

### 5. Eksperymenty

Wariant, liczebność, guardrails, primary metric, wynik i przedział niepewności. Nie ogłaszać zwycięzcy wyłącznie na podstawie nominalnej różnicy małej próby.

## Prywatność i retencja

### Rozdzielić trzy warstwy

1. **Analityka operacyjna właściciela/admina** — bezpieczeństwo, provisioning i gotowość; może być konieczna do świadczenia usługi, ale wymaga podstawy i informacji.
2. **Analityka produktu** — usprawnienie onboardingu; minimalizować, pseudonimizować i ocenić podstawę prawną.
3. **Analityka kupujących/marketingowa** — storefront, atrybucja, cross-site; osobny consent/konfiguracja i odpowiedzialność sklepu/platformy.

### Zakazy payloadu

Nie wysyłać do narzędzia analitycznego:

- e-maila, telefonu, imienia/nazwiska i pełnego IP;
- adresów dostawy/faktur;
- zawartości koszyka przypisanej do osoby, jeśli nie jest konieczna;
- dokumentów i statusów KYC o dużej szczegółowości;
- treści polityk, promptów, ticketów i rozmów;
- danych karty/rachunku;
- nazw produktów mogących ujawniać zdrowie lub inne dane szczególne.

Utrzymywać mapowanie ID w oddzielnym systemie z kontrolą dostępu. Role analityczne widzą agregaty, nie panel pojedynczego klienta bez potrzeby.

### Startowa retencja do oceny z DPO/prawnikiem

- raw product analytics: 13 miesięcy;
- szczegółowe session/anonymous IDs: 90 dni;
- agregaty kohort bez możliwości identyfikacji: dłużej według celu;
- log finansowy/audytowy: według odrębnych obowiązków, nie tej polityki analitycznej;
- delete/anonymize pipeline po zamknięciu konta zgodnie z obowiązkiem i wyjątkami.

To propozycja, nie gotowa podstawa prawna. Dla narzędzi klienckich sprawdzić cookies/storage, transfery, DPA, subprocesorów, tryb consent i konfigurację każdego sklepu/kraju.

## Progi zarządcze na start

To hipotezy do kalibracji po 30–50 kwalifikowanych sklepach:

| Metryka | Cel | Alarm |
|---|---:|---:|
| provisioning success | ≥99% | <97% dziennie |
| signup → preview | ≥70% | <50% |
| preview median time | <20 min | >60 min |
| activated → rehearsal passed | ≥70% | <50% |
| qualified store → sales enabled 14d | ≥50% | <30% |
| sales enabled → first paid order 30d | ≥40% | <20% |
| paid → fulfilled 7d | ≥90% | <80% |
| event completeness | ≥99% required fields | <97% |
| duplicate semantic events after dedupe | <0.5% | >2% |

Nie stosować progów do próby <20 bez pokazania liczebności. Przy małych wolumenach każdy porzucony sklep wymaga jakościowej analizy.

## Implementacja

```text
backend transaction / provider webhook
→ outbox/domain event
→ durable queue
→ schema validation + PII guard
→ append-only raw events
→ dedupe by event_id/provider_id
→ modeled milestones and cohorts
→ BI dashboard / alerts
```

Client events przechodzą osobnym endpointem, rate limit, consent state i bot filteringiem. Kluczowe eventy server-side są reconciled codziennie z tabelami stores/products/orders/payments.

W repo utrzymywać:

- event dictionary i ownera każdego eventu;
- JSON Schema/typy;
- testy kontraktowe producentów;
- changelog semantyki;
- katalog wykluczeń;
- definicję dashboardu/KPI.

## Eksperymenty 14/30/90 dni

### 14 dni

- zatwierdzić słownik i definicje milestone;
- wdrożyć backendowe eventy provisioning, produkt, storefront, readiness, live, test i order;
- dodać `is_test`, `owner_order`, `environment`, `flow_version`;
- zbudować data-quality dashboard i reconciliation;
- ręcznie przejść 10 pełnych scenariuszy, w tym duplicate webhook i błąd płatności.

**Kryterium:** 100% krytycznych milestone odbudowuje się z eventów; zero PII w próbce payloadów; ≥99% required-field completeness.

### 30 dni

- zebrać pierwsze kwalifikowane kohorty;
- uruchomić dashboard executive/readiness/first-sale;
- przeprowadzić jeden test wejścia produktu i jeden test kolejności readiness;
- po każdym porzuceniu zebrać jawny powód;
- skonfrontować eventy z 10 nagraniami/obserwacjami za zgodą.

**Kryterium:** ≥90% sklepów ma jednoznaczną ścieżkę; różnica backend–provider dla paid orders = 0 po reconciliation; każde KPI pokazuje licznik i denominator.

### 90 dni

- minimum 50 kwalifikowanych sklepów lub jawne oznaczenie małej próby;
- analiza kohort kanał × seller stage × onboarding mode;
- model czasu do milestone i przyczyn drop-off;
- audyt prywatności, dostępu, retencji i consent;
- usunąć eventy bez decyzji oraz dodać tylko te, których brak utrudnił analizę.

**Kryterium:** można wskazać trzy największe drop-offy z ilościowym i jakościowym dowodem; co najmniej jeden eksperyment poprawia first fulfilled sale lub czas bez naruszenia guardrails. Jeśli rośnie preview, ale nie paid/fulfilled, priorytet przechodzi na ruch, ofertę lub checkout.

## Źródła

1. [Google Analytics — Ecommerce setup Q&A](https://support.google.com/analytics/answer/14143583?hl=en)
2. [Google Data Manager API — recommended ecommerce events](https://developers.google.com/data-manager/api/reference/analytics/recommended-events)
3. [RODO — tekst rozporządzenia](https://eur-lex.europa.eu/legal-content/PL/TXT/?uri=CELEX%3A32016R0679)
4. [EDPB Guidelines 01/2025 on Pseudonymisation](https://www.edpb.europa.eu/public-consultations/guidelines-012025-on-pseudonymisation_en)
5. [CNIL — audience measurement solutions, 04.07.2025](https://www.cnil.fr/fr/cookies-et-autres-traceurs/regles/cookies-solutions-pour-les-outils-de-mesure-daudience)
6. [EDPB — DPIA template explainer 2026](https://www.edpb.europa.eu/system/files/2026-04/edpb_dpia_template_explainer_2026_v1_en.pdf)

## Co obniża pewność

- brak bazowych danych Sklepika;
- status consent/exemption zależy od konkretnej konfiguracji narzędzia i kraju;
- segmenty mają różny czas do sprzedaży;
- progi aktywacji i konwersji są celami pilotażowymi, nie benchmarkami;
- first fulfilled sale nie mierzy jeszcze długoterminowej retencji ani rentowności sprzedawcy.
