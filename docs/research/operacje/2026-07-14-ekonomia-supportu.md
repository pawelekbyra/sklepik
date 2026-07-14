# Ekonomia supportu Sklepika

**Data:** 2026-07-14  
**Zakres:** onboarding i bieżąca obsługa mikro- i małych sprzedawców  
**Poziom pewności:** wysoki dla modelu pomiaru; średni dla kategorii; niski dla wartości minutowych przed pilotażem  
**Ważne:** wszystkie wartości czasu i kosztu oznaczone jako założenia trzeba zastąpić danymi z pierwszych sklepów.

## Werdykt

Największym zagrożeniem dla ekonomiki Sklepika nie jest koszt hostingu ani tokenów, lecz **niezmierzona praca człowieka ukryta w „łatwym wdrożeniu”**. Model może być bardzo rentowny, jeśli oddzieli się:

- jednorazową pracę uruchomieniową od miesięcznego supportu;
- oczekiwanie na klienta/dostawcę od aktywnego czasu pracy;
- błąd produktu od edukacji klienta i usługi wykonywanej za niego;
- pomoc objętą planem od pracy projektowej.

Przez pierwszych 20–30 pilotów nie należy maksymalizować automatyzacji. Trzeba wykonać badanie time-motion i dowiedzieć się, gdzie naprawdę znika czas. AI powinno najpierw streszczać, diagnozować i przygotowywać odpowiedzi. Samodzielne wykonywanie zmian można włączyć dopiero dla częstych, przewidywalnych i odwracalnych czynności.

Docelowa zasada ekonomiczna: **pełny koszt wsparcia w pierwszych 12 miesiącach ≤30% marży kontrybucyjnej klienta**, a dla planu self-service bieżący support powinien zejść do mediany ≤20 minut na aktywny sklep miesięcznie.

## Metoda i fakty

Nie istnieje wiarygodny uniwersalny benchmark minut supportu dla platformy o dokładnie takim modelu. Raport buduje więc model bottom-up.

Punkty odniesienia:

