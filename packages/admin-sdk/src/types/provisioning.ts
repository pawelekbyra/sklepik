// Hand-written Store Factory provisioning types (controller-shaped, not
// generated). Migrate to `./generated/ProvisioningRun` once
// `bundle exec rake typelizer:generate` runs against
// `Spree::Api::V3::Admin::ProvisioningRunSerializer` in an environment with a
// working Rails app — see docs/plans/store-factory.md, session 2026-07-13.

export type ProvisioningStepStatus = 'in_progress' | 'done' | 'failed'

export interface ProvisioningStep {
  name: string
  status: ProvisioningStepStatus
  error_message: string | null
}

export type ProvisioningRunStatus =
  | 'pending'
  | 'creating_repository'
  | 'creating_vercel_project'
  | 'configuring_environment'
  | 'deploying'
  | 'active'
  | 'failed'

export interface ProvisioningRun {
  id: string
  status: ProvisioningRunStatus
  repo_full_name: string | null
  vercel_project_id: string | null
  deployment_url: string | null
  template_repo: string
  error_message: string | null
  steps: ProvisioningStep[]
  created_at: string
  updated_at: string
}
