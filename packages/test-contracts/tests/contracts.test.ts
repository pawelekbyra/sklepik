import type { Client, TenantId } from '@spree/sdk'
import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  testApiKeyScope,
  testCartContract,
  testCartIsolation,
  testErrorContract,
  testProductIsolation,
  testProductsContract,
  testStoreContract,
  testWebhookStoreContext,
} from '../src/index'

const tenantA = 'store_a' as TenantId
const tenantB = 'store_b' as TenantId

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('Store API contracts', () => {
  it('accepts SDK-native store, product pagination, and cart shapes', async () => {
    const client = {
      store: {
        get: vi.fn().mockResolvedValue({
          id: tenantA,
          name: 'A',
          url: 'a.test',
          default_currency: 'PLN',
          default_locale: 'pl',
        }),
      },
      products: {
        list: vi.fn().mockResolvedValue({
          data: [{ id: 'prod_1', name: 'Product', slug: 'product' }],
          meta: {
            page: 1,
            pages: 1,
            limit: 5,
            count: 1,
            from: 1,
            to: 1,
            in: 1,
            previous: null,
            next: null,
          },
        }),
      },
      carts: {
        create: vi.fn().mockResolvedValue({
          id: 'cart_1',
          token: 'token',
          item_total: '0.0',
          total: '0.0',
          currency: 'PLN',
        }),
      },
    } as unknown as Client
    const config = { client, storeId: tenantA, apiBaseUrl: 'https://api.test' }

    await expect(testStoreContract(config)).resolves.toMatchObject({ id: tenantA })
    await expect(testProductsContract(config)).resolves.toBeUndefined()
    await expect(testCartContract(config)).resolves.toBeUndefined()
  })

  it('requires the SDK to reject a missing product', async () => {
    const rejectingClient = {
      products: { get: vi.fn().mockRejectedValue(new Error('not found')) },
    } as unknown as Client
    const leakingClient = {
      products: { get: vi.fn().mockResolvedValue({ id: 'unexpected' }) },
    } as unknown as Client

    await expect(
      testErrorContract({
        client: rejectingClient,
        storeId: tenantA,
        apiBaseUrl: 'https://api.test',
      }),
    ).resolves.toBeUndefined()
    await expect(
      testErrorContract({
        client: leakingClient,
        storeId: tenantA,
        apiBaseUrl: 'https://api.test',
      }),
    ).rejects.toThrow('Expected a missing product request to reject')
  })
})

describe('tenant isolation contracts', () => {
  function isolationClient(options: { allowForeignRead?: boolean; allowForeignCart?: boolean }) {
    const clientB = {
      products: { get: vi.fn().mockResolvedValue({ id: 'prod_b' }) },
      carts: { create: vi.fn().mockResolvedValue({ id: 'cart_b' }) },
    } as unknown as Client
    const clientA = {
      products: {
        get: options.allowForeignRead
          ? vi.fn().mockResolvedValue({ id: 'prod_b' })
          : vi.fn().mockRejectedValue(new Error('not found')),
      },
      carts: {
        items: {
          create: options.allowForeignCart
            ? vi.fn().mockResolvedValue({ id: 'cart_b' })
            : vi.fn().mockRejectedValue(new Error('not found')),
        },
      },
    } as unknown as Client

    return {
      clientA,
      clientB,
      storeIdA: tenantA,
      publishableKeyA: 'pk_a',
      storeIdB: tenantB,
      productIdB: 'prod_b',
      variantIdB: 'variant_b',
      apiBaseUrl: 'https://api.test',
    }
  }

  it('passes when cross-tenant product reads and cart writes are rejected', async () => {
    const config = isolationClient({})
    await expect(testProductIsolation(config)).resolves.toBeUndefined()
    await expect(testCartIsolation(config)).resolves.toBeUndefined()
  })

  it('reports a security breach when a foreign resource is accessible', async () => {
    await expect(testProductIsolation(isolationClient({ allowForeignRead: true }))).rejects.toThrow(
      'SECURITY BREACH',
    )
    await expect(testCartIsolation(isolationClient({ allowForeignCart: true }))).rejects.toThrow(
      'SECURITY BREACH',
    )
  })

  it('rejects a key/store mismatch and validates webhook tenant context', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 401 }))
    vi.stubGlobal('fetch', fetchMock)

    await expect(testApiKeyScope(isolationClient({}))).resolves.toBeUndefined()
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.test/api/v3/store',
      expect.objectContaining({
        headers: expect.objectContaining({
          'X-Spree-Api-Key': 'pk_a',
          'X-Spree-Store-Id': tenantB,
        }),
      }),
    )
    await expect(
      testWebhookStoreContext({ store_id: tenantA, signature: 'sig' }, tenantA),
    ).resolves.toBeUndefined()
  })
})
