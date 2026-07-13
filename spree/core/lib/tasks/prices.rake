namespace :spree do
  namespace :prices do
    # Recomputes EUR base prices from PLN base prices for every store at the
    # current NBP rate. Replaces the storefront's +sync-eur-prices+ Vercel cron
    # (which carried a broad Admin API secret in client env) — this runs
    # server-side against the models with no external credential.
    #
    # Schedule it from the backend (sidekiq-cron / system cron), not the
    # storefront. Idempotent: re-running upserts the same rows.
    #
    # ENV vars:
    #   STORE_ID        — prefixed id of a single store to sync (default: all stores)
    #   EUR_PLN_RATE    — override the rate instead of fetching NBP (mainly for testing)
    desc 'Recompute EUR base prices from PLN base prices at the current NBP rate'
    task sync_eur_from_pln: :environment do
      rate = ENV['EUR_PLN_RATE'].presence&.to_f

      stores = if ENV['STORE_ID'].present?
                 [Spree::Store.find_by_prefix_id!(ENV['STORE_ID'])]
               else
                 Spree::Store.all
               end

      stores.each do |store|
        result = Spree::Prices::SyncEurFromPln.call(store: store, rate: rate)

        if result.success?
          value = result.value
          puts "[#{store.code}] rate=#{value[:rate]} PLN→EUR: #{value[:source_price_count]} source prices, #{value[:target_price_count]} EUR rows written."
        else
          warn "[#{store.code}] EUR sync failed: #{result.error}"
        end
      end
    end
  end
end
