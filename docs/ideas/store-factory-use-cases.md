# Store Factory — praktyczne scenariusze użycia

**Status:** Idea, oparty na doświadczeniu Etapu 0 (wdrożony 2026-07-13) i dyskusji biznesowej.
**Autor:** agent (sesja 2026-07-13)
**Last updated:** 2026-07-13

## Teza

Store Factory nie jest "maszyną do pieniędzy". Jest **narzędziem do taniego eksperymentowania na skalę**. Jego prawdziwa wartość to:

> *Mogę przetestować 40 nisz/rynków/narracji za koszt, za jaki konkurent testuje jedną — i te, które trafią, skalować, a resztę wyrzucić bez żalu.*

To przewaga eksperymentatora, nie skali.

---

## Realnie działające scenariusze

### 1. Segmentacja produktu po intencji kupującego (nie geografii)

**Setup:**
```
sklep-kakao-ceremonialne.pl     (wellness, duchowość, premium)
sklep-kakao-piekarskie.pl       (kulinaria, przepisy, bulk, ceny)
sklep-kakao-sportowe.pl         (superfood, energia, makro, suplementacja)
```

**Co się dzieje:**
- Ten sam produkt (kakao z Peru), trzy zupełnie różne doświadczenia sklepowe.
- Każdy sklep rank'uje na swoich słowach kluczowych ("kakao ceremonialne" vs "kakao do pieczenia").
- A/B testing całej narracji marki, nie tylko guzika.
- Strona konwertuje inną intencję → inny messaging działa.

**Realistyczne przychody:**
- Sklep "ceremonialny": 50-100 zamówień/miesiąc, $100/zam = $5-10k/mo
- Sklep "piekarski": 200-300 zamówień/miesiąc, $30/zam = $6-9k/mo
- Sklep "sportowy": 100-150 zamówień/miesiąc, $50/zam = $5-7.5k/mo
- **Razem: $16-26.5k/mo z jednego produktu / trzech sklepów**

**Koszt eksperymentu:** 30 minut per sklep. W Shopify: cena tej zabawy to $29/mo × 3 = $87/mo, plus ręczny setup (1-2h). U Ciebie: `provision --name kakao-ceremonialne --country pl` → done.

**Gdzie jest realna fosa:** Nie technologia (każdy może to replikować). Fosa to redakcyjna — trzeba napisać rzeczywiście inny landing, inny blog per sklep. To robota, ale tanią do przetestowania.

---

### 2. Sklepy kampanijne / sezonowe (Black Friday, limitowane edycje)

**Setup:**
```
bf-2026.kakao-sklep.pl          (Black Friday, 3 tygodnie, własny pixel)
limited-edition-peru.kakao.pl   (nowa edycja sezonu, 1 miesiąc)
xmas-gift-boxes.kakao.pl        (święta, bundle'i, gift wrapping)
```

**Co się dzieje:**
- Spin-up pełnoprawnego sklepu w 5 minut pod konkretny event.
- Dedykowany tracking (Pixel, GA, UTM) — widzisz dokładnie co konwertuje.
- Po kampanii: sklep się archiwizuje, baza danych sklepu zostaje (history), ale infrastruktura się wyłącza (zero kosztów).
- **Szybka iteracja:** jeśli kampania nie idzie, możesz ją przerwać/zmienić bez bólu (w Shopify płacisz i tak).

**Realistyczne przychody:**
- Black Friday (3 tygodnie): $50k (skupienie ruchu)
- Limited edition (1 miesiąc): $15k (exclusivity premium)
- Święta (6 tygodni): $80k (gift season)

**Koszt eksperymentu:** $0 (oprócz hostingu backend, który dzieli koszty ze 100 sklepów). Shopify: 3 × $29/mo = $87/mo **wciąż działa** nawet jeśli kampania padnie.

**Gdzie jest realna fosa:** Kreatywność marketingu (copy, visual, offer). Technologia umożliwia, ale nie robi za Ciebie.

---

### 3. Creator / Influencer storefronts (white-label reselling)

**Setup:**
```
Influencer A (wellness coaching) → sklep.influencer-a.com (na Twojej infrastrukturze)
  - jego branding, jego narracja
  - Ty obsługujesz fulfillment (wysyła kakao z magazynu)
  - on bierze 40%, Ty 50%, platform fee 10%

Influencer B (nutrition coaching) → sklep.influencer-b.com
  - podobnie jak A
```

**Co się dzieje:**
- Influencer nie musi wiedzieć o e-commerce (Ty obsługujesz tech, platforma, support).
- Inflencer robi co umie: marketing + community building.
- Ty dostajesz % bez rywalizacji (ich ruch = Twój przychód).
- **Skalowanie bez pracy:** każdy kolejny influencer = +$5-20k/mo w Twoim revenue, prawie żadna praca.

**Realistyczne przychody na 10 influencerów:**
- Avg $10k/mo per influencer × 10 = $100k/mo
- Twoja marża: 50-60% (platform fee + fulfillment margin) = $50-60k/mo czyste

**Koszt eksperymentu:** 2-3 dni pracy per influencer (setup, customize branding). Potem: automatyczne.

**Gdzie jest realna fosa:** Relacje — musisz znaleźć influencerów z *realnym* komunitecie (nie 500k fake followers). Technologia tu nie pomoże.

---

