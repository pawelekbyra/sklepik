class CreateSpreeProvisioningSteps < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_provisioning_steps, if_not_exists: true do |t|
      t.references :run, null: false, index: true, foreign_key: false
      t.string :name, null: false
      t.string :status, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end
  end
end
