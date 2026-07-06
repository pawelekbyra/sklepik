# Raport Refaktoryzacji "Sklepik" - Poziom Mistrzowski 2026

Ten raport jest przeznaczony dla Zaawansowanych Agentów AI (AD 2026), aby zrozumieli obecny stan techniczny (Technical Debt) i cel docelowy dla projektów `sklepik` (backend) oraz `sklepikfront` (frontend).

## 1. Status Quo: Co jest "chujowo" (Legacy Debt)

Mimo że Spree ewoluowało, nadal dźwiga bagaż kilkunastu lat rozwoju:

### Backend (`spree/core` & `spree/api`):
- **Fat Models:** Klasy takie jak `Spree::Order` (ponad 1000 linii, dziesiątki metod delegowanych i inkludowanych) łamią zasadę SRP (Single Responsibility Principle). Logika biznesowa (checkout, podatki, płatności) jest przemieszana z logiką bazy danych.
- **Hidden Logic (Concerns & class_eval):** Używanie `ActiveSupport::Concern` oraz `class_eval` w dekoratorach sprawia, że AI trudno jest prześledzić "skąd pochodzi dana metoda". To "magia", która utrudnia deterministyczne refaktoryzowanie.
- **State Machine Bloat:** Maszyny stanów w modelach są przeciążone callbackami (`after_transition`), co powoduje efekty uboczne trudne do debugowania przez agentów AI.
- **V2/V3 API Split:** Istnienie wielu wersji API z różnymi podejściami do serializacji (Fast JSON API vs modern serializers) wprowadza chaos architektoniczny.

### Frontend (`sklepikfront` / `dashboard`):
- **Schema Duplication:** Konieczność ręcznego definiowania schematów Zod, które dublują logikę walidacji z backendu (ActiveModel Validations).
- **SDK Complexity:** SDK jest potężne, ale wymaga dużej ilości "boilerplate'u" przy obsłudze rozszerzeń (expand) i meta-danych.
- **State Management Overhead:** Mieszanie Server Actions z TanStack Query w Storefrontcie może prowadzić do niespójności stanu (tzw. "hydration mismatch" lub "stale data") jeśli nie jest idealnie zsynchronizowane.

---

## 2. Cel: Poziom Mistrzowski (Architektura 2026)

Dla AI 2026, kod musi być **jawny, typowany i modularny**.

### A. Backend: Kierunek "Modular Monolith & Interactors"
1. **Model -> Data Entity:** Modele Rails powinny być tylko definicjami schematu i relacji. Cała logika biznesowa MUSI zostać przeniesiona do `ServiceModule` (Interactors).
2. **Eradicate `class_eval`:** Rozszerzenia powinny używać kompozycji (Dependency Injection) lub jawnych Hooków/Eventów (Event Bus), a nie "wstrzykiwania kodu" do istniejących klas.
3. **OpenAPI as Single Source of Truth:** Każda zmiana w backendzie musi automatycznie aktualizować specyfikację OpenAPI, z której generowane jest SDK.

### B. Frontend: Kierunek "Zero-Boilerplate & Full-Type-Safety"
1. **Zod-from-OpenAPI:** Automatyczne generowanie schematów walidacji z API. Agent AI nie powinien pisać `z.object({...})` ręcznie.
2. **Shared UI primitives:** Dashboard i Storefront powinny współdzielić bibliotekę komponentów (`dashboard-ui`), aby zachować spójność wizualną (Tailwind CSS 4).
3. **Server-First with Client-Grace:** Maksymalne wykorzystanie React Server Components (RSC) dla wydajności (Lighthouse 100/100), przy zachowaniu interaktywności przez "Island Architecture".

---

## 3. Instrukcje dla Agenta AI (Refactoring Recipes)

Podczas pracy nad kodem, stosuj poniższe reguły:

### Refaktoryzacja Modeli (Rule of Thumb):
- Jeśli widzisz metodę w `Spree::Order`, która ma więcej niż 5 linii lub dotyka innego modelu (np. `Shipment`), przenieś ją do `Spree::Orders::[ActionName]`.
- Zastępuj `before_save` i `after_commit` jawnymi wywołaniami wewnątrz Serwisu. **AI nie lubi ukrytych efektów ubocznych.**

### Refaktoryzacja API:
- Używaj tylko V3 API. Jeśli brakuje endpointu, stwórz go w `Spree::Api::V3::Store` używając nowoczesnych serializerów.
- Zawsze definiuj `permitted_params` w sposób jawny i zsynchronizowany z Zod.

### Rozszerzanie Funkcjonalności:
- Nie używaj dekoratorów (`.class_eval`). Używaj modułów i `prepend` tylko w ostateczności. Preferuj subskrypcję zdarzeń przez `Spree::Event`.

---

## 4. Wnioski Końcowe dla Właściciela

Połączenie `sklepik` i `sklepikfront` to świetna baza, ale wymaga "wycięcia starego mięsa". Dzięki Twoim "najlepszym agentom AI", refaktoryzacja do poziomu Mistrzowskiego powinna skupić się na **uproszczeniu ścieżki danych** i **usunięciu magii Railsów** na rzecz jawnego kodu.

**Ten raport służy jako "mapa drogowa" dla AI, aby wiedziało, że ma dążyć do czystej separacji domen i pełnego typowania.**
