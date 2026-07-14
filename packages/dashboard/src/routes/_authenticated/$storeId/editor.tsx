import { zodResolver } from '@hookform/resolvers/zod'
import {
  SpreeError,
  type StorefrontHeroSection,
  type StorefrontPage,
  type StorefrontPageDocument,
  type StorefrontProductGridSection,
  type StorefrontSection,
} from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Skeleton,
  Textarea,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import {
  ArrowDownIcon,
  ArrowUpIcon,
  BoxIcon,
  LayoutTemplateIcon,
  PlusIcon,
  SendIcon,
  Trash2Icon,
} from 'lucide-react'
import { useEffect } from 'react'
import { type UseFormReturn, useFieldArray, useForm, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import {
  usePublishStorefrontPage,
  useStorefrontPage,
  useUpdateStorefrontPage,
} from '@/hooks/use-storefront-page'
import { type StorefrontPageFormValues, storefrontPageFormSchema } from '@/schemas/storefront-page'

export const Route = createFileRoute('/_authenticated/$storeId/editor')({
  component: StorefrontEditorPage,
})

const PREVIEW_PRODUCT_IDS = [
  'preview-product-1',
  'preview-product-2',
  'preview-product-3',
  'preview-product-4',
  'preview-product-5',
  'preview-product-6',
]

function formValues(page: StorefrontPage): StorefrontPageFormValues {
  return {
    title: page.title,
    document: page.draft_document,
  }
}

function newHero(position: number): StorefrontHeroSection {
  return {
    id: crypto.randomUUID(),
    type: 'hero',
    position,
    preferences: {
      heading: '',
      subheading: '',
      backgroundImageAssetId: null,
    },
    blocks: [],
  }
}

function newProductGrid(position: number): StorefrontProductGridSection {
  return {
    id: crypto.randomUUID(),
    type: 'product_grid',
    position,
    preferences: {
      heading: '',
      taxonId: null,
      limit: 8,
    },
  }
}

function normalizeDocument(document: StorefrontPageDocument): StorefrontPageDocument {
  return {
    ...document,
    sections: document.sections.map((section, position) => ({ ...section, position })),
  }
}

function StorefrontEditorPage() {
  const { t } = useTranslation()
  const pageQuery = useStorefrontPage()

  if (pageQuery.error) {
    return (
      <ErrorState
        title={t('admin.storefront_editor.load_failed')}
        description={pageQuery.error instanceof Error ? pageQuery.error.message : undefined}
        onRetry={() => pageQuery.refetch()}
      />
    )
  }

  if (!pageQuery.data) {
    return <EditorSkeleton />
  }

  return <StorefrontEditorForm page={pageQuery.data} />
}

function StorefrontEditorForm({ page }: { page: StorefrontPage }) {
  const { t, i18n } = useTranslation()
  const updatePage = useUpdateStorefrontPage()
  const publishPage = usePublishStorefrontPage()
  const form = useForm<StorefrontPageFormValues>({
    // Resolver packages can carry a second react-hook-form type instance in
    // pnpm workspaces; the schema and form values are intentionally identical.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(storefrontPageFormSchema) as any,
    defaultValues: formValues(page),
  })
  const sections = useFieldArray({
    control: form.control,
    name: 'document.sections',
    keyName: 'fieldKey',
  })
  const previewDocument = useWatch({ control: form.control, name: 'document' })

  useEffect(() => {
    form.reset(formValues(page))
  }, [form, page])

  const save = async (values: StorefrontPageFormValues): Promise<StorefrontPage | null> => {
    try {
      const saved = await updatePage.mutateAsync({
        title: values.title,
        draft_document: normalizeDocument(values.document),
        lock_version: page.lock_version,
      })
      form.reset(formValues(saved))
      toast.success(t('admin.storefront_editor.saved'))
      return saved
    } catch (error) {
      if (mapSpreeErrorsToForm(error, form.setError)) return null
      if (error instanceof SpreeError) {
        toast.error(error.message)
        return null
      }
      toast.error(t('admin.storefront_editor.save_failed'))
      return null
    }
  }

  const publish = async () => {
    const valid = await form.trigger()
    if (!valid) return

    if (form.formState.isDirty && !(await save(form.getValues()))) return

    try {
      const published = await publishPage.mutateAsync()
      form.reset(formValues(published))
      toast.success(t('admin.storefront_editor.published'))
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : t('admin.storefront_editor.publish_failed'),
      )
    }
  }

  useFormSubmitShortcut(form, async (values) => {
    await save(values)
  })

  const addSection = (type: StorefrontSection['type']) => {
    const position = sections.fields.length
    sections.append(type === 'hero' ? newHero(position) : newProductGrid(position))
  }

  return (
    <form onSubmit={form.handleSubmit(save)} className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.storefront_editor.title')}
        subtitle={t('admin.storefront_editor.subtitle')}
        badges={
          page.published_at ? (
            <Badge variant="secondary">
              {t('admin.storefront_editor.published_at', {
                date: new Intl.DateTimeFormat(i18n.language, {
                  dateStyle: 'medium',
                  timeStyle: 'short',
                }).format(new Date(page.published_at)),
              })}
            </Badge>
          ) : (
            <Badge variant="outline">{t('admin.storefront_editor.not_published')}</Badge>
          )
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              type="submit"
              variant="outline"
              disabled={updatePage.isPending || publishPage.isPending}
            >
              {updatePage.isPending
                ? t('admin.storefront_editor.saving')
                : t('admin.storefront_editor.save')}
            </Button>
            <Button
              type="button"
              onClick={publish}
              disabled={updatePage.isPending || publishPage.isPending}
            >
              <SendIcon />
              {publishPage.isPending
                ? t('admin.storefront_editor.publishing')
                : t('admin.storefront_editor.publish')}
            </Button>
          </div>
        }
      />

      {form.formState.errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {form.formState.errors.root.message}
        </p>
      )}

      <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(360px,0.9fr)]">
        <div className="flex min-w-0 flex-col gap-4">
          <Card>
            <CardHeader>
              <CardTitle>{t('admin.storefront_editor.page_settings')}</CardTitle>
            </CardHeader>
            <CardContent>
              <Field data-invalid={!!form.formState.errors.title}>
                <FieldLabel htmlFor="storefront-page-title">
                  {t('admin.storefront_editor.page_title')}
                </FieldLabel>
                <Input
                  id="storefront-page-title"
                  {...form.register('title')}
                  aria-invalid={!!form.formState.errors.title}
                />
                <FieldError errors={[form.formState.errors.title]} />
              </Field>
            </CardContent>
          </Card>

          {sections.fields.map((section, index) => (
            <SectionEditor
              key={section.fieldKey}
              index={index}
              count={sections.fields.length}
              form={form}
              onMoveUp={() => sections.move(index, index - 1)}
              onMoveDown={() => sections.move(index, index + 1)}
              onRemove={() => sections.remove(index)}
            />
          ))}

          <Card className="border-dashed">
            <CardHeader>
              <CardTitle>{t('admin.storefront_editor.add_section')}</CardTitle>
              <CardDescription>{t('admin.storefront_editor.add_section_help')}</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-2">
              <Button type="button" variant="outline" onClick={() => addSection('hero')}>
                <PlusIcon />
                {t('admin.storefront_editor.section.hero')}
              </Button>
              <Button type="button" variant="outline" onClick={() => addSection('product_grid')}>
                <PlusIcon />
                {t('admin.storefront_editor.section.product_grid')}
              </Button>
            </CardContent>
          </Card>
        </div>

        <div className="sticky top-24">
          <Card className="overflow-hidden">
            <CardHeader className="border-b">
              <CardTitle>{t('admin.storefront_editor.preview')}</CardTitle>
              <CardDescription>{t('admin.storefront_editor.preview_help')}</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <StorefrontPreview document={previewDocument} />
            </CardContent>
          </Card>
        </div>
      </div>
    </form>
  )
}

