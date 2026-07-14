import type { StorefrontPage, StorefrontPageUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useStorefrontPage() {
  return useQuery({
    queryKey: useResourceKey('storefront-page'),
    queryFn: () => adminClient.storefrontPage.get(),
  })
}

export function useUpdateStorefrontPage() {
  return useResourceMutation<StorefrontPage, Error, StorefrontPageUpdateParams>({
    mutationFn: (params) => adminClient.storefrontPage.update(params),
    invalidate: [['storefront-page']],
    successMessage: false,
    errorMessage: false,
  })
}

export function usePublishStorefrontPage() {
  return useResourceMutation<StorefrontPage, Error, void>({
    mutationFn: () => adminClient.storefrontPage.publish(),
    invalidate: [['storefront-page']],
    successMessage: false,
    errorMessage: false,
  })
}
