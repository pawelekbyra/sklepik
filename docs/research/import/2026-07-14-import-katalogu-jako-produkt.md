# Import katalogu jako produkt

**Data badania:** 2026-07-14  
**Decyzja:** czy import ma być technicznym narzędziem, czy płatnym produktem uruchomieniowym Sklepika.

## Werdykt

Import powinien być jednym z pierwszych płatnych produktów Sklepika. Nie jako „wgraj CSV”, lecz jako **bezpieczna migracja katalogu zakończona gotowymi draftami i raportem braków**. Merchant płaci za odzyskane godziny, zachowanie SEO i pewność, że warianty, ceny oraz media nie zostały pomieszane.

Najlepsze MVP: Shopify CSV, WooCommerce CSV, Shoper CSV oraz uniwersalny CSV/XLSX; następnie Etsy API/CSV i Allegro API. Import z dowolnego URL i zdjęć powinien wzbogacać pojedyncze produkty, nie udawać pełnej migracji bez źródła prawdy.

Zasada bezpieczeństwa: import nigdy nie publikuje automatycznie. Tworzy wersjonowany staging, pokazuje diff, confidence i pola wymagające człowieka. Cena, waluta, VAT, SKU, warianty, zapas, prawa do mediów oraz dane GPSR są polami krytycznymi.

## Metoda i pewność

- Benchmark oficjalnych formatów/importerów Shopify, WooCommerce, Shoper i Etsy Open API; analizę Allegro ograniczono do architektury konektora, bo pola zależą od kategorii i bieżących endpointów.
- Fakty o formatach i ograniczeniach pochodzą z dokumentacji vendorów; WTP i jakość to hipotezy do pilotażu.
- Pewność: **wysoka** dla potrzeby mapowania i human review, **średnia** dla kolejności konektorów, **niska–średnia** dla ceny przed rozmowami z klientami.

## Benchmark źródeł

| Źródło | Dostęp | Mocne strony danych | Utrata / ryzyka | Priorytet |
|---|---|---|---|---|
| Shopify | CSV/API | handle, produkt/wariant, ceny, image URLs, SEO i publikacja kanałów | wiele wierszy na produkt; sortowanie CSV może zerwać relację obrazów; metafields/aplikacje wymagają API | P0 |
| WooCommerce | CSV/REST | typy, warianty, atrybuty, kategorie, media URL, upsell/cross-sell, custom meta | plugin-specific meta, HTML, brak alt text w core importerze; duże pliki i konflikty SKU | P0 |
| Shoper | CSV/API/aplikacje | produkty, kategorie/producenci i zdjęcia URL; lokalna baza potencjalnych klientów | core CSV nie obejmuje wariantów/atrybutów/promocji; dodatkowa aplikacja ma osobny format | P0 |
| Allegro | OAuth API | oferty, kategorie, parametry, zdjęcia, cena, stan, delivery; duża polska podaż | oferta marketplace ≠ pełny produkt sklepu; parametry zależne od kategorii, prawa do opisów/zdjęć, rate limits | P1 |
| Etsy | CSV/OAuth API | title, description, price, currency, quantity, tags, materials, image URLs; API inventory/variations | listing-centric; shipping/readiness/taxonomy specyficzne Etsy; warianty nested | P1 |
| uniwersalny CSV/XLSX | upload | dostępność dla hurtowni i arkuszy | nieznane nagłówki, locale decimal, encoding, multi-value cells, brak hierarchii | P0 |
| publiczny URL produktu | fetch + extraction | szybki start pojedynczego SKU, tekst i obrazy | robots/ToS/copyright, JS, niepełna cena/warianty, anty-bot; nie jest źródłem zapasu | P2 |
| zdjęcia produktu | vision + OCR | świetne dla rękodzieła bez systemu | model nie zna składu, wymiarów, ceny, safety; ryzyko wymyślenia | P1 jako enrichment |

