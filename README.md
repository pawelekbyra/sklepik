# Sklepik — platforma uruchamiania sklepów

Backend, Store Factory i panel właściciela platformy, która pozwala tworzyć oraz prowadzić niezależne sklepy internetowe. Użytkownik może założyć konto, utworzyć sklep, zarządzać produktami i wyglądem, przejść checklistę gotowości, a następnie uruchomić sprzedaż. Pierwszy sklep z produktami kakao jest sklepem referencyjnym, nie zakresem całego produktu.

Repo zawiera Rails + REST API (fork Spree Commerce), wielosklepowość, provisioning GitHub/Vercel oraz panel React. Storefronty klientów powstają z wersjonowanego rdzenia w [`pawelekbyra/sklepikFront`](https://github.com/pawelekbyra/sklepikFront).

```text
pawelekbyra/sklepik       ← TO REPO: silnik, backend, Admin API + Store API, panel admina, SDK
pawelekbyra/sklepikFront  ← storefront Next.js: branding, UX, SEO, Vercel
```

Zasada podziału: `sklepik` jest źródłem prawdy dla commerce (produkty, ceny, koszyk, zamówienia, płatności). Storefront konsumuje Store API i nie zawiera logiki biznesowej.

## Zacznij tutaj

1. **Wizja i zasady:** [`docs/kierunek-projektu.md`](docs/kierunek-projektu.md) — kanon całego systemu.
2. **Mapa systemu i hostingu:** [`docs/architektura.md`](docs/architektura.md).
3. **Co działa, co zepsute:** [`docs/stan-projektu.md`](docs/stan-projektu.md).
4. **Co robimy dalej:** [`docs/roadmap.md`](docs/roadmap.md).
5. **Zasady dla agentów kodowania:** [`CLAUDE.md`](CLAUDE.md) (konwencje techniczne + protokół aktualizacji dokumentacji).

## Co jest w repo

| Katalog | Zawartość |
|---|---|
| `spree/core` | Silnik commerce, tenanty, dokumenty storefrontu i logika gotowości sklepu |
| `spree/api` | Store API + Admin API v3 (REST, gem Ruby) |
| `packages/dashboard` | Panel właściciela i edytor storefrontu — React SPA (Vite, TanStack) |
| `packages/dashboard-core` / `dashboard-ui` | Framework i design system panelu |
| `packages/sdk` / `admin-sdk` / `sdk-core` | Klienty TypeScript do Store/Admin API |
| `packages/cli` | CLI do zarządzania projektem (Docker) |
| `bin/render-build.sh`, `render.yaml` | Deployment backendu na Render |
| `docs/` | Dokumentacja projektu — patrz [`docs/README.md`](docs/README.md) |

## Deployment (produkcja)

| Co | Gdzie | Adres |
|---|---|---|
| Backend Rails | Oracle Cloud VPS + Postgres + Redis + Sidekiq | `141-253-103-172.nip.io` |
| Panel admina | Vercel (projekt `sklepik_back`, Root Directory `packages/dashboard`) | `sklepik-gamma.vercel.app` |
| Storefront | Vercel (projekt `sklepik_front`, repo `sklepikFront`) | `sklepikkk.vercel.app` |
| Media produktów | Cloudflare R2 (`kakaowy-sklepik-media`) | przez `CDN_HOST` |

Szczegóły: [`docs/deployment-oracle.md`](docs/deployment-oracle.md) i [`docs/architektura.md`](docs/architektura.md).

## Rozwój lokalny

Wymagania: Node 22+, pnpm, Docker (bez Ruby na hoście).

```bash
pnpm install && pnpm server:setup   # jednorazowy bootstrap (klonuje spree-starter do server/, seeduje DB)
pnpm server:dev                     # backend: http://localhost:3000

cd packages/dashboard && pnpm dev   # panel admina: http://localhost:5173 (proxy /api/* → :3000)
```

Pełen opis workflow (co przeładowuje się samo, kiedy migrować, reset): [`CLAUDE.md`](CLAUDE.md) → „Development Server".

## Pochodzenie i licencja

Silnik bazuje na forku [Spree Commerce](https://github.com/spree/spree) (BSD-3-Clause — patrz [`LICENSE`](LICENSE)). Od momentu forka repozytorium jest rozwijane jako samodzielny projekt: upstream jest fundamentem technicznym, nie wyznacza kierunku produktu.
