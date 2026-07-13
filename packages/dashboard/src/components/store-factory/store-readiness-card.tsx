import type { StoreReadinessKey } from '@spree/admin-sdk'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import { CheckCircle2Icon, CircleDashedIcon, RocketIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useLaunchStore, useStoreReadiness } from '@/hooks/use-store-readiness'

const CHECK_LINKS = {
  business_details: '/$storeId/settings/emails',
  product: '/$storeId/products',
  payment_method: '/$storeId/settings/payment-methods',
  shipping: '/$storeId/settings/shipping-methods',
  legal_documents: '/$storeId/settings/legal',
  homepage: '/$storeId/editor',
} as const satisfies Record<StoreReadinessKey, string>

export function StoreReadinessCard() {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const readiness = useStoreReadiness()
  const launch = useLaunchStore()

  if (!readiness.data) {
    return <Skeleton className="h-72 w-full" />
  }

  if (readiness.data.status !== 'draft') {
    return null
  }

  const launchStore = async () => {
    try {
      await launch.mutateAsync()
      toast.success(t('admin.store_readiness.launched'))
    } catch (error) {
      toast.error(error instanceof Error ? error.message : t('admin.store_readiness.launch_failed'))
    }
  }

  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between gap-4">
        <div>
          <CardTitle>{t('admin.store_readiness.title')}</CardTitle>
          <CardDescription>{t('admin.store_readiness.description')}</CardDescription>
        </div>
        <Badge variant={readiness.data.ready ? 'default' : 'secondary'}>
          {readiness.data.ready
            ? t('admin.store_readiness.ready')
            : t('admin.store_readiness.in_progress')}
        </Badge>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="divide-y rounded-xl border">
          {readiness.data.checks.map((check) => (
            <Link
              key={check.key}
              to={CHECK_LINKS[check.key]}
              params={{ storeId }}
              className="flex items-center justify-between gap-4 px-4 py-3 text-sm hover:bg-muted/50"
            >
              <span className="flex items-center gap-3">
                {check.ready ? (
                  <CheckCircle2Icon className="size-5 text-emerald-600" />
                ) : (
                  <CircleDashedIcon className="size-5 text-muted-foreground" />
                )}
                {t(`admin.store_readiness.checks.${check.key}`)}
              </span>
              <span className="text-xs text-muted-foreground">
                {check.ready
                  ? t('admin.store_readiness.complete')
                  : t('admin.store_readiness.configure')}
              </span>
            </Link>
          ))}
        </div>
        <Button
          type="button"
          onClick={launchStore}
          disabled={!readiness.data.ready || launch.isPending}
        >
          <RocketIcon />
          {launch.isPending
            ? t('admin.store_readiness.launching')
            : t('admin.store_readiness.launch')}
        </Button>
      </CardContent>
    </Card>
  )
}
