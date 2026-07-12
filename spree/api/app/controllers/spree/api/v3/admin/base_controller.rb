module Spree
  module Api
    module V3
      module Admin
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::AdminAuthentication
          include Spree::Api::V3::ScopedAuthorization

          # Must run before `raise_record_not_found_if_store_is_not_found`
          # (registered by `ControllerHelpers::Store`, prepended ahead of this
          # one since it was included into the superclass first).
          prepend_before_action :resolve_store_from_header
          before_action :authenticate_admin!

          private

          # The admin dashboard manages many stores from one origin, so it selects
          # the active store explicitly via `X-Spree-Store-Id` (sent on every
          # admin-sdk request) instead of relying on the request host, which only
          # identifies a store for storefront-facing requests. Pre-fills the same
          # `@current_store` ivar that `current_store` memoizes into, rather than
          # overriding the method itself, so requests without the header still
          # fall back cleanly to host-based resolution (server-to-server API key
          # integrations that predate this header).
          def resolve_store_from_header
            store_id = request.headers['X-Spree-Store-Id']
            return if store_id.blank?

            # An invalid/stale id in the header is a hard 404, not a silent
            # fallback to the default store — matches
            # `raise_record_not_found_if_store_is_not_found` below.
            @current_store = Spree::Store.find_by_prefix_id(store_id) || raise(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end
end
