import { zodResolver } from '@hookform/resolvers/zod'
import type { SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, useAuth } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Input,
  Label,
} from '@spree/dashboard-ui'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { ProvisioningStatusCard } from '@/components/store-factory/provisioning-status-card'
import { type StoreSignupFormValues, storeSignupFormSchema } from '@/schemas/auth'

export const Route = createFileRoute('/signup')({
  component: SignupPage,
})

function SignupPage() {
  const { isAuthenticated } = useAuth()
  const [createdStoreId, setCreatedStoreId] = useState<string | null>(null)

  if (isAuthenticated && !createdStoreId) return <Navigate to="/" replace />

  return (
    <div className="flex min-h-svh flex-col items-center justify-center gap-6 bg-muted p-6 md:p-10">
      <div className="flex w-full max-w-sm flex-col gap-6">
        {createdStoreId ? (
          <ProvisioningStatusCard storeId={createdStoreId} />
        ) : (
          <SignupForm onCreated={setCreatedStoreId} />
        )}
      </div>
    </div>
  )
}

function SignupForm({ onCreated }: { onCreated: (storeId: string) => void }) {
  const { t } = useTranslation()
  const { signup, isLoading } = useAuth()

  const form = useForm<StoreSignupFormValues>({
    resolver: zodResolver(storeSignupFormSchema),
    defaultValues: { store_name: '', email: '', password: '', password_confirmation: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: StoreSignupFormValues) => {
    try {
      const { storeId } = await signup(data)
      onCreated(storeId)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        const e = err as SpreeError
        form.setError('root', { message: e?.message || t('admin.pages.new_store.error') })
      }
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">{t('admin.signup.title')}</CardTitle>
        <CardDescription>{t('admin.signup.subtitle')}</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
          {errors.root && (
            <p className="text-center text-sm text-destructive">{errors.root.message}</p>
          )}
          <div className="grid gap-2">
            <Label htmlFor="store_name">{t('admin.fields.store.name.label')}</Label>
            <Input
              id="store_name"
              autoFocus
              aria-invalid={!!errors.store_name || undefined}
              {...form.register('store_name')}
            />
            {errors.store_name && (
              <p className="text-sm text-destructive">{errors.store_name.message}</p>
            )}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="email">{t('admin.fields.email.label')}</Label>
            <Input
              id="email"
              type="email"
              aria-invalid={!!errors.email || undefined}
              {...form.register('email')}
            />
            {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
            <Input
              id="password"
              type="password"
              aria-invalid={!!errors.password || undefined}
              {...form.register('password')}
            />
            {errors.password && (
              <p className="text-sm text-destructive">{errors.password.message}</p>
            )}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password_confirmation">
              {t('admin.fields.invitation_acceptance.password_confirmation.label')}
            </Label>
            <Input
              id="password_confirmation"
              type="password"
              aria-invalid={!!errors.password_confirmation || undefined}
              {...form.register('password_confirmation')}
            />
            {errors.password_confirmation && (
              <p className="text-sm text-destructive">{errors.password_confirmation.message}</p>
            )}
          </div>
          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? t('admin.signup.submitting') : t('admin.signup.submit')}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
