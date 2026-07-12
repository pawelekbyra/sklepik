import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const store = await client.stores.create({
  name: 'Second Shop',
  url: 'second-shop.example.com',
  mail_from_address: 'orders@second-shop.example.com',
  default_currency: 'USD',
  default_locale: 'en',
  default_country_iso: 'US',
})
// endregion:example

export { store }
