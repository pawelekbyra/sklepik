# Runbooki - odpowiadanie na typowe awarie operacyjne

Poradniki diagnostyczne dla wspólnych problemów w produkcji. Każdy runbook podaje przyczyny → jak diagnozować → jak naprawić.

## 1. Out of Memory (OOM) na Oracle Cloud VPS

**Objawy:** Aplikacja się zawiesza, pojawia się komunikat "Killed" w logach, procesy Puma/Sidekiq są zabijane przez kernel.

**Możliwe przyczyny:**
- Wyciek pamięci w Rails app (np. akumulacja w cache)
- Nieoptymalne zapytanie N+1 na dużym zbiorze danych (np. list 100k produktów bez paginacji)
- Sidekiq worker przetwarzający dużą pracę bez chunking'u
- Dump Redis czy cache bez limitu

**Jak diagnozować:**
1. Sprawdź Recent Logs na Oracle Cloud Console → VM Instance → Instance Details → Logs
2. Szukaj "Out of memory" lub lini podobne do `[  6844.123456] Process killed`
3. Sprawdź timing - czy OOM się dzieje co godzinę (cron job?) czy losowo (traffic spike?)
4. SSH na VPS i sprawdź: `free -m`, `top -o %MEM`, `ps aux | grep ruby`
5. Sprawdzź jeśli jest spike w API traffic w tym czasie (slow requests, timeouts)

**Jak naprawić:**
1. **Short term:** Restart aplikacji: `cd ~/sklepik && docker-compose restart web`
2. **Medium term:** 
   - Sprawdzić oprogramowanie Rails: `bundle exec rails db:sessions:trim` (czyści stare sessions)
   - Dodać `preload` / `includes` do N+1 queryów
   - Chunking w Sidekiq: `batch.each_slice(100) { |batch| process(batch) }`
3. **Long term:** Upgrade VPS do większej pamięci (current: 8GB) jeśli problem się powtarza mniej niż co 48 godzin

**Monitoring:** Skonfigurować alert na Oracle Cloud Monitoring gdy RAM usage > 85% przez 5 min

---

## 2. 500 Internal Server Error na liście zasobów (np. /admin/products)

**Objawy:** Lista zasobów nie ładuje się, pokazuje błąd 500, ale pojedyncze zasoby się ładują OK.

**Możliwe przyczyny:**
- Błędne Ransack zapytanie (filtering/sorting) z invalid kolumny
- Nowy field w serializer bez setup w modelu (nil reference)
- Bubble error w preload chain: `includes(:variants => :prices)` gdzie `Variant` nie ma `prices`
- Regression w CanCanCan scope: accessible_by wraca unpredictable results

**Jak diagnozować:**
1. Sprawdzić backend logs: `cd ~/sklepik && docker-compose logs web | tail -100 | grep -A 5 "500\|ERROR"`
2. Szukać stacktrace w logach
3. Odtworzyć request cURL: `curl "http://localhost:3000/api/v3/admin/products" -H "Authorization: Bearer $TOKEN"`
4. Sprawdzić query params - czy jest `filter[name]=something` czy `sort=-invalid_field`?
5. SSH na backend i test w rails console: 
   ```ruby
   Spree::Product.for_store(store).accessible_by(admin_user.ability, :show)
   ```

**Jak naprawić:**
1. Jeśli to ransack filter: sprawdzić CLAUDE.md sekcja `whitelisted_ransackable_attributes` w modelu
2. Jeśli to N+1: dodać `preload`/`includes` w controller
3. Jeśli to CanCanCan: test `current_ability.can?(:show, resource)` dla każdego typu zasobu
4. Revert ostatni commit jeśli to regression: `git log --oneline -10`, `git revert <commit>`
5. Deploy fix: `git push origin <branch>` → czekaj na GitHub Actions green → Vercel auto-deploys

**Prevention:** Zawsze test CRUD na edge-case zasobów (np. pierwszy/ostatni) przed merge

---

## 3. Payment capture zwraca błąd ale order jest zaznaczony jako zapłacony

**Objawy:** Sprzedawca naciska "Capture Payment", widzi błąd (timeout, 500), ale order status zmienia się na `paid`. Klient jest zarachowany dwukrotnie.

**Możliwe przyczyny:**
- Payment gateway (Stripe) zwraca timeout ale faktycznie przetwarza (race condition)
- Webhook od Stripe przychodzi asynchronicznie i zmienia status zanim UI pokazuje błąd
- Exception w payment controller bez proper transaction rollback
- Sidekiq job retry'uje capture ale retry'ujesz też ręcznie

