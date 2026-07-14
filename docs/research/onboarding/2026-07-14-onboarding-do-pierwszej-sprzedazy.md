# Onboarding Sklepika: od pomysłu do pierwszej sprzedaży

**Data badania:** 2026-07-14  
**Zakres:** mikro- i mały sprzedawca B2C w Polsce; flow self-service oraz „zrobione z Tobą”  
**Typ dokumentu:** rekomendacja produktowa oparta na źródłach i hipotezach do testu  
**Poziom pewności:** wysoki dla elementów koniecznych do bezpiecznego startu; średni dla kolejności; niski dla docelowych benchmarków konwersji przed pomiarem własnych kohort

## Werdykt

Jednostką sukcesu Sklepika nie może być „konto utworzone” ani nawet „sklep opublikowany”. Powinna nią być **pierwsza prawdziwa, opłacona i możliwa do realizacji sprzedaż**.

Idealny onboarding działa dwutorowo:

- **tor ekscytacji:** w ciągu kilku minut użytkownik widzi własny, atrakcyjny sklep z produktem;
- **tor gotowości:** system prowadzi go przez dane firmy, płatności, dostawę, polityki, test zamówienia i pozyskanie pierwszego ruchu.

Nie należy zaczynać od długiego formularza KYC ani pustego panelu. Należy najpierw pokazać rezultat, ale utrzymać sklep w trybie roboczym do spełnienia twardych warunków. AI tworzy drafty i redukuje pracę; człowiek zatwierdza fakty, ceny, obietnice, dokumenty i publikację.

## Metoda

Przeanalizowano:

- aktualny proces startowy i checklisty Shopify jako dowód praktyki dojrzałej platformy;
- podejście Stripe do zmiennych wymagań weryfikacyjnych;
- wymagania Google Merchant Center dla produktów, dostawy, zwrotów i jakości strony;
- aktualne obowiązki informacyjne sprzedawcy B2C w UE;
- oficjalny schemat pomiaru lejka e-commerce w GA4;
- stan techniczny Sklepika opisany przez zespół: sklep powstaje automatycznie, a płatności, polityki, produkt, wysyłka i opublikowana strona są elementami gotowości.

Źródła konkurentów opisują ich własne rozwiązania, nie dowodzą, że identyczny flow będzie optymalny dla Sklepika. Kolejność i progi są rekomendacją do walidacji.

## Co jest faktem, a co wnioskiem

### Fakty