Źródła: [Shopify product CSV](https://help.shopify.com/en/manual/products/import-export/using-csv), [Shopify import](https://help.shopify.com/en/manual/products/import-export/import-products/), [WooCommerce core importer/schema](https://woocommerce.com/document/product-csv-importer-exporter/), [Shoper CSV](https://www.shoper.pl/learn/artykul/opis-import-eksport-csv), [Shoper warianty](https://www.shoper.pl/learn/artykul/aplikacja-import-export-csv-warianty-i-atrybuty-maxsote), [Etsy listing export](https://help.etsy.com/hc/en-gb/articles/360000343508-How-to-Download-Your-Listing-Information), [Etsy API listings/inventory](https://developers.etsy.com/documentation/tutorials/listings/).

## Kanoniczny model pośredni

Konektory nie powinny pisać bezpośrednio do Spree. Najpierw tworzą neutralny `CatalogImportDocument`:

```text
ImportRun
  source, source_store, source_version, currency, locale
  raw_artifact_hash, status, totals, errors
  ProductCandidate[]
    source_id, title, slug, descriptions, vendor, brand
    seo_title, seo_description, canonical_source_url
    category_path[], tags[], attributes[]
    VariantCandidate[]: source_id, sku, options, price, compare_at,
      currency, stock, weight, barcode
    MediaCandidate[]: source_url/file, rank, alt, hash, license_assertion
    compliance: manufacturer, responsible_person, warnings, gtin
    provenance[field], confidence[field], validation[]
```

Transformacja do Spree następuje dopiero po walidacji i akceptacji. Source IDs i hash umożliwiają idempotentne wznowienie, aktualizację i rollback.

## Mapowanie krytyczne

| Domena | Reguła | Co wymaga review |
|---|---|---|
| produkt vs wariant | produkt grupuje wspólne treści; wariant ma konkretną kombinację opcji | brak unikalnego SKU, duplikaty kombinacji, „default variant” |
| ceny | przechowywać amount w minor units + jawna waluta; nie inferować VAT | separator/locale, compare-at, promocja i historia Omnibus |
| zapas | import snapshotu nie oznacza synchronizacji | source of truth i konflikt między kanałami |
| kategorie | zachować source path, proponować mapping do taksonomii Sklepika | nieznane/niejednoznaczne kategorie |
| media | pobrać, hash, sprawdzić format/wymiary, zachować kolejność i alt | prawa/licencja, uszkodzenie, watermark, duplikat |
| SEO | zachować slug, title/description i source URL; wygenerować mapę 301 | kolizje slug, stare URL-e, canonicals |
| HTML | sanitize allowlist, zachować tekst/strukturę, raportować usunięte elementy | iframe/script/styles, tabele i embeds |
| compliance | brak krytycznych danych nie może być „uzupełniony kreatywnie” | GPSR, skład, alergeny, claims, CE |

## Pipeline produktu

1. **Ingest:** upload/OAuth/URL; szyfrowany raw artifact, malware/type/size checks.
2. **Parse:** adapter źródła do modelu pośredniego; checkpointy i batching.
3. **Normalize:** UTF-8, locale, units, currency, HTML, taxonomy i option names.
4. **Media:** download z SSRF protection, content sniffing, hash/dedupe, transform.
5. **Validate:** schema, cross-row relations, unique SKU, warianty, ceny, wymagane pola.
6. **Enrich:** AI proponuje description/alt/category/SEO tylko z oznaczeniem provenance.
7. **Review:** summary, severity, table diff i bulk approval z wyjątkami.
8. **Apply:** idempotentny workflow do draftów Spree, transakcje per product/batch.
9. **Verify:** counts, totals, images, links, storefront preview i sample cart.
10. **Publish:** osobna decyzja; mapa redirectów i signed completion report.

## Test jakości

### Złoty zestaw

Minimum 20 fixture catalogs per connector:

- simple, variable, missing SKU, duplicated SKU, 0 price, sale price;
- polskie znaki, HTML, emoji, przecinki/średniki i przecinek dziesiętny;
- 1/20 images, dead link, redirect, CMYK, WebP/AVIF, duplicate hash;
- category tree, custom attributes, variants with missing combinations;
- 1k/10k rows, interrupted job, retry, same import twice;
- malicious CSV formula, script HTML, internal URL/SSRF and oversized image.

### Metryki i progi MVP

| Metryka | Próg |
|---|---:|
| krytyczne pola zgodne z source (SKU, price, currency, option combination) | 100% w accepted set |
| produkty/varianty zachowane | ≥99,5%; reszta jawnie errored, nigdy silent drop |
| media poprawnie pobrane i przypisane | ≥98%, brak pomylonej kolejności |
| idempotency | 0 duplikatów po ponownym run |
| automatycznie zaakceptowane pola niekrytyczne | ≥80% |
| czas operatora | <60 s/SKU dla trudnych, <15 s/SKU mediany |
| rollback | 100% zmian import run odwracalne przed publikacją |

## Human review i UX

Nie pokazywać użytkownikowi 50 kolumn naraz. Najpierw wynik:

- `92 gotowe`, `6 wymaga decyzji`, `2 zablokowane`;
- grupowanie problemów: warianty, ceny, obrazy, SEO, legal;
- porównanie source → wynik z miniaturą i linkiem;
- bulk accept tylko dla jednorodnej reguły;
- „dlaczego AI tak uważa” = źródło pola i confidence, nie narracja modelu;
- publikacja dopiero po podpisaniu oświadczenia o prawach do treści/mediów.

## WTP i opakowanie

Hipotezy do testu:

| Oferta | Cena testowa netto | Dla kogo |
|---|---:|---|
| self-service do 50 SKU | 99–199 zł jednorazowo | Etsy/rękodzieło |
| assisted do 500 SKU | 499–1 499 zł | działający mały sklep |
| migracja + SEO redirects + QA | 1 999–5 999 zł | przejście z innej platformy |
| continuous connector | 99–499 zł/mies. + wolumen | Allegro/hurtownia jako source |

Nie wyceniać wyłącznie per SKU: 10 configurable products może być trudniejsze niż 1 000 prostych. Cena = źródło × złożoność × liczba wariantów/mediów + poziom review.

## MVP

P0: uniwersalny mapper CSV z preview, Shopify/Woo/Shoper presets, staging, validation, media jobs, review, apply/rollback i completion report. Bez synchronizacji zamówień i dwukierunkowej edycji.

P1: Etsy/Allegro OAuth, redirects, delta update, saved mappings. P2: public URL/vision enrichment, continuous sync i agency bulk runs.

## Eksperymenty 14/30/90 dni

### 14 dni

- zebrać anonimowe eksporty od 3 Shopify/Woo/Shoper/Etsy merchantów;
- concierge-import 100 SKU i ręcznie oznaczyć ground truth;
- fake-door z trzema cenami i deklaracją źródła;
- zaprojektować model pośredni, provenance i severity taxonomy.

### 30 dni

- P0 dla 4 formatów; golden fixtures w CI;
- 5 płatnych importów, pomiar minut/SKU i błędów;
- SEO URL diff + 301 export oraz media dedupe;
- security test upload/fetch i retry po przerwaniu.

### 90 dni

- 20 migracji, minimum 5 pełnych publikacji;
- porównać self-service i assisted pod kątem marży/supportu;
- P1 Etsy albo Allegro według popytu;
- podjąć decyzję o continuous sync dopiero, gdy ≥30% klientów go kupi.

## Główne ryzyka

- nieuprawnione kopiowanie danych i zdjęć;
- „silent success” z utraconymi wariantami;
- błędne ceny/stock prowadzące do umów, których merchant nie zrealizuje;
- SSRF/malware/CSV injection i wyciek tokenów OAuth;
- zależność od zmiennych API/platform ToS;
- błędne 301 niszczące ruch organiczny.

Produkt jest gotowy do sprzedaży dopiero, gdy raport wyjaśnia każdą utratę i import można bezpiecznie wznowić lub cofnąć.

