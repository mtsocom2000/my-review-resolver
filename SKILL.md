---
name: pr-comment-fix
description: >
  Use when given a GitHub/GitLab PR URL to check local branch sync status,
  fetch PR comments, analyze comment validity, apply fixes with multi-agent
  parallel review (using ECC agents if available), verify build/tests pass,
  and optionally push and mark comments resolved.
origin: custom
version: 2.3.0
ecc-integration: true
user-invocable: true
no-emoji: true
---

# PR Comment Fix Workflow

Complete pipeline: fetch PR comments → analyze validity → parallel multi-agent review → fix → verify → push → reply → re-request review.

## Core Principles

- **Do not blindly trust comments** — verify the issue exists and is reasonable before acting.
- **Every fix must be verified** — compile + test + lint must pass before push.
- **User confirmation at critical points** — branch switch, push, and each fix plan require explicit approval.
- **Atomic commits** — one fix per commit, one commit per resolved comment where feasible.
- **No emoji in comment replies** — professional, concise, reference-specific language only.
- **Use existing scripts** — all API calls and git operations are implemented in `scripts/`. Do not write ad-hoc code for these operations.

## API Fallback Chain

All external API operations (fetching comments, posting replies) follow this priority:

1. **gh CLI** — primary. Shell scripts call `gh api` directly.
2. **MCP tools** — fallback when `gh` is not installed or not authenticated. Use the host's available MCP tools.
3. **User prompt** — last resort. Ask the user to run the command manually.

### When to use MCP fallback

A script will output `{"status":"fallback_needed","method":"mcp",...}` when `gh` is not available. Parse this signal and switch to MCP tools.

### MCP tools reference

**For GitHub:**

| Operation | gh CLI equivalent | MCP tool(s) |
|-----------|------------------|-------------|
| Fetch PR info | `gh api repos/o/r/pulls/N` | `getPullRequest(owner, repo, pullNumber)` |
| Fetch inline comments | `gh api repos/o/r/pulls/N/comments` | `getPullRequestComments(owner, repo, pullNumber)` |
| Fetch reviews | `gh api repos/o/r/pulls/N/reviews` | `listPullRequestReviews(owner, repo, pullNumber)` |
| Fetch general comments | `gh api repos/o/r/issues/N/comments` | `getIssueComments(owner, repo, issueNumber)` |
| Reply to review comment | `gh api .../comments/ID/replies -X POST` | `createPullRequestReviewComment(...)` |
| Post general comment | `gh api .../issues/N/comments -X POST` | `createIssueComment(owner, repo, issueNumber, body)` |

**For GitLab:**

| Operation | MCP tool(s) |
|-----------|-------------|
| Fetch MR info | `getMergeRequest(project, iid)` |
| Fetch MR comments | `getMergeRequestNotes(project, iid)` |
| Reply | `addMergeRequestNote(project, iid, body)` |

### Output format normalization

When falling back to MCP tools, normalize the API responses to match the JSON format that the scripts would produce:

```json
{
  "status": "ok",
  "method": "mcp",
  "owner": "owner",
  "repo": "repo",
  "number": 42,
  "pr_info": { ... },
  "comments": {
    "inline": [{ "id": 123, "body": "...", "path": "src/a.ts", "line": 42, "author": "user" }],
    "reviews": [{ "id": 456, "body": "...", "state": "CHANGES_REQUESTED", "author": "user" }],
    "general": [{ "id": 789, "body": "...", "author": "user" }]
  }
}
```

### Fallback at each stage

| Stage | Normal path | MCP fallback | Last resort |
|-------|-------------|--------------|-------------|
| 3 (Fetch comments) | `bash scripts/fetch-pr-comments.sh $PR_URL` | Call MCP tools to assemble equivalent JSON | Ask user to paste comments manually |
| 5 (Dep graph) | subagent analysis | Not MCP-recoverable; retry or flatten order | Show conflict to user, let them decide |
| 11 (Reply) | `bash scripts/reply-to-comment.sh` echo pipe | Call `createPullRequestReviewComment` / `createIssueComment` MCP tool | Print reply text, ask user to post manually |
| 11 (Resolve) | `bash scripts/reply-to-comment.sh action=resolve` | Call MCP tool to resolve the comment | Ask user to resolve manually
| 12 (Re-request) | `bash scripts/re-request-review.sh` echo pipe | Call MCP tool `requestPullRequestReviewers` if available, or `addPullRequestReviewer` | Ask user to re-request review manually

