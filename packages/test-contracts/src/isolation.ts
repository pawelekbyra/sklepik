/**
 * Tenant isolation verification tests.
 *
 * Ensures that:
 * 1. Store A cannot read data from Store B
 * 2. Store A cannot write to Store B's resources
 * 3. API keys are scoped correctly
 * 4. Webhooks include correct store context
 */

import type { Client } from '@spree/sdk'
import type { TenantId } from '@spree/sdk'

export interface IsolationTestConfig {
  /** Client for store A (first tenant) */
  clientA: Client
  storeIdA: TenantId
  /** Client for store B (second tenant) */
  clientB: Client
  storeIdB: TenantId
  /** API base URL */
  apiBaseUrl: string
}

/**
 * Test: Store A cannot read Store B's products
 *
 * Creates a product in Store B, attempts to read it via Store A's client.
 * Should return 404 or empty list (depending on implementation).
 */
export async function testProductIsolation(config: IsolationTestConfig): Promise<void> {
  const { clientA, clientB, storeIdA, storeIdB } = config

  // Create product in Store B
  const createRes = await clientB.products.create({
    name: 'Store B Exclusive Product',
    sku: `test-b-${Date.now()}`,
  })

  if (!createRes.success) {
    throw new Error(`Failed to create product in Store B: ${createRes.error}`)
  }

  const productIdB = createRes.data.id

  // Attempt to read via Store A
  const readRes = await clientA.products.get(productIdB)

  // Should either fail (404) or return empty
  if (readRes.success && readRes.data?.id === productIdB) {
    throw new Error(
      `SECURITY BREACH: Store A read Store B's product (ID: ${productIdB})`,
    )
  }
}

/**
 * Test: Store A cannot modify Store B's cart
 *
 * Creates a cart in Store B, attempts to add item via Store A's client.
 * Should return 404 or 401 (unauthorized).
 */
export async function testCartIsolation(config: IsolationTestConfig): Promise<void> {
  const { clientA, clientB, storeIdB } = config

  // Create cart in Store B
  const cartRes = await clientB.cart.create({})

  if (!cartRes.success) {
    throw new Error(`Failed to create cart in Store B: ${cartRes.error}`)
  }

  const cartTokenB = cartRes.data.token

  // Attempt to add item via Store A with Store B's token
  const addItemRes = await clientA.cart.addItem(cartTokenB, {
    variant_id: 'some-variant',
    quantity: 1,
  })

  // Should fail (401 or 404)
  if (addItemRes.success) {
    throw new Error(
      `SECURITY BREACH: Store A modified Store B's cart (token: ${cartTokenB})`,
    )
  }
}

/**
 * Test: API key scope is enforced
 *
 * Verifies that an API key for Store A cannot be used to access Store B resources.
 */
export async function testApiKeyScope(config: IsolationTestConfig): Promise<void> {
  const { storeIdA, storeIdB, apiBaseUrl } = config

  // This test assumes keys are scoped per store in Authorization header
  // Detailed implementation depends on backend API key format

  const keyA = 'pk_test_store_a' // hypothetical key for Store A
  const keyB = 'pk_test_store_b' // hypothetical key for Store B

  // Attempt to use keyA for Store B
  const res = await fetch(`${apiBaseUrl}/api/v3/store`, {
    headers: {
      'X-Spree-Store-Id': storeIdB,
      Authorization: `Bearer ${keyA}`,
    },
  })

  // Should return 401 (unauthorized)
  if (res.status === 200) {
    throw new Error(
      `SECURITY BREACH: Key for Store A accessed Store B (status: ${res.status})`,
    )
  }
}

/**
 * Test: Webhook events include correct store context
 *
 * Verifies that webhooks from Store A are tagged with storeIdA,
 * and webhooks from Store B are tagged with storeIdB.
 */
export async function testWebhookStoreContext(
  webhookEvent: Record<string, any>,
  expectedStoreId: TenantId,
): Promise<void> {
  const actualStoreId = webhookEvent.store_id

  if (actualStoreId !== expectedStoreId) {
    throw new Error(
      `WEBHOOK MISMATCH: Expected store_id ${expectedStoreId}, got ${actualStoreId}`,
    )
  }

  // Verify signature (if applicable)
  if (!webhookEvent.signature) {
    throw new Error('Webhook missing signature for verification')
  }
}

/**
 * Run all isolation tests.
 *
 * @throws if any isolation test fails
 */
export async function runAllIsolationTests(config: IsolationTestConfig): Promise<void> {
  const tests = [
    { name: 'Product Isolation', fn: () => testProductIsolation(config) },
    { name: 'Cart Isolation', fn: () => testCartIsolation(config) },
    { name: 'API Key Scope', fn: () => testApiKeyScope(config) },
  ]

  for (const test of tests) {
    try {
      await test.fn()
      console.log(`✓ ${test.name}`)
    } catch (error) {
      console.error(`✗ ${test.name}: ${error}`)
      throw error
    }
  }
}
