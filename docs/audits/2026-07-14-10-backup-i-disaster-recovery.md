# Audyt 10 — backup i disaster recovery

**Data:** 2026-07-14
**Zakres:** produkcyjny backend Oracle (PostgreSQL, Redis, Rails/Sidekiq/Nginx), Cloudflare R2/Active Storage, repozytoria i projekty GitHub/Vercel, sekrety i konfiguracja; powiązane storefronty
**Charakter:** audyt statyczny dokumentacji, konfiguracji i kodu; bez dostępu do konsol dostawców, bez odczytu sekretów i bez destrukcyjnego restore'u

## Werdykt

Sklepik ma **pierwszą kopię bezpieczeństwa PostgreSQL**, ale nie ma jeszcze udowodnionej zdolności odtworzenia systemu. Codzienny `pg_dumpall` jest przechowywany lokalnie przez siedem dni i wysyłany do R2, lecz pełnego restore'u nigdy nie wykonano. Nie ma zdefiniowanych RPO/RTO, point-in-time recovery, niezależnej kopii mediów, immutability, alertu o nieskutecznym backupie ani kompletnego runbooka odbudowy nowego hosta. Repo nie zawiera nawet wykonywalnego skryptu backupowego — jego jedyna kopia jest udokumentowana jako plik na chronionym hoście.

Najważniejszy wniosek brzmi: **obecny backup jest obiecującym mechanizmem, nie potwierdzonym planem DR**. Nie znaleziono dowodu uzasadniającego P0, bo baza ma co najmniej dwie kopie dzienne (lokalną i R2), kod jest w GitHubie, a produkcja nie powinna jeszcze przyjmować realnych pieniędzy. Jest jednak pięć P1: brak testu restore, brak niezależnej i odpornej na skasowanie kopii, brak ochrony mediów, brak powtarzalnej odbudowy hosta oraz brak skutecznego alertu backupowego. Przed realną sprzedażą wymagany jest kontrolowany restore drill na izolowanym środowisku.

### Bilans findings

| Priorytet | Liczba | Znaczenie |
|---|---:|---|
| P0 | 0 | nie potwierdzono bezpośrednio trwającej utraty wszystkich kopii |
| P1 | 5 | możliwa nieodtwarzalność bazy, mediów lub całej platformy po awarii/operator error |
| P2 | 5 | zbyt duże RPO/RTO, utrata kolejek/config/provider state, niespójność i retencja |
| P3 | 0 | — |

## Mapa aktywów i obecna ochrona

| Aktyw | Źródło prawdy | Obecna ochrona potwierdzona w repo/dokumentacji | Ocena |
|---|---|---|---|
| PostgreSQL | named volume `postgres_data` na jednej VM | `pg_dumpall` + gzip codziennie 03:00 UTC; lokalnie 7 dni i upload do R2 | **PART** — dump/upload był uruchomiony, restore nie |
| Redis | named volume `redis_data` na tej samej VM | restart policy i watchdog; brak opisanej kopii/restore | **MISS** dla DR |
| Media/originals/variants | Cloudflare R2 + rekordy Active Storage w DB | provider storage; brak potwierdzonego versioning/object lock/replication/export | **UNVERIFIED/MISS** |
| Kod backendu i storefrontu | GitHub | Git, repo zdalne; Store Factory tworzy osobne repo klientów | **PART** — brak inventory/mirror/testu odtworzenia organizacji |
| Vercel projekty i env | Vercel | projekty można częściowo odtworzyć z repo i DB; env/secrets są provider-side | **PART/UNVERIFIED** |
| Konfiguracja Oracle | repo + ręczne pliki hosta | Compose/Nginx w repo; `.env`, cron, cert hooks, firewall, watchdog, backup/healthcheck tylko na hoście | **PART** — znaczący configuration drift |
| Sekrety | `.env` Oracle, GitHub Actions, Vercel/Cloudflare | prawa pliku `.env` 600; brak managera sekretów i udokumentowanego escrow/rotacji po restore | **MISS** dla odtworzenia |
| Certyfikat TLS | Let's Encrypt + hooki hosta | możliwy do ponownego wystawienia; hooki i reguły sieciowe ręczne | **RECREATE**, nie backup |
| Provider metadata | DB (`repo_full_name`, `vercel_project_id`, deployment URL) + providerzy | DB backup zachowuje część identyfikatorów | **PART** — brak reconciliation/exportu provider-side |

