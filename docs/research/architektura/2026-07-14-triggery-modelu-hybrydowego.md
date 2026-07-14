# Policzalne triggery przejścia do modelu hybrydowego

**Data:** 2026-07-14  
**Kontekst:** obecny model może tworzyć repozytorium i projekt Vercel dla każdego sklepu; backend commerce jest wspólny.

## Werdykt

Nie należy przechodzić na shared storefront dlatego, że „100 sklepów brzmi dużo”. Migrację wyzwalają mierzalne koszty i ryzyko. Liczba sklepów jest proxy, nie przyczyną.

Docelowy model: **jeden wersjonowany renderer i dokumenty sklepów jako źródło prawdy; dwa sposoby uruchomienia tego samego kontraktu**:

1. shared multi-domain dla standardowych sklepów;
2. dedykowany projekt dla premium, custom code, izolacji/SLA lub eksperymentu.

Repo per shop może pozostać eksportem/manifestem i przewagą handlową. Nie może tworzyć tysiąca forków rdzenia.

## Fakty, założenia i pewność

- Vercel Pro ma miękki limit 100 000 domen na projekt, Enterprise 1 000 000, więc sam routing domen nie wymusza projektu per sklep ([Vercel limits, 2026](https://vercel.com/docs/limits)).
- Vercel wspiera rolling releases i instant rollback, ale rolling release jest w kontekście projektu; zarządzanie flotą N projektów nadal wymaga control plane ([Rolling Releases](https://vercel.com/docs/rolling-releases), [Rollback](https://vercel.com/docs/deployments/rollback-production-deployment)).
- GitHub ma secondary limits, m.in. 100 concurrent requests i ogólne ograniczenia tworzenia treści; provisioner musi mieć kolejkę/backoff, nie pętlę tworzącą tysiące repo ([GitHub rate limits 2026](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2026-03-10)).
- Cell architecture ogranicza blast radius przez routing tenantów do powtarzalnych komórek ([AWS cell router](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/serverless-cell-router-architecture.html)).

Pewność wysoka dla potrzeby control plane/wspólnego artefaktu; średnia dla progów poniżej — należy je skalibrować telemetrią.

## Trzy fazy

| Faza | Model | Warunek wejścia | Warunek wyjścia |
|---|---|---|---|
| A | projekt/repo per shop | produkt/pilot, mała flota, custom learning | dowolne 2 żółte triggery przez 4 tyg. lub 1 czerwony |
| B | hybryda | shared standard + dedicated premium | shared stabilny, backend noisy-neighbor lub operacje wymagają cells |
| C | shared + cells | multi-domain renderer, komórki backend/data/queues | dalsze podziały tylko przez SLO/regulacje/noisy tenants |

## Dashboard triggerów

### Żółte i czerwone progi

| Obszar | Żółty | Czerwony | Reakcja |
|---|---:|---:|---|
| release całej floty | >30 min | >2 h lub >5% version lag po 24 h | wspólny artefakt, cohorts |
| build fan-out | >2 buildy na zmianę sklepu albo >15% rachunku | >25% rachunku / build storm | shared runtime, ignored builds |
| deploy failure | >1% projektów/release | >3% lub rollback >30 min | idempotent orchestrator, shared default |
| version skew | >2 aktywne wersje >7 dni | security patch lag >24 h | wymuszone kanały wersji |
| provisioning | p95 >10 min lub >1% manual | >5% failed/stuck | control plane + reconcile loop |
| support deploy/domain | >5 min/sklep/mies. | >15 min | shared + self-healing domain flow |
| infra storefront | >10% MRR | >20% MRR | cache/shared, price/limits |
| observability | nie da się query po tenant/version | >15 min locate affected stores | central telemetry before growth |
| blast radius | jeden release psuje >10 sklepów | checkout SLO breach wielu sklepów | canary/cell isolation |
| DB noisy tenant | tenant >10% DB load | tenant >25% lub p95 breach | quota/dedicated/cell |

Reguła decyzji:

```text
phase_change = red_trigger
            OR count(yellow_trigger sustained >= 4 weeks) >= 2
            OR forecast(6 months) breaches red before migration lead time
```

Forecast jest ważny: migrację zaczyna się przed 1 000 sklepów, jeśli onboarding rośnie 100/mies. i przebudowa potrwa kwartał.

## Ekonomia porównawcza

Definicje miesięczne:

```text
C_dedicated = build_fanout + control_plane + config_drift
              + project_observability + support + runtime
C_shared    = shared_runtime + domain_routing + cache_invalidation
              + noisy_neighbor_risk + shared_oncall
```

Hybryda jest uzasadniona, gdy:

```text
savings_shared_standard
  > migration_amortized_12m + added_shared_risk_cost
```

Nie wystarczy porównać Vercel bill. Do kosztu dedicated wliczać minuty ludzi, failed deploys, patch lag i oczekiwaną stratę incydentu.

### Przykład decyzyjny

Przy 300 sklepach, jeśli release trwa 90 minut pracy automatu + 2 h operatora, występuje 3% błędów wymagających średnio 10 min, to jeden release kosztuje 5 h pracy. Przy 8 release/mies. = 40 h. Shared storefront redukujący to do 4 h/mies. oszczędza 36 h; przy $30/h daje $1 080/mies. Jeśli migracja kosztuje $20 tys., sam ten efekt zwraca się w 18,5 miesiąca — zbyt wolno bez dodatkowych korzyści. Jeśli support/domain i build bill dodają $2 tys./mies., payback spada poniżej 7 miesięcy.

To przykład, nie estymacja Sklepika.

## Control plane wymagany w każdej fazie

`StoreDeployment`:

- store/tenant ID, plan i isolation tier;
- source manifest/repo/project/team/domain IDs;
- renderer/schema/template version + desired/current state;
- last deploy, health, rollback target, cost counters;
- secrets references, nie sekrety;
- provisioning workflow checkpoints i idempotency keys.

Reconciler stale porównuje desired/current state. UI pokazuje `provisioning`, `healthy`, `drifted`, `degraded`, `rollback` i pozwala ponowić bez duplikacji.

## Aktualizacja floty

### Dedykowane projekty

Nie otwierać PR w każdym repo dla każdej zmiany. Preferencje:

1. sklepy używają immutable versioned package/artefact;
2. manifest wskazuje release channel `canary`, `stable`, `pinned`;
3. orchestrator buduje tylko, gdy zmienia się artefakt lub manifest;
4. cohorts 1% → 10% → 50% → 100%, z automatycznymi gates;
5. security release ma deadline i raport lag.

### Shared

Jeden deploy + config/document version. Domain middleware rozwiązuje tenant, ale cache key zawsze zawiera tenant i published revision. Nie cache'ować ceny/stock w sposób pozwalający na cross-tenant leakage lub stale checkout.

## Rollback

Są trzy niezależne osie:

- **code rollback:** wskazanie poprzedniego deployment/artefaktu;
- **schema compatibility:** expand/contract, backward compatible API; rollback kodu nie cofa destrukcyjnej migracji;
- **content rollback:** published snapshot dokumentu/layoutu per store.

SLO:

| Operacja | Cel |
|---|---:|
| wykrycie regresji canary | <10 min |
| rollback shared code | <5 min |
| rollback jednego layoutu | <1 min |
| zidentyfikowanie affected tenants/version | <5 min |
| flota wraca do compliant security version | <24 h |

Vercel Instant Rollback działa routingowo bez rebuild, ale environment/config może być niespójny ze starym buildem; runbook musi to sprawdzać ([Instant Rollback caveats](https://vercel.com/docs/instant-rollback)).

## Cells

Cell = powtarzalny zestaw backend compute + DB/schema/partition + queues/cache, obsługujący ograniczoną liczbę tenantów. Global control plane/router zna przypisanie.

Wprowadzić cells, gdy co najmniej jeden warunek:

- projected restore/RTO wspólnej bazy przekracza SLO;
- tenant isolation incident dotyka zbyt dużej części MRR;
- jedna baza/queue osiąga 60–70% bezpiecznej stałej pojemności przy peak;
- upgrade/maintenance nie mieści się w oknie;
- regulacje/SLA wymagają izolacji/danych w regionie;
- noisy tenants są częste, a dedicated wyjątki stają się drugim systemem.

Nie ustalać cell size wyłącznie liczbą sklepów. Limitować jednocześnie aktywne sklepy, orders/sec, DB IOPS/storage, jobs/sec i MRR at risk. Przykład startowy 500–2 000 lekkich tenantów/cell jest hipotezą load testu.

## Strategia migracji bez big bang

1. Wyodrębnić renderer/schema i Store API contract.
2. Shared storefront obsługuje nowy testowy domain, czyta te same published docs.
3. Shadow/read parity i screenshot/contract tests.
4. 10 nowych sklepów domyślnie shared; dedykowane pozostają bez zmian.
5. Przełączać domeny istniejących tenantów kohortami, zachowując rollback DNS/alias.
6. Repo staje się export/extension, nie runtime requirement.
7. Dopiero po 30 dniach parity wyłączyć zbędne projekty.

## Mierniki

- fleet update lead time, success rate, version lag, builds per logical change;
- cost per deploy/store, build minutes i operator minutes;
- provision p50/p95, failure/reconciliation time;
- shared/dedicated traffic, cache hit, CWV, error and checkout SLO;
- incidents × tenants × MRR affected (blast-radius minutes);
- DB/queue top tenant share, throttle events, tenant moves;
- rollback MTTR i schema/content rollback success;
- CM2 osobno dla shared i dedicated planu.

## Eksperymenty 14/30/90 dni

### 14 dni

- metering obecnej fabryki i 10-projektowy synthetic fleet release;
- desired-state model/control-plane draft;
- raport wszystkich miejsc zależnych od repo/project;
- test rollback code/content/schema osobno.

### 30 dni

- shared multi-domain prototype dla 10 domen;
- ten sam sklep na shared/dedicated: parity, CWV, cache, koszt i release;
- cohorts + version headers/logging;
- load/provision chaos test z GitHub/Vercel rate limits.

### 90 dni

- 20–50 realnych shared storefronts, minimum jeden premium dedicated;
- policzyć żółte/czerwone triggery z 4 tygodni;
- noisy tenant + cell router tabletop/load test;
- formalna decyzja domyślnego modelu i cennika isolation tier.

## Decyzja

Budować shared path już teraz jako opcję i ubezpieczenie, ale nie migrować obecnych sklepów bez danych. Najpierw control plane i wspólny kontrakt — rozwiązują chaos niezależnie od modelu hostingu.

