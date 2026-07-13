import { z } from 'zod'

export const policyFormSchema = z.object({
  body: z.string().min(1),
})

export type PolicyFormValues = z.infer<typeof policyFormSchema>
