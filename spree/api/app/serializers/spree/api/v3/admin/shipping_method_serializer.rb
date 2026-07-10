module Spree
  module Api
    module V3
      module Admin
        class ShippingMethodSerializer < V3::BaseSerializer
          typelize name: :string,
                   display_on: :string,
                   tax_category_id: [:string, nullable: true],
                   estimated_transit_business_days_min: [:number, nullable: true],
                   estimated_transit_business_days_max: [:number, nullable: true],
                   shipping_category_ids: [:string, multi: true],
                   zone_ids: [:string, multi: true]

          attributes :name, :display_on,
                     :estimated_transit_business_days_min,
                     :estimated_transit_business_days_max,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :tax_category_id do |shipping_method|
            shipping_method.tax_category&.prefixed_id
          end

          attribute :shipping_category_ids do |shipping_method|
            shipping_method.shipping_categories.map(&:prefixed_id)
          end

          attribute :zone_ids do |shipping_method|
            shipping_method.zones.map(&:prefixed_id)
          end
        end
      end
    end
  end
end
