#!/bin/bash
# fetch-pr-comments.sh
# Fetch all PR comment types (inline + review + general) via gh CLI
# Output: JSON to stdout
# Dependencies: gh CLI (authenticated)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: bash $SCRIPT_NAME <PR_URL>

PR_URL formats:
  https://github.com/owner/repo/pull/42
  gitlab.com/owner/repo/-/merge_requests/42

Output: JSON with { status, owner, repo, number, pr_info, comments }
Exit codes:
  0   — Comments fetched successfully
  1   — Input/parse error
  2   — gh CLI not available (fallback_needed signal)
EOF
  exit 1
}

[ $# -eq 0 ] || [ "$1" = "--help" ] && usage

PR_URL="$1"
[ -z "$PR_URL" ] && echo '{"status":"error","error":"Missing PR URL"}' && exit 1

OWNER=""; REPO=""; NUMBER=""
if [[ "$PR_URL" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$PR_URL" =~ gitlab\..+/([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
  echo "{\"status\":\"error\",\"error\":\"GitLab not yet supported via gh CLI. Use MCP tools.\"}"
  exit 1
else
  echo "{\"status\":\"error\",\"error\":\"Could not parse PR URL: $PR_URL\"}"
  exit 1
fi

# Check gh CLI
if ! command -v gh &>/dev/null; then
  cat <<EOF
{"status":"fallback_needed","method":"mcp","platform":"github","owner":"$OWNER","repo":"$REPO","number":$NUMBER,"fallback_hint":"gh CLI not installed"}
EOF
  exit 2
fi

# Check gh auth
if ! gh auth status &>/dev/null; then
  cat <<EOF
{"status":"fallback_needed","method":"mcp","platform":"github","owner":"$OWNER","repo":"$REPO","number":$NUMBER,"fallback_hint":"gh CLI not authenticated"}
EOF
  exit 2
fi

# Fetch PR metadata
PR_INFO=$(gh api "repos/$OWNER/$REPO/pulls/$NUMBER" --jq '{title,state,head:{ref:.head.ref,sha:.head.sha},base:{ref:.base.ref,sha:.base.sha},additions,deletions,changed_files}' 2>/dev/null) || PR_INFO='{}'

# Fetch inline comments (on code)
INLINE=$(gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments" --paginate \
  --jq '[.[] | {id, body, path, line, author: .user.login}]' 2>/dev/null) || INLINE='[]'

# Fetch review submissions
REVIEWS=$(gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --paginate \
  --jq '[.[] | {id, body, state, author: .user.login}]' 2>/dev/null) || REVIEWS='[]'

# Fetch general comments (issue comments on the PR)
GENERAL=$(gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" --paginate \
  --jq '[.[] | {id, body, author: .user.login}]' 2>/dev/null) || GENERAL='[]'

# Build response
INLINE_COUNT=$(echo "$INLINE" | jq 'length')
REVIEWS_COUNT=$(echo "$REVIEWS" | jq 'length')
GENERAL_COUNT=$(echo "$GENERAL" | jq 'length')

cat <<EOF
{
  "status": "ok",
  "owner": "$OWNER",
  "repo": "$REPO",
  "number": $NUMBER,
  "pr_info": $PR_INFO,
  "comments": {
    "inline": $INLINE,
    "reviews": $REVIEWS,
    "general": $GENERAL
  },
  "counts": {
    "inline": $INLINE_COUNT,
    "reviews": $REVIEWS_COUNT,
    "general": $GENERAL_COUNT
  }
}
EOF

exit 0
