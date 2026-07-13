class CreateSpreeStorefrontPages < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_storefront_pages, if_not_exists: true do |t|
      t.references :store, null: false, index: true
      t.string :slug, null: false
      t.string :title, null: false
      if t.respond_to?(:jsonb)
        t.jsonb :draft_document, null: false
        t.jsonb :published_document
      else
        t.json :draft_document, null: false
        t.json :published_document
      end
      t.datetime :published_at
      t.references :published_by, index: true
      t.integer :lock_version, null: false

      t.timestamps
    end

    add_index :spree_storefront_pages, [:store_id, :slug],
              unique: true, if_not_exists: true
  end
end
