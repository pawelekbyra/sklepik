# Gdzie są pieniądze: rynek i segmenty dla Sklepika

**Data:** 2026-07-14  
**Zakres:** Polska jako rynek wejścia; UE jako kolejny etap  
**Status:** research decyzyjny, nie zatwierdzona strategia ani cennik

## Executive verdict

Najbardziej obiecującym pierwszym klientem nie jest „każdy, kto chce sklep”, początkujący hobbysta ani duży merchant. Jest nim **mała, już sprzedająca marka produktowa z prostym katalogiem (około 5–100 SKU), której właściciel nie chce składać technologii i potrzebuje doprowadzenia od produktów do działającej sprzedaży**.

Rekomendowany klin wejścia w Polsce:

1. operator zakłada sklep klientowi jako produktową usługę;
2. klient przejmuje produkty, zamówienia i prostą edycję treści;
3. powtarzalne czynności stają się assisted self-service;
4. dopiero sprawdzony proces otrzymują freelancerzy i mikroagencje.

Wejście do UE powinno najpierw oznaczać **pomoc polskim merchantom w sprzedaży do jednego sąsiedniego rynku**, a nie natychmiastową akwizycję zagranicznych klientów. Najrozsądniejszy test to jedna para kraj–branża, np. polska marka lifestyle sprzedająca do Czech albo Słowacji. Niemcy są atrakcyjniejsze wartościowo, lecz wymagają dojrzalszej lokalizacji, obsługi i zgodności.

Najważniejsza prawda cenowa: abonament za samo oprogramowanie jest już silnie skomodytyzowany. Pieniądze na początku są w **wdrożeniu, konfiguracji, migracji, lokalnym „ready to sell” i dalszej opiece**, nie w samym utworzeniu repozytorium.

## Metoda i ograniczenia

Research łączy:

- dane publiczne GUS, PARP, NBP, Eurostat i Komisji Europejskiej;
- aktualne publiczne oferty i cenniki Shopify, Shoper, IdoSell i Duda;
- oficjalne dokumentacje Shopify, Vercel i platform headless;
- wnioski produktowe wynikające z istniejącej architektury Sklepika.

Nie znaleziono wiarygodnego publicznego badania willingness-to-pay dokładnie dla polskich mikroproducentów kupujących nowy sklep headless. Publiczne ceny konkurentów pokazują **dostępne alternatywy i kotwice cenowe**, a nie rzeczywistą gotowość konkretnego segmentu do zapłaty. Hipotezy WTP muszą zostać zweryfikowane płatnymi pilotami.

### Skala pewności

- **Wysoka** — aktualne dane urzędowe albo aktualny publiczny cennik.
- **Średnia** — spójny wniosek z kilku źródeł, wymagający rozmów z klientami.
- **Niska** — hipoteza segmentacyjna lub cenowa do eksperymentu.

## Fakty o rynku polskim

### Popyt konsumencki istnieje, lecz sam rynek jest dojrzały

