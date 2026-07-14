import { zodResolver } from '@hookform/resolvers/zod'
import { type Policy, SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
  FieldError,
  FieldLabel,
  Skeleton,
  Textarea,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { usePolicies, useUpdatePolicy } from '@/hooks/use-policies'
import { type PolicyFormValues, policyFormSchema } from '@/schemas/policy'

export const Route = createFileRoute('/_authenticated/$storeId/settings/legal')({
  component: LegalSettingsPage,
})

function LegalSettingsPage() {
  const { t } = useTranslation()
  const policies = usePolicies()

  if (policies.error) {
    return (
      <ErrorState
        title={t('admin.legal.load_failed')}
        description={policies.error instanceof Error ? policies.error.message : undefined}
        onRetry={() => policies.refetch()}
      />
    )
  }

  if (!policies.data) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-12 w-80" />
        <Skeleton className="h-72 w-full" />
        <Skeleton className="h-72 w-full" />
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title={t('admin.legal.title')} subtitle={t('admin.legal.subtitle')} />
      <Card className="border-amber-300 bg-amber-50/60 dark:border-amber-900 dark:bg-amber-950/20">
        <CardHeader>
          <CardTitle>{t('admin.legal.notice_title')}</CardTitle>
          <CardDescription>{t('admin.legal.notice')}</CardDescription>
        </CardHeader>
      </Card>
      {policies.data.map((policy) => (
        <PolicyForm key={policy.id} policy={policy} />
      ))}
    </div>
  )
}

function PolicyForm({ policy }: { policy: Policy }) {
  const { t } = useTranslation()
  const update = useUpdatePolicy()
  const form = useForm<PolicyFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(policyFormSchema) as any,
    defaultValues: { body: policy.body ?? '' },
  })

  const submit = async (values: PolicyFormValues) => {
    try {
      const saved = await update.mutateAsync({
        id: policy.id,
        params: { body: values.body },
      })
      form.reset({ body: saved.body ?? '' })
      toast.success(t('admin.legal.saved', { name: policy.name }))
    } catch (error) {
      if (mapSpreeErrorsToForm(error, form.setError)) return
      if (error instanceof SpreeError) {
        toast.error(error.message)
        return
      }
      toast.error(t('admin.legal.save_failed'))
    }
  }

  return (
    <form onSubmit={form.handleSubmit(submit)}>
      <Card>
        <CardHeader className="flex-row items-start justify-between gap-4">
          <div>
            <CardTitle>{policy.name}</CardTitle>
            <CardDescription>/{policy.slug}</CardDescription>
          </div>
          <Button type="submit" disabled={update.isPending || !form.formState.isDirty}>
            {update.isPending ? t('admin.legal.saving') : t('admin.legal.save')}
          </Button>
        </CardHeader>
        <CardContent>
          <Field data-invalid={!!form.formState.errors.body}>
            <FieldLabel htmlFor={`policy-${policy.id}`}>{t('admin.legal.content')}</FieldLabel>
            <Textarea
              id={`policy-${policy.id}`}
              rows={12}
              {...form.register('body')}
              aria-invalid={!!form.formState.errors.body}
            />
            <FieldError errors={[form.formState.errors.body]} />
          </Field>
        </CardContent>
      </Card>
    </form>
  )
}
