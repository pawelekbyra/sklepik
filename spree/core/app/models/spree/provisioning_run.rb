module Spree
  # Tracks one attempt at automatically provisioning an independent storefront
  # application for a +Store+ — a GitHub repo (copied from a template) plus a
  # linked Vercel project, env vars and a deployment. See
  # +docs/plans/store-factory.md+ (Etap 2/3) for the design this implements.
  #
  # A store can be re-provisioned (e.g. after a failed attempt), so this is a
  # log of attempts, not a 1:1 extension of +Store+ — always read the latest
  # run via +store.provisioning_runs.order(created_at: :desc).first+.
  class ProvisioningRun < Spree.base_class
    has_prefix_id :provrun

    STATUSES = %w[
      pending
      creating_repository
      creating_vercel_project
      configuring_environment
      deploying
      active
      failed
    ].freeze

    belongs_to :store, class_name: 'Spree::Store'
    has_many :steps, -> { order(:id) }, class_name: 'Spree::ProvisioningStep',
                                         foreign_key: :run_id, dependent: :destroy, inverse_of: :run

    validates :status, inclusion: { in: STATUSES }
    validates :template_repo, presence: true

    after_initialize { self.status ||= 'pending' }

    def failed?
      status == 'failed'
    end

    def active?
      status == 'active'
    end

    # Records a step transition and mirrors the stage name onto the run's own
    # +status+ so polling clients only need to read the run, not join every
    # step. +step_status+ is the step's own lifecycle (+in_progress+/+done+/
    # +failed+), independent of +STATUSES+ (which names *stages*, i.e. steps).
    def advance!(step_name, step_status: 'done', error_message: nil)
      step = steps.find_or_initialize_by(name: step_name)
      step.status = step_status
      step.started_at ||= Time.current
      step.finished_at = Time.current if %w[done failed].include?(step_status)
      step.error_message = error_message
      step.save!

      update!(status: step_status == 'failed' ? 'failed' : step_name, error_message: error_message)
    end
  end
end