## Założenia RPO/RTO — stan obecny

W repo **nie ma zatwierdzonych wartości RPO ani RTO**. Poniższe wartości są oceną granic, nie obietnicą:

- PostgreSQL: nominalne RPO wynosi do około 24 godzin, o ile cron, dump, gzip i upload zadziałają; bez alertu rzeczywiste RPO może być nieograniczone.
- Media R2: RPO jest nieznane; bez versioningu/replication pojedyncze skasowanie lub kompromitacja może być trwała.
- Redis/Sidekiq: RPO jest nieznane i potencjalnie równe wszystkim oczekującym/retry/dead jobs od ostatniego zapisu wolumenu; nie ma niezależnej kopii.
- Utrata całej VM: RTO jest nieznane i zależy od ręcznego odtworzenia Oracle, DNS/firewalla, `.env`, certyfikatu, cronów, Compose, dumpu i zgodnej wersji migracji.
- Utrata konta lub regionu Cloudflare: DB backup i media są objęte tym samym dostawcą R2; brak dowodu kopii poza nim.

Przed launch rekomendowany cel początkowy do zatwierdzenia biznesowo: **RPO bazy ≤ 1 godzina dla zamówień/płatności, RPO mediów ≤ 24 godziny, RTO checkoutu ≤ 4 godziny, RTO pełnego panelu i jobów ≤ 8 godzin**. To rekomendacja, nie obecna zdolność.

## Findings

### DR-001 — P1 — restore PostgreSQL nie został nigdy wykonany

**Dowód:** `docs/stan-projektu.md:41` i `docs/deployment-oracle.md:200` mówią wprost, że ręcznie potwierdzono dump 61 KB i upload do R2, ale nie pełny restore. Wykonywalny skrypt `/home/ubuntu/backup-postgres.sh` nie jest tracked; repo opisuje tylko jego zachowanie. Audyt 09 dodatkowo wykazał brak kanonicznego PostgreSQL `structure.sql` i niestabilny artefakt migracji (`DB-001`, `DB-006`).

**Wpływ:** dump może być niepełny, skompresowany plik uszkodzony, role/ownerzy mogą nie pasować, a aktualny kod może nie uruchomić się na odtworzonym schemacie. Sam sukces `aws s3 cp` nie dowodzi odzyskiwalności.

**Remediacja:** przenieść skrypt backupu i restore do repo jako reviewed automation; generować checksumę, manifest (czas, commit/image, PostgreSQL version, rozmiar, zakres), weryfikować `gzip -t` i listę dumpu. Odtwarzać najnowszą kopię automatycznie na izolowanym PostgreSQL, uruchamiać migracyjny post-check i syntetyczne odczyty dwóch tenantów. Nie przywracać po raz pierwszy na produkcji.

**Test zamykający:** patrz pełny restore drill poniżej; wynik zawiera czas, osiągnięte RPO/RTO, checksumy, liczby rekordów i podpis operatora.

**Cross-reference:** ARCH-001; DB-001/006; SYS-012.

### DR-002 — P1 — kopie nie są niezależne ani odporne na skasowanie/kompromitację

**Dowód:** lokalna kopia leży na tej samej Oracle VM co baza, a druga jest wysyłana do R2 istniejącymi `CLOUDFLARE_*` credentials z `.env` (`stan-projektu.md:41`). Media również używają R2 (`architektura.md:46`; `docker-compose.yml:44-51`). Nie znaleziono dowodu osobnego konta/bucketu, minimalnego write-only principal, object lock/WORM, versioningu, MFA-delete, cross-provider copy ani aplikacyjnego szyfrowania dumpu.

