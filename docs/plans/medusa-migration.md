# Migracja backendu ze Spree/Rails na Medusa.js/TypeScript

**Status:** Decyzja podjęta (2026-07-17), plan migracji nierozpoczęty.
**Target:** `sklepik` (backend) — zastąpienie forka Spree Commerce przez Medusa.js.
**Depends on:** `docs/plans/fiscal-compliance-poland.md` (moduł fiskalny budowany na nowym stosie, nie na Spree).
**Author:** właściciel + agent (sesja 2026-07-17, po obiektywnym research-passie porównującym Spree i Medusę bez uwzględniania sunk cost)
**Last updated:** 2026-07-17

## Summary

Właściciel podjął decyzję: zamiast kontynuować na forku Spree Commerce (Ruby on Rails), backend zostaje przepisany od podstaw na **Medusa.js** (Node/TypeScript). Decyzja podjęta świadomie, z pełną informacją, że to prawdziwy kompromis, nie oczywisty wybór technicznie — Spree ma przewagę funkcjonalną (B2B, price lists, multi-store gotowe out-of-the-box) i jedyny w badaniu potwierdzony precedens multi-tenant na dużą skalę (GoDaddy, „dziesiątki tysięcy" witryn). Właściciel świadomie wybrał priorytet **spójności technologicznej (cały stos w TypeScript) i jakości architektury pod bezpieczne, częste zmiany przez agentów AI** nad dojrzałością funkcjonalną i sprawdzoną skalą — i wprost odrzucił argument kosztu/czasu jako czynnik decyzyjny ("dla mnie to nie problem, chcę znać najlepsze możliwe rozwiązanie").

**To nie jest przepisanie "na wszelki wypadek" — to świadomy wybór gorszego dziś, lepszego jutro fundamentu**, przy pełnej świadomości, że część funkcji (subskrypcje, pełne B2B, price lists) trzeba będzie zbudować od zera, których Spree miał gotowe.

**Doprecyzowanie strategii (2026-07-17, ten sam dzień):** to nie ma być fork na GitHubie ani zależność npm od `@medusajs/*` z regularnym `git pull`/`npm update` z upstreamem. Właściciel chce **nowe, czyste repozytorium**: kod Medusy skopiowany raz jako punkt startowy, od tej chwili w pełni własny, bez śledzenia release'ów upstreamu, z własną dokumentacją zamiast ich. Ten sam wzorzec, który już zastosowaliśmy do Spree (fork jako punkt wyjścia, nie ograniczenie), zastosowany od początku, świadomie, zamiast wynikać z przypadku.

**Zweryfikowane: licencja MIT Medusa.js w pełni na to pozwala.** Skopiowanie kodu do prywatnego repo, dowolna modyfikacja, brak synchronizacji z upstream, użycie komercyjne (sprzedaż klientom) — wszystko dozwolone bez ograniczeń. Jedyne twarde wymogi: (a) zachować plik `LICENSE` z notą copyright Medusajs gdzieś w repo (nie trzeba w każdym pliku), (b) nie używać nazwy/logo "Medusa" jako własnej marki (kwestia znaku towarowego, nie prawa autorskiego, więc do przemianowania w dokumentacji/publicznej twarzy, nie w samym kodzie).

**Realny koszt tej decyzji, nazwany wprost:** Medusa to młody, szybko rozwijany projekt (commity co kilka godzin wg wcześniejszego research-passu). Ucinając relację z upstream, **przejmujemy pełną odpowiedzialność za wyszukiwanie i wgrywanie poprawek bezpieczeństwa na zawsze** — nikt nam ich nie wypchnie automatycznie. To większe zobowiązanie utrzymaniowe niż przy dojrzałym, wolniej zmieniającym się Spree. Świadomie zaakceptowane przez właściciela.

## Ustalenia badawcze — dlaczego Medusa, nie Spree

Z research-passu 2026-07-17 ("Unbiased Spree vs Medusa best-foundation comparison"):

**Na korzyść Medusy:**
- **Architektura modułowa z workflow engine i automatycznym rollbackiem** (akcje kompensujące przy błędzie w wieloetapowej operacji) — Medusa 2.0 wymusza granice modułów strukturalnie (brak foreign keys między modułami). Spree opiera się historycznie na dekoratorach (`_decorator.rb`, monkey-patching), które **sam Spree dziś odradza jako "ostateczność"** — ciasno wiąże kod z wewnętrzną implementacją i łamie się przy aktualizacjach.
- **Spójność języka z resztą stosu** (Next.js storefront, osobne monorepo edytora w TS) — współdzielone typy/schematy Zod bez synchronizowania kontraktów między dwoma ekosystemami językowymi. Realna korzyść operacyjna dla małego zespołu opartego o agentów AI, nie tylko estetyka.
- **TypeScript daje statyczną kontrolę typów** przy refaktoryzacji przez LLM — pozwala złapać klasę błędów bez uruchamiania całego zestawu testów. Medusa świadomie inwestuje w rozwój wspomagany AI (dokumentacja formatowana pod LLM-y, `llms-full.txt`, oficjalny case study budowy sklepu z Claude Code).

**Na korzyść Spree (świadomie odrzucone jako mniej ważne niż powyższe):**
- Dojrzałość funkcjonalna out-of-the-box: Price Lists, Customer Groups, konta B2B z zatwierdzeniami zakupu, multi-currency przez Markets, natywny multi-store — w Medusie trzeba to zbudować, częściowo od zera (Medusa **nie ma natywnych subskrypcji** w ogóle).
- **Jedyny potwierdzony precedens multi-tenant na realną skalę:** GoDaddy używa Spree jako silnika dla dziesiątek tysięcy niezależnych witryn małych firm. Medusa ma tylko średniej skali wdrożenia agencyjne, bez jawnie udokumentowanej podobnej skali.

**Neutralne dla wyboru:** żadna platforma nie ma natywnej integracji KSeF/kasy fiskalnej — to zawsze będzie custom moduł, niezależnie od frameworka (patrz `fiscal-compliance-poland.md`).

## Key Decisions (do not deviate without discussion)

1. **Nowy backend: Medusa.js (Node/TypeScript), nie fork Spree.** Zastępuje cały `spree/` katalog w repo `sklepik` docelowo.
2. **Nowe, osobne repozytorium (robocza nazwa: `sklepik-medusa` albo docelowa nazwa platformy) — nie fork na GitHubie, nie zależność npm od `@medusajs/*` z bieżącym śledzeniem upstreamu.** Kod Medusy wklejony raz jako punkt startowy (`git clone` → usunięcie `.git` → nowy, własny commit history), od tej chwili traktowany jako w pełni własny kod. Dokumentacja Medusy zastąpiona własną (`CLAUDE.md`, `docs/` wg konwencji już ustalonej w `sklepik`/`sklepikFront`/`edytor-sklepu`), nie zachowana 1:1.
3. **Moduł fiskalny (KSeF/VAT/kasa fiskalna) budowany od razu na Medusie**, nie na Spree jako tymczasowym fundamencie — to najpilniejsza, różnicująca funkcja, więc ma sens budować ją raz, na docelowym stosie.
4. **`sklepikFront` (Next.js) i `edytor-sklepu` (silnik edytora) zostają bez zmian architektonicznych** — Medusa wystawia REST/GraphQL podobnie jak Spree, więc warstwa frontendowa integruje się z nowym backendem przez zaktualizowany klient API, nie przez przepisanie całej aplikacji. Realny koszt: przepisanie `@spree/sdk`-podobnej warstwy klienta pod Medusę.
5. **Kakałowy Sklepik pozostaje na Spree do czasu gotowości nowego backendu** — brak przerwy w działaniu, ale nowe funkcje biznesowe (poza modułem fiskalnym budowanym równolegle na Medusie) nie powinny być dokładane do Spree, jeśli i tak zostaną zastąpione.

## Design Details

Nierozpoczęte technicznie poza tym, co już wynika z `fiscal-compliance-poland.md` (moduł fiskalny: `FiscalProvider` + Fakturownia jako pierwsza implementacja, fizyczna drukarka fiskalna online z REST API — Novitus NoviAPI — dla kasy fiskalnej, e-paragon za zgodą klienta).

Do zaprojektowania w kolejnej sesji:
- Struktura nowego repo/monorepo Medusa — osobne repo czy nowy katalog w `sklepik` obok/zamiast `spree/`?
- Model danych produktów/zamówień/klientów w Medusie — jak mapuje się na dzisiejsze dane w Postgres (Spree schema).
- Moduł multi-tenant w Medusie — Medusa 2.0 nie ma tego gotowego tak jak Spree Enterprise/GoDaddy-scale; trzeba zaprojektować własny, analogicznie do dzisiejszego `store_id` w Spree, ale od zera.
- Strategia migracji danych z żywej produkcji (Kakałowy Sklepik: 14 produktów, zamówienia, klienci) — eksport/import, czy równoległy zapis, czy cutover.
- Co dzieje się z już zbudowanym `Spree::StorefrontPage` (dzisiejsza praca) — czy koncepcja (JSONB blob per strona, draft/publish, optimistic locking — zwalidowana badawczo jako zgodna z Shopify) przenosi się 1:1 do modelu Medusy, czy wymaga przeprojektowania pod jej architekturę modułową.
- Nowa integracja frontend↔backend: zastąpienie `@spree/sdk` odpowiednikiem dla Medusy (Medusa ma własny JS Client SDK — do zbadania, czy pasuje bezpośrednio, czy potrzebna warstwa adaptera analogiczna do dzisiejszej).

## Migration Path

**Nierozpisane — wymaga osobnej, dedykowanej sesji projektowej**, nie doklejenia do bieżącej roadmapy. Ta migracja dotyka żywej produkcji (realny sklep, realni klienci docelowo) i zasługuje na tyle samo staranności co dzisiejsze badania — plan krok-po-kroku, nie przepisywanie na żywioł.

Zgrubny szkic kolejności do potwierdzenia w kolejnej sesji:
1. Nowe repozytorium GitHub (nie fork) → `git clone` Medusa.js (MIT, zweryfikowane 2026-07-17: pełna dowolność użycia komercyjnego, jedyny wymóg — zachować plik `LICENSE`) → usunięcie historii/`.git`, nowy commit startowy → własny `CLAUDE.md`/`docs/` zastępujący dokumentację Medusy, wg konwencji już ustalonej w pozostałych trzech repo (protokół dokumentacji, obowiązkowa lektura, itd.).
2. Model multi-tenant w Medusie (odpowiednik dzisiejszego `store_id`/`StoreResolution`) — fundament pod wszystko inne, budowany raz, dobrze.
3. Moduł fiskalny (`FiscalProvider` + Fakturownia + integracja kasy fiskalnej) na nowym backendzie — najpilniejsza, różnicująca funkcja, dowód że nowy stos działa na czymś realnym.
4. Podstawowy katalog produktów/zamówień/koszyk — odpowiednik dzisiejszego Store/Admin API.
5. Migracja danych z produkcyjnego Spree (Kakałowy Sklepik) — eksport/import albo równoległy zapis, do zaprojektowania.
6. Przełączenie `sklepikFront` na nowy backend (nowy klient API).
7. Cutover produkcji, wygaszenie Spree.

## Constraints on Current Work

- **Nie dokładać nowych funkcji biznesowych do `spree/`**, które i tak zostaną zastąpione — wyjątek: krytyczne poprawki bezpieczeństwa/stabilności produkcji Kakałowego Sklepika, które musi działać do czasu cutover.
- Moduł fiskalny (`fiscal-compliance-poland.md`) — **budować od razu na Medusie**, nie jako tymczasowy kod w Spree do wyrzucenia. To pierwszy realny kawałek nowego backendu.
- `docs/kierunek-projektu.md` (kanon celu projektu) wymaga aktualizacji sekcji "Stack technologiczny" — dziś wciąż opisuje Rails/Spree jako fundament. Nie zmieniono w tej sesji, żeby nie robić tego pospiesznie przy okazji — wymaga świadomej rewizji w kolejnej sesji projektowej razem z resztą planu migracji.

## Open Questions

- **✅ Rozstrzygnięte (2026-07-17): nowe, osobne repozytorium**, nie katalog w `sklepik`, nie fork na GitHubie. Nazwa repo wciąż nierozstrzygnięta (robocza: `sklepik-medusa`).
- Strategia migracji danych produkcyjnych — nierozstrzygnięte, wymaga starannego planu (żywy sklep, realne zamówienia).
- Czy multi-tenant w Medusie budujemy od zera analogicznie do `store_id`, czy jest w Medusie jakiś wzorzec/przykład warty naśladowania — nieobadane w tej sesji, do zbadania przed startem implementacji.
- Los dzisiejszej pracy nad `Spree::StorefrontPage`/`SklepikPageRepository`/publikacją pakietów `@pawelekbyra/*` — koncepcje (JSONB blob, draft/publish, warstwa `PageRepository`) prawdopodobnie przenoszą się, ale wymagają przeprojektowania pod nowy backend. Nie marnowanie pracy, ale nie 1:1 kopiowanie kodu Ruby.
- Harmonogram: czy moduł fiskalny na Medusie budujemy równolegle z resztą migracji, czy migracja jest wstrzymana do czasu, aż moduł fiskalny będzie gotowy (biorąc pod uwagę, że terminy KSeF już minęły — presja czasowa realna).

## References

- `docs/plans/fiscal-compliance-poland.md` — moduł fiskalny, teraz budowany na tym nowym fundamencie.
- Research-pass 2026-07-17 "Unbiased Spree vs Medusa best-foundation comparison" — źródło ustaleń wyżej.
- Research-pass 2026-07-17 "Verify Medusa.js license terms for vendoring" — [github.com/medusajs/medusa/blob/develop/LICENSE](https://github.com/medusajs/medusa/blob/develop/LICENSE) (MIT, zweryfikowane bezpośrednio z pliku LICENSE w repo).
- [Medusa Architecture](https://docs.medusajs.com/learn/introduction/architecture), [Workflow Engine Module](https://docs.medusajs.com/resources/infrastructure-modules/workflow-engine), [Medusa Build with LLMs](https://docs.medusajs.com/learn/introduction/build-with-llms-ai)
- [Spree Decorators docs](https://spreecommerce.org/docs/developer/customization/decorators) (uzasadnienie dlaczego Spree odradza własny wzorzec rozszerzania)
- [Spree vs Medusa — openalternative.co](https://openalternative.co/compare/medusa/vs/spree-commerce)
