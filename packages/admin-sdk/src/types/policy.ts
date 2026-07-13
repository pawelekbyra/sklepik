export interface Policy {
  id: string
  name: string
  slug: string
  body: string | null
  body_html: string | null
  created_at: string
  updated_at: string
}

export interface PolicyUpdateParams {
  name?: string
  body: string
}
