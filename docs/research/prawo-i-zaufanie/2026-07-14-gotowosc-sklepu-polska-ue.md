# Gotowość prawna i zaufanie sklepu — Polska i UE (2026)

**Stan badania:** 2026-07-14  
**Zakres:** sprzedaż internetowa B2C z Polski, z zaznaczeniem cross-border UE  
**Charakter dokumentu:** mapa produktowa i kontrolna, nie porada prawna ani gotowy regulamin.

## Werdykt

Sklepik powinien technicznie uniemożliwiać uruchomienie checkoutu, dopóki merchant nie poda danych sprzedawcy, zasad dostawy/zwrotów/reklamacji, podstawowych informacji produktowych i nie skonfiguruje płatności. Platforma może zapewnić bezpieczne mechanizmy, checklisty i wersjonowane wzorce, ale **merchant pozostaje odpowiedzialny za prawdziwość danych, legalność produktu, podatki i treść swojej umowy z konsumentem**.

Największy błąd produktowy to obiecać „automatycznie zgodny prawnie sklep”. Poprawna obietnica: **„prowadzimy przez wymagania, wykrywamy braki, dostarczamy mechanizmy i ślad audytowy; treść branżową zatwierdza sprzedawca, a przypadki podwyższonego ryzyka — prawnik lub specjalista.”**

Minimalny launch gate powinien obejmować: identyfikację merchanta, pełną cenę i dostawę, przycisk z obowiązkiem zapłaty, prawo odstąpienia, workflow reklamacji, prywatność/cookies, dostępność, wymagane dane GPSR oraz aktywną płatność i wysyłkę. Kategorie regulowane wymagają osobnego gate.

## Metoda i poziom pewności

- Priorytet: Komisja Europejska, EUR-Lex, Your Europe, UOKiK, UODO i Ministerstwo Finansów/KSeF.
- Stan wdrożenia krajowego i interpretacje mogą się zmieniać; przed produkcyjnymi wzorcami regulaminów potrzebna jest kontrola polskiego prawnika.
- **Wysoka pewność:** 14-dniowe odstąpienie, 2-letnia odpowiedzialność, Omnibus, GPSR, wejście EAA, terminy KSeF.
- **Średnia pewność:** dokładny podział odpowiedzialności platforma–merchant, bo zależy od faktycznej roli Sklepika, umów, przetwarzania danych i tego, czy stanie się marketplace'em.
- **Wymaga porady:** branże regulowane, sprzedaż zagraniczna poza prostym OSS, wyjątki od odstąpienia, treść regulaminów i kwalifikacja Sklepika jako pośrednika/marketplace.

## Model odpowiedzialności

| Warstwa | Platforma Sklepik | Merchant |
|---|---|---|
| Tożsamość sprzedawcy | wymagane pola, publikacja danych, walidacja i historia zmian | poprawne dane firmy, adres, kontakt, NIP/rejestr i aktualizacje |
| Umowa i checkout | prawidłowe UI, suma kosztów, checkboxy, dowód zgody, „zamówienie z obowiązkiem zapłaty” | oferta, ceny, dostawy, terminy, wyjątki, realizacja umowy |
| Konsument | workflow zwrotu/reklamacji, terminy, szablony komunikacji | rozpatrzenie, koszty, zwroty środków, zgodność praktyki z regulaminem |
| Produkt | pola GPSR/branżowe, blokady braków, recall/unpublish | bezpieczeństwo, oznaczenia, producent/importer, instrukcje, zgodność i dokumentacja |
| Dane | bezpieczna architektura, DPA, procesory, eksport/usunięcie, logi | administrator swoich klientów: cele, podstawy, treść polityki, realizacja praw |
| Cookies/marketing | CMP, prior blocking, rejestr zgód, łatwe wycofanie | wybór narzędzi, cele, poprawna podstawa i listy marketingowe |
| Podatki/faktury | integracje, dane i eksport, opcjonalnie KSeF connector | stawki, rejestracja VAT/OSS, fiskalizacja i prawidłowe faktury |
| Dostępność | dostępny system i komponenty; testy regresji | dostępne treści, alt text, dokumenty, kolory i konfiguracja |

