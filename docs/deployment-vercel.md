# Vercel Deployment Configuration

This document describes how to deploy the Kakałowy Sklepik frontend and admin dashboard to Vercel.

## Overview

- **Admin Dashboard** (`packages/dashboard`): React SPA deployed to Vercel, proxies API requests to Oracle backend
- **Storefront** (`sklepikFront` repo): Next.js frontend deployed to Vercel, consumes Store API v3

Both require environment variables pointing to the Oracle backend running at `http://141.253.103.172`.

---

## Admin Dashboard (`packages/dashboard`) on Vercel

### Environment Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `VITE_API_URL` | Oracle backend hostname | Admin API endpoint (e.g., `https://sklepik-api.example.com` or `http://141.253.103.172`) |
| `VITE_API_TOKEN_KEY` | Local storage | JWT token storage key (default: `admin-token`) |

### Build Configuration

Vercel auto-detects this as a Vite app. No special configuration needed.

```
Framework: Other
Build Command: cd packages/dashboard && npm run build
Output Directory: packages/dashboard/dist
```

### Deployment Steps

1. **Create Vercel Project**
   - Import from GitHub: `pawelekbyra/sklepik`
   - Select root directory (monorepo root)
   - Set build command above

2. **Set Environment Variables** (Settings → Environment Variables)
   ```
   VITE_API_URL = http://141.253.103.172  (or your domain)
   ```

3. **Deploy**
   - Push to `main` branch triggers automatic deployment
   - Access at: `https://sklepik-dashboard.vercel.app`

---

## Storefront (`sklepikFront`) on Vercel

### Environment Variables

| Variable | Type | Purpose | Example |
|----------|------|---------|---------|
| `SPREE_API_URL` | Secret | Spree Store API backend URL (server-side only) | `http://141.253.103.172` |
| `SPREE_PUBLISHABLE_KEY` | Var | Public API key for Store API | `pk_...` |
| `SPREE_ADMIN_SECRET_KEY` | Secret | Admin API key for cron jobs (scoped to read_products, write_products) | `sk_...` |
| `CRON_SECRET` | Secret | Shared secret for Vercel Cron authentication | Random string |
| `NEXT_PUBLIC_DEFAULT_COUNTRY` | Var | ISO country code for redirects | `pl` |
| `NEXT_PUBLIC_DEFAULT_LOCALE` | Var | Default locale (2-letter code) | `pl` |
| `NEXT_PUBLIC_SITE_URL` | Var | Canonical storefront URL | `https://sklepik.example.com` |
| `NEXT_PUBLIC_STORE_NAME` | Var | Store display name | `Kakałowy Sklepik` |
| `NEXT_PUBLIC_STORE_DESCRIPTION` | Var | Store meta description | `Sklep z produktami kakao` |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Var | Stripe public key (if using Stripe) | `pk_test_...` |
| `RESEND_API_KEY` | Secret | Resend API key for transactional emails | (if emailing enabled) |
| `EMAIL_FROM` | Var | From address for emails | `orders@sklepik.example.com` |
| `SENTRY_DSN` | Var | Sentry error tracking (optional) | `https://...@sentry.io/...` |
| `REVALIDATE_SECRET` | Secret | Secret for manual cache revalidation | Random string |

### Getting API Keys from Oracle Backend

Before setting environment variables, retrieve credentials from the running Oracle backend:

```bash
# SSH into Oracle VPS
ssh -i ~/.ssh/oracle_key ubuntu@141.253.103.172

# Generate publishable key for Store API
cd ~/sklepik/server
pnpm exec spree keys:generate --key_type=publishable_key

# Generate admin secret key (scoped to read_products, write_products)
pnpm exec spree keys:generate --key_type=admin_secret_key --scopes=read_products,write_products

# Store these securely (they won't be shown again)
```

### Build Configuration

Vercel auto-detects Next.js 16.

```
Framework: Next.js 16
Build Command: npm run build
Output Directory: .next
Install Command: npm ci
```

### Deployment Steps

1. **Create Vercel Project**
   - Import from GitHub: `pawelekbyra/sklepikFront`
   - Root directory: `.` (repo root)
   - Use defaults for Next.js

2. **Set Environment Variables** (Settings → Environment Variables)

   **Build & Production:**
   ```
   SPREE_API_URL = http://141.253.103.172
   SPREE_PUBLISHABLE_KEY = pk_...
   SPREE_ADMIN_SECRET_KEY = sk_...
   CRON_SECRET = <random-32-char-string>
   NEXT_PUBLIC_DEFAULT_COUNTRY = pl
   NEXT_PUBLIC_DEFAULT_LOCALE = pl
   NEXT_PUBLIC_SITE_URL = https://sklepik.example.com
   NEXT_PUBLIC_STORE_NAME = Kakałowy Sklepik
   NEXT_PUBLIC_STORE_DESCRIPTION = Sklep z produktami kakao
   ```

   **Optional (email):**
   ```
   RESEND_API_KEY = re_...
   EMAIL_FROM = orders@sklepik.example.com
   ```

3. **Deploy**
   - Push to `main` triggers deployment
   - Access at: `https://sklepik.vercel.app`

### Cron Job Configuration

The storefront includes a scheduled job `/api/cron/sync-eur-prices` that runs daily at 3 AM UTC.

To enable it in Vercel:
1. Go to Settings → Crons
2. Verify the endpoint is listed: `/api/cron/sync-eur-prices`
3. Schedule is set in `vercel.json`: `0 3 * * *`

The cron job uses `SPREE_ADMIN_SECRET_KEY` and `CRON_SECRET` for authentication.

---

## Updating Production Environment Variables

When backend secrets rotate or URLs change:

1. **Admin Dashboard**
   - Settings → Environment Variables → Edit `VITE_API_URL`
   - Redeploy (or automatic via webhook)

2. **Storefront**
   - Settings → Environment Variables → Update affected keys
   - Redeploy (or automatic via webhook)

---

## Custom Domain Setup

To use custom domains instead of `*.vercel.app`:

1. **Admin Dashboard**: `admin.sklepik.example.com` (or dashboard.sklepik.example.com)
   - Settings → Domains → Add
   - Configure DNS CNAME to `cname.vercel-dns.com`

2. **Storefront**: `sklepik.example.com` (or www.sklepik.example.com)
   - Settings → Domains → Add
   - Configure DNS CNAME to `cname.vercel-dns.com`

---

## Troubleshooting

### Build fails: "Cannot find module '@spree/sdk'"

The storefront imports `@spree/sdk` but it's in the main sklepik repo. Vercel doesn't have access to sibling repos.

**Solution:** npm link or publish `@spree/sdk` to npm public registry, then update `package.json` to use the published version.

### Storefront can't reach backend API

Check:
1. `SPREE_API_URL` is set to reachable Oracle hostname (e.g., `http://141.253.103.172`)
2. Oracle backend is running and healthy: `curl http://141.253.103.172/up`
3. No CORS issues (Spree backend should allow storefront origin in config)

### Cron job not running

1. Verify `vercel.json` has `"crons"` block
2. Check Vercel Settings → Crons — should show `/api/cron/sync-eur-prices`
3. Verify `CRON_SECRET` environment variable is set
4. Check logs in Vercel Dashboard → Function Logs

---

## See Also

- [Oracle Deployment](./deployment-oracle.md) — Backend infrastructure
- [Architecture](./architektura.md) — System diagram
- [CLAUDE.md](../CLAUDE.md) — Development guidelines
