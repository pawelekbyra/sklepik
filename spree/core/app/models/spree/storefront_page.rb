# frozen_string_literal: true

module Spree
  # A store-owned, versioned document rendered by independent storefront apps.
  # Commerce remains in Store API; this model only describes presentation.
  class StorefrontPage < Spree.base_class
    has_prefix_id :sfpage

    SCHEMA_VERSION = 1
    # Mirrors edytor-sklepu's packages/schema SECTION_TYPES: content sections rendered by the
    # shared @editor/component-library (hero, rich_text, newsletter, image_banner, faq, spacer,
    # button) plus commerce sections filled with real store data by the host, not the library
    # (product_grid). See sklepik/docs/plans/storefront-composition-system.md.
    SECTION_TYPES = %w[hero product_grid rich_text newsletter image_banner faq spacer button].freeze
    # Mirrors edytor-sklepu's packages/schema BLOCK_TYPES.
    BLOCK_TYPES = %w[button image rich_text navigation].freeze
    MAX_SECTIONS = 30

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :storefront_pages
    belongs_to :published_by, class_name: Spree.admin_user_class.to_s, optional: true

    validates :slug, :title, presence: true
    validates :slug, uniqueness: { scope: :store_id }
    validate :draft_document_is_supported
    validate :published_document_is_supported, if: :published_document?

    before_validation :set_defaults, on: :create

    def publish!(user:)
      with_lock do
        update!(
          published_document: draft_document.deep_dup,
          published_at: Time.current,
          published_by: user
        )
      end
    end

    def published?
      published_document.present? && published_at.present?
    end

    def self.default_document
      {
        'schemaVersion' => SCHEMA_VERSION,
        'sections' => [
          {
            'id' => SecureRandom.uuid,
            'type' => 'hero',
            'position' => 0,
            'preferences' => {
              'heading' => '',
              'subheading' => '',
              'backgroundImageAssetId' => nil
            },
            'blocks' => []
          },
          {
            'id' => SecureRandom.uuid,
            'type' => 'product_grid',
            'position' => 1,
            'preferences' => {
              'heading' => '',
              'taxonId' => nil,
              'limit' => 8
            }
          }
        ]
      }
    end

    private

    def set_defaults
      self.slug ||= 'home'
      self.title ||= 'Homepage'
      self.draft_document ||= self.class.default_document
      self.lock_version ||= 0
    end

    def draft_document_is_supported
      validate_document(:draft_document, draft_document)
    end

    def published_document_is_supported
      validate_document(:published_document, published_document)
    end

    def validate_document(attribute, document)
      unless document.is_a?(Hash)
        errors.add(attribute, 'must be an object')
        return
      end

      errors.add(attribute, 'has an unsupported schema version') unless document['schemaVersion'] == SCHEMA_VERSION
      sections = document['sections']
      unless sections.is_a?(Array)
        errors.add(attribute, 'must contain a sections array')
        return
      end

      errors.add(attribute, "cannot contain more than #{MAX_SECTIONS} sections") if sections.size > MAX_SECTIONS
      ids = sections.filter_map { |section| section['id'] if section.is_a?(Hash) }
      errors.add(attribute, 'contains duplicate section ids') if ids.uniq.size != ids.size

      sections.each_with_index { |section, index| validate_section(attribute, section, index) }
    end

    def validate_section(attribute, section, index)
      unless section.is_a?(Hash)
        errors.add(attribute, "section #{index} must be an object")
        return
      end

      type = section['type']
      errors.add(attribute, "section #{index} has an unsupported type") unless SECTION_TYPES.include?(type)
      errors.add(attribute, "section #{index} must have an id") if section['id'].blank?
      position = section['position']
      errors.add(attribute, "section #{index} has an invalid position") unless position.is_a?(Integer) && position >= 0

      preferences = section['preferences']
      unless preferences.is_a?(Hash)
        errors.add(attribute, "section #{index} must have preferences")
        return
      end

      case type
      when 'hero' then validate_hero(attribute, preferences, section['blocks'], index)
      when 'product_grid' then validate_product_grid(attribute, preferences, index)
      when 'rich_text' then validate_rich_text(attribute, preferences, index)
      when 'newsletter' then validate_newsletter(attribute, preferences, index)
      when 'image_banner' then validate_image_banner(attribute, preferences, section['blocks'], index)
      when 'faq' then validate_faq(attribute, preferences, index)
      when 'spacer' then validate_spacer(attribute, preferences, index)
      when 'button' then validate_button_preferences(attribute, preferences, index)
      end
    end

    def validate_hero(attribute, preferences, blocks, index)
      validate_text(attribute, preferences['heading'], "section #{index} heading", 160)
      validate_text(attribute, preferences['subheading'], "section #{index} subheading", 500)
      validate_blocks(attribute, blocks, index)
    end

    def validate_product_grid(attribute, preferences, index)
      validate_text(attribute, preferences['heading'], "section #{index} heading", 160)
      limit = preferences['limit']
      errors.add(attribute, "section #{index} limit must be between 1 and 24") unless limit.is_a?(Integer) && limit.between?(1, 24)
    end

    def validate_rich_text(attribute, preferences, index)
      validate_text(attribute, preferences['html'], "section #{index} html", 20_000)
    end

    def validate_newsletter(attribute, preferences, index)
      validate_text(attribute, preferences['heading'], "section #{index} heading", 160)
      validate_text(attribute, preferences['subheading'], "section #{index} subheading", 500)
      validate_text(attribute, preferences['buttonLabel'], "section #{index} button label", 80)
    end

    def validate_image_banner(attribute, preferences, blocks, index)
      height = preferences['heightPx']
      errors.add(attribute, "section #{index} heightPx must be a positive integer") unless height.is_a?(Integer) && height >= 1
      transparency = preferences['overlayTransparency']
      unless transparency.is_a?(Integer) && transparency.between?(0, 100)
        errors.add(attribute, "section #{index} overlayTransparency must be between 0 and 100")
      end
      alignment = preferences['verticalAlignment']
      errors.add(attribute, "section #{index} verticalAlignment is invalid") unless %w[top middle bottom].include?(alignment)
      validate_blocks(attribute, blocks, index)
    end

    def validate_faq(attribute, preferences, index)
      validate_text(attribute, preferences['heading'], "section #{index} heading", 160)
      items = preferences['items']
      return errors.add(attribute, "section #{index} items must be an array") unless items.is_a?(Array)

      items.each_with_index do |item, item_index|
        unless item.is_a?(Hash)
          errors.add(attribute, "section #{index} item #{item_index} must be an object")
          next
        end
        validate_text(attribute, item['question'], "section #{index} item #{item_index} question", 300)
        validate_text(attribute, item['answer'], "section #{index} item #{item_index} answer", 2_000)
      end
    end

    def validate_spacer(attribute, preferences, index)
      height = preferences['heightPx']
      errors.add(attribute, "section #{index} heightPx must be a positive integer") unless height.is_a?(Integer) && height >= 1
    end

    def validate_button_preferences(attribute, preferences, index)
      validate_text(attribute, preferences['label'], "section #{index} label", 80)
      href = preferences['href'].to_s
      errors.add(attribute, "section #{index} link is invalid") unless href.start_with?('/', 'https://', 'http://')
    end

    def validate_blocks(attribute, blocks, index)
      return if blocks.nil?
      return errors.add(attribute, "section #{index} blocks must be an array") unless blocks.is_a?(Array)

      blocks.each_with_index do |block, block_index|
        unless block.is_a?(Hash) && BLOCK_TYPES.include?(block['type'])
          errors.add(attribute, "section #{index} block #{block_index} has an unsupported type")
          next
        end

        preferences = block['preferences']
        unless preferences.is_a?(Hash)
          errors.add(attribute, "section #{index} block #{block_index} must have preferences")
          next
        end
        validate_block_preferences(attribute, block['type'], preferences, "section #{index} block #{block_index}")
      end
    end

    def validate_block_preferences(attribute, type, preferences, label)
      case type
      when 'button'
        validate_text(attribute, preferences['label'], "#{label} label", 80)
        href = preferences['href'].to_s
        errors.add(attribute, "#{label} link is invalid") unless href.start_with?('/', 'https://', 'http://')
      when 'image'
        validate_text(attribute, preferences['alt'], "#{label} alt", 300)
      when 'rich_text'
        validate_text(attribute, preferences['html'], "#{label} html", 20_000)
      when 'navigation'
        validate_text(attribute, preferences['label'], "#{label} label", 80)
      end
    end

    def validate_text(attribute, value, label, maximum)
      errors.add(attribute, "#{label} must be text") unless value.is_a?(String)
      errors.add(attribute, "#{label} is too long") if value.is_a?(String) && value.length > maximum
    end
  end
end
