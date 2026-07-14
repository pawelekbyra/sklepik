# Audyt 00 — stan fundamentu Sklepika po 15 audytach

**Data syntezy:** 2026-07-14
**Zakres:** `pawelekbyra/sklepik` i `pawelekbyra/sklepikFront`
**Baseline raportów:** backend/control plane `9a4f693147`, storefront `0f83b941f3`
**Źródła:** audyty 01–15 z 2026-07-14
**Charakter:** synteza i deduplikacja istniejących audytów; bez zmian produktu, repozytoriów, produkcji i konfiguracji dostawców

## Werdykt wykonawczy

Sklepik ma wartościowy i szeroki fundament pilota: wspólne Store/Admin API, jawny kontekst sklepu, backendowe liczenie commerce, działający katalog i koszyk, rozbudowany panel produktowy, draft/publish layoutu, podstawowy Store Factory, maszyny stanów zamówień oraz sensowne zaczątki webhooków, backupu i CI. To nie jest pusty prototyp.

Jednocześnie **fundament nie jest gotowy do publicznego self-service, wspólnej obsługi niezależnych merchantów z prawdziwymi danymi, płatności online ani samodzielnego fulfillmentu prawdziwych zamówień**. Najważniejsze blokery są systemowe, nie kosmetyczne:

1. potwierdzony dostęp administratora jednego sklepu do klientów i PII innych sklepów;
2. potwierdzony, jawny słaby credential produkcyjnego administratora na snapshot audytu;
3. warunkowo krytyczna, niespójna granica płatności: kwota sesji, routing tenanta i webhook bez trwałego inboxu;
4. procesowo krytyczny release: deploy może wyprzedzić testy, zignorować błąd builda, zbudować inny mutowalny artefakt i wykonać niestabilny zestaw migracji;
5. brak udowodnionego restore, rollbacku, pełnego E2E dwóch tenantów i pełnego E2E właściciel → storefront → zamówienie → obsługa posprzedażowa.

### Decyzja launchowa

| Tryb | Decyzja | Uzasadnienie |
|---|---|---|
| Lokalny development i demo na danych syntetycznych | **GO z ograniczeniami** | fundament funkcjonalny jest wystarczający; nie wolno traktować demo jako dowodu produkcyjnego |
| Wspierany pilot jednego sklepu, bez online payments i bez realnych PII | **CONDITIONAL GO** | dopiero po zamknięciu incydentu credentiali i bezpiecznym release gate; wymaga operatora i jawnych ograniczeń |
| Dwa niezależne sklepy we wspólnym backendzie z realnymi klientami | **NO-GO** | `TENANT-001` przełamuje podstawową granicę danych |
| Płatności online | **NO-GO** | `MONEY-001..003`, `ASYNC-001`, brak adaptera/operatora i reconciliation |
| Samodzielne fulfillment, anulowania, zwroty i reklamacje | **NO-GO** | niespójne cancel/refund/stock i brak dostępnego workflow posprzedażowego |
| Publiczny signup i automatyczny Store Factory | **NO-GO** | provisioning nie jest resumable/idempotent/compensatory; brak owner recovery i pełnego E2E |
| Nienadzorowany deploy produkcyjny z `main` | **NO-GO** | fail-open build/test, niepromowany digest i niestabilne migracje |
| Szeroki publiczny self-service | **NO-GO** | wymaga zamknięcia wszystkich launch gates z tego raportu |

## Normalizacja i poziom dowodu

Piętnaście raportów zawiera łącznie **170 surowych findings**: 9 × P0, 68 × P1, 77 × P2 i 16 × P3. Tych liczb nie wolno sumować jako 170 niezależnych defektów. Wiele raportów ogląda ten sam mechanizm z innej granicy, np. utratę webhooka płatniczego jako ryzyko pieniędzy i jako ryzyko kolejki.

Po deduplikacji powstaje **14 kanonicznych obszarów ryzyka**. Dziewięć surowych P0 sprowadza się do czterech niezależnych klas:

### P0 potwierdzone

| Kanoniczny P0 | Dowód | Znaczenie | Natychmiastowe ograniczenie |
|---|---|---|---|
| **P0-C1 — cross-tenant dostęp do klientów i PII** | kod, serializer, permission set i istniejące testy świadomie utrwalające globalny zakres (`TENANT-001`) | administrator A może czytać/modyfikować klientów B, adresy, notatki i agregaty | nie wpuszczać niezależnych merchantów; do czasu poprawki wyłączyć/ograniczyć customer surfaces w Admin API |
| **P0-C2 — znany słaby credential produkcyjnego admina** | dokładny credential był zapisany w kanonicznej dokumentacji i świadomie przywrócony (`AUTH-001`) | możliwe przejęcie całego panelu i danych; aktualna ważność po snapshotcie nie była ponownie sprawdzana | rotacja, revoke wszystkich sesji, usunięcie z dokumentacji i historii, skan, fail-closed seed; traktować jak incydent |

`P0-C2` jest potwierdzony dla snapshotu audytu, ale jego bieżący stan jest zmienny operacyjnie. Samo usunięcie tekstu z dokumentacji nie zamyka findingu; wymagany jest dowód rotacji i unieważnienia sesji.

### P0 warunkowe

| Kanoniczny P0 | Warunek aktywacji | Dowód | Decyzja |
|---|---|---|---|
| **P0-W1 — błędne obciążenie albo utrata zdarzenia płatniczego** | włączenie realnego adaptera/PSP i płatności online | klient kontroluje amount sesji; webhook URL wskazuje złą aplikację; tenant jest rozwiązywany z niewłaściwej granicy; 200 może zostać zwrócone bez trwałego inboxu (`MONEY-001..003`, `MONEY-007`, `ASYNC-001`) | dziś nie jest to dowód trwającej utraty pieniędzy, bo produkcyjny adapter nie istnieje; bezwzględny gate przed online payments |

