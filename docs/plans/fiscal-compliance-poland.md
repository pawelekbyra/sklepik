# Zgodność fiskalna PL (VAT/KSeF/kasa fiskalna) jako główna przewaga różnicująca

**Status:** Draft — ustalenia strategiczne i techniczne gotowe (trzy rundy research-passów), implementacja nierozpoczęta.
**Target:** ZMIENIONE (2026-07-17) — nowy backend Medusa.js, nie `sklepik`/Spree. Patrz [`medusa-migration.md`](medusa-migration.md).
**Depends on:** [`medusa-migration.md`](medusa-migration.md) — moduł fiskalny budowany na nowym stosie, nie na Spree jako tymczasowym fundamencie.
**Author:** właściciel + agent (sesja 2026-07-17, po sześciu research-passach: krajobraz konkurencyjny, luki Shopify, fundament Spree/Rails, wymogi techniczne KSeF, kasa fiskalna przy pełnym mixie płatności, obiektywne porównanie Spree vs Medusa)
**Last updated:** 2026-07-17

## ⚠️ PILNE: terminy KSeF już minęły

Dziś jest **17 lipca 2026**. Harmonogram obowiązkowego KSeF (ustawa z 27.08.2025, terminy prawnie ostateczne):
- **1 lutego 2026** — obowiązek dla dużych podatników (sprzedaż brutto 2025 > 200 mln zł) — **już minęło**.
- **1 kwietnia 2026** — obowiązek dla pozostałych przedsiębiorców — **już minęło**.
- 1 stycznia 2027 — najmniejsi podatnicy (obrót ≤10 000 zł/mies.) — jedyny termin jeszcze przed nami.

**To nie jest planowanie na przyszłość — to aktywna, dziś istniejąca luka.** Każdy klient robiący sprzedaż B2B (faktura dla firmy) już dziś powinien mieć możliwość odbioru/wystawiania faktur przez KSeF. Priorytet tego planu rośnie odpowiednio.

## Summary

Sesja 2026-07-17 zadała pytanie: czy ten projekt ma sens strategiczny, skoro odtwarza to, co robi Shopify z dużo mniejszymi zasobami? Dwa niezależne research-passy dały jednoznaczną odpowiedź w dwóch częściach:

