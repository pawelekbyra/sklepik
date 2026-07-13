require 'spec_helper'

RSpec.describe Spree::Stores::ReadinessCheck do
  subject(:result) { described_class.call(store: store) }

  let(:store) { create(:store) }

  before do
    allow(store).to receive_message_chain(:products, :published, :exists?).and_return(product_ready)
    allow(store).to receive_message_chain(:payment_methods, :active, :available, :exists?).and_return(payment_ready)
    allow(store).to receive_message_chain(:countries_with_shipping_coverage, :where, :exists?).and_return(shipping_ready)
    policy_body = instance_double(ActionText::RichText, to_plain_text: 'Merchant-authored policy')
    policies = Array.new(legal_ready ? 3 : 0) { instance_double(Spree::Policy, body: policy_body) }
    allow(store).to receive(:policies).and_return(policies)
    allow(store).to receive_message_chain(:storefront_pages, :where, :not, :exists?).and_return(homepage_ready)
  end

  let(:product_ready) { true }
  let(:payment_ready) { true }
  let(:shipping_ready) { true }
  let(:legal_ready) { true }
  let(:homepage_ready) { true }

  context 'when every launch requirement is met' do
    before { store.customer_support_email = 'owner@example.com' }

    it 'reports the store as ready and includes its launch status' do
      expect(result).to include(status: 'live', ready: true)
      expect(result[:checks].map { |check| check[:key] }).to contain_exactly(
        'business_details', 'product', 'payment_method', 'shipping', 'legal_documents', 'homepage'
      )
    end
  end

  context 'when a requirement is missing' do
    let(:payment_ready) { false }

    before { store.customer_support_email = 'owner@example.com' }

    it 'identifies the missing requirement and remains not ready' do
      expect(result[:ready]).to be(false)
      expect(result[:checks]).to include(key: 'payment_method', ready: false)
    end
  end
end
