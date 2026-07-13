require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let!(:product2) { create(:product, status: 'active') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::HttpCaching' do
    describe 'Vary headers' do
      context 'for guest users' do
        it 'sets Vary header for CDN caching, including the store-specific api key' do
          get :index

          expect(response.headers['Vary']).to eq(
            'Accept, X-Spree-API-Key, X-Spree-Store-Id, X-Spree-Country, ' \
            'X-Spree-Currency, X-Spree-Locale, X-Spree-Channel'
          )
        end
      end

      context 'for authenticated users' do
        before do
          request.headers['Authorization'] = "Bearer #{jwt_token}"
        end

        it 'sets Cache-Control to private, no-store' do
          get :index

          expect(response.headers['Cache-Control']).to include('private')
          expect(response.headers['Cache-Control']).to include('no-store')
        end

        it 'does not set Vary header' do
          get :index

          expect(response.headers['Vary']).to be_nil
        end
      end
    end

    describe '#cache_collection' do
      context 'for guest users' do
        it 'sets ETag header' do
          get :index

          expect(response.headers['ETag']).to be_present
        end

        it 'sets Cache-Control with public and max-age' do
          get :index

          expect(response.headers['Cache-Control']).to include('public')
          expect(response.headers['Cache-Control']).to include('max-age=300')
        end

        it 'sets stale-while-revalidate' do
          get :index

          expect(response.headers['Cache-Control']).to include('stale-while-revalidate=30')
        end

        it 'returns 200 when ETag does not match' do
          request.headers['If-None-Match'] = '"stale-etag"'
          get :index

          expect(response).to have_http_status(:ok)
        end

        it 'returns 304 Not Modified when the collection has not changed' do
          get :index
          etag = response.headers['ETag']

          request.headers['If-None-Match'] = etag
          get :index

          expect(response).to have_http_status(:not_modified)
        end

        it 'changes ETag when a product is updated' do
          get :index
          original_etag = response.headers['ETag']

          Timecop.travel(1.minute.from_now) do
            product.update!(name: 'Updated Product Name')

            get :index
            new_etag = response.headers['ETag']

            expect(new_etag).not_to eq(original_etag)
          end
        end

        it 'changes ETag when a product is added' do
          get :index
          original_etag = response.headers['ETag']

          create(:product, status: 'active')

          get :index
          new_etag = response.headers['ETag']

          expect(new_etag).not_to eq(original_etag)
        end

        it 'changes ETag when query params change' do
          get :index
          original_etag = response.headers['ETag']

          get :index, params: { q: { name_cont: 'test' } }
          filtered_etag = response.headers['ETag']

          expect(filtered_etag).not_to eq(original_etag)
        end

        it 'changes ETag when page changes' do
          get :index, params: { page: 1, limit: 1 }
          page1_etag = response.headers['ETag']

          get :index, params: { page: 2, limit: 1 }
          page2_etag = response.headers['ETag']

          expect(page2_etag).not_to eq(page1_etag)
        end

        it 'changes ETag when currency changes' do
          get :index
          original_etag = response.headers['ETag']

          request.headers['x-spree-currency'] = 'EUR'
          get :index
          eur_etag = response.headers['ETag']

          expect(eur_etag).not_to eq(original_etag)
        end

        it 'scopes the ETag to the store so two stores never collide on the same cache key' do
          get :index
          store_a_etag = response.headers['ETag']

          other_store = create(:store, url: 'second-store.example.com', default: false)
          other_key = create(:api_key, :publishable, store: other_store)
          allow_any_instance_of(Spree::Api::V3::BaseController).to receive(:current_store).and_return(other_store)
          request.headers['X-Spree-Api-Key'] = other_key.token

          get :index
          store_b_etag = response.headers['ETag']

          expect(store_b_etag).not_to eq(store_a_etag)
        end

        it 'changes ETag when channel changes' do
          channel = create(:channel, store: store, code: 'pos')
          channel.add_products([product.id, product2.id])

          get :index
          default_channel_etag = response.headers['ETag']

          request.headers['X-Spree-Channel'] = channel.code
          get :index
          pos_channel_etag = response.headers['ETag']

          expect(pos_channel_etag).not_to eq(default_channel_etag)
        end
      end

      context 'for authenticated users' do
        before do
          request.headers['Authorization'] = "Bearer #{jwt_token}"
        end

        it 'does not set ETag header' do
          get :index

          expect(response.headers['ETag']).to be_nil
        end

        it 'does not return 304' do
          get :index

          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe '#cache_resource' do
      context 'for guest users' do
        it 'sets ETag header' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['ETag']).to be_present
        end

        it 'sets Cache-Control with public' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['Cache-Control']).to include('public')
        end

        it 'returns 304 Not Modified when resource has not changed' do
          get :show, params: { id: product.prefixed_id }
          etag = response.headers['ETag']

          request.headers['If-None-Match'] = etag
          get :show, params: { id: product.prefixed_id }

          expect(response).to have_http_status(:not_modified)
        end

        it 'returns 200 when resource has changed' do
          get :show, params: { id: product.prefixed_id }
          etag = response.headers['ETag']

          product.update!(name: 'Updated Name')

          request.headers['If-None-Match'] = etag
          get :show, params: { id: product.prefixed_id }

          expect(response).to have_http_status(:ok)
        end

        it 'changes ETag when channel changes even if the resource is unchanged' do
          channel = create(:channel, store: store, code: 'wholesale')
          channel.add_products(product.id)

          get :show, params: { id: product.prefixed_id }
          default_channel_etag = response.headers['ETag']

          request.headers['X-Spree-Channel'] = channel.code
          get :show, params: { id: product.prefixed_id }
          wholesale_etag = response.headers['ETag']

          expect(wholesale_etag).not_to eq(default_channel_etag)
        end
      end

      context 'for authenticated users' do
        before do
          request.headers['Authorization'] = "Bearer #{jwt_token}"
        end

        it 'does not set ETag header' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['ETag']).to be_nil
        end

        it 'sets Cache-Control to private, no-store' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['Cache-Control']).to include('private')
          expect(response.headers['Cache-Control']).to include('no-store')
        end
      end
    end

    describe 'tenant cache keys' do
      let(:market_a) { instance_double(Spree::Market, cache_key_with_version: 'markets/1-1') }
      let(:market_b) { instance_double(Spree::Market, cache_key_with_version: 'markets/2-1') }

      before do
        allow(Spree::Current).to receive(:channel).and_return(store.default_channel)
        allow(controller).to receive(:current_currency).and_return('USD')
        allow(controller).to receive(:current_locale).and_return('en')
      end

      it 'includes the resolved store in collection cache keys' do
        other_store = create(:store)
        allow(Spree::Current).to receive(:market).and_return(nil)

        allow(controller).to receive(:current_store).and_return(store)
        store_key = controller.send(:collection_cache_key, [product])

        allow(controller).to receive(:current_store).and_return(other_store)
        other_store_key = controller.send(:collection_cache_key, [product])

        expect(other_store_key).not_to eq(store_key)
      end

      it 'includes the resolved market in resource cache keys' do
        allow(Spree::Current).to receive(:market).and_return(market_a)
        market_a_key = controller.send(:resource_cache_key, product)

        allow(Spree::Current).to receive(:market).and_return(market_b)
        market_b_key = controller.send(:resource_cache_key, product)

        expect(market_b_key).not_to eq(market_a_key)
      end
    end
  end
end
