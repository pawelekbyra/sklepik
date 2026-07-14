# Audyt 04: izolacja sklepów

Data: 2026-07-14
Zakres: `pawelekbyra/sklepik` oraz konsument `pawelekbyra/sklepikFront`
Charakter: audyt statyczny z przeglądem istniejących testów; bez zmian kodu produktu

## Wniosek wykonawczy

Fundament izolacji typowych zasobów commerce jest znacznie lepszy, niż sugeruje pochodzenie projektu: publishable key wiąże Store API ze sklepem, konflikt klucza z hostem lub `X-Spree-Store-Id` jest odrzucany, Admin API sprawdza membership, produkty, zamówienia, koszyki, layout, endpointy webhooków i cache mają jawny kontekst sklepu. Nie można jednak uznać systemu za bezpiecznie wielotenantowy.

**Blokerem jest domena klientów.** Konto `Spree.user_class` jest globalne, `User.for_store` celowo zwraca wszystkie rekordy, a standardowa rola `admin` dostaje `SuperUser` z `can :manage, :all`. W efekcie administrator jednego sklepu może listować, czytać i modyfikować klientów innych sklepów, ich dane kontaktowe, adresy, notatki i globalne statystyki zakupowe. Kod i testy wręcz utrwalają to zachowanie jako zamierzone dla starego modelu Spree. Dla platformy niezależnych merchantów jest to **P0**.

Ocena: **NIE GOTOWE na wpuszczenie niezależnych sprzedawców do wspólnego backendu** do czasu zamknięcia `TENANT-001` i podjęcia decyzji z `TENANT-002`.

## Metoda i coverage

Przeczytano instrukcje repozytoriów, kanon produktu, stan, roadmapę, architekturę, decyzje silnikowe i plany Store Factory/multi-store. Następnie prześledzono tenant resolution od nagłówków i kluczy do `Spree::Current`, autoryzację JWT/secret key, bazowy `ResourceController`, `for_store`, CanCanCan oraz cache. Statycznie zinwentaryzowano i sprawdzono:

- 36 kontrolerów Store API v3;
- 71 kontrolerów Admin API v3;
- 24 concerny kontrolerów v3;
- 29 jobów w `spree/core` i `spree/api`;
- modele i serwisy dotyczące klientów, koszyków, zamówień, kluczy, webhooków, layoutu, provisioningu, wyszukiwania i storage;
- singleton klienta i webhook receiver w `sklepikFront`;
- 71 plików testowych zawierających scenariusze `other_store`, cross-store lub tenant isolation.

Każdy endpoint został objęty przeglądem przez wspólne klasy bazowe i wyszukanie odstępstw: własne `scope`, bezpośrednie `find/find_by`, custom actions, nested parent resolution oraz `skip_before_action`. Szczegółowo prześledzono wszystkie trafienia odstępujące od bazowego `scope`.

### Ograniczenia

- Nie wykonano testu na produkcji ani nie tworzono danych w realnych sklepach.
- Lokalny runner `pnpm` jest niedostępny (`pnpm: command not found`), więc `@spree/test-contracts` nie został uruchomiony. Jego testy są ponadto testami z mockami, nie testem prawdziwego Rails API.
- Nie było gotowej uruchomionej testowej aplikacji Rails/Postgres, dlatego nie uruchomiono RSpec. Dowody P0 wynikają bezpośrednio z relacji, permission setów, kontrolera, serializera i istniejących testów kodujących globalny zakres.
- Zewnętrzne granice GitHub, Vercel, R2/CDN i Redis oceniono z kodu i konfiguracji, bez inspekcji kont dostawców.

## Mapa granicy tenanta

| Wejście | Identyfikator tenanta | Kontrola spójności | Ocena |
|---|---|---|---|
| Store API | aktywny publishable key | konflikt z przypisanym hostem lub `X-Spree-Store-Id` → 401 | dobra |
| Admin API, JWT | `X-Spree-Store-Id` | `RoleUser` dla `current_store` → 403 | dobra, poza klientami globalnymi |
| Admin API, secret key | store klucza + wybrany `current_store` | różny `store_id` → odrzucenie | dobra |
| Cache HTTP | store + market + channel + currency + locale | `Vary` obejmuje kontekstowe nagłówki | dobra |
| Koszyk/zamówienie | relacja `current_store` i token/user | parent i wariant scope'owane | dobra |
| Layout | `current_store.storefront_pages` | draft tylko Admin, published tylko Store | dobra |
| Webhook routing | `event.store_id` | endpointy filtrowane po store | dobra; payload nie niesie store ID |
| Provisioning | `current_user.stores` i `run.store` | job pracuje na zapisanym run/store | dobra dla izolacji |
| Storefront Vercel | osobny deployment + publishable key w env | jeden singleton klienta per deployment | dobra dla obecnego modelu |
| Klient końcowy | globalny `Spree.user_class` | brak membership/tenant claim | **przełamana** |

