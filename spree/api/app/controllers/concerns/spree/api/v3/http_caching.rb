module Spree
  module Api
    module V3
      # Provides HTTP caching support for API v3 controllers
      #
      # Strategy:
      # - Guest users: Public HTTP caching with CDN support (5-15 min TTL)
      # - Authenticated users: Private, no-store (no caching)
      #
      # Uses ETag headers for cache validation.
      module HttpCaching
        extend ActiveSupport::Concern

        PUBLIC_CACHE_VARY_HEADERS = [
          'Accept',
          'X-Spree-API-Key',
          'X-Spree-Store-Id',
          'X-Spree-Country',
          'X-Spree-Currency',
          'X-Spree-Locale',
          'X-Spree-Channel'
        ].freeze

        included do
          after_action :set_vary_headers
        end

        protected

        # Check if the current user is a guest (no authentication)
        def guest_user?
          current_user.nil?
        end

        # Partition shared caches by every request header that can select a
        # store or alter the Store API representation.
        def set_vary_headers
          if guest_user?
            merge_vary_headers(PUBLIC_CACHE_VARY_HEADERS)
          else
            response.headers['Cache-Control'] = 'private, no-store'
          end
        end

        # Apply HTTP caching for a collection (index actions)
        # Only caches for guest users
        #
        # @param collection [ActiveRecord::Relation] The collection to cache
        # @param expires_in [ActiveSupport::Duration] Cache TTL (default: 5 minutes)
        # @param stale_while_revalidate [ActiveSupport::Duration] Allow stale responses while revalidating
        # @return [Boolean] true if response should be rendered, false if 304 Not Modified
        def cache_collection(collection, expires_in: 5.minutes, stale_while_revalidate: 30.seconds)
          return true unless guest_user?

          expires_in expires_in, public: true, stale_while_revalidate: stale_while_revalidate

          # Use collection's cache key for ETag
          cache_key = collection_cache_key(collection)
          response.headers['ETag'] = %("#{Digest::MD5.hexdigest(cache_key)}")

          # Return false if client has fresh cache (304 Not Modified)
          if request.fresh?(response)
            head :not_modified
            false
          else
            true
          end
        end

        # Apply HTTP caching for a single resource (show actions)
        # Only caches for guest users
        #
        # @param resource [ActiveRecord::Base] The resource to cache
        # @param expires_in [ActiveSupport::Duration] Cache TTL (default: 5 minutes)
        # @return [Boolean] true if response should be rendered, false if 304 Not Modified
        def cache_resource(resource, expires_in: 5.minutes)
          return true unless guest_user?

          expires_in expires_in, public: true

          response.headers['ETag'] = %("#{Digest::MD5.hexdigest(resource_cache_key(resource))}")

          if request.fresh?(response)
            head :not_modified
            false
          else
            true
          end
        end

        private

        def merge_vary_headers(headers)
          current_headers = response.headers['Vary'].to_s.split(',').map(&:strip).reject(&:blank?)
          return if current_headers.include?('*')

          combined_headers = (current_headers + headers).uniq(&:downcase)
          response.headers['Vary'] = combined_headers.join(', ')
        end

        # Build a cache key for a collection
        # Includes: tenant context, latest updated_at, total count, query
        # params, pagination, expand, currency, and locale.
        def collection_cache_key(collection)
          # For ActiveRecord collections use updated_at, for plain arrays use store's updated_at as proxy
          latest_updated_at = if collection.first&.respond_to?(:updated_at)
                                collection.map(&:updated_at).max&.to_i
                              else
                                current_store&.updated_at&.to_i
                              end

          parts = [
            *tenant_cache_key_parts,
            latest_updated_at,
            @pagy&.count || collection.size,
            params[:expand],
            params[:fields],
            params[:q]&.to_json,
            params[:page],
            params[:limit]
          ]

          parts.compact.join('/')
        end

        def resource_cache_key(resource)
          ([resource.cache_key_with_version] + tenant_cache_key_parts).compact.join('/')
        end

        # Use resolved records, not raw headers, so aliases and fallback values
        # share a variant only when they resolve to the same tenant context.
        def tenant_cache_key_parts
          [
            current_store&.cache_key_with_version,
            Spree::Current.market&.cache_key_with_version,
            Spree::Current.channel&.cache_key_with_version,
            current_currency,
            current_locale
          ]
        end
      end
    end
  end
end
