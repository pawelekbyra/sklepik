require 'spec_helper'

module Spree
  module Prices
    describe SyncEurFromPln do
      let!(:store) { create(:store, default_currency: 'PLN', url: 'pln-shop.example.com') }
      let!(:product) { create(:product, store: store, price: 20.0, currency: 'PLN') }
      let(:variant) { product.master }

      subject { described_class.call(store: store, rate: 4.0) }

      def eur_base_price_for(a_variant)
        Spree::Price.base_prices.with_currency('EUR').find_by(variant: a_variant)
      end

      it 'writes an EUR base price computed from the PLN price at the given rate' do
        expect { subject }.to change { eur_base_price_for(variant) }.from(nil)

        # 20 PLN / 4.0 = 5.00 → rounded to a psychological .99 price
        expect(eur_base_price_for(variant).amount).to eq(4.99)
      end

      it 'reports the rate and the number of rows written' do
        result = subject

        expect(result).to be_success
        expect(result.value[:rate]).to eq(4.0)
        expect(result.value[:target_price_count]).to eq(1)
      end

      it 'does not fetch the NBP rate when one is supplied' do
        expect(Spree::Nbp::EurPlnRate).not_to receive(:call)
        subject
      end

      it 'only touches prices in the given store' do
        other_store = create(:store, default_currency: 'PLN', url: 'other-shop.example.com')
        other_product = create(:product, store: other_store, price: 40.0, currency: 'PLN')

        subject

        expect(eur_base_price_for(other_product.master)).to be_nil
      end

      context 'when no rate is supplied' do
        it 'fetches the NBP rate' do
          expect(Spree::Nbp::EurPlnRate).to receive(:call).and_return(
            Spree::ServiceModule::Result.new(true, 4.0, nil)
          )
          described_class.call(store: store)
        end
      end
    end
  end
end
