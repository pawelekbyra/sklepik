# Radar rynku Sklepika: system ciągłego badania

**Data badania:** 2026-07-14  
**Zakres:** produkt, konkurencja, popyt, klienci, dystrybucja, technologia i regulacje PL/UE  
**Typ dokumentu:** projekt procesu badawczego i systemu danych  
**Poziom pewności:** wysoki dla architektury procesu i oficjalnych źródeł; średni dla progów alertów; niski dla wartości predykcyjnej przed 90 dniami kalibracji

## Werdykt

Sklepik powinien od razu zbudować mały **system pamięci decyzyjnej**, nie wielką hurtownię internetu. Radar ma stale odpowiadać:

1. co faktycznie zmieniło się na rynku;
2. jaki dowód to potwierdza;
3. których klientów i założeń Sklepika dotyczy;
4. czy wymaga alertu, eksperymentu, decyzji czy tylko archiwizacji;
5. po czasie — czy rekomendacja była trafna.

Najważniejszym źródłem nie będą newsy ani social media, lecz **własne zachowania sklepów i rozmowy z klientami**. Zewnętrzny monitoring służy do wyjaśniania zmian i wykrywania szans. Agent może pobierać, deduplikować, streszczać i proponować hipotezy; człowiek zatwierdza wnioski, priorytety oraz działania wobec klientów.

MVP radaru da się uruchomić w 14 dni: repozytorium raportów, rejestr źródeł, wspólny schemat sygnału, dzienny digest i cotygodniowy przegląd. Zaawansowane crawlery i predykcja powinny powstać dopiero wtedy, gdy wiadomo, które sygnały prowadzą do decyzji.

## Metoda

Przegląd obejmuje dostępne w lipcu 2026 oficjalne źródła i interfejsy:

- Google Trends API alpha i Google Shopping Trends;
- Eurostat API/RSS;
- EUR-Lex RSS i konsultacje Komisji Europejskiej;
- DSA Transparency Database Research API;
- Safety Gate;
- GitHub releases/webhooks;
- własne zdarzenia produktu, CRM, support i badania jakościowe;
- aktualne zasady RODO oraz wytyczne EDPB dotyczące web scrapingu.

Projekt celowo oddziela **obserwację** od **wniosku**. Częstym błędem radarów jest generowanie dużej liczby eleganckich streszczeń bez wpływu na decyzje.

## Fakty istotne dla projektu