`ORDER-004` pozostaje P1 w obecnym stanie, bo kompletne returns nie są wystawione przez produkt. Naiwne udostępnienie tego flow bez locków i constraintów podniosłoby je do P0 przez możliwość podwójnej zmiany inventory.

### P0 procesowe

| Kanoniczny P0 | Dowód | Co jest, a czego nie dowiedziono | Decyzja |
|---|---|---|---|
| **P0-P1 — release nie gwarantuje przetestowanego, jednoznacznego i migracyjnie bezpiecznego artefaktu** | deploy nie czeka na testy i ignoruje błąd builda; CI i host budują innymi ścieżkami; starter/obrazy są mutowalne; migracje są kopiowane efemerycznie i mogą dostać nowe timestampy (`INFRA-001/002`, `DB-001`) | potwierdzono niebezpieczny proces; nie potwierdzono, że konkretny obecny deploy już uszkodził dane | zatrzymać automatyczną promocję do czasu immutable build-once/promote-digest, migration manifestu i rollback drill |

P0 procesowe blokuje zmianę produkcji, ale nie oznacza samo w sobie aktywnego incydentu danych. Jego rolą jest nie dopuścić, by poprawki pozostałych P0 zostały wdrożone niepowtarzalną ścieżką.

## Potwierdzone mocne strony

1. **Commerce pozostaje na backendzie.** Ceny, sumy, podatki, promocje, shipping, order state i podstawowe limity płatności są liczone po stronie Store API, nie w UI.
2. **Większość granicy sklepu jest jawna.** Publishable key rozwiązuje tenant, konflikt key/host/header jest odrzucany, secret key i JWT admina są wiązane ze sklepem, cart/order/layout/webhook endpoints zwykle używają scope'u sklepu.
3. **Dobre podstawy auth.** Oddzielne audience JWT, krótkie TTL admina, HttpOnly cookies, current-password przy zmianach klienta, neutralny reset i membership per store są dobrym punktem wyjścia.
4. **Draft/live i draft/published są właściwymi bezpiecznikami.** Sklep draft nie może kończyć zamówień ani tworzyć płatności; Store API nie zwraca draftu layoutu.
5. **Core commerce ma wartościowe primitives.** Decimal money, order locks, state machines, partial unique indexes, inventory units, fulfillment, refund/return/reimbursement models oraz server-side recalculation dają bazę do utwardzenia.
6. **Panel produktu jest głęboki.** Produkty, media, ceny, stock, tłumaczenia i publikacja mają szeroki zakres oraz wiele istniejących testów E2E.
7. **Storefront funkcjonalnie nie jest szkieletem.** Katalog, search/facets, PDP, warianty, koszyk, checkout UI, konto, order detail, polityki, SEO basics, e-maile i renderer istnieją; lint, TypeScript, locale parity i 97 testów jednostkowych przeszły w audycie 15.
8. **Webhooki mają część ważnych zabezpieczeń.** HMAC, timestamp tolerance, SSRF filter outbound, after-commit lifecycle events, delivery records i event UUID są dobrymi elementami, choć brakuje outbox/inbox i realnego retry.
9. **Infrastruktura ma minimalne podstawy.** Nginx jest jedynym publicznym wejściem Compose, PostgreSQL i Redis nie publikują portów, jest HTTPS/HSTS, restart policy i pierwsza off-host kopia dumpu.
10. **Dokumentacja nazywa ograniczenia wprost.** Brak restore, alertów, trwałego firewalla, adaptera Stripe i prawdziwego E2E nie został zamaskowany jako gotowość.
11. **Inwentaryzacja była pełna ewidencyjnie.** 4 859/4 859 tracked paths objęto deterministyczną klasyfikacją; wiadomo, gdzie leżą engine, aktywne UI, generated i legacy.

## Kanoniczny rejestr ryzyk

### K-01 — izolacja tenantów i model klienta

**Priorytet:** P0 dla Admin Customer/PII; P1 dla modelu identity.
**Status:** przełamanie granicy potwierdzone statycznie; brak black-box E2E na prawdziwym Rails/PostgreSQL.

Globalny `User`, fail-open `for_store` i `SuperUser can :manage, :all` sprawiają, że poprawne scope'owanie produktów, koszyków i zamówień nie chroni domeny klientów. Osobną decyzją produktową jest model: konta per sklep albo jawne Sklepik ID/SSO. W obu wariantach merchant-visible customer profile, addresses, aggregates i tokens muszą być tenantowe.

**Wynik docelowy:** jawna relacja customer–store, tenant-aware profile/reset/token albo świadome SSO z consentem, fail-closed model scopes, tenant ownership blobów/jobów/webhook envelope i black-box suite dwóch tenantów.
**Role:** Identity & Tenant, Backend Commerce, Security, QA.

### K-02 — credentiale, sesje i odzyskiwanie kont

**Priorytet:** P0 dla znanego credentialu; P1 dla session lifecycle i owner recovery.
**Status:** credential potwierdzony na snapshot; produkcyjne wartości JWT/cache/MFA i aktualna rotacja nieweryfikowane.

Po rotacji credentialu pozostają: raw refresh tokeny w DB, brak revoke przy zmianie/resetowaniu hasła, brak pełnego admin forgot/reset/confirm, brak MFA/step-up, wyścig refresh i niepełna security observability. Owner signup ustanawia sesję przed weryfikacją e-maila.

**Wynik docelowy:** credential incident closed, refresh digests i token families, atomowe revoke/reuse detection, owner verify/recovery, MFA dla operacji wysokiego ryzyka, security event trail.
**Role:** Security, Identity & Tenant, Dashboard, SRE.

### K-03 — pieniądze, PSP, idempotencja i reconciliation

