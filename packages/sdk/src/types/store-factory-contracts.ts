/**
 * Store Factory Contract Types
 *
 * Defines the contract between backend and frontend for multi-tenant Store Factory model.
 * Used by Etap 1 (stable SDK contract) through Etap 4 (full provisioning + AI).
 *
 * See docs/plans/store-factory.md for architecture and usage.
 */

/**
 * Unique identifier for a store/tenant in Store Factory model.
 * Format: "shop_" prefix + 16 random chars, e.g. "shop_abc123def456"
 * Backend generates this on Store#create.
 */
export type TenantId = string & { readonly __tenantId: unique symbol }

/**
 * API key scoped to a single store (tenant).
 * Different from Admin API key which has broader permissions.
 * Format: "pk_" prefix (publishable, safe to embed in frontend) or "sk_" (secret, server-only).
 */
export interface ApiKey {
  /** Public key, safe to embed in frontend */
  publishable: string
  /** Secret key, server-only (never expose to frontend or client-side code) */
  secret?: string
  /** Scopes this key is authorized for (e.g., "read_products", "write_cart") */
  scopes: ApiKeyScope[]
  /** Tenant this key belongs to */
  store_id: TenantId
  /** When created */
  created_at: string
  /** When it expires (optional) */
  expires_at?: string
}

export type ApiKeyScope =
  | 'read_products'
  | 'read_store'
  | 'write_cart'
  | 'read_customer'
  | 'write_customer'
  | 'read_orders'
  | 'write_orders'

/**
 * Tenant/Store context for a storefront.
 * Single-tenant storefront (Etap 2): one context per deployment.
 * Multi-tenant storefront (future): selected per request/session.
 */
export interface StoreContext {
  /** Unique identifier of the store/tenant */
  id: TenantId
  /** Human-readable store name (e.g., "Kakao Ceremonialne") */
  name: string
  /** Domain this store is served on (e.g., "kakao-ceremonialne.pl") */
  domain: string
  /** ISO country code for default market (e.g., "PL") */
  default_country_iso: string
  /** Default locale for this store (e.g., "pl") */
  default_locale: string
  /** Currency code for this store (e.g., "PLN") */
  currency: string
  /** API key for accessing this store's data */
  api_key: ApiKey
}

/**
 * Multi-store storefront context.
 * Used when single Next.js deployment serves multiple stores (possible in Etap 3+).
 * Complementary to StoreContext (which assumes single store per deployment).
 */
export interface MultiStoreContext {
  /** Map of tenant ID to its store context */
  stores: Record<TenantId, StoreContext>
  /** Currently active store (resolved from request URL/header) */
  current_store_id: TenantId
}

/**
 * Result of tenant isolation verification.
 * Used by test-contracts to ensure data doesn't leak between stores.
 */
export interface TenantIsolationVerification {
  /** Tenant that made the request */
  requesting_store_id: TenantId
  /** Resource being accessed */
  resource_type: string
  resource_id: string
  /** Owner of this resource (which store created it) */
  owner_store_id: TenantId
  /** Was access allowed? (true = same store, false = different store, access denied) */
  access_allowed: boolean
  /** If denied, explanation */
  reason?: string
}

/**
 * Webhook event from Store Factory backend.
 * Every webhook event includes tenant context for proper routing in multi-store scenario.
 */
export interface WebhookEvent {
  /** Event type (e.g., "product.updated", "order.placed") */
  type: string
  /** Which store/tenant this event came from */
  store_id: TenantId
  /** Timestamp (ISO 8601) */
  timestamp: string
  /** Event-specific data (e.g., product details for product.updated) */
  data: Record<string, any>
  /** Signature for verification (HMAC) */
  signature: string
}

/**
 * Store Factory application manifest.
 * Versioned in each independent storefront repo; used by provisioning orchestrator
 * to validate compatibility between app code and backend.
 */
export interface StoreFactoryManifest {
  /** Unique store identifier (e.g., "shop_abc123") */
  store_id: TenantId
  /** Runtime version (e.g., "next.js:14.1.0") */
  runtime: string
  /** API contract version this app requires (e.g., "1.0.0") */
  api_contract_version: string
  /** Capabilities this store exposes (e.g., ["checkout", "wishlist", "subscriptions"]) */
  capabilities: string[]
  /** Routes this store defines (e.g., ["/", "/products", "/checkout"]) */
  routes: string[]
  /** Health check endpoint */
  health_check_endpoint: string
  /** Release channel (e.g., "stable", "canary") */
  release_channel: 'stable' | 'canary' | 'staging'
}
