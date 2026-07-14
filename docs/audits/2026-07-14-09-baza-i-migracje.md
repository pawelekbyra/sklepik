# Audyt 09: baza danych i migracje

**Data:** 2026-07-14
**Repozytoria:** `pawelekbyra/sklepik` @ `9a4f693147`; kontrakty `sklepikFront` @ `0f83b94`
**Zakres:** schemat, inwarianty, tenant keys, pieniądze i zamówienia, migracje, instalacja/upgrade, transakcje i współbieżność, wydajność, retencja/PII oraz rozjazd adapterów.
**Metoda:** analiza wszystkich 170 migracji `spree/core/db/migrate`, schematu dummy, modeli i serwisów krytycznych, zadań upgrade, CI oraz ścieżki wdrożenia Oracle. Bez połączenia z produkcją i bez zmian produktu.

## Werdykt

**Baza jest funkcjonalnym fundamentem pilota, ale nie jest jeszcze fundamentem bezpiecznej fabryki wielu sklepów.** Największym problemem nie jest PostgreSQL sam w sobie, lecz brak jednego, wykonywalnego kontraktu stanu bazy: efemeryczny host kopiuje migracje pod nowymi timestampami, produkcyjny schemat nie jest wersjonowany, wymagane backfille tenantów nie są częścią release'u, a integralność tenantów i pieniędzy w dużej mierze zależy od callbacków i walidacji Rails.

Nie znaleziono dowodu aktualnej korupcji danych. Znaleziono jednak ścieżki, które mogą ją wytworzyć przy upgrade, równoległym zapisie, imporcie, jobie albo błędzie aplikacji. Przed skalowaniem self-service wymagane są: stabilny artefakt migracji, automatyczny upgrade z post-condition checks, bazowe constraints tenant/money oraz test migracji na kopii schematu PostgreSQL.

### Podsumowanie priorytetów

| Priorytet | Liczba | Najważniejszy skutek |
|---|---:|---|
| P0 | 1 | release może ponownie wykonać historyczne DDL albo utracić audytowalność stanu |
| P1 | 5 | niepełny upgrade tenantów, orphan/cross-tenant rows, brak DB-owej ochrony pieniędzy, ryzykowne DDL |
| P2 | 4 | race w provisioningu, brak retencji, brak query budgets, rozjazd adapterów |
| P3 | 0 | — |

## Mapa pokrycia

| Obszar | Sprawdzone | Wynik |
|---|---|---|
| Historia migracji | 170 plików w `spree/core/db/migrate` | 74 pliki mają DDL bez widocznego guarda idempotencji; wszystkie przechodzą `ruby -c` |
| Schemat | `spree/api/spec/dummy/db/schema.rb` | 131 tabel `spree_*`; schemat pochodzi z SQLite, nie z produkcyjnego PostgreSQL |
| Tenant ownership | stores/products/taxons/promotions/payment methods/roles/channels/publications/pages | ownership istnieje, lecz część kluczy pozostaje nullable i bez FK; brak cross-store constraint publikacji |
| Money/order | orders/line_items/prices/payments/refunds/sessions | decimal i walidacje modeli są; brak CHECK/FK dla podstawowych inwariantów |
| Instalacja/upgrade | Oracle workflow, release scripts, rake upgrade | migracje + tylko role-user backfill; pozostałe wymagane backfille nie są w release |
| Współbieżność | cart/order/payment/stock/page/provisioning | krytyczne flow często używają transakcji/locków; provisioning step nie ma unique constraint |
| Wydajność | indeksy, includes, narzędzia | dużo indeksów i lokalne optymalizacje; brak automatycznego N+1/query-budget i statystyk produkcyjnych w repo |
| Retencja/PII | orders/users/addresses/logs/exports/webhooks | brak kompletnego lifecycle/DSAR/retention contract |
| Adaptery | PostgreSQL prod, PostgreSQL/MySQL CI, SQLite packages/dummy | brak canonical PostgreSQL schema/structure i migracyjnego gate na PR |