**Priorytet:** warunkowe P0 przed online payments.
**Status:** błędy kontraktu potwierdzone; wpływ operatora nieweryfikowany, bo realny adapter/Connect nie istnieje.

Kanoniczna kwota i waluta muszą powstać pod lockiem z `amount_due`, webhook musi trafiać do backendu i rozwiązywać tenant z bezpiecznego endpoint ID, a zdarzenie PSP musi zostać trwale zapisane przed 2xx. Ogólne cache read→effect→write nie zapewnia idempotencji refundu, sesji ani provisioningu. UI nie może uznawać dowolnego 403/422 za sukces.

**Wynik docelowy:** wybrany model PSP/Connect, dwa odizolowane tenanty, durable payment inbox, atomowa idempotencja również u providera, DLQ/retry/reconciliation, capability-aware launch i pełny sandbox E2E capture/3DS/void/refund.
**Role:** Payments, Backend Commerce, Data, SRE, Storefront, QA.

### K-04 — zamówienia, stock, anulowania, zwroty i reklamacje

**Priorytet:** P1 przed pierwszym prawdziwym fulfillmentem.
**Status:** niespójności cancel/ship/refund potwierdzone; kompletny returns/cases flow jest obecnie niedostępny.

Cancel API deklaruje decyzje, których kontroler nie egzekwuje; audit flags mogą przeczyć realnemu restockowi i gateway call. `canceled → ship` może ominąć ponowne zdjęcie stocku. Refund nie ma kompletnego aktora, allocation i case. Core returns istnieje, ale bez API/UI, concurrency constraints, tenant invariants i reklamacyjnego agregatu.

**Wynik docelowy:** typowane, idempotentne commands dla cancel/refund/stock; tenantowy Case workflow; actor/reason/evidence; ledger invariants; portal klienta; notification policy i wersjonowane dokumenty/deadlines po zatwierdzeniu operacyjnym i prawnym.
**Role:** Backend Commerce, Operations/Product, Payments, Dashboard, Storefront, Legal/Compliance, QA.

### K-05 — baza, schemat, migracje i integralność

**Priorytet:** procesowe P0 dla artefaktu migracji; P1 dla backfilli i constraints.
**Status:** proces i braki schematu potwierdzone; aktualnej korupcji produkcyjnej nie stwierdzono i nie badano live DB.

Efemeryczne kopiowanie migracji, brak kanonicznego PostgreSQL `structure.sql`, niepełne backfille tenantów i brak PR migration gate powodują, że technicznie zielony release może zostawić silent data loss. Rails validations nie zastępują FK/CHECK/tenant constraints, a część DDL nie ma polityki zero-downtime.

**Wynik docelowy:** stabilny migration artifact i checksum manifest, fresh/upgrade/double-run na PostgreSQL, jeden resumable upgrade z post-conditions, schema drift gate, etapowe NOT NULL/FK/CHECK oraz reconciliation money/tenant/orphans.
**Role:** Data/Database, Backend Commerce, Release Engineering, SRE.

### K-06 — eventy, kolejki, webhooki i e-mail

**Priorytet:** P0 dla payment inbox; P1 dla transactional delivery.
**Status:** luki algorytmiczne potwierdzone; produkcyjny Redis/Resend/queue state nieweryfikowane.

Event bus jest procesowy, bez transactional outbox. Outbound webhook zapisuje failure, ale nie rzuca, więc deklarowane retry dla timeout/5xx jest martwe. Wszystkie logiczne kolejki mapują się na `default`, a provisioning może zająć cały worker. Brak Resend w production przechodzi do dev sink, idempotencja maili jest check-then-act, a `notify_customer` nie steruje wysyłką.

**Wynik docelowy:** transactional outbox, tenant inbox per kanał, atomic claim, retry/backoff/DLQ, osobne critical/webhook/bulk queues, provider message IDs, production fail-closed readiness, scheduler i queue SLO/alerts.
**Role:** Backend Platform, Payments, Messaging, SRE, Storefront.

### K-07 — CI/CD, supply chain, release i rollback

**Priorytet:** procesowe P0.
**Status:** fail-open workflow i rozbieżne build paths są faktami z repo; branch protection i środowiska GitHub nieweryfikowane.

Push do `main` może deployować równolegle z testami; build ma `continue-on-error`; CI buduje inny Dockerfile niż host; host resetuje do bieżącego `origin/main`; starter, actions i obrazy są mutowalne. Aplikacja jest odtwarzana przed migracją, readiness nie bada publicznej ścieżki, nie ma utrwalonego poprzedniego digestu ani sprawdzonego rollbacku.

**Wynik docelowy:** required PR gates, serializowany deploy, build once/test/promote digest, pinned dependencies, SBOM/provenance/signature, release manifest z migracjami, health-gated cutover i fault-injected rollback.
**Role:** Release Engineering, SRE, Security, Data/Database.

### K-08 — infrastruktura, backup, DR i obserwowalność

**Priorytet:** P1 przed realnymi danymi i sprzedażą.
**Status:** jedna VM i nieprzetestowany restore potwierdzone; rzeczywiste R2 policies, firewall, monitoring i backup freshness nieweryfikowane.

API, worker, PostgreSQL, Redis i Nginx współdzielą jeden host i volumes. Dump istnieje lokalnie i w R2, ale nie było restore; media nie mają udowodnionej niezależnej kopii; alerty są lokalne/niedziałające; firewall nie jest trwały; host i sekrety nie są odtwarzalne z IaC. Nie ma zatwierdzonych RPO/RTO ani PITR.

**Wynik docelowy:** zewnętrzne alerty, monitorowany backup z checksumą, immutable/off-provider copy DB i originals, pełny restore na czystej infrastrukturze, IaC/bootstrap, secret recovery, provider reconciliation i zatwierdzone RPO/RTO. Dla szerszej skali oddzielić co najmniej data plane od compute.
**Role:** SRE, Data/Database, Security, Operations.