type EditorForm = UseFormReturn<StorefrontPageFormValues>

function SectionEditor({
  index,
  count,
  form,
  onMoveUp,
  onMoveDown,
  onRemove,
}: {
  index: number
  count: number
  form: EditorForm
  onMoveUp: () => void
  onMoveDown: () => void
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const current = form.watch(`document.sections.${index}`)

  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between gap-4">
        <div>
          <CardTitle className="flex items-center gap-2">
            {current.type === 'hero' ? <LayoutTemplateIcon /> : <BoxIcon />}
            {t(`admin.storefront_editor.section.${current.type}`)}
          </CardTitle>
          <CardDescription>
            {t('admin.storefront_editor.section_position', { position: index + 1 })}
          </CardDescription>
        </div>
        <div className="flex gap-1">
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            onClick={onMoveUp}
            disabled={index === 0}
            aria-label={t('admin.storefront_editor.move_up')}
          >
            <ArrowUpIcon />
          </Button>
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            onClick={onMoveDown}
            disabled={index === count - 1}
            aria-label={t('admin.storefront_editor.move_down')}
          >
            <ArrowDownIcon />
          </Button>
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            onClick={onRemove}
            aria-label={t('admin.storefront_editor.remove_section')}
          >
            <Trash2Icon />
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {current.type === 'hero' ? (
          <HeroFields index={index} form={form} />
        ) : (
          <ProductGridFields index={index} form={form} />
        )}
      </CardContent>
    </Card>
  )
}