**Wpływ:** awaria dysku kasuje bazę i lokalne kopie; wyciek/omyłka operatora/ransomware z prawami R2 może skasować media i zdalne dumpy razem. Gzip nie jest szyfrowaniem. Te same credentials zwiększają blast radius.

**Remediacja:** strategia 3-2-1: lokalna krótka kopia, wersjonowana/immutable kopia w oddzielnym bucketcie i niezależna kopia u drugiego dostawcy lub na osobnym koncie. Osobny principal backupowy: append/write bez delete/list tam, gdzie możliwe; osobny restore principal. Szyfrowanie po stronie klienta kluczem trzymanym poza VM, lifecycle i okres immutability zgodny z polityką.

**Test zamykający:** przejęty credential aplikacji nie może usunąć ani nadpisać backupu; usunięty live object i najnowszy dump dają się odzyskać z immutable/off-provider copy.

**Cross-reference:** ARCH-001; stan projektu punkt 15 (sekrety i backupy).

### DR-003 — P1 — media R2 nie mają udowodnionego backupu ani historii wersji

**Dowód:** R2 jest jedynym trwałym storage Active Storage. `stan-projektu.md:63-65` dokumentuje już nieodwracalną utratę blobów po fallbacku na lokalny, niewolumenowany storage. `roadmap.md:103-106` pozostawia bucket policy do sprawdzenia w konsoli. Repo nie dowodzi versioningu, object lock, inventory, replication ani okresowego eksportu originals.

**Wpływ:** skasowanie obiektu przez aplikację/operatora, kompromitacja klucza, błąd lifecycle lub utrata dostawcy usuwa zdjęcia wszystkich sklepów. Restore samej DB tworzy rekordy blobów wskazujące na nieistniejące obiekty.

**Remediacja:** włączyć i udokumentować wersjonowanie/retencję, o ile wspierane dla wybranego R2 setupu; niezależnie wykonywać inventory + checksum i kopię originals do innego security boundary. Warianty regenerować, ale originals chronić. Usuwanie mediów realizować przez tombstone + opóźniony purge, nie natychmiastowy hard delete.

**Test zamykający:** losowa próbka i kontrolowany obiekt zostają skasowane z live namespace, odzyskane wraz z content-type/checksumą, a storefront generuje wariant i zwraca 200. Reconciliation DB↔R2 nie zgłasza braków.

**Cross-reference:** INV-005; SYS-018; DB-008.

### DR-004 — P1 — utrata VM wymaga ręcznej rekonstrukcji nieobjętej kodem

**Dowód:** Compose wersjonuje kontenery i named volumes (`docker-compose.yml:1-105`), ale `.env`, backup/healthcheck/watchdog scripts i crony są tylko pod `/home/ubuntu`; certbot hooks i reguły firewalla także są ręczne. `deployment-oracle.md:138,203` mówi, że reguły 80/443 nie przetrwają rebootu. Workflow deployu tworzy tylko część `.env` i self-signed cert (`deploy-oracle.yml:83-94`), po czym oczekuje gotowej VM. Dokumentacja odnotowuje, że ręczna poprawka Compose była wcześniej cofana przez deploy (`stan-projektu.md:61`).

**Wpływ:** po utracie hosta operator musi pamiętać niedeklarowane kroki. Odtworzone kontenery mogą nie dostać R2/provisioning secrets, certyfikatu, cronów lub trwałego firewalla; nominalnie odtworzona aplikacja może tracić media albo nie wykonywać backupów.

**Remediacja:** Infrastructure as Code lub co najmniej idempotentny bootstrap nowej VM: sieć/firewall, Docker, użytkownicy/SSH, Compose, certbot, cron/systemd timers, monitoring, backup i restore. Wszystkie manualne elementy ujawnić w manifestach bez wartości sekretów. Budować z przypiętych artefaktów, nie z mutowalnych tagów i świeżego upstream clone.

