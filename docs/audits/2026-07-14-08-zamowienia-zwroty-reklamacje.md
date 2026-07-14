# Audyt 08: zamówienia, fulfillment, zwroty i reklamacje

**Data:** 2026-07-14
**Baseline:** `sklepik` `9a4f693147`, `sklepikFront` `0f83b941f3`
**Charakter:** statyczny audyt pełnego cyklu posprzedażowego; bez zmian kodu, danych produkcyjnych i prawdziwych operacji pieniężnych
**Werdykt:** **nie uruchamiać samodzielnej obsługi prawdziwych zamówień**, dopóki ORDER-001–006 nie mają jednego, przetestowanego workflow. Samo przyjęcie płatności nie wystarcza: dziś właściciel potrafi oznaczyć wysyłkę i anulować zamówienie, ale nie potrafi bezpiecznie obsłużyć pełnego zwrotu ani reklamacji.

## Streszczenie wykonawcze

Silnik ma dojrzałe elementy domenowe odziedziczone z commerce core: maszyny stanów zamówienia, płatności, wysyłki, jednostki magazynowej, autoryzacji zwrotu, pozycji zwrotu i reimbursementu. Nowe Admin API v3 oraz panel udostępniają jednak tylko fragment: zamówienie, fulfillment i bezpośredni refund. Nie ma tras ani UI dla RMA/return authorization, fizycznego przyjęcia zwrotu, oceny pozycji, wymiany, reimbursementu ani reklamacji.

Najgroźniejsza niespójność dotyczy anulowania. SDK deklaruje powód, notatkę, decyzję o restocku, refundzie i powiadomieniu, lecz kontroler ignoruje wszystkie te pola. Panel pyta tylko „anulować?”. Rekord audytowy zapisuje wartości domyślne `false`, podczas gdy callback zamówienia zawsze anuluje wysyłki (co restockuje inventory) i wywołuje `cancel!` dla zakończonych płatności. Historia operacyjna może więc opisywać coś innego niż wykonane efekty zewnętrzne.

Przepływ wysyłki jest użyteczny: panel pokazuje fulfillment, tracking, ship i cancel, backend blokuje rekord zamówienia, a event `order.shipped` istnieje. Brakuje jednak spójnego sposobu cofania błędów, częściowych anulowań, zwrotów, reklamacji, SLA, komunikacji i reconciliation. Bez tego „mały mydlarz” musi rozwiązywać najtrudniejszą część e-commerce poza systemem.

## Zakres i metoda

Prześledzono kodowo:

- checkout `cart → address → delivery → payment → confirm → complete`, późniejsze `cancel/resume/return`;
- `Order`, `Shipment/Fulfillment`, `InventoryUnit`, `Payment`, `Refund`;
- `ReturnAuthorization`, `ReturnItem`, `CustomerReturn`, `Reimbursement` i typy reimbursementu;
- Admin/Store API v3, oba SDK, panel właściciela, konto klienta i webhooki e-mail;
- tenant scope, uprawnienia, blokady, retry/idempotencję, stock, aktora i audit trail;
- wymagane capabilities dla polskiej obsługi odstąpień i reklamacji — **nie wykonywano audytu prawnego i raport nie jest poradą prawną**.

Skala: **P0** utrata pieniędzy/towaru lub cross-tenant w aktywnej ścieżce; **P1** blokada bezpiecznej prawdziwej sprzedaży; **P2** wymagane przed skalą/self-service; **P3** jakość i dług. MONEY-xxx i AUTH-xxx są referencjami do audytów 07 i 05, nie duplikatami.

## Mapa rzeczywistych przepływów

