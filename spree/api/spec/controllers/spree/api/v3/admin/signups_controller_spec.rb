# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Spree::Api::V3::Admin::SignupsController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let(:params) do
    {
      store_name: 'Nowy Sklep',
      email: 'owner@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    }
  end

  describe 'POST #create' do
    context 'when self-service signup is disabled' do
      before { allow(controller).to receive(:signup_enabled?).and_return(false) }

      it 'returns 404 without creating any records or jobs' do
        expect do
          post :create, params: params
        end.not_to change(Spree.admin_user_class, :count)

        expect(response).to have_http_status(:not_found)
        expect(Spree::ProvisioningRun.count).to eq(0)
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
      end
    end

    context 'when self-service signup is enabled' do
      before { allow(controller).to receive(:signup_enabled?).and_return(true) }

      it 'atomically creates an admin, store and provisioning run, then signs the admin in' do
        counts_before = signup_record_counts

        expect { post :create, params: params }
          .to have_enqueued_job(Spree::Provisioning::ProvisionStoreJob)

        expect(signup_record_counts).to eq(counts_before.map { |count| count + 1 })

        expect(response).to have_http_status(:created)
        expect(json_response['token']).to be_present
        expect(json_response['store_id']).to eq(Spree::Store.last.prefixed_id)
        expect(json_response['provisioning_run_id']).to eq(Spree::ProvisioningRun.last.prefixed_id)
        expect(json_response['user']['email']).to eq(params[:email])

        user = Spree.admin_user_class.find_by!(email: params[:email])
        expect(Spree::Store.last.url).to eq('nowy-sklep.vercel.app')
        expect(user.spree_admin?(Spree::Store.last)).to be(true)
      end

      it 'rolls back all records and does not enqueue provisioning when validation fails' do
        invalid_params = params.merge(password_confirmation: 'different-password')

        expect do
          post :create, params: invalid_params
        end.not_to change(Spree.admin_user_class, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Spree::ProvisioningRun.count).to eq(0)
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
      end
    end
  end

  def signup_record_counts
    [Spree.admin_user_class.count, Spree::Store.count, Spree::ProvisioningRun.count]
  end
end
# rubocop:enable Metrics/BlockLength