function HeroFields({ index, form }: { index: number; form: EditorForm }) {
  const { t } = useTranslation()
  const section = form.watch(`document.sections.${index}`)
  if (section.type !== 'hero') return null
  const button = section.blocks[0]

  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor={`hero-heading-${index}`}>
          {t('admin.storefront_editor.heading')}
        </FieldLabel>
        <Input
          id={`hero-heading-${index}`}
          {...form.register(`document.sections.${index}.preferences.heading`)}
        />
      </Field>
      <Field>
        <FieldLabel htmlFor={`hero-subheading-${index}`}>
          {t('admin.storefront_editor.subheading')}
        </FieldLabel>
        <Textarea
          id={`hero-subheading-${index}`}
          rows={4}
          {...form.register(`document.sections.${index}.preferences.subheading`)}
        />
      </Field>
      {button ? (
        <div className="grid gap-4 sm:grid-cols-2">
          <Field>
            <FieldLabel htmlFor={`hero-button-label-${index}`}>
              {t('admin.storefront_editor.button_label')}
            </FieldLabel>
            <Input
              id={`hero-button-label-${index}`}
              {...form.register(`document.sections.${index}.blocks.0.preferences.label`)}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor={`hero-button-link-${index}`}>
              {t('admin.storefront_editor.button_link')}
            </FieldLabel>
            <Input
              id={`hero-button-link-${index}`}
              {...form.register(`document.sections.${index}.blocks.0.preferences.href`)}
            />
          </Field>
          <Button
            type="button"
            variant="ghost"
            className="sm:col-span-2 justify-self-start"
            onClick={() =>
              form.setValue(`document.sections.${index}.blocks`, [], { shouldDirty: true })
            }
          >
            <Trash2Icon />
            {t('admin.storefront_editor.remove_button')}
          </Button>
        </div>
      ) : (
        <Button
          type="button"
          variant="outline"
          className="self-start"
          onClick={() =>
            form.setValue(
              `document.sections.${index}.blocks`,
              [
                {
                  id: crypto.randomUUID(),
                  type: 'button',
                  position: 0,
                  preferences: {
                    label: t('admin.storefront_editor.default_button_label'),
                    href: '/products',
                    openInNewTab: false,
                  },
                },
              ],
              { shouldDirty: true },
            )
          }
        >
          <PlusIcon />
          {t('admin.storefront_editor.add_button')}
        </Button>
      )}
    </FieldGroup>
  )
}

function ProductGridFields({ index, form }: { index: number; form: EditorForm }) {
  const { t } = useTranslation()
  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor={`grid-heading-${index}`}>
          {t('admin.storefront_editor.heading')}
        </FieldLabel>
        <Input
          id={`grid-heading-${index}`}
          {...form.register(`document.sections.${index}.preferences.heading`)}
        />
      </Field>
      <Field>
        <FieldLabel htmlFor={`grid-limit-${index}`}>
          {t('admin.storefront_editor.product_limit')}
        </FieldLabel>
        <Input
          id={`grid-limit-${index}`}
          type="number"
          min={1}
          max={24}
          {...form.register(`document.sections.${index}.preferences.limit`, {
            valueAsNumber: true,
          })}
        />
      </Field>
    </FieldGroup>
  )
}

function StorefrontPreview({ document }: { document: StorefrontPageDocument }) {
  const { t } = useTranslation()
  const sections = [...document.sections].sort((a, b) => a.position - b.position)

  if (sections.length === 0) {
    return (
      <div className="flex min-h-72 items-center justify-center p-8 text-center text-sm text-muted-foreground">
        {t('admin.storefront_editor.empty_preview')}
      </div>
    )
  }

  return (
    <div className="bg-white text-zinc-950">
      {sections.map((section) =>
        section.type === 'hero' ? (
          <section
            key={section.id}
            className="flex min-h-64 flex-col items-center justify-center bg-amber-50 px-8 py-12 text-center"
          >
            <p className="max-w-xl text-3xl font-semibold tracking-tight">
              {section.preferences.heading || t('admin.storefront_editor.heading_placeholder')}
            </p>
            <p className="mt-3 max-w-lg text-sm leading-6 text-zinc-600">
              {section.preferences.subheading ||
                t('admin.storefront_editor.subheading_placeholder')}
            </p>
            {section.blocks[0] && (
              <span className="mt-6 rounded-full bg-zinc-950 px-5 py-2 text-sm font-medium text-white">
                {section.blocks[0].preferences.label}
              </span>
            )}
          </section>
        ) : (
          <section key={section.id} className="px-6 py-10">
            <p className="mb-5 text-xl font-semibold">
              {section.preferences.heading || t('admin.storefront_editor.products_placeholder')}
            </p>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              {PREVIEW_PRODUCT_IDS.slice(0, section.preferences.limit).map((productId) => (
                <div key={productId} className="space-y-2">
                  <div className="aspect-square rounded-lg bg-zinc-100" />
                  <div className="h-2.5 w-3/4 rounded bg-zinc-200" />
                  <div className="h-2.5 w-1/3 rounded bg-zinc-200" />
                </div>
              ))}
            </div>
          </section>
        ),
      )}
    </div>
  )
}

function EditorSkeleton() {
  return (
    <div className="grid gap-6 xl:grid-cols-2">
      <div className="space-y-4">
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-80 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
      <Skeleton className="h-[560px] w-full" />
    </div>
  )
}
