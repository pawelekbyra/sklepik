namespace :spree do
  namespace :media do
    desc 'Backfill primary_media_id for all variants and products'
    task backfill_primary_media: :environment do
      puts 'Backfilling variant primary_media...'
      Spree::Variant.where(primary_media_id: nil).where.not(media_count: 0).find_each do |variant|
        first_media = variant.gallery_media.first
        variant.update_column(:primary_media_id, first_media.id) if first_media
      end

      puts 'Backfilling product primary_media...'
      Spree::Product.where(primary_media_id: nil).where.not(media_count: 0).find_each do |product|
        first_media = product.gallery_media.first
        product.update_column(:primary_media_id, first_media.id) if first_media
      end

      puts 'Done!'
    end

    # Enqueues Spree::Media::MigrateProductAssetsJob for every product that
    # still has at least one variant-pinned asset. The job is idempotent, so
    # re-running this task is safe.
    #
    # ENV vars:
    #   BATCH_SIZE — products fetched per scope batch (default: 500)
    desc 'Enqueue jobs to migrate legacy variant-pinned images to product-level media (opt-in, 5.5)'
    task migrate_master_images_to_product_media: :environment do
      batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
      batch_size = 500 if batch_size < 1

      # Subquery (not pluck) so the product set doesn't materialize in Ruby —
      # important for catalogs with millions of products.
      variant_product_ids = Spree::Variant
                              .joins("INNER JOIN #{Spree::Asset.table_name} ON " \
                                     "#{Spree::Asset.table_name}.viewable_id = #{Spree::Variant.table_name}.id " \
                                     "AND #{Spree::Asset.table_name}.viewable_type = 'Spree::Variant'")
                              .select(:product_id)

      relation = Spree::Product.where(id: variant_product_ids)
      relation.find_each(batch_size: batch_size) do |product|
        Spree::Media::MigrateProductAssetsJob.perform_later(product.id)
      end

      puts "Enqueued migration jobs for #{relation.count} products on the #{Spree.queues.images} queue."
    end

    # Direct-upload flows (admin media picker) create an ActiveStorage::Blob
    # as soon as the file lands, before the owning record (Asset, Store logo,
    # Taxon image, ...) is saved — an abandoned form or failed save leaves the
    # blob (and its R2 object) orphaned forever, since nothing purges it on
    # its own. The age cutoff avoids racing an in-flight upload whose record
    # hasn't been saved yet.
    #
    # ENV vars:
    #   OLDER_THAN_HOURS — minimum blob age before it's eligible for purge (default: 24)
    desc 'Purge Active Storage blobs that are not attached to any record (orphaned direct uploads)'
    task purge_unattached_blobs: :environment do
      older_than_hours = ENV.fetch('OLDER_THAN_HOURS', 24).to_i
      cutoff = older_than_hours.hours.ago

      relation = ActiveStorage::Blob.unattached.where(created_at: ...cutoff)
      count = relation.count
      relation.find_each(&:purge_later)

      puts "Enqueued purge for #{count} unattached blob(s) older than #{older_than_hours}h."
    end
  end
end