**Test zamykający:** czysta VM bez ręcznych poprawek osiąga HTTPS health, Store/Admin API, Sidekiq, R2 upload i aktywny backup timer wyłącznie z repo + kontrolowanego secret restore; osiągnięty czas mieści się w RTO.

**Cross-reference:** ARCH-001, ARCH-005; SEC-004; DB-001.

### DR-005 — P1 — nie ma alertu, że backup przestał działać

**Dowód:** backup loguje do lokalnego `/home/ubuntu/backup-postgres.log`; nie znaleziono heartbeat/dead-man switch, metryki wieku ostatniej kopii, alertu rozmiaru/checksumy ani automatycznego test restore. Ogólny healthcheck również tylko zapisuje lokalny log, bo kanał SMTP nie działa (`stan-projektu.md:45`).

**Wpływ:** cron może przestać działać, dysk się zapełnić, token R2 wygasnąć albo dump mieć 0 bajtów, a operator dowie się dopiero podczas awarii. Lokalny log ginie razem z hostem.

**Remediacja:** zewnętrzny heartbeat po pełnym sukcesie oraz alert, gdy `now - completed_at` przekracza próg; metryki rozmiaru, czasu, checksumy, uploadu, liczby obiektów i ostatniego test restore. Alert kanałem niezależnym od Rails/Oracle/R2.

**Test zamykający:** kontrolowane wyłączenie crona i odmowa uploadu wywołują alert w ustalonym czasie; alarm jest widoczny poza Oracle.

**Cross-reference:** ARCH-001; stan projektu punkt 15 monitoring.

### DR-006 — P2 — brak PITR oraz zatwierdzonych RPO/RTO i scenariuszy ciągłości

**Dowód:** istnieje jeden dzienny logical dump, bez archiwizacji WAL, ciągłego backupu, repliki lub udokumentowanych celów. Nie ma planu per aktywo dla host loss, region/provider loss, operator error, ransomware i przerwania w trakcie płatności.

**Wpływ:** po awarii można utracić niemal dobę nowych kont, produktów, zamówień i statusów płatności. Przy realnej sprzedaży baza po restore może być starsza niż stan operatora płatności, co wymaga bezpiecznej reconciliation, nie ponownego capture.

**Remediacja:** zatwierdzić RPO/RTO per klasa danych; dla pieniędzy wdrożyć PostgreSQL base backup + WAL/PITR do niezależnego storage albo zarządzany PostgreSQL z PITR. Ustalić business continuity mode: checkout maintenance/read-only, kolejność przywracania i payment-provider reconciliation.

**Test zamykający:** odtworzenie do timestampu między dwoma kontrolowanymi zapisami zachowuje pierwszy i nie drugi; po restore reconciliation providerów wykrywa wszystkie transakcje nowsze niż punkt odzyskania bez podwójnego capture/refund.

**Cross-reference:** MONEY-001/003/004; DB-004.

### DR-007 — P2 — Redis/Sidekiq nie mają jawnej polityki backupu i utraty

**Dowód:** Redis ma tylko named volume (`docker-compose.yml:16-25,103-105`). Nie ma wersjonowanej konfiguracji AOF/RDB, kopii tego wolumenu, exportu queue state ani procedury po jego utracie. Redis zasila Sidekiq i inne nietrwałe mechanizmy; dokumentacja odnotowuje czyste zatrzymywanie kontenera przez nieznane źródło (`stan-projektu.md:36`).

**Wpływ:** utrata Redis może usunąć oczekujące provisioning jobs, webhook deliveries, retry i zaplanowane operacje. Sam DB record może pozostać w stanie `in_progress`, choć żaden job już nie istnieje. Cache można odbudować, ale kolejki i idempotency wymagają osobnej semantyki.

