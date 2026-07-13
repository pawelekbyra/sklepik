/**
 * @sklepik/test-contracts
 *
 * Tenant isolation and API contract verification for Store Factory.
 * Used in Etap 2+ to verify that independent storefronts don't leak data between stores.
 *
 * Gate: must pass all tests before promoting to production.
 */

export * from './contract'
export * from './isolation'
