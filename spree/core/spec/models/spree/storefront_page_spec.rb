require 'spec_helper'

RSpec.describe Spree::StorefrontPage do
  let(:store) { create(:store) }
  let(:page) do
    described_class.new(
      store: store,
      slug: 'home',
      title: 'Homepage',
      draft_document: described_class.default_document
    )
  end

  it 'accepts the versioned homepage document' do
    expect(page).to be_valid
  end

  it 'rejects document sections outside the renderer allowlist' do
    page.draft_document['sections'] << {
      'id' => SecureRandom.uuid,
      'type' => 'script',
      'position' => 2,
      'preferences' => {}
    }

    expect(page).not_to be_valid
    expect(page.errors[:draft_document]).to include('section 2 has an unsupported type')
  end

  it 'rejects executable button URLs' do
    page.draft_document['sections'].first['blocks'] = [
      {
        'id' => SecureRandom.uuid,
        'type' => 'button',
        'position' => 0,
        'preferences' => {
          'label' => 'Click',
          'href' => 'javascript:alert(1)',
          'openInNewTab' => false
        }
      }
    ]

    expect(page).not_to be_valid
    expect(page.errors[:draft_document]).to include('section 0 block 0 link is invalid')
  end

  it 'accepts all seven content section types plus product_grid' do
    page.draft_document['sections'] = [
      { 'id' => SecureRandom.uuid, 'type' => 'hero', 'position' => 0,
        'preferences' => { 'heading' => 'H', 'subheading' => 'S', 'backgroundImageAssetId' => nil } },
      { 'id' => SecureRandom.uuid, 'type' => 'product_grid', 'position' => 1,
        'preferences' => { 'heading' => 'Produkty', 'taxonId' => nil, 'limit' => 8 } },
      { 'id' => SecureRandom.uuid, 'type' => 'rich_text', 'position' => 2,
        'preferences' => { 'html' => '<p>Tekst</p>' } },
      { 'id' => SecureRandom.uuid, 'type' => 'newsletter', 'position' => 3,
        'preferences' => { 'heading' => 'H', 'subheading' => 'S', 'buttonLabel' => 'Zapisz' } },
      { 'id' => SecureRandom.uuid, 'type' => 'image_banner', 'position' => 4,
        'preferences' => { 'imageAssetId' => nil, 'heightPx' => 384, 'overlayTransparency' => 40, 'verticalAlignment' => 'middle' } },
      { 'id' => SecureRandom.uuid, 'type' => 'faq', 'position' => 5,
        'preferences' => { 'heading' => 'FAQ', 'items' => [{ 'question' => 'Q?', 'answer' => 'A.' }] } },
      { 'id' => SecureRandom.uuid, 'type' => 'spacer', 'position' => 6,
        'preferences' => { 'heightPx' => 40 } },
      { 'id' => SecureRandom.uuid, 'type' => 'button', 'position' => 7,
        'preferences' => { 'label' => 'Kliknij', 'href' => '/kontakt', 'openInNewTab' => false } }
    ]

    expect(page).to be_valid
  end

  it 'rejects an image_banner with an out-of-range overlayTransparency' do
    page.draft_document['sections'] = [
      { 'id' => SecureRandom.uuid, 'type' => 'image_banner', 'position' => 0,
        'preferences' => { 'imageAssetId' => nil, 'heightPx' => 384, 'overlayTransparency' => 150, 'verticalAlignment' => 'middle' } }
    ]

    expect(page).not_to be_valid
    expect(page.errors[:draft_document]).to include('section 0 overlayTransparency must be between 0 and 100')
  end

  it 'accepts non-button block types (image, rich_text, navigation) inside hero' do
    page.draft_document['sections'].first['blocks'] = [
      { 'id' => SecureRandom.uuid, 'type' => 'image', 'position' => 0, 'preferences' => { 'assetId' => nil, 'alt' => 'Alt text' } },
      { 'id' => SecureRandom.uuid, 'type' => 'rich_text', 'position' => 1, 'preferences' => { 'html' => '<p>Hi</p>' } },
      { 'id' => SecureRandom.uuid, 'type' => 'navigation', 'position' => 2, 'preferences' => { 'label' => 'Link', 'href' => '/x', 'linkedPageId' => nil } }
    ]

    expect(page).to be_valid
  end

  it 'publishes an independent snapshot and records its author' do
    admin = create(:admin_user)
    page.save!
    page.publish!(user: admin)

    page.draft_document['sections'].first['preferences']['heading'] = 'Changed later'

    expect(page).to be_published
    expect(page.published_by).to eq(admin)
    expect(page.published_at).to be_present
    expect(page.published_document['sections'].first['preferences']['heading']).not_to eq('Changed later')
  end

  it 'logs a warning when the draft document grows past the size threshold' do
    # Each rich_text section is capped at 20,000 chars (see validate_rich_text) — stay under that
    # per-field limit and accumulate size across several sections instead.
    large_sections = (0...6).map do |i|
      {
        'id' => SecureRandom.uuid,
        'type' => 'rich_text',
        'position' => i,
        'preferences' => { 'html' => '<p>' + ('x' * 19_000) + '</p>' }
      }
    end
    page.draft_document['sections'] = large_sections

    expect(Rails.logger).to receive(:warn).with(/draft_document is \d+ bytes/)
    page.save!
  end

  it 'does not warn for a normally-sized document' do
    expect(Rails.logger).not_to receive(:warn)
    page.save!
  end
end
