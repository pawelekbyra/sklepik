# Ekonomia i architektura fabryki sklepów

**Data modelu:** 2026-07-14  
**Skale:** 10 / 100 / 1 000 / 10 000 sklepów  
**Cel:** wskazać, kiedy repozytorium i projekt Vercel per sklep jest przewagą, a kiedy staje się kosztem operacyjnym.

## Werdykt

Osobny projekt Vercel dla każdego sklepu jest świetnym mechanizmem demonstracyjnym i sensownym produktem premium, ale nie powinien być jedynym sposobem obsługi 10 000 sklepów. Sam ruch może być tani; koszt eksploduje przez **build fan-out, konfigurację, domeny, awarie, support i niejednorodne wersje**.

Rekomendacja:

- do ok. 100 sklepów można utrzymać projekt per sklep, jeśli kod pochodzi z jednego template'u i istnieje centralny control plane;
- między 100 a 1 000 przejść na hybrydę: wspólny artefakt lub multi-tenant storefront dla standardowych sklepów, dedykowane projekty dla premium/niestandardowych;
- przy 1 000+ domyślny storefront powinien być multi-tenant z routingiem domeny i wersjonowanym dokumentem sklepu; osobne repo nie może być źródłem treści;
- backend commerce i dane powinny pozostać logicznie multi-tenant, z możliwością wydzielenia „noisy tenant” lub regulowanej marki do osobnej komórki infrastruktury.

Najważniejszy koszt jednostkowy to nie Vercel/Postgres. To minuty ludzkiej obsługi. Przy 10 000 sklepów każde 10 minut miesięcznie na sklep oznacza 1 667 godzin pracy.

## Metoda i jawne założenia

Model nie jest prognozą faktury. To parametryzowany scenariusz „lekki SMB”; ceny dostawców są migawką i bez VAT.

### Założenia bazowe miesięczne

| Parametr na sklep | Wartość modelowa |
|---|---:|
| aktywne sklepy | 30% wszystkich |
| pageviews aktywnego / nieaktywnego | 5 000 / 200 |
| zamówienia na aktywny sklep | 20 |
| DB: dane + indeksy średnio | 0,10 GB/sklep + 5 GB platformy |
| media | 0,50 GB/sklep |
| e-maile transakcyjne | 4 / zamówienie + 20/sklep |
| AI onboarding jednorazowo | $2/sklep, z limitem i tańszym modelem |
| AI operacyjne | $0,50/aktywny sklep/mies. przed kampaniami premium |
| support po automatyzacji | 10 min/aktywny sklep/mies. + 1% sklepów × 30 min incydentu |
| koszt pełnej godziny supportu | $20; jawna zmienna, nie stawka rynkowa |

Własne realne dane muszą zastąpić każde założenie. Najważniejsze rozkłady mają długi ogon: jeden popularny sklep może kosztować więcej niż setki pustych.

## Wolumen bazowy

| Wszystkie sklepy | Aktywne | Pageviews/mies. | Zamówienia/mies. | DB GB | Media GB | E-maile/mies. |
|---:|---:|---:|---:|---:|---:|---:|
| 10 | 3 | 17 tys. | 60 | 6 | 5 | 440 |
| 100 | 30 | 170 tys. | 600 | 15 | 50 | 4 400 |
| 1 000 | 300 | 1,7 mln | 6 000 | 105 | 500 | 44 000 |
| 10 000 | 3 000 | 17 mln | 60 000 | 1 005 | 5 000 | 440 000 |

## Fakty cenowe 2026

