# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Shipping Methods API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:shipping_method) { create(:shipping_method, name: 'Standard') }
  let!(:shipping_category) { Spree::ShippingCategory.first || create(:shipping_category) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/shipping_methods' do
    get 'List shipping methods' do
      tags 'Shipping Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of shipping methods.'
      admin_scope :read, :shipping_methods

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'shipping methods found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('ShippingMethod')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a shipping method' do
      tags 'Shipping Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a shipping method.'
      admin_scope :write, :shipping_methods

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Express' },
          display_on: { type: :string, example: 'both' },
          calculator_type: { type: :string, example: 'Spree::Calculator::Shipping::FlatRate' },
          shipping_category_ids: { type: :array, items: { type: :string } },
        },
        required: %w[name]
      }

      response '201', 'shipping method created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            name: 'Express',
            display_on: 'both',
            calculator_type: 'Spree::Calculator::Shipping::FlatRate',
            shipping_category_ids: [shipping_category.prefixed_id],
          }
        end

        schema '$ref' => '#/components/schemas/ShippingMethod'

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

  path '/api/v3/admin/shipping_methods/{id}' do
    get 'Get a shipping method' do
      tags 'Shipping Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single shipping method by ID.'
      admin_scope :read, :shipping_methods

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipping Method ID'

      response '200', 'shipping method found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { shipping_method.prefixed_id }

        schema '$ref' => '#/components/schemas/ShippingMethod'

        run_test!
      end

      response '404', 'shipping method not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'shm_nonexistent' }

        run_test!
      end
    end

    patch 'Update a shipping method' do
      tags 'Shipping Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a shipping method.'
      admin_scope :write, :shipping_methods

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipping Method ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          display_on: { type: :string },
        },
      }

      response '200', 'shipping method updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { shipping_method.prefixed_id }
        let(:body) { { name: 'Updated Standard' } }

        schema '$ref' => '#/components/schemas/ShippingMethod'

        run_test!
      end
    end

    delete 'Delete a shipping method' do
      tags 'Shipping Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a shipping method.'
      admin_scope :delete, :shipping_methods

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipping Method ID'

      response '204', 'shipping method deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { shipping_method.prefixed_id }

        run_test!
      end
    end
  end
end
