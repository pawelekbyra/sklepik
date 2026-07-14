# Audyt 12: infrastruktura i deployment

**Data:** 2026-07-14
**Zakres wersji:** backend/control plane `9a4f69314735`, storefront `0f83b941f345`
**Zakres:** Oracle Cloud VPS, Docker Compose, Nginx/TLS, PostgreSQL, Redis, Sidekiq, Cloudflare R2, GitHub Actions, Vercel panel/storefront oraz provisioning GitHub→Vercel.
**Metoda:** statyczny audyt obu repozytoriów, workflowów, obrazów, konfiguracji i runbooków; cross-reference audytów 01–09. Bez połączenia SSH, zmian zewnętrznych, deploymentu i odczytu sekretów. Stan Oracle/Vercel/R2 opisany wyłącznie w dokumentacji oznaczam jako **niezweryfikowany runtime**.

## Werdykt

Obecny stack wystarcza do pilota i ręcznie nadzorowanych wdrożeń, ale **nie jest jeszcze bezpieczną, powtarzalną platformą produkcyjną dla wielu sklepów**. Najpoważniejszy problem nie polega na samym użyciu jednej VM, lecz na tym, że push do `main` może rozpocząć deployment równolegle z testami, a workflow jawnie ignoruje błąd budowy obrazu. Produkcja następnie buduje inny obraz bezpośrednio z mutowalnego upstreamu, odtwarza kontenery przed migracją i nie ma automatycznego rollbacku. Zielony status deployu nie dowodzi więc, że przetestowany artefakt został bezpiecznie promowany.

Dokumentacja potwierdza działające HTTPS, niewystawione porty Postgresa/Redisa, backup lokalny+R2 i okresowy healthcheck. To dobre minimum. Nie ma jednak zweryfikowanego restore, realnych alertów, trwałej konfiguracji firewalla, IaC/drift detection, limitów zasobów, obrazu podpisanego/SBOM ani kontrolowanej aktualizacji floty storefrontów. GitHub i Vercel provisioning korzysta z długowiecznych tokenów o szerokim zasięgu, nie jest wznawialny i nie zapisuje wersji template/release.

### Podsumowanie priorytetów

| Priorytet | Liczba | Znaczenie |
|---|---:|---|
| P0 | 2 | produkcja może dostać nieprzetestowany lub niejednoznaczny artefakt |
| P1 | 6 | release/rollback, sekrety, monitoring i pojedynczy failure domain nie spełniają bezpiecznego minimum |
| P2 | 7 | health, capacity, TLS, Vercel fleet, supply chain i drift wymagają utwardzenia przed skalą |
| P3 | 1 | dokumentacja i równoległe konfiguracje utrudniają operacje |

## Mapa zweryfikowanego stacku

| Warstwa | Fakt z repo | Stan runtime |
|---|---|---|
| Oracle VM | Ubuntu 22.04, E4 Flex 1 OCPU/8 GB, public subnet; wszystkie główne usługi na jednej VM (`docs/architektura.md`, `docs/deployment-oracle.md`) | nie odczytano konsoli Oracle ani hosta |
| Rails/Sidekiq | dwa obrazy budowane z root `Dockerfile`; restart `unless-stopped` | nie odczytano procesów/logów |
| PostgreSQL | `postgres:15-alpine`, named volume, aplikacja łączy się jako `postgres` | dokumentacja mówi o backupie; brak katalogów DB/restore testu |
| Redis | `redis:7-alpine`, named volume, bez hasła w prywatnej sieci Compose | nie odczytano persistence/config/runtime |
| Nginx/TLS | `nginx:alpine`, 80/443, TLS 1.2/1.3, HSTS; cert kopiowany z hosta | dokumentacja deklaruje LE ważny do 2026-10-07 |
| R2 | sekrety przekazywane do web i sidekiq; media oraz backupy mają używać R2 | nie zweryfikowano bucket policy, versioning, lifecycle, restore ani kluczy |
| Admin Vercel | SPA ma proxy `/api` i `/rails` do hardcodowanego `nip.io` | nie odczytano ustawień projektu/domen/logów |
| Storefront Vercel | repo ma CI oraz dokumentowane env; provisioning ustawia tylko trzy env | nie odczytano projektów, env ani deployment protection |
| GitHub Actions | deploy, testy, packages, release, security audit | statycznie zweryfikowane; nie odczytano branch protection/environments |

## Ustalenia

### INFRA-001 — P0 — deployment produkcyjny nie czeka na testy i ignoruje błąd budowy obrazu