## Findings

### TENANT-001 — P0 — administrator sklepu ma globalny dostęp do klientów innych sklepów

Status dowodu: **fakt**.

Dowód:

- `spree/core/app/models/concerns/spree/user_methods.rb:189-192` — `Spree.user_class.for_store(store)` bezwarunkowo zwraca `self`;
- `spree/api/app/controllers/spree/api/v3/admin/customers_controller.rb:73-75` — zakres klientów to bazowy `super.with_order_aggregates`, a bazowy scope opiera się na `model_class.for_store(current_store)`; dla usera oznacza wszystkie konta;
- `spree/core/app/models/spree/permission_sets/super_user.rb:12-14` — rola admina ma `can :manage, :all`;
- `spree/lib/generators/spree/install/templates/config/initializers/spree.rb:90-91` — standardowa konfiguracja przypisuje `SuperUser` roli `admin`;
- `spree/api/app/serializers/spree/api/v3/admin/customer_serializer.rb:23-49,52-57,83-102` — odpowiedź może zawierać e-mail, telefon, IP logowania, notatkę wewnętrzną, adresy, grupy i metadane;
- `spree/api/spec/controllers/spree/api/v3/admin/customers_controller_spec.rb:8-19` — test oczekuje zwrotu klienta, który nie jest przypisany do bieżącego sklepu;
- `spree/api/spec/controllers/spree/api/v3/admin/customers_controller_spec.rb:298-301` — komentarz utrwala globalny zakres userów i deleguje granicę do ability, które dla admina jest globalne;
- `spree/api/app/controllers/spree/api/v3/admin/orders_controller.rb:132-137` oraz `spree/core/app/services/spree/orders/create.rb:81-105` — administrator może znaleźć globalnego klienta i skopiować jego domyślne adresy do zamówienia swojego sklepu.

Wpływ: niezależny merchant A może odczytać i zmienić PII, hasło, tagi, notatki i metadane klienta sklepu B; może też poznać lub skopiować jego adres. Agregaty `with_order_aggregates` (`user_methods.rb:156-170`) liczą zamówienia ze wszystkich sklepów, więc ujawniają również cudzy wolumen i wartość zakupów. To narusza podstawową obietnicę izolacji danych i może stanowić incydent ochrony danych.

Naprawa:

1. Wprowadzić jawną relację membership klient–store (np. `StoreCustomer`/`CustomerAccount`) lub bezpieczny scope wyprowadzony z zamówień **bez** uznawania usera globalnego za rekord panelu każdego sklepu.
2. `Admin::CustomersController#scope`, nested customer controllers, bulk operations, tags, groups, credit cards, store credits i `OrdersController#resolve_user` muszą korzystać wyłącznie z zakresu klientów bieżącego sklepu.
3. Agregaty i serializowane relacje (`orders`, `addresses`, `store_credits`, groups) muszą być liczone/filtrowane w kontekście sklepu.
4. Nie polegać na `SuperUser` jako granicy rekordowej; scope tenanta musi poprzedzać authorization.

Test zamykający: dwóch adminów i dwa sklepy; klient tylko B. JWT i secret key A muszą dostać 404 dla show/update/destroy, nie widzieć klienta na index/search/export/tags/groups, nie móc utworzyć z nim zamówienia ani odczytać nested resources. Klient wspólny dla A i B ma pokazywać każdemu merchantowi wyłącznie dane i agregaty z jego sklepu.

### TENANT-002 — P1 — tokeny i profil klienta są przenośne pomiędzy sklepami bez jawnej decyzji produktowej

Status dowodu: **fakt w kodzie; klasyfikacja ryzyka zależy od decyzji produktowej**.

Dowód:

