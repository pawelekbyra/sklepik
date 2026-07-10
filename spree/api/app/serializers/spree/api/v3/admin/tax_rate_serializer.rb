module Spree
  module Api
    module V3
      module Admin
        class TaxRateSerializer < V3::BaseSerializer
          typelize name: :string,
                   amount: :number,
                   tax_category_id: :string,
                   zone_id: [:string, nullable: true],
                   included_in_price: :boolean

          attributes :name, :included_in_price,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :amount do |tax_rate|
            tax_rate.amount&.to_f
          end

          attribute :tax_category_id do |tax_rate|
            tax_rate.tax_category&.prefixed_id
          end

          attribute :zone_id do |tax_rate|
            tax_rate.zone&.prefixed_id
          end
        end
      end
    end
  end
end
