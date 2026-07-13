import type { ProvisioningRun } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '../client'

export function provisioningRunQueryKey(storeId: string) {
  return ['provisioning-run', storeId] as const
}

const TERMINAL_STATUSES: ProvisioningRun['status'][] = ['active', 'failed']

/**
 * Polls the latest provisioning run for a store. Stops polling once the run
 * reaches a terminal status (`active`/`failed`) — `enabled` lets the caller
 * hold off querying until a run has actually been started.
 */
export function useProvisioningStatus(storeId: string, enabled: boolean) {
  return useQuery({
    queryKey: provisioningRunQueryKey(storeId),
    queryFn: (): Promise<ProvisioningRun> => adminClient.provisioningRun.status(storeId),
    enabled,
    refetchInterval: (query) => {
      const data = query.state.data
      if (!data || TERMINAL_STATUSES.includes(data.status)) return false
      return 3000
    },
  })
}

export function useStartProvisioning() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (storeId: string): Promise<ProvisioningRun> =>
      adminClient.provisioningRun.start(storeId),
    onSuccess: (run, storeId) => {
      queryClient.setQueryData(provisioningRunQueryKey(storeId), run)
    },
  })
}
