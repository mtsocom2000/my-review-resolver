# Test Cases (v2.2.0)

All scripts output JSON. Expected outputs below assume `gh` CLI is installed and authenticated.

## Test 1: check-branch.sh — Match

**Input:**
```bash
./scripts/check-branch.sh https://github.com/example/api/pull/42
```
- PR Branch: `feature/auth`
- Local Branch: `feature/auth`
- Uncommitted Changes: 0

**Expected JSON:**
```json
{"status":"ok","local_branch":"feature/auth","pr_branch":"feature/auth","match":true,"uncommitted_files":0}
```

---

## Test 2: check-branch.sh — Mismatch

**Input:**
```bash
./scripts/check-branch.sh https://github.com/example/api/pull/42
```
- PR Branch: `feature/auth`
- Local Branch: `main`
- Uncommitted Changes: 0

**Expected JSON:**
```json
{"status":"info","local_branch":"main","pr_branch":"feature/auth","match":false,"uncommitted_files":0}
```

---

## Test 3: check-branch.sh — Uncommitted changes

**Input:**
```bash
./scripts/check-branch.sh https://github.com/example/api/pull/42
```
- PR Branch: `feature/auth`
- Local Branch: `feature/auth`
- Uncommitted Changes: 2

**Expected JSON:**
```json
{"status":"info","local_branch":"feature/auth","pr_branch":"feature/auth","match":true,"uncommitted_files":2}
```

---

## Test 4: fetch-pr-comments.sh — Normal

**Input:** (dryrun or mock required)
```bash
DRY_RUN=true ./scripts/fetch-pr-comments.sh https://github.com/example/api/pull/42
```

**Expected JSON structure:**
```json
{
  "status": "ok",
  "owner": "example",
  "repo": "api",
  "number": 42,
  "comments": {
    "inline": [{"id": 123, "body": "...", "path": "src/auth.ts", "line": 42, "author": "reviewer"}],
    "reviews": [{"id": 456, "body": "...", "state": "CHANGES_REQUESTED", "author": "reviewer"}],
    "general": [{"id": 789, "body": "...", "author": "reviewer"}]
  }
}
```

---

## Test 5: fetch-pr-comments.sh — gh not installed

**Expected exit code 2, JSON:**
```json
{"status":"fallback_needed","method":"mcp","platform":"github","error":"gh CLI not installed"}
```

---

## Test 6: verify-changes.sh — All green

**Input:** In a Node.js project directory
```bash
DRY_RUN=true ./scripts/verify-changes.sh
```

**Expected JSON:**
```json
{
  "status": "pass",
  "steps": {
    "build": {"label":"build","status":"dryrun","exit_code":0},
    "test": {"label":"test","status":"dryrun","exit_code":0},
    "lint": {"label":"lint","status":"dryrun","exit_code":0}
  }
}
```

---

## Test 7: compose-reply.sh — Resolved

**Input:**
```bash
echo '{"comment_id":"123","action":"resolved","fix_commit":"abc123","fix_summary":"Added parameterized queries"}' | ./scripts/compose-reply.sh
```

**Expected output:**
```
This has been fixed in commit abc123. Added parameterized queries
```

---

## Test 8: compose-reply.sh — Skipped

**Input:**
```bash
echo '{"comment_id":"456","action":"skipped","reason":"This pattern is intentional per project convention"}' | ./scripts/compose-reply.sh
```

**Expected output:**
```
Skipped: This pattern is intentional per project convention
```

---

## Test 9: reply-to-comment.sh — Dryrun

**Input:**
```bash
DRY_RUN=true echo '{"pr_url":"https://github.com/example/api/pull/42","comment_id":"123","message":"Fixed"}' | ./scripts/reply-to-comment.sh
```

**Expected JSON:**
```json
{"status":"dryrun","platform":"github","comment_id":"123","action":"reply","message_len":5}
```

---

## Test 10: reply-to-comment.sh — gh not available

**Input:** (without DRY_RUN, with no gh CLI)
```bash
PATH="/dev/null" echo '{"pr_url":"https://github.com/example/api/pull/42","comment_id":"123","message":"Fixed"}' | ./scripts/reply-to-comment.sh
```

**Expected exit code 2, JSON:**
```json
{"status":"fallback","method":"mcp","platform":"github","comment_id":"123","action":"reply","error":"gh CLI not available"}
```

---

## Test 11: rollback.sh — Multiple commits (dryrun)

**Input:**
```bash
DRY_RUN=true ./scripts/rollback.sh abc123 def456
```

**Expected JSON:**
```json
{"rolled_back":["abc123","def456"],"failed":[]}
```

---

## Test 12: rollback.sh — Invalid SHA

**Input:**
```bash
DRY_RUN=true ./scripts/rollback.sh invalid_sha_here
```

**Expected JSON:**
```json
{"rolled_back":[],"failed":["invalid_sha_here"]}
```

---

## Test 13: MCP fallback detection (pipeline integration)

**Scenario:** `fetch-pr-comments.sh` exits 2 with `fallback_needed`.

**Expected behavior in pipeline:**
1. Detect exit code 2
2. Read `fallback_hint` field to determine which MCP tools to use
3. Call MCP tools with parsed owner/repo/number
4. Normalize MCP responses to match script JSON format
5. Proceed to Stage 4 normally

---

## Test 14: Dependency graph — Overlap detection

**Input (to agents/dependency-analyzer.md):**
```json
{
  "comment_analyses": [
    {"id":"c1","file":"src/auth.ts","line":42,"original_body":"SQL injection via string interpolation","severity":"Critical"},
    {"id":"c2","file":"src/auth.ts","line":43,"original_body":"Use parameterized queries instead of string building","severity":"Medium"}
  ],
  "changed_files": {"src/auth.ts": "function getUser(id) { return db.query(`SELECT * FROM users WHERE id = ${id}`) }"}
}
```

**Expected edge in output:**
```json
{"source":"c1","target":"c2","type":"OVERLAP","confidence":"high","reason":"..."}
```

---

## Test 15: Dependency graph — Conflict detection

**Input:**
```json
{
  "comment_analyses": [
    {"id":"c3","file":"src/config.ts","line":15,"original_body":"Move timeout to environment variable","severity":"Medium"},
    {"id":"c4","file":"src/config.ts","line":15,"original_body":"Keep hardcoded — less indirection for a simple value","severity":"Low"}
  ],
  ...
}
```

**Expected edge:**
```json
{"source":"c3","target":"c4","type":"CONFLICT","confidence":"high"}
```

---

## Test 16: Dependency graph — Supersede detection

**Input:**
```json
{
  "comment_analyses": [
    {"id":"c5","file":"src/auth.ts","line":42,"original_body":"Implement parameterized queries","severity":"Critical"},
    {"id":"c6","file":"src/auth.ts","line":45,"original_body":"Sanitize user input before using in query","severity":"Medium"}
  ]
}
```

**Expected edge:**
```json
{"source":"c5","target":"c6","type":"SUPERSEDES","confidence":"high"}
```

---

## Test 17: Pipeline — End-to-end dryrun

```bash
DRY_RUN=true ./scripts/dryrun.sh https://github.com/example/api/pull/42
```

Expected: All stages print dryrun messages without modifying git state or calling external APIs.
