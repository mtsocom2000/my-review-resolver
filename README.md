# PR Comment Fix Skill

[![Version](https://img.shields.io/badge/version-2.3.0-blue)](https://github.com/mtsocom2000/my-review-resolver/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-8B5CF6)](https://code.claude.com)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-v1-4EAA25)](https://agentskills.io)

A Claude Code skill (and compatible with VS Code Copilot, Cursor, OpenCode) that automates the end-to-end workflow of handling PR review comments.

**Instead of manually reading comments, judging validity, fixing code, verifying, and replying — this skill orchestrates the entire pipeline with script-backed execution, multi-agent parallel review, and comment dependency graph analysis.**

---

## Architecture

### 14-Stage Pipeline (0-13)

```
  0. URL Validation & Input        — Parse PR URL, extract owner/repo/number
  1. Branch Check                  — Verify local branch matches PR target
  2. Sync Latest                   — Pull latest changes from remote
  3. Fetch Comments                — gh CLI (or MCP fallback) → inline + reviews + general
  4. Analyze Comments (subagent)   — Per-comment: exists? valid? auto-fixable?
  5. Dependency Graph (subagent)   — Cluster, conflict, supersede analysis
  6. Parallel Review (multi-agent) — Security + performance + quality reviewers
  7. Apply Fixes                   — Follow resolution order from Stage 5
  8. Verify                        — Build + test + lint via verify-changes.sh
  9. Final Review (subagent)       — Validator checks all fixes are correct
 10. Push Confirmation             — Summary report with blocking status, user must confirm
 11. Reply to Comments             — Template-driven replies via reply-to-comment.sh
 12. Re-request Review             — Re-request review from CHANGES_REQUESTED reviewers
 13. Summary Comment (optional)    — Concise overview of changes made
```

### Design Principles

- **Script-backed, not model-generated** — All API calls and git operations are implemented in standalone shell scripts. The model calls these scripts; it does not generate octokit/gh/cURL code on the fly.
- **gh CLI primary, MCP fallback** — All external API calls first try `gh`, then fall back to MCP tools, then to user prompt.
- **Stage 5 Dependency Graph prevents double work** — Comments are not fixed independently. OVERLAP, CONFLICT, SAME_ROOT, SUPERSEDES, and DEPENDS_ON relationships are identified first.
- **User confirmation at critical points** — Branch switch, push, conflict resolution, re-request review, and each fix plan require explicit user approval.
- **CHANGES_REQUESTED tracking** — Comments from CHANGES_REQUESTED reviews are flagged as blocking; unfixed blockers warn before push.
- **Re-request review as final step** — After all fixes and replies, automatically re-request review from original change-requesting reviewers.
- **Confidence-based automation** — High-confidence relationships auto-apply; medium suggest; low just inform.

---

## Files

### Scripts (`scripts/`)

| Script | Purpose | Exit codes |
|--------|---------|------------|
| `check-branch.sh` | Verify local branch matches PR branch. Supports GitHub/GitLab URL parsing. | 0 = match, 1 = error/info |
| `sync-pr.sh` | Fetch latest changes from remote for target branch | 0 = ok |
| `fetch-pr-comments.sh` | Fetch all PR comment types via gh CLI with pagination | 0 = JSON, 1 = input error, 2 = fallback needed |
| `verify-changes.sh` | Run build + test + lint, auto-detect project type (npm/go/cargo/maven/gradle/python) | stdout JSON, exit mirrors overall status |
| `compose-reply.sh` | Template-driven comment reply generation (8 action types) | stdin JSON → stdout markdown |
| `reply-to-comment.sh` | Post reply or resolve comment via gh CLI or MCP fallback | 0 = posted, 1 = input error, 2 = fallback needed |
| `rollback.sh` | Safe local revert of specified fix commits | JSON with rolled_back + failed arrays |
| `re-request-review.sh` | Re-request review from specified reviewers via gh CLI | 0 = ok, 1 = partial failure, 2 = fallback needed |
| `post-resolution.sh` | Legacy — reply to PR comments (superseded by reply-to-comment.sh) | — |

### Agents (`agents/`)

| Agent | Purpose | Used in |
|-------|---------|---------|
| `analyzer.md` | Comment validity analysis: does the issue exist? Is it reasonable? | Stage 4 |
| `dependency-analyzer.md` | Comment dependency graph: clusters, conflicts, supersedes | Stage 5 |
| `security.md` | Security-focused review agent | Stage 6 |
| `performance.md` | Performance-focused review agent | Stage 6 |
| `quality.md` | Code quality review agent | Stage 6 |
| `validator.md` | Post-fix validation: are all comments addressed properly? | Stage 9 |

### Support Files

| File | Purpose |
|------|---------|
| `references/github-api.md` | GitHub API reference for gh CLI commands |
| `references/comment-patterns.md` | Common PR comment types and response strategies |
| `COMPATIBILITY.md` | Platform compatibility matrix |
| `.claude-plugin/marketplace.json` | Claude Code marketplace manifest |

---

## Installation

```bash
git clone https://github.com/mtsocom2000/my-review-resolver.git
cd my-review-resolver

# Auto-install (detects Claude Code / Cursor / VS Code / OpenCode):
./install.sh --auto

# Or manual: copy .claude/skills/pr-comment-fix to your project
```

Requires: `gh` CLI (authenticated), `jq`, `bash 4+`.

---

## Usage

1. **In Claude Code:** Provide any GitHub/GitLab PR URL. The skill auto-triggers and runs the full pipeline.
2. **In VS Code Copilot / Cursor:** Type `/pr-comment-fix` followed by the PR URL.
### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `BUILD_CMD` | auto-detect | Override build command for Stage 8 |
| `TEST_CMD` | auto-detect | Override test command |
| `LINT_CMD` | auto-detect | Override lint command |
| `DRY_RUN` | `false` | Simulation mode (no git/API write operations) |
---

## Changelog

### v2.3.0 (2026-05-14) 🔁

- **Stage 12: Re-request Review** (new stage)
  - After all fixes pushed and replies posted, re-request review from CHANGES_REQUESTED reviewers
  - New script: `scripts/re-request-review.sh` — gh CLI primary, MCP fallback
  - User must confirm before re-requesting (with modify option)
  - Only CHANGES_REQUESTED reviewers are re-requested, approved reviewers are skipped
  - Skip stage if no changes were requested

- **CHANGES_REQUESTED tracking**
  - Stage 10 (Push Confirmation) now shows blocking status per comment
  - Warnings when unfixed blocking comments remain before push
  - Blocking comment tag [BLOCKING: reviewer] displayed in summary table

### v2.2.0 (2026-05-14) 🔧

- **Stage 5: Comment Dependency Graph Analysis** (new stage)
  - OVERLAP detection — deduplicate comments describing the same issue
  - CONFLICT detection — identify mutually exclusive fix proposals
  - SAME_ROOT clustering — different symptoms, same root cause
  - SUPERSEDES detection — fix A makes comment B irrelevant
  - DEPENDS_ON ordering — topological sort of fix dependencies
  - Confidence tiers (high/medium/low) control auto-application

- **Architecture:** scripts replace model-generated API code
  - `scripts/fetch-pr-comments.sh` — paginated gh CLI, 3 comment types, structured fallback signals
  - `scripts/verify-changes.sh` — unified build/test/lint with project auto-detection
  - `scripts/compose-reply.sh` — template-driven comment replies (8 action types)
  - `scripts/reply-to-comment.sh` — actual API posting with MCP fallback
  - `scripts/rollback.sh` — safe local revert of fix commits

- **MCP fallback chain:** gh CLI → MCP tools → user prompt
  - Fetch comments: `getPullRequest` + `getPullRequestComments` + `listPullRequestReviews` + `getIssueComments`
  - Post reply: `createPullRequestReviewComment` / `createIssueComment`
  - Each stage documents exact MCP tool mapping

- **SKILL.md rewritten:** script-backed, retry/abort/skip error handling per stage, subagent input/output schemas, confidence tiers
- **Agents:** `agents/dependency-analyzer.md` — 174-line agent with 8-step analysis methodology
- Removed redundant `skills/pr-comment-fix/lib/ecc-detector.ts` duplicate

### v2.1.0 (2026-04-19) 🆕

- ECC (Everything Claude Code) integration
- Automatic ECC detection
- Parallel review using ECC agents
- Language-specific reviewer auto-selection
- Graceful fallback to built-in agents
- ECC detection module (`lib/ecc-detector.ts`)
- Complete ECC integration documentation

### v2.0.0 (2026-04-18)

- 10-stage workflow
- 5 built-in Agent definitions
- 3 script tools
- Complete test cases
- Multi-platform installation support

### v1.0.0 (2026-04-17)

- Initial release

---

## Dependencies

| Tool | Required for | Fallback |
|------|-------------|---------|
| `gh` CLI (1.0+) | Fetching comments, posting replies | MCP tools |
| `jq` | JSON processing in shell scripts | `grep`/`sed` fallback in some scripts |
| `bash` 4+ | Script execution | — |

