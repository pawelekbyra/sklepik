module Spree
  module Provisioning
    class ProvisionStoreJob < ::Spree::BaseJob
      queue_as Spree.queues.default

      # Provisioning talks to two external APIs across several sequential
      # steps (repo generation + deploy wait alone can take minutes) — not
      # safe to blanket-retry on any StandardError like some jobs do, since a
      # partial success (e.g. repo created, Vercel project failed) would
      # duplicate the repo-creation step on replay. Etap 3 of the plan
      # (docs/plans/store-factory.md) is where per-step idempotency/resumption
      # gets built; today a failed run is surfaced via its `error_message`
      # and the admin retries by starting a fresh run.
      discard_on Spree::Provisioning::GithubClient::Error
      discard_on Spree::Provisioning::VercelClient::Error

      def perform(run_id)
        run = Spree::ProvisioningRun.find(run_id)
        Spree::Provisioning::ProvisionStore.call(run)
      end
    end
  end
end