### K-09 — Store Factory, provisioning i zarządzanie flotą

**Priorytet:** P1 przed publicznym signupem i drugim automatycznym tenantem.
**Status:** brak resume/idempotency/compensation potwierdzony; realne GitHub→Vercel E2E nieweryfikowane.

Provisioning wykonuje długą sekwencję w jednym jobie, zostawia orphan resources, nie adoptuje częściowego sukcesu, nie ma self-service recovery ani trwałego status route. Nowy storefront dostaje niepełny env manifest, nie zapisuje template/release/contract version i nie ma canary/cohort rollback dla floty.

**Wynik docelowy:** durable step state machine, idempotency keys per provider, leases/retry/adoption/compensation/reconcile, GitHub App, pełny Vercel doctor, resource inventory, template/release version i fleet security update channel.
**Role:** Control Plane/Store Factory, SRE, Dashboard, Security, QA.

### K-10 — bezpieczeństwo aplikacji i abuse resistance

**Priorytet:** P1 przed realnymi klientami.
**Status:** stored XSS, produkcyjna flaga local-IP image fetch, nieograniczone pliki i mutowalny supply chain potwierdzone w repo; exploit runtime nie był wykonywany.

Rich text ownera jest renderowany jako HTML bez kanonicznej sanitizacji; image optimizer pozwala na prywatne IP; importy/digitals nie mają spójnych limitów i buforują całe pliki; storefront nie definiuje CSP; rate limits mają procesowy magazyn; webhook odczytuje całe body przed limitem.

**Wynik docelowy:** allowlist sanitization backend+renderer, CSP i security headers, produkcyjna origin allowlist dla obrazów, limity/streaming/signed downloads, Redis rate limiting, webhook budgets, blokujące advisory/container gates i autoryzowany DAST dwóch tenantów.
**Role:** Security, Backend Platform, Storefront, SRE, QA.

### K-11 — kontrakty API/SDK, granica Spree i kompatybilność floty

**Priorytet:** P1 dla niekontrolowanej granicy; P2 dla mechaniki migracji.
**Status:** publiczne przecieki i drift OpenAPI potwierdzone; realne consumer contracts nie istnieją.

Storefront importuje `@spree/sdk` szeroko, dashboard używa klas `Spree::*`, publiczny protokół ma `X-Spree-*`, cookies/env/webhook route, a Store OpenAPI ma 0 B. Layout, provisioning i webhook contract są ręcznie kopiowane. Nie należy globalnie przemianowywać namespace Ruby ani 131 tabel `spree_*`; to silnik wewnętrzny, a rename byłby dodatkowym ryzykiem danych.

**Wynik docelowy:** `@sklepik/contracts`, store/admin clients i adapter `adapters/spree`; CI „no new leaks”; neutralne identyfikatory provider/permission; dual-read/write-new dla headers/cookies/env/webhooków; wersjonowane schemas; deterministyczny OpenAPI→types→Zod→SDK→consumer pipeline; wsparcie aktualnej i poprzedniej wersji storefrontu.
**Role:** Platform Architecture, API/SDK, Backend Commerce, Dashboard, Storefront, Release Engineering.

### K-12 — panel, onboarding, edytor i launch readiness

**Priorytet:** P1 przed self-service.
**Status:** niepełne shipping/tax i brak owner recovery/E2E potwierdzone; część runtime flow historyczna, nie powtórzona.

Właściciel nie skonfiguruje prawidłowo shippingu i VAT z samego panelu. Readiness mierzy często obecność, nie zdolność. Edytor ma optimistic save, ale publish nie wymaga oczekiwanej rewizji, brak historii/rollbacku i dirty guard. Błędy są maskowane jako skeleton/null, a provisioning nie ma recovery UI.

**Wynik docelowy:** owner verify/recovery, guided shipping/tax/payment/legal setup, capability-aware readiness snapshot, pełny owner E2E, immutable layout revisions i expected-revision publish, rollback/audit, faithful preview, typed errors i role-aware actions. AI dopiero przez typed commands, dry-run/diff i approval.
**Role:** Dashboard/Owner Experience, Backend Commerce, Control Plane, Product Operations, QA.

### K-13 — storefront, sprzedaż, zaufanie, prywatność i SEO

**Priorytet:** P1 przed prawdziwym ruchem klientów.
**Status:** kodowe maskowanie awarii, tracking bez consent i brak policy evidence potwierdzone; prawna adekwatność treści nieweryfikowana.

Outage/config error udaje pusty katalog lub 404; Playwright używa starego routingu; analytics startuje bez consent; checkbox polityk nie zapisuje wersji/snapshotu; brakuje pełnego profilu sprzedawcy, kontaktu i wejścia do after-sales. Cache katalogu jest pozorny, renderer ignoruje część kontraktu, a locale/SEO/sitemap/noindex/a11y/cross-browser nie mają pełnych gates.

**Wynik docelowy:** storefront doctor i production-like golden path, typed outage vs 404, consent default-deny, immutable policy evidence, seller profile/support, real cache z tenant tags i stale-if-error, pełny renderer schema, poprawne metadata/sitemap oraz mobile/WebKit/Firefox/axe gates.
**Role:** Storefront, Privacy/Legal, Product, API/SDK, QA, SRE.

### K-14 — brakujące dowody end-to-end i governance gotowości

**Priorytet:** P1 jako przekrojowy launch blocker; nie jest osobnym exploitem.
**Status:** luki w testach są potwierdzone; wiele runtime controls nie mogło zostać odczytanych.

