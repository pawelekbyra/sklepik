import type { Store, StoreCreateParams } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '../client'

/**
 * Not store-scoped (unlike `useResourceKey`/`withStoreScope`, which inject
 * the *current* store): this lists every store the admin belongs to,
 * independent of which one happens to be selected right now.
 */
export const storesQueryKey = ['stores'] as const

/** Every store the authenticated admin holds a role on — feeds the store switcher. */
export function useStores() {
  return useQuery({
    queryKey: storesQueryKey,
    queryFn: (): Promise<Store[]> => adminClient.stores.list(),
  })
}

/**
 * Creates a new store and grants the current admin the admin role on it
 * (server-side). Deliberately not built on `useResourceMutation` — that
 * hook's cache invalidation always scopes keys to the *current* store
 * (`withStoreScope`), which would mis-key this cross-store list.
 */
export function useCreateStore() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: StoreCreateParams): Promise<Store> => adminClient.stores.create(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: storesQueryKey })
    },
  })
}
