import type { ProvisioningStep, ProvisioningStepStatus } from '@spree/admin-sdk'
import { PageHeader, useProvisioningStatus } from '@spree/dashboard-core'
import { Badge, Button, Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { CheckIcon, CircleDashedIcon, Loader2Icon, XIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

const STEP_ORDER = [
  'creating_repository',
  'creating_vercel_project',
  'configuring_environment',
  'deploying',
] as const

function StepIcon({ status }: { status: ProvisioningStepStatus | 'pending' }) {
  if (status === 'done') return <CheckIcon className="size-4 text-green-600 dark:text-green-400" />
  if (status === 'failed') return <XIcon className="size-4 text-destructive" />
  if (status === 'in_progress')
    return <Loader2Icon className="size-4 animate-spin text-muted-foreground" />
  return <CircleDashedIcon className="size-4 text-muted-foreground/50" />
}

interface ProvisioningStatusCardProps {
  storeId: string
}

/**
 * Polls a store's provisioning run (`useProvisioningStatus`) and renders a
 * fixed checklist of the pipeline's stages — always all four, regardless of
 * how many the backend has reported so far, so the user sees the whole plan
 * up front rather than steps popping in one at a time.
 */
export function ProvisioningStatusCard({ storeId }: ProvisioningStatusCardProps) {
  const { t } = useTranslation()
  const { data: run } = useProvisioningStatus(storeId, true)

  const stepByName = new Map<string, ProvisioningStep>((run?.steps ?? []).map((s) => [s.name, s]))

  return (
    <>
      <PageHeader
        title={t('admin.pages.new_store.provisioning_title')}
        subtitle={run?.repo_full_name ?? undefined}
      />
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.new_store.provisioning_title')}</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="flex flex-col gap-3">
            {STEP_ORDER.map((name) => {
              const step = stepByName.get(name)
              return (
                <li key={name} className="flex items-center gap-3">
                  <StepIcon status={step?.status ?? 'pending'} />
                  <span className="text-sm">
                    {t(`admin.pages.new_store.provisioning_step_${name}`)}
                  </span>
                  {step?.status === 'failed' && step.error_message && (
                    <span className="text-sm text-destructive">{step.error_message}</span>
                  )}
                </li>
              )
            })}
          </ul>

          {run?.status === 'active' && (
            <div className="flex items-center gap-3 mt-6">
              <Badge variant="success">{t('admin.pages.new_store.provisioning_active')}</Badge>
              {run.deployment_url && (
                <Button asChild variant="outline" size="sm">
                  <a href={run.deployment_url} target="_blank" rel="noreferrer">
                    {t('admin.pages.new_store.provisioning_visit_store')}
                  </a>
                </Button>
              )}
              <Button asChild size="sm">
                <Link to="/$storeId" params={{ storeId }}>
                  {t('admin.pages.new_store.provisioning_continue_to_admin')}
                </Link>
              </Button>
            </div>
          )}

          {run?.status === 'failed' && (
            <div className="flex items-center gap-3 mt-6">
              <Badge variant="destructive">{t('admin.pages.new_store.provisioning_failed')}</Badge>
              <Button asChild variant="outline" size="sm">
                <Link to="/$storeId" params={{ storeId }}>
                  {t('admin.pages.new_store.provisioning_continue_to_admin')}
                </Link>
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </>
  )
}
