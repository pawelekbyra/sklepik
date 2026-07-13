/** Runtime tenant-isolation checks for two already-provisioned test stores. */

import type { Client, TenantId } from '@spree/sdk'

export interface IsolationTestConfig {
  clientA: Client
  storeIdA: TenantId
  publishableKeyA: string
  clientB: Client
  storeIdB: TenantId
  /** Existing product visible only in store B. */
  productIdB: string
  /** Existing variant assigned only to store B, used for the cross-tenant cart write. */
  variantIdB: string
  apiBaseUrl: string
}

async function expectRejected(operation: () => Promise<unknown>, breach: string): Promise<void> {
  try {
    await operation()
  } catch {
    return
  }

  throw new Error(`SECURITY BREACH: ${breach}`)
}

export async function testProductIsolation(config: IsolationTestConfig): Promise<void> {
  await config.clientB.products.get(config.productIdB)
  await expectRejected(
    () => config.clientA.products.get(config.productIdB),
    `Store A read Store B's product (ID: ${config.productIdB})`,
  )
}

export async function testCartIsolation(config: IsolationTestConfig): Promise<void> {
  const cartB = await config.clientB.carts.create({})

  await expectRejected(
    () =>
      config.clientA.carts.items.create(cartB.id, {
        variant_id: config.variantIdB,
        quantity: 1,
      }),
    `Store A modified Store B's cart (ID: ${cartB.id})`,
  )
}

export async function testApiKeyScope(config: IsolationTestConfig): Promise<void> {
  const response = await fetch(`${config.apiBaseUrl.replace(/\/$/, '')}/api/v3/store`, {
    headers: {
      'X-Spree-Api-Key': config.publishableKeyA,
      'X-Spree-Store-Id': config.storeIdB,
    },
  })

  if (response.ok) {
    throw new Error(`SECURITY BREACH: Store A key selected Store B (status: ${response.status})`)
  }
}

export async function testWebhookStoreContext(
  webhookEvent: Record<string, unknown>,
  expectedStoreId: TenantId,
): Promise<void> {
  if (webhookEvent.store_id !== expectedStoreId) {
    throw new Error(
      `WEBHOOK MISMATCH: Expected store_id ${expectedStoreId}, got ${String(webhookEvent.store_id)}`,
    )
  }

  if (!webhookEvent.signature) {
    throw new Error('Webhook missing signature for verification')
  }
}

export async function runAllIsolationTests(config: IsolationTestConfig): Promise<void> {
  const tests = [
    { name: 'Product Isolation', fn: () => testProductIsolation(config) },
    { name: 'Cart Isolation', fn: () => testCartIsolation(config) },
    { name: 'API Key Scope', fn: () => testApiKeyScope(config) },
  ]

  for (const test of tests) {
    await test.fn()
    console.log(`✓ ${test.name}`)
  }
}
