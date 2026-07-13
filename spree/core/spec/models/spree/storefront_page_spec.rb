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
    expect(page.errors[:draft_document]).to include('section 0 button link is invalid')
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
end
