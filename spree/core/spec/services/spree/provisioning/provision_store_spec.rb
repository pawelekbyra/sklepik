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

  # Real (non-stubbed) #wait_for_deployment, covering the 2026-07-16 "hejkarty"
  # incident: the repo's initial commit predates the Vercel project, so
  # nothing ever auto-deploys without an explicit trigger, and a build that
  # errors must fail the run immediately rather than exhaust the 5-minute poll.
  describe 'deployment triggering and polling' do
    subject(:service) { described_class.new(run, github: github, vercel: vercel) }

    let(:store) { create(:store, url: 'nowy-sklep.vercel.app', code: 'nowy-sklep') }
    let(:github) { instance_double(Spree::Provisioning::GithubClient) }
    let(:vercel) { instance_double(Spree::Provisioning::VercelClient) }

    before do
      allow(github).to receive(:create_from_template).and_return('owner/nowy-sklep')
      allow(github).to receive(:repo_ready?).and_return(true)
      allow(github).to receive(:fetch_repo_id).and_return(987_654)
      allow(vercel).to receive(:create_project).and_return('id' => 'project-id')
      allow(vercel).to receive(:set_env)
      allow(vercel).to receive(:trigger_deployment)
      allow(service).to receive(:sleep)
    end

    it 'explicitly triggers a deployment instead of only waiting on a push' do
      allow(vercel).to receive(:latest_deployment).and_return(
        'id' => 'dpl_1', 'url' => 'nowy-sklep-abc.vercel.app', 'readyState' => 'READY'
      )

      service.call

      expect(vercel).to have_received(:trigger_deployment).with(
        project_id: 'project-id', repo_id: 987_654, name: 'nowy-sklep'
      )
      expect(run.reload.status).to eq('active')
    end

    it 'fails the run immediately on a build error instead of polling the full timeout' do
      allow(vercel).to receive(:latest_deployment).and_return(
        'id' => 'dpl_1', 'readyState' => 'ERROR', 'errorMessage' => 'Command "npm run build" exited with 1'
      )

      expect { service.call }.to raise_error(Spree::Provisioning::VercelClient::Error, /npm run build/)
      expect(vercel).to have_received(:latest_deployment).once
      expect(run.reload.status).to eq('failed')
    end

    it 'keeps polling while the deployment is still building, then succeeds' do
      call_count = 0
      allow(vercel).to receive(:latest_deployment) do
        call_count += 1
        call_count < 3 ? { 'readyState' => 'BUILDING' } : { 'id' => 'dpl_1', 'url' => 'nowy-sklep-abc.vercel.app', 'readyState' => 'READY' }
      end

      service.call

      expect(call_count).to eq(3)
      expect(run.reload.status).to eq('active')
    end
  end
end
