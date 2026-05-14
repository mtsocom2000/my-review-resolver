#!/bin/bash
# re-request-review.sh
# Re-request review from specified reviewers after all comments are resolved.
# Primary: gh CLI
# MCP fallback: exit code 2 with JSON signal

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: echo '<JSON>' | bash $SCRIPT_NAME

Stdin JSON:
{
  "pr_url": "https://github.com/owner/repo/pull/42",
  "reviewers": ["reviewer1", "reviewer2"],
  "action": "re-request"          // "re-request" | "dismiss-and-re-request"
}

Exit codes:
  0   — Request sent via gh CLI
  1   — Input error (details on stderr)
  2   — gh CLI not available (fallback_needed JSON on stdout)
EOF
  exit 1
}

[ $# -gt 0 ] && [ "$1" = "--help" ] && usage

# Parse stdin
if [ -t 0 ]; then
  echo '{"status":"error","error":"No input provided. Pipe JSON to stdin."}'
  exit 1
fi

INPUT=$(cat)

PR_URL=$(echo "$INPUT" | jq -r '.pr_url // empty')
REVIEWERS=$(echo "$INPUT" | jq -c '.reviewers // []')
ACTION=$(echo "$INPUT" | jq -r '.action // "re-request"')

[ -z "$PR_URL" ] && echo '{"status":"error","error":"Missing pr_url"}' && exit 1

# Extract owner/repo/number from PR URL
OWNER=""; REPO=""; NUMBER=""
if [[ "$PR_URL" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$PR_URL" =~ gitlab\..+/([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
  echo "GitLab not yet supported for re-request. Please re-request manually."
  exit 1
else
  echo "{\"status\":\"error\",\"error\":\"Could not parse PR URL: $PR_URL\"}"
  exit 1
fi

RATING=$(echo "$REVIEWERS" | jq length)
[ "$RATING" -eq 0 ] && echo '{"status":"ok","action":"no_reviewers","message":"No reviewers to re-request"}' && exit 0

# Check gh CLI availability
if ! command -v gh &>/dev/null; then
  cat <<EOF
{"status":"fallback_needed","method":"mcp","platform":"github","action":"re_request_review","owner":"$OWNER","repo":"$REPO","number":$NUMBER,"reviewers":$REVIEWERS}
EOF
  exit 2
fi

if ! gh auth status &>/dev/null; then
  cat <<EOF
{"status":"fallback_needed","method":"mcp","platform":"github","action":"re_request_review","owner":"$OWNER","repo":"$REPO","number":$NUMBER,"reviewers":$REVIEWERS}
EOF
  exit 2
fi

# Check for DRY_RUN
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "{\"status\":\"dryrun\",\"action\":\"$ACTION\",\"owner\":\"$OWNER\",\"repo\":\"$REPO\",\"pr\":$NUMBER,\"reviewers\":$REVIEWERS}"
  exit 0
fi

# Execute re-request
SUCCESSFUL=()
FAILED=()

echo "$REVIEWERS" | jq -c '.[]' | while read -r REVIEWER; do
  REVIEWER_NAME=$(echo "$REVIEWER" | jq -r '.')
  if gh api "repos/$OWNER/$REPO/pulls/$NUMBER/requested_reviewers" \
       -X POST -f "reviewers[]=$REVIEWER_NAME" &>/dev/null; then
    SUCCESSFUL+=("$REVIEWER_NAME")
  else
    FAILED+=("$REVIEWER_NAME")
  fi
done

# Build result JSON
SUCCESS_LIST=$(printf '%s\n' "${SUCCESSFUL[@]}" | jq -R . | jq -s '.' 2>/dev/null || echo '[]')
FAILED_LIST=$(printf '%s\n' "${FAILED[@]}" | jq -R . | jq -s '.' 2>/dev/null || echo '[]')

cat <<EOF
{"status":"ok","action":"$ACTION","successful_reviewers":$SUCCESS_LIST,"failed_reviewers":$FAILED_LIST}
EOF

[ ${#FAILED[@]} -gt 0 ] && exit 1
exit 0