- Google Trends API jest w wersji alpha i wymaga przyjęcia do programu. Oferuje pięcioletnie okno, stałą skalę oraz agregacje dzienne, tygodniowe, miesięczne i roczne. Nie wolno projektować krytycznego procesu tak, jakby był już powszechnie dostępny. [Google Trends API Alpha](https://developers.google.com/search/apis/trends)
- Oficjalny przewodnik Google wyjaśnia, że Trends opiera się na próbce zagregowanych, anonimizowanych i kategoryzowanych wyszukiwań. Dane są wskaźnikiem zainteresowania, nie liczbą klientów ani prognozą przychodu. [Google — Get started with Trends](https://developers.google.com/search/docs/monitor-debug/trends-start)
- Merchant API/Shopping Trends pozwala badać popularność tematów produktowych oraz prognozę do 13 tygodni, ale dostęp zależy m.in. od posiadania produktów w kategorii. Jest to źródło dla działających sklepów, nie pełny radar rynku. [Google — Shopping trends](https://developers.google.com/shopping-content/guides/reports/shopping-trends)
- EUR-Lex pozwala tworzyć własne RSS-y z zapisanych wyszukiwań dotyczących prawa, projektów i orzecznictwa. [EUR-Lex — RSS alerts](https://eur-lex.europa.eu/content/help/my-eurlex/my-rss-feeds.html?locale=en)
- Eurostat udostępnia RSS o aktualizacjach danych oraz programowy dostęp do statystyk. [Eurostat — Catalogue API/RSS](https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/api-detailed-guidelines/catalogue-api/rss)
- DSA Transparency Database ma Research API z wyszukiwaniem, agregacjami i metadanymi platform, lecz dotyczy głównie uzasadnień decyzji moderacyjnych. Jest źródłem wyspecjalizowanym, nie codziennym wskaźnikiem konkurencji e-commerce. [Komisja Europejska — DSA Research API](https://transparency.dsa.ec.europa.eu/page/research-api?lang=pl)
- EDPB w lipcu 2026 podkreśliła, że scraping obejmujący dane osobowe podlega RODO, a szczególnie ważne są ograniczenie celu, przejrzystość, minimalizacja, wiarygodność źródła, timestamp i walidacja danych. [EDPB, 08.07.2026](https://www.edpb.europa.eu/news/edpb-sheds-light-on-anonymisation-and-web-scraping-for-generative-ai-and-adopts-final-version_en)

## Wniosek architektoniczny

Źródło powinno być dodane do radaru dopiero wtedy, gdy ma:

- właściciela;
- pytanie decyzyjne, na które odpowiada;
- dozwoloną metodę pobierania;
- częstotliwość sensowną dla tempa zmian;
- sposób wykrycia awarii lub zmiany formatu;
- retencję i klasyfikację danych;
- koszt pozyskania i analizy.

„Możemy to scrapować” nie jest uzasadnieniem biznesowym.

## Pytania badawcze radaru

### Popyt

- Które typy sprzedawców najczęściej dochodzą do pierwszej sprzedaży?
- Jak zmienia się zainteresowanie „sklep internetowy”, sprzedażą przez Instagram/marketplace i niszami produktowymi?
- Jakie wydarzenia sezonowe poprzedzają tworzenie sklepów i zakupy?

### Konkurencja

- Kto zmienił cenę, onboarding, AI, ograniczenia, integracje lub pozycjonowanie?
- Jaką obietnicę pokazuje nowym sprzedawcom i co jest dostępne w realnym produkcie?
- Jakie powtarzalne skargi użytkowników pozostają nierozwiązane?

### Produkt

- Gdzie użytkownicy Sklepika porzucają flow?
- Które interwencje człowieka prowadzą do startu, a które tylko maskują problem?
- Które funkcje korelują z pierwszą sprzedażą i retencją, a nie jedynie użyciem?

### Dystrybucja

- Który kanał prowadzi do aktywnego, płacącego sklepu po 30/90 dniach?
- Jakie komunikaty, nisze i partnerzy dostarczają kwalifikowanych klientów?
- Czy CAC i czas człowieka zwracają się w marży?

### Prawo i ryzyko

- Która zmiana może wpłynąć na checkout, produkt, komunikację, prywatność, dostępność lub odpowiedzialność platformy?
- Czy zmieniły się wytyczne regulatorów, terminy lub wymagania dostawców płatności?
- Czy produkty sprzedawców pojawiły się w Safety Gate albo innej bazie ostrzeżeń?

## Hierarchia źródeł

| Poziom | Źródła | Zastosowanie | Częstotliwość |
|---|---|---|---|
| 0 — własna prawda | eventy produktu, płatności, zamówienia, CRM, support, uptime | aktywacja, pierwsza sprzedaż, retencja, problemy | near-real-time/dziennie |
| 1 — głos klienta | rozmowy, testy użyteczności, powody rezygnacji, ankiety po zdarzeniu | potrzeby, język, drop-off | po zdarzeniu/tygodniowo |
| 2 — pierwotne zewnętrzne | cenniki i changelogi konkurentów, regulatorzy, akty prawne, oficjalne statystyki/API | fakty o rynku i obowiązkach | dziennie–miesięcznie |
| 3 — obserwacyjne | publiczne fora, recenzje, social, ogłoszenia | hipotezy i słabe sygnały | tygodniowo |
| 4 — wtórne | media, newslettery, raporty konsultingowe | odkrywanie tematów | tygodniowo/miesięcznie |

Wniosku nie należy oznaczać jako „potwierdzony”, jeśli opiera się wyłącznie na poziomie 3–4. Co najmniej jedno źródło pierwotne albo własny pomiar powinno poprzeć decyzję inwestycyjną.

## Rejestr źródeł MVP

### Własne

- eventy onboardingu od `store_created` do `first_order_fulfilled`;
- kohorty kanał/segment/plan;
- porzucone etapy i jawne powody rezygnacji;
- zapytania supportu, czas rozwiązania, interwencje ręczne;
- refundy, spory, błędy checkoutu;
- wywiady, utracone oferty i powody wygranej;
- koszty infrastruktury, AI i pracy na sklep.

### Rynek i popyt

- Google Trends UI, a po uzyskaniu dostępu — oficjalne API alpha;
- Google Shopping Trends dla działających kategorii;
- Eurostat: e-commerce, wykorzystanie AI, struktura MŚP, zakupy online;
- własne Search Console i Merchant Center — pokazują popyt osiągalny przez Sklepik, nie cały rynek;
- Google Ads Keyword Planner jako źródło płatnej intencji po ręcznej ocenie ograniczeń danych.

### Konkurencja

- oficjalne strony cenowe, changelogi, dokumentacja i status pages z timestampem;
- release'y publicznych repozytoriów przez [GitHub Releases API](https://docs.github.com/en/rest/releases);
- okresowy ręczny mystery shopping: rejestracja, screeny, realny zakres produktu;
- wybrane publiczne recenzje jako materiał jakościowy, po warunkach platformy i bez masowego kopiowania danych osób;
- repozytoria reklam dostępne prawnie w danym kraju — jako sygnał komunikatu i czasu emisji, nie wiarygodna miara wyniku kampanii.

### Regulacje i bezpieczeństwo

- EUR-Lex zapisane wyszukiwania/RSS: e-commerce, consumer rights, AI, DSA, DMA, Data Act, accessibility, payments, VAT, product safety;
- [Have Your Say](https://have-your-say.ec.europa.eu/index_en) dla inicjatyw przed wejściem w życie;
- UODO, UOKiK, UKE, KNF i polski Dziennik Ustaw — oficjalne komunikaty/RSS, jeśli dostępne;
- [Safety Gate](https://ec.europa.eu/safety-gate/) dla niebezpiecznych produktów nieżywnościowych;
- wytyczne dostawców Stripe/Vercel/Google oraz ich changelogi i status pages;
- DSA Research API tylko dla konkretnych pytań o moderację/scam/fraud.

## Schemat danych

Najmniejszą jednostką jest **sygnał**, nie raport.

```yaml
signal_id: sig_...
observed_at: 2026-07-14T08:00:00Z
source_id: eurlex_consumer_rights
source_type: regulator_primary
source_url: https://...
retrieval_method: rss|api|manual|webhook|product_event
scope: PL|EU|global|internal
topic: demand|competitor|customer|distribution|product|regulation|risk
entity: competitor_or_segment_or_feature
event_type: price_change|launch|complaint_pattern|law_change|metric_shift
statement: "Co zaobserwowano — bez interpretacji"
evidence_snapshot_ref: object-storage://...
content_hash: sha256:...
personal_data: none|business_contact|customer_pseudonymous
confidence: high|medium|low
materiality: 1..5
novelty: 1..5
urgency: 1..5
status: new|triaged|finding|archived|rejected
owner: role_or_person
related_hypothesis_ids: []
```

Z sygnałów powstaje **finding**:

```yaml
finding_id: find_...
title: "Zwięzły wniosek"
facts: []
inference: "Interpretacja jawnie oddzielona od faktów"
alternative_explanations: []
supporting_signal_ids: []
contradicting_signal_ids: []
affected_segments: []
expected_impact: revenue|retention|risk|cost|strategy
recommended_action: monitor|interview|experiment|ship|stop|legal_review
decision_deadline: 2026-07-21
confidence: high|medium|low
reviewer: human
```

Każda decyzja zapisuje także wynik po 30/90 dniach. Bez tego radar nie uczy się, które źródła i analizy są użyteczne.

## Gdzie przechowywać dane

```text
sklepik/docs/research/
├── README.md                    # indeks, metodologia, status aktualności
├── radar-rynku/
│   ├── 2026-07-14-system-ciaglego-badania.md
│   ├── weekly/                  # zatwierdzone raporty tygodniowe
│   ├── monthly/                 # syntezy i decyzje
│   └── source-registry.md       # źródła bez sekretów
└── ...                          # raporty tematyczne

operacyjna baza danych / hurtownia
├── signals                     # rekordy i metadane
├── findings
├── experiments
├── decisions
└── outcomes

object storage
└── dozwolone snapshoty/dowody z retencją i ACL
```

Repozytorium przechowuje tylko zatwierdzone dokumenty, metodę i decyzje. Nie należy commitować surowych danych osobowych, pełnych kopii cudzych serwisów, tokenów API ani dużych datasetów.

## Harmonogram pracy

### Codziennie — automatycznie

- ingest zdarzeń własnego produktu i alarmów operacyjnych;
- pobranie dozwolonych RSS/API/changelogów;
- wykrycie zmiany treści w jawnie wybranych stronach cenowych;
- deduplikacja po URL/hash/entity/event;
- agent klasyfikuje fakt, możliwy wpływ i wiarygodność;
- krytyczne alerty trafiają do człowieka, reszta do kolejki tygodniowej;
- kontrola zdrowia źródeł: ostatni sukces, błędy, opóźnienie, zmiana schematu.

### Codziennie — 10 minut człowieka

- zatwierdzenie/odrzucenie alertów P1;
- oznaczenie fałszywych trafień;
- przypisanie właściciela tylko zdarzeniom wymagającym działania.

### Tygodniowo — 60–90 minut

Raport maksymalnie dwóch stron:

1. 3–5 zmian, które mają dowody;
2. własny lejek i anomalie kohort;
3. nowe głosy klientów i powtarzające się problemy;
4. ruchy konkurencji;
5. regulacje/ryzyko;
6. wyniki eksperymentów;
7. maksymalnie trzy rekomendowane działania;
8. lista „obserwuj, nie działaj”.

Spotkanie kończy się decyzjami z właścicielem i terminem. Brak decyzji też jest zapisywany.

### Miesięcznie — 2–3 godziny

- porównanie segmentów, kanałów, retencji i ekonomiki;
- aktualizacja mapy konkurencji i pricingu;
- ocena, które źródła były użyteczne;
- usunięcie źródeł produkujących szum;
- jedna rewizja tezy: „co obecnie przynosi pieniądze i dlaczego?”;
- wybór 1–3 eksperymentów na kolejny miesiąc.

### Kwartalnie

- przegląd strategii i roadmapy;
- audyt zgodności źródeł, retencji i dostępu;
- kalibracja progów alertów;
- retrospektywa rekomendacji: trafne, błędne, nieweryfikowalne;
- decyzja o wejściu/wyjściu z segmentu lub kraju na podstawie kohort, nie pojedynczych sygnałów.

## Alerty

### P1 — natychmiast, z obowiązkowym człowiekiem

- regulator/dostawca ogłasza zmianę z terminem <30 dni wpływającą na checkout, dane, płatności lub legalność produktu;
- wzrost błędów płatności/checkoutu >2× względem 28-dniowej mediany i minimum 10 zdarzeń;
- podejrzenie wycieku, oszustwa, masowego refundu lub niebezpiecznego produktu;
- krytyczna zależność ogłasza incydent lub breaking change.

### P2 — dzienny digest

- konkurent zmienia cenę/pakiet albo uruchamia porównywalną funkcję;
- własna konwersja etapowa spada o >25% tydzień do tygodnia przy minimum 30 przypadkach;
- ten sam problem występuje w ≥5 rozmowach/ticketach w 30 dni;
- koszt kanału rośnie >30% bez wzrostu jakości.

### P3 — raport tygodniowy/miesięczny

- wzrost trendu wyszukiwania bez potwierdzenia sprzedażą;
- pojedyncza recenzja, post, premiera lub raport medialny;
- nowa funkcja konkurenta bez dowodu adopcji;
- słaby sygnał z rynku sąsiedniego.

Progi należy po 90 dniach kalibrować do sezonowości i wolumenu. Przy małej próbie lepszy jest alert opisowy niż pozornie statystyczny z-score.

## Metryki jakości radaru

### Operacyjne

- % źródeł pobranych zgodnie z harmonogramem;
- opóźnienie od publikacji do sygnału;
- duplikaty na 100 sygnałów;
- koszt ingestu i analizy;
- czas człowieka na tygodniowy przegląd.

### Jakościowe

- precision alertów: ile alertów uznano za rzeczywiście istotne;
- odsetek findingów z co najmniej jednym pierwotnym dowodem;
- odsetek findingów z jawnie opisaną alternatywną interpretacją;
- odsetek rekomendacji zaakceptowanych, odrzuconych i nieweryfikowalnych;
- liczba decyzji/eksperymentów wynikających z radaru;
- trafność po 30/90 dniach.

### Biznesowe

- wzrost `first_fulfilled_sale_30d` w eksperymentach z radaru;
- przychód/marża przypisana do wykrytej szansy;
- uniknięty koszt lub incydent;
- skrócenie czasu reakcji na zmianę;
- liczba zabitych wcześniej nietrafionych pomysłów — to także wartość.

Cel po 90 dniach: co najmniej 60% alertów P1/P2 uznanych przez człowieka za istotne, ≥90% findingów z pierwotnym źródłem oraz minimum dwie mierzalne decyzje miesięcznie. Jeśli raport rośnie, lecz decyzje nie, system należy zmniejszyć.

## Granice prawne i etyczne

1. **Publiczne nie znaczy dowolne.** Przed pobieraniem sprawdzamy regulamin, robots, licencję, zakres API i prawo baz danych.
2. **API/RSS przed crawlerem.** Nie obchodzimy logowania, CAPTCHA, rate limitów ani zabezpieczeń.
3. **Minimalizacja.** Do badania konkurencji zwykle potrzebna jest firma, oferta i zmiana — nie imię autora recenzji, jego profil czy dane kontaktowe.
4. **Oddzielenie baz.** Dane radaru nie trafiają automatycznie do CRM/prospectingu ani treningu modeli.
5. **Retencja.** Surowe dane osobowe usuwać lub anonimizować szybko; przechowywać agregat i źródło, jeśli wystarcza.
6. **Prawo do sprzeciwu i transparentność.** Dla przetwarzania danych osób należy określić podstawę, obowiązek informacyjny lub udokumentowany wyjątek oraz proces żądań.
7. **Brak autonomicznego działania o wysokim wpływie.** Agent nie publikuje oskarżeń, nie kontaktuje osoby, nie zmienia cennika, nie blokuje sklepu i nie interpretuje prawa bez zatwierdzenia.
8. **Copyright i tajemnice.** Przechowujemy krótką obserwację, metadane i dozwolony snapshot; nie kopiujemy całych raportów, baz lub płatnych treści.
9. **Bez danych wrażliwych.** Radar nie profiluje właścicieli po zdrowiu, poglądach, pochodzeniu czy innych cechach szczególnych.
10. **Audytowalność AI.** Każde streszczenie wskazuje źródło, timestamp i wersję promptu/modelu; fakt nie może istnieć wyłącznie w odpowiedzi modelu.

Wytyczne EDPB 03/2026 dotyczą bezpośrednio web scrapingu w kontekście generatywnej AI i są w konsultacji, więc nie stanowią kompletnej instrukcji dla radaru. Potwierdzają jednak właściwy kierunek zabezpieczeń: cel, minimalizacja, wiarygodne źródła, czas pozyskania i walidacja. Niezależnie należy wykonać DPIA, jeśli skala/profil ryzyka tego wymaga, oraz przegląd prawny przed uruchomieniem masowego crawlningu.

## Agentowy workflow z kontrolą jakości

```text
collector
→ walidacja schematu i licencji
→ deduplikacja
→ agent ekstrakcji: wyłącznie fakt + fragment dowodu
→ agent analizy: hipoteza, alternatywy, wpływ
→ reguły alertów
→ reviewer człowiek
→ finding / eksperyment / archiwum
→ decyzja
→ outcome po 30/90 dniach
→ ocena źródła i rekomendacji
```

Modele nie powinny oceniać własnej pewności bez oparcia w klasie źródła i liczbie niezależnych dowodów. Proponowana reguła:

- `high`: źródło pierwotne + własny pomiar albo dwa niezależne źródła pierwotne;
- `medium`: jedno źródło pierwotne lub powtarzalny wzorzec jakościowy;
- `low`: źródło wtórne, pojedyncza obserwacja, trend bez przełożenia na zachowanie.

## Eksperymenty

### 14 dni

1. Utworzyć indeks `docs/research/README.md`, rejestr 20 źródeł i template weekly report.
2. Wdrożyć wspólny słownik eventów onboardingu oraz ręczny eksport kohort.
3. Podłączyć maksymalnie 10 źródeł: własne eventy, support/CRM, 3 konkurentów, EUR-Lex, Eurostat, Google Trends manual i 1 regulator PL.
4. Przez dwa tygodnie generować dzienny digest, lecz publikować tylko po review.
5. Zmierzyć czas, liczbę duplikatów i liczbę sygnałów prowadzących do rozmowy/eksperymentu.

**Kryterium:** kompletne provenance dla 100% findingów, przegląd dzienny <15 min, tygodniowy <90 min, co najmniej 2 sensowne hipotezy i zero niezatwierdzonych działań zewnętrznych.

### 30 dni

1. Dodać trwały store sygnałów/findings/decisions i outcome review.
2. Automatyzować oficjalne RSS/API oraz health-check każdego źródła.
3. Monitorować 5 konkurentów: pricing, changelog, onboarding snapshot raz w miesiącu.
4. Uruchomić trzy alerty własnego lejka i jeden regulacyjny.
5. Przeprowadzić pierwszą retrospektywę false positives/false negatives.

**Kryterium:** ≥80% ingestów na czas, duplikaty <10%, ≥80% findingów z pierwotnym źródłem, minimum 3 eksperymenty/decyzje powiązane z radarem. Brak działań oznacza redukcję źródeł.

### 90 dni

1. Skorelować sygnały i rekomendacje z wynikiem `first_fulfilled_sale_30d`, retencją i marżą.
2. Dodać Google Trends API tylko po oficjalnym dostępie; nie używać nieautoryzowanych obejść.
3. Zbudować porównanie kohort segment/kanał i osobny risk radar.
4. Wykonać audyt prawny danych, retencji, licencji, dostępów i procesorów.
5. Usunąć dolne 30% źródeł według użyteczności; zainwestować tylko w źródła, które przewidziały działanie.

**Kryterium:** precision P1/P2 ≥60%, ≥90% findingów z dowodem pierwotnym, dwie mierzalne decyzje miesięcznie, co najmniej jeden eksperyment z dodatnim wynikiem biznesowym albo udokumentowaną oszczędnością. Jeśli system nie osiąga tych progów, wraca do rytuału manualnego zamiast rosnąć technologicznie.

## Kryteria decyzji o rozbudowie

- **Nowe źródło:** dodajemy tylko, gdy odpowiada na nazwane pytanie i ma właściciela.
- **Nowy crawler:** dopiero gdy brak API/RSS i przegląd prawny/ToS go dopuszcza.
- **Nowy model AI:** tylko gdy poprawia mierzoną precision/recall albo skraca review bez utraty provenance.
- **Alert automatyczny:** dopiero po minimum 20 ręcznie sklasyfikowanych przypadkach.
- **Raport cykliczny:** zamykamy, jeśli przez trzy edycje nie wywołał decyzji ani aktualizacji hipotezy.
- **Dane osobowe:** nie zbieramy, jeśli agregat, pseudonim lub dane podmiotu wystarczą.

## Rekomendowana pierwsza wersja

Pierwszy radar nie wymaga osobnej aplikacji. Wystarczą:

- eventy produktu w istniejącym systemie analitycznym;
- prosta baza `signals/findings/decisions/outcomes`;
- scheduler dla oficjalnych źródeł;
- object storage na dozwolone dowody;
- generowanie draftu tygodniowego do repo;
- ręczne zatwierdzenie pull requestu;
- miesięczny przegląd przy roadmapie.

Największą przewagą nie będzie liczba zebranych rekordów, lecz to, że Sklepik będzie pamiętał **dlaczego podjął decyzję i czy miała sens**.

## Źródła pierwotne

1. [Google Trends API Alpha](https://developers.google.com/search/apis/trends)
2. [Google — Get started with Google Trends](https://developers.google.com/search/docs/monitor-debug/trends-start)
3. [Google — Shopping trends reports](https://developers.google.com/shopping-content/guides/reports/shopping-trends)
4. [Eurostat — Catalogue API/RSS](https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/api-detailed-guidelines/catalogue-api/rss)
5. [EUR-Lex — RSS alerts](https://eur-lex.europa.eu/content/help/my-eurlex/my-rss-feeds.html?locale=en)
6. [European Commission — Have Your Say](https://have-your-say.ec.europa.eu/index_en)
7. [European Commission — DSA Transparency Database Research API](https://transparency.dsa.ec.europa.eu/page/research-api?lang=pl)
8. [European Commission — Safety Gate](https://ec.europa.eu/safety-gate/)
9. [GitHub — Releases API](https://docs.github.com/en/rest/releases)
10. [RODO — art. 5–6](https://eur-lex.europa.eu/legal-content/PL/TXT/?uri=CELEX%3A32016R0679)
11. [EDPB — web scraping and anonymisation, 08.07.2026](https://www.edpb.europa.eu/news/edpb-sheds-light-on-anonymisation-and-web-scraping-for-generative-ai-and-adopts-final-version_en)

## Co obniża pewność

- brak 90-dniowej kalibracji na danych Sklepika;
- Google Trends API jest nadal alpha;
- dostępność i zakres API/platform mogą się zmienić;
- nie wszystkie urzędy i konkurenci mają stabilne RSS/changelogi;
- progi alertów są startowymi heurystykami;
- radar może wykrywać korelację, ale eksperyment lub triangulacja jest potrzebna do wniosku przyczynowego.

