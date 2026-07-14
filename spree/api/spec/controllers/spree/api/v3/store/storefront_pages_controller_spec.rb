require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StorefrontPagesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  let(:page) do
    store.storefront_pages.create!(
      slug: 'home',
      title: 'Homepage',
      draft_document: Spree::StorefrontPage.default_document
    )
  end

  it 'returns not found until a page is published' do
    page

    get :show

    expect(response).to have_http_status(:not_found)
  end

  it 'returns only the published snapshot' do
    page.publish!(user: create(:admin_user))

    get :show

    expect(response).to have_http_status(:ok)
    expect(json_response['document']).to eq(page.published_document)
    expect(json_response).not_to have_key('draft_document')
    expect(json_response).not_to have_key('published_document')
  end

  it 'does not expose a page belonging to another store' do
    other_store = create(:store)
    other_store.storefront_pages.create!(
      slug: 'home',
      title: 'Other homepage',
      draft_document: Spree::StorefrontPage.default_document,
      published_document: Spree::StorefrontPage.default_document,
      published_at: Time.current
    )

    get :show

    expect(response).to have_http_status(:not_found)
  end
end