## Pre-flight: ECC Detection

Before starting the pipeline, run:

```
tsx ./lib/ecc-detector.ts
```

If output shows `installed: true`, note the agent count and paths. Use ECC agents for Stage 6 parallel review (see ECC section below). If not installed, use the built-in subagents from `agents/`.

## Pipeline

### Stage 0: URL Validation & Input

Parse the PR URL into components (owner, repo, number). Supported formats:
- `https://github.com/owner/repo/pull/42`
- `gitlab.example.com/owner/repo/-/merge_requests/42`
- Plain `owner/repo#42` style from chat references

If parsing fails, ask the user for the correct URL before proceeding.

### Stage 1: Branch Check

**Objective:** Verify local branch matches PR branch.

**Script call:**

```
bash ./scripts/check-branch.sh <PR_URL>
```

**Expected output:**

```json
{
  "status": "ok",
  "local_branch": "feature/foo",
  "pr_branch": "feature/foo",
  "remote": "origin",
  "match": true,
  "uncommitted_files": 0,
  "upstream": "origin/feature/foo"
}
```

**Decision table:**

| match | uncommitted files | Action |
|-------|-------------------|--------|
| true  | 0                 | Proceed to Stage 2 |
| true  | >0                | Ask user: stash / commit / abort |
| false | any               | Ask user: switch branch / abort |

Also display the PR summary line (title, state, commit count) from the script output.

### Stage 2: Sync Latest

**Script call:**

```
bash ./scripts/sync-pr.sh <remote> <branch>
```

Show commit differences (behind/ahead) from script output before proceeding. Ask user confirmation before syncing.

### Stage 3: Fetch Comments

**Script call:**

```
bash ./scripts/fetch-pr-comments.sh <PR_URL>
```

**Exit code handling:**
| Exit | Output | Action |
|------|--------|--------|
| 0 | JSON with comments | Parse and display summary, proceed |
| 1 | JSON parse/input error | Show error, abort |
| 2 | `{"status":"fallback_needed","method":"mcp",...}` | Switch to MCP tools (see fallback section below) |

When script succeeds, output is a JSON object with three comment categories:
- `inline` — code line-level comments
- `reviews` — review submissions (APPROVE/CHANGES_REQUESTED/COMMENTED)
- `general` — top-level PR discussion comments

Display a summary:

```
Comments: X total
  Inline:     A
  Reviews:    B  (APPROVE: C, CHANGES: D, COMMENTED: E)
  General:    F
```

**MCP fallback:** If script exits code 2 with `fallback_needed`, use the host's MCP tools to fetch the data. See the [API Fallback Chain](#api-fallback-chain) section for exact MCP tool mapping. Assemble the MCP responses into the same JSON format as the script output.

If MCP is also unavailable, ask the user to install `gh` CLI and re-run.

If count is suspiciously low (e.g., 0 total for a PR that clearly has comments), check:
1. `gh auth status` is valid (or MCP tool status)
2. No pagination failure
3. If using GitLab, confirm API endpoint is reachable

### Stage 4: Analyze Comments (Subagent)

**Objective:** For each comment, determine if the issue exists and is reasonable.

**Spawn subagent** using the instructions in `agents/analyzer.md`.

**Input to subagent:** The full comment JSON from Stage 3 plus the current file contents at each comment's location.

**Expected output from analyzer subagent:**

```json
{
  "analyses": [
    {
      "comment_id": "123456",
      "file": "src/auth.ts",
      "line": 42,
      "exists": true,
      "valid": true,
      "severity": "Critical",
      "auto_fixable": true,
      "confidence": "high",
      "reasoning": "String concatenation in SQL query at line 42 allows injection",
      "needs_human_review": false
    }
  ]
}
```

**Display a table** to the user:

```
| ID     | Location       | Issue         | Exists | Valid | Priority  | Fix  |
|--------|----------------|---------------|--------|-------|-----------|------|
| 123456 | auth.ts:42     | SQL injection | [Y]    | [Y]   | Critical  | Auto |
| 123457 | utils.ts:15    | Naming        | [Y]    | [~]   | Low       | Skip |
| 123458 | config.ts:33   | Missing cache | [N]    | [-]   | -         | Skip |
```

