require 'net/http'
require 'json'

module Spree
  module Nbp
    # Fetches the current EUR/PLN mid rate from the Polish central bank (NBP).
    # Isolated from +Spree::Prices::SyncEurFromPln+ so the price computation is
    # testable without hitting the network — pass the rate in, or let the sync
    # service call this.
    #
    # @return [Spree::ServiceModule::Result] success carries the mid rate
    #   (PLN per 1 EUR) as a Float.
    class EurPlnRate
      prepend Spree::ServiceModule::Base

      RATE_URL = 'https://api.nbp.pl/api/exchangerates/rates/a/eur/?format=json'.freeze

      def call
        response = Net::HTTP.get_response(URI(RATE_URL))
        return failure(nil, "NBP rate fetch failed: #{response.code}") unless response.is_a?(Net::HTTPSuccess)

        rate = JSON.parse(response.body).dig('rates', 0, 'mid')
        return failure(nil, "NBP response missing a usable mid rate: #{response.body}") unless rate.is_a?(Numeric) && rate.positive?

        success(rate.to_f)
      rescue JSON::ParserError => e
        failure(nil, "NBP response was not valid JSON: #{e.message}")
      end
    end
  end
end