**Fakt.** `deploy-oracle.yml` uruchamia się bezpośrednio po każdym pushu do `main` (`:3-8`). Build obrazu ma `continue-on-error: true` (`:32-43`), po czym job `deploy` wymaga jedynie zakończenia tego build joba (`:49-52`). Pełne testy backendu są osobnym workflowem i uruchamiają się również po pushu; deployment nie ma od nich zależności. Ponadto workflow testów wykonuje właściwe RSpec tylko dla `push`, nie dla PR (`tests.yml:112-117`).

**Wpływ.** Kod może wejść na produkcję zanim testy wykryją regresję. Nieudany obraz w GHCR nie blokuje deployu; komentarz nazywa go fail-fast gate’em, choć konfiguracja robi z niego fail-open. Status „Deploy successful” nie jest dowodem przejścia testów ani poprawnego obrazu.

**Rekomendacja.** Jeden wymagany pipeline: PR gates → merge queue/chroniony `main` → build immutable image → test obrazu → push digest → approval environment → deploy dokładnie tego digestu. Usunąć `continue-on-error`; testy backendu wykonywać na PR i wymagać ich w branch protection. Dodać `concurrency` dla produkcji bez równoległych deployów.

**Test zamykający.** Celowo zepsuty test i celowo zepsuty Docker build nie tworzą deploymentu; dwa szybkie pushe promują wyłącznie nowszy, w pełni zielony digest; log produkcji zapisuje commit i digest identyczne z artefaktem CI.

### INFRA-002 — P0 — produkcyjny artefakt jest niepowtarzalny i zależy od mutowalnego upstreamu

**Fakt.** Root `Dockerfile` klonuje `https://github.com/spree/spree-starter.git` bez SHA/tagu (`Dockerfile:19-21`) i wykonuje `bundle install` przeciw świeżo pobranemu starterowi (`:23-31`). Compose używa tego pliku (`docker-compose.yml:27-30`, `:60-64`). Obrazy bazowe `ruby:3.4.4-slim`, `postgres:15-alpine`, `redis:7-alpine`, `nginx:alpine` nie są przypięte digestem. CI buduje natomiast `server/Dockerfile` (`deploy-oracle.yml:32-38`), podczas gdy host buduje obrazy ponownie z Compose (`:96-102`); nie promuje obrazu CI. Host robi też `git reset --hard origin/main`, zamiast checkoutu SHA wyzwalającego workflow (`:78-81`).

**Wpływ.** Ten sam commit może dać inny kod host-app, zależności systemowe i obrazy w różnym czasie. Artefakt testowany/buildowany w CI nie jest artefaktem uruchomionym. Rollback Git może nadal zbudować nowy, niezgodny upstream. Migracje host-app nie są trwałym elementem obrazu, co audyt 09 sklasyfikował jako DB-001 P0.

**Rekomendacja.** Wersjonować host-app albo przypiąć starter do zweryfikowanego commit SHA; wszystkie obrazy bazowe pinować digestem i odnawiać botem. Budować raz w CI, generować provenance/SBOM, podpisywać, a host ma pullować digest. Wersjonować manifest: git SHA, image digest, starter SHA, migration checksum, schema version.

**Test zamykający.** Dwa clean buildy tego samego commitu mają ten sam manifest i funkcjonalnie identyczny SBOM; produkcja raportuje dokładnie digest z CI; build bez sieci po pobraniu zatwierdzonych artefaktów nie zależy od HEAD upstreamu.

**Duplikaty:** ARCH-005/006, DB-001/006, SEC-004, SPREE-005.

### INFRA-003 — P1 — release odtwarza aplikację przed migracją i nie ma bezpiecznego rollbacku

**Fakt.** Workflow najpierw `--force-recreate` web/sidekiq/nginx (`deploy-oracle.yml:99-103`), a dopiero potem kopiuje i uruchamia migracje (`:115-118`). „Gotowość” przed migracją sprawdza jedynie `puma -v`, nie request ani zależności (`:104-113`); pętla nie kończy joba błędem, gdy 30 prób minie. Assety są kompilowane już na działającym kontenerze (`:120-124`). Końcowy check omija publiczny Nginx/TLS i odpytuje `http://localhost:3000/up` (`:126-128`). Nie ma zachowania poprzedniego obrazu, automatycznego rollbacku, canary/blue-green, sprawdzenia Sidekiq ani post-condition dla wszystkich backfilli. Runbook ręczny z 2026-07-14 ma inną kolejność i jawny restart Nginx, więc istnieją co najmniej dwie procedury.

