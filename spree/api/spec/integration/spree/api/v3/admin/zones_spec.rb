# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Zones API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:zone) { create(:zone, name: 'EU') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/zones' do
    get 'List zones' do
      tags 'Zones'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of zones.'
      admin_scope :read, :zones

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'zones found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Zone')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a zone' do
      tags 'Zones'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a zone.'
      admin_scope :write, :zones

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Americas' },
          description: { type: :string },
          default_tax: { type: :boolean, example: false },
        },
        required: %w[name]
      }

      response '201', 'zone created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Americas' } }

        schema '$ref' => '#/components/schemas/Zone'

        run_test!
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/zones/{id}' do
    get 'Get a zone' do
      tags 'Zones'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single zone by ID.'
      admin_scope :read, :zones

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Zone ID'

      response '200', 'zone found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { zone.prefixed_id }

        schema '$ref' => '#/components/schemas/Zone'

        run_test!
      end

      response '404', 'zone not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'zn_nonexistent' }

        run_test!
      end
    end

    patch 'Update a zone' do
      tags 'Zones'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a zone.'
      admin_scope :write, :zones

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Zone ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          default_tax: { type: :boolean },
        },
      }

      response '200', 'zone updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { zone.prefixed_id }
        let(:body) { { name: 'European Union' } }

        schema '$ref' => '#/components/schemas/Zone'

        run_test!
      end
    end

    delete 'Delete a zone' do
      tags 'Zones'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a zone.'
      admin_scope :delete, :zones

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Zone ID'

      response '204', 'zone deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { zone.prefixed_id }

        run_test!
      end
    end
  end
end
