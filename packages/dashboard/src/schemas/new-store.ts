import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const newStoreFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('store.name') }),
  code: z.string().optional(),
  url: z.string().min(1, { error: requiredMessage('store.url') }),
  mail_from_address: z.string().min(1, { error: requiredMessage('store.mail_from_address') }),
  default_currency: z.string().optional(),
  default_locale: z.string().optional(),
  default_country_iso: z.string().optional(),
})

export type NewStoreFormValues = z.infer<typeof newStoreFormSchema>