- `spree/core/app/models/spree/authentication/strategies/base_strategy.rb:37-40` — login wyszukuje e-mail globalnie;
- `spree/api/app/controllers/concerns/spree/api/v3/jwt_authentication.rb:51-60,74-81,99-108` — JWT zawiera user/audience, ale nie `store_id`; token Store API wystawiony w B jest ważny w A;
- `spree/api/app/controllers/spree/api/v3/store/auth_controller.rb:50-67` — refresh token jest globalny i może zostać odświeżony przez dowolny storefront z prawidłowym publishable key;
- `spree/api/app/serializers/spree/api/v3/customer_serializer.rb:31-33` — profil zwraca globalne adresy, bill address i ship address;
- `spree/api/app/controllers/spree/api/v3/store/customers_controller.rb:13-29` — rejestracja tworzy globalny user, więc ten sam e-mail nie tworzy niezależnego konta w następnym sklepie.

Wpływ: klient zalogowany w jednym niezależnym sklepie może użyć tego samego tokenu w drugim i zobaczyć tam swój globalny profil oraz adresy. Merchanty stają się niejawnie uczestnikami jednego systemu tożsamości. To może być celowe SSO platformy, ale nie jest zgodne z intuicją „niezależnych sklepów” bez wyraźnej zgody, komunikacji i modelu danych.

Naprawa: przed implementacją podjąć decyzję: (A) konta per sklep — tenant claim w access/refresh tokenie, unikalność e-mail per store i tenant-owned adresy; albo (B) jawne Sklepik ID/SSO — osobne merchant-visible profile/memberships i wyraźna zgoda na udostępnienie adresu kolejnemu sklepowi. Samo dodanie `store_id` do JWT bez przebudowy danych nie zamknie `TENANT-001`.

Test zamykający: macierz login/refresh/profile/update/password reset dla A/B. Dla modelu per-store token B musi być 401 w A i nie może ujawnić adresów; dla SSO test musi wykazać jawny consent i brak dostępu merchanta do danych innego membershipu.

### TENANT-003 — P1 — nie ma wykonywanego E2E dwóch tenantów, a kontrakt izolacji nie bada najbardziej ryzykownej domeny

Status dowodu: **fakt**.

Dowód:

- `packages/test-contracts/src/isolation.ts:1-75` testuje jedynie produkt, zapis do cudzego koszyka i konflikt klucza ze store ID;
- `packages/test-contracts/tests/contracts.test.ts:92-158` używa mocków HTTP, więc nie wykonuje kontraktu przeciw Rails;
- `docs/plans/store-factory.md:99` jawnie pozostawia pełne testy dwóch tenantów jako niezrobione;
- istniejące specy klientów utrwalają globalne zachowanie zamiast je odrzucać;
- próba uruchomienia `pnpm --filter @spree/test-contracts test` zakończyła się `pnpm: command not found` w środowisku audytu.

Wpływ: zielone unit/controller tests mogą współistnieć z krytycznym przeciekiem PII. Obecny test kontraktowy daje fałszywe poczucie zamknięcia tematu.

Naprawa: utworzyć uruchamiany w CI black-box suite na prawdziwym Postgres/Rails dla dwóch sklepów, dwóch adminów, dwóch publishable/secret keys i klientów. Pokryć wszystkie wiersze mapy tenanta oraz negatywne IDOR dla każdego endpointu z identyfikatorem.

Test zamykający: suite uruchamiana w CI bez mockowania odpowiedzi API; failuje po celowym usunięciu dowolnego scope'u i obejmuje klientów, adresy, pliki, eksporty, joby i webhooki, nie tylko katalog/koszyk.

### TENANT-004 — P2 — runtime webhook payload nie zawiera `store_id`, mimo że kontrakt SDK tego wymaga

Status dowodu: **fakt**.

Dowód:

- `spree/api/app/subscribers/spree/webhook_event_subscriber.rb:25-33` poprawnie wybiera endpointy po `event.store_id`;
- `spree/api/app/subscribers/spree/webhook_event_subscriber.rb:67-74` buduje payload bez `store_id`;
- `packages/sdk/src/types/store-factory-contracts.ts:100-108` deklaruje tenant context na każdym webhooku;
- `packages/test-contracts/src/isolation.ts:62-73` oczekuje `webhookEvent.store_id`;
- `sklepikFront/src/lib/spree/webhooks.ts:79-87` parsuje event bez runtime walidacji tenanta.