**Wpływ.** Błąd migracji następuje po wyłączeniu starej aplikacji. Częściowy DDL nie cofa się wraz z kodem; stary obraz nie jest gotowy do natychmiastowego przywrócenia. Deploy może uznać proces za gotowy, mimo że API, DB, Redis, Sidekiq lub TLS nie działają prawidłowo.

**Rekomendacja.** Release command na immutable obrazie: backup/restore point → migracje kompatybilne N/N+1 pod advisory lock → post-conditions → uruchomienie nowego stacku → readiness przez publiczny HTTPS → przełączenie ruchu → drain starego. Zdefiniować osobno rollback kodu, forward-fix schematu i restore danych. Jeden wykonywalny runbook ma być źródłem prawdy.

**Test zamykający.** Wymuszony błąd builda, migracji, startu Puma, Sidekiq i HTTPS pozostawia poprzednią wersję obsługującą ruch; ćwiczenie rollbacku mierzy MTTR i potwierdza zgodność schematu; synthetic checkout nie ma błędów w czasie release'u.

**Duplikaty:** DB-001/002/005, ARCH-006.

### INFRA-004 — P1 — stan hosta i sieci nie jest odtwarzalny; firewall znika po restarcie

**Fakt.** `docs/deployment-oracle.md` jawnie mówi, że reguły `iptables` dla 80/443 nie są trwałe i po reboocie trzeba je odtworzyć ręcznie. Certbot, hooki renewal, skrypty backup/healthcheck, cron, uprawnienia plików, Docker i system packages istnieją wyłącznie na hoście; repo nie zawiera Ansible/Terraform/cloud-init ani testu driftu. VCN/subnet/NSG są opisane prozą, nie deklaracją.

**Wpływ.** Reboot, odtworzenie VM albo ręczna zmiana może wyłączyć HTTPS, zmienić exposure portów lub utracić backup/monitoring. Nie istnieje pewna droga od pustej VM do równoważnej produkcji ani kontrola różnicy między dokumentacją a hostem.

**Rekomendacja.** Minimalny IaC: Terraform/OpenTofu dla Oracle network/VM/NSG i storage policy; Ansible/cloud-init dla Docker, trwałego firewalla, użytkowników, fail2ban/SSH, certbot, cron/systemd, logrotate i katalogów. Codzienny read-only drift check i okresowy rebuild staging z zera.

**Test zamykający.** Reboot zachowuje wyłącznie 22/80/443 zgodnie z polityką; świeża VM z IaC przechodzi pełny smoke; ręczna zmiana reguły lub crona jest wykryta; odtworzenie hosta nie wymaga wiedzy spoza repo/secrets managera.

**Duplikat:** ARCH-007.

### INFRA-005 — P1 — monitoring istnieje tylko jako lokalny log, bez skutecznego alertowania i SLO

**Fakt.** `docs/stan-projektu.md` opisuje cron co 5 minut sprawdzający pięć kontenerów, `/up` i dysk, ale wysyłka e-mail nie działa, bo SMTP jest placeholderem. Repo nie zawiera konfiguracji zewnętrznego uptime checku, metryk Puma/Sidekiq/Postgres/Redis, agregacji logów, tracingu, dashboardów, alert routing/on-call ani SLO. Akcja „Notify Slack” jedynie wypisuje tekst do logu (`deploy-oracle.yml:133-140`). `Rails.error.report` w provisioningu nie dowodzi skonfigurowanego odbiornika.

**Wpływ.** Awaria może trwać do ręcznego zajrzenia w log. Brak alertów o kolejce, błędach płatności/webhooków, backup age, cert expiry, dysku, OOM, DB connections i p95 powoduje, że degradacja wszystkich tenantów jest niewidoczna.

**Rekomendacja.** Najpierw zewnętrzny synthetic HTTPS + działający kanał alertu; potem centralne error/log/metric collection, metryki RED/USE, Sidekiq queue age/retries/dead, backup freshness, cert/disk/memory/DB. Ustalić SLO checkout/API/provisioning i ownera reakcji. Alert musi wychodzić poza host, którego dotyczy.

**Test zamykający.** Zatrzymanie web, Sidekiq, Postgresa, zapełnienie testowego progu dysku, przeterminowany heartbeat backupu i cert <14 dni generują deduplikowane alerty do człowieka z runbookiem; kwartalny game day mierzy detection/ack/restore.

### INFRA-006 — P1 — jedna VM jest wspólnym failure domain bez potwierdzonego DR