| Obszar | Core | Admin API/SDK | Panel | Klient | Ocena |
|---|---|---|---|---|---|
| Złożenie i podgląd zamówienia | pełna maszyna checkout | tak | lista/detail/create/complete | guest token lub JWT | fundament działa |
| Fulfillment i tracking | pending/ready/shipped/canceled | CRUD + ship/cancel/resume/split | tracking, ship, cancel | status i tracking | częściowo działa |
| Anulowanie całego zamówienia | service + historia + efekty stock/payment | endpoint, lecz ignoruje parametry | prosty confirm | tylko status/e-mail | niespójne |
| Częściowe anulowanie | modele/operacje niskiego poziomu | brak jawnego workflow | brak | brak | niedostępne |
| Refund bez zwrotu | model i gateway call | list/create | brak UI | widok płatności | money-risk, patrz MONEY-006/008 |
| Autoryzacja zwrotu (RMA) | istnieje | brak tras v3 | brak | brak formularza | martwy core |
| Fizyczne przyjęcie zwrotu | `CustomerReturn` | brak tras v3 | brak | brak statusu | martwy core |
| Ocena pozycji | accept/reject/manual | brak tras v3 | brak | brak komunikacji | martwy core |
| Wymiana | model expedited exchange | brak tras v3 | brak | brak | martwy core |
| Reimbursement | original payment/store credit/exchange | tylko typy/serializery, brak workflow | brak | brak | martwy core |
| Reklamacja | brak osobnego agregatu/case | brak | brak | brak | nie istnieje |

## Znaleziska

### ORDER-001 — P1 — anulowanie ignoruje cały zadeklarowany kontrakt i zapisuje mylący audit trail

**Status dowodu:** fakt.

`OrderCancelParams` deklaruje `reason`, `note`, `restock_items`, `refund_payments`, `refund_amount` i `notify_customer` (`packages/admin-sdk/src/params.ts:204-212`). Kontroler przekazuje jednak wyłącznie aktora przez `@resource.canceled_by(...)` (`spree/api/app/controllers/spree/api/v3/admin/orders_controller.rb:64-69`). Panel nie zbiera żadnej decyzji — wysyła puste `orders.cancel(orderId)` po prostym potwierdzeniu (`packages/dashboard/src/routes/_authenticated/$storeId/orders/$orderId.tsx:181-185,295-313`).

Service zapisuje domyślnie `restock_items: false`, `refund_payments: false`, `notify_customer: false` (`spree/core/app/services/spree/orders/cancel.rb:22-39`), ale callback zawsze `cancel!`-uje wszystkie wysyłki i zakończone płatności (`spree/core/app/models/spree/order.rb:1121-1137`). Anulowanie wysyłki restockuje manifest (`spree/core/app/models/spree/shipment.rb:88-92,518-525`), a anulowanie płatności wykonuje zewnętrzne `payment_method.cancel` (`spree/core/app/models/spree/payment/processing.rb:88-91`). Flagi historii nie sterują skutkiem.

**Wpływ:** operator nie wybiera i nie widzi faktycznego zwrotu/restocku, a audit record może twierdzić „nie refundowano/nie restockowano”, mimo wykonania operacji. Gateway call odbywa się wewnątrz transakcji DB; jego skutku nie da się cofnąć rollbackiem. To nakłada się na MONEY-006 i MONEY-008.

**Rekomendacja:** jeden typowany `CancelOrder` command z wersją zamówienia, powodem, liniami/ilościami, decyzją stock, decyzją refund, kwotą, metodą, komunikacją i aktorem. Efekty zewnętrzne przez durable outbox/job z reconciliation; audit log zapisuje wynik, nie tylko zamiar. Usunąć martwe parametry albo naprawdę je egzekwować.

**Test zamykający:** macierz paid/authorized/offline × unshipped/partial/shipped × full/partial cancellation. Każdy wariant dowodzi dokładnie jednego restocku i refundu/voidu, zgodności historii z efektem, poprawnego zachowania po timeout/retry oraz braku częściowo cofniętego stanu po błędzie gatewaya.

### ORDER-002 — P1 — kompletne zwroty i reklamacje są nieosiągalne z produktu

**Status dowodu:** fakt.

Modele i serializery dla RMA, customer return i reimbursement istnieją, lecz routing Admin API v3 pod zamówieniem wystawia tylko items, fulfillments, payments, refunds, adjustments, gift cards i credits (`spree/api/config/routes.rb:354-386`). Admin SDK ma refundy, ale nie ma klientów operacyjnych dla return authorizations/customer returns/reimbursements (`packages/admin-sdk/src/admin-client.ts:1078-1101`). Panel zamówienia nie ma procesu zwrotu ani reklamacji.

