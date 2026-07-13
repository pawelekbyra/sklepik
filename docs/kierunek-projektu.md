# Kierunek projektu: Sklepik

**Ten dokument jest kanonem całego systemu.** Obowiązuje w repozytoriach `sklepik` i `sklepikFront`. Opisuje to, czym jest produkt; bieżący stan i kolejność prac są w `stan-projektu.md` i `roadmap.md`.

## Czym jest Sklepik

Sklepik jest platformą do uruchamiania i prowadzenia niezależnych sklepów internetowych. Właściciel może:

- założyć konto i utworzyć sklep samodzielnie;
- zlecić nam lub partnerowi przygotowanie sklepu;
- zarządzać produktami, konfiguracją i wyglądem bez programowania;
- otrzymać osobny storefront, repozytorium i wdrożenie;
- rozwijać sklep poza ograniczeniami zamkniętego kreatora.

> **Sklepik jest systemem operacyjnym małej marki. Generator sklepu to tylko pierwsza minuta relacji. Prawdziwa wartość zaczyna się później — kiedy platforma pomaga marce rzeczywiście sprzedawać.**

Właściciel marki ma pozostać ekspertem od swojego produktu, nie musi stawać się specjalistą od e-commerce. Sklepik dostarcza mu cyfrowy zespół: pomaga z wyglądem, treściami, SEO/AEO, katalogiem, kampaniami, analizą, wiadomościami i obsługą klienta. Agenci przygotowują oraz wykonują bezpieczne działania w kontekście konkretnego sklepu; właściciel zachowuje głos marki i zatwierdza decyzje dotyczące pieniędzy, prawa oraz komunikacji o podwyższonym ryzyku.

Pierwszy sklep z produktami kakao pozostaje działającym sklepem referencyjnym i poligonem produktu. Nie jest już definicją całego projektu.

Docelową obietnicą nie jest samo „wygenerowanie strony”, lecz przeprowadzenie sprzedawcy od pomysłu i produktów do sklepu rzeczywiście gotowego przyjąć zamówienie, a następnie systematyczne pomaganie mu w prowadzeniu i rozwijaniu sprzedaży.

## Dla kogo

Pierwszym klinem są małe polskie marki produktowe, twórcy i mikroproducenci z prostym katalogiem, którzy potrzebują profesjonalnej sprzedaży bez składania technologii i długiego wdrożenia agencyjnego.

Produkt ma obsługiwać trzy sposoby pracy na wspólnym silniku:

1. **Done-for-you** — operator przygotowuje sklep dla klienta.
2. **Assisted self-service** — klient tworzy sklep sam, a system i operator pomagają w trudnych krokach.
3. **Partner** — freelancer lub agencja tworzy i prowadzi wiele sklepów klientów.

Pełny self-service oraz kanał partnerski rozwijamy na podstawie rzeczywistych wdrożeń, a nie wyłącznie założeń.

## Obietnica produktu

> Od produktów do własnego sklepu gotowego do sprzedaży — samodzielnie albo z naszą pomocą.

Właściciel sklepu ma widzieć zadania biznesowe: produkty, wygląd, dostawy, płatności, dokumenty i sprzedaż. GitHub, Vercel i szczegóły infrastruktury są mechanizmem platformy, nie wymaganiem wobec użytkownika.

AI jest operatorem wspierającym człowieka, a nie dekoracją. Może przygotowywać treści i układ, importować produkty, wykrywać braki, proponować działania oraz wykonywać odwracalne operacje po zatwierdzeniu. Nie może omijać kontroli płatności, prawa, bezpieczeństwa ani publikacji.

Docelowym interfejsem platformy jest również język naturalny. Właściciel może poprosić agenta o jednorazową zmianę („ustaw zielone tło”) albo zdefiniować trwałą automatyzację („eskaluj agresywną reklamację i zaproponuj refund według tej polityki”). Agent tłumaczy intencję na typowany plan operacji wykonywany przez deterministyczne serwisy platformy. Każda akcja ma klasę ryzyka: bezpieczne i odwracalne zmiany mogą wykonać się po podglądzie, a pieniądze, prawo, dane oraz komunikacja wysokiego ryzyka wymagają limitów, uprawnień, zatwierdzenia i śladu audytowego. Zasada brzmi: **AI wszędzie, ale nie LLM jako niekontrolowany wykonawca wszystkiego.**

## Podział repozytoriów

```text
pawelekbyra/sklepik
→ kanon systemu, silnik commerce, tenanty i właściciele, Admin API + Store API,
  panel właściciela, edytor, provisioning, SDK i backend produkcyjny

pawelekbyra/sklepikFront
→ wersjonowany storefront Next.js: rendering sklepu, branding, UX, SEO,
  checkout klienta i wdrożenie Vercel
```