Unit/controller/typechecki są wartościowe, ale mockowe `test-contracts`, stary checkout E2E, brak dwóch realnych tenantów, brak realnego PSP, brak restore/rollback/chaos i brak owner golden path oznaczają, że „kod istnieje” nie może być utożsamiane z „wdrożone”, „zweryfikowane runtime” ani „gotowe”.

**Wynik docelowy:** każdy launch gate ma automatyczny test albo podpisany drill, datę, środowisko, artefakt i jednoznaczny PASS/FAIL. Runtime unknown pozostaje unknown, dopóki nie ma dowodu.
**Role:** QA/Release Engineering, SRE, właściciele domenowi wszystkich gates.

## Kolejność realizacji

### Etap 0 — containment i zamrożenie ekspozycji

1. Zrotować credential produkcyjnego admina, odwołać sesje i zamknąć historię sekretu.
2. Wstrzymać publiczny signup, online payments, niezależnych merchantów i customer PII w współdzielonym panelu.
3. Tymczasowo wyłączyć lub zawęzić customer admin endpoints, jeśli poprawka tenantowa nie może wejść natychmiast.
4. Zablokować fail-open deployment; zmiany produkcyjne dopuszczać tylko ręcznie, z jawnym commitem i rollback pointem.
5. Zapisać baseline produkcyjnego commit/image/schema/backup bez ujawniania sekretów.

**Wyjście:** P0-C2 operacyjnie zamknięty; ekspozycja P0-C1/P0-W1/P0-P1 nie może się zwiększać.

### Etap 1 — bezpieczna droga dostarczenia poprawek i dowód danych

1. Required PR tests i jeden build-once/promote-digest pipeline.
2. Stabilny host-app/migration artifact, PostgreSQL structure i migration manifest.
3. Fresh install, upgrade, double-run, backfills i schema post-conditions w CI.
4. Zewnętrzny uptime/backup alert i pierwszy izolowany restore najnowszego dumpu.
5. Uruchamialny black-box harness na PostgreSQL/Redis dla dwóch tenantów.

**Wyjście:** poprawki kolejnych etapów można wdrażać powtarzalnie; restore i rollback mają pierwszy zmierzony dowód.

### Etap 2 — tenant i identity

1. Podjąć decyzję: per-store accounts albo jawne Sklepik ID/SSO.
2. Wdrożyć customer membership/profile scope i tenant-aware aggregates/nested resources.
3. Naprawić reset, JWT/refresh i addresses zgodnie z wybranym modelem.
4. Zmienić fail-open model scopes, blob ownership i job tenant guards.
5. Zahashować refresh tokeny, revoke przy zmianie/reset, dodać owner confirmation/recovery i MFA/step-up.

**Wyjście:** pełny test dwóch tenantów nie znajduje cross-store read/write dla żadnego credential type.

### Etap 3 — money i asynchroniczna niezawodność

1. Wybrać PSP/Connect i wdrożyć adapter sandboxowy bez sekretów w zwykłych preferencjach.
2. Usunąć amount/currency z kontroli klienta; naprawić webhook origin i tenant resolution.
3. Dodać durable payment inbox, domenową idempotencję, retry/DLQ i reconciliation.
4. Wprowadzić transactional outbox oraz trwałe inboxy e-mail/webhook/cache.
5. Rozdzielić kolejki critical/webhooks/bulk; dodać SLO i alerty.
6. Usunąć false-success checkoutu i dopiero potem wykonać dwutenantowy PSP E2E.

**Wyjście:** jeden event PSP daje dokładnie jeden efekt domenowy mimo retry, crashu i utraty odpowiedzi; provider i ledger są zgodne.

### Etap 4 — prawdziwe zamówienie i obsługa właściciela

1. Jeden cancel/refund/stock command z aktorem, powodem i durable effect execution.
2. Zamknąć canceled/resume/ship i concurrency inventory.
3. Zbudować dostępny Case/return/reklamacja workflow i portal klienta.
4. Naprawić guided shipping/tax oraz capability-aware payment/legal/readiness.
5. Dodać owner E2E od verify signup do sandbox order, komunikacji i sprawy posprzedażowej.
6. Dodać revisioned editor, expected-version publish, diff, audit i rollback.

**Wyjście:** świeży owner bez terminala przechodzi cały flow, a money/stock/communication pozostają spójne przy fault injection.

### Etap 5 — odporność operacyjna i Store Factory

1. Durable provisioning workflow z resume/adoption/compensation/reconcile.
2. GitHub App, scoped Vercel/R2/DB credentials i rotation drill.
3. IaC/bootstrap hosta, trwały firewall, publiczna readiness, centralne logi/metrics.
4. Niezależne immutable backups, media inventory, PITR według zatwierdzonego RPO/RTO.
5. Fleet manifest, doctor, canary/cohort update i rollback.

**Wyjście:** czysta VM i nowy tenant są odtwarzalne automatycznie; awaria każdego providera kończy się jednoznacznym stanem i alertem.

### Etap 6 — jakość storefrontu i kontrolowana abstrakcja Spree

1. Empty vs outage, real cache/stale-if-error, aktualny storefront golden path.
2. Consent, policy snapshots, seller profile, after-sales entry, SEO/i18n/a11y/cross-browser.
3. Jedno schema layout/event, renderer compatibility i contract tests.
4. `@sklepik/*` facades i adapter Spree; dual-read/write-new publicznego protokołu.
5. Usuwanie legacy aliases dopiero po telemetrycznym oknie zerowego użycia i próbie rollbacku.

**Wyjście:** publiczny i integracyjny język jest neutralny, ale engine namespace/tabele pozostają stabilne i niewidoczne poza adapterem.

## Launch gates

