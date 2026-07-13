# System kompozycji storefrontu (docelowa niezależność stylu/layoutu bez forkowania kodu)

**Status:** Draft — wizja koncepcyjna, nierozpoczęta
**Target:** `sklepikFront` (storefront), `sklepik` (backend, jako źródło danych konfiguracji)
**Depends on:** [`multi-store-support.md`](multi-store-support.md) — Faza 1 (zaimplementowana), rozszerza/precyzuje Fazę 2 tamtego planu
**Author:** właściciel + agent (sesja 2026-07-13)
**Last updated:** 2026-07-13

## Summary

Pytanie, które zainicjowało ten plan: jeśli sklep ma mieć **pełną niezależność wizualną** (własny layout, własny styl, nie tylko kolor/logo) i nie ma ograniczeń budżetowych na inżynierię, to jakie jest najlepsze rozwiązanie — czy to fork repozytorium per sklep?

Odpowiedź: **nie.** Fork repo per sklep to tani kompromis, nie premium rozwiązanie — kupuje niezależność kodu kosztem N kopii do ręcznego utrzymania (każda poprawka bezpieczeństwa/checkoutu musi być propagowana ręcznie albo botem synchronizującym). Platformy z prawdziwym budżetem inżynieryjnym (Shopify Online Store 2.0, Webflow, Builder.io) nie forkują kodu per klient — budują **warstwę kompozycji**: system komponentów + drzewo strony jako dane (JSON w bazie), renderowane przez jedną, wspólną aplikację. Właściciel sklepu (albo jego designer) komponuje layout wizualnie, bez dotykania kodu, a mimo to dostaje w praktyce nieograniczoną swobodę wizualną. Płaci się raz za zbudowanie tej warstwy, zamiast płacić powtarzalnie za utrzymanie N kodebase'ów.

To jest wizja **docelowa** (target state), świadomie ambitniejsza niż Faza 2 z `multi-store-support.md` (która zakładała tylko routing po domenie, bez zmiany modelu customizacji). Ten plan nie jest jeszcze zaczęty i nie ma ustalonego terminu — zapisany, żeby nie zgubić decyzji architektonicznej, gdy przyjdzie czas na realizację.

## Key Decisions (do not deviate without discussion)

- **Jeden storefront, jedna baza kodu, wszystkie sklepy.** Żadnych forków repozytorium per sklep jako domyślnego mechanizmu. Fork/osobna apka to wyjątek premium (patrz niżej), nie ścieżka standardowa.
- **Layout i styl sklepu to dane, nie kod.** Strona sklepu to drzewo JSON (sekcje + propsy), przechowywane w backendzie, renderowane przez rejestr komponentów React współdzielony przez wszystkie sklepy. Nowy komponent w rejestrze staje się dostępny dla wszystkich sklepów natychmiast.
- **Design tokens per sklep, nie tylko kolor/logo.** Pełna skala: typografia, spacing, promienie zaokrągleń, krzywe animacji, override'y per-komponent. To realna głębia customizacji, nie kosmetyka.
- **Draft/publish z wersjonowaniem.** Edycja layoutu na żywym podglądzie (draft), publikacja jawnym krokiem, historia wersji z możliwością rollbacku — layout sklepu nie jest edytowany "na produkcji" bez siatki bezpieczeństwa.
- **Custom code jako sandboxed escape hatch, nie jako domyślna ścieżka.** Rzadki przypadek sklepu potrzebującego faktycznie unikalnej logiki (nie tylko wyglądu) dostaje izolowany, poddany review komponent/plugin ładowany per-sklep — rozszerza system, nie duplikuje całej aplikacji.
- **Jeden deployment, cache per-tenant na edge'u.** Skalowanie do wielu sklepów przez ISR/edge cache kluczowany `store_id`+`path`, nie przez mnożenie deploymentów Vercel.

## Design Details

### Backend (`sklepik`)