**Remediacja:** sklasyfikować każdy keyspace jako cache/odtwarzalny/durable; włączyć świadomą persistencję dla durable queues albo przenieść trwały intent do PostgreSQL/outbox. Dodać recovery sweeper, który rekoncyliuje rekordy `queued/in_progress` z realną kolejką i bezpiecznie wznawia idempotentne operacje.

**Test zamykający:** skasowanie izolowanego Redis podczas joba nie gubi intentu: po restarcie provisioning/webhook zostaje wznowiony dokładnie raz lub jawnie oznaczony do interwencji; cache odbudowuje się automatycznie.

**Cross-reference:** ARCH-003; DB-007; audyt 11 jobs/webhooks/e-mail.

### DR-008 — P2 — sekrety i zasoby GitHub/Vercel nie mają kompletnej ścieżki odzyskania

**Dowód:** sekrety leżą w plaintext `.env` z prawami 600 i u dostawców; brak secret managera (`stan-projektu.md:43-44`). Provisioning przechowuje w DB `repo_full_name`, `vercel_project_id` i deployment URL, a tokeny czyta z env (`spree/core/app/services/spree/provisioning/settings.rb:17-47`). Nie znaleziono inventory wszystkich repo/projektów/domen/env, escrow kluczowych sekretów, procedury rotacji po kompromitacji ani eksportu konfiguracji Vercel/Cloudflare/Oracle.

**Wpływ:** restore DB nie odtworzy tokenów, zmiennych Vercel, ustawień domen, bucket policy ani zasobów skasowanych u providera. Utrata konta GitHub/Vercel może dotknąć osobne storefronty klientów mimo działającego backendu.

**Remediacja:** centralny secret manager z break-glass access i audytem; inventory provider resources powiązane ze store ID; deklaratywna konfiguracja projektów/env bez zapisywania wartości w repo; okresowy export metadanych i cross-account mirror krytycznych repo. Po DR rotować credentiale przed wznowieniem write traffic.

**Test zamykający:** nowy operator z procedurą break-glass odtwarza secret references i jeden testowy storefront bez kopiowania sekretów z utraconej VM; reconciliation wskazuje orphan/missing GitHub/Vercel resources.

**Cross-reference:** ARCH-003; SEC-004; DB-007.

### DR-009 — P2 — brak spójnego punktu odzyskania DB ↔ R2 ↔ providerzy

**Dowód:** logical dump DB i obiekty R2 są chronione osobno, bez snapshot barrier/manifestu. Active Storage przechowuje metadata/key w DB, a bytes w R2. Provisioning zapisuje stan w DB po zewnętrznych wywołaniach GitHub/Vercel. Nie ma reconciliation uruchamianej po restore.

**Wpływ:** restore DB do T może wskazywać na obiekty utworzone/usunięte w innym czasie oraz na projekty providerów w innym stanie. Niewidoczne orphan objects zwiększają koszt; missing objects psują produkty; ponowienie provisioning może stworzyć kolizje lub duplikaty.

**Remediacja:** manifest backupu zawierający timestamp/LSN DB i R2 inventory version; po restore mandatory reconciliation: DB blobs↔R2 keys/checksums, store↔GitHub repo↔Vercel project/deployment/env, payment/order↔provider. Automatyczne działania domyślnie read-only; destructive cleanup dopiero po review.

**Test zamykający:** fixture z obiektem i projektem utworzonym/usuniętym po punkcie DB restore generuje poprawny raport missing/orphan/drift; system nie publikuje sklepu ani nie purge'uje danych przed decyzją operatora.

**Cross-reference:** ARCH-003; DB-003/007.

### DR-010 — P2 — backupy nie są objęte wykonywalną polityką retencji i usuwania danych

**Dowód:** lokalne dumpy są kasowane po 7 dniach, ale nie znaleziono retencji kopii R2, legal hold, klasyfikacji danych, DSAR/tombstones ani harmonogramu usuwania PII z backupów. Audyt DB stwierdził brak kompletnego lifecycle i procedury ponownego zastosowania tombstones po restore (`DB-008`).

