module Spree
  module Api
    module V3
      module Admin
        class StorefrontPageSerializer < V3::BaseSerializer
          typelize slug: :string,
                   title: :string,
                   draft_document: 'Record<string, unknown>',
                   published_document: ['Record<string, unknown>', nullable: true],
                   published_at: [:string, nullable: true],
                   published_by_id: [:string, nullable: true],
                   lock_version: :number

          attributes :slug, :title, :draft_document, :published_document, :lock_version,
                     created_at: :iso8601, updated_at: :iso8601

          attribute(:published_at) { |page| page.published_at&.iso8601 }
          attribute(:published_by_id) { |page| page.published_by&.prefixed_id }
        end
      end
    end
  end
end
