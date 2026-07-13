# Osobne konta klientów per sklep (per-store customer accounts)

**Status:** Draft — projekt, nierozpoczęty. Wymaga decyzji o kolejności względem Etapu 0 `store-factory.md`.
**Target:** `sklepik` (gem `spree/core` + `spree/api`) **oraz** host-app `server/` (Devise `Spree::User`, poza tym repo)
**Depends on:** [`store-factory.md`](store-factory.md) — Etap 0 (izolacja tenantów) jako prerekwizyt; [`multi-store-support.md`](multi-store-support.md) — Faza 1 (role/store w Admin API)
**Author:** właściciel + agent (sesja 2026-07-13)
**Last updated:** 2026-07-13

## Summary

Decyzja właściciela (2026-07-13): docelowo klient ma mieć **osobne konto w każdym sklepie** — ten sam adres e-mail zarejestrowany w sklepie A i w sklepie B to **dwa różne, niezależne konta** (osobne hasło, osobny profil, osobna historia). To silniejsza izolacja niż dzisiejszy model silnika i naturalnie pasuje do celu „niezależny sklep / możliwość przekazania sklepu klientowi" ze `store-factory.md`.

**To NIE jest część Etapu 0** i nie jest szybką poprawką. Etap 0 (`store-factory.md`) zapewnia „zero przecieków danych między sklepami" na **istniejącym** modelu tożsamości i jest prerekwizytem tej zmiany. Ten dokument opisuje osobny, większy krok: przebudowę modelu tożsamości klienta z globalnej na per-sklep.

## Stan obecny (zweryfikowany w kodzie 2026-07-13)

- **Użytkownik jest globalny — świadomie.** `Spree::User.for_store` jest nadpisane, żeby zwracać `self` (no-op) — `spree/core/app/models/concerns/spree/user_methods.rb:190`, z komentarzem „we cannot use for_store on users because it will return admin users". `custom_fields_controller.rb:62` i `customers/base_controller.rb:21` powtarzają: „Users are intentionally global in Spree".
- **Ale dane klienta są już per-sklep.** `Order belongs_to :store` (`order.rb:168`), `Store has_many :orders` (`store.rb:73`); zamówienia, `store_credits`, raporty filtrowane przez `for_store(store)`. Klient loguje się jednym e-mailem, ale w sklepie A widzi tylko dane sklepu A. Model to dziś: **wspólna tożsamość, osobne dane**.
- **Unikalność e-maila jest globalna.** `spree/core/app/models/spree/legacy_user.rb:14`: `validates :email, presence: true, uniqueness: { case_sensitive: false }` — bez `scope: :store_id`.
- **Auth klienta częściowo poza tym repo.** W produkcji `Spree.user_class` to `Spree::User` (Devise) z host-app `server/` (klon `spree-starter`, `.gitignored`, klonowany na świeżo przy deployu). Devise `:validatable` dokłada własną globalną walidację unikalności e-maila. `LegacyUser` w gemie to tylko default dev/test.
- **Login/rejestracja szukają usera globalnie po e-mailu.** `Store::AuthController` (`spree/api/app/controllers/spree/api/v3/store/auth_controller.rb`) woła strategię z `user_class: Spree.user_class`; `email_password_strategy` znajduje usera po e-mailu bez kontekstu sklepu. Rejestracja: `customers_controller.rb:14` → `Spree.user_class.new(...)`.
- **JWT/refresh token wiążą się z userem globalnie.** `Spree::RefreshToken.user`, `generate_jwt(user)` — bez store scope.

## Key Decisions (do not deviate without discussion)

