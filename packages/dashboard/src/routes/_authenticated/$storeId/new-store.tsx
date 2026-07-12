import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type StoreCreateParams } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader, useCreateStore } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  FormSaveButton,
  Input,
  ResourceLayout,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { type NewStoreFormValues, newStoreFormSchema } from '@/schemas/new-store'

export const Route = createFileRoute('/_authenticated/$storeId/new-store')({
  component: NewStorePage,
})

const DEFAULT_VALUES: NewStoreFormValues = {
  name: '',
  code: '',
  url: '',
  mail_from_address: '',
  default_currency: '',
  default_locale: '',
  default_country_iso: '',
}

function NewStorePage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const createStore = useCreateStore()

  const form = useForm<NewStoreFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(newStoreFormSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  const onSubmit = async (values: NewStoreFormValues) => {
    const params: StoreCreateParams = {
      name: values.name,
      url: values.url,
      mail_from_address: values.mail_from_address,
      code: values.code || undefined,
      default_currency: values.default_currency || undefined,
      default_locale: values.default_locale || undefined,
      default_country_iso: values.default_country_iso || undefined,
    }
    try {
      const store = await createStore.mutateAsync(params)
      toast.success(t('admin.pages.new_store.success'))
      navigate({ to: '/$storeId', params: { storeId: store.id } })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.pages.new_store.error'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.pages.new_store.title')}
            subtitle={t('admin.pages.new_store.subtitle')}
            actions={
              <FormSaveButton
                form={form}
                label={t('admin.actions.create')}
                savingLabel={t('admin.actions.creating')}
              />
            }
          />
        }
        main={
          <>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.settings.store.tab_general')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="new-store-name">
                      {t('admin.fields.store.name.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-name"
                      aria-invalid={!!errors.name || undefined}
                      {...form.register('name')}
                    />
                    <FieldError errors={[errors.name]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="new-store-url">
                      {t('admin.fields.store.url.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-url"
                      placeholder={t('admin.fields.store.url.placeholder')}
                      aria-invalid={!!errors.url || undefined}
                      {...form.register('url')}
                    />
                    <FieldError errors={[errors.url]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="new-store-mail-from">
                      {t('admin.fields.store.mail_from_address.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-mail-from"
                      placeholder={t('admin.fields.store.mail_from_address.placeholder')}
                      aria-invalid={!!errors.mail_from_address || undefined}
                      {...form.register('mail_from_address')}
                    />
                    <FieldError errors={[errors.mail_from_address]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="new-store-code">
                      {t('admin.fields.store.code.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-code"
                      placeholder={t('admin.fields.store.code.placeholder')}
                      {...form.register('code')}
                    />
                    <FieldError errors={[errors.code]} />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.settings.store.tab_standards')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="new-store-currency">
                      {t('admin.fields.store.default_currency.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-currency"
                      placeholder={t('admin.fields.store.default_currency.placeholder')}
                      {...form.register('default_currency')}
                    />
                    <FieldError errors={[errors.default_currency]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="new-store-locale">
                      {t('admin.fields.store.default_locale.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-locale"
                      placeholder={t('admin.fields.store.default_locale.placeholder')}
                      {...form.register('default_locale')}
                    />
                    <FieldError errors={[errors.default_locale]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="new-store-country">
                      {t('admin.fields.store.default_country_iso.label')}
                    </FieldLabel>
                    <Input
                      id="new-store-country"
                      placeholder={t('admin.fields.store.default_country_iso.placeholder')}
                      {...form.register('default_country_iso')}
                    />
                    <FieldError errors={[errors.default_country_iso]} />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>
          </>
        }
      />
    </form>
  )
}