**Fakt.** Rails, Sidekiq, PostgreSQL, Redis i Nginx działają na jednej publicznej VM i lokalnych named volumes (`docker-compose.yml`). Nie ma repliki DB, failover hosta, PITR ani warm standby. Dokumentacja deklaruje codzienny `pg_dumpall` lokalnie i do R2, ale restore nie został przetestowany. Nie zweryfikowano R2 versioning/object lock/lifecycle ani odrębnych credentiali backupu. Brak zmierzonego RPO/RTO.

**Wpływ.** Awaria hosta, volume, konta Oracle, regionu albo błąd operatora zatrzymuje wszystkie sklepy. Backup logiczny może być nieodtwarzalny lub za stary; wspólny credential R2 zwiększa ryzyko skasowania danych i kopii jednym incydentem.

**Rekomendacja.** Przed realnymi płatnościami: automatyczny encrypted backup z niezależnym, append-only/ograniczonym credentialem, retention, restore drill i pomiar RPO/RTO. Następnie rozdzielić managed Postgres/PITR lub co najmniej DB na oddzielny failure domain; decyzję o HA podejmować z SLO i przychodem, nie od razu budować klaster.

**Test zamykający.** Odtworzenie na czystej infrastrukturze z R2 obejmuje DB, media references i sekrety/config; integrity/tenant/order checks są zielone; udokumentowane RPO/RTO mieszczą się w zaakceptowanym celu; utrata VM nie wymaga dostępu do jej dysku.

**Duplikaty:** ARCH-001/002, DB-006; cross-reference audyt 10 po publikacji.

### INFRA-007 — P1 — procesy i tokeny mają zbyt szerokie uprawnienia oraz brak lifecycle rotacji

**Fakt.** Aplikacja łączy się do DB jako superuser `postgres` (`docker-compose.yml:3-6`, `:40`, `:74`). Redis nie ma auth, co jest akceptowalne tylko przy nienaruszonej prywatnej sieci kontenerowej. Zarówno web, jak i sidekiq dostają klucze R2/AWS, GitHub provisioning PAT i pełny Vercel token (`:36-55`, `:70-88`), mimo że provisioning wykonuje job. `GithubClient` dokumentuje wymaganie classic PAT `repo` (`github_client.rb:14-18`), choć kanon wymaga GitHub App. Tokeny są długowieczne; repo nie zawiera harmonogramu rotacji, revocation drill, scope inventory ani automatycznych krótkotrwałych credentials. SSH deploy secret daje dostęp użytkownikowi `ubuntu`, który zarządza całym stackiem.

**Wpływ.** RCE w webie lub wyciek jednego enva może dać możliwość tworzenia prywatnych repo, projektów Vercel, odczytu/zapisu mediów i administracji DB wszystkich tenantów. Rotacja jest ręczna i może przerwać provisioning/deploy.

**Rekomendacja.** Osobny DB role dla aplikacji i migratora; osobne Redis ACL jeśli sieć przestanie być jedyną granicą. Web bez tokenów provisioningowych, worker z GitHub App installation tokenem TTL i Vercel credentialem o najmniejszym możliwym scope/team. Oddzielić R2 media read/write od append-only backup writera. Secrets manager/OIDC tam, gdzie provider pozwala; kwartalna rotacja i emergency revoke runbook. Deploy przez ograniczonego użytkownika/command albo pull-based agent.

**Test zamykający.** Dump env weba nie zawiera GitHub/Vercel ani backup-delete credentials; app DB role nie może tworzyć/dropować schematu; skradziony/revokowany token wygasa bez wpływu na commerce; automatyczny provisioning po rotacji przechodzi canary.

### INFRA-008 — P1 — Store Factory tworzy zasoby bez trwałej orkiestracji, kompensacji i fleet control

**Fakt.** Provisioning wykonuje blokujący, sekwencyjny job i jawnie nie jest resumable (`provision_store.rb:12-18`). Po częściowym sukcesie nie usuwa repo/projektu/env; retry tworzy nowy run. Polling repo po 20 sekundach kończy się bez sprawdzenia warunku i przechodzi dalej (`:55-63`). Vercel project/env linkage nie jest w pełni zweryfikowany live (`vercel_client.rb:8-16`). W bazie nie ma wymuszonej unikalności kroku (DB-007). Model nie zapisuje template commit SHA, active release SHA, contract version, GitHub/Vercel resource IDs potrzebnych do reconciliation ani update channel. Template jest pełną kopią `sklepikFront`, a nie wersjonowanym cienkim starterem.

**Wpływ.** Awaria GitHub/Vercel lub crash workera zostawia osierocone repo/projekty/sekrety i niejednoznaczny stan klienta. Nie ma pewnej metody masowej poprawki bezpieczeństwa, porównania wersji, canary/rollback ani wykrycia ręcznego driftu dziesiątek storefrontów.

