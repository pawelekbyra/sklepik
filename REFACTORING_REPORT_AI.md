# Raport Refaktoryzacji "Sklepik" - Poziom Mistrzowski 2026

Ten raport jest przeznaczony dla Zaawansowanych Agentów AI (AD 2026), aby zrozumieli obecny stan techniczny (Technical Debt) i cel docelowy dla projektów `sklepik` (backend) oraz `sklepikfront` (frontend).

## 1. Status Quo: Dlaczego obecna architektura to "Bullshit" (Legacy Debt)

Mimo że Spree ewoluowało, nadal dźwiga bagaż kilkunastu lat rozwoju, który w 2026 roku jest nieakceptowalny:

### Backend (`spree/core` & `spree/api`):
- **Fat Models (God Objects):** Klasa `Spree::Order` (ponad 1000 linii) posiada zbyt wiele odpowiedzialności. Przykład: `finalize!` (linia 653) zarządza zamykaniem adjustacji, stanami płatności, wysyłką, webhookami, ryzykiem i zdarzeniami PubSub jednocześnie. To koszmar dla testowalności.
- **Master Variant Coupling:** W `Spree::Product`,Master Variant jest silnie sprzężony z produktem przez delegację (`delegate :sku, :price, to: :master`). To utrudnia modelowanie produktów, które nie mają "głównego" wariantu lub mają specyficzne cechy na poziomie produktu.
- **Magia Dekoratorów:** Nadużywanie `ActiveSupport::Concern` i `class_eval` ukrywa pochodzenie metod. AI widzi metodę, ale nie wie, który "concern" ją wstrzyknął bez głębokiej analizy AST.

### Frontend (`sklepikfront` / `dashboard`):
- **Brak Prawdziwego End-to-End Typing:** SDK (`@spree/sdk`) zwraca typy, ale walidacja formularzy (Zod) w Dashboardzie jest pisana ręcznie (`packages/dashboard/src/schemas/order.ts`), co prowadzi do desynchronizacji z regułami backendu.
- **Hydration & State Sync:** Storefront (Next.js 16) miesza Server Actions z lokalnym stanem koszyka, co przy skomplikowanych promocjach prowadzi do "flickeringu" cen.

---

## 2. Cel: Poziom Mistrzowski (Architektura 2026)

### A. Backend: Kierunek "Interactor Pattern"
Zamiast Fat Models, każda akcja biznesowa musi być osobnym obiektem `ServiceModule`.

**Przykład Transformacji `Order#finalize!`:**
```ruby
# ZAMIAST: order.finalize!
# STOSUJEMY:
result = Spree::Orders::Finalize.call(order: @order)
```
Interaktor `Spree::Orders::Finalize` powinien jawnie wywoływać kroki:
1. `CloseAdjustments.call`
2. `UpdatePaymentState.call`
3. `FinalizeShipments.call`
4. `TriggerWebhooks.call`

### B. Frontend: Kierunek "Schema-Driven UI"
1. **Automatyzacja Zod:** Generowanie schematów walidacji bezpośrednio z definicji OpenAPI backendu.
2. **Shared UI primitives:** Użycie `@spree/dashboard-ui` jako bazy dla Storefrontu, aby uniknąć redundancji kodu CSS.

---

## 3. Instrukcje dla Agenta AI (Refactoring Recipes)

1. **SRP Enforcement:** Każda metoda modelu Rails powyżej 10 linii powinna być kandydatem do ekstrakcji do Serwisu.
2. **Explicitness over Magic:** Zamiast `before_save`, używaj jawnych wywołań wewnątrz Serwisu/Interaktora. AI nie może zgadywać, co stanie się po `save!`.
3. **API V3 First:** Wszystkie nowe funkcjonalności muszą lądować w V3 API z wykorzystaniem nowoczesnych Transformerów/Serializerów.

---

## 4. Wnioski Końcowe

Połączenie `sklepik` i `sklepikfront` wymaga drastycznego cięcia "magii Railsowej". Celem jest system, w którym AI może jednoznacznie określić przepływ danych (Data Flow) bez analizowania 50 modułów wstrzykniętych do jednej klasy.
