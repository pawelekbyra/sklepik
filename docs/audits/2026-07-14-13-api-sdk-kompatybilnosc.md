# Audyt 13 — API, SDK i kompatybilność

**Data:** 2026-07-14
**Baseline:** backend/admin `9a4f693147`, storefront `0f83b94`
**Zakres:** Store/Admin API v3, Alba, `sdk-core`, oba SDK, dashboard, storefront, OpenAPI i `@sklepik/test-contracts`
**Charakter:** audyt statyczny i typechecki; bez zmian produktu i produkcyjnych wywołań

## Werdykt

Połączenie Rails–SDK–UI działa dla obecnego demo, ale nie jest jeszcze zarządzanym kontraktem platformy. Store Factory i edytor są podłączone ręcznie, poza pipeline'em OpenAPI → generated types → SDK → consumer contract. `docs/api-reference/store.yaml` ma **0 B**, a Admin OpenAPI z 2026-07-11 nie zawiera funkcji dodanych 14 lipca. Nie znaleziono nowego P0; są 2 nowe P1 i 5 P2. Istniejące P0/P1 z audytów 04/07/11/12 nadal blokują sprzedaż.

| Flow | Rails | Konsument | Generated/OpenAPI | Realny gate |
|---|---|---|---|---|
| katalog | tak | Store SDK/storefront | częściowo | tylko podstawowy shape |
| cart/checkout/customer | tak | Store SDK/storefront | generated | brak prawdziwej płatności/lifecycle |
| admin commerce | tak | Admin SDK/dashboard | częściowo | brak CDC |
| layout | tak | Admin SDK + raw Store request | ręczne, brak OpenAPI | controller RSpec |
| signup/provisioning/readiness | tak | Admin SDK/dashboard | ręczne, brak OpenAPI | częściowe unit |

## Findings

### API-001 — P1 — referencje API nie opisują wdrożonego produktu

**Dowód (fakt):** `docs/api-reference/store.yaml` ma 0 B. `admin.yaml` ma 133 paths, ale ostatni commit to `31dc308c09` (2026-07-11) i brak w nim `auth/signup`, `stores`, `provisioning_run`, `store/readiness`, `store/launch`, `storefront_page`. Trasy istnieją w `spree/api/config/routes.rb:58-59,112-132`; Store Factory/layout weszły w `31532f602b` 2026-07-14. Generated types nie zawierają `StorefrontPage`/`ProvisioningRun`; komentarz `admin-sdk/src/types/provisioning.ts:1-5` nazywa typ ręcznym substytutem.

**Wpływ:** partner/agent nie ustali wspieranego API; breaking change może przejść przy zielonym TS. Generator klienta odtworzyłby starszy produkt.

**Naprawa:** naprawić oba generatory, dodać rswag examples i CI gate route/serializer → typelizer → Zod → OpenAPI → SDK → clean diff; pusty/mniejszy artefakt ma czerwienić CI.

**Test zamykający:** czysty checkout regeneruje oba YAML-e i typy bez diffu; route coverage obejmuje wszystkie publiczne operacje; generated client wykonuje signup → provisioning → draft/publish/public read → readiness/launch.

### API-002 — P1 — retry mutacji obiecuje bezpieczeństwo bez atomowej idempotencji

**Dowód (fakt; cross-reference `MONEY-006`):** `sdk-core/request.ts:192-229` auto-generuje `Idempotency-Key` dla każdej mutacji i retry po 5xx/network error. Backend robi osobne cache `read`, efekt i `write` (`idempotent.rb:32-61`), więc równoległe requesty mogą oba przejść. Namespace najpierw używa publicznego klucza sklepu, nie aktora/koszyka (`:69-74`). Changelog mówi „safe automatic retries” bez rezerwacji `in_progress`, trwałej tabeli i potwierdzonego shared cache.

**Wpływ:** timeout/retry może podwoić payment/refund/complete/provisioning.

**Naprawa:** trwała atomowa rezerwacja `(tenant, actor/cart, endpoint, key)` z fingerprintem, stanem i odpowiedzią; do tego czasu auto-retry money/provisioning wyłącznie opt-in.

**Test zamykający:** 20 równoległych requestów przez dwa procesy plus zerwanie odpowiedzi daje jeden efekt; reszta replay/`in_progress`; inny body z tym kluczem jest odrzucony.

### API-003 — P2 — transport traci kontrakt błędu poza idealnym JSON-em

**Dowód (fakt):** non-2xx bezwarunkowo robi `response.json()` i cast; `SpreeError` bez guarda czyta `response.error.*` (`sdk-core/request.ts:49-58,233-235`). Empty/HTML/malformed/502 przed Rails daje `SyntaxError`/`TypeError` bez statusu/request ID. `Retry-After` obsługuje tylko integer sekund (`:221-225`).

**Wpływ:** UI/monitoring traci status, a handler refresh wymaga poprawnego `SpreeError`.

**Naprawa/test:** defensywny parser content-type + runtime guard i stabilny error z status/code/requestId/headers; testy 401/422/429/502 dla canonical/flat JSON, empty, HTML, malformed i obu formatów Retry-After.

