import { z } from 'zod'

const buttonBlockSchema = z.object({
  id: z.string().min(1),
  type: z.literal('button'),
  position: z.number().int().min(0),
  preferences: z.object({
    label: z.string().max(80),
    href: z
      .string()
      .refine(
        (value) =>
          value.startsWith('/') || value.startsWith('https://') || value.startsWith('http://'),
        'Enter a relative path or an http(s) URL',
      ),
    openInNewTab: z.boolean(),
  }),
})

const heroSectionSchema = z.object({
  id: z.string().min(1),
  type: z.literal('hero'),
  position: z.number().int().min(0),
  preferences: z.object({
    heading: z.string().max(160),
    subheading: z.string().max(500),
    backgroundImageAssetId: z.string().nullable(),
  }),
  blocks: z.array(buttonBlockSchema).max(1),
})

const productGridSectionSchema = z.object({
  id: z.string().min(1),
  type: z.literal('product_grid'),
  position: z.number().int().min(0),
  preferences: z.object({
    heading: z.string().max(160),
    taxonId: z.string().nullable(),
    limit: z.number().int().min(1).max(24),
  }),
})

export const storefrontPageDocumentSchema = z.object({
  schemaVersion: z.literal(1),
  sections: z
    .array(z.discriminatedUnion('type', [heroSectionSchema, productGridSectionSchema]))
    .max(30),
})

export type StorefrontPageDocumentValues = z.infer<typeof storefrontPageDocumentSchema>

export const storefrontPageFormSchema = z.object({
  title: z.string().min(1).max(160),
  document: storefrontPageDocumentSchema,
})

export type StorefrontPageFormValues = z.infer<typeof storefrontPageFormSchema>