## Ustalenia

### DB-001 — P0 — migracje nie są trwałym i jednoznacznym artefaktem release'u

**Fakt.** Oracle kopiuje migracje engine do efemerycznego startera przed `db:migrate`. Starter nie zachowuje skopiowanych plików; dokumentacja potwierdza nowe timestampy, ostrzeżenia „missing migrations” oraz wcześniejszą próbę ponownego utworzenia `spree_tags` przez zbyt szeroki task (`docs/deployment-oracle.md:150-166`, `docs/deployment-render.md:39-43`). Repo nie wersjonuje produkcyjnego `schema.rb`/`structure.sql` ani manifestu migracji host-app.

Statyczne skanowanie znalazło 74/170 migracji z DDL bez widocznego `if_not_exists`, `if_exists` lub jawnego sprawdzenia. To konserwatywna liczba kandydatów, nie dowód, że każda jest niebezpieczna; obejmuje jednak także współczesne migracje tworzące markets, allowed origins, price histories i zmieniające media. Brak testu, który dwa razy odtwarza dokładnie produkcyjny copy-and-migrate flow.

**Wpływ.** Release może zatrzymać się na duplicate table/column/index, a operator nie ma repozytoryjnego artefaktu pozwalającego jednoznacznie porównać kod migracji, `schema_migrations` i realny schemat. Przy częściowym release'ie rollback aplikacji nie oznacza rollbacku bazy.

**Rekomendacja.** Umieścić stabilną host-app/migracje w obrazie lub commitowanym katalogu; wersjonować PostgreSQL `structure.sql`; generować manifest `version/name/checksum`; uruchamiać migracje pojedynczym release commandem pod blokadą. Do czasu zmiany architektury doprowadzić każdą migrację kopiowaną ponownie do pełnej idempotencji.

**Test zamykający.** Na świeżym PostgreSQL: install → pełny migrate → ponowne utworzenie efemerycznego host-app → install/migrate drugi raz → zero DDL i zero błędów; następnie upgrade kopii poprzedniego schematu i porównanie `structure.sql`, constraints, indexes oraz manifestu checksum.

**Duplikaty:** SYS-012; ARCH-005; SPREE-005.

### DB-002 — P1 — wymagane backfille tenantów nie są atomową częścią upgrade'u

**Fakt.** Migracje jawnie mówią, że po ich wykonaniu istniejące rekordy pozostają bez ownership i wymagają zadań:

- produkty: `spree:upgrade:populate_publications` (`20260601000002...:2-9`),
- taxons: `spree:taxons:backfill_store_id` (`20260626000001...:2-7`),
- promotions i payment methods: `spree:upgrade:populate_single_store_associations` (`20260628000001...:2-6`, `20260628000002...:2-7`),
- role users: `spree:role_users:backfill_store_ids` (`20260613000001...:3-8`).

Automatyczny deploy wykonuje po migracjach tylko backfill role users (`.github/workflows/deploy-oracle.yml:115-118`). Zweryfikowany runbook ręczny wykonuje wyłącznie install/migrate (`docs/deployment-oracle.md:156-164`). Kolumny `store_id` produktów, taxons, promotions, payment methods i role users nadal są nullable w schemacie.

**Wpływ.** Upgrade istniejącej instalacji może przejść technicznie na zielono, ale ukryć produkty/promocje/płatności albo pozostawić rekordy globalne. To silent data loss z perspektywy API/storefrontu, niekoniecznie błąd migracji.

**Rekomendacja.** Jeden wersjonowany task `spree:upgrade` jako obligatoryjny etap release: migracje → idempotentne backfille → post-condition queries → dopiero health gate. Każdy etap rejestrowany w osobnej tabeli/manifestcie i bezpieczny do wznowienia. Po oczyszczeniu danych dodać `NOT NULL` dla faktycznie tenantowych rekordów albo udokumentowany mechanizm globalnych rekordów.