**Legend:** Exists: [Y]es [N]o [~]Partial | Valid: [Y]es [N]o [~]Needs review | Fix: [Auto] auto [Skip] skip [Review] needs review

**Confirmation point:** Ask user before fixing. Offer to skip specific comments or categories.

### Stage 5: Comment Dependency Graph Analysis (Subagent)

**Objective:** Model the relationships between all actionable comments from Stage 4. Identify clusters, conflicts, supersedes relationships, and derive the optimal fix order.

This stage catches situations that a flat "fix each comment independently" approach misses:
- Two comments describe the same bug → merge into one fix
- Fixing comment A automatically resolves comment B → skip comment B's fix
- Comments A and B propose mutually exclusive solutions → flag for human decision
- Comments C, D, E all point to the same architectural root cause → one refactor resolves all three

**Spawn subagent** using the instructions in `agents/dependency-analyzer.md`.

**Input to subagent:**
- Stage 4 analysis output (full JSON with exists/valid/auto_fixable per comment)
- Full git diff (staged + unstaged)
- Changed file contents
- PR title and description

**Expected output from subagent:**

```json
{
  "dependency_graph": {
    "nodes": [
      {"id": "comment_123", "file": "auth.ts", "line": 42, "summary": "SQL injection"},
      {"id": "comment_124", "file": "auth.ts", "line": 45, "summary": "Add input validation"},
      {"id": "comment_125", "file": "service.ts", "line": 88, "summary": "N+1 query"}
    ],
    "edges": [
      {"source": "comment_123", "target": "comment_124", "type": "OVERLAP",
       "confidence": "high", "reason": "Both comments reference the same database call chain; fixing parameterization requires a new query layer that handles validation"},
      {"source": "comment_125", "target": "comment_124", "type": "SAME_ROOT",
       "confidence": "medium", "reason": "N+1 query and missing validation both stem from raw SQL in handlers vs a shared query layer"},
      {"source": "comment_126", "target": "comment_128", "type": "CONFLICT",
       "confidence": "high", "reason": "Comment 126 suggests inline error handling, comment 128 suggests a global error boundary"}
    ],
    "clusters": [
      {
        "id": "cluster_1",
        "comments": ["comment_123", "comment_124", "comment_125"],
        "root_cause": "Database access layer needs refactoring",
        "recommended_fix": "Extract a query builder layer (fixes 123, 124, 125 in one commit)"
      }
    ],
    "conflicts": [
      {
        "comments": ["comment_126", "comment_128"],
        "nature": "architectural_choice",
        "options": [
          {"choice": "global_error_boundary", "rationale": "Aligned with PR's existing error handling pattern", "would_resolve": ["comment_128"]},
          {"choice": "inline_handling", "rationale": "Simpler change, no new abstraction", "would_resolve": ["comment_126"]}
        ],
        "recommendation": "Choose global error boundary"
      }
    ],
    "supersedes": [
      {"superseding_comment": "comment_123", "superseded_comments": ["comment_124"],
       "confidence": "high", "reason": "Parameterized query layer inherently handles input sanitization"}
    ],
    "resolution_order": ["comment_123", "comment_125", {"conflict": "comment_126_vs_128"}, ...]
  },
  "summary": {
    "total_comments": 10,
    "actionable": 8,
    "clustered": 5,
    "independent": 3,
    "conflicts": 1,
    "superseded": 1,
    "fix_plan": "Fix cluster 1 first (database layer refactor), then choose conflict resolution, then fix remaining independent items"
  }
}
```

**Relationship type reference:**

| Type | Definition | Detection signal | Action |
|------|-----------|-----------------|--------|
| **OVERLAP** | Two comments describe the same root issue | Same file, same function, overlapping line ranges, keyword overlap | Merge into one fix. Apply only once. |
| **CONFLICT** | Fixes are mutually exclusive | Comment A says "do X", comment B says "do opposite of X" or "do Y that prevents X" | Present both options to user. Do not auto-resolve. |
| **SAME_ROOT** | Different symptoms, same root cause | Comments in different files/functions but all trace to one architectural layer or shared component | One refactor resolves all. Flag as cluster fix. |
| **SUPERSEDES** | Fixing A makes B irrelevant | A introduces abstraction/mechanism that inherently handles B's concern | Skip B's fix. Note in commit message. |
| **DEPENDS_ON** | B cannot be fixed before A | B's fix requires code that A introduces, or A must run first for correctness | Enforce topological order in resolution_order. |