1. **"AI-native killer Shopify" / próba konkurowania globalnie — nie ma sensu.** Dystrybucja, zaufanie regulacyjne (PCI-DSS, lata dopracowywania edge case'ów podatkowych w wielu jurysdykcjach) i dane to fosy, których nie da się dogonić szybciej niż istnieją. Nawet dobrze sfinansowani gracze (Genstore, 10 mln USD seed) nie mają dowiedzionej trakcji; sama kategoria "AI prowadzi checkout" już poniosła realną porażkę rynkową (OpenAI wycofał ChatGPT Instant Checkout w marcu 2026 — ~30 aktywnych sprzedawców wobec zapowiadanego "ponad miliona"; Walmart zerwał współpracę po ~3x niższej konwersji w czacie).
2. **Ale znaleziono konkretną, udokumentowaną, obronioną niszę: zgodność z polskim reżimem podatkowym.** Shopify **strukturalnie jej nie domyka** — to nie jest kwestia priorytetu produktowego, to setki jurysdykcji, z których Polska jest jedną z wielu, więc nigdy nie będzie dla nich priorytetem.

**Decyzja właściciela (2026-07-17):** cel projektu to nie "prześcignąć Shopify globalnie", tylko zbudować platformę **dla właściciela i jego kilku-kilkunastu (potencjalnie więcej) klientów**, **według najlepszych możliwych praktyk inżynierskich**, nie półśrodków. Fork Spree jest punktem wyjścia, nie ograniczeniem — części, które nie pasują do celu, mają być przepisane, nie naginane wokół ograniczeń frameworka.

## Ustalenia badawcze — co dokładnie jest złamane u Shopify w Polsce

Z research-passu 2026-07-17 ("Research structural gaps incumbents leave open"):

- **Dokumenty generowane natywnie przez Shopify formalnie straciły status faktury VAT w krajowym obrocie B2B od 2026.**
- **Brak natywnej integracji z KSeF** (obowiązkowy krajowy system e-fakturowania) — ani numeracja, ani korekty, ani wysyłka.
- **Brak statusu paragonu fiskalnego** — jeśli sprzedaż wymaga rejestracji na kasie fiskalnej, trzeba dowiązywać zewnętrzny system.
- **Kwota VAT musi być wyrażona w PLN wg kursu NBP niezależnie od waluty zamówienia** — Shopify tego nie robi natywnie.
- Efekt: sprzedawcy dokładają zewnętrzne narzędzia (np. Fakturownia) do czegoś, co w lokalnie zbudowanym systemie może być wbudowane od początku, nie doklejone.

Źródła z tamtego research-passu: [ksiegowego.pl — Shopify a faktury VAT w Polsce](https://ksiegowego.pl/artykul/shopify-a-faktury-vat-w-polsce-jak-przygotowac-sprzedaz-zgodnie-z-przepisami), [icomSEO — integracja Shopify z księgowością](https://icomseo.pl/blog/integracja-shopify-z-ksiegowoscia-wyzwania-przy-sprzedazy-miedzynarodowej/).

Dodatkowe potwierdzone luki Shopify istotne dla małych/średnich niezależnych sprzedawców (mniej krytyczne niż VAT/KSeF, ale warte świadomości): opłaty transakcyjne przy niekorzystaniu z Shopify Payments, twarde limity customizacji Liquid bez Shopify Plus (~2000-2300 USD/mies. progu wejścia), utrata danych klientów/haseł przy migracji z platformy (vendor lock-in — hasła nie migrują, historia atrybucji nie jest eksportowalna), słabe wsparcie B2B/subskrypcji bez płatnych dodatków.

## Key Decisions (do not deviate without discussion)

1. **Cel: platforma dla właściciela + kilku-kilkunastu (rosnąco) klientów, nie globalny konkurent Shopify.** To ustala realistyczną skalę inżynierską — nie projektujemy pod setki tysięcy sklepów, projektujemy pod dziesiątki, dobrze.
2. **Zgodność fiskalna PL (VAT/KSeF/kasa fiskalna) jest główną przewagą różnicującą, nie funkcją poboczną.** Ma być zaprojektowana jako pierwszorzędny moduł domenowy, nie plugin doklejony na końcu.
3. **Najlepsze możliwe praktyki inżynierskie, nie kompromisy wokół ograniczeń Spree.** Tam, gdzie architektura/kod Spree nie pasuje dobrze do celu (np. do zgodności fiskalnej, wielosklepowości, jakości kodu), przepisujemy, nie naginamy się do konwencji upstreamu. To odwraca dotychczasową zasadę "core ma być betonem, domyślnie rozszerzamy Spree" z `kierunek-projektu.md` — wymaga świadomej rewizji tamtego dokumentu (patrz Open Questions).
4. **Personalizacja/page builder przestaje być głównym różnicownikiem.** Shopify/Webflow robią to szybciej przez wbudowane AI. Wystarczy "wystarczająco dobre", nie inwestować tam ponad potrzebę — priorytet przesuwa się na zgodność fiskalną.
5. **Zakres geograficzny zawężony świadomie do Polski/Europy Środkowej**, nie "platforma dla każdego sklepu na świecie".

## Design Details

**Kluczowa decyzja architektoniczna: warstwa abstrakcji `FiscalProvider`, nie własny klient KSeF od razu.**

- Interfejs `Spree::FiscalProvider` (nazwa robocza) w Rails — backend nie wie, czy faktura leci przez własny klient KSeF czy przez zewnętrzne API. Daje szybki start i późniejszą migrację na własną integrację bez przepisywania reszty systemu.
- **Pierwsza implementacja: integracja z Fakturownią** (darmowa integracja z KSeF na dowolnym abonamencie, gotowe API, obsługa kas fiskalnych producentów Novitus/Posnet/Elzab/iPOS, obsługa HUB-u paragonowego/e-paragonów). Szybki time-to-market, zero ryzyka regulacyjnego na start. Alternatywy tej klasy: wFirma, ifirma, inFakt.
- **❌ ODRZUCONE (2026-07-17): ograniczenie płatności B2C do przelewu/BLIK.** Właściciel wprost odrzucił to jako złe dla konwersji — platforma ma obsługiwać pełen zakres metod płatności (karta, Przelewy24, PayU, Stripe) od początku. **Potwierdzone badawczo: przy jakiejkolwiek płatności innej niż bezpośredni przelew na konto, fiskalizacja jest obowiązkowa od pierwszej transakcji** (karta/bramka płatnicza przerywa bezpośredni związek wpłaty z transakcją wymagany przez przepis o zwolnieniu — nawet BLIK rozliczany jako transakcja kartowa się nie kwalifikuje). Kasa wirtualna **prawnie odpada** dla zwykłej sprzedaży detalicznej (zamknięta lista PKWiU: transport, gastronomia, hotelarstwo, myjnie, węgiel — nie handel/rękodzieło).
- **✅ Architektura kasy fiskalnej (bez kompromisów, potwierdzona jako wzorzec używany przez IdoSell/Shoper/duże platformy PL):** fizyczna drukarka fiskalna online z natywnym REST API — **Novitus NoviAPI** jako pierwszy wybór (~2800-3000 zł netto/urządzenie, protokół REST zaprojektowany pod integracje e-commerce), Posnet Thermal HD Online jako porównanie/backup. Podłączona do dedykowanego, zawsze dostępnego mini-serwera z publicznym dostępem (musi łączyć się z Centralnym Repozytorium Kas MF). Własny mikroserwis „fiscal-service" nasłuchuje webhooków bramki płatności (Stripe/P24/PayU) i po potwierdzeniu wpłaty wystawia paragon przez NoviAPI. **E-paragon za zgodą klienta w checkout** (opt-in + e-mail, zgodnie z art. 111 ustawy o VAT i portalem e-paragony na podatki.gov.pl) zamiast/obok papierowego; bez zgody — paragon drukowany lokalnie i pakowany fizycznie do przesyłki. Mikroserwis potrzebuje kolejki z retry na wypadek offline drukarki i alarmowania — brak fiskalizacji przy przyjętej płatności to ryzyko sankcji karnoskarbowych.
- **B2B → KSeF, nie zwykła faktura PDF.** Format: struktura logiczna **FA(3)** (aktualna wersja, następczyni FA(2)), XML wg XSD publikowanego przez MF. Model danych zamówienia musi mieć od początku pola wymagane przez FA(3): NIP, dane adresowe, stawki VAT, kody GTU, jednostki miary — żeby nie przerabiać schematu bazy później.
- **Środowiska KSeF do developmentu:** MF udostępnia 3 odrębne środowiska — testowe (TE, `ksef-test.mf.gov.pl`), demo/przedprodukcyjne (TR, `ksef-demo.mf.gov.pl`, bez skutków prawnych), produkcyjne (PRD). Podłączyć środowisko testowe do CI wcześnie, żeby oswoić się z API zanim ewentualna własna integracja stanie się priorytetem.
- **Uwierzytelnianie KSeF** (potrzebne dopiero przy własnej integracji, nie przy starcie przez Fakturownię): podpis kwalifikowany XAdES albo token KSeF. UPO (Urzędowe Poświadczenie Odbioru) zawiera numer KSeF, timestamp, hash SHA-256 — pojawia się zwykle w ciągu kilku minut, ma znaczenie dowodowe. Tryb offline (offline24/awaryjny) wymaga wysyłki do 24h od przywrócenia łączności.
- Przeliczanie VAT wg kursu NBP w PLN niezależnie od waluty zamówienia — rozszerza istniejący `Spree::Nbp::EurPlnRate` (już w kodzie, patrz `stan-projektu.md`), nie wymaga nowego serwisu od zera.
- Brak oficjalnego SDK Ruby dla KSeF (gem `ksef` na RubyGems jest w wersji 0.1.0, praktycznie nieużywalny) — potwierdzone, że i tak trzeba by pisać integrację ręcznie niezależnie od wyboru frameworka backendu. To nie wpływa na wybór Rails vs alternatywy (patrz Open Questions, rozstrzygnięte).

## Migration Path

**Etap 1 (MVP, wysoki priorytet — terminy już minęły, budowane na Medusie, patrz `medusa-migration.md`):**
1. Model danych zamówienia rozszerzony o pola FA(3) (NIP, adres, VAT, GTU, jednostki miary).
2. Rozróżnienie B2B (NIP podany → faktura, docelowo przez KSeF) vs B2C (paragon/e-paragon lub faktura na żądanie).
3. **Pełen zakres metod płatności B2C od startu** (karta, P24, PayU, Stripe) — bez ograniczeń.
4. Mikroserwis „fiscal-service" + fizyczna drukarka fiskalna online (Novitus NoviAPI) — fiskalizacja każdej opłaconej transakcji, e-paragon za zgodą.
5. Interfejs `FiscalProvider` + pierwsza implementacja przez API Fakturowni (wystawianie faktury B2B/KSeF po zmianie statusu zamówienia, pobieranie UPO).
6. Środowisko testowe KSeF podłączone w CI.

**Etap 2 (odłożone, dopiero gdy skala uzasadni koszt — setki faktur/mies.):**
- Własna natywna integracja z surowym KSeF API (certyfikaty, XAdES, tryb offline) zamiast Fakturowni.
- VAT-OSS/eksport UE dla sprzedaży wielosklepowej — osobny temat, nie blokuje MVP.

## Constraints on Current Work

- Nie kontynuować inwestycji w personalizację/page builder ponad "wystarczająco dobre" (design tokens, warianty, custom code z `storefront-composition-system.md`) kosztem zgodności fiskalnej — to już nie jest priorytet różnicujący.
- Każda nowa praca nad modelem zamówienia/płatności w `sklepik` powinna mieć z tyłu głowy przyszłe wymogi faktury/KSeF (numeracja, korekty, PLN wg NBP), żeby nie trzeba było tego retrofitować.

## Open Questions

- **Rewizja `kierunek-projektu.md`:** zasada "core ma być betonem, domyślnie rozszerzamy Spree" jest teraz nieaktualna w całości, nie tylko częściowo — backend przestaje być Spree. Wymaga pełnej rewizji kanonu. Patrz `medusa-migration.md`.
- **🔄 ZMIENIONE 2026-07-17 (odwraca wcześniejszą rekomendację z tego samego dnia): pełny rewrite backendu na Medusa.js, nie pozostanie przy Spree.** Wcześniejsza rekomendacja "zostać przy Spree" była trafna dla kryterium "najszybciej dowieźć różnicującą funkcję" — ale właściciel świadomie odrzucił koszt/czas jako kryterium decyzyjne i wybrał "obiektywnie najlepszy fundament techniczny" zamiast tego. Drugi, celowo bezstronny research-pass (ignorujący sunk cost) dał w tym kryterium wynik na korzyść Medusy: czystsza architektura modułowa z rollbackiem, spójność języka z resztą stacku TS, lepsze wsparcie dla bezpiecznej pracy agentów AI. Pełne uzasadnienie i plan: [`medusa-migration.md`](medusa-migration.md). Kwestia licencji Spree Enterprise (multi-tenancy jako funkcja płatna od wersji 5.0) staje się częściowo bezprzedmiotowa przy tej decyzji, ale warto ją mieć z tyłu głowy, gdyby migracja się przeciągnęła.
- Czy moduł fiskalny powinien być wymienny/pluginowy (na wypadek ekspansji poza Polskę) czy hardkodowany pod PL na start — nierozstrzygnięte, nie blokuje pierwszego kroku. Interfejs `FiscalProvider` (patrz Design Details) częściowo już to rozwiązuje niezależnie od tej decyzji.

## References

- `docs/plans/storefront-composition-system.md` — sekcja "Zweryfikowane względem branży" (2026-07-17), skąd pochodzi to ustalenie.
- `docs/kierunek-projektu.md` — kanon celu projektu, wymaga rewizji pozycjonowania (patrz Open Questions).
- Research-pass 2026-07-17 "AI-native commerce landscape" — potwierdza, że konkurowanie globalnie z Shopify nie ma sensu strategicznego (checkout AI już przegrał na rynku, fosy dystrybucji/zaufania/regulacji nie do dogonienia).
- Research-pass 2026-07-17 "Structural gaps incumbents leave open" — źródło ustaleń VAT/KSeF wyżej.
- Research-pass 2026-07-17 "Validate Spree/Rails as best-practice foundation" — [spreecommerce.org pricing](https://spreecommerce.org/what-is-the-price-for-the-spree-enterprise-edition/), porównanie do Medusa.js/Solidus/Saleor/Vendure.
- Research-pass 2026-07-17 "Technical requirements for KSeF and fiscal integration" — [gov.pl/finanse harmonogram](https://www.gov.pl/web/finanse/obowiazkowy-ksef-odroczony-do-1-lutego-2026-r), [dokumentacja API KSeF 2.0/FA(3)](https://www.gov.pl/web/finanse/publikacja-dokumentacji-api-ksef-20-oraz-struktury-logicznej-fa3), [fakturownia.pl/integracja-z-ksef](https://fakturownia.pl/integracja-z-ksef).
- Research-pass 2026-07-17 "Research fiscal cash register requirements with card payments" — źródło architektury kasy fiskalnej wyżej ([sklepfiskalny.pl Novitus NoviAPI](https://sklepfiskalny.pl/Drukarka-fiskalna-NOVITUS-Bono-online), [gov.pl e-paragony](https://www.gov.pl/web/gov/ulatwienia-w-e-paragonach)).
- Research-pass 2026-07-17 "Unbiased Spree vs Medusa best-foundation comparison" — źródło decyzji o migracji, pełne uzasadnienie w `medusa-migration.md`.
- [`medusa-migration.md`](medusa-migration.md) — decyzja o zmianie backendu, plan migracji.
