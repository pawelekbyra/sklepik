module Spree
  module Api
    module V3
      module Admin
        # Nested singleton under a store: `POST` starts a provisioning attempt
        # (repo + Vercel project), `GET` polls the latest one. Like
        # `StoresController`, deliberately not scoped through `current_store`
        # — an admin operates on a store they just created (or any store they
        # belong to), not necessarily the one currently selected in the panel.
        class ProvisioningRunsController < Admin::BaseController
          skip_before_action :authenticate_admin!
          before_action :require_authentication!
          before_action :set_store
          skip_scope_check!

          # GET /api/v3/admin/stores/:store_id/provisioning_run
          def show
            run = @store.provisioning_runs.order(created_at: :desc).first
            return render_error(code: ERROR_CODES[:record_not_found], message: 'No provisioning run yet.', status: :not_found) unless run

            render json: serialize_resource(run)
          end

          # POST /api/v3/admin/stores/:store_id/provisioning_run
          def create
            run = @store.provisioning_runs.create!(template_repo: Spree::Provisioning::Settings.template_repo)
            Spree::Provisioning::ProvisionStoreJob.perform_later(run.id)

            render json: serialize_resource(run), status: :created
          end

          private

          def set_store
            @store = current_user.stores.find_by_prefix_id!(params[:store_id])
          end

          def serializer_class
            Spree.api.admin_provisioning_run_serializer
          end
        end
      end
    end
  end
end
