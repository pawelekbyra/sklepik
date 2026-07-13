module Spree
  module Provisioning
    # Central place for the env vars the provisioning pipeline needs, so
    # nothing else in this namespace calls +ENV[]+ directly. Secrets are read
    # straight from the process environment (matches +CDN_HOST+/`CLOUDFLARE_*`
    # elsewhere in this app), never from +Spree::Config+ — provisioning
    # credentials are infra-level, not merchant-configurable preferences.
    #
    # Required on the server actually running provisioning, NOT for the app
    # to boot: every accessor raises only when called without the var set, so
    # environments that never provision (dev, most of prod) are unaffected.
    module Settings
      class MissingCredential < StandardError; end

      module_function

      # Fine-grained PAT or GitHub App installation token with repo-create
      # access to +github_owner+. See docs/plans/store-factory.md Key
      # Decision #8 — production should move this to a GitHub App
      # installation token, not a long-lived PAT.
      def github_token
        fetch('GITHUB_PROVISIONING_TOKEN')
      end

      def github_owner
        ENV.fetch('GITHUB_PROVISIONING_OWNER', 'pawelekbyra')
      end

      def template_repo
        ENV.fetch('GITHUB_PROVISIONING_TEMPLATE_REPO', 'pawelekbyra/sklepikFront')
      end

      def vercel_token
        fetch('VERCEL_TOKEN')
      end

      def vercel_team_id
        fetch('VERCEL_TEAM_ID')
      end

      # Backend URL new storefronts should point their SDK client at.
      def default_spree_api_url
        ENV.fetch('SPREE_API_URL', 'https://141-253-103-172.nip.io')
      end

      def fetch(key)
        ENV[key].presence || raise(MissingCredential, "#{key} is not set")
      end
    end
  end
end
