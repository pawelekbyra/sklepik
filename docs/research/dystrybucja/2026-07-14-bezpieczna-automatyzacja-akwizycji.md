# Bezpieczna automatyzacja akwizycji Sklepika

**Data:** 2026-07-14  
**Zakres:** Polska jako rynek startowy, z możliwością rozszerzenia na UE po analizie lokalnej  
**Typ:** proces operacyjny i granice automatyzacji; nie jest opinią prawną  
**Poziom pewności:** wysoki dla konserwatywnych ograniczeń i kontroli; średni dla workflow; niski dla konwersji przed pilotażem  
**Działania zewnętrzne wykonane w ramach badania:** zero

## Werdykt

Sklepik może zautomatyzować większość pracy **wokół** sprzedaży, lecz nie powinien automatyzować niezamówionego kontaktu. Bezpieczna fabryka działa w tej kolejności:

```text
badanie segmentu bez tworzenia listy mailingowej
→ legalne powierzchnie opt-in / partner / polecenie
→ dowód zgody i oczekiwanego celu kontaktu
→ minimalne wzbogacenie danych
→ agent przygotowuje audyt, prototyp i draft
→ człowiek zatwierdza fakty, odbiorcę, obietnicę i wysyłkę
→ kontrolowana sekwencja z wypisem
→ onboarding albo zamknięcie i retencja/suppression
```

Największa przewaga AI nie polega tu na wysłaniu miliona wiadomości. Polega na tym, że mała liczba osób, które **poprosiły o kontakt**, może w ciągu godzin dostać bardzo trafny audyt i prototyp. To zwiększa jakość, chroni domenę i tworzy proces możliwy do audytu.

## Metoda i aktualne fakty

### Polska

