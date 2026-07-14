module Spree
  module Api
    module V3
      module Admin
        class StorefrontPagesController < Admin::BaseController
          scoped_resource :settings

          def show
            authorize! :show, current_store
            render json: serialize_resource(homepage)
          end

          def update
            authorize! :update, current_store

            if homepage.update(permitted_params)
              render json: serialize_resource(homepage)
            else
              render_validation_error(homepage.errors)
            end
          rescue ActiveRecord::StaleObjectError
            render_error(
              code: 'conflict',
              message: 'This page was changed in another session. Reload it before saving again.',
              status: :conflict
            )
          end

          def publish
            authorize! :update, current_store
            homepage.publish!(user: current_user)
            render json: serialize_resource(homepage)
          end

          private

          def homepage
            @homepage ||= current_store.storefront_pages.find_or_create_by!(slug: 'home') do |page|
              page.title = 'Homepage'
              page.draft_document = Spree::StorefrontPage.default_document
            end
          end

          def serializer_class
            Spree.api.admin_storefront_page_serializer
          end

          def permitted_params
            params.permit(:title, :lock_version, draft_document: {})
          end
        end
      end
    end
  end
end
