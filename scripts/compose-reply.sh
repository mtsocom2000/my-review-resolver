#!/bin/bash
# compose-reply.sh
# Generate structured reply drafts from fix results
# Input JSON: { comment_id, comment_body, file, line, action, fix_commit?, fix_summary?, reason? }
# Output: markdown reply text to stdout

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: echo '<JSON>' | bash $SCRIPT_NAME

Stdin JSON fields:
  comment_id (string)   — required
  action (string)        — required: resolved|skipped|not_applicable|needs_discussion|part_of_diff|outdated|fixed_elsewhere|user_override
  fix_commit (string)   — optional, for resolved
  fix_summary (string)  — optional, short description of what was done

Exit codes:
  0   — Reply text written to stdout
  1   — Input error
EOF
  exit 1
}

[ $# -gt 0 ] && [ "$1" = "--help" ] && usage

if [ -t 0 ]; then
  echo "Error: No input provided. Pipe JSON to stdin." >&2
  exit 1
fi

INPUT=$(cat)

COMMENT_ID=$(echo "$INPUT" | jq -r '.comment_id // empty')
ACTION=$(echo "$INPUT" | jq -r '.action // empty')
FIX_COMMIT=$(echo "$INPUT" | jq -r '.fix_commit // empty')
FIX_SUMMARY=$(echo "$INPUT" | jq -r '.fix_summary // empty')
REASON=$(echo "$INPUT" | jq -r '.reason // empty')

[ -z "$COMMENT_ID" ] && echo '{"error":"Missing comment_id"}' >&2 && exit 1
[ -z "$ACTION" ] && echo '{"error":"Missing action"}' >&2 && exit 1

generate_reply() {
  case "$ACTION" in
    resolved)
      if [ -n "$FIX_COMMIT" ] && [ -n "$FIX_SUMMARY" ]; then
        echo "This has been fixed in commit $FIX_COMMIT. $FIX_SUMMARY"
      elif [ -n "$FIX_COMMIT" ]; then
        echo "This has been fixed in commit $FIX_COMMIT."
      elif [ -n "$FIX_SUMMARY" ]; then
        echo "Fixed: $FIX_SUMMARY"
      else
        echo "This has been resolved."
      fi
      ;;
    skipped)
      echo "Skipped: $REASON"
      ;;
    not_applicable)
      echo "This comment does not apply to the current state of the code."
      ;;
    needs_discussion)
      echo "This requires further discussion. Please clarify the expected approach."
      ;;
    part_of_diff)
      echo "This concern is about code outside the current PR scope. No changes made here."
      ;;
    outdated)
      echo "The referenced code has changed since this comment was made. This is no longer applicable."
      ;;
    fixed_elsewhere)
      echo "This has been addressed in a separate commit/workstream."
      ;;
    user_override)
      echo "Declined: $REASON"
      ;;
    *)
      echo "Unknown action: $ACTION"
      exit 1
      ;;
  esac
}

generate_reply
