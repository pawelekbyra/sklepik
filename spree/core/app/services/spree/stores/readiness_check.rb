module Spree
  module Stores
    # Reports whether a newly provisioned store is ready to accept real orders.
    # It never fabricates configuration or legal text; the merchant must
    # explicitly satisfy every check and then launch the store.
    class ReadinessCheck
      def self.call(store:)
        new(store).call
      end

      def initialize(store)
        @store = store
      end

      def call
        checks = [
          check('business_details', business_details?),
          check('product', product?),
          check('payment_method', payment_method?),
          check('shipping', shipping?),
          check('legal_documents', legal_documents?),
          check('homepage', homepage?)
        ]

        {
          status: store.launch_status,
          ready: checks.all? { |item| item[:ready] },
          checks: checks
        }
      end

      private

      attr_reader :store

      def check(key, ready)
        { key: key, ready: ready }
      end

      def business_details?
        store.customer_support_email.present?
      end

      def product?
        store.products.published.exists?
      end

      def payment_method?
        store.payment_methods.active.available.exists?
      end

      def shipping?
        store.countries_with_shipping_coverage.where(id: store.default_country_id).exists?
      end

      def legal_documents?
        store.policies.count { |policy| policy.body.to_plain_text.strip.present? } >= 3
      end

      def homepage?
        store.storefront_pages.where.not(published_at: nil).exists?
      end
    end
  end
end
