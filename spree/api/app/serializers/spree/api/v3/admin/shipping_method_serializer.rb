module Spree
  module Api
    module V3
      module Admin
        class ShippingMethodSerializer < V3::BaseSerializer
          typelize name: :string,
                   display_on: :integer,
                   tax_category_id: [:string, nullable: true],
                   estimated_transit_business_days_min: [:integer, nullable: true],
                   estimated_transit_business_days_max: [:integer, nullable: true]

          attributes :name, :display_on, :tax_category_id,
                     :estimated_transit_business_days_min,
                     :estimated_transit_business_days_max,
                     :shipping_category_ids, :zone_ids,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
