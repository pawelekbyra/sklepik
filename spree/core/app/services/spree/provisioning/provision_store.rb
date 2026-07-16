# frozen_string_literal: true

require 'uri'

module Spree
  module Provisioning
    # Orchestrates one end-to-end provisioning attempt for a store's
    # independent storefront: GitHub repo (from template) -> Vercel project
    # -> env vars -> wait for the first deployment. Each stage updates the
    # +ProvisioningRun+ via +advance!+ so the admin panel can poll progress.
    #
    # Deliberately synchronous/blocking within the job that calls it (not its
    # own state machine with persisted resumption) — see
    # docs/plans/store-factory.md Migration Path for why: this is Etap 2/3,
    # a single deterministic attempt is enough before building the fuller
    # ProvisioningRun/ProvisioningStep retry machinery the plan describes for
    # Etap 3+. On failure the run is marked +failed+ with the error message;
    # retrying today means enqueueing a fresh run, not resuming this one.
    class ProvisionStore
      def self.call(run)
        new(run).call
      end

      def initialize(run, github: GithubClient.new, vercel: VercelClient.new)
        @run = run
        @github = github
        @vercel = vercel
      end

      def call
        repo_full_name = create_repository
        project = create_vercel_project(repo_full_name)
        configure_environment(project['id'])
        deployment_url = wait_for_deployment(project['id'], repo_full_name)
        activate!(repo_full_name, project['id'], deployment_url)
      rescue GithubClient::Error, VercelClient::Error, Timeout::Error, URI::InvalidURIError,
             ActiveRecord::RecordInvalid => e
        fail!(e)
      end

      private

      def create_repository
        @run.advance!('creating_repository', step_status: 'in_progress')
        repo_name = @run.store.code.presence || "store-#{@run.store_id}"
        full_name = @github.create_from_template(
          template_repo: @run.template_repo,
          new_repo_name: repo_name
        )
        wait_for_repository(full_name)
        # Needed later to explicitly trigger the first deployment — see
        # VercelClient#trigger_deployment for why that's necessary at all.
        @repo_id = @github.fetch_repo_id(full_name)
        @run.advance!('creating_repository', step_status: 'done')
        full_name
      end

      def wait_for_repository(full_name)
        # GitHub's "generate from template" is async; give it a few tries
        # before handing an incompletely-materialized repo to Vercel.
        10.times do
          break if @github.repo_ready?(full_name)

          sleep 2
        end
      end

      def activate!(repo_full_name, project_id, deployment_url)
        ActiveRecord::Base.transaction do
          @run.store.update!(url: URI.parse(deployment_url).host)
          @run.update!(repo_full_name: repo_full_name, vercel_project_id: project_id,
                       deployment_url: deployment_url, status: 'active')
        end
      end

      def fail!(error)
        @run.advance!(@run.status, step_status: 'failed', error_message: error.message)
        Rails.error.report(error, context: { provisioning_run_id: @run.id, store_id: @run.store_id })
        raise error
      end

      def create_vercel_project(repo_full_name)
        @run.advance!('creating_vercel_project', step_status: 'in_progress')
        project = @vercel.create_project(name: repo_full_name.split('/').last, repo_full_name: repo_full_name)
        @run.advance!('creating_vercel_project', step_status: 'done')
        project
      end

      def configure_environment(project_id)
        @run.advance!('configuring_environment', step_status: 'in_progress')

        @vercel.set_env(project_id: project_id, key: 'SPREE_API_URL', value: Settings.default_spree_api_url)
        @vercel.set_env(project_id: project_id, key: 'SPREE_PUBLISHABLE_KEY', value: publishable_key_for_store)
        @vercel.set_env(project_id: project_id, key: 'NEXT_PUBLIC_STORE_NAME', value: @run.store.name.to_s)

        @run.advance!('configuring_environment', step_status: 'done')
      end

      # Every store needs a publishable API key for its storefront to read
      # the Store API — reuse an existing active one rather than minting a
      # fresh key per provisioning attempt, so a retry doesn't leave orphaned
      # keys behind.
      def publishable_key_for_store
        key = @run.store.api_keys.publishable.active.first
        key ||= @run.store.api_keys.create!(key_type: 'publishable', name: 'Storefront (auto-provisioned)')
        key.token
      end

      def wait_for_deployment(project_id, repo_full_name)
        @run.advance!('deploying', step_status: 'in_progress')

        @vercel.trigger_deployment(
          project_id: project_id,
          repo_id: @repo_id,
          name: repo_full_name.split('/').last
        )

        deployment_url = nil
        30.times do
          deployment = @vercel.latest_deployment(project_id)
          ready_state = deployment && deployment['readyState']

          if ready_state == 'READY'
            deployment_url = "https://#{deployment['url']}"
            break
          elsif %w[ERROR CANCELED].include?(ready_state)
            raise VercelClient::Error,
                  "Vercel deployment #{deployment['id']} failed to build (state: #{ready_state}): " \
                  "#{deployment['errorMessage'].presence || 'Vercel did not return an error message — check the build logs in the dashboard'}"
          end

          sleep 10
        end

        raise Timeout::Error, 'Vercel deployment did not become ready in time' unless deployment_url

        @run.advance!('deploying', step_status: 'done')
        deployment_url
      end
    end
  end
end