**Jak diagnozować:**
1. Sprawdzić Stripe Dashboard: szukaj duplicate authorizations dla tej kwoty w tym samym czasie
2. Sprawdzić backend logs: szukaj payment gateway timeout wokół timestampa orderu
3. SSH i sprawdzić: `Order.find_by(number: 'ORD-123').payments.map { |p| [p.state, p.response_code] }`
4. Sprawdzić jeśli webhook delivery było retried: Spree Admin → Webhooks → Recent Deliveries
5. Sprawdzić Sidekiq job queue czy jest pending capture job

**Jak naprawić:**
1. **Immediate:** Sprawdzić u Stripe czy klient był faktycznie zarachowany 1x czy 2x
   - Jeśli 2x: request refund manual w Stripe Dashboard (lub przez API)
2. **For order:** Update order Payment state ręcznie jeśli potrzebne
   ```ruby
   Order.find(id).payments.last.update(state: :completed, response_code: stripe_charge_id)
   ```
3. **Long term:** Dodać idempotency_key do capture request w payment gateway (Stripe wspiera)
4. Test scenario: "Stripe timeout during capture" w integration tests

**Prevention:** Monitoring dla duplicate payments (alert jeśli dwa payments do tego samego orderu w 10 sekund)

---

## 4. Storefront pokazuje pusty katalog mimo że produkty są w admin

**Objawy:** Admin pokazuje 6 produktów, ale storefront katalog jest pusty. Żaden błąd nie ma. Produkty się nie ładują.

**Możliwe przyczyny:**
- `SPREE_API_URL` lub `SPREE_PUBLISHABLE_KEY` nie są ustawione na Vercel (najczęstsza!)
- `isSpreeConfigured()` zwraca false po cichu (nie ma błędu w konsoli)
- Produkty nie mają `product_publications` (niewidoczne na Store API)
- API key jest revoked lub ma zbyt wąskie scope'y
- CORS policy blocks request (origin mismatch)

**Jak diagnozować:**
1. **FIRST:** Sprawdzić Vercel dashboard: Settings → Environment Variables
   - Czy `SPREE_API_URL` jest ustawione? (powinno wskazywać na Oracle backend)
   - Czy `SPREE_PUBLISHABLE_KEY` istnieje i ma wartość?
2. Otwórz storefront, prawym przyciskiem → Inspect → Console
   - Sprawdź czy są jakieś błędy network (red zaznaczenia)
   - Wpisz: `console.log(window.SPREE_API_URL)` — czy zwraca URL czy undefined?
3. SSH na backend i sprawdzić Products:
   ```ruby
   Store.first.products.count  # czy są produkty?
   Spree::ProductPublication.count  # czy są publikacje?
   ```
4. Testuj API bezpośrednio: `curl "https://backend.io/api/v3/store/products" -H "X-Spree-API-Key: pk_..."`

**Jak naprawić:**
1. Jeśli `SPREE_API_URL` missing: Dodaj do Vercel Settings → Environment Variables (np. `https://141.253.103.172`)
2. Jeśli `SPREE_PUBLISHABLE_KEY` missing: Retrieve z admin lub generate nowy w Admin API
3. Jeśli produkty bez publikacji: Bulk-create publikacje:
   ```ruby
   store = Spree::Store.first
   store.products.find_each do |p|
     Spree::ProductPublication.find_or_create_by!(product: p, channel: store.default_channel)
   end
   ```
4. Redeploy storefront: `git push` → czekaj Vercel build
5. Czyszczenie cache: Vercel → Deployments → Redeploy (bez zmiany kodu)

**Prevention:** 
- Dodaj health-check: `/api/healthz` na backend (wygeneruj listing count)
- Storefront: dodaj fallback banner "Shop unavailable, try again later" jeśli API timeout > 5 sec
- Dokumentacja: dodaj checklist przy deployu (patrz `docs/admin-access.md`)

---

## 5. Webhook endpoint disability loop — jeden endpoint nieustannie robi retry

**Objawy:** Webhook endpoint status = `disabled`, reason = "Too many failures", ale retry'uje się sam i nigdy się nie resetuje.

