# Agent prowadzący do pierwszej sprzedaży

**Data badania:** 2026-07-14  
**Cel:** zaprojektować system „next best action”, który kończy pracę, ale nie podejmuje nieodwracalnych decyzji bez właściciela.

## Werdykt

Agent nie powinien być chatem ani generatorem ogólnych porad. Powinien być **maszyną stanu prowadzącą sklep przez mierzalne kamienie milowe**: oferta → gotowość → publikacja → ruch kwalifikowany → koszyk → pierwsza opłacona i możliwa do realizacji sprzedaż.

Pierwsza wersja nie potrzebuje ML rankingowego. Reguły, jawne prerekwizyty i scoring wystarczą. LLM tłumaczy, tworzy drafty i wywołuje allowlistowane narzędzia. Dopiero dane z setek realnych rekomendacji pozwolą uczyć ranking.

North Star nie może być „liczba wygenerowanych treści”. To `median time-to-first-valid-sale`, z guardrailami: refund/fraud, marża, błędy prawne, koszt reklamy i zadowolenie właściciela.

## Fakty, wnioski i pewność

**Fakty:** Shopify Sidekick w 2026 wykonuje wieloetapowe zadania, buduje kolekcje/kampanie, analizuje pricing i podaje proaktywne sugestie; jest w planie Shopify ([Sidekick](https://www.shopify.com/sidekick), [Winter '26](https://www.shopify.com/editions/winter2026)). 72% badanych firm mierzących GenAI formalnie skupia ROI na produktywności i incremental profit ([Wharton 2025](https://knowledge.wharton.upenn.edu/special-report/2025-ai-adoption-report/)). Badania terenowe wskazują kontekstowe efekty AI w reklamie i retailu, nie uniwersalny uplift ([AI advertising field experiment](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5389646), [retail personalization 2026](https://www.sciencedirect.com/science/article/pii/S0969698926001256)).

**Wniosek:** moat Sklepika nie leży w modelu, ale w stanie commerce, właściwych narzędziach, bezpieczeństwie, pamięci decyzji i danych o tym, które działanie faktycznie doprowadziło podobny sklep do sprzedaży.

Pewność: wysoka dla rule-first/approval; średnia dla sekwencji milestones; niska dla upliftu bez eksperymentu.

## Definicja pierwszej sprzedaży

`first_valid_sale` spełnia wszystkie warunki:

- payment captured/confirmed;
- brak flagi test/fraud/cancel w oknie np. 72 h;
- zamówienie ma stock, dostawę i możliwość fulfilment;
- gross margin po opłatach nie jest ujemna;
- nie jest zakupem właściciela/zespołu ani sztucznym eventem.

Osobno mierzyć `first_cart`, `first_checkout`, `first_paid`, `first_fulfilled`, bo każdy wskazuje inny bloker.

## Maszyna stanu

| Stan | Warunek wyjścia | Typowy next best action |
|---|---|---|
| IDEA | segment i produkt opisane | dodaj/importuj 3 realne produkty |
| CATALOG | produkt ma cenę, stock, zdjęcie, opis, warianty | wybierz hero product i ofertę startową |
| READY | merchant, policy, payment, shipping, GPSR/legal green | wykonaj test order i opublikuj |
| LIVE_NO_TRAFFIC | sklep live, mało kwalifikowanych sesji | udostępnij osobistej sieci / przygotuj 1 kanał |
| TRAFFIC_NO_PDP | ruch nie trafia/nie angażuje produktu | popraw landing/message-source match |
| PDP_NO_CART | sesje PDP bez add-to-cart | uzupełnij zdjęcia, delivery, trust, variant UX |
| CART_NO_CHECKOUT | koszyki bez checkout | pokaż koszt/termin dostawy i usuń friction |
| CHECKOUT_NO_PAY | rozpoczęcia bez płatności | sprawdź payment errors/metody/price shock |
| PAID | pierwsza ważna sprzedaż | fulfilment checklist, prośba o feedback/review |

Agent zawsze najpierw usuwa blokery integralności, potem pozyskuje ruch. Nie uruchamia reklam dla sklepu bez płatności, dostawy, polityk i poprawnych produktów.

## Model next-best-action

Każdy kandydat `Action` ma:

```text
id, goal, prerequisites[], blockers[], tool, expected_outcome,
effort_minutes, cash_cost, reversibility, risk,
evidence[], confidence, owner, expires_at, measurement_plan
```

Ranking v1:

```text
score = expected_progress × confidence × urgency
        - owner_effort - cash_cost - risk_penalty
```

Reguły twarde wyprzedzają score: legal/safety/payment blocker > growth. System pokazuje maksymalnie 1 główną i 2 alternatywne akcje, nie backlog 30 porad.

## Narzędzia agenta

| Narzędzie | Tryb domyślny | Approval |
|---|---|---|
| odczyt readiness/analytics/orders/catalog | automatyczny, tenant-scoped | nie |
| draft produktu/SEO/layout/policy checklist | automatyczny draft | przed publikacją |
| zmiana produktu/collections | patch preview | owner approve |
| publish storefront/product | przygotuj diff | owner approve |
| discount | limitowany draft z marżą i terminem | owner approve |
| e-mail/post | draft + audience preview | owner approve/send |
| ad campaign | plan/creative/budget cap | podwójna zgoda przed wydatkiem |
| refund/cancel/order change | sugeruj lub allowlist low-value | człowiek w MVP |
| legal/regulated claim | brak generowania jako faktu | specjalista |

Każdy call ma idempotency key, dry-run, precondition version, audit event i rollback/compensation gdy możliwe.

## Approval UX

Karta działania odpowiada na pięć pytań:

1. Dlaczego teraz? — dane i bloker.
2. Co dokładnie się zmieni? — diff, odbiorcy, koszt.
3. Jaki oczekiwany wynik i poziom pewności?
4. Jak cofniemy zmianę?
5. Co zmierzymy i kiedy ocenimy?

Tryby uprawnień per tool: `suggest_only`, `approve_each`, `approve_within_policy`, `auto`. Nowy sklep zaczyna w `approve_each`; auto dopiero po historii bezbłędnych wykonań.

## Bezpieczeństwo

- narzędzia nie przyjmują dowolnego kodu/SQL/URL; typed schemas i tenant checks;
- content ze sklepu, maili i URL-i jest nieufnym inputem, nie instrukcją systemową;
- RBAC agenta = RBAC użytkownika; brak cross-store memory;
- limity: dzienny cash, liczba wysyłek, maks. rabat, minimalna marża;
- PII redaction w prompt/log, retention i vendor DPA;
- nieodwracalne akcje przez outbox/workflow z reconfirmation;
- kill switch globalny, per tenant, per tool i per campaign;
- evaluator nie jest tym samym promptem/model-em, który wykonał akcję.

## Ewaluacja offline

Zbudować `StoreSnapshot` fixtures reprezentujące każdy stan i edge cases. Dla każdego ekspert definiuje dozwolone, najlepsze i zabronione akcje.

| Metryka | Próg MVP |
|---|---:|
| blocker detection recall | ≥95% |
| unsafe action rate | 0 dla krytycznych fixtures |
| top-1 action accepted by expert | ≥80% |
| tool args valid | ≥99% |
| correct tenant/permission | 100% |
| reproducibility przy tym samym stanie | ≥95% dla wyboru klasy akcji |

Red-team: prompt injection w opisach/CSV, zły store header, stale version, duplicated webhook, negative margin, regulated claims, fake analytics spike i partial payment.

## Ewaluacja online

Randomizować na poziomie sklepu, nie sesji właściciela:

- Control: checklista bez priorytetu.
- Treatment A: jedna regułowa next action.
- Treatment B później: AI draft + execution after approval.

Primary: odsetek `first_valid_sale` w 30 dni i median time-to-sale. Secondary: ready/live w 7 dni, action completion, accepted suggestion, owner minutes, support minutes. Guardrails: refunds, complaints, ad spend, unsubscribes, negative margin, override/rollback i unsafe incidents.

Nie przypisywać sukcesu ostatniej akcji. Logować exposure, execution, counterfactual cohort i cały funnel.

## MVP 30 dni

- event model + milestone calculator;
- 15–25 deterministycznych action recipes;
- read tools i 5 write tools: product draft, layout draft, test order guide, publish request, launch post/e-mail draft;
- approval inbox, diff, audit, outcome check;
- weekly digest, ale tylko jedna główna akcja naraz.

Bez autonomicznych ads, pricing, refunds, legal text publication i „chat with all data”.

## Eksperymenty 14/30/90 dni

### 14 dni

- 20 retrospektywnych journey maps właścicieli sklepów i etykiety blocker/action;
- instrumentacja milestones i definicja valid sale;
- concierge: człowiek wysyła jedną next action dziennie 10 pilotom;
- policy matrix tools/approval i 50 offline snapshots.

### 30 dni

- rule engine + approval UI + 5 tools;
- A/B checklista vs next action na nowych sklepach;
- koszt/minuty właściciela i supportu obok aktywacji;
- red-team oraz kill-switch drill.

### 90 dni

- 100+ sklepów lub raport „insufficient sample”; bez udawania significance;
- ranking uczony wyłącznie jeśli rule candidates mają wystarczającą ekspozycję;
- jeden mierzalny growth recipe, np. launch/win-back, z holdout;
- decyzja o `approve_within_policy` dla najbezpieczniejszych narzędzi.

## Kryteria kontynuacji

- ≥20% względnej poprawy first-valid-sale lub wyraźnie krótszy czas przy niegorszych guardrails;
- ≥50% rekomendacji wykonanych i ≥70% ocenionych jako pomocne;
- ≥30% mniej support minutes w treatment;
- 0 cross-tenant/critical unsafe action;
- koszt agenta <10% incremental contribution margin.

Jeżeli agent generuje aktywność, ale nie przesuwa milestones, uprościć go do lepszego onboardingu. Sukcesem jest sprzedaż możliwa do obsłużenia, nie spektakularna rozmowa.