1. **Tożsamość klienta jest per-sklep; tożsamość admina zostaje globalna.** `AdminUser`/`RoleUser` (panel wielosklepowy, F25) opierają się na globalnym userze z rolami per-store — tego **nie** ruszamy. Zmiana dotyczy wyłącznie kont *klientów* (storefront), nie operatorów panelu. To dlatego `User.for_store` musiało zwracać `self` — „inaczej zwróci adminów"; rozdzielenie tych dwóch ścieżek jest warunkiem tej zmiany.
2. **Klucz izolacji to `store_id` na koncie klienta.** Unikalność e-maila staje się `scope: store_id` (para `[email, store_id]` unikalna), nie globalna.
3. **Login jest rozwiązywany w kontekście sklepu.** Strategia auth dostaje `current_store` i szuka usera po `email` **w obrębie** tego sklepu. Storefront rozwiązuje sklep po hoście (wymaga naprawy `FindDefault` z Etapu 0 — stąd twarda zależność).
4. **Zmiana obejmuje host-app `server/`.** Devise `Spree::User` (unikalność e-maila, lookup przy loginie/resetach/potwierdzeniach) żyje w `server/`, nie w tym repo. Część tej pracy musi trafić do host-app i być trwała mimo efemerycznego klonowania (override w inicjalizatorze/modelu host-appa, nie ręczna zmiana na serwerze — patrz uwaga produkcyjna z `CLAUDE.md`).
5. **Migracja istniejących kont jest jawnym krokiem, nie efektem ubocznym.** Dziś istnieją globalne konta. Przy wdrożeniu każde istniejące konto musi zostać przypisane do sklepu (dla jednego dzisiejszego sklepu — trywialnie do niego; przy wielu — decyzja per konto). Dane transformujemy rake taskiem, nigdy w migracji (`CLAUDE.md`).

## Design Details

### Model danych (`spree/core`)

1. **`store_id` na tabeli userów klientów.** Migracja idempotentna (`add_column ... if_not_exists`, `CLAUDE.md`), `null: false` docelowo (po migracji danych; wdrożenie dwufazowe: dodaj nullable → backfill rake → set null:false). Bez FK (`CLAUDE.md`). Alternatywa do rozważenia: join table `spree_store_users` (user↔store) zamiast kolumny — ale to zmienia „jeden user = jeden sklep" w „jeden user = wiele sklepów", co jest sprzeczne z decyzją „osobne konta". Kolumna `store_id` jest zgodna z decyzją; join table odrzucona.
2. **Unikalność e-maila `scope: :store_id`.** Na gemowym `LegacyUser` (dev/test) **i** — przez override — na host-app `Spree::User` (Devise). DB index `unique [email, store_id]` zamiast `unique [email]`.
3. **`Spree::User.for_store` przestaje być no-opem dla klientów.** Rozdzielić: konta klientów scope'ują się po `store_id`; `AdminUser` (globalny, z rolami per-store) zachowuje dotychczasowe zachowanie. Prawdopodobnie osobna ścieżka/klasa, nie wspólne nadpisanie — do rozstrzygnięcia w projekcie szczegółowym (ryzyko: `AdminUser` i `Customer` współdzielą tabelę `spree_users`).

### Auth (`spree/api` + host-app)

4. **Strategia auth dostaje kontekst sklepu.** `email_password_strategy` (i `base_strategy`) przyjmują `store:` i robią lookup `user_class.where(store: store).find_by(email:)` zamiast globalnego. `Store::AuthController#authentication_strategy` przekazuje `current_store`.
5. **Rejestracja tworzy usera w kontekście sklepu.** `customers_controller#create`: `Spree.user_class.new(permitted_params.merge(store: current_store))`.
6. **Reset hasła / potwierdzenia (Devise, host-app) scope'owane po sklepie.** `password_resets_controller` + Devise mailers w `server/` — lookup po `[email, store_id]`. **Ta część jest w host-app, nie w tym repo.**
7. **JWT/refresh token** — user jest już jednoznaczny (konto należy do jednego sklepu), więc token nie wymaga osobnego store claim; ale walidacja przy użyciu powinna sprawdzać zgodność `user.store` z `current_store` (obrona w głąb).

### Migracja danych

