# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Stores API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/stores' do
    get 'List the stores this admin belongs to' do
      tags 'Stores'
      produces 'application/json'
      security [{ bearer_auth: [] }]
      description 'Returns every store the authenticated admin holds a role on — the list a store switcher picks from before one is selected.'

      admin_sdk_example 'stores/list'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'stores the admin belongs to' do
        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Store' } }
               }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |s| s['id'] }).to include(admin_user.stores.first.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a new store' do
      tags 'Stores'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearer_auth: [] }]
      description 'Creates a new store and grants the requesting admin the admin role on it. Requires the admin to already hold the admin role on at least one existing store.'

      admin_sdk_example 'stores/create'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Second Shop' },
          url: { type: :string, example: 'second-shop.example.com' },
          mail_from_address: { type: :string, example: 'orders@second-shop.example.com' },
          default_currency: { type: :string, example: 'USD' },
          default_locale: { type: :string, example: 'en' },
          default_country_iso: { type: :string, example: 'US' }
        },
        required: %w[name url mail_from_address]
      }

      response '201', 'store created' do
        let(:body) do
          {
            name: 'Second Shop',
            url: 'second-shop.example.com',
            mail_from_address: 'orders@second-shop.example.com',
            default_currency: 'USD',
            default_locale: 'en',
            default_country_iso: 'US'
          }
        end

        # `default_country_iso` drives the `after_create` default-market
        # bootstrap (`Spree::Stores::Markets#ensure_default_market`), which
        # requires the country to already have shipping coverage somewhere
        # in the system (`Spree::MarketCountry#country_covered_by_shipping_zone`)
        # — same fixture shape as `spree/core/spec/models/spree/store_spec.rb`.
        before do
          country = Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US')
          zone = create(:zone, name: 'US Zone', kind: 'country')
          zone.zone_members.create!(zoneable: country)
          create(:shipping_method, zones: [zone])
        end

        schema '$ref' => '#/components/schemas/Store'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Second Shop')
          expect(admin_user.stores.reload.map(&:name)).to include('Second Shop')
        end
      end

      response '403', 'admin has no existing store to bootstrap from' do
        let(:Authorization) do
          non_admin = create(:admin_user, :without_admin_role)
          "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(non_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}"
        end
        let(:body) { { name: 'Second Shop', url: 'second-shop.example.com', mail_from_address: 'orders@second-shop.example.com' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '422', 'validation error' do
        let(:body) { { name: '', url: '', mail_from_address: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  describe 'POST /api/v3/admin/stores atomicity' do
    let(:params) do
      {
        name: 'Atomic Shop',
        url: 'atomic-shop.example.com',
        mail_from_address: 'orders@atomic-shop.example.com'
      }
    end

    before do
      admin_user
      store

      allow_any_instance_of(Spree::Store).to receive(:add_user) do
        membership = Spree::RoleUser.new
        membership.errors.add(:role, :blank)
        raise ActiveRecord::RecordInvalid.new(membership)
      end
    end

    it 'rolls the store back when assigning its owner fails' do
      expect do
        post '/api/v3/admin/stores',
             params: params.to_json,
             headers: {
               'Authorization' => "Bearer #{admin_jwt_token}",
               'Content-Type' => 'application/json'
             }
      end.not_to change(Spree::Store.unscoped, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body).dig('error', 'details', 'role')).to be_present
      expect(Spree::Store.unscoped.find_by(url: params[:url])).to be_nil
    end
  end
end