**Wpływ:** kopie mogą znikać zbyt szybko dla recovery albo przechowywać dane osobowe bezterminowo. Restore starej kopii może ponownie wprowadzić dane wcześniej usunięte/zanonimizowane. Ręczne czyszczenie dumpów może z kolei naruszyć obowiązki księgowe lub dowodowe.

**Remediacja:** zatwierdzona z prawnikiem macierz retencji dla operational backups, records finansowych, danych klienta i mediów; immutable deletion ledger/tombstones odtwarzane po restore; legal hold jako jawny wyjątek; automatyczny lifecycle z raportem.

**Test zamykający:** restore kopii sprzed anonimizacji, następnie replay tombstones, usuwa/pseudonimizuje właściwe PII i zachowuje wymagane rekordy finansowe; lifecycle kasuje kopie zgodnie z polityką i pozostawia audyt.

**Cross-reference:** DB-008; SYS-015.

## Scenariusze katastrof

| Scenariusz | Obecna zdolność | Brakujący element |
|---|---|---|
| awaria/reboot VM | restart policy/watchdog; dane w named volumes | trwały firewall, alert, test reboot, off-host restore |
| utrata dysku/całej VM | dzienny dump w R2 + kod GitHub | IaC, sekrety, restore drill, PITR, Redis |
| błąd operatora w DB | najnowszy dzienny dump | PITR i procedura bez nadpisania dowodów |
| skasowanie mediów | brak potwierdzonej historii | versioning/immutable/off-provider copy |
| kompromitacja/ransomware | prawa plików 600 | izolowane credentials, immutable copy, rotacja |
| utrata regionu/konta Oracle | ręczna budowa innej VM | provider-neutral bootstrap i RTO drill |
| utrata Cloudflare/R2 | brak dowodu kopii poza R2 | drugi provider/account dla DB i originals |
| utrata GitHub/Vercel | lokalne checkouty mogą być przypadkową kopią | inventory, mirror/export, odtworzenie env/domains |
| DB starsza niż Stripe/provider | brak aktywnej produkcyjnej metody, brak procedury | payment reconciliation przed write traffic |

## Minimalny restore drill zamykający audyt

Drill ma być wykonany na izolowanym środowisku, bez zmiany produkcyjnych DNS, bucketu ani danych:

1. **Zamrozić dowód:** wybrać konkretny dump, zapisać checksumę, timestamp, commit/image i deklarowane RPO; nie modyfikować źródła.
2. **Czysta infrastruktura:** utworzyć nowy PostgreSQL tej samej major version i pusty Redis; docelowo również czystą VM z bootstrapem.
3. **Restore DB:** zweryfikować gzip/checksum, odtworzyć role i bazę, zapisać wszystkie warnings/errors; nie ignorować błędów owner/extension.
4. **Schema gate:** porównać tabele, migracje, indexes/constraints; uruchomić post-condition z audytu 09 i dopiero potem aplikację na dokładnym commicie przypisanym do backupu.
5. **Dane i tenanty:** policzyć stores/users/products/orders/payments/Active Storage blobs/provisioning runs per tenant; sprawdzić brak orphan/cross-tenant rows.
6. **Media:** wykonać read-only inventory DB↔R2, checksum próbki originals, wygenerować wariant w osobnym namespace; nie pisać do produkcyjnych keys.
7. **Funkcje:** login ownera, Store/Admin API, katalog dwóch tenantów, koszyk testowy bez realnego capture, Sidekiq test job, webhook do kontrolowanego endpointu.
8. **Provider reconciliation:** read-only porównać store↔repo↔Vercel project/deployment i payment/order↔provider; żadne retry nie może tworzyć zasobów ani pobierać pieniędzy.
9. **Failure drill:** zasymulować brak R2 credential, utratę Redis i nowszy external provider state; potwierdzić bezpieczne fail-closed oraz raport driftu.
10. **Raport:** rzeczywiste RPO/RTO, czasy etapów, błędy, liczby rekordów, zakres utraconych danych, decyzja pass/fail i właściciel napraw. Po drill usunąć izolowane dane zgodnie z polityką.