**Wpływ:** właściciel może zrobić ręczny refund bez powiązania ze zgłoszeniem, paczką, pozycją, oceną, stockiem i odpowiedzią dla klienta. Nie da się wiarygodnie rozliczyć częściowego zwrotu, wymiany, odrzucenia ani reklamacji. To blokuje pierwsze prawdziwe sklepy bardziej niż brak funkcji marketingowych.

**Rekomendacja:** zbudować własny case/workflow Sklepika ponad istniejącymi primitives: `request → triage → authorized/declined → in_transit → received → inspected → resolution_approved → reimbursing → resolved`. Typ sprawy: odstąpienie, reklamacja niezgodności, uszkodzenie transportowe, goodwill; żądanie: naprawa, wymiana, obniżka, refund. Zachować osobne terminy, dowody, komunikację i outcome.

**Test zamykający:** E2E klient i owner dla pełnego/partial return, reklamacji z wymianą i odrzucenia; status klienta, stock, refund, dokumenty i eventy pozostają zgodne po każdym kroku i reloadzie.

### ORDER-003 — P1 — refund jest odłączony od przedmiotu, aktora i procesu zwrotu

**Status dowodu:** fakt; money execution opisuje MONEY-006/008.

Admin endpoint buduje `payment.refunds` jedynie z kwoty, powodu i pustego transaction ID (`spree/api/app/controllers/spree/api/v3/admin/orders/refunds_controller.rb:9-28`). Nie ustawia `refunder`, mimo że model ma to pole (`spree/core/app/models/spree/refund.rb:13-20`), nie wiąże reimbursement/return items i synchronicznie woła gateway w `after_create` (`refund.rb:22-31,76-112`). Refund reason fallback to pierwszy dostępny rekord może ukryć brak jawnego wyboru. SDK ma tę operację, ale bieżąca strona zamówienia w dashboardzie jej nie udostępnia.

**Wpływ:** po czasie nie wiadomo kto, za które sztuki, na jakiej podstawie i po jakiej decyzji oddał pieniądze. Sam refund nie przywraca spójnie inventory ani nie zamyka sprawy klienta.

**Rekomendacja:** bezpośredni refund tylko jako jawny „refund bez zwrotu” z wymaganym aktorem i powodem; standardowo refund generowany przez zatwierdzoną resolution. Wymagać item allocation, amount breakdown, currency, gateway ID, idempotency key, status i reconciliation.

**Test zamykający:** każdy refund ma admina/service account, reason, source case, pozycje lub jawny kod `no_return`, money breakdown i immutable gateway references; nie można zwrócić drugi raz tej samej alokacji.

### ORDER-004 — P1 — zwroty nie są bezpieczne na współbieżność i mogą podwójnie zmienić inventory

**Status dowodu:** fakt w algorytmie; exploit wymaga udostępnienia flow.

`CustomerReturn#after_create` synchronicznie wywołuje `receive!` na pozycjach (`spree/core/app/models/spree/customer_return.rb:19-24,83-86`). `ReturnItem` sprawdza wcześniejszy zakończony zwrot zapytaniem aplikacyjnym i anuluje inne rekordy callbackiem, lecz w bazie jest tylko zwykły indeks po `inventory_unit_id`, bez unikalnego constraintu chroniącego aktywną/zakończoną pozycję (`spree/core/app/models/spree/return_item.rb:256-269`; migracja `20210914000000_spree_four_three.rb:647-670`). `receive!` zmienia InventoryUnit na returned i może utworzyć StockMovement (`return_item.rb:191-207`). Brak order/inventory row lock w tym przepływie.

**Wpływ:** dwa requesty lub retry mogą przejść walidację jednocześnie, podwójnie próbować przyjąć tę samą ilość/restockować albo stworzyć sprzeczne return items. Ten obszar jest obecnie martwy z API, ale stanie się aktywnym P0 przy naiwnym wystawieniu endpointów.

**Rekomendacja:** serializować case/order/inventory unit, wprowadzić bazową integralność dla allocation, idempotency i atomowy stock ledger. Fizyczne przyjęcie paczki powinno być commandem, nie `after_create` z wieloma efektami.

**Test zamykający:** 20 równoległych accept/receive dla tej samej sztuki kończy się jednym accepted return, jednym transition InventoryUnit i jednym StockMovement; retry po crashu jest replayem, nie nową operacją.