| Gate | Warunek PASS | Blokuje | Rola prowadząca |
|---|---|---|---|
| **G0 Credential containment** | stary credential 401; wszystkie stare refresh sessions revoked; secret scan repo/history/logów; production seed failuje bez env | każdy tryb z realnymi danymi | Security |
| **G1 Safe release** | zepsuty test/build nie tworzy deployu; produkcja uruchamia dokładny digest z CI; migration manifest zgodny; rollback drill PASS | każdy deploy produkcyjny | Release Engineering |
| **G2 Tenant isolation** | black-box dwa tenanty obejmujące klientów, addresses, orders, money, media, exports, jobs, cache i webhooki; negatywne IDOR | niezależni merchanty i PII | Identity & Tenant |
| **G3 Identity recovery** | owner confirm/reset/MFA; customer reset per tenant; token digests/revocation/reuse; CSRF browser suite | publiczny signup i konta klientów | Identity & Tenant |
| **G4 Payment safety** | dwa sandbox tenanty; amount/currency canonical; signed tenant webhook; durable inbox; idempotent retry; reconciliation; 3DS/capture/void/refund | online payments | Payments |
| **G5 Async communication** | outbox/inbox, retry/DLQ, queue separation; Resend readiness; atomic dedupe; notify policy; provider message IDs | gwarantowane e-maile i event-driven operations | Backend Platform/Messaging |
| **G6 Order operations** | state/concurrency matrix cancel/ship/return/refund; ledger invariants; actor/audit; customer Case E2E | fulfillment i samodzielna obsługa zamówień | Backend Commerce/Operations |
| **G7 Owner self-service** | aktualny E2E signup→provision→config→publish→launch→sandbox order; shipping/tax round-trip; retry/recovery | publiczny Store Factory | Dashboard/Control Plane |
| **G8 DR and operations** | clean-host restore PASS; DB↔R2↔provider reconcile; measured RPO/RTO; external alerts; reboot/IaC PASS | realne dane i płatny pilot bez stałego nadzoru | SRE/Data |
| **G9 Application security** | XSS/SSRF/upload/rate/webhook abuse tests; CSP; blocking dependency/image scans; DAST bez high/critical | realny ruch klientów | Security |
| **G10 Contract compatibility** | niepuste kompletne OpenAPI; clean generation; two-tenant provider tests; current+previous consumer; versioned event/layout | aktualizacja floty i usuwanie aliasów | API/SDK |
| **G11 Storefront quality** | build i aktualny checkout E2E; outage≠404; consent/policy evidence; sitemap/metadata; mobile WebKit + Firefox/Chromium; axe | szeroki publiczny launch | Storefront/QA |
| **G12 Legal and operational readiness** | zatwierdzone dane sprzedawcy, polityki, wersje, terminy i workflow reklamacji; snapshot przy zamówieniu | publiczna sprzedaż na danym rynku | Legal/Compliance + Operations |

Żaden gate nie zamyka się samym PR-em ani zielonym unit testem. Dowód musi wskazywać commit/digest, środowisko, datę, wynik i artefakt testu lub drill.

## Minimalny pakiet testów zamykających

### T-01 — secret incident closure

- próba starym credentialem: 401;
- revoke wszystkich sesji sprzed rotacji;
- skan bieżącego drzewa i historii bez wypisywania wartości;
- seed produkcyjny bez wymaganych env: kontrolowany fail;
- dowód MFA/recovery dla uprzywilejowanego konta.

### T-02 — black-box tenant matrix

Dwa sklepy, dwóch adminów, dwa publishable/secret keys, dwóch klientów i klient wspólny tylko jeśli wymaga tego wybrany SSO. Realny Rails + PostgreSQL + Redis, bez mocków odpowiedzi API. Macierz obejmuje index/show/search/export/update/destroy i nested resources dla klientów, adresów, orders, payments, credits, media, blobs, jobs, cache i webhooków. Usunięcie jednego scope'u musi celowo czerwienić suite.

### T-03 — auth/session matrix

Login/register/refresh/logout/reset/change password/email dla obu tenantów, 10 równoległych refreshy, reuse poza grace, logout-all, session kill, CSRF z obcego originu, rate limit przez dwa procesy i owner verify/reset/MFA/recovery z prawdziwą skrzynką testową.

### T-04 — migration and schema gate

Na PostgreSQL wersji zgodnej z produkcją: fresh install → migrate → ponowne odtworzenie host-app → double migrate; upgrade fixture poprzedniej wersji dwóch tenantów; wszystkie backfille i post-conditions; schema/manifest diff; orphan/cross-tenant scan; invalid direct SQL odrzucany przez constraints.

### T-05 — payment sandbox and reconciliation

Dwa tenanty i dwa konta/operator configs: tampered amount/currency, cart mutation race, 3DS, duplicate/reordered webhook, Redis outage, DB error, response loss, provider timeout, capture, void, full/partial refund. Dokładnie jedna płatność i jedno completion; reconciliation wykrywa każdy drift bez ponownego obciążenia.

### T-06 — async chaos matrix

Kill procesu między commit/outbox/enqueue, zatrzymanie Redis, timeout/429/5xx, parallel delivery, poison job, missing provider config i crash po provider accept. Każdy committed event ma trwały stan, retry lub DLQ; żaden nie znika po fałszywym 2xx/success.

### T-07 — order, stock and after-sales state tests

Property/state-machine oraz 20 równoległych operacji dla cancel/ship/resume/receive/refund. Macierz paid/authorized/offline × unshipped/partial/shipped × full/partial. Inwarianty money i inventory, jeden actor/audit trail, jeden stock movement/refund. Browser E2E customer/guest/owner dla return i reklamacji.

### T-08 — release and rollback fault injection

Zepsuty test, build, migracja, Puma, Sidekiq i publiczny HTTPS nie mogą wyłączyć poprzedniej wersji. Dwa szybkie pushe promują wyłącznie zatwierdzony nowszy digest. Produkcja raportuje commit, digest, starter SHA i migration checksum. Rollback/forward-fix ma zmierzony MTTR.

