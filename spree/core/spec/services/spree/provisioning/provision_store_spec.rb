# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Provisioning::ProvisionStore do
  subject(:service) do
    described_class.new(
      run,
      github: instance_double(Spree::Provisioning::GithubClient),
      vercel: instance_double(Spree::Provisioning::VercelClient)
    )
  end

  let(:store) { create(:store, url: 'nowy-sklep.vercel.app') }
  let(:run) { Spree::ProvisioningRun.create!(store: store, template_repo: 'owner/template') }

  before do
    allow(service).to receive(:create_repository).and_return('owner/nowy-sklep')
    allow(service).to receive(:create_vercel_project).and_return('id' => 'project-id')
    allow(service).to receive(:configure_environment)
    allow(service).to receive(:wait_for_deployment).and_return('https://nowy-sklep-abc.vercel.app')
  end

  it 'activates the run and replaces the provisional store URL with the deployed host' do
    service.call

    expect(run.reload.attributes.symbolize_keys).to include(
      status: 'active',
      repo_full_name: 'owner/nowy-sklep',
      vercel_project_id: 'project-id',
      deployment_url: 'https://nowy-sklep-abc.vercel.app'
    )
    expect(store.reload.url).to eq('nowy-sklep-abc.vercel.app')
  end
end
