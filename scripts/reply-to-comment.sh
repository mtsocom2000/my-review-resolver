#!/bin/bash
# reply-to-comment.sh
# Post reply or resolve a PR comment (gh CLI primary, MCP fallback signal)
# Output: JSON { status, method, platform, comment_id }

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: echo '<JSON>' | bash $SCRIPT_NAME

Stdin JSON:
{
  "pr_url": "https://github.com/owner/repo/pull/42",
  "comment_id": "123456",
  "message": "Reply text",
  "action": "reply" | "resolve"
}

Exit codes:
  0   — Posted/resolved via gh CLI
  1   — Input error (details on stderr)
  2   — gh CLI not available (fallback_needed JSON on stdout)
EOF
  exit 1
}

[ $# -gt 0 ] && [ "$1" = "--help" ] && usage

if [ -t 0 ]; then
  echo '{"status":"error","error":"No input provided. Pipe JSON to stdin."}'
  exit 1
fi

INPUT=$(cat)

PR_URL=$(echo "$INPUT" | jq -r '.pr_url // empty')
COMMENT_ID=$(echo "$INPUT" | jq -r '.comment_id // empty')
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')
ACTION=$(echo "$INPUT" | jq -r '.action // "reply"')

[ -z "$PR_URL" ] && echo '{"status":"error","error":"Missing pr_url"}' && exit 1
[ -z "$COMMENT_ID" ] && echo '{"status":"error","error":"Missing comment_id"}' && exit 1

OWNER=""; REPO=""; NUMBER=""
if [[ "$PR_URL" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$PR_URL" =~ gitlab\..+/([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
  echo '{"status":"error","error":"GitLab reply via script not yet supported. Use MCP tools."}'
  exit 1
else
  echo "{\"status\":\"error\",\"error\":\"Could not parse PR URL: $PR_URL\"}"
  exit 1
fi

DRY_RUN="${DRY_RUN:-false}"

if [ "$DRY_RUN" = "true" ]; then
  cat <<EOF
{"status":"dryrun","platform":"github","comment_id":"$COMMENT_ID","action":"$ACTION","message_len":${#MESSAGE}}
EOF
  exit 0
fi

# Check gh CLI availability
if ! command -v gh &>/dev/null; then
  cat <<EOF
{"status":"fallback","method":"mcp","platform":"github","comment_id":"$COMMENT_ID","action":"$ACTION","error":"gh CLI not available"}
EOF
  exit 2
fi

if ! gh auth status &>/dev/null; then
  cat <<EOF
{"status":"fallback","method":"mcp","platform":"github","comment_id":"$COMMENT_ID","action":"$ACTION","error":"gh CLI not authenticated"}
EOF
  exit 2
fi

# Execute
case "$ACTION" in
  reply)
    if [ -z "$MESSAGE" ]; then
      echo '{"status":"error","error":"Missing message for reply action"}'
      exit 1
    fi
    if gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$COMMENT_ID/replies" \
         -X POST -f "body=$MESSAGE" --silent 2>/dev/null; then
      echo "{\"status\":\"ok\",\"method\":\"gh\",\"platform\":\"github\",\"comment_id\":\"$COMMENT_ID\",\"action\":\"reply\"}"
    else
      echo "{\"status\":\"ok\",\"method\":\"gh\",\"platform\":\"github\",\"comment_id\":\"$COMMENT_ID\",\"action\":\"reply_failed\"}"
    fi
    ;;
  resolve)
    if gh api "repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID" \
         -X PATCH -f 'body=@- <<< "$MESSAGE"' 2>/dev/null; then
      echo "{\"status\":\"ok\",\"method\":\"gh\",\"platform\":\"github\",\"comment_id\":\"$COMMENT_ID\",\"action\":\"resolve\"}"
    else
      echo "{\"status\":\"fallback\",\"method\":\"mcp\",\"platform\":\"github\",\"comment_id\":\"$COMMENT_ID\",\"action\":\"resolve\",\"error\":\"gh CLI resolve failed — try MCP or manual\"}"
      exit 2
    fi
    ;;
  *)
    echo "{\"status\":\"error\",\"error\":\"Unknown action: $ACTION\"}"
    exit 1
    ;;
esac