### T-09 — full DR drill

Czysta infrastruktura, zweryfikowany dump/checksum, restore ról/DB, schema/tenant/money checks, DB↔R2 originals inventory, testowy wariant, Sidekiq, webhook, read-only GitHub/Vercel/payment reconcile, utrata Redis i missing credentials. Raportuje realne RPO/RTO i PASS/FAIL; sam start Rails nie wystarcza.

### T-10 — Store Factory chaos and fleet test

Fault injection przed i po każdym callu GitHub/Vercel. Dowolna liczba retry kończy się jednym repo, projektem, env i deploymentem albo pełną kompensacją. Reload UI zachowuje status. Fleet inventory wykrywa drift i wykonuje canary→cohort→rollback.

### T-11 — application security suite

OWASP rich-text payloads przez Admin→Store API→browser; Next image requests do loopback/RFC1918/link-local/redirect/rebinding; oversized/fake-MIME/CSV bomb; concurrent digital downloads; distributed limiter; oversized webhook. Do tego CSP/header scan, dependency/container policy i autoryzowany DAST dwóch tenantów.

### T-12 — contract and fleet compatibility

Route/serializer→OpenAPI→types→Zod→SDK bez diffu; wszystkie publiczne paths pokryte; versioned event/layout fixtures; webhook z podpisanym store ID; current i oldest-supported storefront/dashboard przeciw bieżącemu backendowi; breaking-change detector i rollback fixture.

### T-13 — owner golden path

Signup→confirm→provision→reload→login→product/media→shipping zone/category/method/rate→VAT 23%→PSP sandbox→legal→draft/save/conflict/publish→launch→public storefront→sandbox order. Fake provider psuje każdy krok, retry nie dubluje zasobów, a correlation ID łączy UI, API i job.

### T-14 — storefront sales-quality gate

Build PASS; aktualne route PL; katalog empty vs 401/403/404/5xx/timeout/config; consent accept/reject/revoke; policy version evidence; seller/contact/after-sales; cache hit/miss/invalidation/tenant isolation; wszystkie pola layoutu; sitemap URL=200; canonical/hreflang/noindex; Chromium/Firefox/mobile WebKit; keyboard-only i axe bez serious/critical.

## Ryzyko rezydualne po zamknięciu gates

1. **Jedna VM nadal pozostanie wspólnym failure domain**, nawet po dobrym restore i alertach. Może to być zaakceptowane dla ograniczonego pilota tylko z jawnym SLO/RPO/RTO i procedurą operatora; nie jest rozsądnym stanem docelowym dla większego przychodu.
2. **Spree pozostanie wewnętrznym silnikiem.** Namespace `Spree::`, gemy i tabele `spree_*` nie są same w sobie porażką. Ryzyko jest akceptowalne, jeśli UI, publiczny protokół i nowe moduły używają kontraktów Sklepika, a engine jest zamknięty w adapterze.
3. **At-least-once jest właściwą semantyką transportu.** Nawet po outbox/inbox nie należy obiecywać dokładnie jednego transportu; gwarancją ma być trwały zapis, idempotentny efekt i reconciliation.
4. **Providerzy zewnętrzni pozostają zależnością.** GitHub, Vercel, R2, Resend i PSP wymagają własnych SLO, quota, incident runbooks i exit strategy; testy aplikacji nie certyfikują ich usług.
5. **Zgodność prawna i płatnicza wymaga osobnego zatwierdzenia.** Audyty techniczne nie są opinią prawną, księgową, PCI DSS ani PSD2/SCA.
6. **Retencja i DSAR pozostaną programem ciągłym.** Backupy, logi, webhooks, gateway data i documents wymagają wersjonowanej polityki oraz tombstone replay po restore.
7. **Legacy zwiększa koszt utrzymania.** `spree/admin` i `spree/emails` to 1 135 tracked files. Ich izolacja jest ważna, ale usunięcie nie powinno wyprzedzać trace'u runtime/build dependencies.
8. **Wydajność nie została dowiedziona na skali.** Brak production query plans, load/CWV i capacity modelu. Po gates bezpieczeństwa potrzebne są budgets i pomiar na reprezentatywnym fixture.
9. **Audyt jest snapshotem.** Każdy runtime unknown pozostaje ryzykiem, dopóki nie zostanie potwierdzony z konsoli, logu lub kontrolowanego testu. Zmiana baseline wymaga ponownego testu, nie tylko aktualizacji dokumentacji.

## Mapa cross-reference kanonicznych ryzyk

Poniższa mapa wskazuje źródła kanoniczne. Powtórzenie identyfikatora między wierszami oznacza, że finding przecina kilka granic, a nie że jest liczony ponownie.

