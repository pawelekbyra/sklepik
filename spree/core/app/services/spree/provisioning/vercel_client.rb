require 'net/http'
require 'json'

module Spree
  module Provisioning
    # Thin wrapper around the Vercel REST API calls provisioning needs.
    #
    # `create_project` and `delete_project` are VERIFIED against the real
    # Vercel API (session 2026-07-13, docs/plans/store-factory.md Etap 2) —
    # a project was created and immediately deleted to confirm the exact
    # request/response shape below. `set_env` uses the documented endpoint
    # but was not exercised live. The `gitRepository` linkage in
    # `create_project` (this is what's untested end-to-end): whether a bare
    # `{"type":"github","repo":"owner/name"}` auto-resolves against the
    # account's existing GitHub App installation, or 4xxs and needs a
    # `gitCredentialId` — see the client note in ProvisionStore.
    class VercelClient
      API_BASE = 'https://api.vercel.com'.freeze
      TIMEOUT = 30

      class Error < StandardError; end

      def initialize(token: Settings.vercel_token, team_id: Settings.vercel_team_id)
        @token = token
        @team_id = team_id
      end

      # @return [Hash] parsed project response, includes "id"
      def create_project(name:, repo_full_name:)
        response = request(
          :post,
          '/v11/projects',
          {
            name: name,
            framework: 'nextjs',
            gitRepository: { type: 'github', repo: repo_full_name }
          }
        )
        JSON.parse(response.body)
      end

      def delete_project(project_id)
        request(:delete, "/v9/projects/#{project_id}")
        true
      end

      def set_env(project_id:, key:, value:, targets: %w[production preview])
        request(
          :post,
          "/v10/projects/#{project_id}/env",
          { key: key, value: value, type: 'encrypted', target: targets }
        )
      end

      # Latest deployment URL for the project's production target, once
      # Vercel's GitHub integration has auto-deployed the pushed branch.
      # Returns nil while no deployment exists yet — callers poll.
      def latest_deployment_url(project_id)
        response = request(:get, "/v6/deployments?projectId=#{project_id}&target=production&limit=1")
        deployment = JSON.parse(response.body)['deployments']&.first
        return nil unless deployment

        deployment['readyState'] == 'READY' ? "https://#{deployment['url']}" : nil
      end

      private

      def request(method, path, body = nil)
        separator = path.include?('?') ? '&' : '?'
        uri = URI("#{API_BASE}#{path}#{separator}teamId=#{@team_id}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT

        request = build_request(method, uri, body)
        response = http.request(request)
        raise Error, "Vercel API #{method.to_s.upcase} #{path} failed: #{response.code} #{response.body}" unless response.code.to_i.between?(200, 299)

        response
      end

      def build_request(method, uri, body)
        request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method)
        request = request_class.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@token}"
        if body
          request['Content-Type'] = 'application/json'
          request.body = body.to_json
        end
        request
      end
    end
  end
end
