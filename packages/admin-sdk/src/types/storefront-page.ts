export interface StorefrontButtonBlock {
  id: string
  type: 'button'
  position: number
  preferences: {
    label: string
    href: string
    openInNewTab: boolean
  }
}

export interface StorefrontHeroSection {
  id: string
  type: 'hero'
  position: number
  preferences: {
    heading: string
    subheading: string
    backgroundImageAssetId: string | null
  }
  blocks: StorefrontButtonBlock[]
}

export interface StorefrontProductGridSection {
  id: string
  type: 'product_grid'
  position: number
  preferences: {
    heading: string
    taxonId: string | null
    limit: number
  }
}

export type StorefrontSection = StorefrontHeroSection | StorefrontProductGridSection

export interface StorefrontPageDocument {
  schemaVersion: 1
  sections: StorefrontSection[]
}

export interface StorefrontPage {
  id: string
  slug: string
  title: string
  draft_document: StorefrontPageDocument
  published_document: StorefrontPageDocument | null
  published_at: string | null
  published_by_id: string | null
  lock_version: number
  created_at: string
  updated_at: string
}

export interface StorefrontPageUpdateParams {
  title?: string
  draft_document: StorefrontPageDocument
  lock_version: number
}
