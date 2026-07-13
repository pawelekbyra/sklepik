require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StoreController, type: :controller do

  render_views

  let(:first_store) { @default_store }
  let(:second_store) { create(:store, name: 'Second Store', url: 'second-store.example.com') }
  let(:first_key) { create(:api_key, :publishable, store: first_store) }
  let(:second_key) { create(:api_key, :publishable, store: second_store) }

  before do
    request.host = 'shared-api.example.com'
  end

  it 'selects each store from its publishable key on a shared API host' do
    allow(Spree::Current).to receive(:store=).and_call_original
    request.headers['X-Spree-Api-Key'] = second_key.token

    get :show

    expect(response).to have_http_status(:ok)
    expect(json_response['name']).to eq(second_store.name)
    expect(controller.current_store).to eq(second_store)
    expect(Spree::Current).to have_received(:store=).with(second_store)
  end

  it 'selects the first store when its key is used after another tenant request' do
    Spree::Current.store = second_store
    request.headers['X-Spree-Api-Key'] = first_key.token

    get :show

    expect(response).to have_http_status(:ok)
    expect(json_response['name']).to eq(first_store.name)
    expect(controller.current_store).to eq(first_store)
  end

  it 'accepts a matching explicit store id' do
    request.headers['X-Spree-Api-Key'] = second_key.token
    request.headers['X-Spree-Store-Id'] = second_store.prefixed_id

    get :show

    expect(response).to have_http_status(:ok)
    expect(json_response['name']).to eq(second_store.name)
  end

  it 'rejects a store id belonging to a different store' do
    request.headers['X-Spree-Api-Key'] = second_key.token
    request.headers['X-Spree-Store-Id'] = first_store.prefixed_id

    get :show

    expect(response).to have_http_status(:unauthorized)
    expect(json_response.dig('error', 'code')).to eq('invalid_token')
  end

  it 'rejects a key when the request host is assigned to a different store' do
    first_store.update!(url: 'https://first-store.example.com:443/shop')
    request.host = 'first-store.example.com'
    request.headers['X-Spree-Api-Key'] = second_key.token

    get :show

    expect(response).to have_http_status(:unauthorized)
    expect(json_response.dig('error', 'code')).to eq('invalid_token')
  end

  it 'rejects a revoked publishable key' do
    second_key.revoke!
    request.headers['X-Spree-Api-Key'] = second_key.token

    get :show

    expect(response).to have_http_status(:unauthorized)
  end
end
