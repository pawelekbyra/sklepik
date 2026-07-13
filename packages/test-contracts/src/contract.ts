/**
 * API Contract verification tests.
 *
 * Ensures that:
 * 1. Response types match contract (Product, Cart, Order, etc.)
 * 2. Required fields are present
 * 3. Error responses have expected shape
 * 4. Pagination works as documented
 */

import type { Client, Store, Product, Cart, Order } from '@spree/sdk'
import type { TenantId } from '@spree/sdk'

export interface ContractTestConfig {
  client: Client
  storeId: TenantId
  apiBaseUrl: string
}

/**
 * Test: Store endpoint returns valid Store object
 *
 * Verifies that GET /api/v3/store returns a Store with required fields.
 */
export async function testStoreContract(config: ContractTestConfig): Promise<Store> {
  const { client } = config

  const res = await client.store.get()

  if (!res.success) {
    throw new Error(`Store endpoint failed: ${res.error}`)
  }

  const store = res.data

  // Verify required Store fields
  const required = ['id', 'type', 'attributes']
  for (const field of required) {
    if (!(field in store)) {
      throw new Error(`Store missing required field: ${field}`)
    }
  }

  // Verify attributes (per OpenAPI spec)
  const attrs = store.attributes as Record<string, any>
  const requiredAttrs = ['name', 'url', 'mail_from_address']
  for (const attr of requiredAttrs) {
    if (!(attr in attrs)) {
      throw new Error(`Store.attributes missing required field: ${attr}`)
    }
  }

  return store
}

/**
 * Test: Products endpoint returns paginated response
 *
 * Verifies that GET /api/v3/store/products returns products with pagination metadata.
 */
export async function testProductsContract(config: ContractTestConfig): Promise<void> {
  const { client } = config

  const res = await client.products.list({ per_page: 5 })

  if (!res.success) {
    throw new Error(`Products endpoint failed: ${res.error}`)
  }

  // Verify response shape
  if (!Array.isArray(res.data)) {
    throw new Error('Products response is not an array')
  }

  // Verify pagination metadata (if present)
  const meta = (res as any).meta
  if (meta) {
    const requiredMeta = ['page', 'pages', 'per_page', 'total']
    for (const field of requiredMeta) {
      if (!(field in meta)) {
        throw new Error(`Pagination meta missing field: ${field}`)
      }
    }
  }

  // Verify each product has required fields
  for (const product of res.data) {
    if (!product.id) {
      throw new Error('Product missing id')
    }
    if (!product.attributes?.name) {
      throw new Error('Product missing name attribute')
    }
  }
}

/**
 * Test: Cart response includes required fields
 *
 * Verifies that cart operations return a valid Cart object.
 */
export async function testCartContract(config: ContractTestConfig): Promise<void> {
  const { client } = config

  const res = await client.cart.create({})

  if (!res.success) {
    throw new Error(`Cart creation failed: ${res.error}`)
  }

  const cart = res.data

  // Verify required Cart fields
  const required = ['id', 'type', 'attributes']
  for (const field of required) {
    if (!(field in cart)) {
      throw new Error(`Cart missing required field: ${field}`)
    }
  }

  // Verify cart attributes
  const attrs = cart.attributes as Record<string, any>
  const requiredAttrs = ['token', 'item_total', 'total']
  for (const attr of requiredAttrs) {
    if (!(attr in attrs)) {
      throw new Error(`Cart.attributes missing required field: ${attr}`)
    }
  }
}

/**
 * Test: Error response has expected shape
 *
 * Verifies that API errors return standardized error object.
 */
export async function testErrorContract(config: ContractTestConfig): Promise<void> {
  const { client } = config

  // Attempt to fetch non-existent product
  const res = await client.products.get('nonexistent-id-12345')

  if (res.success) {
    throw new Error('Expected product fetch to fail, but it succeeded')
  }

  // Verify error shape
  if (!res.error) {
    throw new Error('Error response missing error field')
  }

  // Error should have message
  if (typeof res.error !== 'string') {
    throw new Error(`Error should be a string, got ${typeof res.error}`)
  }
}

/**
 * Run all contract tests.
 *
 * @throws if any contract test fails
 */
export async function runAllContractTests(config: ContractTestConfig): Promise<void> {
  const tests = [
    { name: 'Store Contract', fn: () => testStoreContract(config) },
    { name: 'Products Contract', fn: () => testProductsContract(config) },
    { name: 'Cart Contract', fn: () => testCartContract(config) },
    { name: 'Error Contract', fn: () => testErrorContract(config) },
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
