# AI, za które właściciel małego sklepu zapłaci

**Data badania:** 2026-07-14  
**Cel:** ustalić kolejność inwestycji AI według gotowości do zapłaty (WTP), aktywacji, wpływu na GMV, kosztu i ryzyka.  
**WTP:** hipoteza produktowa, nie wynik własnego badania cenowego Sklepika.

## Werdykt

Największą szansę na pieniądze mają funkcje, które **kończą pracę** lub **zmniejszają koszt stały**, a nie jedynie generują materiał do poprawienia. Pierwsze trzy zakłady dla Sklepika to:

1. import i wzbogacenie katalogu z linku/zdjęcia/CSV;
2. agent gotowości, który prowadzi i wykonuje konfigurację do publikacji;
3. agent wzrostu generujący mierzalną kampanię lub merchandising i proszący o akceptację.

Prompt-to-layout jest kluczowy dla efektu „wow” i aktywacji, ale będzie szybko commoditized przez Shopify/Wix/builders. Chatbot zakupowy ma potencjał w katalogach wymagających doradztwa, lecz dla małego sklepu z kilkunastoma produktami bywa rozwiązaniem bez problemu. Generowanie copy i obrazów powinno być składnikiem przepływu, nie osobnym drogim produktem.

## Metoda, dowody i poziom pewności

