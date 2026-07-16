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
    # but was not exercised live.
    #
    # 2026-07-16 incident (first real /signup attempt, store "hejkarty"):
    # the bare `gitRepository: {"type":"github","repo":"owner/name"}` DOES
    # auto-resolve against the account's GitHub App installation — no
    # `gitCredentialId` needed, confirmed by real deployments building from
    # later pushes. The actual bug was different: the repo's one commit
    # (from GitHub's generate-from-template) exists *before* this project
    # does, so nothing was ever going to auto-deploy it — `create_project`
    # only links *future* pushes. `wait_for_deployment` polled for 5 minutes
    # against a project that had no deployment to find, timing out on a
    # deployment that was never coming. `trigger_deployment` below closes
    # that gap by explicitly building the current ref instead of waiting on
    # a push event.
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

      # Explicitly builds `ref` instead of waiting for a push event — the
      # repo's initial commit predates the project (see class comment), so
      # without this call there is nothing for Vercel to ever auto-deploy.
      # @return [Hash] parsed deployment response, includes "id"/"url"/"readyState"
      def trigger_deployment(project_id:, repo_id:, name:, ref: 'main')
        response = request(
          :post,
          '/v13/deployments',
          {
            name: name,
            project: project_id,
            target: 'production',
            gitSource: { type: 'github', repoId: repo_id, ref: ref }
          }
        )
        JSON.parse(response.body)
      end

      # Most recent deployment for the project's production target, in
      # whatever state it's actually in — nil only when none exists yet.
      # Callers need the raw state (not just a URL) to tell "still
      # building" apart from "errored", which is exactly what got missed
      # before: a build that failed at minute 1 was indistinguishable from
      # one still running, so polling burned the full timeout either way.
      def latest_deployment(project_id)
        response = request(:get, "/v6/deployments?projectId=#{project_id}&target=production&limit=1")
        JSON.parse(response.body)['deployments']&.first
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