**Rekomendacja.** Trwała state machine z idempotency key per provider operation, retries/backoff, compensation i reconciliation. `StoreApplication`/manifest ma zapisywać template SHA, release/contract version, repo/project/deployment IDs i last verified status. GitHub App, Vercel project policy, branch protection oraz update bot z cohort/canary. Draft nie powinien bez limitu tworzyć kosztownych zasobów.

**Test zamykający.** Chaos test przerywa każdy krok przed/po odpowiedzi providera; retry kończy się dokładnie jednym repo/projektem/env/deploymentem albo pełną kompensacją. Fleet inventory wykrywa drift i potrafi wdrożyć security update canary→cohort→rollback.

**Duplikaty:** ARCH-003/004, DB-007.

### INFRA-009 — P2 — readiness i health nie obejmują zależności ani publicznej ścieżki

**Fakt.** Compose ma healthcheck wyłącznie dla Postgresa i Redisa (`docker-compose.yml:9-13`, `:20-24`); web, sidekiq i Nginx go nie mają. Nginx `/up` tylko proxy do Rails (`nginx.conf:83-91`). Deploy sprawdza `puma -v`, potem bezpośredni port 3000, a nie DNS→TLS→Nginx→Rails. Nie ma oddzielnych liveness/readiness/startup probes ani checku DB/Redis/queue/R2. `depends_on` nie chroni przed późniejszą degradacją.

**Wpływ.** Proces może być „healthy”, choć nie obsługuje requestów lub nie ma DB/Redis. Sidekiq może nie konsumować kolejki, a provisioning/mail/webhook backlog rośnie bez sygnału.

**Rekomendacja.** Tani liveness bez zależności; readiness z DB/cache i stanem migracji; worker heartbeat/queue age; publiczny synthetic po HTTPS. Docker healthchecks i deploy gate powinny korzystać z tych samych semantyk, bez kosztownych provider calls w każdym request.

**Test zamykający.** Odcięcie każdej zależności daje oczekiwany stan liveness/readiness; deployment nie promuje niedostępnego Nginx/TLS; zatrzymany worker jest wykrywany mimo działającego weba.

### INFRA-010 — P2 — brak limitów zasobów, log rotation i capacity modelu dla wspólnej VM

**Fakt.** Compose nie definiuje CPU/memory/PID limits, reservations, ulimitów ani rotacji log drivera. Sidekiq ma domyślnie concurrency 5 na 1 OCPU (`docker-compose.yml:64`); Puma pochodzi z mutowalnego startera. Nginx dopuszcza body 100 MB (`nginx.conf:25`), a audyt SEC-003/007 wskazuje nieograniczone operacje w pamięci. Brak connection pool budgetu, load testu wielu tenantów, disk forecast i autoscaling triggerów.

**Wpływ.** Import/upload, build lub ciężki job może zagłodzić checkout, DB albo hosta i wywołać OOM/disk full. Jeden noisy tenant wpływa na wszystkich. Docker logs i obrazy mogą zapełnić root volume.

**Rekomendacja.** Zmierzyć baseline i ustawić budgets: web/worker memory, Sidekiq queues/concurrency, Puma threads/workers, DB/Redis max memory/connections, upload limits i log rotation. Osobne kolejki/limity dla provisioningu/importów/maili. Alerty oraz runbook zwiększenia shape/oddzielenia workera/DB.

**Test zamykający.** Load test katalog+cart+checkout równolegle z uploadem/provisioningiem nie przekracza SLO; celowy memory/CPU spike jest ograniczony do usługi; 30 dni modelowanego log growth nie zapełnia dysku.

### INFRA-011 — P2 — Vercel konfiguracja i domeny są hardcodowane, niekompletne i nieaudytowalne jako flota

**Fakt.** Panel proxy hardcoduje `https://141-253-103-172.nip.io` w `packages/dashboard/vercel.json:4-7`. Provisioning ustawia wyłącznie `SPREE_API_URL`, `SPREE_PUBLISHABLE_KEY` i `NEXT_PUBLIC_STORE_NAME` (`provision_store.rb:86-93`). Nie ustawia `NEXT_PUBLIC_SITE_URL`, locale/country, webhook secret, Resend, trwałej idempotencji ani Sentry opisanych w `sklepikFront/docs/deployment-vercel.md`. URL deploymentu z Vercela jest zapisywany jako host sklepu, lecz nie ma domain binding workflow. Repo nie zawiera polityki preview/prod env, deployment protection, spend limits, WAF ani centralnego inventory Vercel config.

