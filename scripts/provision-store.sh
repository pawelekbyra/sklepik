#!/bin/bash
# Store Factory — manual/local provisioning script (Etap 2 pilot support).
#
# Creates a new store's GitHub repo (copy of sklepikFront template) + a linked
# Vercel project + env vars + a deployment. Run this LOCALLY (not from a
# sandboxed Claude Code web/remote session) — a remote session's outbound
# proxy blocks GitHub API calls to repos outside its configured scope,
# including repo creation. Confirmed 2026-07-13, see docs/plans/store-factory.md
# "Sesja 2026-07-13 — API mapping z sesji zdalnej" for details.
#
# Requires: gh (authenticated: `gh auth login`), curl, jq
# Env vars required:
#   VERCEL_TOKEN        - Vercel API token (Account Settings -> Tokens)
#   SPREE_API_URL        - backend URL new store should point to (defaults to prod Oracle IP)
#   SPREE_PUBLISHABLE_KEY - Store API publishable key for the new store (create it in admin first)
# Args:
#   $1 = store slug (used as repo name + vercel project name), e.g. "sklepik-eur"
#
# What is VERIFIED against the real Vercel API (session 2026-07-13):
#   - POST /v11/projects?teamId=... to create a project (tested live, 200 OK)
#   - DELETE /v9/projects/:id?teamId=... to remove a project (tested live, 204)
#   - GET /v9/projects/:id?teamId=... link shape for an existing GitHub-linked
#     project (read from sklepik_front): {"type":"github","repo":"sklepikFront",
#     "repoId":...,"org":"pawelekbyra","repoOwnerId":...,"gitCredentialId":...}
# What is NOT verified yet (could not create a real repo from the remote session):
#   - Whether POST /v11/projects with a bare {"type":"github","repo":"owner/name"}
#     (no gitCredentialId) auto-resolves against the account's existing GitHub
#     App installation, or whether it 4xxs and needs the credential id.
#   - Whether the Vercel GitHub App integration is set to "All repositories" or
#     "Only select repositories" for pawelekbyra's GitHub account. If it's the
#     latter, a brand-new repo will NOT be visible to Vercel until you add it
#     manually: https://github.com/settings/installations -> Vercel -> Configure
#     -> add the new repo. Do this BEFORE step 3 below if projects fail to link.
#   - The exact deployment-trigger payload (POST /v13/deployments) for a repo
#     that was just linked. Untested — may need iteration.
#
# This script pauses before the Vercel-linking step so you can do the GitHub
# App repo-access check above if needed.

set -euo pipefail

STORE_SLUG="${1:?Usage: provision-store.sh <store-slug>}"
GH_OWNER="pawelekbyra"
TEMPLATE_REPO="pawelekbyra/sklepikFront"
VERCEL_TEAM_ID="team_sc16PptMTGc4ip47phctR79J"
SPREE_API_URL="${SPREE_API_URL:-https://141-253-103-172.nip.io}"

: "${VERCEL_TOKEN:?Set VERCEL_TOKEN}"
: "${SPREE_PUBLISHABLE_KEY:?Set SPREE_PUBLISHABLE_KEY (create it in admin for the new store first)}"

command -v gh >/dev/null || { echo "Missing 'gh' CLI. Install: https://cli.github.com"; exit 1; }
command -v jq >/dev/null || { echo "Missing 'jq'."; exit 1; }

echo "=== 1/5: Copying template ($TEMPLATE_REPO) into a fresh working dir ==="
WORKDIR="$(mktemp -d)"
git clone --depth 1 "https://github.com/$TEMPLATE_REPO.git" "$WORKDIR/$STORE_SLUG"
rm -rf "$WORKDIR/$STORE_SLUG/.git"
cd "$WORKDIR/$STORE_SLUG"
git init -q
git add -A
git commit -q -m "Initial commit: provisioned from $TEMPLATE_REPO template"

echo "=== 2/5: Creating GitHub repo $GH_OWNER/$STORE_SLUG ==="
gh repo create "$GH_OWNER/$STORE_SLUG" --private --source=. --remote=origin --push

echo "=== 3/5: Checking Vercel GitHub App has access to the new repo ==="
echo "If the next step fails to link the repo, go to:"
echo "  https://github.com/settings/installations -> Vercel -> Configure -> add '$STORE_SLUG'"
read -rp "Press Enter once confirmed (or if you already use 'All repositories') to continue..."

echo "=== 4/5: Creating Vercel project linked to the repo ==="
CREATE_RESP="$(curl -sf -X POST "https://api.vercel.com/v11/projects?teamId=$VERCEL_TEAM_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
  -d "$(jq -n --arg name "$STORE_SLUG" --arg repo "$GH_OWNER/$STORE_SLUG" \
        '{name:$name, framework:"nextjs", gitRepository:{type:"github", repo:$repo}}')")"
PROJECT_ID="$(echo "$CREATE_RESP" | jq -r '.id')"
echo "Vercel project id: $PROJECT_ID"

echo "=== 5/5: Setting env vars + triggering deploy ==="
set_env() {
  local key="$1" value="$2"
  curl -sf -X POST "https://api.vercel.com/v10/projects/$PROJECT_ID/env?teamId=$VERCEL_TEAM_ID" \
    -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
    -d "$(jq -n --arg k "$key" --arg v "$value" \
          '{key:$k, value:$v, type:"encrypted", target:["production","preview"]}')" >/dev/null
}
set_env "SPREE_API_URL" "$SPREE_API_URL"
set_env "SPREE_PUBLISHABLE_KEY" "$SPREE_PUBLISHABLE_KEY"
set_env "NEXT_PUBLIC_STORE_NAME" "$STORE_SLUG"

echo "Env vars set. Trigger a deploy by pushing again (Vercel's GitHub integration"
echo "auto-deploys on push to main) or via the Vercel dashboard's 'Deploy' button —"
echo "the deployment-trigger API payload is not verified yet, see header comment."

echo
echo "Done (pending manual deploy trigger/verification). Project: https://vercel.com/$VERCEL_TEAM_ID/$STORE_SLUG"
