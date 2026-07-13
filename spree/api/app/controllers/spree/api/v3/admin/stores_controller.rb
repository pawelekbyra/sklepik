module Spree
  module Api
    module V3
      module Admin
        # Lists/creates stores across the admin's own memberships — unlike
        # every other admin resource, these two actions are deliberately not
        # scoped to `current_store`: `index` is how the dashboard discovers
        # which stores exist *before* one is selected, and `create` mints a
        # new one. Store-scoped membership is still enforced everywhere else
        # via `AdminAuthentication#require_store_membership!`.
        class StoresController < Admin::BaseController
          skip_before_action :authenticate_admin!
          before_action :require_authentication!
          # JWT-only (dashboard session), no server-to-server API key path yet.
          skip_scope_check!

          # GET /api/v3/admin/stores
          def index
            render json: { data: serialize_collection(current_user.stores) }
          end

          # POST /api/v3/admin/stores
          def create
            return render_access_denied unless current_user.admin_of_any_store?

            store = Spree::Store.new(permitted_params)
            store.code = unique_code(store.name) if store.code.blank?

            # Store creation and owner assignment must be atomic: `add_user`
            # can raise (`find_or_create_by!`), and a store persisted without
            # its creating admin would be orphaned — nobody could enter it.
            ActiveRecord::Base.transaction do
              store.save!
              store.add_user(current_user)
            end

            render json: serialize_resource(store), status: :created
          rescue ActiveRecord::RecordInvalid => e
            render_validation_error(e.record.errors)
          end

          private

          def serializer_class
            Spree.api.admin_store_serializer
          end

          def render_access_denied
            render_error(
              code: ERROR_CODES[:access_denied],
              message: 'Only an existing store admin can create new stores.',
              status: :forbidden
            )
          end

          # `Store#set_default_code` only fills in `'default'` when blank, which
          # would collide with the unique index on every store after the first.
          def unique_code(name)
            base = name.to_s.parameterize.presence || 'store'
            code = base
            code = "#{base}-#{SecureRandom.hex(2)}" while Spree::Store.unscoped.exists?(code: code)
            code
          end

          def permitted_params
            params.permit(
              :name,
              :code,
              :url,
              :mail_from_address,
              :default_currency,
              :default_locale,
              :default_country_iso
            )
          end
        end
      end
    end
  end
end
