module Spree
  module Stores
    class FindDefault
      def initialize(scope: nil, url: nil)
        @scope = scope || Spree::Store
        @url = url
      end

      def execute
        store = store_for_url || @scope.where(default: true).first || @scope.first
        return if store.nil?

        Spree::Current.store = store
        store
      end

      private

      # Resolves the store whose +url+ matches the request host. This is what
      # lets a second storefront on its own domain reach its own store instead
      # of always getting the default one. Falls back (in +execute+) to the
      # default store when the host matches no store — e.g. the backend/admin
      # host, which is not a storefront domain — so single-store setups where
      # the request host never equals a +Store#url+ behave exactly as before.
      def store_for_url
        host = normalize_host(@url)
        return if host.blank?

        @scope.detect { |store| normalize_host(store.url) == host }
      end

      # Strips scheme, path and port, lower-cases. Mirrors the host extraction
      # used by +Spree::Store#formatted_url+ so a store's +url+ and the request
      # +SERVER_NAME+ compare on the same normalized host.
      def normalize_host(value)
        value.to_s.sub(%r{^https?://}, '').split('/').first.to_s.split(':').first.to_s.downcase.presence
      end
    end
  end
end
