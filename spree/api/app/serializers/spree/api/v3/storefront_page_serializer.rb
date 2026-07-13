module Spree
  module Api
    module V3
      # Public representation contains only the immutable published snapshot.
      class StorefrontPageSerializer < BaseSerializer
        typelize slug: :string,
                 title: :string,
                 document: 'Record<string, unknown>',
                 published_at: [:string, nullable: true]

        attributes :slug, :title

        attribute :document, &:published_document
        attribute(:published_at) { |page| page.published_at&.iso8601 }
      end
    end
  end
end
