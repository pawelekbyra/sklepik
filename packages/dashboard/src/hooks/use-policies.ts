import type { Policy, PolicyUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function usePolicies() {
  return useQuery({
    queryKey: useResourceKey('policies'),
    queryFn: () => adminClient.policies.list(),
  })
}

export function useUpdatePolicy() {
  return useResourceMutation<Policy, Error, { id: string; params: PolicyUpdateParams }>({
    mutationFn: ({ id, params }) => adminClient.policies.update(id, params),
    invalidate: [['policies'], ['store-readiness']],
    successMessage: false,
    errorMessage: false,
  })
}