**Test zamykający.** Fixture poprzedniej wersji z co najmniej dwoma sklepami przechodzi upgrade; liczba produktów, promocji, taxons i payment methods per tenant przed/po jest identyczna; zapytania `WHERE store_id IS NULL` zwracają wyłącznie jawnie dozwolone klasy rekordów; storefront obu tenantów zachowuje katalog.

### DB-003 — P1 — integralność tenantów zależy od Rails, bez pełnej ochrony w DB

**Fakt.** Projekt świadomie unika FK w większości migracji. Dummy schema ma FK głównie dla Active Storage i starych tabel tłumaczeń; orders, products, channels, role users, provisioning, payments i line items nie mają FK. Kluczowe ownership columns są nullable w warstwie przejściowej. `spree_product_publications` wymusza tylko unikalność `(product_id, channel_id)`; model również sprawdza obecność i unikalność, ale nie sprawdza `product.store_id = channel.store_id` (`product_publication.rb:13-18`). Podobne relacje cross-store mogą powstać przez raw SQL, import, `insert_all` lub pominięty callback.

**Wpływ.** Orphan rows i relacje między sklepami mogą przetrwać w bazie, przeciekać do joinów/cache albo blokować późniejsze constraints. Brak FK utrudnia bezpieczne usuwanie sklepu i wykrycie niepełnego provisioningu.

**Rekomendacja.** Zdefiniować tabelę inwariantów per model. Dodać FK `NOT VALID` → validate online dla relacji krytycznych; dla cross-tenant relations denormalizować `store_id` i stosować composite FK/unique keys albo constraint triggers. Minimum: orders, products, channels, publications, roles, provisioning, line items, payments/refunds. Dodać okresowy orphan/cross-tenant reconciliation.

**Test zamykający.** Próba SQL utworzenia orphan i cross-store publication/role/payment kończy się naruszeniem constraint; reconciliation na fixture dwóch tenantów zwraca zero; usunięcie/soft-delete store ma jawnie przetestowaną semantykę dla wszystkich dzieci.

**Duplikaty:** TENANT-004/005 (jeśli występują w audycie 04), AUTH findings dotyczące role ownership.

### DB-004 — P1 — baza nie chroni podstawowych inwariantów pieniędzy i zamówień

**Fakt.** Kwoty są przechowywane jako `decimal`, a modele walidują m.in. price/refund/payment amount oraz order totals. W schemacie brak jednak `CHECK` dla:

- `line_items.quantity > 0`, cen i refundów nieujemnych,
- poprawnych kodów waluty i zgodności currency line item/order/payment session,
- ograniczenia refund sum do captured amount,
- poprawnych zbiorów status/state,
- zależności czasowych publication/session/reservation,
- podstawowego równania sum zamówienia.

`orders`, `line_items`, `payments`, `refunds` nie mają DB FK. Unikalny partial index payment response code jest dobrym zabezpieczeniem idempotencji providera, a serwisy płatności/cart/order używają transakcji i w części `with_lock`; nie obejmuje to jednak raw/bulk writes ani wszystkich asynchronicznych ścieżek.

**Wpływ.** Błąd joba, importu, przyszłego agenta AI lub ręcznej operacji może zapisać sprzeczny stan finansowy, którego aplikacja nie odrzuci przy późniejszym odczycie. Reconciliation i audyt księgowy stają się trudne.

**Rekomendacja.** Najpierw constraints niskiego ryzyka: dodatnia quantity, nieujemne price/payment/refund, ISO currency shape, status sets i required relations. Następnie immutable ledger/eventy płatnicze, reconciliation oraz idempotency table. Nie próbować kodować zmiennych sum order w prostym CHECK; chronić je serwisem transakcyjnym i cyklicznym reconciliation z alertem.

**Test zamykający.** Property/concurrency tests na PostgreSQL: równoległy checkout, podwójny webhook, refund race, stock race; bez ujemnych wartości, podwójnego capture/refund i rozjazdu sum. Bezpośredni invalid SQL jest odrzucany przez DB.

