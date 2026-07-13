class CreateSpreeProvisioningRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_provisioning_runs, if_not_exists: true do |t|
      t.references :store, null: false, index: true
      t.string :status, null: false
      t.string :repo_full_name
      t.string :vercel_project_id
      t.string :deployment_url
      t.string :template_repo, null: false
      t.text :error_message

      t.timestamps
    end
  end
end
