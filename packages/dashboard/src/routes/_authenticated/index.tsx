import { adminClient } from '@spree/dashboard-core'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'

export const Route = createFileRoute('/_authenticated/')({
  component: IndexRedirect,
})

function IndexRedirect() {
  const navigate = useNavigate()

  useEffect(() => {
    let cancelled = false
    // Lists the stores this admin actually belongs to (rather than the
    // singular `/store`, which — before any store is selected — resolves to
    // whichever store the backend treats as the host-based default, not
    // necessarily one this admin has a role on) and lands on the first one.
    adminClient.stores
      .list()
      .then((stores) => {
        const storeId = stores[0]?.id ?? 'default'
        if (!cancelled) navigate({ to: '/$storeId', params: { storeId }, replace: true })
      })
      .catch(() => {
        if (!cancelled) navigate({ to: '/$storeId', params: { storeId: 'default' }, replace: true })
      })
    return () => {
      cancelled = true
    }
  }, [navigate])

  return null
}
