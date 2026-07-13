module Spree
  module Api
    module V3
      module Store
        class StorefrontPagesController < Store::BaseController
          allow_guest_storefront_access!
          include Spree::Api::V3::HttpCaching

          def show
            page = current_store.storefront_pages.find_by!(slug: 'home')
            raise ActiveRecord::RecordNotFound unless page.published?
            return unless cache_resource(page)

            render json: serializer_class.new(page, params: serializer_params).to_h
          end

          private

          def serializer_class
            Spree.api.storefront_page_serializer
          end
        end
      end
    end
  end
end
