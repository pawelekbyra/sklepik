# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Enforces signup password rules independently of the configured admin user class.
        class SignupPasswordValidator
          MINIMUM_LENGTH = 8

          def self.validate!(user, password:, confirmation:)
            password = password.to_s
            user.errors.add(:password, :blank) if password.blank?
            if password.present? && password.length < MINIMUM_LENGTH
              user.errors.add(:password, :too_short, count: MINIMUM_LENGTH)
            end
            if password != confirmation.to_s
              user.errors.add(:password_confirmation, :confirmation, attribute: 'Password')
            end
            raise ActiveRecord::RecordInvalid, user if user.errors.any?
          end
        end
      end
    end
  end
end
