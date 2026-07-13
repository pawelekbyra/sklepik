# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Public self-service Store Factory onboarding. Creates a new admin
        # and store atomically, then starts storefront provisioning.
        class SignupsController < Admin::BaseController
          include Spree::Api::V3::Admin::AuthCookies

          skip_before_action :authenticate_admin!
          skip_scope_check!
          before_action :require_signup_enabled!

          rate_limit to: Spree::Api::Config[:rate_limit_login],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: :create,
                     with: RATE_LIMIT_RESPONSE

          def create
            user, store, run = create_signup!

            Spree::Provisioning::ProvisionStoreJob.perform_later(run.id)
            set_refresh_cookie(Spree::RefreshToken.create_for(user, request_env: request_env_for_token))

            render json: auth_response(user, store).merge(
              store_id: store.prefixed_id,
              provisioning_run_id: run.prefixed_id
            ), status: :created
          rescue ActiveRecord::RecordInvalid => e
            render_validation_error(e.record.errors)
          end

          private

          def create_signup!
            ActiveRecord::Base.transaction do
              user = create_user!
              store = create_store!(user)
              run = store.provisioning_runs.create!(
                template_repo: Spree::Provisioning::Settings.template_repo
              )
              [user, store, run]
            end
          end

          def create_user!
            attributes = params.permit(:email, :password, :password_confirmation)
            user = Spree.admin_user_class.new(attributes)
            SignupPasswordValidator.validate!(
              user, password: attributes[:password], confirmation: attributes[:password_confirmation]
            )
            user.save!
            user
          end

          def create_store!(user)
            store = Spree::Store.new(name: params[:store_name], mail_from_address: params[:email])
            store.code = unique_code(store.name) if store.code.blank?
            store.url = "#{store.code}.vercel.app"
            store.save!
            store.add_user(user)
            store
          end

          def require_signup_enabled!
            return if signup_enabled?

            render_error(
              code: ERROR_CODES[:not_found],
              message: 'Store signup is not enabled.',
              status: :not_found
            )
          end

          def signup_enabled?
            ActiveModel::Type::Boolean.new.cast(ENV.fetch('STORE_SIGNUP_ENABLED', 'false'))
          end

          def unique_code(name)
            base = name.to_s.parameterize.presence || 'store'
            code = base
            code = "#{base}-#{SecureRandom.hex(2)}" while Spree::Store.unscoped.exists?(code: code)
            code
          end

          def auth_response(user, store)
            {
              token: generate_jwt(user, audience: JWT_AUDIENCE_ADMIN),
              user: admin_user_serializer.new(user, params: serializer_params(store)).to_h
            }
          end

          def serializer_params(store)
            {
              store: store,
              locale: current_locale,
              currency: current_currency,
              user: nil,
              includes: []
            }
          end

          def admin_user_serializer
            Spree.api.admin_admin_user_serializer
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end

          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end
        end
      end
    end
  end
end