### ORDER-005 — P1 — anulowany fulfillment można wysłać bez ścieżki resume, co omija ponowne zdjęcie stocku

**Status dowodu:** fakt w maszynie stanów i API.

Maszyna `Shipment` pozwala `ship` zarówno z `ready`, jak i `canceled` (`spree/core/app/models/spree/shipment.rb:82-89`). Dedykowany `resume` wykonuje `after_resume`, które ponownie unstockuje manifest (`shipment.rb:93-99,528-530`). Bezpośrednie `ship!` z canceled omija `after_resume`; kontroler `fulfill` nie ogranicza stanu przed `@resource.ship!` (`spree/api/app/controllers/spree/api/v3/admin/orders/fulfillments_controller.rb:48-57`). UI pokazuje ship tylko dla ready, ale secret-key/API client może wywołać trasę wprost.

**Wpływ:** anulowanie restockuje towar, a późniejsze bezpośrednie wysłanie może oznaczyć go shipped bez ponownego zdjęcia zapasu. Stan magazynowy i fizyczny towar rozjeżdżają się.

**Rekomendacja:** `fulfill` wyłącznie z `ready`; canceled wymaga jawnego `resume` i kontroli zamówienia/płatności. Jeżeli „ship canceled” jest potrzebne wewnętrznie, musi wykonać ten sam atomowy stock command.

**Test zamykający:** canceled→fulfill daje 422; canceled→resume→fulfill wykonuje dokładnie restock, unstock, ship i poprawne state changes. Test obejmuje niedostępny stock oraz anulowane zamówienie.

### ORDER-006 — P1 — flagi komunikacji nie kontrolują faktycznej wysyłki e-maili

**Status dowodu:** fakt w kodzie; aktywna subskrypcja/dostawca są runtime-dependent.

Complete i cancel publikują payload `notify_customer`, domyślnie false (`spree/core/app/services/spree/orders/complete.rb:20-21`; `orders/cancel.rb:22-47`). Frontendowe handlery `order.completed` i `order.canceled` w ogóle nie sprawdzają tej flagi i zawsze wysyłają, jeśli jest e-mail (`sklepikFront/src/lib/webhooks/handlers.ts:30-75,80-107`). Z kolei `resend_confirmation` publikuje zwykły `order.completed` bez jawnej semantyki resend (`orders_controller.rb:88-91`).

**Wpływ:** operator nie może polegać na opcji „powiadom/nie powiadamiaj”; import lub ręczne complete/cancel może wysłać niezamierzony mail. Nazwa „resend” jest ukryta przed downstreamem, a event biznesowy „order completed” jest używany jako komenda wysyłki.

**Rekomendacja:** rozdzielić zdarzenie faktu od komendy komunikacji. `order.completed` zawsze zapisuje fakt; notification policy/outbox tworzy `customer_notification.requested` z template, locale, recipient, reason, actor i dedupe key. Resend ma osobny reason i audit.

**Test zamykający:** complete/cancel z notify false nie wysyła; true wysyła raz; resend wysyła ponownie dokładnie raz z nowym command ID; retry webhooka nie dubluje; każda wiadomość ma tenant branding i locale.

### ORDER-007 — P2 — tenant invariants zwrotów nie są wymuszane w modelu

**Status dowodu:** fakt; obecnie ograniczony brakiem tras v3.

`ReturnAuthorization` nie ma `store_id` i zawiera FIXME o powiązaniu ze sklepem; currency fallbackuje do globalnego default store (`spree/core/app/models/spree/return_authorization.rb:55-57`). `CustomerReturn` ma store, lecz waliduje tylko obecność oraz wspólne order_id pozycji — nie sprawdza `customer_return.store == order.store`, zgodności stock location ani reason/reimbursement type z tenantem (`spree/core/app/models/spree/customer_return.rb:12-24,47-52,77-90`).

**Wpływ:** przyszły kontroler/service może połączyć sklep A, zamówienie B i magazyn C. Nawet bez wycieku odczytu może to zmienić cudzy stock lub zaksięgować zwrot w złym tenantcie.

**Rekomendacja:** case i wszystkie operacje wywodzić z `current_store.orders`; dodać jawne store_id/invariants na agregatach i tenant-scoped lookups. Stock location, payment, order, customer return i komunikacja muszą należeć do tego samego store.