Art. 398 Prawa komunikacji elektronicznej wymaga uprzedniej zgody abonenta lub użytkownika końcowego na używanie automatycznych systemów wywołujących lub telekomunikacyjnych urządzeń końcowych do przesyłania informacji handlowej, w tym marketingu bezpośredniego. Przepis nie daje prostej generalnej furtki „to adres firmowy/B2B”. [Prawo komunikacji elektronicznej, Dz.U. 2024 poz. 1221](https://isap.sejm.gov.pl/isap.nsf/download.xsp/WDU20240001221/O/D20241221.pdf)

RODO jest odrębną warstwą. Uzasadniony interes z art. 6 ust. 1 lit. f może mieć znaczenie dla określonego przetwarzania, ale nie znosi wymagań konkretnego kanału komunikacji. Obowiązują minimalizacja, ograniczenie celu, przejrzystość, retencja, bezpieczeństwo i prawo sprzeciwu. [RODO, art. 5–6 i 21](https://eur-lex.europa.eu/legal-content/PL/TXT/?uri=CELEX%3A32016R0679)

EDPB opisuje trzyczęściowy test uzasadnionego interesu: istnienie prawnie uzasadnionego celu, konieczność oraz wyważenie wobec praw osoby. Sam interes komercyjny nie kończy analizy. [EDPB — case digest on legitimate interest, 26.03.2026](https://www.edpb.europa.eu/documents/support-pool-of-experts/one-stop-shop-case-digest-on-the-legal-basis-of-legitimate_en)

### UE

Oficjalny portal UE wskazuje jako zasadę konieczność wyraźnej zgody na marketingowy e-mail, poza istniejącą relacją handlową. Szczegóły i wyjątki zależą od kraju; nie wolno kopiować polskiej procedury na całą UE bez analizy lokalnej. [Your Europe, aktualizacja 29.04.2026](https://europa.eu/youreurope/business/running-business/digitalising/promoting-business-online/index_en.htm)

### Scraping i dostarczalność

EDPB w wytycznych z lipca 2026 podkreśla, że scraping obejmujący dane osobowe podlega RODO i wymaga szczególnej uwagi wobec celu, przejrzystości, minimalizacji, dokładności, wiarygodności źródła i timestampu. Wytyczne dotyczą generatywnej AI, ale zasady ochrony danych są istotne również dla agentowego researchu. [EDPB, 08.07.2026](https://www.edpb.europa.eu/news/edpb-sheds-light-on-anonymisation-and-web-scraping-for-generative-ai-and-adopts-final-version_en)

Gmail wymaga od nadawców masowych m.in. SPF, DKIM, DMARC, TLS i one-click unsubscribe, zaleca spam rate <0,1%, a 0,3% lub więcej wiąże z negatywnymi konsekwencjami. Spełnienie wymagań technicznych nie legalizuje kontaktu — chroni tylko dostarczalność. [Google — Email sender guidelines FAQ](https://support.google.com/mail/answer/14229414?hl=en)

### Wnioski, nie fakty

- Audyt na żądanie i partnerstwa powinny dać lepszą jakość niż masowy outbound — wymaga to własnego eksperymentu.
- Human approval 100% wiadomości jest startowym guardrailem, nie wymogiem ustawowym w każdym przypadku.
- Zakładamy, że przewaga Sklepika polega na szybkim, spersonalizowanym prototypie; gotowość do zapłaty nie została jeszcze potwierdzona.
- Progi complaint, konwersji i liczebności są zasadami operacyjnymi, a nie gwarancją zgodności prawnej.

## Założenie konserwatywne

Do czasu pisemnej opinii polskiego prawnika dotyczącej konkretnych tekstów i kanałów:

- nie wysyłamy cold e-maili, cold DM-ów ani automatycznych wiadomości „czy mogę przesłać ofertę?”;
- nie dzwonimy marketingowo na publiczne numery bez wymaganej zgody;
- nie traktujemy wizytówki, stopki strony, CEIDG/KRS ani profilu social jako zgody;
- nie kupujemy baz;
- nie używamy danych z researchu rynkowego jako listy odbiorców;
- istniejącej relacji z klientem nie traktujemy automatycznie jako zgody na każdy kanał i każdą usługę.

Reguła jest bardziej ostrożna niż część praktyk rynkowych, ale minimalizuje ryzyko prawne, spam complaints i utratę zaufania.

## Cztery oddzielne zbiory

### 1. `market_entities`

Firmy/marki jako obiekty badania segmentu: domena, branża, kanał sprzedaży, publicznie widoczne cechy oferty. Bez danych osoby, jeśli nie są niezbędne. Zbiór służy do statystyki i wyboru kanału, **nie do wysyłki**.

### 2. `leads_opted_in`

Osoby, które same wysłały formularz, umówiły rozmowę lub zostały przekazane przez partnera w procesie zawierającym świadomą zgodę. Zawiera dowód i zakres zgody.

### 3. `customers`

Relacja umowna i dane potrzebne do świadczenia usługi. Cele operacyjne i marketingowe pozostają rozdzielone.

### 4. `suppression`

Minimalny identyfikator niezbędny, aby nigdy ponownie nie kontaktować osoby, która odmówiła/sprzeciwiła się/wypisała. Suppression ma wyższy priorytet niż każda kampania i nie może zostać nadpisane importem.

Łączenie zbiorów wymaga jawnej reguły i logu. Agent badawczy nie ma automatycznego dostępu do systemu wysyłki.

## Bezpieczne źródła leadów

| Źródło | Warunek wejścia do `leads_opted_in` | Rekomendacja |
|---|---|---|
| formularz audytu/prototypu | osoba sama podaje kontakt i wybiera oczekiwany follow-up | priorytet 1 |
| formularz reklamy leadowej | jasna tożsamość, cel, zakres kontaktu i privacy notice | priorytet 1 |
| polecenie klienta | polecany sam otwiera link/formularz; nie wystarczy przekazanie cudzego maila | priorytet 1 |
| partner | partner ma zgodę na przekazanie lub klient sam umawia kontakt | priorytet 1 |
| webinar/warsztat | osobne pole dalszego kontaktu; udział nie jest automatyczną zgodą | priorytet 2 |
| lista oczekujących | zgodnie z celem listy; marketing dodatkowy osobno | priorytet 2 |
| odpowiedź na jawne zapytanie ofertowe | kontakt w granicach briefu i regulaminu platformy | ręczna ocena |
| publiczny katalog/social/marketplace | badanie segmentu, nie automatyczna wysyłka | nie zasila wysyłki |
| kupiona/scrapowana lista osób | brak wiarygodnej zgody i duże ryzyko | zakaz |

Meta oferuje formularze bezpośrednio w reklamie oraz formularze na własnej stronie; wyniki reklamowe deklarowane przez platformę należy zweryfikować własnym kosztem kwalifikowanego leada. [Meta for Business](https://www.facebook.com/business/ads/ad-objectives/lead-generation/lead-ads-with-forms)

## Audyt na żądanie

### Formularz

Minimalne pola:

- URL/profil marki wskazany przez właściciela;
- co sprzedaje i jaki ma cel;
- etap: sprzedaję / mam produkty / pomysł;
- e-mail;
- checkbox potwierdzający prośbę o przygotowanie audytu i kontakt w tej sprawie;
- link do informacji o prywatności;
- opcjonalna, oddzielna zgoda na dalsze materiały/marketing.

Checkbox nie może być wstępnie zaznaczony. Treść zapisujemy wraz z wersją, czasem, źródłem, IP ograniczonym do ochrony antyfraudowej i dowodem submit. Nie łączymy zgody na audyt z obowiązkowym newsletterem.

### Agent przygotowuje

- fakty: obecne kanały, widoczne produkty, brak lub obecność checkoutu, mobile, dane kontaktowe firmy;
- 3–5 problemów bez spekulacji o przychodach;
- prototyp/draft z wyraźnym oznaczeniem;
- zakres i założenia oferty;
- listę faktów wymagających potwierdzenia klienta;
- draft wiadomości odpowiadającej dokładnie na prośbę.

### Człowiek zatwierdza

- że osoba rzeczywiście poprosiła o audyt;
- że analizowana marka należy do niej albo ma prawo nią zarządzać;
- że fakty są poprawne i aktualne;
- że nie skopiowano chronionych treści ponad konieczność;
- że nie ma nieuprawnionych claims, presji ani fałszywej personalizacji;
- cenę, termin, zakres i wysyłkę.

Nie publikować audytu bez zgody. Nie używać w reklamie logo, danych ani prototypu firmy bez odrębnego pozwolenia.

## Program partnerstw

Rekomendowani partnerzy: fotografowie produktowi, graficy, księgowi, drukarnie/opakowania, inkubatory, organizatorzy targów, freelancerzy marketingowi i lokalne organizacje przedsiębiorców.

Proces:

1. partner dostaje landing/link z identyfikatorem, nie formularz do wpisywania cudzych danych;
2. potencjalny klient sam prosi o kontakt;
3. źródło partnera zapisuje się do atrybucji;
4. wynagrodzenie jest ujawnione zgodnie z umową i zasadami kanału;
5. partner nie dostaje dostępu do danych sklepu ani statusu beyond minimum bez podstawy;
6. fraud/self-referrals i podwójna atrybucja mają jawne reguły;
7. DPA lub role administratorów są określone, gdy partner przetwarza dane w imieniu Sklepika.

Nie nagradzać partnera za sam adres e-mail. Nagradzać za kwalifikowaną zgodę, płacący sklep lub first fulfilled sale, aby nie tworzyć bodźca do spamu.

## Rekord zgody i legal basis

```yaml
contact_id: pseudonymous_id
source: audit_form|partner_link|lead_ad|webinar
purpose: requested_store_audit
channel: email
consent_text_version: audit_v3_pl
privacy_notice_version: privacy_v2_pl
captured_at: 2026-07-14T12:00:00Z
captured_by: form_id
evidence_ref: immutable_log_ref
country_context: PL
expires_or_review_at: 2026-10-14
withdrawn_at: null
suppressed: false
```

Nie nazywać każdego przetwarzania „consent”. CRM powinien przechowywać ocenioną podstawę prawną per cel i kanał; zgoda marketingowa jest tylko jedną z możliwości. Ocena/LIA i treść obowiązku informacyjnego wymagają przeglądu DPO/prawnika.

## Personalizacja przez agentów

### Dozwolone dane

- informacje podane w formularzu;
- treść wskazanego przez osobę sklepu/profilu w zakresie potrzebnym do audytu;
- dane podmiotu, oferta, publiczne kanały sprzedaży;
- historia interakcji ze Sklepikiem;
- segment i jawne preferencje.

### Niedozwolone lub wymagające specjalnego review

- dane szczególne, sytuacja rodzinna, zdrowie, poglądy, pochodzenie;
- przewidywanie dochodu lub podatności na presję;
- dane członków rodziny/pracowników bez potrzeby;
- łączenie profili z wielu platform w celu ukrytego profilowania;
- wymyślone komplementy, wyniki, problemy lub twierdzenie, że człowiek osobiście analizował materiał, jeśli tego nie zrobił;
- kopiowanie cudzych zdjęć/tekstów do prototypu bez podstawy.

Każdy draft ma sekcję `facts_used` i linki do źródła. Model nie może sam dodać odbiorcy ani wykonać send.

## Macierz uprawnień automatyzacji

| Czynność | Automat | Wymaga człowieka | Zakaz bez nowej oceny |
|---|:---:|:---:|:---:|
| deduplikacja i suppression check | ✓ | | |
| klasyfikacja formularza opt-in | ✓ | review wyjątków | |
| wzbogacenie o dane firmy w minimalnym zakresie | ✓ | losowy QA | dane osób z wielu źródeł |
| scoring fit/readiness | ✓ | wyjaśnialna korekta | cechy wrażliwe |
| draft audytu/prototypu/wiadomości | ✓ | **zawsze przed wysyłką w pilotażu** | |
| wybór ceny, zakresu, obietnicy i terminu | | ✓ | |
| pierwsza wiadomość i oferta | | ✓ | autonomous send |
| przypomnienie po oczekiwanej odpowiedzi | draft/schedule | ✓ według zgody/sekwencji | nieograniczone follow-upy |
| odpowiedź na proste pytanie | draft | ✓ w pilotażu | prawne/płatnicze bez review |
| wypis/sprzeciw/suppression | ✓ natychmiast | audyt | ponowny opt-in bez dowodu |
| podpisanie umowy, rabat, refund | | ✓ | |

Po minimum 100 poprawnie zatwierdzonych wiadomościach można rozważyć automatyczną wysyłkę wyłącznie transakcyjnego potwierdzenia formularza, nie oferty. Każde rozszerzenie ma osobny risk review.

## Human approval checklist

Przed wysyłką operator widzi jedną kartę:

- odbiorca i dowód opt-in;
- dozwolony cel/kanał i termin;
- suppression = false;
- źródła faktów;
- draft i zaznaczone claims;
- oferta/cena/termin;
- brak danych wrażliwych;
- privacy/unsubscribe, jeśli wymagane;
- liczba wcześniejszych kontaktów;
- przyciski: approve/edit/reject/report data issue.

Approval zapisuje operatora, timestamp, wersję draftu i finalną treść. Nie wymaga czytania surowego promptu.

## Sekwencja kontaktu

Dla prośby o audyt rekomendacja pilotażowa:

1. natychmiastowe potwierdzenie otrzymania prośby — transakcyjne, bez dodatkowej oferty;
2. audyt/prototyp w obiecanym terminie;
3. jedno przypomnienie, jeśli mieści się w oczekiwanym celu i czasie;
4. zamknięcie sprawy; dalszy nurture tylko na odrębnej podstawie/zgodzie.

Nie używać sztucznej presji, fałszywych terminów ani pozorowania odpowiedzi człowieka. Każda wiadomość identyfikuje Sklepik i daje prostą możliwość zakończenia kontaktu.

## Kontrola domeny wysyłkowej

- oddzielić wiadomości transakcyjne, support i marketing logicznie oraz operacyjnie;
- skonfigurować SPF, DKIM, DMARC, TLS i alignment;
- list-unsubscribe/one-click dla wiadomości promocyjnych;
- honorować wypis maksymalnie natychmiast operacyjnie, niezależnie od technicznego limitu dostawcy;
- monitorować bounce, complaint, spam rate i reputację;
- nigdy nie rotować domen, aby obchodzić złą reputację;
- zatrzymać kampanię przy spam rate ≥0,1%, gwałtownym bounce lub skardze prawnej i przeprowadzić review.

## Scoring jakości zamiast wolumenu

```text
fit_score = produkt + gotowość operacyjna + realny termin + authority
intent_score = requested_audit + booked_call + supplied_materials + replied
risk_score = consent_ambiguity + regulated_product + abuse + ownership_unclear
priority = fit + intent − risk
```

Żaden scoring nie omija braku zgody. High fit bez opt-in pozostaje obiektem researchu, nie leadem wysyłkowym.

KPI:

- opt-in → kwalifikowany lead;
- czas opt-in → zatwierdzony audyt;
- audyt → rozmowa → płatny pilot → live → first fulfilled sale;
- pełny CAC i ludzkie minuty per klient;
- withdrawal, complaint, bounce i spam rate;
- odsetek draftów poprawionych/odrzuconych;
- błędy faktograficzne i incydenty prywatności;
- retencja 90 dni według źródła.

Nie optymalizować open rate kosztem zaufania. Główną metryką kanału jest koszt aktywnego sklepu z pierwszą zrealizowaną sprzedażą.

## Incident stop rules

Automatycznie zatrzymać wysyłkę, gdy:

- suppression check lub consent store jest niedostępny;
- draft nie ma źródeł faktów albo wykryto PII/sensitive data poza kontraktem;
- przekroczono limit kontaktów;
- complaint/spam/bounce przekracza próg;
- provider zgłasza authentication/reputation failure;
- regulator, prawnik lub użytkownik zgłasza zasadny problem;
- model/prompt zmienił się bez zatwierdzonego evaluation.

Fail closed: awaria nie może oznaczać wysyłki „na wszelki wypadek”.

## Eksperymenty 14/30/90 dni

### 14 dni

- przegląd prawny art. 398 PKE dla e-mail/telefon/DM i konkretnych treści formularzy;
- uruchomienie oddzielnych tabel market/opt-in/customer/suppression;
- landing audytu z wersjonowaną zgodą i privacy notice;
- ręczne przygotowanie 10 audytów wyłącznie po żądaniu;
- SPF/DKIM/DMARC/TLS i monitoring;
- zero cold outreach.

**Kryterium:** 100% kontaktów ma dowód, cel i suppression check; 0 niezatwierdzonych wysyłek; minimum 5 kwalifikowanych opt-inów i 2 rozmowy.

### 30 dni

- dwa źródła opt-in: audyt inbound i jeden partner;
- agent przygotowuje drafty, człowiek zatwierdza 100%;
- rejestr acceptance/edit/reject i minut operatora;
- test dwóch obietnic landing page bez dark patterns;
- pierwsza analiza complaints/withdrawals i jakości leadów.

**Kryterium:** ≥90% faktów w losowym QA poprawnych, 0 incydentów consent/suppression, czas przygotowania audytu spada ≥30% względem manualnego baseline, a przynajmniej 3 leady płacą za pilot.

### 90 dni

- 100 opt-in leadów lub jawnie mniejsza próba;
- minimum 3 partnerów z procesem client-initiated referral;
- porównanie CAC do first fulfilled sale;
- audyt DPO/prawny, retencji, vendorów i logów approval;
- automatyzować tylko potwierdzenia transakcyjne i powtarzalne drafty o niskim ryzyku;
- rozważyć drugi kraj dopiero po local legal matrix.

**Kryterium:** zero poważnych naruszeń, complaint rate <0,1%, pełne provenance 100% wiadomości, ≥20 płacących klientów lub wystarczający dowód jakości kanału, payback ≤6 miesięcy. Jeśli wolumen rośnie kosztem zgód/jakości, kanał zatrzymujemy zamiast rotować domenę lub łagodzić kontrole.

## Źródła

1. [Prawo komunikacji elektronicznej, Dz.U. 2024 poz. 1221](https://isap.sejm.gov.pl/isap.nsf/download.xsp/WDU20240001221/O/D20241221.pdf)
2. [RODO — tekst rozporządzenia](https://eur-lex.europa.eu/legal-content/PL/TXT/?uri=CELEX%3A32016R0679)
3. [EDPB — legitimate interest case digest, 26.03.2026](https://www.edpb.europa.eu/documents/support-pool-of-experts/one-stop-shop-case-digest-on-the-legal-basis-of-legitimate_en)
4. [EDPB — web scraping and anonymisation, 08.07.2026](https://www.edpb.europa.eu/news/edpb-sheds-light-on-anonymisation-and-web-scraping-for-generative-ai-and-adopts-final-version_en)
5. [Your Europe — Promoting a business online, 29.04.2026](https://europa.eu/youreurope/business/running-business/digitalising/promoting-business-online/index_en.htm)
6. [Google — Email sender guidelines FAQ](https://support.google.com/mail/answer/14229414?hl=en)
7. [Meta — Lead ads with forms](https://www.facebook.com/business/ads/ad-objectives/lead-generation/lead-ads-with-forms)

## Co obniża pewność

- brak opinii prawnej dla gotowych treści i kanałów Sklepika;
- interpretacje i wyjątki różnią się między państwami UE;
- EDPB Guidelines 03/2026 są świeże i dotyczą wprost scrapingu dla generatywnej AI;
- skuteczność audytu/prototypu nie została jeszcze zmierzona;
- progi 0,1%, 30%, 90% i 100 leadów są guardrails/założeniami operacyjnymi, nie gwarancją legalności ani wyniku.