**Fakt — wysoka pewność.** Według GUS 69,7% osób w wieku 16–74 lata kupiło coś przez internet w ciągu 12 miesięcy w 2025 r., o 2,3 p.p. więcej niż rok wcześniej. Dostęp do internetu miało 96,2% gospodarstw domowych. [GUS, „Społeczeństwo informacyjne w Polsce w 2025 r.”](https://stat.gov.pl/obszary-tematyczne/nauka-i-technika-spoleczenstwo-informacyjne/spoleczenstwo-informacyjne/spoleczenstwo-informacyjne-w-polsce-w-2025-r-%2C2%2C15.html)

**Fakt — wysoka pewność.** Sprzedaż internetowa odpowiadała w 2025 r. za 9,1% polskiej sprzedaży detalicznej. Udział różnił się mocno między kategoriami: 25,2% dla tekstyliów/odzieży/obuwia, 17,7% dla mebli/RTV/AGD, 6,9% dla farmaceutyków/kosmetyków/sprzętu ortopedycznego i 0,9% dla żywności/napojów/tytoniu. Dane GUS dotyczą struktury sprzedaży detalicznej, nie rentowności nowych sklepów. [GUS, sytuacja społeczno-gospodarcza — rynek wewnętrzny 2025](https://ssgk.stat.gov.pl/01.2026/Rynek_wewnetrzny.html)

**Wniosek — średnia pewność.** Sklepik nie musi edukować rynku, czym jest zakup online. Musi odpowiedzieć, dlaczego merchant ma uruchomić własny kanał zamiast zostać przy marketplace, social media albo gotowym SaaS.

### Mikrofirm jest dużo, ale ich przeżywalność i budżety są nierówne

**Fakt — wysoka pewność.** PARP podaje, że mikroprzedsiębiorstwa stanowią 97,2% polskich firm (około 2,3 mln). W najnowszej obserwowanej kohorcie pierwszy rok przetrwało 68,4% nowo powstałych firm. [PARP, kondycja sektora MŚP 2026](https://www.parp.gov.pl/component/content/article/90455%3Akondycja-sektora-msp-w-polsce---najnowszy-raport-parp)

**Fakt — wysoka pewność.** W danych opisanych przez PARP firmy prowadzące e-sprzedaż najczęściej korzystały z własnych stron lub aplikacji (78,6%), ale równolegle 62,5% korzystało z platform handlowych. Dane dotyczą firm objętych badaniem ICT i nie są czystym pomiarem mikrofirm jednoosobowych. [PARP, Raport o stanie sektora MŚP 2026](https://en.parp.gov.pl/storage/publications/pdf/ROSS_2026___29-04-2026.pdf)

**Wniosek — wysoka pewność.** „Własny sklep zamiast marketplace” to fałszywa alternatywa. Klient potrzebuje własnego kanału **obok** Allegro, Etsy, Instagrama czy sprzedaży targowej. Integracja i import są ważniejsze niż ideologiczna wyłączność.

### Lokalne płatności są obowiązkowym elementem produktu

**Fakt — wysoka pewność.** NBP podał, że w I kwartale 2025 r. 49% wszystkich operacji BLIK stanowiły płatności internetowe; rozliczono 325,54 mln takich transakcji o wartości 50,61 mld zł. NBP wskazuje BLIK jako najczęściej wybierany sposób płatności za zakupy online. [NBP, informacja o rozliczeniach w I kw. 2025](https://nbp.pl/wp-content/uploads/2025/11/Informacja-o-rozliczeniach-i-rozrachunkach-miedzybankowych-w-I-kw.-2025.pdf)

**Wniosek — wysoka pewność.** Sklep technicznie opublikowany, ale bez BLIK/odpowiedniej bramki, dostawy, zwrotów i stron prawnych, nie realizuje obietnicy „gotowy do sprzedaży”.

## Obecne alternatywy i kotwice budżetowe

### Tani SaaS

**Fakt — wysoka pewność, ceny odczytane 2026-07-14.** Shopify Basic kosztuje publicznie 79 zł miesięcznie przy płatności rocznej albo 109 zł miesięcznie; opublikowane stawki Shopify Payments obejmują m.in. BLIK 1,3% + 1,20 zł. [Shopify Polska — cennik](https://www.shopify.com/pl/pricing)

**Fakt — wysoka pewność, z zastrzeżeniem promocji.** Shoper reklamuje pierwszy rok Standard za 29 zł netto miesięcznie przy płatności z góry, lecz podaje, że po pierwszym roku cena miesięczna Standard/Standard+ wynosi 299 zł netto. Premium jest reklamowany promocyjnie za 480 zł netto miesięcznie, a standardowa cena miesięczna zaczyna się od 729 zł netto. Oferta zawiera hosting, support, integracje, zgodność GPSR/EAA i drag-and-drop. [Shoper — cennik](https://www.shoper.pl/cennik-sklepu-shoper)

**Interpretacja — wysoka pewność.** Sklepik nie wygra ceną samego abonamentu z promocją 29–109 zł. Musi sprzedawać lepszy rezultat, obsługę albo elastyczność dla konkretnej grupy.

### Wdrożenie i indywidualizacja

**Fakt — średnia/wysoka pewność.** IdoSell publikuje stawkę 180 zł/h dla prac indywidualnych i komunikuje pakiet GO+ o wartości 14 999 zł w ofertach kontraktowych. Pakiety obejmują konfigurację, import, szkolenie, branding i prace UX/UI. Cena promocyjna „za 1 zł” jest powiązana z umową i nie pokazuje kosztu ekonomicznego w izolacji. [IdoSell — oferta i pakiety wdrożeniowe](https://www.idosell.com/pl/order/)

**Fakt — średnia pewność, dane własne dostawcy.** Duda oferuje agencyjny white-label od 149 USD miesięcznie, z rolami klientów, dashboardem, preview i billingiem. [Duda — white-label](https://www.duda.co/website-builder/white-label)

**Interpretacja — średnia pewność.** Na rynku istnieje akceptowany rozdział między abonamentem infrastrukturalnym a opłatą za doprowadzenie sklepu do formy dopasowanej do biznesu. To tworzy miejsce dla produktowego wdrożenia Sklepika w tysiącach, nie dziesiątkach złotych — ale dopiero płatne pilotaże potwierdzą wysokość.

## Segmentacja według rzeczywistego problemu

### A. Walidowana mikro-/mała marka produktowa

**Profil:** 5–100 SKU, istniejąca sprzedaż z targów/social/marketplace, 20–200 zamówień miesięcznie albo powtarzalni klienci offline, właściciel nadal blisko operacji.

**Problem:** sprzedaż jest rozproszona; ręczne wiadomości nie skalują się; marka wygląda mniej profesjonalnie niż produkt; właściciel nie chce zarządzać hostingiem i wtyczkami.

**Alternatywy:** Shoper/Shopify/WooCommerce, pozostanie na marketplace, freelancer, agencja.

**WTP — hipoteza, niska pewność:** 2,5–6 tys. zł za gotowy start i 199–499 zł miesięcznie, jeżeli oferta realnie obejmuje konfigurację płatności, dostawy, domenę, import i opiekę. Nie potwierdzone badaniem.

**Ocena:** najlepszy pierwszy klient.

### B. Hobbysta i działalność nierejestrowana

**Profil:** nieregularna sprzedaż, często mniej niż kilkanaście zamówień miesięcznie.

**Fakt:** limit działalności nierejestrowanej w 2026 r. wynosi 10 813,50 zł przychodu należnego na kwartał. [Biznes.gov.pl — działalność nierejestrowa](https://biznes.gov.pl/pl/firma/zakladanie-firmy/chce-wiedziec-jak-zalozyc-wlasna-firme/dzialalnosc-nierejestrowa-oraz-inne-sytuacje-w-ktorych-nie-trzeba-rejestrowac-firmy)

**Problem:** niska pewność popytu i silna awersja do stałych kosztów.

**Wniosek:** dobry użytkownik darmowego testu lub przyszłego self-service, słaby klient dla pracochłonnego done-for-you. Nie budować ekonomii pierwszego etapu na tej grupie.

### C. Istniejący sklep wymagający migracji

**Profil:** realny GMV, dane i proces, ale frustracja aktualną platformą.

**Problem:** ryzyko SEO, danych klientów, integracji i przerwy sprzedaży.

**WTP:** wyższe niż nowy sklep, lecz wymagania i odpowiedzialność również znacznie wyższe.

**Wniosek:** atrakcyjny segment po zbudowaniu importerów, redirectów, procedury rollbacku i checkoutu potwierdzonego na produkcji. Nie na pierwsze pięć wdrożeń.

### D. Freelancer lub mikroagencja

**Profil:** zakłada kilka–kilkanaście sklepów rocznie i zarabia na wdrożeniu oraz opiece.

**Problem:** powtarzalna konfiguracja, zbieranie materiałów, aktualizacje, role, handoff, utrzymanie wielu instalacji.

**Sygnał popytu:** Shoper deklaruje ponad 5 tys. partnerów, a Shopify i Duda rozwijają osobne narzędzia partnerów. To dowód istnienia workflow, nie dowód chęci migracji do Sklepika. [Shoper — program partnerski](https://www.shoper.pl/program-partnerski), [Shopify — stores and roles for partners](https://www.shopify.com/partners/blog/improved-building-for-partners)

**Wniosek:** najlepszy kanał skalowania po udowodnieniu procesu merchantowego. Agencja nie kupi samej wizji; kupi skrócenie godzin pracy, marżę i przewidywalność.

### E. Rosnący merchant / B2B / duży katalog

**Problem:** ERP, WMS, SLA, wielomagazynowość, ceny kontraktowe, zwroty, integracje.

**Wniosek:** potencjalnie wysoki ACV, ale segment zbliża Sklepik do IdoSell, Shopware, Saleor i commercetools, zanim platforma ma stabilne podstawy. Świadomie odłożyć.

## Ranking nisz na wejście w Polsce

Ocena 1–5 uwzględnia pilność problemu, WTP, prostotę katalogu, koszt obsługi, dopasowanie do obecnego produktu i możliwość dotarcia. Wynik jest **hipotezą strategiczną**, nie pomiarem rynku.

| Miejsce | Nisza | Wynik | Uzasadnienie |
|---|---|---:|---|
| 1 | Walidowane marki handmade/lifestyle, ale bez ciężkiej regulacji | 24/30 | branding ważny, proste katalogi, sprzedaż już istnieje, możliwa bezpośrednia akwizycja |
| 2 | Mali producenci prezentów, dekoracji i produktów premium | 23/30 | wysoka wartość narracji i zestawów, sezonowość tworzy trigger, łatwa demonstracja |
| 3 | Twórcy/influencerzy z fizycznym produktem | 21/30 | mają dystrybucję, chcą własnej marki; większa zmienność i oczekiwania designu |
| 4 | Lokalne marki odzieżowe z małym katalogiem | 20/30 | wysoki udział online, lecz warianty, zwroty i konkurencja zwiększają złożoność |
| 5 | Mikroproducenci kosmetyków, np. mydła | 19/30 | dobry storytelling i zakup powtarzalny, ale obowiązki kosmetyczne zwiększają ryzyko produktu i supportu |
| 6 | Mali producenci żywności | 17/30 | naturalne dopasowanie do historii Kakao, lecz niski udział online w kategorii i dodatkowe wymogi żywnościowe/logistyczne |
| 7 | Freelancerzy tworzący sklepy | 17/30 teraz, 25/30 później | mocny mnożnik dystrybucji, ale potrzebują dojrzałego white-label, ról, billingów i stabilności |
| 8 | Migracje istniejących sklepów | 15/30 teraz, 23/30 później | wyższy budżet, lecz duże ryzyko SEO/danych/ciągłości |

### Rekomendacja niszy

Rozpocząć nie od deklaracji branżowej, lecz od filtra operacyjnego:

> „Masz już produkt i pierwszych klientów, 5–100 produktów, sprzedajesz ręcznie lub przez marketplace, ale nie masz własnego sklepu gotowego do przyjmowania zamówień.”

W pierwszych 10 pilotach dopuszczać kilka sąsiednich kategorii, ale mierzyć czas konfiguracji, blokery i konwersję osobno. Po 10 wdrożeniach wybrać pion, w którym czas do publikacji i pierwszego zamówienia jest najlepszy.

## Sensowne wejście do UE

### Fakty

W 2024 r. zakupy online deklarowało 86% czeskich i 85% słowackich użytkowników internetu, wobec 83% w Niemczech. To pokazuje dojrzałość popytu, nie łatwość zdobycia merchantów. [Destatis na podstawie Eurostatu](https://www.destatis.de/Europa/EN/Topic/Science-technology-digital-society/Onlineshopping_Products.html)

Od 2025 r. unijny SME VAT scheme może upraszczać zwolnienie VAT małym przedsiębiorcom o łącznym obrocie w UE do 100 tys. euro, jeśli spełniają warunki krajowe; OSS nadal służy rozliczaniu sprzedaży B2C między krajami. Platforma nie powinna jednak udzielać automatycznych porad podatkowych bez walidacji eksperta. [Komisja Europejska — cross-border SME scheme](https://sme-vat-rules.ec.europa.eu/sme-scheme/cross-border-sme-scheme_en), [VAT OSS](https://vat-one-stop-shop.ec.europa.eu/index_en)

### Kolejność

1. **Polski merchant sprzedający za granicę** — najniższy koszt akwizycji; trzeba dodać język, walutę, wysyłkę, zwroty, podatki i lokalny checkout.
2. **Słowacja, partner-led** — mały rynek testowy, euro i bliskość geograficzna; sensowny do nauki, nie do maksymalizacji TAM.
3. **Czechy, partner-led** — wysoki udział zakupów online i większy rynek, ale wymaga lokalnego partnera, języka i zbadania konkurencji.
4. **Niemcy** — dopiero po sprawdzeniu dostępności, lokalizacji prawnej, zwrotów i supportu; duży rynek nie rekompensuje niegotowego produktu.

Nie należy „włączać UE” jako jednej flagi. Każdy kraj powinien mieć checklistę gotowości oraz co najmniej jednego lokalnego partnera lub eksperta.

## Decyzje produktowe wynikające z researchu

1. Głównym obiektem onboardingu jest **gotowość do sprzedaży**, nie deployment.
2. Dashboard powinien prowadzić checklistą: produkty → domena → płatności → dostawa → strony prawne → testowe zamówienie → publikacja.
3. Import z arkusza/marketplace i zbieranie materiałów od klienta mają wyższy priorytet niż rozbudowany drag-and-drop.
4. Repo/Vercel należy ukryć przed merchantem, a eksponować agencji i deweloperowi.
5. Platforma potrzebuje pakietów branżowych zawierających strukturę danych, treści obowiązkowe i proces, nie tylko kolory.
6. Pierwszy vertical nie może wymagać funkcji, których core jeszcze nie obsługuje niezawodnie.
7. Ekspansja UE zaczyna się od cross-border obecnego merchanta.

## Eksperymenty

### 14 dni

- 15 rozmów: 10 walidowanych mikrobrandów, 5 freelancerów.
- Pokazać dwa komunikaty: „sklep w dwa kliknięcia” kontra „gotowy do sprzedaży z naszą pomocą”.
- Poprosić o podpisanie płatnej deklaracji pilota, nie tylko ocenę pomysłu.
- Zebrać rzeczywisty obecny stack, miesięczne koszty i liczbę godzin obsługi zamówień.

**Próg:** co najmniej 5 osób zgadza się na kolejną rozmowę z konkretnymi danymi, a 2 akceptują płatny pilot.

### 30 dni

- Uruchomić 3–5 sklepów done-for-you w dwóch sąsiednich niszach.
- Mierzyć osobno czas maszyny, czas operatora i czas oczekiwania na klienta.
- Przetestować dwie ceny wdrożenia i jeden abonament.
- Każdy sklep musi przejść testowe zamówienie; sukces biznesowy to pierwsze realne zamówienie.

**Próg:** mediana pracy operatora poniżej 12 godzin, co najmniej 60% pilotów publikuje, co najmniej 2 sklepy otrzymują realne zamówienie w 30 dni.

### 90 dni

- 10 płatnych sklepów, z czego minimum 6 w jednym powtarzalnym profilu.
- Jeden freelancer tworzy drugi sklep bez prowadzenia za rękę.
- Jeden polski merchant testuje wersję językową i dostawę do jednego kraju UE.
- Porównać CAC founder-led z marżą z wdrożenia i przewidywanym 12-miesięcznym abonamentem.

**Próg:** co najmniej 70% wdrożonych sklepów nadal aktywnych po 90 dniach, support poniżej 2 h/sklep/miesiąc i dodatnia marża kontrybucyjna wdrożenia.

## Mierniki przychodu i walidacji

North-star na etapie komercjalizacji:

> liczba płacących sklepów, które przyjęły co najmniej jedno prawdziwe zamówienie w ostatnich 30 dniach.

Dodatkowo:

- przychód z wdrożeń i marża brutto wdrożenia;
- MRR oraz MRR na aktywny sklep;
- odsetek rejestracji kończących się publikacją i pierwszym zamówieniem;
- median time-to-ready-to-sell i time-to-first-order;
- godziny operatora na uruchomiony sklep;
- support hours/store/month;
- 90- i 180-dniowa retencja płacących sklepów;
- udział klientów pozyskanych przez polecenie/partnera;
- liczba partnerów, którzy uruchomili drugi sklep;
- przychód z usług do MRR — powinien finansować naukę, ale z czasem maleć jako udział całości.

## Źródła główne

- [GUS — Społeczeństwo informacyjne w Polsce w 2025 r.](https://stat.gov.pl/obszary-tematyczne/nauka-i-technika-spoleczenstwo-informacyjne/spoleczenstwo-informacyjne/spoleczenstwo-informacyjne-w-polsce-w-2025-r-%2C2%2C15.html)
- [GUS — sprzedaż detaliczna przez internet w 2025 r.](https://ssgk.stat.gov.pl/01.2026/Rynek_wewnetrzny.html)
- [PARP — Raport o stanie sektora MŚP 2026](https://en.parp.gov.pl/storage/publications/pdf/ROSS_2026___29-04-2026.pdf)
- [NBP — rozliczenia i BLIK, I kw. 2025](https://nbp.pl/wp-content/uploads/2025/11/Informacja-o-rozliczeniach-i-rozrachunkach-miedzybankowych-w-I-kw.-2025.pdf)
- [Shopify Polska — cennik](https://www.shopify.com/pl/pricing)
- [Shoper — cennik](https://www.shoper.pl/cennik-sklepu-shoper)
- [IdoSell — cennik i wdrożenia](https://www.idosell.com/pl/order/)
- [Duda — white-label](https://www.duda.co/website-builder/white-label)
- [Eurostat — Digitalisation in Europe 2025](https://ec.europa.eu/eurostat/web/interactive-publications/digitalisation-2025)
- [Komisja Europejska — VAT OSS](https://vat-one-stop-shop.ec.europa.eu/index_en)
- [Komisja Europejska — SME VAT scheme](https://sme-vat-rules.ec.europa.eu/index_en)