- przeciętne wynagrodzenie brutto w sektorze przedsiębiorstw w Polsce wyniosło w maju 2026 r. 9 173,24 PLN; to szeroki wskaźnik, **nie stawka pracownika supportu**. [GUS, 22.06.2026](https://stat.gov.pl/files/gfx/portalinformacyjny/pl/defaultaktualnosci/5474/3/173/1/przecietne_zatrudnienie_i_wynagrodzenie_w_sektorze_przedsiebiorstw_w_maju_2026_r.pdf)
- minimalna stawka godzinowa w 2026 r. wynosi 31,40 PLN, ale nie obejmuje pełnego kosztu zatrudnienia, narzędzi, zarządzania ani nieproduktywnego czasu. [Dz.U. 2025 poz. 1242](https://api.sejm.gov.pl/eli/acts/DU/2025/1242/text.pdf)
- dojrzałe platformy dokumentują osobno problemy płatności, dostawy i domen. Przykładowo brak stawki wysyłki blokuje przejście klienta do płatności, więc takie zgłoszenie ma wyższy priorytet niż pytanie wizualne. [Shopify — troubleshooting payments](https://help.shopify.com/en/manual/payments/troubleshooting) i [domains](https://help.shopify.com/en/manual/domains/troubleshoot-issues-with-domains?locale=en-US)
- hosted/embedded onboarding dostawcy płatności ogranicza konieczność utrzymywania własnego, zmieniającego się flow KYC. [Stripe Connect](https://docs.stripe.com/connect/migrate-from-api-onboarding)

### Wnioski i jawne założenia

- Support prawdopodobnie będzie największym kosztem zmiennym kontrolowanym przez Sklepik — to wniosek wymagający time-motion, nie zmierzony fakt.
- Przedziały minut, koszt 1,00/1,80/3,00 PLN za minutę oraz progi marży w dalszej części są scenariuszami zarządczymi.
- Zakładamy model hybrydowy: self-service, assisted i done-for-you. Jeśli oferta zostanie uproszczona do jednego planu, model trzeba przeliczyć.
- Zakładamy, że zewnętrzny dostawca przejmuje zasadniczy KYC; własna obsługa pełnego KYC istotnie podniosłaby koszt i ryzyko.

## Jednostka pomiaru

Nie mierzymy „liczby ticketów” bez kontekstu. Jednostką kosztu jest **aktywna minuta pracy przypisana do sklepu i rezultatu**.

```text
active_minutes = czas realnej diagnozy, komunikacji lub wykonania
elapsed_time = czas od zgłoszenia do zamknięcia
waiting_time = elapsed_time − active_minutes
touches = liczba powrotów człowieka do sprawy
rework_minutes = praca po błędnej diagnozie albo ponownym otwarciu
```

Każda interwencja ma `store_id`, fazę, kategorię, przyczynę, kanał, osobę/model, aktywne minuty, oczekiwanie, rezultat, ponowne otwarcie i informację, czy ujawniła błąd produktu.

## Fazy kosztu na sklep

| Faza | Okres | Co mierzyć osobno |
|---|---|---|
| kwalifikacja | przed płatnością | rozmowa, audyt, prototyp; należy do CAC, nie supportu |
| wdrożenie | rejestracja → live | produkty, płatności, dostawa, polityki, layout, domena, test |
| first-sale care | live → pierwsza realizacja | kampania startowa, checkout, pierwsze zamówienie i wysyłka |
| steady state | kolejne miesiące | pytania, zmiany, incydenty, billing |
| offboarding | rezygnacja/migracja | eksport, domena, retencja danych, zwrot |

Mieszanie tych faz fałszuje CAC, marżę i ocenę produktu.

## Taksonomia zgłoszeń

| Kod | Kategoria | Typowy owner | Priorytet domyślny |
|---|---|---|---|
| `AUTH` | logowanie, role, dostęp do sklepu | produkt/support | P1, jeśli właściciel zablokowany |
| `CATALOG` | produkt, wariant, zdjęcie, cena, stan | self-service/content assist | P2 |
| `EDITOR` | layout, treść, publikacja strony | self-service/design assist | P3 |
| `PAYMENTS_KYC` | weryfikacja, payout, wymagania dostawcy | dostawca + human | P1/P2 |
| `CHECKOUT` | koszyk, płatność, realne zamówienie | engineering/support | P1 |
| `SHIPPING` | stawki, obszar, etykiety, brak metody | support/produkt | P1/P2 |
| `LEGAL_INFO` | dane firmy, polityki, zgody | owner + prawnik przy ryzyku | P2 |
| `DOMAIN_DNS` | domena, SSL, rekordy | support/platform | P2 |
| `ORDERS` | realizacja, refund, zwrot, status | merchant operations | P1/P2 |
| `MARKETING` | kampania startowa, feed, SEO | usługa dodatkowa | P3 |
| `BILLING` | plan, faktura, rezygnacja | support/finance | P2 |
| `BUG` | potwierdzony defekt platformy | engineering | wg wpływu |
| `HOW_TO` | edukacja bez błędu | knowledge/self-service | P3 |
| `DONE_FOR_YOU` | wykonanie pracy za klienta | płatna usługa | wg SLA planu |
| `ABUSE_RISK` | fraud, bezpieczeństwo, produkt zakazany | trust/risk | P0/P1 |

Obowiązkowe pole `root_cause`: `product_defect`, `missing_guidance`, `customer_error`, `provider_dependency`, `custom_request`, `risk_review`, `unknown`. Jeśli ten sam `missing_guidance` pojawia się pięć razy, powstaje zadanie produktowe, a nie tylko kolejny artykuł supportu.

## Model minut — hipoteza startowa

### Nowy sklep, pierwsze 30 dni

| Czynność | Self-service | Assisted | Done-for-you |
|---|---:|---:|---:|
| orientacja i kwalifikacja po zakupie | 10–20 min | 20–40 | 30–60 |
| pierwszy produkt/import | 5–20 | 20–45 | 45–120 |
| layout i treści | 5–15 | 30–60 | 90–240 |
| płatności/KYC — aktywny czas Sklepika | 5–15 | 10–25 | 15–40 |
| dostawa | 5–20 | 15–40 | 30–90 |
| informacje prawne — bez porady | 5–15 | 15–30 | 30–60 |
| domena i próba generalna | 10–25 | 20–45 | 30–75 |
| pierwsza sprzedaż/realizacja | 5–20 | 20–45 | 30–90 |
| **suma hipotezy** | **50–150** | **150–330** | **300–775** |

To nie są benchmarki. Tabela określa, co mierzyć i dlaczego plan „done-for-you” nie może kosztować tyle samo co self-service.

### Bieżący miesiąc po uruchomieniu

- self-service: mediana docelowa 0–20 min, P90 ≤60 min;
- assisted: 30–90 min w cenie planu;
- done-for-you: sprzedawany blok godzin/SLA, nie „nielimitowany support”.

Należy raportować medianę, P75/P90 i odsetek sklepów bez kontaktu. Średnia jest podatna na pojedyncze incydenty.

## Koszt jednej minuty

```text
fully_loaded_monthly_cost = płaca brutto + koszt pracodawcy + narzędzia + udział managementu + rekrutacja/szkolenie
productive_minutes = godziny robocze − urlopy − spotkania − szkolenie − przerwy − praca wewnętrzna
cost_per_active_minute = fully_loaded_monthly_cost / productive_minutes
```

Do pierwszego modelu finansowego użyć trzech scenariuszy, zamiast jednej fałszywie dokładnej kwoty:

- **niski:** 1,00 PLN/aktywna minuta;
- **bazowy:** 1,80 PLN/min;
- **wysoki/specjalistyczny:** 3,00 PLN/min.

Przy koszcie 1,80 PLN/min:

- 120 min onboardingu = 216 PLN;
- 20 min miesięcznie = 36 PLN;
- 90 min miesięcznie = 162 PLN;
- jeden incydent 4 h = 432 PLN.

Własny czas właściciela również trzeba wycenić stawką alternatywną. „Robię to sam za darmo” ukrywa koszt i blokuje decyzję o zatrudnieniu.

## Marża po supporcie

```text
revenue_12m = setup_fee + 12 × subscription + transaction_revenue + paid_services
variable_cost_12m = infra + AI + email/media + payment/platform variable fees
support_cost_12m = active_minutes_12m × cost_per_minute
contribution_margin_12m = revenue_12m − variable_cost_12m − support_cost_12m
support_ratio = support_cost_12m / (revenue_12m − variable_cost_12m)
```

Przykład wyłącznie ilustracyjny: 1 490 PLN wdrożenia + 149 PLN/mies. daje 3 278 PLN przychodu 12M. Jeśli koszty techniczne wynoszą 360 PLN, a support 300 min × 1,80 = 540 PLN, marża kontrybucyjna to 2 378 PLN przed CAC i kosztami stałymi. Jeśli ten sam klient zużyje 1 200 minut, support kosztuje 2 160 PLN i prawie zjada model.

### Progi zarządcze

- support ratio: cel ≤30%, alarm >40%;
- zwrot opłaty wdrożeniowej względem pracy startowej: ≤30 dni;
- medianowy miesięczny support self-service: ≤20 min;
- P90 nie może być ignorowane — sklepy powyżej 180 min/mies. wymagają zmiany planu, usługi płatnej lub rozwiązania przyczyny;
- błąd platformy nigdy nie jest płatną usługą klienta, ale jego koszt trafia do jakości produktu.

## AI kontra human-in-the-loop

### Poziom 0 — zapobieganie

Readiness checks, walidacja przed publikacją, status dostawcy płatności, diagnostyka domeny i próba generalna. Najtańszy ticket to ten, który nie powstał.

### Poziom 1 — samoobsługa kontekstowa

Agent widzi stan konkretnego sklepu i pokazuje jeden następny krok. Nie odpowiada ogólną instrukcją, gdy może wskazać brakującą konfigurację.

### Poziom 2 — copilot pracownika

Automatycznie: klasyfikacja, podsumowanie historii, wyszukanie dokumentacji, propozycja odpowiedzi i aktualizacja pól. Człowiek zatwierdza. To pierwszy rekomendowany poziom.

### Poziom 3 — wykonanie odwracalne

Po akceptacji klienta agent może np. przygotować draft opisu, zmienić kolejność sekcji, ponowić bezpieczny test lub wygenerować checklistę. Musi istnieć log i rollback.

### Poziom 4 — zawsze człowiek

KYC/payout, refund/spór, bezpieczeństwo, interpretacja prawa, zawieszenie sklepu, produkt regulowany, zmiana ceny/stanów bez potwierdzenia, komunikacja do klientów i każda nieodwracalna akcja.

Mierzyć `acceptance_rate` draftów, poprawki, błędne sugestie, ponowne otwarcia i minuty zaoszczędzone netto. Sama liczba odpowiedzi AI nie jest sukcesem.

## Badanie time-motion dla pilotów

### Próba

- minimum 20 sklepów: 10 self-service, 5 assisted, 5 done-for-you;
- osobno nowi sprzedawcy i migrujący;
- co najmniej dwa segmenty produktowe;
- okres: rejestracja → 30 dni po live, a następnie miesiące 2–3.

### Zbieranie

1. Timer uruchamiany przy aktywnej pracy; oczekiwanie ma osobny status.
2. Każda sesja pracy ma kategorię i rezultat.
3. Po zamknięciu pracownik zaznacza root cause oraz możliwość automatyzacji.
4. Raz dziennie kontrola brakujących wpisów; raz tygodniowo obserwacja 3 nagrań/sesji za zgodą.
5. Do klienta jedno krótkie pytanie o wysiłek po kluczowym zadaniu, nie po każdym kliknięciu.

### Raport kohorty

- minuty onboarding/first-sale/steady-state;
- koszt per etap i plan;
- P50/P75/P90;
- touches i reopen rate;
- top 10 root causes;
- udział pracy: naprawa produktu / edukacja / done-for-you / provider;
- minuty AI brutto i netto;
- marża po supporcie.

## Triggery automatyzacji

Automatyzować zadanie, gdy łącznie:

- wystąpiło ≥20 razy w 30 dni lub zużyło ≥5 h;
- kroki są stabilne i opisane;
- ryzyko jest niskie, akcja odwracalna;
- znany jest poprawny wynik i wyjątki;
- rozwiązanie produktu nie może po prostu usunąć potrzeby;
- oczekiwany zwrot kosztu budowy ≤6 miesięcy.

Najpierw automatyzować: klasyfikację, zbieranie kontekstu, readiness diagnosis, draft odpowiedzi i aktualizację CRM. Później działania w sklepie.

## Triggery zatrudnienia

Zatrudnienie/kontrakt supportowy jest uzasadnione, gdy przez 4 kolejne tygodnie występuje co najmniej jeden warunek:

- prognozowana praca supportowa >60% produktywnej pojemności jednej osoby;
- właściciel spędza >15 h tygodniowo na powtarzalnym supporcie;
- P1/P2 przekracza ustalone SLA z powodu kolejki, nie braku rozwiązania;
- backlog >1 tygodnia pracy lub >20 spraw wymagających człowieka;
- utracona marża/churn przypisany opóźnieniu przekracza koszt dodatkowej pojemności.

Pierwszą rolą powinien być produktowy customer success/generalist, który potrafi diagnozować i ulepszać proces, nie tylko zamykać tickety. Specjalistę płatności/ryzyka zatrudniać dopiero przy trwałym wolumenie; wcześniej eskalacja do dostawcy i konsultanta.

## Eksperymenty 14/30/90 dni

### 14 dni

- wdrożyć taksonomię, timer aktywnego czasu i root cause;
- zmierzyć cały własny czas przy 5 wdrożeniach;
- rozdzielić CAC/sales, onboarding, support i done-for-you;
- ustalić koszt minuty w trzech scenariuszach;
- nie automatyzować jeszcze działań mutujących dane.

**Kryterium:** ≥90% sesji pracy ma sklep, kategorię, aktywne minuty i rezultat; znamy P50 oraz top 5 przyczyn.

### 30 dni

- objąć minimum 20 pilotów;
- włączyć copilot dla podsumowań/draftów na losowej połowie spraw;
- porównać minuty, reopen rate i jakość;
- opisać zakres supportu dla planów i osobny cennik done-for-you;
- usunąć trzy najczęstsze przyczyny przez produkt/dokumentację.

**Kryterium:** copilot oszczędza ≥20% aktywnych minut bez wzrostu reopen/błędów; praca startowa mieści się w cenie wdrożenia w scenariuszu bazowym.

### 90 dni

- raport 20+ sklepów przez pełne 90 dni;
- kohorty według planu, segmentu i kanału;
- automatyzować maksymalnie trzy stabilne procesy;
- ustalić capacity plan na 100/500/1000 sklepów;
- podjąć decyzję o pierwszej roli operacyjnej według triggerów.

**Kryterium:** support ratio ≤30%, self-service P50 ≤20 min/mies., ≥70% spraw rozwiązanych w jednym kontakcie, automatyzacja nie zwiększa incydentów. Jeśli progi nie są spełnione, zmieniamy zakres/cenę/produkt przed skalowaniem sprzedaży.

## Źródła

1. [GUS — wynagrodzenie w sektorze przedsiębiorstw, maj 2026](https://stat.gov.pl/files/gfx/portalinformacyjny/pl/defaultaktualnosci/5474/3/173/1/przecietne_zatrudnienie_i_wynagrodzenie_w_sektorze_przedsiebiorstw_w_maju_2026_r.pdf)
2. [Rozporządzenie o minimalnym wynagrodzeniu w 2026 r.](https://api.sejm.gov.pl/eli/acts/DU/2025/1242/text.pdf)
3. [Stripe Connect — hosted/embedded onboarding](https://docs.stripe.com/connect/migrate-from-api-onboarding)
4. [Shopify — troubleshooting payment gateways](https://help.shopify.com/en/manual/payments/troubleshooting)
5. [Shopify — domain troubleshooting](https://help.shopify.com/en/manual/domains/troubleshoot-issues-with-domains?locale=en-US)

## Co obniża pewność

- brak time-motion Sklepika;
- szerokie dane płacowe nie odpowiadają dokładnemu profilowi roli;
- koszt zależy od umowy, narzędzi, języka, SLA i segmentu;
- pierwsze sklepy mogą generować nienaturalnie dużo pracy z powodu niedojrzałości produktu;
- wartości 20/30/60/70% są progami operacyjnymi do kalibracji, nie benchmarkami branżowymi.
