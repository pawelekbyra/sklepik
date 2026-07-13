require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StorefrontPagesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'creates and returns the store homepage draft' do
      expect { get :show, as: :json }.to change(store.storefront_pages, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response['slug']).to eq('home')
      expect(json_response.dig('draft_document', 'schemaVersion')).to eq(1)
      expect(json_response['published_document']).to be_nil
    end
  end

  describe 'PATCH #update' do
    it 'updates only the draft document' do
      get :show, as: :json
      page = store.storefront_pages.find_by!(slug: 'home')
      document = page.draft_document.deep_dup
      document['sections'].first['preferences']['heading'] = 'My soap studio'

      patch :update, params: {
        title: 'Home',
        lock_version: page.lock_version,
        draft_document: document
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(page.reload.draft_document.dig('sections', 0, 'preferences', 'heading')).to eq('My soap studio')
      expect(page.published_document).to be_nil
    end

    it 'rejects a stale editor session' do
      get :show, as: :json
      page = store.storefront_pages.find_by!(slug: 'home')
      stale_version = page.lock_version
      page.update!(title: 'Changed elsewhere')

      patch :update, params: {
        title: 'Stale title',
        lock_version: stale_version,
        draft_document: page.draft_document
      }, as: :json

      expect(response).to have_http_status(:conflict)
    end
  end

  describe 'POST #publish' do
    it 'promotes the current draft to a public snapshot' do
      get :show, as: :json

      post :publish, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['published_document']).to eq(json_response['draft_document'])
      expect(json_response['published_at']).to be_present
      expect(store.storefront_pages.find_by!(slug: 'home').published_by).to eq(admin_user)
    end
  end
end
