/** Runtime checks for the public Store API contract exposed by @spree/sdk. */

import type { Client, Store, TenantId } from '@spree/sdk'

export interface ContractTestConfig {
  client: Client
  storeId: TenantId
  apiBaseUrl: string
}

function requireFields(value: object, fields: string[], subject: string): void {
  for (const field of fields) {
    if (!(field in value)) {
      throw new Error(`${subject} missing required field: ${field}`)
    }
  }
}

export async function testStoreContract(config: ContractTestConfig): Promise<Store> {
  const store = await config.client.store.get()

  requireFields(store, ['id', 'name', 'url', 'default_currency', 'default_locale'], 'Store')

  return store
}

export async function testProductsContract(config: ContractTestConfig): Promise<void> {
  const response = await config.client.products.list({ limit: 5 })

  if (!Array.isArray(response.data)) {
    throw new Error('Products response data is not an array')
  }

  requireFields(
    response.meta,
    ['page', 'pages', 'limit', 'count', 'from', 'to', 'in', 'previous', 'next'],
    'Pagination meta',
  )

  for (const product of response.data) {
    requireFields(product, ['id', 'name', 'slug'], 'Product')
  }
}

export async function testCartContract(config: ContractTestConfig): Promise<void> {
  const cart = await config.client.carts.create({})
  requireFields(cart, ['id', 'token', 'item_total', 'total', 'currency'], 'Cart')
}

export async function testErrorContract(config: ContractTestConfig): Promise<void> {
  try {
    await config.client.products.get(`contract-test-missing-${Date.now()}`)
  } catch {
    return
  }

  throw new Error('Expected a missing product request to reject')
}

export async function runAllContractTests(config: ContractTestConfig): Promise<void> {
  const tests = [
    { name: 'Store Contract', fn: () => testStoreContract(config) },
    { name: 'Products Contract', fn: () => testProductsContract(config) },
    { name: 'Cart Contract', fn: () => testCartContract(config) },
    { name: 'Error Contract', fn: () => testErrorContract(config) },
  ]

  for (const test of tests) {
    await test.fn()
    console.log(`✓ ${test.name}`)
  }
}