**Display to user:**

```
=== Comment Dependency Analysis ===

Cluster 1: Database access refactoring (3 comments)
  #123 [auth.ts:42] SQL injection
  #124 [auth.ts:45] Missing input validation
  #125 [service.ts:88] N+1 query
  Root cause: Direct SQL in handlers — no shared query layer
  Recommendation: Extract query builder layer → resolves all 3
  Confidence: high

Conflict: Architectural choice
  #126 vs #128: Inline error handling vs global error boundary
  Options:
    [1] Global error boundary (recommended — aligned with PR patterns)
    [2] Inline handling (simpler change, no new abstraction)
  Cannot auto-resolve — user decision required

Supersedes:
  #130 [config.ts:22] Hardcoded timeout value
  → Already handled by #129's config abstraction change → skip

Proposed resolution order:
  1. Cluster 1: Database layer refactor (#123, #124, #125)
  2. Conflict: Choose #126 or #128
  3. #129, #131 (independent)

Accept this resolution plan? (yes / view details / reorder / skip)
```

**Confidence tiers:**
- **high** (≥90%): Auto-apply the relationship. Merge clusters, skip superseded.
- **medium** (70-89%): Show reasoning, ask user to confirm before auto-applying.
- **low** (<70%): Mark as "possible relationship", don't change order, just note for user.

**Conflict cannot be auto-resolved.** Always present to user with options and recommendation. If user chooses option A, mark conflicting comments as "rejected — see decision" and skip them.

**Output feeds into:**
- Stage 6 (Parallel Review): provide the dependency graph so reviewers understand clustering
- Stage 7 (Apply Fixes): use `resolution_order` to determine fix sequence; skip superseded comments entirely; apply cluster fixes as single commits

### Stage 6: Parallel Review (Multi-Agent)

Spawn review subagents in parallel. Each agent reads the full diff and affected files.

**If ECC is available** (detected in pre-flight), use ECC agents in priority order:

1. `security-reviewer` — always
2. `performance-optimizer` — always
3. `code-reviewer` — always
4. Language-specific agents based on file extensions:
   - `.ts`, `.tsx`, `.js`, `.jsx` → `typescript-reviewer`
   - `.py` → `python-reviewer`
   - `.java` → `java-reviewer`
   - `.go` → `go-reviewer`
   - `.kt` → `kotlin-reviewer`
   - `.rs` → `rust-reviewer`
   - `.cpp`, `.cc`, `.h` → `cpp-reviewer`
   - `.sql` → `database-reviewer`

**If ECC is not available**, use built-in agents from `agents/`:
- `security` (agents/security.md)
- `performance` (agents/performance.md)
- `quality` (agents/quality.md)

**Each subagent input spec:**

```json
{
  "diff": "string (git diff --staged + git diff --no-staged)",
  "changed_files": [{"path": "string", "content": "string"}],
  "comments": [{"id": "string", "file": "string", "line": "number", "body": "string"}]
}
```

**Each subagent output spec:**

```json
{
  "findings": [
    {
      "severity": "HIGH|MEDIUM|LOW",
      "file": "src/auth.ts",
      "line": 42,
      "issue": "SQL injection via string concatenation",
      "fix_suggestion": "Use parameterized query",
      "comment_id": "123456"
    }
  ]
}
```

**Merge strategy after all subagents return:**
1. Deduplicate findings by (file, line, normalized_issue_text)
2. During deduplication, keep the highest severity
3. If two agents give contradictory findings for the same line, flag for human review
4. Integrate findings into the fix plan started in Stage 4

**Timeout:** If any subagent does not respond within 60 seconds, proceed without its findings and note the gap.

### Stage 7: Apply Fixes

**Order:** Follow the `resolution_order` from Stage 5 dependency analysis.
- Apply **cluster fixes** as single commits (multiple comments resolved by one refactor)
- Skip **superseded** comments entirely
- Present **conflict** options to user before fixing either side
- Fix **independent** items in the order specified

