require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # `@default_store` is a shared in-memory object across the suite; reload it
  # so each example starts from the persisted state and isn't tripped up by
  # AR change tracking from earlier rolled-back updates.
  before { store.reload }
  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    subject { get :show, as: :json }

    it 'returns ok' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'serializes the prefixed id, not the raw integer DB id' do
      # Regression: a previous version of the serializer listed `:id` in
      # `attributes`, which overrode `BaseSerializer#id` and exposed the
      # raw integer primary key.
      subject
      expect(json_response['id']).to eq(store.prefixed_id)
      expect(json_response['id']).to start_with('store_')
      expect(json_response['id']).not_to eq(store.id)
      expect(json_response['id']).not_to eq(store.id.to_s)
    end

    it 'returns the store name' do
      subject
      expect(json_response['name']).to eq(store.name)
    end

    context 'when the store has no allowed origins' do
      it 'serializes url from storefront_url (falling back to formatted_url)' do
        # Regression: the previous serializer exposed the raw `url` column,
        # not the customer-facing storefront URL.
        subject
        expect(json_response['url']).to eq(store.storefront_url)
        expect(json_response['url']).to eq(store.formatted_url)
      end
    end

    context 'when the store has an allowed origin' do
      before do
        store.allowed_origins.create!(origin: 'https://shop.example.com')
      end

      it 'serializes url from the first allowed origin' do
        subject
        expect(json_response['url']).to eq('https://shop.example.com')
      end
    end

    it 'includes computed default_currency, default_locale and supported lists' do
      subject
      expect(json_response).to include(
        'default_currency' => store.default_currency,
        'default_locale' => store.default_locale
      )
      expect(json_response['supported_currencies']).to be_an(Array)
      expect(json_response['supported_locales']).to be_an(Array)
    end

    it 'exposes the full canonical set of translatable locales' do
      subject
      expect(json_response['available_locales']).to eq(Spree::Locales::ALL)
      # Locales a store can adopt even if not yet in supported_locales.
      expect(json_response['available_locales']).to include('pt-BR', 'zh-CN', 'en-GB')
    end

    it 'exposes the email-section attributes' do
      subject
      expect(json_response).to include(
        'mail_from_address' => store.mail_from_address,
        'customer_support_email' => store.customer_support_email,
        'new_order_notifications_email' => store.new_order_notifications_email,
        'preferred_send_consumer_transactional_emails' => store.preferred_send_consumer_transactional_emails
      )
      expect(json_response).to have_key('mailer_logo_url')
    end

    it 'exposes the storefront-access gating defaults' do
      subject
      expect(json_response).to include(
        'preferred_storefront_access' => store.preferred_storefront_access,
        'preferred_guest_checkout' => store.preferred_guest_checkout
      )
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: params, as: :json }

    context 'with valid params' do
      let(:params) { { name: 'Renamed Store' } }

      it 'updates the store and returns ok' do
        subject
        expect(response).to have_http_status(:ok)
        expect(store.reload.name).to eq('Renamed Store')
      end

      it 'returns the prefixed id in the response (not the raw DB id)' do
        subject
        expect(json_response['id']).to eq(store.prefixed_id)
        expect(json_response['id']).to start_with('store_')
      end

      it 'returns the storefront_url in the url field' do
        subject
        expect(json_response['url']).to eq(store.reload.storefront_url)
      end
    end

    context 'with invalid params' do
      let(:params) { { name: '' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'with email-section params' do
      let(:params) do
        {
          mail_from_address: 'mailer@example.com',
          customer_support_email: 'support@example.com',
          new_order_notifications_email: 'ops@example.com',
          preferred_send_consumer_transactional_emails: false
        }
      end

      it 'updates the email preferences and addresses' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.mail_from_address).to eq('mailer@example.com')
        expect(store.customer_support_email).to eq('support@example.com')
        expect(store.new_order_notifications_email).to eq('ops@example.com')
        expect(store.preferred_send_consumer_transactional_emails).to eq(false)
      end
    end

    context 'with an invalid mail_from_address' do
      let(:params) { { mail_from_address: 'not-an-email' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'with storefront-access gating params' do
      let(:params) { { preferred_storefront_access: 'login_required', preferred_guest_checkout: false } }

      it 'updates the store-wide gating defaults' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.preferred_storefront_access).to eq('login_required')
        expect(store.preferred_guest_checkout).to eq(false)
      end
    end

    context 'with an invalid storefront_access value' do
      let(:params) { { preferred_storefront_access: 'nonsense' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'without authentication' do
      let(:headers) { {} }
      let(:params) { { name: 'Renamed Store' } }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Deliberately does NOT use `include_context 'API v3 Admin authenticated'`:
  # that context stubs `current_store` directly
  # (`allow_any_instance_of(Spree::Api::V3::BaseController).to
  # receive(:current_store)`), which would hide the resolution logic under
  # test here. Builds its own JWT instead.
  describe 'multi-store resolution via X-Spree-Store-Id' do
    let(:store_a) { @default_store }
    let(:store_b) { create(:store) }
    let(:admin) { create(:admin_user, :without_admin_role) }
    let(:token) do
      Spree::Api::V3::TestingSupport.generate_jwt(admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)
    end

    before do
      admin.add_role('admin', store_b)
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'when the header selects a store the admin belongs to' do
      before { request.headers['X-Spree-Store-Id'] = store_b.prefixed_id }

      it 'resolves current_store to the selected store, not the host-based default' do
        get :show, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(store_b.prefixed_id)
      end
    end

    context 'when the header selects a store the admin does not belong to' do
      before { request.headers['X-Spree-Store-Id'] = store_a.prefixed_id }

      it 'returns forbidden instead of leaking the other store' do
        get :show, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the header is a prefixed id that does not exist' do
      before { request.headers['X-Spree-Store-Id'] = 'store_doesnotexist' }

      it 'returns not found instead of silently falling back to the default store' do
        get :show, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without the header' do
      before { admin.add_role('admin', store_a) }

      it 'falls back to host-based resolution (existing single-store behavior)' do
        get :show, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(store_a.prefixed_id)
      end
    end
  end
end
