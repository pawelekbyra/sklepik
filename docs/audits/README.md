# Program audytu fundamentu Sklepika

**Start programu:** 2026-07-14
**Audytowany baseline backend/admin:** `9a4f693147`
**Audytowany baseline storefront:** `0f83b94`
**Zasada:** audyt dokumentuje stan i dowody. Naprawy kodu powstają później jako osobne, priorytetyzowane zadania.

## Definicja znaleziska

Każde znalezisko ma stabilny identyfikator, priorytet `P0`–`P3`, dowód w kodzie/runtime, wpływ, rekomendację, kryterium zamknięcia i status weryfikacji. Raport musi rozróżniać:

- **fakt** — bezpośrednio potwierdzony kodem, testem, bazą lub produkcją;
- **inferencję** — mocny wniosek z dowodów, jeszcze bez testu runtime;
- **nieweryfikowane** — wymaga danych, sekretu, konta albo kontrolowanego testu;
- **nie dotyczy** — świadomie poza zakresem danego raportu.

Priorytety:

- **P0:** realne ryzyko utraty pieniędzy/danych, cross-tenant leak, przejęcie konta lub niedostępność krytycznej ścieżki;
- **P1:** blokuje bezpieczną sprzedaż albo powoduje poważny błąd operacyjny;
- **P2:** istotny dług, niezawodność, utrzymanie lub UX bez natychmiastowego zagrożenia;
- **P3:** usprawnienie, porządek lub przyszłościowa optymalizacja.

## Rejestr audytów

| Nr | Audyt | Fala | Status | Raport |
|---:|---|---:|---|---|
| 01 | Inwentaryzacja 100% repozytoriów | 1 | zakończony | `2026-07-14-01-inwentaryzacja-100-procent.md` |
| 02 | Architektura i granice systemu | 1 | zakończony | `2026-07-14-02-architektura-i-granice.md` |
| 03 | Uniezależnienie od Spree | 1 | zakończony | `2026-07-14-03-uniezaleznienie-od-spree.md` |
| 04 | Izolacja sklepów | 2 | zakończony | `2026-07-14-04-izolacja-sklepow.md` |
| 05 | Uwierzytelnianie i uprawnienia | 2 | zakończony | `2026-07-14-05-auth-i-uprawnienia.md` |
| 06 | Bezpieczeństwo aplikacji | 2 | zakończony | `2026-07-14-06-bezpieczenstwo-aplikacji.md` |
| 07 | Pieniądze i checkout | 2 | zakończony | `2026-07-14-07-pieniadze-i-checkout.md` |
| 08 | Zamówienia, zwroty i reklamacje | 2 | zakończony | `2026-07-14-08-zamowienia-zwroty-reklamacje.md` |
| 09 | Baza danych i migracje | 3 | zakończony | `2026-07-14-09-baza-i-migracje.md` |
| 10 | Backup i disaster recovery | 3 | zakończony | `2026-07-14-10-backup-i-disaster-recovery.md` |
| 11 | Joby, webhooki i e-maile | 3 | zakończony | `2026-07-14-11-joby-webhooki-email.md` |
| 12 | Infrastruktura i deployment | 3 | zakończony | `2026-07-14-12-infrastruktura-i-deployment.md` |
| 13 | API, SDK i kompatybilność | 4 | zakończony | `2026-07-14-13-api-sdk-kompatybilnosc.md` |
| 14 | Panel, edytor i onboarding | 4 | zakończony | `2026-07-14-14-panel-edytor-onboarding.md` |
| 15 | Storefront i jakość sprzedaży | 4 | zakończony | `2026-07-14-15-storefront-jakosc-sprzedazy.md` |

Raport końcowy: `2026-07-14-00-stan-fundamentu-sklepika.md`.
Weryfikacja przekrojowa: `2026-07-14-16-weryfikacja-przekrojowa.md`.

## Testy przekrojowe

Po raportach obszarowych program obejmuje pełne suite obu repo, E2E wielu tenantów, testy kontraktowe, property/fuzz, mutation, obciążenie, chaos, skan zależności/licencji, prawdziwy restore backupu oraz testy przeglądarkowe desktop/mobile. Brak dostępnego narzędzia lub danych jest wynikiem audytu i musi być zapisany, nie zastępowany założeniem.

## Warunek zakończenia

Program jest zakończony dopiero wtedy, gdy:

1. każdy tracked plik należy do sklasyfikowanego modułu;
2. wszystkie 15 raportów ma jawny zakres i ograniczenia;
3. findings są zdeduplikowane w raporcie nadrzędnym;
4. każde P0/P1 ma właściciela, kolejność i test zamykający;
5. roadmapa i `stan-projektu.md` odzwierciedlają zweryfikowany stan;
6. nie twierdzimy „zero bugów” — raportujemy pokrycie i pozostałe ryzyko.
