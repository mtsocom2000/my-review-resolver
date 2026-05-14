#!/bin/bash
# rollback.sh
# Revert specified fix commits locally (does not auto-push)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: bash $SCRIPT_NAME <sha1> [sha2 ...]
   or: echo '["sha1","sha2"]' | bash $SCRIPT_NAME --from-json

Rolls back commits in reverse order (newest first) using git revert.
Outputs JSON: { "rolled_back": [...], "failed": [...] }

Exit codes:
  0   — All specified commits rolled back
  1   — Some or all commits failed to revert
EOF
  exit 1
}

[ $# -gt 0 ] && [ "$1" = "--help" ] && usage

DRY_RUN="${DRY_RUN:-false}"
ROLLED_BACK=()
FAILED=()

# Get SHAs from args or stdin
SHAS=()
if [ $# -eq 0 ]; then
  if [ -t 0 ]; then
    usage
  fi
  while IFS= read -r line; do
    SHAS+=("$line")
  done < <(jq -r '.[]')
else
  SHAS=("$@")
fi

# Collect SHAs in reverse order (newest first needed for revert)
REVERT_ORDER=()
for sha in "${SHAS[@]}"; do
  REVERT_ORDER=("$sha" "${REVERT_ORDER[@]}")
done

for sha in "${REVERT_ORDER[@]}"; do
  if [ "$DRY_RUN" = "true" ]; then
    ROLLED_BACK+=("$sha")
    continue
  fi

  # Check if SHA is valid and has a parent
  if git rev-parse --quiet "$sha" &>/dev/null && \
     git rev-parse --quiet "$sha^" &>/dev/null 2>&1; then
    if git revert --no-edit "$sha" &>/dev/null; then
      ROLLED_BACK+=("$sha")
    else
      FAILED+=("$sha")
    fi
  else
    FAILED+=("$sha")
  fi
done

ROLLED_JSON=$(printf '%s\n' "${ROLLED_BACK[@]}" | jq -R . | jq -s '.' 2>/dev/null || echo '[]')
FAILED_JSON=$(printf '%s\n' "${FAILED[@]}" | jq -R . | jq -s '.' 2>/dev/null || echo '[]')

cat <<EOF
{"rolled_back":$ROLLED_JSON,"failed":$FAILED_JSON}
EOF

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Warning: ${#FAILED[@]} commit(s) failed to revert." >&2
  exit 1
fi