**Warunek PASS:** odtworzony system przechodzi schema/tenant/money invariants, referencje mediów są kompletne, provider drift jest wykryty bez skutków ubocznych, a zmierzone RPO/RTO mieszczą się w zatwierdzonych celach. Sam fakt, że Rails się uruchomił, nie jest wynikiem PASS.

## Zalecana kolejność wdrożenia

1. Wersjonowany skrypt backup/restore, manifest, checksumy i działający zewnętrzny alert.
2. Izolowany pełny restore najnowszego dumpu; naprawić wszystko, co ujawni, i powtarzać cyklicznie.
3. Niezależna immutable/off-provider kopia DB oraz originals R2; osobne credentials.
4. Zatwierdzić RPO/RTO i uruchomić PITR/WAL dla danych zamówień/płatności.
5. Idempotentny bootstrap/IaC nowej VM z secrets recovery i wszystkimi timerami/monitoringiem.
6. DB↔R2↔GitHub↔Vercel↔payment reconciliation oraz recovery kolejki Redis/Sidekiq.
7. Retention/DSAR/tombstone replay i kwartalny DR drill; po istotnej zmianie storage/migracji dodatkowy drill.

## Potwierdzone mocne strony

- Dump jest off-process i ma drugą kopię poza Oracle VM.
- Uprawnienia `.env`, katalogu backupów i dumpów zostały ograniczone do operatora (`600`/`700`).
- Runbook deployu wymaga backupu przed migracją.
- Kod aplikacji i konfiguracja Compose/Nginx są wersjonowane w Git.
- Postgres i Redis nie są publicznie wystawione; R2 jest już zewnętrznym storage względem VM.
- Dokumentacja uczciwie nie nazywa uploadu dumpu potwierdzonym restore'em.

## Pokrycie i ograniczenia

Sprawdzono dokumenty kanoniczne, raporty 01–09, `docker-compose.yml`, Dockerfile, Oracle deploy workflow/runbook, konfigurację Active Storage widoczną w repo, provisioning GitHub/Vercel, modele/migracje jego metadata oraz wzmianki o backup/restore/retention w obu repo.

Nie wykonano i dlatego **nie potwierdzono**:

- połączenia z Oracle, odczytu crontaba/skryptu/logów ani pobrania dumpu;
- integralności pełnego dumpu, restore PostgreSQL, startu aplikacji na restored DB;
- konfiguracji R2 versioning/lifecycle/object lock/encryption/IAM;
- Oracle boot-volume backups, snapshots, availability domain lub recovery innego regionu;
- inventory i recovery Vercel/GitHub/Cloudflare secrets, domains i projects;
- działania backup alertów (dokumentacja mówi, że ogólny kanał alertowy nie działa);
- prawnie wymaganych okresów retencji — wymaga to decyzji prawnej i biznesowej;
- realnego payment-provider reconciliation, bo produkcyjna metoda nie jest jeszcze skonfigurowana.

Brak dostępu do konsol nie został zastąpiony założeniem. Każda funkcja providera niewidoczna w repo ma status **UNVERIFIED**, nie „włączona”.

## Kryterium zamknięcia całego audytu 10

Audyt jest zamknięty dopiero, gdy cykliczny, monitorowany proces tworzy szyfrowane i niezależne kopie PostgreSQL oraz originals, co najmniej jedna kopia jest odporna na skasowanie przez credential aplikacji, a pełny restore na czystej infrastrukturze przechodzi testy schema/tenant/money/media/provider reconciliation w zatwierdzonym RPO/RTO. Wynik i data ostatniego drill są widoczne operacyjnie, a nie tylko w lokalnym logu utraconego hosta.