- Vercel Pro ma bazę zespołową/per-seat i kredyt infrastrukturalny, a zasoby są usage-based; Fast Data Transfer obejmuje pierwsze 1 TB, Edge Requests pierwsze 10 mln. Ceny regionalne zaczynają się od $0,128/CPU-h, $0,0106/GB-h pamięci, $0,60/mln wywołań, a transfer ponad pulę ok. $0,15–0,35/GB ([Vercel pricing](https://vercel.com/pricing), [regional pricing](https://vercel.com/docs/pricing/regional-pricing)). Nie należy mnożyć $20 przez liczbę projektów bez sprawdzenia kontraktu — projekty współdzielą billing zespołu.
- Neon Launch: $0,106/CU-h i $0,35/GB-mies.; Scale: $0,222/CU-h, storage $0,35/GB-mies., z dłuższą retencją/eksportem logów; compute może scale-to-zero ([Neon pricing](https://neon.com/pricing)).
- Cloudflare R2 Standard: $0,015/GB-mies., $4,50/mln zapisów klasy A, $0,36/mln odczytów klasy B i brak opłaty egress; free 10 GB, 1 mln A i 10 mln B ([R2 pricing](https://developers.cloudflare.com/r2/pricing/)).
- Resend transactional: $20/50 tys. e-maili, $35/100 tys., $350/500 tys., overage od $0,90 do $0,70/1 tys. zależnie od planu ([Resend pricing](https://resend.com/docs/knowledge-base/what-is-resend-pricing)).
- Upstash PAYG: $0,20/100 tys. komend i $0,25/GB-mies. ponad bezpłatną pulę; fixed od $10/250 MB i $20/1 GB. Przy stałym dużym ruchu fixed/node może być tańszy niż per-command ([porównanie Upstash 2026](https://upstash.com/blog/redis-pricing-comparison-every-major-provider-in-2026-with-numbers)).

To ceny katalogowe, nie rekomendacja konkretnych vendorów. Obecny backend Rails/Spree może działać na innym hostingu; model jednostek pozostaje ten sam.

## Trzy warianty architektury

| Cecha | A. Repo + projekt per sklep | B. Multi-tenant storefront | C. Hybryda rekomendowana |
|---|---|---|---|
| izolacja awarii/deploy | wysoka per storefront | wspólna blast radius | standard wspólny, premium osobno |
| custom code | naturalny | wymaga systemu sekcji/flags | dedykowane wyjątki |
| aktualizacja bezpieczeństwa | fan-out N deployów | jeden deploy | kilka kanałów release |
| onboarding domeny | N projektów i automatyzacja API | domena → tenant | oba |
| cold/build cost | rośnie z N projektów | amortyzowany | kontrolowany |
| obserwowalność | N strumieni do agregacji | jeden kontekst + tenant tag | centralna |
| rollback | per sklep łatwy, flota trudna | wspólny artefakt + dokument wersji | kanał + store override |
| ryzyko noisy neighbor | frontend niskie | wyższe | quotas + wydzielenie |
| przenośność klienta | wysoka, jeśli repo kompletne | eksport danych/layoutu potrzebny | premium export |
| sensowna skala | 10–100, wybrane premium | 1 000–10 000+ | 100–10 000+ |

### Ważna korekta modelu „repo per klient”

Nie forkować całego produktu i nie dopuszczać rozjazdu. Repo/projekt sklepu powinien zawierać co najwyżej manifest, branding i świadome rozszerzenia. Commerce, schema dokumentu i renderer mają wersjonowany upstream. Aktualizacja floty to promocja jednego artefaktu przez kanały `canary → stable`, nie 10 000 ręcznych pull requestów.

## Orientacyjny koszt zmienny — scenariusz bazowy

Poniższe widełki są modelowym budżetem, nie sumą gwarantowanych cenników. Zawierają storefront/CDN, backend compute, DB, cache/jobs, media, e-mail, observability/backups i lekkie AI; nie zawierają PSP, domen, podatków, ads ani supportu ludzkiego.

| Sklepy | Platform infra/mies. | Support modelowy/mies. | AI onboarding jednorazowo dla kohorty | Koszt infra/sklep | Dominujące ryzyko |
|---:|---:|---:|---:|---:|---|
| 10 | $100–300 | ~$12 | $20 | $10–30 | koszt minimalnej produkcji i czas założyciela |
| 100 | $250–700 | ~$120 | $200 | $2,50–7 | automatyzacja domen/deploy i support |
| 1 000 | $900–3 000 | ~$1 200 | $2 000 | $0,90–3 | build fan-out, DB queries, kolejki, observability |
| 10 000 | $5 000–18 000 | ~$12 000 | $20 000 | $0,50–1,80 | ludzie, blast radius, długi ogon ruchu, compliance |

Support obliczono z jawnego założenia: 10 min × aktywny sklep + 0,5 h × 1% wszystkich, po $20/h. Bez automatyzacji i dobrego produktu może być wielokrotnie wyższy. AI onboarding jest kosztem kohorty, nie stałym miesięcznym rachunkiem; powinien być pokryty opłatą launch.

### Sensitivity: co naprawdę zmienia rachunek

| Zdarzenie | Skutek | Ochrona |
|---|---|---|
| każdy commit buduje N projektów | build minutes rosną liniowo z flotą | ignored builds, immutable artifact, release cohorts |
| 1 sklep generuje 50% ruchu | wspólny koszt i ryzyko SLO | per-tenant metering, cache, quota, wydzielenie premium |
| obrazy bez limitu | storage jest tani, transformacje i transfer mniej | limity, WebP/AVIF, warianty, lifecycle, CDN |
| agent AI bez budżetu | runaway tokens/loops | per-tenant budget, rate limit, cache, tańszy model, approval |
| 30 min support/sklep | przy 10k = 5 000 h/mies. | onboarding, self-service, telemetry, płatne concierge |
| pełne logi bez sampling/retencji | observability rośnie z eventami | strukturalne metryki, sampling, tiered retention |

Publiczny przykład z Vercel Community opisuje $602, z czego $601 stanowiły build minutes po budowaniu sześciu projektów monorepo na każdy push. To anegdota, nie benchmark, ale dobrze ilustruje fan-out ([wątek 2026](https://community.vercel.com/t/outrageous-billing-on-a-monorepo/34129)).

## Koszty per warstwa i projektowe zasady

### Storefront/Vercel

- standardowe sklepy: jeden artefakt, routing po domenie i cache key zawierający tenant/document version;
- dedykowany projekt tylko dla custom runtime, izolacji kontraktowej lub premium SLA;
- build raz, promuj wiele; brak pobierania całego katalogu do statycznej generacji na każdy deploy;
- spend limits, WAF/rate limits, cache hit ratio i usage attribution per store.

### Backend Rails, Postgres, Redis/Sidekiq

- jedna logiczna baza z `store_id` i testami izolacji jest ekonomiczna do tysięcy lekkich tenantów;
- indeksy zawsze zaczynające się od tenant/key użycia, connection pooling, brak N+1 i query budgets;
- Sidekiq queues per class/priority, tenant fairness i idempotent jobs; ciężkie importy/AI poza requestem;
- Redis nie jako źródło prawdy; przy małej skali PAYG, przy stałych milionach komend fixed/node;
- sharding dopiero po metrykach: rozmiar, IOPS, p95 query, lock contention, backup/restore time, noisy tenant.

### Media/CDN

Przy założeniu 0,5 GB/sklep R2 storage wynosi około $0 przy 10 sklepach, $0,60 przy 100, $7,35 przy 1 000 i $74,85 przy 10 000 po free tier. To pokazuje, że sama pojemność obrazów nie jest problemem; operacje, transformacje, cache misses i jakość pipeline'u są ważniejsze.

### E-mail

Model 44 tys. e-maili dla 1 000 sklepów mieści się w okolicy planu 50 tys. za $20; 440 tys. przy 10 000 zbliża się do planu 500 tys. za $350. Trzeba osobno liczyć marketing contacts/sends, dedicated IP, reputację per merchant i bounce handling. Nie tworzyć domeny wysyłkowej per sklep bez automatycznego DNS/warmup i modelu odpowiedzialności.

### AI

Nie przyjmować jednego kosztu „AI call”. Mierzyć per feature:

`koszt_AI = input_tokens × rate + output_tokens × rate + obrazy + retry + retrieval + review`

Każda generacja ma `store_id`, feature, model, koszt, latency, wynik akceptacji i wartość biznesową. Tanie modele do klasyfikacji/importu, mocniejsze tylko do trudnych wyjątków. Cache po hash źródła; brak ponownego generowania niezmienionego katalogu. Koszt kampanii premium przenieść do planu/usage, nie subsydiować wszystkim.

### Observability, backup i bezpieczeństwo

- metryki SLO globalnie i per tenant; trace sampling z zawsze-on dla błędów/checkout;
- oddzielić audit log (trwały) od debug log (krótka retencja);
- backup bez testu restore nie jest zabezpieczeniem; mierzyć RPO/RTO i regularnie odtwarzać;
- secret rotation, RBAC/MFA, dependency scanning, tenant isolation tests i incident runbooks;
- przy 10k rozważyć komórki (cells) po 1–2 tys. sklepów, ograniczające blast radius.

## Unit economics

Definicje:

- `CM1 = przychód abonamentowy + launch/usage amortyzowane – PSP/platform variable – infra – AI – e-mail`;
- `CM2 = CM1 – support – success/customer operations`;
- `payback = CAC / miesięczny CM2`;
- osobno kohorty self-service, concierge, agency i premium isolated.

### Przykładowe scenariusze, nie rekomendowany cennik

| Plan | Przychód/mies. | Infra+AI+mail | Support | CM2 przed CAC | Warunek sensowności |
|---|---:|---:|---:|---:|---|
| self-service | 79 zł | 8–20 zł | 5–15 zł | 44–66 zł | wysoka automatyzacja, niski churn |
| guided | 199 zł | 15–35 zł | 25–60 zł | 104–159 zł | agent ogranicza ręczną pomoc |
| concierge | 599 zł | 25–80 zł | 120–250 zł | 269–454 zł | jasno ograniczony zakres i SLA |
| agency/premium isolated | 1 500+ zł | 80–300 zł | 250–600 zł | 600–1 170+ zł | custom work wyceniany oddzielnie |

Opłata launch powinna pokrywać AI onboarding, pracę człowieka, domenę/setup i ryzyko nieaktywnego klienta. Darmowe sklepy nie mogą generować pełnego projektu/deploy i kosztów operacyjnych bez limitu; draft może żyć we wspólnym środowisku do płatnej publikacji.

## Punkty zmiany architektury

Nie migrować tylko dlatego, że osiągnięto liczbę sklepów. Używać triggerów:

| Trigger przez 2–4 tygodnie | Decyzja |
|---|---|
| fan-out build/deploy >20% kosztu lub release >30 min | wspólny artefakt i release orchestration |
| projekty/domeny powodują >1% nieudanych onboardingów | control plane + shared storefront default |
| p95 API przekracza SLO przy poprawnych query | read cache/replica, następnie scale compute |
| jedna grupa tenantów >30% DB load | quota, przeniesienie do cell/dedicated DB |
| restore całej bazy nie spełnia RTO | PITR + cell/shard + tenant export strategy |
| support >15 min/active store/mies. | zatrzymać wzrost i naprawić onboarding/produkt |
| infra+AI >20% revenue lub CM2 <60% w self-service | zmienić limity/cenę/architekturę |

## Rekomendowana ewolucja

### 0–100 sklepów

- zachować obecną fabrykę repo/projekt, ale dodać centralny rejestr sklepu, deployment status, template version i koszt;
- jeden upstream storefront, automatyczne aktualizacje i test canary;
- shared Rails/Postgres/Sidekiq; metering per tenant od pierwszego dnia;
- nie optymalizować serwerów przed zmierzeniem supportu.

### 100–1 000

- wdrożyć shared multi-domain storefront dla standardowego planu;
- osobne projekty jako premium/escape hatch;
- kolejki import/AI, quotas, spend caps, dashboards cohort/tenant;
- cell-ready tenant routing i procedura przenoszenia tenantów.

### 1 000–10 000

- kilka cells backend+DB/queues, centralny identity/billing/control plane;
- stateless storefront + cache/versioned documents; rollout cohorts;
- 24/7 alerting/on-call adekwatny do przychodu, tested restore/DR;
- kontrakty enterprise z vendorami dopiero po rzeczywistym usage i negocjacji egress/support.

## Eksperymenty 14/30/90 dni

### 14 dni

1. Dodać metering: build minutes, requests, transfer, DB time/rows, Redis commands, jobs, e-mail, AI tokens i support minutes — wszystko z `store_id`.
2. Zbudować arkusz/kalkulator z trzema percentylami ruchu, nie średnią.
3. Zmierzyć pełne utworzenie 10 sklepów: czas automatu, błędy, build i ludzka interwencja.
4. Test restore na kopii i zmierzyć RPO/RTO.

### 30 dni

1. Prototyp jednego shared storefront obsługującego 10 domen i te same dokumenty layoutu.
2. Porównać projekt-per-store versus shared: TTFB/cache, deploy time, koszt, rollback i customizację.
3. Wprowadzić limity AI/import/media oraz spend alerts/hard caps.
4. Automatyzować DNS/domain verification i failed-provisioning reconciliation.

### 90 dni

1. Canary → stable rollout dla całej floty i automatyczny rollback.
2. Symulacja 1 000 tenantów i jednego noisy tenant; test fairness kolejek i DB.
3. Pilotaż 20 sklepów: 10 shared, 10 dedicated; policzyć CM2 i support, nie tylko cloud bill.
4. Podjąć decyzję: dedykowany deploy jako domyślny, premium czy tylko custom — na podstawie danych.

## Dashboard zarządczy

Mierzyć co tydzień:

- MRR, ARPU, gross margin CM1/CM2 i CAC payback per plan/kohorta;
- koszt infra, AI, mail i support per aktywny sklep oraz per zamówienie;
- aktywacja: draft → płatność → live → pierwsze zamówienie;
- p50/p95/p99 traffic i koszt tenantów, cache hit, DB p95, queue delay;
- build fan-out, deploy failure, template version lag i mean time to patch;
- support minutes, contact rate, reopen rate i przyczyna;
- churn, store inactivity, domeny wygasające i koszt „martwego” sklepu;
- RPO/RTO, restore success, incydenty izolacji i SLO checkout.

## Poziom pewności i decyzja końcowa

**Wysoka pewność:** ludzki support i fan-out operacyjny rosną szybciej niż prosty storage; wspólny artefakt redukuje koszt floty; per-tenant metering jest konieczny.  
**Średnia:** progi 100/1 000 są rozsądnymi etapami organizacyjnymi, ale nie twardymi limitami technicznymi.  
**Niska bez telemetrii:** konkretne widełki całkowitego kosztu i opłacalność repo per sklep — zależą od ruchu, buildów, hostingu backendu, SLA i pracy ludzi.

Decyzja na dziś: nie porzucać „fabryki” — sformalizować ją jako control plane. Jednocześnie zbudować wspólną ścieżkę storefrontu zanim liczba sklepów wymusi migrację pod presją.