`sklepik` jest źródłem prawdy dla produktów, cen, koszyka, zamówień, konfiguracji sklepu oraz dokumentu layoutu. `sklepikFront` renderuje dane Store API i nie duplikuje logiki commerce.

Każdy sklep jest tenantem backendu. Store Factory może tworzyć osobne repozytorium i projekt Vercel, ale storefronty korzystają ze wspólnego, wersjonowanego rdzenia. Osobny kod nie może oznaczać setek nieaktualizowalnych kopii.

## Granica obietnicy własności

Klient otrzymuje otwarty i przenośny storefront działający na zarządzanym silniku commerce. Dopóki nie istnieje kompletny eksport lub samodzielne uruchomienie backendu, nie obiecujemy własności całego stosu. Komunikacja ma precyzyjnie odróżniać:

- własność kodu storefrontu;
- przenośność danych;
- zarządzany backend commerce;
- rozszerzalność przez API.

## Hierarchia decyzji

1. Bezpieczeństwo pieniędzy, danych i izolacji sklepów.
2. Doprowadzenie sprzedawcy do pierwszej prawdziwej sprzedaży.
3. Decyzje właściciela projektu.
4. Wiedza z realnych wdrożeń, pomiarów i badań rynku.
5. Dokumentacja projektu, z tym plikiem jako kanonem.
6. Stabilność commerce: checkout, koszyk, zamówienia, płatności i produkty.
7. Kompatybilność ze Spree upstream.

## Zasady architektoniczne

- Core commerce ma być przewidywalny i odseparowany od eksperymentów.
- Wszystkie dane właściciela są bezwzględnie scope'owane do sklepu.
- Nowy sklep zaczyna jako `draft`; może przyjąć pieniądze dopiero po spełnieniu jawnej checklisty i świadomym uruchomieniu.
- Edytor zapisuje ustrukturyzowany, walidowany dokument. Storefront renderuje wyłącznie opublikowany snapshot; wersja robocza nie może wyciec publicznie.
- AI i generatory layoutu tworzą dane zgodne z tym samym schematem co edytor ręczny.
- Frontend nie zawiera własnych cen, stanów magazynowych ani reguł zamówień.
- Sklepik ma własny język domenowy i stabilne kontrakty. Nazwy i szczegóły obecnego silnika commerce są zamykane za adapterem; nie przenosimy ich do nowych funkcji, agentów ani publicznych integracji.
- Modyfikacja core Spree wymaga uzasadnienia i wpisu w `engine-decisions.md`.
- Sekrety platformy nigdy nie trafiają do repozytorium klienta.
- Wszystkie storefronty muszą mieć kontrolowaną ścieżkę aktualizacji wspólnego rdzenia.

## Definicja sklepu gotowego do sprzedaży

Samo utworzenie repozytorium i deploymentu nie oznacza sukcesu. Przed uruchomieniem sklep musi mieć co najmniej:

- dane kontaktowe firmy;
- opublikowany produkt;
- metodę płatności;
- pokrycie dostawy;
- uzupełnione dokumenty prawne;
- opublikowaną stronę główną.

Lista będzie rozszerzana wraz z rzeczywistymi wdrożeniami. System nie generuje fikcyjnych danych prawnych ani nie aktywuje sprzedaży bez decyzji właściciela.

## Model rozwoju produktu

1. Uruchamiać prawdziwe sklepy jako usługę wspieraną.
2. Mierzyć czas, problemy, porzucenia i pierwsze zamówienia.
3. Zamieniać powtarzalną pracę operatora w bezpieczne funkcje platformy.
4. Dopiero potem automatyzować pełny self-service i udostępniać narzędzia partnerom.

North-star metric:

> Liczba aktywnych sklepów, które w danym miesiącu zrealizowały co najmniej jedno prawdziwe zamówienie.

Metryki pomocnicze to: rejestracja → produkt → gotowość → publikacja → pierwsze zamówienie, czas pracy człowieka na uruchomienie, koszt aktywnego sklepu, retencja oraz przychód na sklep.

## Badania i decyzje

Badania rynku żyją w `docs/research/`. Raport nie staje się automatycznie decyzją. Powinien zawierać źródła, datę, poziom pewności i eksperyment, a zatwierdzony wniosek trafia do tego dokumentu, roadmapy albo decyzji architektonicznej.

## Wizja końca

Sklepik ma być systemem uruchamiania i prowadzenia niezależnych marek handlowych. Człowiek opisuje biznes, przekazuje produkty i wybiera sposób pracy: sam, z nami albo z partnerem. Platforma pomaga przygotować markę, storefront, checkout, płatności, dostawy, wymagania operacyjne, domenę i infrastrukturę, a później pomaga rozwijać sprzedaż bez zamykania klienta w szablonie.

Technologia może rosnąć bardzo szybko. Zakres wybieramy jednak według wartości dla klienta i możliwości zbudowania dystrybucji, nie według samej możliwości napisania kodu.
