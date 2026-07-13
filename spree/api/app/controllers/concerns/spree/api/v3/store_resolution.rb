module Spree
  module Api
    module V3
      module StoreResolution
        extend ActiveSupport::Concern

        included do
          # ControllerHelpers::Store resolves current_store before the regular
          # authentication callback, so bind the store from the publishable key
          # first. The key is globally unique and therefore an unambiguous tenant
          # identifier even when every storefront calls the same API host.
          prepend_before_action :resolve_store_from_publishable_key
        end

        private

        def resolve_store_from_publishable_key
          api_key = Spree::ApiKey.active.publishable.includes(:store).find_by(token: extract_api_key)
          return if api_key.nil? || api_key.store.nil?
          return render_invalid_store_api_key unless store_request_consistent_with?(api_key.store)

          @current_api_key = api_key
          @current_store = api_key.store
          Spree::Current.store = @current_store
        end

        def store_request_consistent_with?(store)
          requested_store_id_matches?(store) && request_host_matches?(store)
        end

        def requested_store_id_matches?(store)
          requested_store_id = request.headers['X-Spree-Store-Id']
          return true if requested_store_id.blank?

          Spree::Store.find_by_param(requested_store_id) == store
        end

        # A shared API hostname is intentionally not a tenant identifier. Only
        # reject the request when its host is explicitly assigned to another
        # store; an unassigned host remains compatible with today's deployments.
        def request_host_matches?(store)
          host = normalize_store_host(request.host)
          return true if host.blank?

          host_store = Spree::Store.all.detect { |candidate| normalize_store_host(candidate.url) == host }
          host_store.nil? || host_store == store
        end

        # Keep host comparison aligned with Stores::FindDefault: Store#url may
        # contain a scheme, path, or port while Rack exposes only request.host.
        def normalize_store_host(value)
          value.to_s
            .sub(%r{^https?://}, '')
            .split('/').first.to_s
            .split(':').first.to_s
            .downcase
            .chomp('.')
            .presence
        end

        def render_invalid_store_api_key
          render_error(
            code: ErrorHandler::ERROR_CODES[:invalid_token],
            message: 'Valid API key required',
            status: :unauthorized
          )
        end
      end
    end
  end
end
