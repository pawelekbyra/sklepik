# Zgodność fiskalna PL (VAT/KSeF/kasa fiskalna) jako główna przewaga różnicująca

**Status:** Draft — ustalenia strategiczne gotowe, projekt techniczny nierozpoczęty.
**Target:** `sklepik` (backend), docelowo osobny moduł/silnik, nie doklejony hack.
**Depends on:** brak formalnej zależności, ale determinuje priorytety reszty roadmapy.
**Author:** właściciel + agent (sesja 2026-07-17, po dwóch research-passach nad krajobrazem konkurencyjnym)
**Last updated:** 2026-07-17

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

Nierozpoczęte technicznie. Do zaprojektowania:
- Model danych faktury/paragonu zgodny z wymogami KSeF (struktura FA(3)/FA(2), numeracja, korekty).
- Integracja z API KSeF (wysyłka, odbiór UPO — Urzędowe Poświadczenie Odbioru).
- Integracja z kasą fiskalną (jaki standard — online/offline, jaki producent/protokół; do zbadania).
- Przeliczanie VAT wg kursu NBP w PLN niezależnie od waluty zamówienia — czy to rozszerza istniejący `Spree::Nbp::EurPlnRate` (już w kodzie, patrz `stan-projektu.md`), czy wymaga nowego serwisu.
- Czy to żyje jako rozszerzenie `spree_core`, czy jako osobny, wymienny moduł/gem — do decyzji w duchu punktu 3 Key Decisions.

## Migration Path

Nierozpisane — to wymaga osobnej sesji projektowej, nie doklejenia do obecnej roadmapy. Pierwszy krok: dogłębny research techniczny wymagań KSeF (API, certyfikacja, terminy obowiązkowego wdrożenia) i wymagań integracji kas fiskalnych — zanim zacznie się projektować model danych.

## Constraints on Current Work

- Nie kontynuować inwestycji w personalizację/page builder ponad "wystarczająco dobre" (design tokens, warianty, custom code z `storefront-composition-system.md`) kosztem zgodności fiskalnej — to już nie jest priorytet różnicujący.
- Każda nowa praca nad modelem zamówienia/płatności w `sklepik` powinna mieć z tyłu głowy przyszłe wymogi faktury/KSeF (numeracja, korekty, PLN wg NBP), żeby nie trzeba było tego retrofitować.

## Open Questions

- **Rewizja `kierunek-projektu.md`:** zasada "core ma być betonem, domyślnie rozszerzamy Spree, modyfikacja tylko gdy naprawdę uzasadniona" (Key Decision 3 wyżej) częściowo koliduje z dotychczasową filozofią tamtego dokumentu. Wymaga świadomej decyzji właściciela: czy to zmiana generalnej zasady, czy wyjątek konkretnie dla modułu fiskalnego.
- **Czy Spree/Rails to nadal najlepszy fundament** pod cel "najlepsze możliwe praktyki, gotowość do przepisywania tam gdzie nie pasuje" — w trakcie badania (research-pass 2026-07-17, wyniki do wpisania po zakończeniu).
- Techniczne wymogi KSeF (kształt API, certyfikacja, harmonogram obowiązkowego wdrożenia) — nieobadane, priorytet na następną sesję.
- Standard integracji kas fiskalnych (online/offline, protokół) — nieobadane.
- Czy moduł fiskalny powinien być wymienny/pluginowy (na wypadek ekspansji poza Polskę) czy hardkodowany pod PL na start — nierozstrzygnięte, nie blokuje pierwszego kroku.

## References

- `docs/plans/storefront-composition-system.md` — sekcja "Zweryfikowane względem branży" (2026-07-17), skąd pochodzi to ustalenie.
- `docs/kierunek-projektu.md` — kanon celu projektu, wymaga rewizji pozycjonowania (patrz Open Questions).
- Research-pass 2026-07-17 "AI-native commerce landscape" — potwierdza, że konkurowanie globalnie z Shopify nie ma sensu strategicznego (checkout AI już przegrał na rynku, fosy dystrybucji/zaufania/regulacji nie do dogonienia).
- Research-pass 2026-07-17 "Structural gaps incumbents leave open" — źródło ustaleń VAT/KSeF wyżej.
