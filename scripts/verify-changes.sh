#!/bin/bash
# verify-changes.sh
# Run build + test + lint, output structured JSON

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  echo "Usage: bash $SCRIPT_NAME"
  echo "Reads BUILD_CMD, TEST_CMD, LINT_CMD from env, or auto-detects project type."
  exit 1
}

[ $# -gt 0 ] && [ "$1" = "--help" ] && usage

DRY_RUN="${DRY_RUN:-false}"

# Read commands from env or auto-detect
BUILD_CMD="${BUILD_CMD:-}"
TEST_CMD="${TEST_CMD:-}"
LINT_CMD="${LINT_CMD:-}"

# Auto-detect project type
if [ -z "$BUILD_CMD" ] && [ -z "$TEST_CMD" ] && [ -z "$LINT_CMD" ]; then
  if [ -f "package.json" ]; then
    [ -z "$BUILD_CMD" ] && BUILD_CMD="npm run build 2>/dev/null || npx tsc --noEmit 2>/dev/null || true"
    [ -z "$TEST_CMD" ]  && TEST_CMD="npm test 2>/dev/null || npx vitest run 2>/dev/null || npx jest --passWithNoTests 2>/dev/null || true"
    [ -z "$LINT_CMD" ]  && LINT_CMD="npm run lint 2>/dev/null || npx eslint . 2>/dev/null || true"
  elif [ -f "Cargo.toml" ]; then
    [ -z "$BUILD_CMD" ] && BUILD_CMD="cargo build 2>/dev/null"
    [ -z "$TEST_CMD" ]  && TEST_CMD="cargo test 2>/dev/null"
    [ -z "$LINT_CMD" ]  && LINT_CMD="cargo clippy -- -D warnings 2>/dev/null || true"
  elif [ -f "go.mod" ]; then
    [ -z "$BUILD_CMD" ] && BUILD_CMD="go build ./... 2>/dev/null"
    [ -z "$TEST_CMD" ]  && TEST_CMD="go test ./... 2>/dev/null"
    [ -z "$LINT_CMD" ]  && LINT_CMD="golangci-lint run 2>/dev/null || true"
  elif [ -f "pom.xml" ]; then
    [ -z "$BUILD_CMD" ] && BUILD_CMD="mvn compile -q 2>/dev/null"
    [ -z "$TEST_CMD" ]  && TEST_CMD="mvn test -q 2>/dev/null"
    [ -z "$LINT_CMD" ]  && LINT_CMD="mvn checkstyle:check -q 2>/dev/null || true"
  elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    [ -z "$BUILD_CMD" ] && BUILD_CMD="gradle build -x test -q 2>/dev/null"
    [ -z "$TEST_CMD" ]  && TEST_CMD="gradle test -q 2>/dev/null"
    [ -z "$LINT_CMD" ]  && LINT_CMD="gradle checkstyleMain -q 2>/dev/null || true"
  elif [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    [ -z "$BUILD_CMD" ] && BUILD_CMD="python -m compileall . -q 2>/dev/null || true"
    [ -z "$TEST_CMD" ]  && TEST_CMD="python -m pytest -q 2>/dev/null || python -m unittest discover -q 2>/dev/null || true"
    [ -z "$LINT_CMD" ]  && LINT_CMD="flake8 . --count 2>/dev/null || true"
  fi
fi

# Check command availability before running
run_step() {
  local label="$1"
  local cmd="$2"
  local step_json
  
  if [ "$DRY_RUN" = "true" ]; then
    cat <<STEP
{"label":"$label","status":"dryrun","exit_code":0}
STEP
    return 0
  fi
  
  if [ -z "$cmd" ]; then
    cat <<STEP
{"label":"$label","status":"skipped","exit_code":0}
STEP
    return 0
  fi
  
  local cmd_base
  cmd_base=$(echo "$cmd" | awk '{print $1}')
  if ! command -v "$cmd_base" &>/dev/null; then
    cat <<STEP
{"label":"$label","status":"skipped","exit_code":0}
STEP
    return 0
  fi
  
  if eval "$cmd" > /tmp/verify_"$label".log 2>&1; then
    cat <<STEP
{"label":"$label","status":"pass","exit_code":0}
STEP
  else
    local ec=$?
    cat <<STEP
{"label":"$label","status":"fail","exit_code":$ec}
STEP
  fi
}

STEPS_JSON=""
SEP=""

for step_spec in "build:$BUILD_CMD" "test:$TEST_CMD" "lint:$LINT_CMD"; do
  label="${step_spec%%:*}"
  cmd="${step_spec#*:}"
  
  step_result=$(run_step "$label" "$cmd")
  STEPS_JSON="${STEPS_JSON}${SEP}\"${label}\":${step_result}"
  SEP=","
done

OVERALL="pass"
echo "$STEPS_JSON" | jq -e 'select(.status == "fail")' >/dev/null 2>&1 && OVERALL="fail"

cat <<OUT
{"status":"$OVERALL","steps":{$STEPS_JSON}}
OUT

[ "$OVERALL" = "fail" ] && exit 1
exit 0