### 4. Testy geograficzne (przed pełną ekspansją)

**Setup:**
```
Test: cacao.mx (Meksyk, testowanie product-market fit)
Test: cacao.br (Brazylia, testowanie pricing)
Test: cacao.co (Kolumbia, lokalne konkurencja)
```

**Co się dzieje:**
- Lecimy 3 sklepy "alpha" w 3 rynkach.
- Każdy sklep ma natywne copywriting, natywne payment gateways, natywną logistykę.
- Po 3 miesiącach: widzisz, czy rynek trzyma, czy nie.
- Jeśli tak: skaluj ten rynek (multiple sklepów per segment, influencer collaborations).
- Jeśli nie: zamknij, zero strat (poza nauki).

**Realistyczne przychody (jeśli trafia):**
- Meksyk: $20-50k/mo (ponad 100M ludzi, segment wellness rosnący)
- Brazylia: $50-100k/mo (rynek zdecydowanie większy)
- Kolumbia: $10-20k/mo (mniejszy, ale direct sourcing blisko)

**Koszt eksperymentu:** Praktycznie zero (struktura rozciągnięta już przez istniejące sklepy). W Shopify: $87/mo × 3 + lokalizacja = $250+/mo + 2-3 tygodnie pracy na local SEO.

**Gdzie jest realna fosa:** Supply chain — czy potrafisz wysłać kakao tanio do Meksyku bez ceł? To operacyjne wyzwanie, nie tech.

---

### 5. Dane cross-store jako dźwignia biznesowa

**Co się dzieje (po ~20 sklepach):**
- Widzisz: "Segment wellness konwertuje 30% lepiej przy pricing -10%, ale tylko w DE i AT."
- Widzisz: "Copywriting 'superfood energy' trzyma bounce rate o 15% niżej niż 'organic cacao'."
- Widzisz: "Sklepów kategorii 'gift' konwertują 2× lepiej w listopadzie."

**Ta wiedza to Twoja fosa.** Żaden indie merchant na Shopify jej nie ma — każdy widzi swoje siedem sklepów. Ty widzisz mapę całego krajobrazu.

**Konkretnie:**
- Każdy nowy sklep startujesz ze strategią opartą na 20 poprzednich.
- Marketing budget rozdzielasz bardziej inteligentnie (widzisz, gdzie conversion rate wyższa).
- Produkty tanujesz różnie per rynek (nie jeden catalog globalny).

**Realistyczne wzmocnienie:** 20-40% wyższa średnia konwersja vs eksperyment tradycyjny.

---

## Co NIE będzie działać (i dlaczego poprzednia odpowiedź Cię oszukała)

### "50 prawie-identycznych sklepów to SEO multiply" 

❌ **FAŁSZ.** Google aktywnie karze doorway pages / thin content. To działa dopiero, gdy każdy sklep ma **naprawdę inną, natywną treść** — a to redakcyjna robota per sklep. Fabryka daje Ci szablon w 30 sekund; unikalny, nieprzetłumaczony maszynowo blog to wciąż $500-1000 pracy per sklep.

### "500 sklepów = $250k/mo passive income"

❌ **FAŁSZ.** 90% roboty to marketing/support/operacje. Fabryka rozwiązuje tanie 10% (setup). Każdy sklep to jednostka operacyjna: VAT per kraj, support tickets, zwroty, regulacje lokalne. 500 sklepów to 500× koszty compliance (UE ma różne progi VAT per kraj), zamiast skalowania w górę.

### "Sama technologia tworzenia sklepów to fosa"

❌ **FAŁSZ.** Technologia jest replikowalna — dobry senior zrobi to w 3 tygodnie. Prawdziwa fosa to: (a) supply chain (skąd produkty, po jakiej cenie), (b) obsługa operacyjna (fulfillment, support), (c) **dane cross-store** (co faktycznie konwertuje).

---

## Praktyczne wskazówki — co działać będzie

1. **Zaczynaj od 5-10 sklepów, nie 500.** Test intencji kupującego / geografii / narracją. Mierz metryki per sklep (AOV, LTV, ROAS). Po 3 miesiącach: skale to, co trzyma.

2. **Buduj treść, nie polegaj na SEO.** Dla każdego sklepu / segmentu: blog, guide, user-generated content. To Cię odróżni od "doorway pages".

3. **Leverage data, nie skalę.** Prawdziwa wartość to wiedza "segment X konwertuje w kraju Y przy pricing Z". Ta wiedza inwestujesz wstecz w nowe sklepy.

4. **Partnershiopy > własna skala.** Influencer storefronts (10 influencerów z prawdziwym komiunitkiem = lepiej niż 100 sklepów, które Ty markelinujesz sam).

5. **Operacje — to nie skaluje się magicznie.** Każdy rynek to nowe payment gateways, VAT rules, logistics. Automation powinno być priority (ale to osobna praca).

---

## Podsumowanie

Store Factory jest potężne, ale jako **narzędzie do eksperymentowania** — nie do "drukowania pieniędzy". Wartość: mogę tanio testować — ci, którzy mogą tanio testować 40 razy, znajdą zwycięzców, których ostrożny konkurent nigdy nie odkryje.

Reszta (zysk, skalę) budujesz tradycyjnie: obsługa operacyjna, marketing, partnershtory. Ale co najmniej — infrastruktura za Tobą nie stoi.