For each fixable comment, present the fix plan to the user:

```
=== Fix Plan for Comment #123456 ===
Location: src/auth.ts:42
Issue: SQL injection via string concatenation
Severity: Critical
Proposed Fix: Replace string interpolation with parameterized query
Code Change:
```diff
- const query = `SELECT * FROM users WHERE id = ${userId}`;
+ const query = `SELECT * FROM users WHERE id = $1`;
+ const result = await db.query(query, [userId]);
```
Proceed with this fix? (yes / no / skip / show more)
```

After each fix, stage the change with `git add <file>` but do not commit yet.

**Fix ordering:** Apply Critical → High → Medium → Low severity fixes. This ensures the most important issues are fixed first even if pipeline stops early.

After all fixes are staged, create atomic commits:

```
git commit -m "fix: SQL injection in auth.ts (comment #123456)"
```

One comment = one commit. If multiple comments affect the same logical change, group them into one commit and reference both IDs.

### Stage 8: Verify

**Script call:**

```
bash ./scripts/verify-changes.sh
```

Also run `git diff --stat` to show the total changes.

**Output format from script:**

```json
{
  "status": "pass|fail",
  "steps": {
    "build": {"label": "build", "status": "pass|fail", "output": "..."},
    "test":  {"label": "test", "status": "pass|fail", "output": "..."},
    "lint":  {"label": "lint", "status": "pass|fail", "output": "..."}
  }
}
```

**Failure handling:**
- If build fails → show errors, offer to retry or abort
- If tests fail → show failing test names, offer to retry or abort
- Consider `--fix-retry` option: revert all staged changes and re-apply with more cautious approach
- If lint warnings only → inform user, continue

### Stage 9: Final Review (Subagent)

Spawn the validator subagent (`agents/validator.md`) to review the changes:

**Input:** Original comments + diff of applied fixes

**Expected output:**

```json
{
  "fixed_comments": [{"id": "123456", "addressed": true, "comment": "..."}],
  "new_issues": [],
  "verdict": "APPROVE|NEEDS_WORK"
}
```

If verdict is NEEDS_WORK, go back to Stage 7 (Apply Fixes) for the affected comments.

### Stage 10: Push Confirmation