| Ryzyko kanoniczne | P0/P1 źródłowe | Najważniejsze zależności P2/P3 |
|---|---|---|
| **K-01 Tenant/customer** | `TENANT-001..003`, `AUTH-002/003` | `TENANT-004..008`, `DB-003`, `API-005/006`, `ORDER-007`, `FRONT-014` |
| **K-02 Credentials/sessions** | `AUTH-001`, `AUTH-004..006`, `PANEL-001` | `AUTH-007..012`, `INFRA-007`, `DR-008` |
| **K-03 Money/PSP** | `MONEY-001..008`, `ASYNC-001`, `API-002` | `MONEY-009/010`, `DB-004`, `ORDER-003/008`, `PANEL-016`, `FRONT-005` |
| **K-04 Order/after-sales** | `ORDER-001..006`, `MONEY-008`, `PANEL-002/003`, `FRONT-003/004` | `ORDER-007..012`, `FRONT-015`, `PANEL-017` |
| **K-05 Database/migrations** | `DB-001..006`, `SPREE-007`, `INFRA-003` | `DB-007..010`, `ARCH-006`, `DR-001`, `INFRA-002` |
| **K-06 Async/email/webhooks** | `ASYNC-001..007`, `MONEY-007`, `ORDER-006`, `ARCH-009/010` | `ASYNC-008..012`, `ORDER-011`, `SEC-007`, `TENANT-004`, `FRONT-015` |
| **K-07 CI/release/supply chain** | `INFRA-001..003`, `SEC-004`, `ARCH-005`, `DB-001/006` | `SEC-008`, `INFRA-012/016`, `DR-004`, `ARCH-006/012/015` |
| **K-08 Infra/DR/observability** | `ARCH-001/002`, `DR-001..005`, `INFRA-004..007` | `ARCH-007/008`, `DR-006..010`, `INFRA-009/010/013..015`, `DB-009`, `SEC-003/006` |
| **K-09 Store Factory/fleet** | `ARCH-003/004`, `ASYNC-005/006`, `INFRA-008`, `PANEL-007` | `DB-007`, `INFRA-011`, `PANEL-008/010/014`, `ARCH-014/016` |
| **K-10 App security** | `SEC-001..004`, `AUTH-001` | `SEC-005..008`, `AUTH-007/010/012`, `TENANT-005..008`, `FRONT-002/014` |
| **K-11 Contracts/Spree** | `INV-001/002`, `SPREE-001..003/007`, `API-001/002` | `ARCH-013`, `INV-003..008`, `SPREE-004..006/008/009`, `API-003..007`, `PANEL-005/009/015`, `FRONT-010` |
| **K-12 Panel/onboarding/editor** | `AUTH-006`, `PANEL-001..005/007`, `MONEY-005` | `PANEL-006/008..017`, `MONEY-010`, `ORDER-009/010` |
| **K-13 Storefront/sales quality** | `FRONT-001..005`, `SEC-001/002`, `MONEY-004`, `ASYNC-004` | `FRONT-006..015`, `ARCH-011`, `SEC-005/007`, `API-004/005`, `ASYNC-008` |
| **K-14 Verification/governance** | `TENANT-003`, `PANEL-004`, `FRONT-005` | `INV-006`, `API-006/007`, `FRONT-012`, runtime limitations wszystkich audytów |

## Mapa audytów 01–15 do decyzji nadrzędnych

| Audyt | Wkład do syntezy | Najważniejsza decyzja nadrzędna |
|---|---|---|
| 01 — inwentaryzacja | pełna mapa 4 859 plików, legacy, generated, checkout concentration | izolować legacy i Spree; nie usuwać/rename'ować mechanicznie |
| 02 — architektura | failure domains, provisioning, mutowalny host-app | przed skalą potrzebne DR, resumable control plane i pinned build |
| 03 — uniezależnienie od Spree | publiczne przecieki engine i plan adapterów | neutralny kontrakt Sklepika, nie globalny rename danych/namespace |
| 04 — izolacja | potwierdzony cross-tenant customer/PII | bezwzględny NO-GO dla niezależnych merchantów |
| 05 — auth | credential P0, globalna identity, session lifecycle | incident containment i wybór modelu tożsamości przed klientami |
| 06 — bezpieczeństwo | XSS, SSRF, pliki, supply chain | security gate i DAST przed realnym ruchem |
| 07 — pieniądze | amount, webhook URL/tenant, adapter, idempotency | online payments dopiero po durable PSP architecture i E2E |
| 08 — zamówienia | cancel/refund/stock mismatch i brak after-sales | płatność nie oznacza gotowości do prawdziwej sprzedaży |
| 09 — baza | niestabilne migracje, backfille, constraints | stabilny migration artifact i PostgreSQL gate przed deployem |
| 10 — DR | backup istnieje, recoverability nieudowodniona | restore drill i niezależne kopie przed realnymi danymi |
| 11 — async | fałszywe 200/success, martwe retry, brak outbox | trwały outbox/inbox, queue separation i messaging readiness |
| 12 — infrastruktura | fail-open deploy, rozbieżne obrazy, brak rollback/IaC | immutable build-once/promote-digest jako procesowe P0 |
| 13 — API/SDK | puste/stare OpenAPI i mockowe contracts | kontrakt platformy musi być generowany, wersjonowany i testowany z konsumentami |
| 14 — panel | owner flow, shipping/tax, editor revisions, recovery | self-service dopiero po pełnym owner golden path |
| 15 — storefront | outage maskowanie, consent/policies, stary E2E, SEO/a11y | storefront doctor i quality gate przed publicznym launch |

## Definicja „fundament gotowy”

Fundament Sklepika można nazwać gotowym do kontrolowanego launchu dopiero, gdy:

1. P0-C1 i P0-C2 są zamknięte dowodami runtime;
2. P0-W1 ma sandbox E2E oraz durable inbox/idempotency/reconciliation przed włączeniem online payments;
3. P0-P1 ma immutable release i migration artifact z fault-injected rollbackiem;
4. dwa realne tenanty przechodzą pełną macierz auth/data/money/jobs/cache/webhook bez cross-store read/write;
5. świeży owner przechodzi bez operatora od zweryfikowanego konta do sandbox order i sprawy posprzedażowej;
6. clean-host restore spełnia zatwierdzone RPO/RTO i wykrywa drift DB/R2/providerów;
7. publiczny storefront przechodzi build, aktualny checkout, fault injection, consent/policy evidence, mobile/cross-browser/a11y i SEO gates;
8. każdy gate ma aktualny artefakt PASS powiązany z wdrożonym digestem.

Do tego momentu właściwym komunikatem nie jest „platforma gotowa”, tylko: **„szeroki fundament produktu istnieje; launch jest kontrolowanie wstrzymany przez zidentyfikowane i mierzalne granice bezpieczeństwa, pieniędzy, danych i operacji.”**