Wpływ: routing backendowy jest obecnie izolowany sekretem endpointu i filtrem store, więc nie potwierdzono bezpośredniego wycieku. Brak identyfikatora uniemożliwia jednak odbiorcy sprawdzenie tenant context, bezpieczny fan-in wielu sklepów i audyt zgodności; kontrakt oraz runtime są sprzeczne.

Naprawa: dodać prefixed `store_id` do podpisanego body (oraz do typów runtime/Zod), a storefront niech porównuje go z oczekiwanym store ID z konfiguracji. Nie polegać na niepodpisanym dodatkowym nagłówku.

Test zamykający: event A trafia wyłącznie do endpointu A, podpisane body ma `store_id=A`; receiver B odrzuca poprawnie podpisany jego sekretem payload z `store_id=A`.

### TENANT-005 — P2 — Active Storage nie ma własności blobu przypisanej do sklepu

Status dowodu: **inferencja potwierdzona modelem, exploit nieodtworzony dynamicznie**.

Dowód:

- `spree/core/app/models/concerns/spree/user_methods.rb:102` i modele commerce używają standardowych attachables Active Storage;
- `packages/dashboard-core/src/components/image-upload-field.tsx:40` korzysta z bezpośredniego uploadu Active Storage;
- kontrolery medów scope'ują docelowy produkt (`spree/api/app/controllers/spree/api/v3/admin/media_controller.rb:36-62`), ale standardowy `ActiveStorage::Blob` nie ma `store_id` ani policy wiążącej signed blob ID z tenantem.

Wpływ: signed blob ID działa jak bearer capability. Jeżeli ID blobu ze sklepu B wycieknie przed lub po podpięciu, kod nie ma drugiej kontroli uniemożliwiającej użycie go w rekordzie A. Publiczne asset URL-e są z natury dostępne, ale mutacja/ponowne przypisanie powinny mieć granicę tenantową.

Naprawa: podczas direct upload zapisywać tenant ownership w kontrolowanej tabeli/metadata i przy każdym attach sprawdzać zgodność z `current_store`; dla publicznych mediów jasno rozdzielić poufność od integralności przypisania.

Test zamykający: admin A nie może dołączyć signed blob ID utworzonego w sesji B do produktu, wariantu, logo ani layout assetu A; odpowiedź 404/422 i brak attachmentu.

### TENANT-006 — P2 — `Base.for_store` pozostaje fail-open dla każdego nowego lub źle skojarzonego modelu

Status dowodu: **fakt; ryzyko przyszłej regresji**.

Dowód: `spree/core/app/models/spree/base.rb:34-53` zwraca całą klasę, jeżeli `Store` nie odpowiada na oczekiwaną plural association. Komentarz w kodzie sam określa to jako sharp edge i możliwy leak. `TENANT-001` pokazuje, że ostrzeżenie dokumentacyjne nie stanowi skutecznej granicy.

Wpływ: literówka, brak `has_many` albo nowy model tenant-owned automatycznie zmienia „brakuje konfiguracji” w „zwróć rekordy wszystkich sklepów”. Review i testy muszą wykryć każdą taką regresję.

Naprawa: wprowadzić jawny kontrakt modeli: `GlobalResource` albo `SingleStoreResource`; dla pozostałych `for_store` ma failować głośno. Migrację wykonać przez listę wszystkich wywołań, bo globalne modele są load-bearing.

Test zamykający: syntetyczny tenant-owned model bez association powoduje kontrolowany wyjątek w test/development i blokuje CI; lista globalnych modeli jest jawna i zatwierdzona.

### TENANT-007 — P2 — job wyszukiwarki ufa niesprawdzonej parze `resource_id`/`store_id`

Status dowodu: **fakt w kodzie; wektor zewnętrzny niewykazany**.

Dowód: `spree/core/app/jobs/spree/search_provider/index_job.rb:16-23` niezależnie pobiera zasób i sklep, a potem indeksuje zasób w providerze tego sklepu. Nie sprawdza, czy resource należy do store. `RemoveJob` analogicznie usuwa prefixed ID z indeksu wskazanego store (`remove_job.rb:14-20`).

Wpływ: błąd enqueue, replay zmodyfikowanego joba lub przyszły call site może wstawić produkt A do indeksu B albo usunąć dokument B. To problem integralności i potencjalnego publicznego ujawnienia danych przez search provider.

