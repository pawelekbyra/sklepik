export type StoreReadinessKey =
  | 'business_details'
  | 'product'
  | 'payment_method'
  | 'shipping'
  | 'legal_documents'
  | 'homepage'

export interface StoreReadinessCheck {
  key: StoreReadinessKey
  ready: boolean
}

export interface StoreReadiness {
  status: 'draft' | 'live' | 'suspended'
  ready: boolean
  checks: StoreReadinessCheck[]
}