**Duplikaty:** MONEY-001, MONEY-003, MONEY-004 z audytu 07.

### DB-005 — P1 — migracje zawierają blokujące i destrukcyjne DDL bez polityki zero-downtime

**Fakt.** W 170 migracjach nie ma `disable_ddl_transaction!` ani `algorithm: :concurrently`. Występują tworzenie indeksów, `change_column_null`, rename columns i data-changing SQL. Przykładowo migracje zone members, payment response code i price/promotion rules kasują duplikaty przed utworzeniem unique index; media migration wykonuje `update_all`; order status wykonuje batch update, po czym ustawia NOT NULL. Repo nie ma jawnego lock-timeout/statement-timeout, shadow migration ani expand-contract gate.

**Wpływ.** Przy rosnących orders/products/payments migracja może długo blokować zapisy checkoutu lub nieodwracalnie skasować rekordy uznane za duplikaty. `docker compose` recreates web przed migracją, więc nie jest to rolling deploy ze zgodnością N/N+1.

**Rekomendacja.** Standard expand/backfill/contract; indexy PostgreSQL `CONCURRENTLY`; constraints `NOT VALID` + validate; jawne `lock_timeout`; destrukcyjne dedupe jako osobny raportowany task z backupem i dry-run; kontrakt kompatybilności co najmniej jednej wersji aplikacji.

**Test zamykający.** Migracja na reprezentatywnej kopii danych przy równoległym syntetycznym ruchu checkout ma mierzone locki i p95; brak request timeoutów; każda destrukcyjna operacja raportuje liczbę rekordów i ma sprawdzony restore/compensation.

### DB-006 — P1 — brak kanonicznego schematu PostgreSQL i migracyjnego gate na PR

**Fakt.** Jedyny tracked schema to `spree/api/spec/dummy/db/schema.rb`, generowany w środowisku SQLite (typy JSON zamiast JSONB, adapterowe różnice partial indexes i typów referencji). Produkcja używa PostgreSQL 15, CI PostgreSQL 16 oraz MySQL 8. Testy backendu mają `if: github.event_name == 'push'`, więc nie chronią PR (`.github/workflows/tests.yml:112-117`). Nie ma joba upgrade-from-previous-schema ani schema drift check.

**Wpływ.** Zmiana może zostać zmergowana bez uruchomienia migracji PostgreSQL; SQLite dummy może ukryć adapter-specific DDL, a MySQL zwiększa matrycę bez gwarancji zgodności z produkcją. Produkcyjny drift pozostaje niewidoczny do release'u.

**Rekomendacja.** PostgreSQL jako source-of-truth: tracked `structure.sql`, CI na tej samej major version co produkcja, migration lint i trzy ścieżki: fresh install, upgrade poprzedniego release, double-run efemerycznego copy flow. MySQL zachować tylko jeśli jest realnym wspieranym produktem; SQLite ograniczyć do szybkich unit tests.

**Test zamykający.** Każdy PR z migracją uruchamia fresh/upgrade/double-run na PostgreSQL; diff `structure.sql` musi być oczekiwany; production read-only drift check porównuje tabele/kolumny/indexes/constraints po deployu.

### DB-007 — P2 — provisioning steps ma race i nie wymusza deklarowanej unikalności

**Fakt.** Model mówi „one row per stage” i używa `steps.find_or_initialize_by(name:)`, ale tabela ma tylko index `run_id`, bez unique `(run_id, name)` (`20260714000002...:3-11`, `provisioning_run.rb:40-50`). `advance!` nie obejmuje zapisu kroku i runa jedną transakcją/lockiem. Statusy są tylko model validation.

**Wpływ.** Dwa retry/workery mogą utworzyć duplikaty kroku, zgubić aktualizację lub zapisać step `done` przy run pozostającym w poprzednim statusie. Polling panelu może prezentować nieprawdziwy stan.

