# Pomysł do rozważenia: automatyczny provisioning wielu sklepów

**Status:** ZASTĄPIONY decyzją — patrz [`docs/plans/store-factory.md`](../plans/store-factory.md) (2026-07-13). Ten dokument zostaje jako historyczny szkic, z którego wywodzi się decyzja; rekomendacja "wspólne repo storefrontu, osobny projekt Vercel per sklep" poniżej **nie jest już aktualna** — model docelowy to osobne repozytorium **i** projekt Vercel per sklep (`store-factory.md`).
**Data zapisu:** 2026-07-12

## Kontekst

Obecna architektura już posiada fundamenty multi-store po stronie silnika i panelu: `Spree::Store`, kontekst sklepu w Admin API, routing panelu przez `/$storeId` oraz nagłówek `X-Spree-Store-Id`. Storefront działa jednak jako osobne repozytorium Next.js wdrażane na Vercel i jest obecnie konfigurowany głównie przez zmienne środowiskowe.

Pomysł polega na umożliwieniu utworzenia nowego, niezależnego sklepu z panelu jednym procesem provisioningowym, obejmującym zarówno dane commerce, jak i infrastrukturę storefrontu.

## Rekomendowany wariant początkowy

```text
Jeden backend Rails / Spree
Jeden panel administracyjny
Jedno wspólne repo storefrontu: sklepikFront
        │
        ├── osobny projekt Vercel dla sklepu A
        ├── osobny projekt Vercel dla sklepu B
        └── osobny projekt Vercel dla sklepu C
```

Każdy sklep korzystałby z tego samego kodu storefrontu, ale posiadałby własne:

- `Spree::Store`,
- produkty, zamówienia, promocje i konfigurację,
- publishable API key,
- projekt Vercel,
- zmienne środowiskowe,
- domenę lub subdomenę,
- webhook endpoint i sekret,
- konfigurację brandingu,
- status wdrożenia.

Nowe repozytorium GitHub nie byłoby tworzone domyślnie. Osobne repo miałoby sens wyłącznie dla sklepów wymagających trwałych, indywidualnych zmian w kodzie.

## Przykładowy proces „Utwórz sklep”

Formularz w panelu mógłby przyjmować m.in.:

- nazwę sklepu,
- slug,
- domenę lub subdomenę,
- domyślny język, kraj i walutę,
- wybrany szablon,
- opis marki i oczekiwany styl.

Po zatwierdzeniu system wykonywałby kolejne, idempotentne kroki:

1. Utworzenie `Spree::Store`.
2. Utworzenie domyślnego kanału i rynku.
3. Utworzenie publishable API key.
4. Przypisanie administratora i ról.
5. Wygenerowanie osobnego sekretu webhooków.
6. Utworzenie projektu Vercel przez API.
7. Podłączenie projektu do wspólnego repo `sklepikFront`.
8. Ustawienie zmiennych środowiskowych, np.:

   ```env
   SPREE_API_URL=https://api.example.com
   SPREE_PUBLISHABLE_KEY=pk_store_xxx
   NEXT_PUBLIC_SITE_URL=https://nowy-sklep.example.com
   NEXT_PUBLIC_STORE_NAME=Nowy Sklep
   NEXT_PUBLIC_DEFAULT_LOCALE=pl
   NEXT_PUBLIC_DEFAULT_COUNTRY=pl
   SPREE_WEBHOOK_SECRET=...
   ```

9. Przypisanie domeny lub wygenerowanej subdomeny.
10. Utworzenie webhook endpointu wskazującego na storefront.
11. Uruchomienie pierwszego deploymentu.
12. Test automatyczny podstawowych ścieżek: homepage, katalog, produkt, koszyk i checkout.
13. Zmiana statusu sklepu z `provisioning` na `active` albo `failed`.

Proces powinien działać w tle przez Sidekiq i być bezpieczny do ponowienia po błędzie. Ponowienie kroku nie może tworzyć drugiego sklepu, projektu Vercel ani klucza.

## Proponowany model danych

Możliwy nowy model:

