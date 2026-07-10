# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Rates API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:tax_category) { create(:tax_category, name: 'Standard', store: store) }
  let!(:zone) { create(:zone, name: 'EU') }
  let!(:tax_rate) { create(:tax_rate, name: 'VAT', amount: 0.23, tax_category: tax_category, zone: zone) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/tax_rates' do
    get 'List tax rates' do
      tags 'Tax Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of tax rates.'
      admin_scope :read, :tax_rates

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'tax rates found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('TaxRate')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a tax rate' do
      tags 'Tax Rates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a tax rate.'
      admin_scope :write, :tax_rates

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Reduced VAT' },
          amount: { type: :number, example: 0.1 },
          tax_category_id: { type: :string, example: 'tc_abc123' },
          zone_id: { type: :string, example: 'zn_abc123' },
          included_in_price: { type: :boolean, example: false },
        },
        required: %w[name amount tax_category_id]
      }

      response '201', 'tax rate created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Reduced VAT', amount: 0.1, tax_category_id: tax_category.prefixed_id } }

        schema '$ref' => '#/components/schemas/TaxRate'

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

  path '/api/v3/admin/tax_rates/{id}' do
    get 'Get a tax rate' do
      tags 'Tax Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single tax rate by ID.'
      admin_scope :read, :tax_rates

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Tax Rate ID'

      response '200', 'tax rate found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { tax_rate.prefixed_id }

        schema '$ref' => '#/components/schemas/TaxRate'

        run_test!
      end

      response '404', 'tax rate not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'tr_nonexistent' }

        run_test!
      end
    end

    patch 'Update a tax rate' do
      tags 'Tax Rates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a tax rate.'
      admin_scope :write, :tax_rates

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Tax Rate ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          amount: { type: :number },
          tax_category_id: { type: :string },
          included_in_price: { type: :boolean },
        },
      }

      response '200', 'tax rate updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { tax_rate.prefixed_id }
        let(:body) { { amount: 0.25 } }

        schema '$ref' => '#/components/schemas/TaxRate'

        run_test!
      end
    end

    delete 'Delete a tax rate' do
      tags 'Tax Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a tax rate.'
      admin_scope :delete, :tax_rates

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Tax Rate ID'

      response '204', 'tax rate deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { tax_rate.prefixed_id }

        run_test!
      end
    end
  end
end