Jeżeli Sklepik zacznie pośredniczyć w ofertach wielu niezależnych sprzedawców pod wspólnym interfejsem lub przejmie płatność/fulfilment, analizę roli trzeba powtórzyć: mogą dojść obowiązki marketplace, DSA, DAC7, GPSR online marketplace i inne.

## Mapa obowiązków i wymagań produktu

| Obszar | Fakt prawny / operacyjny | Mechanizm wymagany w Sklepiku | Właściciel |
|---|---|---|---|
| Informacje przed zakupem | konsument musi znać towar/usługę, sprzedawcę, pełną cenę, dostawę, płatność, termin i prawa przed zawarciem umowy | komplet danych w produkcie, stopce, koszyku i podsumowaniu; trwałe potwierdzenie po zakupie | wspólnie |
| Zawarcie umowy | CTA musi jasno komunikować obowiązek zapłaty; brak ukrytych dopłat i domyślnych płatnych dodatków | zablokowany, testowany komponent checkout CTA; snapshot zamówienia i zgód | platforma |
| Odstąpienie | co do zasady 14 dni dla umów na odległość; istnieją ustawowe wyjątki | informacja, wzór formularza, self-service request, termin i koszt zwrotu; wyjątek tylko z uzasadnionym typem produktu | merchant + platforma |
| Reklamacje | sprzedawca odpowiada za niezgodność towaru przez 2 lata; odpowiedź w Polsce co do zasady w 14 dni | osobny workflow od dobrowolnego zwrotu/gwarancji, SLA i audit log | merchant |
| Omnibus | przy komunikowanej obniżce podaje się najniższą cenę z 30 dni, czytelnie również na liście/reklamie | nieusuwalna historia cen, poprawne reguły dla nowych/szybko psujących się produktów, komponent na listing/PDP/feed | platforma |
| Opinie | informacja czy i jak weryfikowane; zakaz fałszywych opinii i manipulacji | status „potwierdzony zakup”, publikacja zasad moderacji, brak generowania opinii AI | wspólnie |
| Personalizacja/ranking | ujawnienie personalizacji ceny; marketplace ujawnia główne parametry rankingu | flagi personalizacji, explainability i rejestr reguł | platforma |
| GDPR | legalność, celowość, minimalizacja, retencja, bezpieczeństwo, prawa osób, umowy procesorów | data map, DPA/subprocesorzy, RBAC, eksport/usunięcie, incident workflow, retention jobs | wspólnie |
| Cookies/ePrivacy | niekonieczne trackery wymagają uprzedniej, dobrowolnej zgody; odmowa/wycofanie realne | prior blocking, równorzędne „odrzuć”, granularność, rejestr wersji i skan cookies | platforma + merchant |
| EAA/dostępność | e-commerce objęty wymaganiami dostępności od 28.06.2025; dyrektywa przewiduje zwolnienie mikroprzedsiębiorstw świadczących usługi, ale platforma nie powinna opierać strategii na wyjątku | WCAG 2.2 AA jako baseline, klawiatura, focus, błędy formularzy, screen reader, dostępne e-maile i deklaracja dostępności | wspólnie |
| GPSR | od 13.12.2024 oferta online musi jasno pokazywać wymagane informacje o produkcie/operatorach i ostrzeżenia | producent, adres/kontakt, osoba odpowiedzialna UE gdy dotyczy, identyfikator/zdjęcie, ostrzeżenia w języku rynku; recall/unpublish | merchant; platforma wymusza pola |
| CE / sektorowe safety | CE tylko dla kategorii objętych harmonizacją; producent/importer ma obowiązki oceny i dokumentacji | kategoria ryzyka, dokumenty/oznaczenia, gate dla zabawek/elektroniki/PPE/medical | merchant + specjalista |
| VAT/OSS | próg unijny 10 tys. EUR dla określonej transgranicznej sprzedaży B2C; OSS upraszcza deklarowanie VAT kraju konsumpcji | kraje, stawki, dowody lokalizacji, raport OSS, korekty/zwroty; integracja księgowa | merchant |
| KSeF | od 1.04.2026 większość polskich przedsiębiorców wystawia B2B w KSeF; najmniejsi ≤10 tys. zł miesięcznej sprzedaży fakturowanej do 1.01.2027; B2C nie jest obowiązkowe | rozróżnienie B2B/B2C, NIP, integracja lub eksport, numer/status KSeF, offline/awaria i idempotencja | merchant + integracja platformy |
| Płatności | licencjonowany PSP realizuje płatność/SCA; Sklepik nie powinien przechowywać danych kart | hosted checkout/tokenizacja, webhook verification, idempotencja, refund i reconciliation | PSP + platforma |
| Geoblocking/cross-border | nieuzasadniona dyskryminacja dostępu/płatności jest ograniczona, ale merchant nie musi dostarczać do każdego kraju | oddzielić kraj sprzedaży od miejsca dostawy, jasne ograniczenia i metody płatności | merchant |

