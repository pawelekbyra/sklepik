# @sklepik/test-contracts

Executable Store API and tenant-isolation gates for Store Factory pilots. The package uses the public `@spree/sdk` interface and is intended to run against disposable test data before a storefront is promoted.

## What it verifies

- Store, product pagination, cart and error response contracts.
- Store A cannot read a product that belongs only to Store B.
- Store A cannot mutate Store B's cart.
- Store A's publishable key cannot be combined with Store B's explicit store ID.
- Webhook payloads carry the expected `store_id` and a signature.

These checks complement backend RSpec. They do not replace the full two-tenant checkout scenario covering customer accounts, orders and payment state.

## Required pilot fixtures

Create two active stores with separate publishable API keys. Store B must have one product and variant that are not published to Store A. Pass their prefixed IDs as `productIdB` and `variantIdB`; the package deliberately does not create catalog data through Store API because `@spree/sdk` exposes read-only product operations.

```ts
import { createClient } from '@spree/sdk'
import {
  runAllContractTests,
  runAllIsolationTests,
} from '@sklepik/test-contracts'

const clientA = createClient({
  baseUrl: process.env.SPREE_API_URL!,
  publishableKey: process.env.STORE_A_KEY!,
})
const clientB = createClient({
  baseUrl: process.env.SPREE_API_URL!,
  publishableKey: process.env.STORE_B_KEY!,
})

await runAllContractTests({
  client: clientA,
  storeId: process.env.STORE_A_ID!,
  apiBaseUrl: process.env.SPREE_API_URL!,
})

await runAllIsolationTests({
  clientA,
  storeIdA: process.env.STORE_A_ID!,
  publishableKeyA: process.env.STORE_A_KEY!,
  clientB,
  storeIdB: process.env.STORE_B_ID!,
  productIdB: process.env.STORE_B_PRODUCT_ID!,
  variantIdB: process.env.STORE_B_VARIANT_ID!,
  apiBaseUrl: process.env.SPREE_API_URL!,
})
```

Never commit real keys. CI should inject them through repository/environment secrets and use non-production pilot stores.

## Local verification

From the repository root, after workspace dependencies and `@spree/sdk` are built:

```sh
pnpm --filter @sklepik/test-contracts typecheck
pnpm --filter @sklepik/test-contracts build
pnpm --filter @sklepik/test-contracts test
```

The workspace lockfile must contain the `packages/test-contracts` importer; use `pnpm install --frozen-lockfile` as the clean-install gate.