**Wpływ.** Nowy storefront może być technicznie READY, ale mieć błędne canonical/sitemap, nie wysyłać maili, nie invalidować cache, nie mieć obserwowalności i nie posiadać docelowej domeny. Zmiana backendu wymaga zmian kodu i fan-out deployów.

**Rekomendacja.** Wersjonowany manifest wymaganych env z walidacją pre-deploy/post-deploy; backend base URL w platform config, nie w kodzie dashboardu. DomainBinding state machine z DNS verification, cert i canonical. Fleet policy sprawdza config drift, plan/cost/WAF/analytics/monitoring i template compatibility bez odczytywania wartości sekretów.

**Test zamykający.** Nowy sklep przechodzi `doctor`: poprawne canonical/sitemap, tenant API, webhook signature/idempotency, e-mail canary, Sentry canary i domena/cert; rotacja backend URL/sekretu wykonuje canary i bezpieczny fan-out.

**Duplikat:** ARCH-008/011/014.

### INFRA-012 — P2 — supply chain jest częściowo utwardzony, ale produkcyjny obraz nie ma SBOM, skanu ani podpisu

**Fakt.** Mocną stroną jest przypięcie SHA akcji w storefront CI i security workflow oraz ustawienia pnpm `minimumReleaseAge`, `blockExoticSubdeps`, `trustPolicy` i allowlist build scripts. Jednak większość akcji backendu nadal używa mutowalnych tagów (`actions/checkout@v4`, `docker/*@v3/v5`, `ruby/setup-ruby@v1`), obrazy/apt/upstream są mutowalne, a deploy nie generuje SBOM, provenance, podpisu Cosign ani skanu obrazu/IaC/secrets. `pnpm audit` używa `|| true`, a Dependabot obejmuje tylko `spree/core` Bundler, nie wszystkie Gemfile'y. Release gems używa `rubygems/configure-rubygems-credentials@main`.

**Wpływ.** Kompromitacja upstream action/image/package lub znana podatność może wejść do produkcji bez blokady i bez szybkiej odpowiedzi „gdzie ten komponent działa”.

**Rekomendacja.** Pin actions i images SHA/digestem; CodeQL/Brakeman/Bundler Audit dla aktywnej powierzchni, container scan z polityką severity/exploitability, secret scan, SBOM CycloneDX/SPDX, SLSA provenance i keyless signing. Automatyczna aktualizacja ma otwierać PR i przechodzić pełne CI, a wyjątki mieć owner/expiry.

**Test zamykający.** Artefakt bez podpisu/provenance lub z blokującą CVE nie może być promowany; każdy produkcyjny digest ma queryable SBOM; symulowana podatność wskazuje wszystkie backend/storefront deploymenty i generuje update cohort.

**Duplikat:** SEC-004/008.

### INFRA-013 — P2 — TLS zależy od zewnętrznego wildcard DNS, a renewal powoduje planowaną przerwę

**Fakt.** Backend używa `141-253-103-172.nip.io`; Nginx ma ten host na stałe (`nginx.conf:55`). Certbot standalone zatrzymuje i uruchamia Nginx, żeby zwolnić port 80 (`docs/deployment-oracle.md`, `nginx.conf:42-45`). Nie ma repozytoryjnego alertu certificate expiry ani testu renewal. Nginx ustawia TLS 1.2/1.3 i HSTS, co jest mocną stroną, ale nadal ma deprecated `X-XSS-Protection`; nie ma OCSP/security policy testu.

**Wpływ.** Awaria nip.io, renewal hooka albo reguł firewalla może odciąć API wszystkim sklepom. Renewal celowo przerywa reverse proxy, a nieudany post-hook może wydłużyć outage.

**Rekomendacja.** Własna domena API i automatyczny DNS; ACME webroot/DNS challenge lub proxy nie wymagające stopu; zewnętrzny expiry/DNS/TLS monitor. Wersjonowany test TLS i rotacji certyfikatu, a docelowo load balancer/proxy z managed cert, jeśli uzasadni to SLO.

**Test zamykający.** Staging renewal pod ruchem nie powoduje błędów; alert działa przed 30/14/7 dni; utrata nip.io nie dotyczy własnej domeny; restart hosta zachowuje ACME i HTTPS.

### INFRA-014 — P2 — logi i zdarzenia operacyjne nie tworzą spójnego, bezpiecznego śladu