- Shopify rozpoczyna konfigurację od produktu, motywu i domeny oraz udostępnia krokową checklistę startową. [Shopify — Getting started](https://help.shopify.com/en/manual/intro-to-shopify/initial-setup/setup-getting-started) i [Intro to Shopify](https://help.shopify.com/en/manual/intro-to-shopify)
- Akceptacja płatności wymaga danych osobowych i firmowych, weryfikacji oraz rachunku do wypłat; wymagania zmieniają się według kraju. [Shopify Payments — account setup](https://help.shopify.com/en/manual/payments/shopify-payments/onboarding/account-setup)
- Stripe rekomenduje hosted lub embedded onboarding, ponieważ te flow automatycznie określają aktualne wymagania dla kraju i ograniczają konieczność utrzymywania własnego procesu KYC. [Stripe Connect](https://docs.stripe.com/connect/migrate-from-api-onboarding)
- Google wymaga dla bezpłatnych listingów m.in. identyfikatora, tytułu, linku, obrazu i ceny produktu oraz konfiguracji dostawy w Polsce; polityka zwrotów wpływa na decyzję klienta. Niekompletna, niedziałająca lub ogólnikowa strona może zostać odrzucona. [Google Merchant Center — Free listings](https://support.google.com/merchants/answer/13889434?hl=en) i [Editorial & technical requirements](https://support.google.com/merchants/answer/12079604?hl=en)
- Przed zakupem konsument w UE musi otrzymać m.in. główne cechy produktu, pełną cenę, koszty dostawy, zasady płatności/dostawy, tożsamość i kontakt sprzedawcy, a przy sprzedaży online także informacje o odstąpieniu. Po zakupie potrzebne jest potwierdzenie na trwałym nośniku. [Your Europe, aktualizacja 29.04.2026](https://europa.eu/youreurope/citizens/consumers/shopping/contract-information/index_en.htm)
- GA4 definiuje kolejne zdarzenia lejka zakupowego, m.in. `view_item`, `add_to_cart`, `begin_checkout`, `add_shipping_info`, `add_payment_info`, `purchase`. [Google Analytics — Ecommerce setup Q&A](https://support.google.com/analytics/answer/14143583?hl=en)

### Wnioski

- Największym błędem byłoby utożsamienie „AI wygenerowało layout” z „sprzedawca jest gotowy przyjąć pieniądze”.
- Płatność i zgodność powinny być twardą bramką publikacji checkoutu, ale nie powinny blokować tworzenia wizualnego draftu.
- Pierwsza sprzedaż wymaga nie tylko sklepu, lecz także pierwszej kampanii/ruchu; onboarding musi obejmować dystrybucję.
- Jeden uniwersalny flow jest gorszy niż trzy rozgałęzienia: „już sprzedaję gdzie indziej”, „mam produkty, ale nie sklep” i „dopiero zaczynam”.

## Definicje sukcesu

```text
TTV-preview = czas od rejestracji do zobaczenia własnego sklepu z co najmniej 1 produktem
activation = właściciel uzupełnił 1 produkt i obejrzał działający preview
launch-ready = produkt + dane firmy + płatność + dostawa + polityki + opublikowana strona + test zamówienia
launched = sklep publiczny i technicznie zdolny przyjąć prawdziwą płatność
first sale = prawdziwe opłacone zamówienie, nie test ani zamówienie właściciela
first fulfilled sale = pierwsze zamówienie oznaczone jako wysłane/zrealizowane bez refundu w pierwszych 7 dniach
```

Północna gwiazda onboardingu: **odsetek nowych sklepów, które osiągnęły first fulfilled sale w 30 dni**. Metryki pomocnicze: mediana czasu do preview, launch-ready, publikacji i pierwszej sprzedaży.

## Rekomendowany flow

### 0. Obietnica przed rejestracją

Użytkownik powinien wiedzieć, jaki rezultat i jakie zobowiązania go czekają:

> „Opowiedz lub pokaż, co sprzedajesz. Za kilka minut zobaczysz własny sklep. Przed przyjęciem płatności pomożemy Ci dodać dane firmy, dostawę, płatności i dokumenty.”

Nie obiecywać „gotowego legalnie sklepu jednym kliknięciem”. System może prowadzić przez zgodność, lecz sprzedawca odpowiada za prawdziwość danych i powinien móc skonsultować dokumenty.

### 1. Konto i natychmiastowy prywatny sklep

Minimalne dane: e-mail, hasło/passkey lub bezpieczny link, nazwa robocza sklepu. Po rejestracji system tworzy sklep w statusie `draft` i przypisuje właściciela. Potwierdzenie e-maila może być wymagane przed publikacją lub działaniem wrażliwym, ale nie powinno blokować preview, jeśli ryzyko nadużycia jest ograniczone rate limitingiem.

Pierwsze pytanie rozgałęzia flow:

- „Już sprzedaję — wkleję link”;
- „Mam produkty/zdjęcia — dodam je”;
- „Mam pomysł — potrzebuję prowadzenia”.

### 2. Pierwszy produkt bez pustego formularza

Drogi wejścia:

- import z podanego przez właściciela URL/marketplace'u za potwierdzeniem praw do treści;
- zdjęcia + dyktowanie/opis;
- CSV;
- ręczny formularz;
- integracja źródłowa później.

AI może wyciągnąć tytuł, warianty, opis, kategorię i zasugerować cenę, ale użytkownik musi zatwierdzić: cenę, VAT, stan, cechy, skład/materiały, ostrzeżenia, pochodzenie i obietnice marketingowe. Nie generować niepotwierdzonych właściwości zdrowotnych ani certyfikatów.

Warunek przejścia: przynajmniej jeden realny produkt ma tytuł, cenę, zdjęcie, opis, dostępność i sposób dostawy.

### 3. „Moment magii”: wygenerowany sklep

Na podstawie produktu i trzech preferencji system generuje stronę główną:

- styl wybrany obrazem lub słowami;
- paleta i typografia dostępne do zmiany;
- hero, lista produktów, historia marki, FAQ i kontakt;
- podgląd mobile/desktop;
- widoczny znacznik „wersja robocza”.

Nie pytać na początku o kilkadziesiąt ustawień layoutu. Edytor służy do poprawiania działającego draftu. AI powinno podać, z jakich danych skorzystało i oznaczyć treści wymagające zatwierdzenia.

Cel produktu: mediana TTV-preview <10 minut dla użytkownika z linkiem/zdjęciami i <20 minut dla ręcznego wejścia. To cel eksperymentalny, nie benchmark rynkowy.

### 4. Kokpit gotowości zamiast liniowego kreatora

Po preview użytkownik widzi sześć kart, ich status i szacowany czas:

1. **Firma i kontakt** — nazwa prawna, adres, e-mail wsparcia, NIP/VAT jeśli dotyczy.
2. **Produkt** — kompletność, bezpieczeństwo i publikowalność.
3. **Płatności** — rozpoczęte/oczekujące/zweryfikowane/ograniczone.
4. **Dostawa i zwroty** — obszar, koszt, termin, sposób realizacji.
5. **Polityki i informacje prawne** — status draft/zatwierdzone, data i wersja.
6. **Wygląd i domena** — opublikowany dokument strony, branding, domena opcjonalna do startu.

Każda karta ma jeden następny krok. Użytkownik może zmieniać kolejność, z wyjątkiem twardych zależności.

### 5. Płatności przez dostawcę, nie własny KYC

Używać hosted/embedded onboarding dostawcy płatności. Sklepik powinien:

- wstępnie wyjaśnić wymagane dane i przewidywany czas;
- przekazać do dostawcy tylko niezbędne dane;
- pokazywać status i powód brakującego wymagania;
- pozwolić wrócić do pozostałych zadań w czasie weryfikacji;
- nie przechowywać zdjęć dokumentów tożsamości, jeśli nie jest to niezbędne;
- wymagać MFA przed wypłatami i zmianą rachunku.

Brak potwierdzonej metody płatności blokuje prawdziwy checkout, nie edycję sklepu.

### 6. Dostawa oparta na rzeczywistym produkcie

Nie zaczynać od matrycy stref. Zapytać: skąd wysyłasz, dokąd, jaki jest typowy rozmiar/waga i jak dziś nadajesz. Zaproponować prosty profil PL, odbiór osobisty lub produkt cyfrowy. Użytkownik zatwierdza koszt i deklarowany czas.

Należy wykonać test: każdy opublikowany fizyczny produkt ma co najmniej jedną metodę dostawy do domyślnego kraju.

### 7. Polityki i informacje prawne jako prowadzony wywiad

System zadaje pytania faktograficzne i tworzy drafty, ale:

- wyraźnie oznacza je jako szablony, nie poradę prawną;
- nie pozwala AI wymyślać danych przedsiębiorcy, terminów ani wyjątków;
- przechowuje wersję, datę i odpowiedzi źródłowe;
- wymaga jawnego „sprawdziłem i zatwierdzam” od właściciela;
- daje drogę do konsultacji prawnika dla produktów regulowanych lub nietypowych modeli;
- potrafi ponownie otworzyć checklistę po zmianie kraju, produktu lub prawa.

### 8. Próba generalna

Przed startem system automatycznie sprawdza linki, mobile, cenę, dostawę, kontakt i checkout. Następnie właściciel wykonuje jedno testowe zamówienie:

```text
produkt → koszyk → dane → dostawa → płatność testowa → potwierdzenie → panel zamówienia → anulowanie/refund testowy
```

Test powinien generować jasny raport, nie mieszać się z przychodem i nie trafiać do realnej realizacji.

### 9. Publikacja z dwoma poziomami

- **Publikuj preview:** publiczny lub chroniony link bez aktywnego checkoutu, do zebrania opinii.
- **Uruchom sprzedaż:** dostępne dopiero po twardych kontrolach gotowości oraz akceptacji właściciela.

Miękkie rekomendacje (własna domena, pięć produktów, „O nas”, dodatkowe zdjęcia) nie powinny blokować pierwszej sprzedaży. Twarde bramki to tylko elementy, bez których transakcja jest niemożliwa, niebezpieczna lub niezgodna.

### 10. Kampania pierwszej sprzedaży

Po uruchomieniu użytkownik wybiera pierwszy kanał:

- link do obecnych obserwujących/klientów;
- kod/QR na stoisko lub opakowanie;
- bezpłatne listingi Google po spełnieniu wymagań;
- kampania launchowa do własnej bazy mającej odpowiednią zgodę;
- link polecający od partnera.

Agent przygotowuje 3–5 treści i UTM-y, ale użytkownik zatwierdza odbiorców i wysyłkę. Bez tego etap „pierwsza sprzedaż” zależy wyłącznie od szczęścia.

### 11. Po pierwszym zamówieniu

Natychmiastowy tryb prowadzenia:

- co dokładnie trzeba wysłać/zrealizować;
- termin i dane klienta w minimalnym zakresie;
- potwierdzenie wysyłki;
- obsługa pytania, anulowania i zwrotu;
- ochrona przed phishingiem i zmianą rachunku;
- prośba o opinię dopiero po realizacji.

Za zakończony onboarding uznajemy pierwsze **zrealizowane**, nie tylko opłacone zamówienie.

## Mapa drop-offów i interwencji

| Etap | Prawdopodobna przyczyna | Sygnał | Interwencja |
|---|---|---|---|
| Rejestracja → produkt | pusty panel, brak materiałów | brak produktu 24 h | wybór: link, zdjęcie, rozmowa z człowiekiem |
| Produkt → preview | za dużo pól, słaby import | wiele błędów walidacji | draft AI + oznaczenie tylko braków krytycznych |
| Preview → gotowość | „już wygląda, reszta później” | edycja layoutu bez działań launch | stały licznik gotowości i jeden następny krok |
| Płatności | brak dokumentu, obawa o dane, pending | porzucony hosted onboarding | wyjaśnienie przed przekierowaniem, status, human support |
| Polityki | strach prawny i niezrozumiały język | otwarte, niezatwierdzone drafty | pytania faktograficzne + opcjonalny prawnik |
| Dostawa | złożona konfiguracja | brak wspólnej strefy produktu | gotowy profil dla najczęstszego przypadku |
| Test zamówienia | błąd integracji lub brak czasu | readiness 5/6 | asysta „zróbmy test razem” |
| Publikacja → sprzedaż | brak ruchu | zero sesji/produkt views | kreator pierwszej kampanii i partner channel |
| Pierwsze zamówienie → realizacja | właściciel nie wie, co zrobić | brak zmiany statusu 24 h | alarm i prosta checklista realizacji |

To lista hipotez. Każdy powód porzucenia powinien być potwierdzany krótkim pytaniem jakościowym, a nie wyłącznie interpretacją eventów.

## Automatyzacja i human-in-the-loop

| Może działać automatycznie | Wymaga potwierdzenia właściciela | Wymaga człowieka/specjalisty w sytuacji ryzyka |
|---|---|---|
| utworzenie prywatnego sklepu, ekstrakcja draftu z własnego URL, resize zdjęć, propozycja layoutu, wykrycie braków, test techniczny | cena, VAT, dostępność, opisy i claims, dane firmy, koszt/termin dostawy, polityki, domena, publikacja, odbiorcy kampanii | odrzucone KYC, branża regulowana, spór/chargeback, nietypowe prawo, podejrzenie oszustwa, treści naruszające prawa |

AI nigdy nie powinno oznaczać własnego draftu jako „zweryfikowany”. Każde pole ma provenance: użytkownik, import, AI, system lub dostawca zewnętrzny.

## Instrumentacja

Minimalne zdarzenia produktu:

```text
signup_started, signup_completed, store_created
onboarding_path_selected
product_import_started, product_draft_created, product_published
preview_generated, preview_viewed, editor_changed
readiness_check_viewed, readiness_item_completed
payments_onboarding_started, payments_restricted, payments_enabled
shipping_configured, policies_approved, domain_connected
test_order_started, test_order_completed
store_preview_published, store_sales_enabled
launch_campaign_created
first_real_order_paid, first_order_fulfilled, first_order_refunded
help_requested, human_intervention_started, onboarding_abandoned_reason
```

Każdy event: `store_id`, kohorta, ścieżka, segment, źródło pozyskania, timestamp i wersja flow. Nie wkładać do analityki pełnych danych produktu, klienta ani dokumentów KYC.

Lejek sklepu po uruchomieniu powinien zachować standardowe wydarzenia `view_item` → `add_to_cart` → `begin_checkout` → `add_shipping_info` → `add_payment_info` → `purchase`, co ułatwia porównywalność z GA4.

## Eksperymenty

### 14 dni

1. Przejść obecny flow pięcioma fikcyjnymi personami i zapisać każde miejsce, gdzie potrzebna jest wiedza techniczna.
2. Zrekrutować 5 realnych sprzedawców; obserwować ekran bez pomagania przez pierwsze 15 minut.
3. Wprowadzić definicje eventów i dashboard kohortowy przed kolejnymi zmianami UI.
4. Porównać dwa wejścia: formularz ręczny kontra „wklej link/dodaj zdjęcia”.
5. Zmierzyć TTV-preview i odsetek użytkowników z jednym poprawnym produktem.

**Kryterium:** 4/5 uczestników samodzielnie widzi własny preview, mediana <20 minut, a każdy blokujący błąd ma właściciela i telemetryczny sygnał.

### 30 dni

1. Uruchomić kokpit gotowości z twardymi i miękkimi wymaganiami.
2. Dodać pełny test zamówienia i raport próby generalnej.
3. Przetestować równolegle 10 sklepów self-service i 10 „zrobione z Tobą”.
4. Dodać ręczne interwencje po 24/72 h, ale mierzyć czas obsługi.
5. Dodać pierwszy prosty flow kampanii launchowej.

**Kryterium:** ≥70% aktywowanych sklepów dochodzi do testowego zamówienia; ≥50% kwalifikowanych płacących pilotów uruchamia sprzedaż w 14 dni; mediana ludzkiej pomocy <90 min/sklep. To progi operacyjne do walidacji.

### 90 dni

1. Zebrać co najmniej 50 kwalifikowanych kohort, nie licząc kont testowych i spamu.
2. Osiągnąć co najmniej 20 sklepów uruchomionych i 10 z first fulfilled sale.
3. Porównać segmenty oraz źródła pozyskania po pierwszej sprzedaży, nie po rejestracji.
4. Zautomatyzować tylko trzy najczęstsze, dobrze rozpoznane interwencje człowieka.
5. Uruchomić cykl „brak pierwszej sprzedaży po 7 dniach”: diagnoza ruch/oferta/checkout + konkretny plan.

**Kryterium:** ≥40% uruchomionych sklepów osiąga first fulfilled sale w 30 dni; refund/fraud nie rośnie względem ręcznie wdrażanej kohorty; minimum 80% nowych właścicieli potrafi samodzielnie dodać drugi produkt. Jeśli generowanie preview rośnie, ale first sale nie, priorytetem jest dystrybucja/oferta, nie bogatszy edytor.

## Kryteria decyzji produktowych

- Funkcja onboardingu wygrywa, jeśli zwiększa `first_fulfilled_sale_30d` albo skraca czas/człowieka bez pogorszenia bezpieczeństwa.
- Nie skalujemy źródła rejestracji z niską kwalifikacją tylko dlatego, że obniża koszt konta.
- Nie dodajemy pola do pierwszej sesji, jeśli nie jest potrzebne do preview; nie usuwamy bramki, jeśli jest potrzebna do prawdziwej transakcji.
- Automatyzujemy krok dopiero po co najmniej 20 ręcznych przypadkach i opisaniu wyjątków.
- Każdy twardy gate musi mieć uzasadnienie, widoczny status i drogę naprawy.
- Każde sugerowane przez AI pole musi być edytowalne i mieć źródło.

## Priorytety wdrożeniowe

1. Wspólna maszyna stanów `draft → preview → launch_ready → live → suspended`.
2. Jeden kanoniczny serwis readiness dostępny w adminie i API.
3. Eventy i kohorty do first fulfilled sale.
4. Import pierwszego produktu i szybki preview.
5. Hosted/embedded payments onboarding.
6. Testowe zamówienie end-to-end.
7. Kampania pierwszej sprzedaży.
8. Dopiero potem bardziej rozbudowany generator layoutów i proaktywne AI.

## Źródła pierwotne

1. [Shopify — Getting started](https://help.shopify.com/en/manual/intro-to-shopify/initial-setup/setup-getting-started)
2. [Shopify — Intro and setup checklist](https://help.shopify.com/en/manual/intro-to-shopify)
3. [Shopify — Store design checklist](https://help.shopify.com/en/manual/intro-to-shopify/store-design)
4. [Shopify Payments — Account setup](https://help.shopify.com/en/manual/payments/shopify-payments/onboarding/account-setup)
5. [Stripe Connect — Hosted/embedded onboarding](https://docs.stripe.com/connect/migrate-from-api-onboarding)
6. [Google Merchant Center — Free listings requirements](https://support.google.com/merchants/answer/13889434?hl=en)
7. [Google Merchant Center — Editorial and technical requirements](https://support.google.com/merchants/answer/12079604?hl=en)
8. [Your Europe — Contract information, aktualizacja 29.04.2026](https://europa.eu/youreurope/citizens/consumers/shopping/contract-information/index_en.htm)
9. [Google Analytics — Ecommerce funnel events](https://support.google.com/analytics/answer/14143583?hl=en)

## Co obniża pewność

- brak własnych danych Sklepika o porzuceniach;
- brak obserwacji realnych, nietechnicznych użytkowników w tym badaniu;
- różne branże wymagają innych danych produktu i zgodności;
- KYC i dostępne metody płatności zależą od wybranego dostawcy i kraju;
- progi 10/20/40/70% są hipotezami zarządczymi, nie benchmarkami rynku.

