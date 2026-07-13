class AddLaunchStatusToSpreeStores < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_stores, :launch_status, :string, if_not_exists: true
    add_index :spree_stores, :launch_status, if_not_exists: true
  end
end
