module Spree
  module Api
    module V3
      module Admin
        class PoliciesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::Policy
          end

          def serializer_class
            Spree.api.admin_policy_serializer
          end

          def scope
            current_store.policies.accessible_by(current_ability, :show).order(:name)
          end

          def permitted_params
            params.permit(:name, :body)
          end
        end
      end
    end
  end
end