1. **Model strony/sekcji** — nowa struktura danych spinająca sklep z drzewem sekcji: `Spree::Store has_many :pages`, `Page has_many :sections` (albo pojedyncza kolumna `jsonb` z całym drzewem, do rozstrzygnięcia — trade-off: normalizacja + query'owalność vs prostota jednego blobu). Każda sekcja: `component_key` (wskazuje do rejestru po stronie frontu) + `props` (jsonb) + `position` (`acts_as_list`, drag-and-drop w edytorze jak reszta panelu).
2. **Design tokens** — rozszerzenie istniejących `Store` preferences (już ma `preferred_*` dla części ustawień) o pełny zestaw tokenów: paleta, typografia, spacing, radius, itd. Prawdopodobnie osobny model `Spree::StoreTheme` zamiast dorzucania kolejnych `preference`, żeby nie rozdymać `Store`.
3. **Draft/publish** — `Page` (albo cały theme) ma `draft_data`/`published_data` (dwa stany tego samego drzewa) + `published_at`. Publikacja to atomowa operacja kopiująca draft → published. Historia wersji: `PaperTrail`/`acts_as_versioned`-podobny mechanizm albo prostszy log zmian, do rozstrzygnięcia przy projektowaniu szczegółowym.
4. **Custom code / plugin sandbox** — poza zakresem szczegółowego projektu w tym dokumencie; wymaga osobnej decyzji o modelu bezpieczeństwa (co sandboxed komponent może/nie może robić — network, dostęp do danych innych sklepów, itd.), prawdopodobnie osobny plan gdy realnie zaczniemy.

### Frontend (`sklepikFront`)

1. **Rejestr komponentów** — mapa `component_key → React component`, każdy komponent przyjmuje `props` z drzewa strony + `theme` (design tokens bieżącego sklepu) z kontekstu. Biblioteka startowa: hero, siatka produktów, karuzela, tekst+obraz, CTA, itd. — rozbudowywana z czasem, każdy nowy komponent dostępny dla wszystkich sklepów.
2. **Renderer strony** — server component iterujący po drzewie sekcji sklepu, renderujący każdą przez rejestr; brakujący `component_key` w rejestrze → czytelny fallback, nie crash całej strony.
3. **Routing po domenie (z Fazy 2 `multi-store-support.md`)** — warunek wstępny tego planu. Storefront musi już rozpoznawać sklep po `Host` żądania i dociągać jego config dynamicznie, zanim ma sens dociąganie do tego configu również drzewa strony/theme.
4. **Edytor wizualny** — osobna, duża część projektu: podgląd na żywo, drag-and-drop sekcji, panel edycji propsów/tokenów. Prawdopodobnie nowa sekcja panelu admina (`packages/dashboard`) albo dedykowany edytor osadzony w storefroncie (jak Shopify theme editor) — do rozstrzygnięcia.

## Migration Path

Nie rozpisane szczegółowo — to wizja docelowa, nie plan sprintu. Zgrubny szkic kolejności (każdy krok wymaga osobnej decyzji, żeby zacząć realizację):

1. Faza 2 z `multi-store-support.md` (routing po domenie) jako fundament — bez tego nie ma sensu dociągać configu strony dynamicznie.
2. Design tokens (krok najmniejszego ryzyka, rozszerza istniejące `Store` preferences) — daje realną wartość (głęboka customizacja brandingu) zanim zacznie się budować cały page builder.
3. Rejestr komponentów + statyczne drzewo strony (bez edytora — layout ustawiany przez dewelopera/wsparcie, nie samoobsługowo) — sprawdza architekturę zanim zainwestuje się w UI edytora.
4. Edytor wizualny z draft/publish — największy kawałek pracy, dopiero gdy 1-3 działają stabilnie.
5. Custom code sandbox — najbardziej ryzykowny element (bezpieczeństwo), świadomie na końcu i tylko jeśli realnie pojawi się klient/sklep tego wymagający.

## Constraints on Current Work

- Nic w bieżącej pracy nad Fazą 1 (`multi-store-support.md`) nie wymaga zmian z powodu tego planu — ten dokument nie jest jeszcze rozpoczęty.
- Jeśli ktoś zacznie budować Fazę 2 (routing po domenie) zanim ten plan wystartuje, powinien projektować ją tak, żeby dociąganie configu sklepu było już przygotowane pod rozszerzenie o drzewo strony/theme w przyszłości (np. jeden endpoint "config sklepu", nie rozproszone zmienne) — ale nie budować tego na zapas, jeśli nie ma jeszcze decyzji o starcie tego planu.

## Open Questions

- Model danych strony: znormalizowane `Page`/`Section` (query'owalne, ale więcej migracji) czy jeden `jsonb` z całym drzewem (prostsze, mniej elastyczne w query'owaniu)?
- Gdzie żyje edytor wizualny: nowa sekcja `packages/dashboard`, czy osadzony bezpośrednio w `sklepikFront` (jak Shopify theme editor na subdomenie `/editor`)?
- Model bezpieczeństwa custom code sandbox — jak izolować dostęp do danych, sieci, innych sklepów. Osobna, głęboka decyzja, nierozstrzygnięta tutaj.
- Czy rejestr komponentów jest w pełni generyczny (dowolny sklep e-commerce), czy zakłada pewien kształt (produkty kakao, konkretny typ katalogu) — wpływa na to, jak bardzo "platformowe" ma być to rozwiązanie.
- Koszt/tempo: to jest wielomiesięczny projekt zespołowy, nie zadanie na sesję agenta — kiedy właściciel chce to realnie zacząć, potrzebny osobny, szczegółowy plan sprintu, nie tylko ta wizja.

## References

- [`multi-store-support.md`](multi-store-support.md) — Faza 1 (zaimplementowana), Faza 2 (routing po domenie, warunek wstępny tego planu).
- [`docs/ideas/multi-store-provisioning.md`](../ideas/multi-store-provisioning.md) — wcześniejszy szkic automatyzacji provisioningu (model "osobny projekt Vercel per sklep"); ten plan jest świadomie inną, bardziej docelową ścieżką niż tamten szkic.
- Wzorce referencyjne (nie kod, tylko architektura do inspiracji): Shopify Online Store 2.0 (sections/blocks), Webflow, Builder.io.
