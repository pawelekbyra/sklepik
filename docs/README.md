# Dokumentacja — sklepik

Zwięzły komplet żywych dokumentów. Zasada: aktualizujemy istniejące pliki, nie tworzymy nowych notatek-sierot. Historia jest w gicie.

| Dokument | Rola |
|---|---|
| [`kierunek-projektu.md`](kierunek-projektu.md) | **Kanon systemu** — cel, podział repo, hierarchia decyzji, zasady architektury. Obowiązuje oba repozytoria. |
| [`architektura.md`](architektura.md) | Jedyna mapa systemu: aplikacje, hosting, przepływy danych, zmienne środowiskowe. |
| [`stan-projektu.md`](stan-projektu.md) | Żywy stan: co działa, znane problemy, czego brakuje. **Aktualizowany po każdym zadaniu.** |
| [`roadmap.md`](roadmap.md) | Backlog F1–F24 (Faza 1 — fundament) + Faza 2 (Kakao MVP) + Faza 3. Statusy zadań. |
| [`deployment-oracle.md`](deployment-oracle.md) | Jak realnie działa deploy backendu na Oracle Cloud VPS — **produkcja od 2026-07-09.** |
| [`oracle-setup-guide.md`](oracle-setup-guide.md) | Krokowa instrukcja setupu VPS na Oracle Cloud (dla właściciela/nowego serwera). |
| [`deployment-render.md`](deployment-render.md) | Jak działał deploy backendu na Render — **legacy**, zachowane jako referencja. |
| [`engine-decisions.md`](engine-decisions.md) | Rejestr świadomych zmian w core silnika commerce. |
| [`admin-access.md`](admin-access.md) | Granica admin / API / storefront i gdzie loguje się administrator. |
| [`audit-playbook.md`](audit-playbook.md) | Powtarzalny proces audytu panelu (read/write symmetry, martwe endpointy, ciche błędy) + mapa pokrycia. |
| [`runbooks.md`](runbooks.md) | Diagnostyka typowych awarii produkcyjnych (OOM, 500, duplicate payment, webhook retry loop, rate limit). |
| `audits/` | Jednorazowe, datowane raporty audytowe (np. system-wide production readiness). |
| `plans/` | Szablon (`_template.md`) i własne plany architektoniczne (np. `market-language-switcher.md`). |

Dokumentacja storefrontu żyje w repo `sklepikFront` (`docs/`); generowana specyfikacja OpenAPI odtwarza się do `docs/api-reference/` przez `bundle exec rake rswag:specs:swaggerize` (nie edytować ręcznie, nie commitować bez potrzeby).