**Fakt.** Nginx loguje lokalnie standardowy access log (`nginx.conf:14-18`), Docker używa domyślnego drivera, health/backup mają osobne pliki hosta. Brak centralnego correlation/request ID obejmującego Vercel→Nginx→Rails→Sidekiq→GitHub/Vercel provider, tenant/store ID, deployment SHA i retry. Provisioning zapisuje pełne komunikaty odpowiedzi providerów w błędzie (`github_client.rb:68-69`, `vercel_client.rb:76-78`) i następnie `error.message` w DB (`provision_store.rb:73-76`); nie ma jawnej redakcji/retencji. Nie znaleziono audit logu zmian infrastruktury i sekretów.

**Wpływ.** Dochodzenie incydentu i rozliczenie kosztu/błędu per tenant jest ręczne. Provider response może zawierać dane nieprzeznaczone do panelu lub długiej retencji. Logi mogą zniknąć razem z VM albo zapełnić dysk.

**Rekomendacja.** Strukturalne logi z request/job/provisioning/deployment/store IDs, centralny immutable sink, redaction allowlist, retention per klasa i role-based access. Audit provider actions ma zapisywać typ operacji, resource ID, actor, outcome i idempotency key — nigdy token/value sekretu.

**Test zamykający.** Jedno E2E provisioning i checkout da się prześledzić po correlation ID przez wszystkie warstwy; skaner potwierdza brak tokenów/PII; utrata VM nie usuwa wymaganych logów; retention usuwa je zgodnie z polityką.

### INFRA-015 — P2 — R2 nie ma repozytoryjnie weryfikowalnej polityki bezpieczeństwa i lifecycle

**Fakt.** Kod/Compose przekazuje dwa zestawy nazw credentiali AWS/Cloudflare do web i sidekiq, a dokumentacja opisuje bucket mediów oraz backupy w R2. Nie ma IaC ani eksportu policy pokazującego public/private access, CORS, encryption, versioning, lifecycle, object lock, quota, access logs, osobne buckety/klucze czy region/data residency. `CDN_HOST` obecnie wskazuje backend, nie jawny dedykowany CDN. Stan live nie został odczytany.

**Wpływ.** Nie da się dowieść, że media jednego sklepu i backup całej bazy mają odpowiednią separację, retencję i ochronę przed usunięciem. Szeroki wspólny klucz może połączyć kompromitację aplikacji z utratą backupów.

**Rekomendacja.** Oddzielne buckety/prefix policies i credentials dla publicznych mediów, private originals/digital files i append-only backupów; encryption/versioning/lifecycle/object lock według klasy; inventory/access logs i IaC. Tenant prefix ownership oraz purge/DSAR muszą być jawne.

**Test zamykający.** Credential web nie czyta backupów ani cudzych private originals i nie usuwa backupu; publiczny dostęp obejmuje tylko zamierzone obiekty; lifecycle/versioning/restore oraz tenant-prefix negative tests są automatyczne.

**Cross-reference:** TENANT-005, DB-008.

### INFRA-016 — P3 — aktywne i legacy ścieżki deploymentu tworzą drift dokumentacji i narzędzi

**Fakt.** Repo zachowuje Render scripts/config/docs, dwa różne Dockerfile'e, workflow budujący `server/Dockerfile`, Compose budujący root `Dockerfile` i dokumentację, która miejscami nadal mówi o Renderze lub self-signed cert. Ruby różni się między root obrazem 3.4.4, `server/Dockerfile` 4.0.1 i testami 4.0. Ręczny runbook używa `docker compose`, workflow `docker-compose`. `ARCH-012/015` wykazały ten sam drift.

**Wpływ.** Operator lub agent może uruchomić zły build/release, naprawić nieaktywną ścieżkę albo fałszywie uznać konfigurację za zweryfikowaną.

**Rekomendacja.** Jedna aktywna ścieżka `deploy/production`; legacy przenieść do wyraźnego archive/ADR bez wykonywalnego triggera. Automatyczny docs/config consistency check dla wersji Ruby/Postgres, hostów, env manifestu i komend. Każdy runbook ma ownera i last-tested date.

**Test zamykający.** `make/just deploy-check` albo równoważny dry-run wskazuje dokładnie jeden Dockerfile/Compose/release manifest; grep nie znajduje aktywnych starych hostów; docs check failuje po kontrolowanej zmianie wersji/URL tylko w jednym miejscu.

## Mocne strony fundamentu