Naprawa: job ma resolve'ować zasób przez `for_store(store)`/store association i odrzucać mismatch z telemetrycznym alertem. Payload joba powinien przechowywać stabilny tenant context.

Test zamykający: `IndexJob(product_A, store_B)` nie wywołuje providera i raportuje mismatch; poprawna para działa. Analogiczny test remove powinien korzystać z tenant-namespaced document ID/index.

### TENANT-008 — P3 — Admin API ujawnia istnienie sklepu przez różnicę 404/403

Status dowodu: **fakt; niski wpływ**.

Dowód:

- `spree/api/app/controllers/spree/api/v3/admin/base_controller.rb:25-33` najpierw globalnie rozwiązuje store z nagłówka; nieistniejący ID daje 404;
- `spree/api/app/controllers/concerns/spree/api/v3/admin_authentication.rb:53-61` istniejący sklep bez membership daje 403.

Wpływ: zalogowany użytkownik może odróżnić poprawny identyfikator cudzego sklepu od nieistniejącego. Nie daje to dostępu do danych, ale ułatwia enumerację tenantów.

Naprawa: dla JWT rozwiązywać wybór przez `current_user.stores` albo ujednolicić zewnętrzną odpowiedź dla braku i braku membership; zachować diagnostykę w logach.

Test zamykający: obcy i nieistniejący prefixed ID dają nierozróżnialny status/body/timing w rozsądnej tolerancji.

## Kontrole, które przeszły przegląd

Poniższe obszary nie wygenerowały findingu o bezpośrednim cross-tenant read/write:

- publishable key jest globalnie znaleziony, ale następnie wiąże `current_store`; sprzeczny jawny store lub host innego sklepu jest odrzucany;
- secret key Admin API musi mieć `store_id == current_store.id`;
- JWT admina wymaga `RoleUser` na bieżącym sklepie;
- bazowe resource controllers znajdują rekord przez `scope`, a krytyczne custom actions na produktach, cenach, wariantach, zamówieniach, płatnościach, fulfillmentach, gift cards, policies, markets i webhookach mają store/parent scope;
- cart resolution i warianty są zawężone przez `current_store`; ukończonych zamówień nie można pobrać przez cudzy prefixed ID;
- layout draft/publish jest pobierany przez `current_store.storefront_pages`, a Store API nie zwraca draftu;
- webhook subscriber wybiera endpointy przez `event.store_id`, deliveries są nested pod endpointem sklepu;
- provisioning endpoint wybiera store przez `current_user.stores`, a job pracuje na `ProvisioningRun#store`;
- ETag/cache key zawiera store, market, channel, currency i locale; `Vary` uwzględnia nagłówki kontekstu;
- obecny storefront jest single-tenant per deployment i tworzy klienta SDK z jednym `SPREE_PUBLISHABLE_KEY`, więc nie ma request-time pomieszania singletonów.

To są wyniki przeglądu kodu, nie substytut black-box E2E z `TENANT-003`.

## Kolejność zamknięcia

1. **Natychmiast:** nie wpuszczać niezależnych merchantów do wspólnego panelu z realnymi klientami; zamknąć `TENANT-001`.
2. **Przed projektowaniem poprawki:** rozstrzygnąć konta per-store kontra jawne Sklepik ID (`TENANT-002`).
3. **W tym samym strumieniu:** zbudować prawdziwy E2E dwóch tenantów (`TENANT-003`), aby poprawka była mierzalna i regresje blokowały CI.
4. Następnie domknąć kontrakt webhooków, ownership blobów, fail-open `for_store` i guard jobów (`TENANT-004`–`007`).
5. Enumerację store (`TENANT-008`) naprawić przy porządkowaniu resolution, bez opóźniania P0.

## Kryterium akceptacji audytu izolacji

Audyt można zamknąć dopiero, gdy black-box test uruchamiany w CI tworzy dwa kompletne tenanty i potwierdza brak cross-tenant read/write dla katalogu, klientów i PII, adresów, koszyków, zamówień, pieniędzy, konfiguracji, layoutu, medów, eksportów, jobów, cache i webhooków; a kontrolowany test negatywny dowodzi, że usunięcie scope'u rzeczywiście powoduje czerwone CI.