### API-004 — P2 — kontrakt layoutu jest ręcznie skopiowany w trzech miejscach

**Dowód (fakt):** `schemaVersion: 1`, `hero`, `product_grid`, `button` istnieją osobno w Rails, `admin-sdk/src/types/storefront-page.ts` + Zod dashboardu i `sklepikFront/src/lib/data/storefront-page.ts`. Storefront omija Store SDK przez generic `request<PublishedStorefrontPage>`; brak generated/runtime validation.

**Wpływ:** edytor może zapisać dokument łamiący starszy renderer.

**Naprawa/test:** jedno wersjonowane JSON Schema/Zod/OpenAPI, migratory i first-class Store SDK accessor; fixtures każdej wersji Rails → SDK → oba UI, kontrolowany fallback unknown/future schema.

### API-005 — P2 — kontrakt webhooka zaprzecza runtime i testom

**Dowód (fakt; `TENANT-004`, `SPREE-008`):** `Spree::Event` ma `store_id`, lecz `WebhookEventSubscriber#build_payload` go pomija (`:68-76`); SDK type też go nie ma. `@sklepik/test-contracts`/README twierdzą odwrotnie. Helper przyjmuje `Record`, nie SDK type, i nie należy do `runAllIsolationTests`.

**Wpływ:** receiver nie ma podpisanej tożsamości tenantowej, a niewykonywany helper wygląda jak gate.

**Naprawa/test:** wersjonowany envelope z tenant ID/schema version i generated type; realne eventy dwóch sklepów do receivera, podpis i tenant verified; usunięcie pola czerwieni główny runner.

### API-006 — P2 — „contract tests” są unit testami mocków

**Dowód (fakt):** pakiet sprawdza store, product list, create cart i reject missing product. Vitest używa obiektu `as unknown as Client`, bez Rails/transportu. Brak auth/customer/addresses/items/complete/payments/admin/layout/signup/provisioning/422/429. README opisuje live fixtures, ale nie ma CI runnera.

**Wpływ:** każda warstwa może być zielona na własnym mocku mimo niezgodnego wire contract (`TENANT-003`, `INV-006`, `MONEY-004..007`).

**Naprawa/test:** consumer-driven contracts storefrontu/dashboardu i provider verification na Postgres/Redis dla krytycznych flow, dwóch tenantów oraz aktualnej i poprzedniej wersji konsumenta.

### API-007 — P2 — brak polityki wersjonowania i deprecacji

**Dowód (fakt):** stałe `/v3`, `info.version: v3` i osobne changelogi, ale brak definicji breaking change, okresu wsparcia starego storefrontu, versioning event/layout, capabilities i rollback matrix. Deprecacja `CustomField#type` mówi „future minor” bez daty/telemetrii/testu starego klienta.

**Wpływ:** nowy backend może złamać starsze deploymenty Store Factory.

**Naprawa/test:** SemVer kontraktu niezależny od engine, additive-only active major, deprecation window, telemetryka/fleet version matrix; breaking-change detector i provider test najstarszej wspieranej wersji.

## Potwierdzenia, testy i ograniczenia

- `sdk-core` dobrze centralizuje headers/context/list params/retry/error — dobra baza pod `@sklepik/*` (`INV-002`, `SPREE-001..005`).
- Admin SDK rozdziela secret key/JWT, dodaje `X-Spree-Store-Id` i ma handler 401.
- Typecheck Store SDK, Admin SDK + examples i test-contracts: **pass**. To zgodność TS, nie runtime.
- SDK Vitest nie wystartował: sandbox odmówił utworzenia `node_modules/.vite-temp` (`ENOENT`). Rails/rswag i produkcyjne API nie były uruchamiane.
- Storefront ma `as unknown as` na `Order → Cart` i fallback pagination; skutki należą też do audytów 07/15.
- Martwy `PriceListsController#prices` jest już w F12/`INV-003`; payment/webhook findings są w MONEY/ASYNC i nie zostały zdublowane.

Przejrzano routes, bazowe controllers/concerns, krytyczne kontrolery/serializery, oba SDK, cały sdk-core, ręczne/generated boundaries, OpenAPI, webhook envelope, dashboard hooks i storefront adapters. Nie porównano ręcznie wszystkich 133 Admin endpoints pole-po-polu — to powinien robić generator/diff. Nie wykonano payment/provisioning ani dwóch wersji storefrontu.

## Kolejność domknięcia

1. `API-002`/`MONEY-006` wraz z istniejącymi P0.
2. `API-001` bez ręcznej edycji YAML.
3. `API-004/005`, następnie realne CDC `API-006`.
4. Parser `API-003` i fleet policy `API-007`.

Audyt jest zamknięty, gdy OpenAPI są niepuste/kompletne, regeneracja deterministyczna, Store Factory/layout bez ręcznych kopii, money mutations mają atomową idempotencję, webhook wersjonowany tenant-aware envelope, a CI wykonuje API→SDK→UI contracts dla dwóch tenantów i dwóch wspieranych wersji konsumenta.
