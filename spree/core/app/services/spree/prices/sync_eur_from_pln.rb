module Spree
  module Prices
    # Recomputes EUR base prices from PLN base prices for a store at the current
    # NBP rate, rounding to a psychological .99 price. Runs entirely server-side
    # against the models — no Admin API secret, no HTTP round-trip to our own
    # API. This replaces the +sync-eur-prices+ Vercel cron that used to live in
    # the storefront repo and carried a broad Admin API secret in client env.
    #
    # "Best effort" pricing, deliberately not live conversion at checkout: the
    # rate is applied once, written as ordinary +Spree::Price+ rows, and any
    # product can still be overridden manually in the admin afterwards.
    #
    # @param store [Spree::Store] the store whose PLN prices drive EUR prices
    # @param rate [Float, nil] PLN per 1 EUR; fetched from NBP when nil (kept
    #   injectable so the computation is testable without the network)
    # @param source_currency [String] base currency to convert from
    # @param target_currency [String] currency to write
    # @return [Spree::ServiceModule::Result] success carries
    #   `{ rate:, source_price_count:, target_price_count: }`
    class SyncEurFromPln
      prepend Spree::ServiceModule::Base

      def call(store:, rate: nil, source_currency: 'PLN', target_currency: 'EUR')
        rate ||= begin
          result = Spree::Nbp::EurPlnRate.call
          return result if result.failure?

          result.value
        end

        source_prices = base_prices_for(store, source_currency)

        rows = source_prices.filter_map do |price|
          amount = price.amount
          next if amount.nil? || amount <= 0

          {
            variant_id: price.variant_id,
            currency: target_currency,
            amount: psychological_99(amount / rate)
          }
        end

        upsert = Spree::Prices::BulkUpsert.call(rows: rows)
        return upsert if upsert.failure?

        success(
          rate: rate,
          source_price_count: source_prices.size,
          target_price_count: upsert.value[:price_count]
        )
      end

      private

      def base_prices_for(store, currency)
        Spree::Price.
          base_prices.
          with_currency(currency).
          joins(variant: :product).
          where(Spree::Product.table_name => { store_id: store.id })
      end

      # Mirrors the storefront's former rounding: round to the nearest whole
      # unit (min 1), then land on X.99.
      def psychological_99(amount)
        rounded = [1, amount.round].max
        (rounded - 0.01).round(2)
      end
    end
  end
end
