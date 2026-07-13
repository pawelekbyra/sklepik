import type { Store } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation, useStore } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useStoreReadiness() {
  return useQuery({
    queryKey: useResourceKey('store-readiness'),
    queryFn: () => adminClient.store.readiness(),
  })
}

export function useLaunchStore() {
  const { refetch } = useStore()
  return useResourceMutation<Store, Error, void>({
    mutationFn: () => adminClient.store.launch(),
    invalidate: [['store-readiness'], ['store-settings']],
    successMessage: false,
    errorMessage: false,
    onSuccess: () => refetch(),
  })
}