Display a summary report that includes CHANGES_REQUESTED blocking status (parsed from Stage 3's reviews state):

```
PR: owner/repo#42
Branch: feature/foo
Blocking reviewers (CHANGES_REQUESTED): reviewer1 (3 comments), reviewer2 (1 comment)

Fixed: 5 / 6 comments

  [R]  #123456  SQL injection         auth.ts:42       → a1b2c3d   [BLOCKING: reviewer1]
  [Y]  #123457  N+1 query             service.ts:48    → d4e5f6g
  [O]  #123458  Skipped (false positive)
  [Y]  #123459  Naming                utils.ts:12      → f7g8h9i
  [Y]  #123460  Cache missing         config.ts:33     → j0k1l2m
  [R]  #123461  API key hardcoded     payment.ts:8     → n3o4p5q   [BLOCKING: reviewer2]

Verification:
  Build:  [Y] Pass
  Tests:  [Y] Pass (24/24)
  Lint:   [Y] Pass

Push to remote? (yes / no / show commits / edit)
```

**Legend for comment status:** [R]esolved, [Y] fixed, [O] skipped, [B]locked (not fixed — blocking comment).
**BLOCKING** tag means the comment came from a CHANGES_REQUESTED review — the PR cannot be merged until it is addressed or the review is dismissed.

If any blocking comments remain unfixed, warn the user before push:

```
⚠️  WARNING: 2 blocking comments remain unresolved (from reviewer1 CHANGES_REQUESTED)
    PR cannot merge until these are addressed or review is dismissed.
    Continue pushing anyway? (yes / go_back / abort)
```

User must explicitly confirm. Do NOT push without confirmation.

### Stage 11: Reply to Comments

#### Step 10a: Generate reply text

For each applicable comment, compose a reply using:

```
echo '{"comment_id": "123456", "action": "resolved", "fix_commit": "a1b2c3d", "fix_summary": "Added parameterized queries"}' \
  | bash ./scripts/compose-reply.sh
```

#### Step 10b: Post reply and/or resolve

After user confirms the reply, post it using:

```
echo '{"pr_url":"...","comment_id":"123456","message":"Generated reply text","action":"reply_review"}' \
  | bash ./scripts/reply-to-comment.sh
```

**Exit code handling for reply-to-comment.sh:**
| Exit | Meaning | Action |
|------|---------|--------|
| 0 | Posted via gh CLI | Continue to next comment |
| 2 (status:fallback_needed) | gh failed | Use MCP `createPullRequestReviewComment` tool |
| 2 (status:fallback) | gh not installed | Use MCP tool |
| 1 | Input error | Show error, skip this comment |

If user wants to resolve (mark outdated) without a reply:

```
echo '{"pr_url":"...","comment_id":"123456","action":"resolve"}' \
  | bash ./scripts/reply-to-comment.sh
```

For each comment, present:

```
=== Reply for Comment #123456 ===
Original: "String interpolation in SQL query is vulnerable to injection"

Proposed Reply:
"This has been fixed in commit a1b2c3d. Added parameterized queries to prevent SQL injection."

Send this reply? (yes / no / edit / skip)
```

**Action values for compose-reply.sh:**

| action | When to use |
|--------|-------------|
| resolved | Fix applied and pushed |
| skipped | User or analysis determined no change needed |
| not_applicable | Comment refers to code not in this PR |
| needs_discussion | Requires further architectural discussion |
| part_of_diff | Comment is about unchanged/unrelated code |
| outdated | Code has changed since the comment was made |
| fixed_elsewhere | Fix was in a different commit/workstream |
| user_override | User manually declined the change |

**Guidelines for replies:**
- No emoji
- Reference specific commit SHAs when applicable
- Explain why if not fixing ("This pattern is intentional — follows the project convention of...")
- Professional tone, concise

### Stage 12: Re-request Review

**Objective:** After all fixes are pushed and all replies are posted, re-request review from each reviewer whose last review state was CHANGES_REQUESTED. This is the final stage before the PR is ready for reviewer re-evaluation.

**Input:** The `reviews` array from Stage 3 output, filtered for `state: "CHANGES_REQUESTED"`.

**Rules:**
- Only re-request from reviewers who submitted a CHANGES_REQUESTED review (not COMMENTED, not APPROVED)
- Do NOT re-request from reviewers who already approved
- If all reviewers approved, skip this stage entirely — no re-request needed
- If no reviews exist, skip this stage

**Script call:**

```bash
echo '{
  "pr_url": "https://github.com/owner/repo/pull/42",
  "reviewers": ["reviewer1", "reviewer2"],
  "action": "re-request"
}' | bash ./scripts/re-request-review.sh
```

**Exit code handling:**
| Exit | Output | Action |
|------|--------|--------|
| 0 | JSON with successful/failed | Confirm to user and continue |
| 0 (no_reviewers) | No reviewers to request | Skip, PR is ready for merge |
| 1 | Some failures | Show failed reviewers, ask if user wants to retry |
| 2 | fallback_needed for MCP | Use MCP `requestPullRequestReviewers` or equivalent |

**Display to user before execution:**

```
=== Re-request Review ===

Reviewers who requested changes:
  [1] reviewer1 (3 comments resolved)
  [2] reviewer2 (1 comment resolved)

Reviewers who approved (skipping):
  [ ] reviewer3

Re-request review from reviewer1 and reviewer2? (yes / modify / skip)
```

**User must confirm before executing.** If user chooses "modify", let them edit the reviewer list (remove/add).

**MCP fallback:** If `gh` CLI is not available, use MCP tools:
- GitHub: `requestPullRequestReviewers(owner, repo, pullNumber, reviewers)` or `addPullRequestReviewer(...)`
- If MCP does not support reviewer management, print the command for the user to run manually:
  ```bash
  gh api repos/owner/repo/pulls/42/requested_reviewers -X POST -f reviewers[]=reviewer1
  ```

### Stage 13: Summary Comment (Optional)

Default: Do NOT add a summary comment on the PR.

If user requests it, compose a concise summary of changes made, organized by category (security fixes, performance fixes, etc.). Keep it to bullet points.

## Error Handling Reference

| Stage | Failure Mode | Recovery |
|-------|-------------|----------|
| 0 | Invalid URL format | Ask user to re-enter |
| 1 | Branch mismatch | Offer to switch / abort |
| 1 | Uncommitted changes | Offer stash / commit / abort |
| 2 | Sync conflicts | Offer resolve / abort |
| 3 | gh CLI not found | Show install instructions, abort |
| 3 | API auth failure | Ask user to run `gh auth login` |
| 3 | API rate limited | Show retry-after header, wait or abort |
| 4 | Subagent timeout | Proceed with unanalyzed comments flagged |
| 5 | Dependency graph conflicts | Show conflict options, let user decide direction |
| 5 | Dependency resolution timeout | Proceed with flat order (no graph) |
| 6 | Subagent timeout | Proceed without subagent findings |
| 7 | Fix introduces new issues | Revert commit, re-analyze, retry |
| 8 | Build fails | Show errors, offer retry / abort |
| 8 | Tests fail | Show failing tests, offer retry / abort |
| 9 | Validator rejects fix | Return to Stage 7 for affected comments |
| 10 | Push rejected | Show git error, offer force-push warning / abort |
| 11 | Reply API fails | Log error, skip reply for that comment |
| 12 | Re-request API fails | Show error, offer retry or ask user to re-request manually via gh CLI |

**General retry:** Any stage failure supports exactly one retry. If retry also fails, abort the pipeline and leave the workspace in the current state. Do not revert fixes automatically — let the user decide.

## Rollback

If the user says "rollback" or "revert", provide the list of commit SHAs made during this run and offer to revert them locally:

```
bash ./scripts/rollback.sh <sha1> <sha2>
```

Do not auto-push the revert. Present the reverted state for user confirmation.

## Subagent Orchestration Notes

**When spawning subagents:**

1. Use the agent definition files from `agents/` as the subagent's instructions
2. Each subagent should be spawned with `model: sonnet` (not haiku — code review needs reasoning depth)
3. Each subagent runs independently — wait for all to complete or timeout
4. If you cannot spawn subagents (environment limitation), run the review tasks sequentially as a fallback

**Subagent input format (for all review agents):**
- Full `git diff` output for staged and unstaged changes
- Content of the files referenced in PR comments
- The filtered list of actionable comments from Stage 4

## ECC Integration

When ECC is detected (from pre-flight):

1. Read `~/.claude/agents/` for ECC agent definitions
2. Use ECC's security-reviewer, performance-optimizer, code-reviewer by default
3. Select language-specific ECC reviewers based on file extensions (see Stage 6)
4. Fall back to built-in agents for any category not covered by ECC

When ECC is NOT detected:
- Use built-in agents from `agents/`
- Same workflow structure, fewer specialized capabilities
- The pipeline functions identically, just with broader review agents

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| BUILD_CMD | auto-detect | Build command |
| TEST_CMD | auto-detect | Test command |
| LINT_CMD | auto-detect | Lint command |
| GITHUB_TOKEN | from gh CLI | GitHub API auth fallback |
| GITLAB_TOKEN | none | GitLab API auth |
| DRY_RUN | false | Set to "true" for dryrun mode (no git changes, no API writes) |
| ECC_DEBUG | false | Enable ECC debug logging |
| ECC_INSTALL_PATH | ~/.claude | Custom ECC install path |

## File Reference

All reusable scripts are in `scripts/`:
- `check-branch.sh` — verify local branch matches PR branch
- `sync-pr.sh` — sync local branch with remote
- `fetch-pr-comments.sh` — fetch all PR comment types
- `verify-changes.sh` — run build + test + lint, output JSON
- `compose-reply.sh` — template-based comment replies
- `rollback.sh` — revert fix commits locally
- `re-request-review.sh` — re-request review from specified reviewers
- `post-resolution.sh` — post resolved status via gh API
- `dryrun.sh` — full pipeline dryrun validation

Agent definitions in `agents/`:
- `analyzer.md` — comment validity analysis
- `dependency-analyzer.md` — comment dependency graph (clusters, conflicts, supersedes)
- `security.md` — security-focused review
- `performance.md` — performance-focused review
- `quality.md` — code quality review
- `validator.md` — post-fix validation