**Możliwe przyczyny:**
- Webhook endpoint URL jest offline (storefront down, domain expired)
- Webhook payload structure się zmieniła ale handler jest stary
- Storefront endpoint `/api/webhooks/spree` zwraca 500 (bug w handlerze)
- Spike webhook deliveries zatrzaskuje queue (retry'uje zamiast drop)

**Jak diagnozować:**
1. Spree Admin → Webhooks → Endpoints → [endpoint name] → Recent Deliveries
2. Sprawdzić ostatnią dostarczony webhook: "Response code" = ?
   - 200-299: success, ale może be stare dane jeśli endpoint zmienił się
   - 404/403: endpoint nie istnieje lub auth failed
   - 500: endpoint zwraca server error (bug)
   - timeout/connection refused: endpoint offline
3. SSH na backend: `cd ~/sklepik && docker-compose logs sidekiq | tail -50 | grep webhook`
4. Testuj endpoint cURL:
   ```bash
   curl -X POST "https://storefront.vercel.app/api/webhooks/spree" \
     -H "X-Webhook-Secret: $SECRET" \
     -d '{"event":"product.updated","id":"prod_123"}'
   ```

**Jak naprawić:**
1. Jeśli storefront offline: czekaj aż powróci online, potem ręcznie reset endpoint:
   - Admin → Endpoints → Settings → "Enable" (zmienia disabled_reason na null, nextTry na now)
2. Jeśli handler bug: Napraw kod w `sklepikFront/src/lib/webhooks/handlers.ts`, deploy, potem enable
3. Jeśli webhook deliveries są stuck: 
   - Sprawdzić: `WebhookDelivery.where(webhook_endpoint_id: id).count`
   - Bulk-retry failed: `WebhookDelivery.where(response_code: nil).limit(10).each(&:redeliver!)`
4. Rotacja secret: Admin → Endpoint → Settings → "Rotate Secret" (jeśli secret compromise)

**Prevention:**
- Monitoring: alert jeśli endpoint status = disabled przez > 1 godzinę
- Runbook dla devops: "Webhook endpoint down - here's where to check"

---

## 6. Rate limit (429) na auth/login, users nie mogą się zalogować

**Objawy:** Login returns 429 "Too many requests" nawet dla pierwszej próby; brute force attack albo misconfigured limit

**Możliwe przyczyny:**
- Brute force attack z jednego IP (bot spamuje login attempts)
- Rate limit jest zbyt wąski (5 attempts/hour zamiast 15)
- Load balancer/proxy sprawia że wszystkie requests mają ten sam IP (fix X-Forwarded-For)
- Autentykacja mobilna próbuje login'a zamiast token refresh (drain quota)

**Jak diagnozować:**
1. Sprawdzić ostatnie 100 POST /auth/login:
   ```ruby
   Rails.cache.read("rack_attack:store/auth/login/ip:1.2.3.4") # czy counter jest wysoki?
   ```
2. Sprawdzić IP address: `request.remote_ip` czy jest jedno IP czy różne
3. Sprawdzić logs: szukać pattern wzoru login attempts
4. Jeśli to attak: Sprawdzić jaki user/email był targetowany

**Jak naprawić:**
1. Jeśli attak: 
   - Tymczasowo wyłącz rate limit: skomentuj throttle w `spree/api/config/initializers/rack_attack.rb`
   - Deploy hotfix bez rate limiting
   - Dodaj IP do whitelist (jeśli to legit użytkownik)
2. Jeśli limit zbyt wąski: Zmień w initializer z `limit: 5` na `limit: 10`
3. Jeśli proxy issue: Sprawdzić `X-Forwarded-For` header w request
4. Reset throttle dla IP: `Rails.cache.delete("rack_attack:store/auth/login/ip:1.2.3.4")`

**Prevention:**
- Monitoring: alert na 429 responses > 10 w 5 minut
- Whitelist trusted IPs (office, CI/CD agents) jeśli znane

---

## Ogólne procedury troubleshootingu

1. **Logi** — zawsze zacznij tu:
   ```bash
   cd ~/sklepik
   docker-compose logs web -f           # realtime
   docker-compose logs web --tail 100   # ostatnie 100 linii
   grep "ERROR\|500" <(logs)                           # filter errors
   ```

2. **Rails console** — test w runtime:
   ```bash
   docker-compose exec web rails c
   Order.last(5).map { |o| [o.number, o.state, o.created_at] }
   ```

3. **Database snapshot** — jeśli musisz restore:
   ```bash
   pg_dump postgres://... > backup.sql
   # po naprawie:
   psql postgres://... < backup.sql
   ```

4. **Webhook testing** — replay failed delivery:
   - Admin UI: Webhooks → Deliveries → [failed] → "Redeliver"
   - CLI: `WebhookDelivery.find(id).redeliver!`

5. **Cache reset** — jeśli stale data:
   ```ruby
   Rails.cache.clear
   # lub konkretny key:
   Rails.cache.delete("spree:store:#{store_id}:products")
   ```
