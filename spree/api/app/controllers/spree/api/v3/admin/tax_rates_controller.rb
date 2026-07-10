module Spree
  module Api
    module V3
      module Admin
        class TaxRatesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::TaxRate
          end

          def serializer_class
            Spree.api.admin_tax_rate_serializer
          end

          def permitted_params
            permitted = params.permit(:name, :amount, :tax_category_id, :zone_id,
                                       :included_in_price, :calculator_type)
            permitted[:calculator_type] ||= 'Spree::Calculator::DefaultTax' if action_name == 'create'
            permitted
          end
        end
      end
    end
  end
end