- Postgres i Redis nie są publikowane przez `ports`; Nginx jest jedynym wejściem Compose.
- Web z root `Dockerfile` nie jest uruchamiany jako root tylko pośrednio — **uwaga:** to dotyczy `server/Dockerfile`; aktywny root `Dockerfile` nie deklaruje `USER`, więc produkcyjny proces z Compose jest rootem. To powinno zostać poprawione przy ujednoliceniu obrazu.
- Nginx wymusza HTTPS, TLS 1.2/1.3, HSTS, `nosniff` i ogranicza bezpośrednią ekspozycję aplikacji.
- `.env` i backup permissions zostały według dokumentacji poprawione do 600/700; SSH ma wyłączone logowanie hasłem i system ma unattended security updates.
- Storefront CI przypina akcje SHA, nie utrwala credentials checkoutu i posiada lint/typecheck/unit/E2E.
- pnpm ma sensowne zabezpieczenia supply chain, a repo ma Dependabot i tygodniowy security workflow.
- Provisioning ukrywa wartości env w Vercelu jako encrypted i nie loguje ich jawnie w kodzie; repozytoria sklepów domyślnie są prywatne.
- Dokumentacja uczciwie zapisuje ograniczenia: brak restore, niedziałające alerty, nietrwały firewall, niezweryfikowane elementy Vercel i mutowalne migracje.

## Zalecana kolejność napraw

1. **Zatrzymać fail-open deployment:** testy PR, required checks, build bez `continue-on-error`, environment approval i serializacja deployów.
2. **Immutable build once/promote digest:** przypięty starter/host-app, image digest, migration manifest, SBOM/provenance/signature.
3. **Release/rollback/restore drill:** jeden workflow, migracje przed cutover, publiczna readiness, poprzedni digest, forward-fix schema, zmierzone RPO/RTO.
4. **Alert poza hostem + trwały firewall/IaC:** uptime, backup age, cert, disk/OOM, Sidekiq; odtwarzalna VM.
5. **Least privilege:** app/migrator DB roles, GitHub App, scoped Vercel/R2 credentials, web bez provisioning tokens, rotacja.
6. **Provisioning jako control plane:** idempotentna state machine, compensation/reconciliation, resource IDs, template/release version i fleet update channels.
7. **Capacity i izolacja awarii:** limity, logrotate, queue separation, load tests; potem decyzja managed DB/worker/HA na podstawie SLO.
8. **Domeny/Vercel/R2 policy:** własna domena API, zero-downtime cert renewal, env manifest/doctor, domain workflow, bucket policies w IaC.

## Kryterium zamknięcia audytu 12

Audyt można zamknąć dopiero, gdy zatwierdzony commit przechodzi wymagane PR gates, tworzy jeden immutable i podpisany artefakt z SBOM/migration manifestem, a produkcja promuje dokładnie jego digest po migracji i readiness; kontrolowany błąd uruchamia sprawdzony rollback bez utraty ruchu. Fresh VM jest odtwarzana z IaC, reboot zachowuje firewall/TLS/cron, restore z off-host backupu spełnia zaakceptowane RPO/RTO, a awarie web/worker/DB/dysku/certu/backup age wysyłają realny alert poza host. Każdy sklep ma zinwentaryzowaną wersję storefrontu i config, provisioning jest idempotentny/kompensacyjny, a tokeny GitHub/Vercel/R2/DB mają minimalny scope i zweryfikowaną rotację.

## Ograniczenia audytu

- Nie łączono się z Oracle, Vercel, GitHub settings ani Cloudflare; nie potwierdzono runtime, billing, branch protection, environment approvals, NSG, bucket policy, cert timer, cronów ani wartości/zakresów tokenów.
- Nie wykonywano rebootu, deployu, rollbacku, restore, load/chaos testu ani skanu publicznego hosta.
- Dokumentowane dobre praktyki hosta są traktowane jako deklaracje, nie dowody aktualnego stanu.
- Nie oceniano cen i SLA providerów ani zgodności prawnej regionów; wskazano brak technicznego kontraktu/polityki.
- Audyt 10 nie istniał jeszcze w katalogu w chwili rozpoczęcia; wnioski backup/DR należy później zadeduplikować z jego identyfikatorami.

## Artefakty kontrolne

- `git rev-parse --short=12 HEAD` → backend `9a4f69314735`, storefront `0f83b941f345`.
- Aktywne workflow backendu: 6; tylko `security-audit.yml` przypina główne actions SHA konsekwentnie.
- Compose: 5 usług, healthchecki 2/5, limity zasobów 0/5, publikowane porty tylko Nginx 80/443.
- Brak znalezionych Terraform/Ansible/SBOM/Cosign/Trivy/Syft configów w tracked repo.
- Dwa Dockerfile'e; workflow CI obrazu i host produkcyjny używają różnych plików.
