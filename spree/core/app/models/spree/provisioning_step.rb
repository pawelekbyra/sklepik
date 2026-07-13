module Spree
  # A single stage of a +ProvisioningRun+ (e.g. "creating_repository"). One
  # row per stage the run has reached — re-running an idempotent step updates
  # the existing row rather than appending a duplicate (see
  # +ProvisioningRun#advance!+).
  class ProvisioningStep < Spree.base_class
    has_prefix_id :provstep

    STATUSES = %w[in_progress done failed].freeze

    belongs_to :run, class_name: 'Spree::ProvisioningRun', foreign_key: :run_id, inverse_of: :steps

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }

    after_initialize { self.status ||= 'in_progress' }
  end
end
