// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreSchema = z.object({
  id: z.string(),
  name: z.string(),
  default_currency: z.string(),
  default_locale: z.string(),
  url: z.string(),
  supported_currencies: z.array(z.string()),
  supported_locales: z.array(z.string()),
  logo_url: z.string().nullable(),
});

export type Store = z.infer<typeof StoreSchema>;