Źródła rdzeniowe: [prawa przy zakupach w UE](https://europa.eu/youreurope/citizens/consumers/shopping/shopping-consumer-rights/index_en.htm), [Consumer Rights Directive](https://commission.europa.eu/law/law-topic/consumer-protection-law/consumer-contract-law/consumer-rights-directive_en), [UOKiK — odstąpienie](https://prawakonsumenta.uokik.gov.pl/prawo-odstapienia-od-umowy/), [UOKiK — niezgodność towaru](https://prawakonsumenta.uokik.gov.pl/reklamacja/niezgodnosc/), [UOKiK — ceny Omnibus](https://uokik.gov.pl/w-black-friday-jasne-ceny), [wytyczne GPSR](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52025XC06233), [EAA](https://eur-lex.europa.eu/EN/legal-content/summary/accessibility-of-products-and-services.html), [zasady GDPR](https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/principles-gdpr_en), [ważna zgoda](https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/legal-grounds-processing-data/grounds-processing/when-consent-valid_en), [KSeF — zakres](https://ksef.podatki.gov.pl/informacje-ogolne-ksef-20/zakres-obowiazkowego-ksef/).

## GPSR: minimalny model danych produktu

W zależności od roli i produktu oferta online powinna mieć co najmniej:

- nazwę i dane kontaktowe producenta;
- jeśli producent nie jest w UE — dane osoby odpowiedzialnej w UE;
- informacje pozwalające zidentyfikować produkt: obraz, typ, partia/serial/SKU, gdy właściwe;
- ostrzeżenia i informacje bezpieczeństwa w języku łatwo zrozumiałym na rynku sprzedaży;
- kategorię produktu i flagę regulowaną;
- dokumenty/oznaczenia sektorowe, jeśli dotyczy;
- możliwość szybkiego wycofania partii, wskazania klientów i wysłania powiadomienia.

Platforma powinna przechowywać snapshot tych danych przy zamówieniu. Same pola nie potwierdzają legalności — merchant odpowiada za treść i dokumentację. Oficjalne wytyczne GPSR obowiązki stosują od 13 grudnia 2024 r. i podkreślają rolę zależną od konkretnej oferty ([Komisja/EUR-Lex](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52025XC06233)).

## Dane osobowe i cookies: minimum operacyjne

1. Zmapować role: merchant zwykle administrator danych kupujących, Sklepik procesor; dla billing/security własnym administratorem może być Sklepik.
2. DPA z merchantem, lista subprocessors, lokalizacje i mechanizmy transferów poza EOG.
3. Rozdzielić niezbędne dane checkoutu od marketingu; osobna, niewymuszona zgoda marketingowa.
4. Przed zgodą blokować analytics/ads/embeds, które zapisują/odczytują dane na urządzeniu; techniczne/auth cookies mogą być konieczne.
5. Umożliwić równie łatwą odmowę i wycofanie; logować treść i wersję zgody.
6. Retencja per kategoria, obsługa access/correction/deletion/objection i legal holds dla księgowości/sporów.
7. MFA dla admina, least privilege, szyfrowanie, backup/restore tests, alerty i procedura naruszenia.

Komisja wskazuje, że niekonieczne cookies są odrzucalne, a techniczne/auth mogą nie wymagać zgody; ważna zgoda musi być możliwa do wycofania ([cookies](https://commission.europa.eu/cookies-policy_en), [consent](https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/legal-grounds-processing-data/grounds-processing/when-consent-valid_en)). Produkcyjną interpretację polskiego Prawa komunikacji elektronicznej powinien sprawdzić prawnik/privacy specialist.

## Dostępność

E-commerce jest w zakresie EAA od czerwca 2025 r. Wyjątek dla mikroprzedsiębiorstw świadczących usługi wymaga kwalifikacji konkretnego merchanta; nie zwalnia on Sklepika z budowy dostępnej platformy ani nie jest rozsądną strategią wzrostu. Minimum testów:

- pełna obsługa klawiaturą, widoczny focus, skip links i logiczne nagłówki;
- etykiety, instrukcje i komunikaty błędów formularzy czytane przez technologie asystujące;
- kontrast, zoom/reflow, tekst alternatywny, niepoleganie wyłącznie na kolorze;
- dostępne uwierzytelnienie, koszyk, płatność i status zamówienia;
- napisy/transkrypcje treści, dostępne PDF-y i e-maile;
- ręczny audyt screen reader + automatyczne testy jako regresja, nie jako certyfikat.

Źródło zakresu: [Komisja — EAA obowiązuje od czerwca 2025](https://commission.europa.eu/news-and-media/news/eu-becomes-more-accessible-all-2025-07-31_en).

## Podatki, OSS i KSeF

Na 14 lipca 2026 r. odbieranie faktur KSeF jest obowiązkowe dla objętych podmiotów od 1 lutego; wystawianie dla większości od 1 kwietnia, z przejściowym wyłączeniem najmniejszych do 10 tys. zł brutto miesięcznie sprzedaży dokumentowanej fakturami do końca 2026. Faktury B2C nie muszą być wystawiane w KSeF, mogą dobrowolnie. Kary pieniężne za błędy KSeF przewidziano od 1 stycznia 2027 ([MF — zasady 2026](https://ksef.podatki.gov.pl/ksef-news/zasady-obowiazywania-ksef-i-przepisy-prawne/)).

Decyzja produktowa: Sklepik nie musi od razu być systemem księgowym. Powinien mieć poprawny model faktury, status integracji, idempotentny eksport/API, tryby awaryjne i partnera księgowego. Wysokość VAT, kasa fiskalna, B2B/B2C i OSS pozostają konfiguracją merchanta weryfikowaną przez księgowego.

## Kategorie regulowane — osobne launch gates

| Kategoria | Dodatkowe wymagania / ryzyko | Polityka startowa Sklepika |
|---|---|---|
| Żywność | obowiązkowe informacje przed zakupem, składniki, alergeny, ilość, warunki, operator, nutrition/origin gdy dotyczy | branżowy schema + obowiązkowe alergeny; kontrola specjalisty |
| Kosmetyki / mydło kosmetyczne | Responsible Person w UE, safety assessment/PIF, GMP, etykieta i CPNP | nie publikować jako kosmetyk bez deklaracji RP/CPNP; prawnik/regulatory reviewer |
| Suplementy | żywność + notyfikacja/claims; wysokie ryzyko niedozwolonych twierdzeń zdrowotnych | brak generowania claims AI; weryfikacja krajowa |
| Alkohol | zezwolenia, wiek, reklama i krajowe ograniczenia sprzedaży/dostawy | domyślnie poza self-service; indywidualna opinia prawna |
| Leki/wyroby medyczne | odrębne zezwolenia, rejestry, reklama, MDR/CE | poza standardowym onboardingiem |
| Zabawki/elektronika/PPE | CE, dokumentacja, importer, ostrzeżenia, baterie/WEEE gdy dotyczy | dokumenty i osoba odpowiedzialna przed publikacją |
| Produkty personalizowane/cyfrowe | możliwe wyjątki od odstąpienia wymagają prawidłowej informacji i często uprzedniej zgody | dedykowany typ produktu i dowód zgody |

Żywność online musi pokazywać obowiązkowe informacje przed zawarciem umowy, a przy dostawie komplet łącznie z datą; alergeny są szczególnie istotne ([Komisja — distance selling food](https://food.ec.europa.eu/food-safety/labelling-and-nutrition/food-information-consumers-legislation/distance-selling_en)). Kosmetyki sprzedawane online w UE muszą mieć EU Responsible Person, a CPNP jest systemem notyfikacji ([Komisja/Parlament 2026](https://www.europarl.europa.eu/doceo/document/E-10-2025-005070-ASW_EN.html), [CPNP](https://single-market-economy.ec.europa.eu/sectors/cosmetics/cosmetic-product-notification-portal_en)).

## Co bezwzględnie sprawdza prawnik

- wzorce regulaminu, odstąpienia, reklamacji, prywatności i DPA;
- wyjątki od odstąpienia i produkty cyfrowe/personalizowane/higieniczne;
- kwalifikację Sklepika jako hosting, SaaS, marketplace, sprzedawca lub współadministrator;
- kategorie regulowane i twierdzenia marketingowe;
- sprzedaż do konkretnego państwa UE, prawo właściwe i lokalne obowiązki;
- cookies/marketing stack i transfery poza EOG;
- mechanizm generowania „dokumentów prawnych przez AI” — powinien pozostać draftem z wersją źródeł i akceptacją.

## Decyzje produktowe

1. Readiness API zwraca osobno `technical`, `commercial`, `legal`, `regulated`; status „green” nie jest certyfikatem prawnym.
2. Wersjonować polityki i zgody; do zamówienia zapisywać wersję, cenę, dane produktu/GPSR i komunikaty checkoutu.
3. Nie pozwalać merchantowi usuwać obowiązkowych komponentów ceny, sprzedawcy, checkout CTA i bezpieczeństwa produktu w edytorze.
4. Dodać kategorię ryzyka i branżowe schematy; AI nie może zmieniać pól krytycznych bez źródła i zatwierdzenia.
5. Utrzymywać „legal change radar” z właścicielem, datą przeglądu i migracją istniejących sklepów.

## Eksperymenty 14/30/90 dni

### 14 dni

- audyt jednego przykładowego sklepu przez prawnika konsumenckiego/privacy oraz accessibility specialist;
- kontrakt danych dla merchant identity, GPSR i snapshotu zamówienia;
- test cookie scanner przed/po odmowie oraz ręczny test checkoutu klawiaturą/screen readerem;
- lista kategorii blokowanych lub wymagających ręcznego review.

### 30 dni

- wdrożyć legal/readiness gate, policy versioning, consent receipts i history cen Omnibus;
- przeprowadzić test reklamacji, odstąpienia, refundu i wycofania partii od końca do końca;
- prototyp eksportu/KSeF z księgowym i scenariusz awarii/idempotencji;
- pilotaż branżowy dla żywności albo kosmetyków dopiero po review specjalisty.

### 90 dni

- kwartalny audyt losowej próby sklepów i automatyczne wykrywanie braków;
- umowy DPA/subprocessors, retention jobs, backup restore i tabletop incident;
- VPAT-like accessibility evidence/deklaracja procesu oraz zewnętrzny audyt ścieżki krytycznej;
- decyzja, czy zakres produktu obejmuje marketplace/cross-border — jeśli tak, osobny projekt prawny.

## Mierniki

- 100% zamówień z niezmiennym snapshotem ceny, treści CTA, wersji polityk i produktu;
- 0 niekoniecznych trackerów przed zgodą;
- 100% produktów ryzykownych z wymaganymi polami lub blokadą publikacji;
- czas obsługi DSAR, reklamacji, odstąpienia i recall;
- liczba regresji accessibility w checkout oraz pokrycie testów ręcznych;
- odsetek sklepów z aktualną weryfikacją prawną/branżową, nie tylko zaznaczonym checkboxem.

