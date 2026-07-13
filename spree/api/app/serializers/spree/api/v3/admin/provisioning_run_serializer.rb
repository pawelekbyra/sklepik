module Spree
  module Api
    module V3
      module Admin
        class ProvisioningRunSerializer < V3::BaseSerializer
          typelize status: :string,
                   repo_full_name: [:string, nullable: true],
                   vercel_project_id: [:string, nullable: true],
                   deployment_url: [:string, nullable: true],
                   template_repo: :string,
                   error_message: [:string, nullable: true],
                   steps: '{ name: string; status: string; error_message: string | null }[]'

          attributes :status, :repo_full_name, :vercel_project_id, :deployment_url,
                     :template_repo, :error_message,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :steps do |run|
            run.steps.map do |step|
              { name: step.name, status: step.status, error_message: step.error_message }
            end
          end
        end
      end
    end
  end
end