**Rekomendacja.** Unique `(run_id,name)`, transaction + row lock/upsert, optimistic lock dla run, CHECK statusów i recovery state machine. Operacje zewnętrzne nadal wymagają idempotency keys/reconciliation.

**Test zamykający.** 10 równoległych wywołań `advance!` tworzy dokładnie jeden step; run i step są spójne po wymuszonym wyjątku między zapisami; retry po crashu kończy się deterministycznie.

**Duplikat:** ARCH-003.

### DB-008 — P2 — brak kompletnego lifecycle retencji i danych osobowych

**Fakt.** Baza przechowuje customer email, adresy, IP, user-agent, order metadata, webhook payloads, exports i log entries. Istnieją soft-delete i punktowe purge dla unattached media, ale nie znaleziono wykonywalnej macierzy retention/anonymization/DSAR dla całego grafu zamówienie–klient–adres–płatność–webhook–export. Feature matrix oznacza self-service export/delete jako brak.

**Wpływ.** Dane mogą być przechowywane bezterminowo albo usunięte niespójnie z obowiązkami podatkowymi/reklamacyjnymi. Backup zachowuje dane także po usunięciu z live DB.

**Rekomendacja.** Data inventory z ownerem i podstawą prawną; policy per tabela/kolumna; pseudonimizacja zamiast kasowania dokumentów finansowych; jobs retencji z dry-run i audit log; procedura DSAR obejmująca backupy, R2 i providerów.

**Test zamykający.** Fixture klienta jest eksportowany i anonimizowany end-to-end zgodnie z macierzą; zamówienie zachowuje wymagane dane księgowe, a PII znika z live/search/cache/log/export; odtworzony backup ma procedurę ponownego zastosowania tombstones.

**Duplikat:** SYS-015.

### DB-009 — P2 — brak wykonywalnych budżetów zapytań i obserwowalności SQL

**Fakt.** Kod zawiera liczne `includes`, preload i dedykowane indeksy; hot paths stock/cart/payment stosują transakcje i locki. Nie znaleziono jednak Bullet/Prosopite, request query budgets, `pg_stat_statements` runbooku, slow-query alertów ani load fixture reprezentującego setki sklepów. Indeksy są często projektowane pod pojedyncze kolumny; bez realnych planów zapytań nie da się ocenić selektywności tenant-first.

**Wpływ.** N+1 i table scans mogą pozostać niewidoczne na sześciu produktach, a potem wyczerpać połączenia pojedynczej VM i zatrzymać checkout wszystkich tenantów.

**Rekomendacja.** Włączyć `pg_stat_statements`, slow query log i dashboard top queries; query budgets dla catalog/PDP/cart/order/admin lists; seed obciążeniowy wielotenantowy; indeksy dobierać z `EXPLAIN (ANALYZE, BUFFERS)` i rzeczywistych filtrów, zwykle tenant key jako leading column.

**Test zamykający.** Ustalony fixture scale przechodzi endpoint budgets (liczba zapytań i p95), brak N+1 przy zmianie 10→100 rekordów, a top SQL ma zatwierdzony plan bez nieuzasadnionych seq scans.

### DB-010 — P2 — semantyka slugów produktu pozostaje globalna, nie tenantowa

**Fakt.** `spree_products.slug` ma globalny unique index; friendly-id scope opiera się na `spree_base_uniqueness_scope`, a standardowy fork nie dodaje do niego `store_id`. Tłumaczone slug histories również nie zawierają jawnego tenant key. W efekcie dwa niezależne sklepy nie mogą mieć identycznego kanonicznego slugu bez automatycznego suffixu, mimo że storefront rozwiązuje produkt w kontekście sklepu.

**Wpływ.** Nazewnictwo jednego tenant wpływa na URL innego; rośnie liczba sztucznych suffixów, a migracja/merge sklepu może powodować kolizje SEO.

