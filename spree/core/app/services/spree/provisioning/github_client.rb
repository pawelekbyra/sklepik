require 'net/http'
require 'json'

module Spree
  module Provisioning
    # Thin wrapper around the GitHub REST API calls provisioning needs.
    # Uses the "generate a repository from a template" endpoint
    # (https://docs.github.com/en/rest/repos/repos#create-a-repository-using-a-template)
    # rather than shelling out to `git clone`/`git push` — no local git
    # process, no filesystem tempdir, and it requires the template repo to be
    # marked "Template repository" in GitHub settings (a one-time manual
    # toggle on sklepikFront, not something this client can set).
    #
    # UNVERIFIED end-to-end: exercised against the real GitHub API only up to
    # authentication (see docs/plans/store-factory.md, session 2026-07-13) —
    # the create-from-template call itself was never run for real because the
    # session that wrote this had no scope to create a repo. First live run
    # should watch this closely.
    class GithubClient
      API_BASE = 'https://api.github.com'.freeze
      TIMEOUT = 30

      class Error < StandardError; end

      def initialize(token: Settings.github_token)
        @token = token
      end

      # @return [String] full_name of the created repo (e.g. "owner/repo")
      def create_from_template(template_repo:, new_repo_name:, owner: Settings.github_owner, private_repo: true)
        template_owner, template_name = template_repo.split('/', 2)

        response = request(
          :post,
          "/repos/#{template_owner}/#{template_name}/generate",
          {
            owner: owner,
            name: new_repo_name,
            private: private_repo,
            include_all_branches: false
          }
        )

        JSON.parse(response.body)['full_name']
      end

      # Confirms the generated repo finished being materialized — GitHub's
      # "generate" call returns 201 before the repo is necessarily fully
      # populated (async on their end for large templates). Poll this before
      # handing the repo to Vercel.
      def repo_ready?(full_name)
        response = request(:get, "/repos/#{full_name}")
        response.code.to_i == 200 && JSON.parse(response.body)['size'].to_i.positive?
      rescue Error
        false
      end

      private

      def request(method, path, body = nil)
        uri = URI("#{API_BASE}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT

        request = build_request(method, uri, body)
        response = http.request(request)
        raise Error, "GitHub API #{method.to_s.upcase} #{path} failed: #{response.code} #{response.body}" unless response.code.to_i.between?(200, 299)

        response
      end

      def build_request(method, uri, body)
        request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
        request = request_class.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@token}"
        request['Accept'] = 'application/vnd.github+json'
        request['User-Agent'] = 'Kakalowy-Sklepik-Provisioning/1.0'
        if body
          request['Content-Type'] = 'application/json'
          request.body = body.to_json
        end
        request
      end
    end
  end
end
