require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PoliciesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:policy) { create(:policy, owner: store, name: 'Returns') }
  let!(:other_policy) { create(:policy, owner: create(:store), name: 'Other store') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns only policies owned by the selected store' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      policy_ids = json_response.fetch('data').pluck('id')
      expect(policy_ids).to include(policy.prefixed_id)
      expect(policy_ids).not_to include(other_policy.prefixed_id)
    end
  end

  describe 'PATCH #update' do
    it 'updates the merchant-authored legal document' do
      patch :update, params: { id: policy.prefixed_id, body: 'Returns within 14 days.' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(policy.reload.body.to_plain_text).to eq('Returns within 14 days.')
    end

    it 'does not expose another store policy' do
      patch :update, params: { id: other_policy.prefixed_id, body: 'Leaked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_policy.reload.body.to_plain_text).not_to eq('Leaked')
    end
  end
end