**Test zamykający:** pełna macierz dwóch tenantów miesza każdy ID po kolei; wszystkie kombinacje cross-store kończą się 404/422 bez rekordów, eventów, stock movements i gateway calls.

### ORDER-008 — P2 — resume zamówienia nie ma polityki finansowej ani UI, mimo publicznego endpointu

**Status dowodu:** fakt.

Anulowanie voiduje/canceluje płatności, po czym `resume` bez dodatkowych warunków wywołuje `@resource.resume!` (`orders_controller.rb:80-85`). Callback ustawia status `placed`, resume'uje wysyłki i rozważa risk, lecz nie odbudowuje prawidłowej płatności (`spree/core/app/models/spree/order.rb:1140-1145`). SDK wystawia endpoint, panel nie oferuje spójnego flow.

**Wpływ:** integracja może przywrócić anulowane zamówienie do operacyjnego statusu z void/refunded payment. Dalszy stan zależy od updatera i ręcznych działań, co sprzyja wysyłce bez zapłaty lub błędnemu reconciliation.

**Rekomendacja:** zdefiniować politykę: reopen jako nowy draft/payment attempt albo nieodwracalne cancel po efekcie pieniężnym. Resume wymaga actor, reason, payment/stock preconditions i audit.

**Test zamykający:** resume po void, full refund, partial refund i offline payment ma jawne, różne wyniki; nie można osiągnąć ready/shipped bez wymaganej zapłaty i stocku.

### ORDER-009 — P2 — klient widzi zamówienie, ale nie może rozpocząć ani śledzić sprawy posprzedażowej

**Status dowodu:** fakt.

Store API bezpiecznie ogranicza pojedyncze completed order do current store oraz JWT usera lub guest tokenu (`spree/api/app/controllers/spree/api/v3/store/orders_controller.rb:6-35`), a customer list dodatkowo używa `for_store(current_store).complete` (`store/customer/orders_controller.rb:19-22`). Storefront pokazuje towary, fulfillment, tracking, adres, płatności i sumy (`sklepikFront/src/components/account/OrderDetail.tsx:27-121`). Nie ma przycisku „zwróć/reklamuj”, formularza, załączników, statusu sprawy ani trwałego kanału odpowiedzi. Globalna tożsamość klienta pozostaje osobnym AUTH-002.

**Wpływ:** klient pisze e-mail poza systemem, a właściciel przepisuje dane ręcznie. Terminy, dowody i decyzje rozchodzą się między skrzynką, panelem i płatnościami.

**Rekomendacja:** self-service case creation z kwalifikacją pozycji, powodem/żądaniem, zdjęciami, preferowaną resolution i instrukcją wysyłki; guest korzysta z podpisanego, ograniczonego dostępu do konkretnej sprawy, nie z publicznego numeru zamówienia.

**Test zamykający:** customer i guest mogą otworzyć sprawę tylko do własnego order/item; owner odpowiada; klient widzi immutable timeline i pobiera odpowiedzi/dokumenty, bez dostępu do internal notes.

### ORDER-010 — P2 — brak technicznych capability dla polskich terminów i trwałego śladu reklamacji

**Status dowodu:** fakt produktu; wymagania prawne służą tylko jako źródło capability, nie jako opinia prawna.

System nie ma daty otrzymania reklamacji/odstąpienia, deadline engine, klasy żądania, odpowiedzi na trwałym nośniku, dowodu doręczenia, wstrzymania refundu do otrzymania rzeczy/dowodu nadania ani wyjątków od odstąpienia. Nie ma również wersji polityki zaakceptowanej dla zamówienia.