```text
StoreDeployment
├── store_id
├── provider
├── github_repository
├── vercel_project_id
├── current_deployment_id
├── generated_domain
├── custom_domain
├── storefront_version
├── release_channel
├── status
├── last_error
├── configuration
└── provisioned_at
```

Przykładowe statusy:

```text
pending
creating_store
creating_project
configuring_environment
configuring_domain
deploying
awaiting_dns
verifying
active
failed
suspended
```

## Alternatywne modele

### 1. Jeden projekt Vercel obsługujący wszystkie domeny

Storefront rozpoznaje sklep po `Host` i pobiera konfigurację z backendu. Utworzenie sklepu wymaga wtedy głównie dodania rekordu sklepu i domeny, bez tworzenia nowego deploymentu.

Zalety:

- łatwe skalowanie do setek sklepów,
- jeden deployment,
- szybkie uruchamianie kolejnych tenantów.

Ryzyka:

- konieczność pełnego rozdzielenia cache, cookies i koszyków per sklep,
- jeden wadliwy deployment może wpłynąć na wszystkie sklepy,
- obecny storefront wymagałby refaktoryzacji z konfiguracji build-time/env na konfigurację dynamiczną per domena.

### 2. Osobne repo GitHub i projekt Vercel dla każdego sklepu

Nowe repo mogłoby powstawać z template repository, a następnie być automatycznie podłączane do Vercela.

Zalety:

- pełna niezależność kodu,
- możliwość przekazania repo klientowi,
- AI może mocno personalizować konkretny sklep.

Ryzyka:

- duży koszt utrzymania wielu forków,
- poprawki checkoutu i bezpieczeństwa trzeba propagować do wielu repozytoriów,
- potrzebny bot synchronizujący zmiany ze wspólnego szablonu i otwierający PR-y.

Ten wariant powinien być opcją premium, a nie domyślnym sposobem tworzenia sklepu.

## Rola AI

Provisioning infrastruktury powinien być deterministycznym workflowem, a nie swobodnym działaniem modelu AI. AI może natomiast wspierać personalizację sklepu, np.:

- generowanie propozycji nazwy i opisu marki,
- tworzenie tekstów SEO i stron informacyjnych,
- dobór tokenów kolorów i typografii,
- wybór układu sekcji homepage,
- tworzenie tłumaczeń,
- generowanie grafik i materiałów startowych,
- przygotowywanie kategorii i przykładowej struktury katalogu,
- wykonywanie wizualnego audytu po deploymencie,
- tworzenie PR-ów dla opcjonalnych zmian indywidualnych.

Preferowany kierunek: branding i konfigurację trzymać przede wszystkim jako dane w backendzie, aby nie wymagać zmian kodu dla każdej marki.

## Kwestie wymagające decyzji przed realizacją

- Czy klient może posiadać więcej niż jeden sklep?
- Czy administrator platformy widzi wszystkie sklepy?
- Czy produkty są całkowicie niezależne, czy potrzebny jest katalog centralny?
- Czy każdy sklep ma własne konto płatnicze, np. Stripe Connect?
- Czy e-maile transakcyjne wychodzą z jednego konta czy osobnych domen nadawczych?
- Jak wygląda rozliczanie kosztów Vercela, storage i e-maili per sklep?
- Jak obsługiwać aktualizacje wersji storefrontu i stopniowe rollouty?
- Jak archiwizować lub usuwać sklep bez utraty danych księgowych i historii zamówień?
- Jak mocno izolować dane tenantów i jak testować brak wycieków między sklepami?

## Wstępna rekomendacja

Na pierwszy etap rozważyć model:

```text
jeden backend + jeden panel
jedno wspólne repo storefrontu
osobny projekt Vercel na sklep
osobny klucz API, domena, webhook i konfiguracja
osobne repo tylko dla mocno niestandardowych wdrożeń
```

Rozwiązanie daje niezależność operacyjną sklepów bez natychmiastowego mnożenia repozytoriów i pozostawia drogę do późniejszego modelu SaaS lub white-label.