- Porównano oficjalne funkcje Shopify, Wix, Shoper, IdoSell i WooCommerce oraz badania terenowe/akademickie z lat 2025–2026.
- „Dostępne na rynku” nie oznacza „zwiększa GMV”. Deklaracje vendorów typu „+15% konwersji” bez metodologii nie są traktowane jako dowód.
- Najmocniejsze dowody dotyczą produktywności operacyjnej; dowody na przyrost sprzedaży są mieszane i zależne od kategorii.
- Duże eksperymenty w online retail znalazły dodatnią wartość tylko w części wdrożeń GenAI, co przemawia za eksperymentowaniem funkcja po funkcji, nie pakietem „AI everywhere” ([field experiments](https://arxiv.org/abs/2510.12049)).
- Poziom pewności rankingów: **średni**. WTP i wpływ muszą zostać skalibrowane na polskich mikrofirmach.

## Ranking inwestycji

Skala 1–5: 5 = najwyżej. Koszt i ryzyko: 5 = najdrożej/najbardziej ryzykownie.

| # | Funkcja | WTP | Aktywacja | GMV / oszczędność | Koszt | Ryzyko | Rekomendacja |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | Import katalogu z URL/CSV/zdjęć + normalizacja | 5 | 5 | 4 | 3 | 3 | budować teraz |
| 2 | Agent gotowości sklepu i konfiguracji | 5 | 5 | 4 | 3 | 3 | budować teraz |
| 3 | Kampanie z zatwierdzeniem i pomiarem przychodu | 5 | 3 | 5 | 4 | 4 | pilot w jednej kampanii |
| 4 | Merchandising: kolekcje, cross-sell, promocje | 4 | 3 | 5 | 3 | 3 | po pierwszych danych |
| 5 | Support agent ze sprawdzaniem zamówień i eskalacją | 4 | 2 | 4 oszczędność | 4 | 5 | dopiero przy wolumenie |
| 6 | Prompt-to-store/layout z bezpiecznym edytorem | 3 | 5 | 2–3 | 4 | 3 | budować jako aktywację, nie SKU |
| 7 | SEO i widoczność w wyszukiwarkach/LLM | 4 | 3 | 3 długoterminowo | 3 | 4 | jako ciągły workflow |
| 8 | Analityk i „next best action” | 4 | 2 | 4 | 4 | 4 | po zebraniu danych |
| 9 | Treści produktowe i tłumaczenia | 2 | 4 | 2 | 1 | 3 | wbudować, nie sprzedawać osobno |
| 10 | Obrazy/lifestyle/background removal | 3 | 4 | 2–3 | 2 | 4 | pakiet kredytów + kontrola |
| 11 | Chatbot zakupowy/rekomendacje dialogowe | 3 | 2 | 2–4 zależnie od katalogu | 4 | 5 | eksperyment niszowy |

## Macierz: za jaki rezultat klient płaci

| Job-to-be-done klienta | Słaba obietnica | Płatna obietnica | Jednostka rozliczenia |
|---|---|---|---|
| „Mam produkty, ale nie mam katalogu” | wygenerujemy opis | wrzuć link/zdjęcia; dostaniesz gotowe produkty, warianty i braki do zatwierdzenia | pakiet importu / liczba SKU |
| „Nie wiem, czy mogę wystartować” | chatbot odpowie na pytania | agent doprowadzi sklep do zielonej checklisty i wskaże blokery | wdrożenie / plan z opieką |
| „Nie umiem reklam” | wygenerujemy post | kampania zostanie przygotowana, uruchomiona po zgodzie i rozliczona wynikiem | abonament + budżet / success fee ostrożnie |
| „Klienci ciągle pytają” | FAQ bot | agent zna katalog i zamówienie, rozwiązuje dozwolone sprawy, eskaluje resztę | liczba rozwiązanych spraw |
| „Nie wiem, co zmienić” | dashboard AI | co tydzień 3 działania, przewidywany efekt, wykonanie po akceptacji i raport | abonament growth |
| „Sklep wygląda zwyczajnie” | obraz z promptu | spójny system marki + layouty bez psucia checkoutu, z wersjonowaniem | plan premium / redesign |

## Analiza funkcji

### 1. Import i wzbogacanie produktów — najwyższy priorytet

**Fakt:** istniejące platformy monetyzują importy dostawców. IdoSell Downloader pobiera ofertę, ceny, opisy i zdjęcia, a w bieżącym cenniku jest osobną usługą. To bezpośredni dowód rynkowej WTP za usunięcie ręcznej pracy ([IdoSell cennik](https://www.idosell.com/pl/order/)).

**Produkt:** URL/CSV/PDF/zdjęcia → propozycje produktów, wariantów, kategorii, atrybutów, cen i SEO; jawne źródło każdego pola; deduplikacja; wskaźnik pewności; masowa akceptacja.

**Ryzyka:** prawa do zdjęć/opisów, halucynowane parametry, błędny VAT/cena, duplikaty. Nie publikować automatycznie pól krytycznych bez reguł i zatwierdzenia.

### 2. Agent gotowości i onboarding — najwyższy priorytet

Wix potrafi wygenerować biznesową stronę z promptu, a Shopify Sidekick podejmuje działania w panelu. Przewaga nie może więc polegać na samej rozmowie. Agent Sklepika powinien posiadać **stan celu**: katalog, dane firmy, płatność, dostawa, polityki, domena, test zamówienia i publikacja. Każda odpowiedź ma albo wykonać krok, albo odblokować decyzję.

WTP jest wysoka, bo konkuruje z płatnym wdrożeniem: IdoSell pokazuje pakiety od 1 199 do 29 999 zł. To nie znaczy, że AI może przejąć całość tej wartości, ale daje sufit cenowy dla rezultatu „uruchomiony sklep”.

### 3. Prompt-to-store i layout — aktywator, nie fosa

Wix już oferuje prompt → e-commerce z logiką, produktami i późniejszą edycją; Shopify Sidekick generuje bloki dla motywów ([Wix AI builder](https://www.wix.com/ai-website-builder), [Shopify Winter '26](https://www.shopify.com/editions/winter2026)).

Budować, ale z wyróżnikami:

- generowanie z **rzeczywistego katalogu i celu marki**, nie lorem ipsum;
- allowlista bezpiecznych sekcji, responsywność, dostępność i budżety wydajności;
- wersje, diff, rollback i niezależny opublikowany snapshot;
- automatyczne testy kontrastu, pustych stanów i ścieżki zakupowej;
- AI nie modyfikuje krytycznego checkoutu bez osobnego procesu.

### 4. Treści, obrazy i tłumaczenia — higiena produktu

Shoper ma sklep aplikacji AI, a IdoSell rozlicza automatyczne tłumaczenia za znaki. Generowanie tekstu jest tanie i powszechne, więc sam „generator opisów” ma niską WTP. Wartość rośnie, gdy jest częścią importu, utrzymuje ton marki, wykrywa braki i aktualizuje wszystkie kanały.

Obrazy mają wyższą postrzeganą wartość, ale też ryzyko zafałszowania produktu. Rozdzielić:

- bezpieczne transformacje: crop, tło, cień, format, alt;
- kreatywne lifestyle: wyraźne oznaczenie i kontrola zgodności z produktem;
- generowanie samego produktu: domyślnie niedozwolone dla kategorii, gdzie wygląd jest cechą oferty.

### 5. Merchandising — potencjalnie największy wpływ na GMV

Shopify Sidekick buduje kolekcje i analizuje pricing, IdoSell i Shoper oferują rekomendacje. Jednak marketingowe twierdzenia vendorów o konwersji nie mają w publicznych stronach pełnej metodologii, więc traktujemy je jako hipotezę.

Pierwsza wersja powinna być regułowa i mierzalna: bestsellery, zapas, marża, komplementarność, nowość, wykluczenia. LLM może wyjaśniać i proponować, ale ranking powinien respektować twarde ograniczenia. Eksperyment A/B per moduł, nie globalne „AI on/off”.

### 6. Kampanie — wysoka WTP tylko z wykonaniem i atrybucją

Tekst maila nie jest produktem. Produkt to segment → oferta → kreacja → zgoda → wysyłka → przychód/odpisy/unsubscribe → następna decyzja. Shopify Sidekick już deklaruje budowę kampanii i optymalizację marketing mix, więc Sklepik powinien wygrać prostotą dla mikrofirm i opieką człowieka.

Ryzyka: spam, reputacja domeny, zgody marketingowe, przepalenie budżetu, fałszywa atrybucja. Domyślnie draft+approval, limity wydatków i kill switch.

### 7. Support agent — oszczędność przy skali, nie na dzień pierwszy

Klarna raportowała, że asystent obsługi wykonywał pracę odpowiadającą ponad 700 etatom; jej raporty giełdowe potwierdzają użycie w ostatnich 12 miesiącach. Jednocześnie relacje z 2025 wskazują powrót ludzi do złożonych spraw. To dobry model: automatyzować śledzenie, FAQ i proste zmiany, eskalować zwroty sporne, fraud, tożsamość i wyjątki ([Klarna filing](https://d18rn0p25nwr6d.cloudfront.net/CIK-0002003292/67991e36-4112-4c68-a771-e3feae27b281.pdf), [AP o ograniczeniach automatyzacji](https://apnews.com/article/ca87ae77d7c6797ebb2628bd1b532929)).

Dla mikrofirm płatność pojawi się dopiero, gdy liczba spraw jest odczuwalna. Wcześniej wystarczą sugerowane odpowiedzi właścicielowi.

### 8. Chatbot zakupowy — selektywny zakład

WooCommerce sprzedaje dodatki z dialogowym wyszukiwaniem już za $29–39 rocznie plus API, więc sam widget nie ma dużej bariery. Badania adopcji podkreślają zaufanie i prywatność; ShoppingComp pokazuje, że trafność i bezpieczeństwo są nadal trudne. Z kolei badanie 31 mln użytkowników Ctrip daje mocną podstawę do analizowania, kto, kiedy i po co używa asystenta — ale kontekst travel nie przenosi się automatycznie na mydło ([Ctrip study](https://arxiv.org/abs/2603.24947)).

Najlepsze nisze: produkty porównywalne technicznie, prezenty, rutyny kosmetyczne, konfiguratory i duże katalogi. Zły pierwszy target: sklep z 12 oczywistymi produktami.

### 9. SEO/AEO i analityk — produkt ciągły

Publikowanie masy tekstu AI grozi duplikacją i niską jakością. Płatna wartość to kontrola indeksacji, structured data, feed, wewnętrzne linkowanie, aktualność, błędy techniczne oraz pomiar wejść i sprzedaży. Badania nad ruchem z LLM są sprzeczne: Marketing Science zestawia branżowe wyniki od przewagi konwersji do wyniku Adobe niższego o 9% od kanałów non-AI. To obszar do mierzenia, nie obietnicy gwarantowanej sprzedaży ([przegląd dowodów](https://pubsonline.informs.org/doi/10.1287/mksc.2025.0489)).

Analityk jest wartościowy dopiero, gdy ma dane, baseline i możliwość wykonania rekomendacji. Bez tego staje się generatorem oczywistych porad.

## Guardrails wymagane przed autonomią

| Obszar | Domyślna polityka |
|---|---|
| cena, rabat, budżet reklamowy | twarde limity + akceptacja właściciela |
| produkt i parametry | źródło pola, confidence, brak zgadywania danych regulowanych |
| publikacja layoutu | preview, accessibility/performance tests, snapshot, rollback |
| mail/SMS/reklama | zgoda, segment preview, suppression list, limit wysyłki |
| obsługa zamówienia | allowlista akcji; zwrot pieniędzy i wyjątki do człowieka |
| chatbot zakupowy | cytowanie danych katalogu, brak porad medycznych/prawnych, log audytowy |
| dane klienta | minimalizacja, role, retencja i brak treningu na danych bez podstawy |

## Model cenowy do przetestowania

Nie sprzedawać „tokenów AI” jako głównej narracji. Klient rozumie rezultat:

- **Start:** AI w cenie, limity importu i generacji; samodzielne zatwierdzanie.
- **Launch:** jednorazowa opłata za doprowadzenie do gotowego sklepu.
- **Grow:** miesięczny agent kampanii/merchandisingu z raportem wyniku.
- **Concierge:** człowiek zatwierdza pracę agentów; wyższy abonament.
- Usage-based tylko tam, gdzie odpowiada wartości: SKU importowane, kampanie, rozwiązane sprawy — z sufitem kosztu.

## Eksperymenty 14/30/90 dni

### 14 dni

1. **Fake-door WTP:** trzy karty oferty — import katalogu, launch agent, growth agent — z cenami i rozmową zamiast checkoutu. Mierzyć kliknięcie i akceptowalny przedział.
2. **Concierge import:** 5 katalogów rzeczywistych sprzedawców, AI + ręczna kontrola. Mierzyć minuty/SKU, odsetek zaakceptowanych pól, błędy krytyczne.
3. **Prompt-to-layout:** 10 właścicieli; porównać pusty edytor z wygenerowanym draftem. Mierzyć czas do pierwszego „to wygląda jak moja marka” i liczbę poprawek.

### 30 dni

1. Agent gotowości dla 5 pilotów: cel publikacja w 7 dni; mierzyć blokery, ludzkie interwencje i ukończenie.
2. Jedna kampania win-back lub launch z grupą kontrolną; mierzyć incremental revenue, nie tylko opens/clicks.
3. Rekomendacje regułowe kontra AI-assisted w 2 sklepach z odpowiednim ruchem; guardrail marży i zapasu.
4. Support copilot tylko dla właściciela: mierzyć czas odpowiedzi i procent sugestii wysłanych bez zmian.

### 90 dni

1. Randomizować co najmniej dwa onboarding flows i porównać publikację, pierwsze SKU, podłączenie płatności i pierwsze zamówienie.
2. Uruchomić zakupowego asystenta wyłącznie w jednej kategorii doradczej; mierzyć użycie, add-to-cart, konwersję i błędne rekomendacje.
3. Wprowadzić tygodniowy „next best action” z przyciskiem wykonania; mierzyć wykonanie i efekt względem sklepów bez rekomendacji.
4. Ustalić cenę na podstawie faktycznej oszczędności czasu i marży, nie kosztu modelu.

## Progi „buduj / zatrzymaj”

| Funkcja | Próg dalszej inwestycji |
|---|---|
| import | ≥80% niekrytycznych pól zaakceptowanych; 0 publikowanych błędów ceny; ≥70% oszczędności czasu |
| launch agent | ≥60% sklepów opublikowanych w 7 dni; <3 h ludzkiej obsługi/sklep |
| layout | ≥30% krótszy czas do akceptowanego draftu niż szablon; brak regresji checkout/performance |
| kampanie | dodatni incremental gross profit po kosztach i unsubscribe bez pogorszenia reputacji |
| support | ≥60% prostych spraw rozwiązanych; 100% prawidłowych eskalacji spraw wysokiego ryzyka |
| chatbot zakupowy | poprawa add-to-cart lub konwersji z CI; <1% poważnych błędów rekomendacji |

## Co odłożyć

- pełną autonomię cenową i reklamową;
- ogólnego chatbota „wie wszystko”;
- generowanie tysięcy stron SEO bez popytu;
- trenowanie własnego dużego modelu;
- agentic checkout przed stabilnym katalogiem, płatnościami i kontrolą ryzyka;
- rozliczenie success fee zanim atrybucja zostanie wiarygodnie zmierzona.

## Główne źródła

- [Shopify Sidekick — funkcje i włączenie w plan](https://www.shopify.com/sidekick)
- [Shopify Winter '26 — multi-step actions i block generation](https://www.shopify.com/editions/winter2026)
- [Wix AI Website Builder](https://www.wix.com/ai-website-builder)
- [Shoper AI App Store](https://www.shoper.pl/appstore-aplikacje/ai)
- [IdoSell cennik i moduły AI/import](https://www.idosell.com/pl/order/)
- [WooCommerce AI shopping assistant](https://woocommerce.com/products/ai-shopping-assistant/)
- [Generative AI and Firm Productivity — duże field experiments](https://arxiv.org/abs/2510.12049)
- [Shopping with a Platform AI Assistant — 31 mln użytkowników](https://arxiv.org/abs/2603.24947)
- [ShoppingComp — trafność i bezpieczeństwo agentów](https://arxiv.org/abs/2511.22978)
- [AI chatbot shopping experiment](https://papers.ssrn.com/sol3/Delivery.cfm/5088975.pdf?abstractid=5088975)
- [Baymard: search UX](https://baymard.com/research/eCommerce-search)
- [Wharton 2025 AI Adoption Report — pomiar ROI](https://knowledge.wharton.upenn.edu/special-report/2025-ai-adoption-report/)