UOKiK wskazuje m.in. odpowiedź na reklamację w 14 dni i możliwe żądania: naprawa, wymiana, obniżenie ceny albo odstąpienie ([UOKiK — niezgodność towaru z umową](https://prawakonsumenta.uokik.gov.pl/reklamacja/niezgodnosc/)). Dla odstąpienia UOKiK opisuje obowiązek odesłania rzeczy w 14 dni oraz możliwość wstrzymania refundu do otrzymania rzeczy lub dowodu nadania ([UOKiK — skutek odstąpienia](https://prawakonsumenta.uokik.gov.pl/prawo-odstapienia-od-umowy/skutek/)). Dokładne reguły i wyjątki musi zatwierdzić prawnik dla konkretnego merchanta/asortymentu.

**Wpływ:** platforma nie pilnuje terminów i nie dowodzi, co oraz kiedy zakomunikowano. Merchant może przegapić SLA mimo poprawnej intencji.

**Rekomendacja:** konfigurowalny policy/deadline engine z kanonicznymi timestampami, timezone sklepu, holiday policy, alertami/escalation, pause rules tylko gdy dozwolone, immutable communication receipts i snapshotem polityki/dokumentów z chwili zakupu.

**Test zamykający:** zegar kontrolowany testem obejmuje granice DST/weekend, deadline reklamacji, odstąpienia i refund hold/release; każda odpowiedź ma wygenerowany trwały artefakt i dowód wysyłki. Reguły prawne są wersjonowane i zatwierdzone poza kodem przez kompetentną osobę.

### ORDER-011 — P2 — event `order.shipped` powstaje dopiero przy pełnej wysyłce, więc brak komunikacji częściowych paczek

**Status dowodu:** fakt.

Każdy shipment publikuje `shipment.shipped`, ale `order.shipped` dopiero gdy `order.fully_shipped?` (`spree/core/app/models/spree/shipment/custom_events.rb:19-25,42-43`). Storefront subskrybuje tylko `order.shipped` i wtedy buduje listę wszystkich shipped fulfillments (`sklepikFront/src/app/api/webhooks/spree/route.ts:22-29`; `handlers.ts:109-165`).

**Wpływ:** pierwsza z kilku paczek może wyjść bez wiadomości i trackingu dla klienta; finalny e-mail może zebrać kilka przesyłek dopiero po ostatniej. To jest słabe dla split fulfillment i dropship/3PL.

**Rekomendacja:** notification per `shipment.shipped` z fulfillment ID jako dedupe key, a `order.fully_shipped` jako osobny milestone opcjonalny. Payload musi zawierać customer-safe order context bez potrzeby zgadywania po całym orderze.

**Test zamykający:** dwa fulfillmenty wysłane w różne dni generują dwie właściwe wiadomości z różnymi trackingami; retry nie dubluje, a full-order milestone nie wysyła ponownie tych samych danych.

### ORDER-012 — P3 — gateway log zapisuje surową serializowaną odpowiedź bez jawnej redakcji

**Status dowodu:** fakt; zawartość zależy od adaptera.

Po refundzie `create_log_entry` zapisuje `@response.to_yaml` (`spree/core/app/models/spree/refund.rb:30-31,123-125`). Nie ma w tym miejscu allowlisty/redakcji.

**Wpływ:** adapter może umieścić w params dane klienta, identyfikatory lub inne wrażliwe pola. Audit trail jest potrzebny, ale nie powinien być dumpem całej odpowiedzi operatora.

**Rekomendacja:** strukturalny allowlisted payment event: status, provider, sanitized codes, gateway IDs, correlation ID, timestamp; zakaz raw payloadów poza szyfrowanym, ograniczonym magazynem incydentowym z retencją.

**Test zamykający:** fake response zawiera token, e-mail, card fragment i dowolny secret; żaden nie trafia do DB/logów, a potrzebne IDs/status pozostają dostępne.

## Potwierdzone zabezpieczenia i wartościowy fundament

1. **Podstawowy order access jest store-scoped.** Admin pobiera przez `current_store.orders`, Store API przez completed orders bieżącego sklepu i token/JWT.
2. **Mutacje zamówienia/fulfillmentu używają order lock.** Kontrolery obejmują update, complete, cancel, fulfillment i refund blokadą rekordu.
3. **Shipment ma jawne stany i state changes.** pending/ready/shipped/canceled oraz przejścia są zapisywane.
4. **InventoryUnit rozróżnia on-hand/backordered/shipped/returned.** Istnieją primitives dla częściowych ilości i stock movements.
5. **Zwrot ma kalkulator kwoty i ograniczenia ilości.** ReturnItem nie pozwala zwrócić więcej niż kupiono, wspiera częściową sztukę i zachowuje podatkowy breakdown.
6. **Refund ma limit `credit_allowed`.** Nie można standardowo przekroczyć dostępnej kwoty płatności; wykonanie i idempotencja nadal wymagają MONEY-006/008.
7. **Fulfillment UI ma tracking i jawne potwierdzenia ship/cancel.** Błędy mutacji przechodzą wspólną obsługę, zamiast znikać bez komunikatu.
8. **Klient ma czytelny read-only widok historii zamówienia.** To dobre miejsce do dołączenia spraw posprzedażowych bez duplikowania commerce w frontendzie.

## Docelowa maszyna sprawy posprzedażowej

```text
requested
  → needs_information
  → approved_for_return ─→ in_transit ─→ received ─→ inspected
  → declined                                      ├→ repair
                                                  ├→ replacement
                                                  ├→ price_reduction
                                                  ├→ refund_pending → refunded
                                                  └→ returned_to_customer

każde przejście: store + actor + reason + timestamp + version + evidence
money/stock/message: osobne idempotentne komendy z wynikiem i reconciliation
```

Nie należy mapować reklamacji 1:1 na `ReturnAuthorization`: reklamacja może zakończyć się naprawą, wymianą, obniżką albo odmową i może nie wymagać zwrotu paczki. Istniejące modele są przydatnymi primitives, ale własny agregat `Case` powinien być stabilnym kontraktem Sklepika.

## Minimalny pakiet testów zamykających audyt

1. Dwa tenanty × guest/customer/admin/service key dla order detail, case, return, stock, refund i załączników.
2. Property/state-machine tests wszystkich dozwolonych i zabronionych przejść order/shipment/case/return/reimbursement.
3. Równoległe cancel/ship/receive/refund z retry, timeoutem po stronie gatewaya i crashem workera.
4. Ledger invariants: sprzedana ilość = shipped + canceled/restocked + returned/exchanged; pieniądze = captured − refunded + credits, bez podwójnej alokacji.
5. Sandbox gateway E2E: full/partial refund, void, timeout, duplicate webhook i reconciliation.
6. Browser E2E ownera i klienta: tracking, odstąpienie, reklamacja, decyzja, paczka, refund/wymiana, timeline.
7. Notification E2E z prawdziwą testową skrzynką: per-shipment, cancel, case receipt, request for info, resolution, refund; tenant branding/locale/dedupe.
8. Deadline tests z kontrolowanym czasem i zatwierdzonym zestawem polskich policy rules.
9. Audit/PII test: każdy money/stock/status transition ma aktora i correlation ID; internal note oraz raw gateway payload nigdy nie trafiają do klienta.

## Kolejność napraw

1. **Najpierw MONEY-001–008 i ORDER-001:** jeden bezpieczny command anulowania/refundu, durable idempotency i reconciliation.
2. **Następnie ORDER-002/003/007:** tenantowy agregat sprawy, Admin API i audit trail; wykorzystać core returns tylko za adapterem.
3. **Przed pierwszym prawdziwym fulfillmentem ORDER-005/008:** zamknąć przejścia canceled/resume/ship oraz politykę płatności/stocku.
4. **Przed self-service ORDER-004/009/010:** concurrency, portal klienta, dowody, deadline engine i zatwierdzone reguły operacyjne.
5. **Domknąć komunikację ORDER-006/011 i prywatność ORDER-012.**

## Ograniczenia audytu

- Nie wykonywano prawdziwego zamówienia, wysyłki, refundu ani zmian w produkcji.
- Repo nie zawiera produkcyjnego adaptera płatności, więc skutki `cancel/credit` muszą zostać potwierdzone na wybranym operatorze — patrz MONEY-005.
- Nie potwierdzono aktywnych produkcyjnych subskrypcji wszystkich eventów, Resend/Redis ani dostarczalności wiadomości.
- Nie uruchomiono pełnego RSpec: środowisko testowe backendu leży poza zapisywalnym rootem tej sesji. Istniejące specy pokrywają pojedyncze modele, ale nie pełny przepływ v3/panel/tenant/concurrency.
- Wskazane polskie wymagania są listą potrzebnych capabilities na podstawie źródeł publicznych. Konfigurację polityk, treści i wyjątków musi zatwierdzić kompetentny prawnik/operator przed sprzedażą.
