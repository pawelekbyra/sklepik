module Spree
  module Api
    module V3
      module Store
        module RequiresLiveStore
          extend ActiveSupport::Concern

          private

          def require_live_store!
            return if current_store.live?

            render_error(
              code: 'cart_cannot_complete',
              message: 'This store is not accepting orders yet.',
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