**Rekomendacja.** Ustalić kontrakt `(store_id, locale, slug)`; zmienić indeksy aktywnych produktów i friendly-id scope etapowo, zachowując redirect histories. Zweryfikować Store API lookup zawsze w scope bieżącego sklepu przed poluzowaniem globalnego unique.

**Test zamykający.** Dwa sklepy tworzą `/products/mydlo` w tym samym locale; oba lookupy zwracają właściwy produkt; historia rename i redirect nie przecieka między tenantami.

## Mocne strony obecnego fundamentu

- Kwoty używają `decimal`, nie float.
- Wiele nowych migracji ma `if_not_exists`/`if_exists` i jawne różnice PostgreSQL/MySQL.
- Krytyczne serwisy cart/order/payment/stock często używają transakcji, `with_lock` lub unikalnych indeksów.
- Ceny mają partial unique indexes rozdzielające base price i price-list price.
- Storefront pages używają optimistic locking i unique `(store_id, slug)`.
- Kanały mają unique `(store_id, code)` oraz PostgreSQL partial unique dla default channel.
- Migracje przechodzą kontrolę składni Ruby; nie znaleziono sekretów ani danych produkcyjnych w schemacie.

## Zalecana kolejność napraw

1. **Stabilny artefakt migracji i PostgreSQL structure** — usuwa P0 i umożliwia wiarygodne kolejne prace.
2. **Wykonywalny upgrade + post-conditions** — wszystkie tenant backfille, migration manifest, jeden release command.
3. **Constraint inventory i cleanup danych** — najpierw read-only reconciliation, potem NOT NULL/FK/CHECK `NOT VALID` i validate.
4. **Money/checkout concurrency suite** — równolegle z payment provider, zanim sklep przyjmie realne pieniądze.
5. **Zero-downtime migration policy** — przed istotnym wzrostem tabel.
6. **Production-like CI i drift check** — gate na każdym PR z migracją.
7. **Query/retention program** — przed większą liczbą tenantów i realnych danych klientów.

## Ograniczenia audytu

- Nie łączono się z produkcyjnym PostgreSQL i nie odczytywano jego `schema_migrations`, katalogów systemowych, statystyk, rozmiarów tabel ani planów zapytań.
- Nie uruchomiono Dockerowego fresh-install/upgrade/double-run; lokalny `server/` jest efemeryczny/.gitignored, a test miał być bez produkcji. To jest wymagany test zamykający DB-001/006.
- `schema.rb` dummy pochodzi z SQLite, więc nie dowodzi dokładnych typów i constraints produkcji.
- Statyczny licznik 74 migracji jest przesiewem DDL; wymaga klasyfikacji każdej pozycji przed mechaniczną zmianą.
- Nie oceniano legalnych okresów retencji — raport wskazuje brak technicznego kontraktu, nie udziela porady prawnej.
- N+1 oceniono kodowo; bez danych i `EXPLAIN ANALYZE` nie przypisano konkretnym query kosztu produkcyjnego.

## Artefakty i komendy kontrolne

- `find spree/core/db/migrate -type f | wc -l` → `170`.
- `find . -name schema.rb -o -name structure.sql` → tylko `spree/api/spec/dummy/db/schema.rb`.
- Skan DDL bez widocznych guardów → 74 pliki kandydackie.
- `ruby -c` na wszystkich 170 migracjach → bez błędów składni.
- Brak trafień `disable_ddl_transaction!` i `algorithm: :concurrently` w migracjach core.

## Kryterium zamknięcia całego audytu 09

Audyt można uznać za zamknięty dopiero, gdy jeden CI workflow na PostgreSQL wykonuje: fresh install, upgrade z poprzedniego release, powtórny efemeryczny install/migrate, tenant post-conditions, constraint/orphan scan, concurrency money smoke oraz schema drift diff; ten sam artefakt migracji trafia na produkcję, a restore test potwierdza, że odtworzona baza przechodzi identyczne kontrole.
