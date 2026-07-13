require 'spec_helper'

module Spree
  describe Stores::FindDefault do
    subject { described_class.new(scope: scope, url: url).execute }

    let!(:store) { @default_store }
    let!(:store_2) { create(:store, url: 'another.com', default_currency: 'GBP') }

    let(:scope) { nil }
    let(:url) { nil }

    before do
      Spree::Current.store = nil
    end

    context 'no arguments' do
      it { expect(subject).to eq(store) }
      it { subject; expect(Spree::Current.store).to eq(store) }
    end

    context 'when the url host matches a store' do
      let(:url) { 'another.com' }

      it 'resolves that store, not the default one' do
        expect(subject).to eq(store_2)
      end

      it 'sets it as the current store' do
        subject
        expect(Spree::Current.store).to eq(store_2)
      end
    end

    context 'when the url has a scheme, port or path' do
      let(:url) { 'https://another.com:443/products' }

      it 'normalizes the host and still matches the store' do
        expect(subject).to eq(store_2)
      end
    end

    context 'when the url host matches no store' do
      let(:url) { 'unmatched-host.example' }

      it 'falls back to the default store' do
        expect(subject).to eq(store)
      end
    end

    context 'with scope' do
      let(:scope) { Spree::Store.where(default_currency: 'GBP') }

      it 'returns the first store in scope' do
        expect(subject).to eq(store_2)
      end
    end

    context 'when no default store exists' do
      before do
        Spree::Store.update_all(default: false)
      end

      it 'returns the first store' do
        expect(subject).to eq(store)
      end
    end
  end
end