8. **Rake task backfill:** każde istniejące konto klienta → przypisz `store_id` (dla jednego dzisiejszego sklepu: wszystkie do niego). Zamówienia mają już `store_id` — spójność weryfikowalna (`order.user.store_id == order.store_id`).
9. **Konflikt e-maili przy backfillu:** przy jednym sklepie brak konfliktów. Scenariusz wielosklepowy nie występuje przed tą zmianą (dziś jeden sklep), więc backfill jest bezpieczny — ale rake task musi to asertować, nie zakładać.

## Migration Path

**Prerekwizyt: Etap 0 z `store-factory.md`** (naprawa `FindDefault` — storefront rozpoznaje sklep po hoście; bez tego login store-aware nie ma jak rozwiązać „który sklep"). Musi być zamknięty pierwszy.

1. **Model + migracja (gem):** `store_id` nullable na userach klientów, DB index `[email, store_id]`, rozdzielenie `for_store` klient vs admin. Bez zmiany zachowania (kolumna pusta = zachowanie jak dziś).
2. **Backfill (rake):** przypisz istniejące konta do dzisiejszego sklepu, zweryfikuj spójność z `order.store_id`, ustaw `null: false`.
3. **Auth store-aware (gem + api):** strategia i rejestracja z kontekstem sklepu; unikalność e-maila `scope: store_id` na `LegacyUser`.
4. **Host-app (`server/`, wymaga SSH/dostępu do repo host-appa):** override Devise `Spree::User` — unikalność e-maila per store, lookup per store przy loginie/resetach. Trwałe w kodzie host-appa, nie ręcznie na serwerze.
5. **Testy dwóch tenantów:** ten sam e-mail rejestruje się niezależnie w sklepie A i B; login w A nie daje dostępu do konta w B; reset hasła nie przecieka między sklepami.

## Constraints on Current Work

- **Nie zaczynać tej zmiany przed zamknięciem Etapu 0** (`store-factory.md`) — login store-aware zależy od naprawionego `FindDefault`.
- Dopóki ta zmiana nie jest wdrożona, **nie zakładać w nowym kodzie, że e-mail klienta jest globalnie unikalny ani globalnie wspólny** — to się zmienia.
- Część pracy (Devise `Spree::User`) jest w host-app `server/`, poza tym repo — planować to jako zmianę w kodzie host-appa (trwałą), nie ręczną modyfikację na produkcji.

## Open Questions

- `AdminUser` i `Customer` współdzielą tabelę `spree_users` — jak rozdzielić scope per-store dla klientów, nie łamiąc globalnych adminów z rolami per-store (F25)? Osobna klasa? Kolumna typu? Warunkowa walidacja? Do rozstrzygnięcia w projekcie szczegółowym.
- Gdzie dokładnie żyje host-app `Spree::User` w `server/` i jak wygląda tam konfiguracja Devise — wymaga wglądu w `server/` (SSH / repo spree-starter), niedostępne z tego repo.
- Czy klient ma widzieć „masz już konto w innym sklepie tej platformy" (cross-store hint przy rejestracji), czy sklepy są dla klienta całkowicie nieświadome siebie nawzajem (pełna izolacja white-label)? Wpływa na UX rejestracji.
- Reset hasła: jeden e-mail w dwóch sklepach → dwa osobne linki resetu; jak zaadresować, żeby klient nie zresetował złego konta.

## References

- [`store-factory.md`](store-factory.md) — Etap 0 (izolacja tenantów) jako prerekwizyt.
- [`multi-store-support.md`](multi-store-support.md) — Faza 1, globalny admin z rolami per-store (którego ta zmiana świadomie nie rusza).
- `spree/core/app/models/concerns/spree/user_methods.rb:190`, `spree/core/app/models/spree/legacy_user.rb:14`, `spree/api/app/controllers/spree/api/v3/store/auth_controller.rb` — obecny, globalny model tożsamości.
