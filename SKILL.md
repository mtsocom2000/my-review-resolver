---
name: pr-comment-fix
description: Use when given a GitHub/GitLab PR URL to check local branch sync status, fetch PR comments, analyze comment validity, apply fixes with multi-agent parallel review (using ECC agents if available), verify build/tests pass, and optionally push and mark comments resolved
origin: custom
version: 2.2.0
ecc-integration: true
no-emoji: true
---

# PR Comment Fix v2.2

## Overview

Complete workflow for automatic analysis, fix, and verification of code based on PR comments.

**Core Principles:**
1. Do not blindly trust comments - verify if the issue exists and is reasonable
2. Fixes must pass compilation and tests
3. **All critical operations require user confirmation**
4. Maintain atomicity and traceability of fixes
5. **Detailed log output for every step**
6. **No emoji in comment replies**

---

## ECC Integration

### Detection

This skill automatically detects if ECC (Everything Claude Code) is installed:

```typescript
import { detectECC, buildParallelReviewTasks } from './lib/ecc-detector';

const ecc = detectECC();
if (ecc.installed) {
  // Use ECC agents for parallel review
  const tasks = buildParallelReviewTasks({ diff, comment, filePath });
  // Spawn subagents for security, performance, quality review
} else {
  // Use fallback subagents
}
```

### ECC Agents Used

When ECC is available, the skill leverages these agents for parallel review:

| Agent | Purpose | Fallback |
|-------|---------|----------|
| `security-reviewer` | Security vulnerability analysis | Built-in security agent |
| `performance-optimizer` | Performance issue detection | Built-in performance agent |
| `code-reviewer` | Code quality review | Built-in quality agent |
| `typescript-reviewer` | TS/JS specific review (auto-selected) | Built-in analyzer |
| `python-reviewer` | Python specific review (auto-selected) | Built-in analyzer |

### Fallback Strategy

If ECC is not installed:

1. Use built-in subagents (analyzer, security, performance, quality, validator)
2. Same workflow, fewer specialized capabilities
3. User can install ECC later for enhanced review

---

## When to Use

- User provides GitHub/GitLab PR URL
- Need to batch process PR review comments
- Need to fix code based on comments and verify

---

## Workflow

```
Stage 1: PR Info & Branch Check (detailed logs + confirmation)
    ↓
Stage 2: Sync Latest (confirmation)
    ↓
Stage 3: Fetch Comments (ALL comments including reviews)
    ↓
Stage 4: Analyze Comments (display analysis table)
    ↓
Stage 5: Parallel Review (multi-Agent)
    ↓
Stage 6: Apply Fixes (confirmation for each fix)
    ↓
Stage 7: Verify (build + tests)
    ↓
Stage 8: Final Review
    ↓
Stage 9: Push? (confirmation before push)
    ↓
Stage 10: Mark Resolved (confirmation for each reply)
    ↓
END
```

---

## Stage Details

### Stage 1: PR Info & Branch Check

**Objective:** Display PR details and confirm local branch status

**Output Log:**
```
=================================================================
  PR Comment Fix - PR Information
=================================================================

PR:          {owner}/{repo}#{number}
Title:       {pr_title}
Branch:      {head_branch} -> {base_branch}
State:       {open|closed|merged}

Commits:     {commit_count}
Comments:    {comment_count} total
  - Inline:      {inline_count}
  - General:     {general_count}
Reviews:     {review_count} total
  - [APPROVE]    {approve_count}
  - [CHANGES]    {changes_count}
  - [COMMENTED]  {commented_count}

Changed Files: {changed_files}
Additions:     {additions}
Deletions:     {deletions}

Description:   {Present | Empty}
Assignees:     {assignees_count}
Labels:        {labels_count}

=================================================================
  Local Branch Status
=================================================================

Current Branch:  {current_branch}
Expected Branch: {pr_branch}
Match:           {Yes | No}

Upstream:        {upstream_remote}
Uncommitted:     {uncommitted_count} files

=================================================================
```

**Confirmation Points:**
- Branch mismatch -> **Ask** whether to switch
- Uncommitted changes -> **Ask** how to handle (stash/commit/abort)

---

### Stage 2: Sync Latest

**Objective:** Sync PR branch to latest code

**Confirmation Points:**
- Show local and remote commit differences before sync
- **Ask** whether to continue sync

---

### Stage 3: Fetch Comments

**Objective:** Fetch ALL PR comments including review comments

**Important:** Must fetch both:
1. Inline comments on code changes
2. Review comments (from review submissions)
3. General discussion comments

**Output:**
```
Fetched {count} comments:
- {id}: {path}:{line} - {body[0:50]}...
- {id}: [review] - {body[0:50]}...
- ...
```

**Note:** If comment count seems low, verify:
- GitHub API is properly authenticated
- Review comments are fetched separately
- Pagination is handled correctly

---

### Stage 4: Analyze Comments

**Objective:** Analyze validity of each comment

**Output Table:**
```
=================================================================
  Comment Analysis
=================================================================

| ID       | Location      | Issue          | Exists | Valid | Priority | Fix    |
|----------|---------------|----------------|--------|-------|----------|--------|
| 123456   | file.ts:42    | SQL Injection  | [Y]    | [Y]   | Critical | Auto   |
| 123457   | utils.ts:15   | Naming         | [Y]    | [~]   | Low      | Review |
| 123458   | api.ts:88     | Performance    | [N]    | [-]   | -        | Skip   |

=================================================================
```

**Legend:**
- Exists: [Y] Yes, [N] No, [~] Partial
- Valid: [Y] Yes, [N] No, [~] Needs review, [-] N/A
- Fix: [Auto] Auto-fix, [Review] Needs review, [Skip] Skip

**Confirmation Points:**
- **Ask** whether to continue fix after displaying analysis
- **Ask** whether to confirm skip for comments marked "Skip"

---

### Stage 5: Parallel Review

**Objective:** Multi-Agent parallel review

**Output:**
```
Running parallel review...
- Analyzer Agent:    {count} comments analyzed
- Security Agent:    {count} security issues
- Performance Agent: {count} performance issues
- Quality Agent:     {count} quality issues
```

---

### Stage 6: Apply Fixes

**Objective:** Apply fixes

**Confirmation (for each comment):**
```
=================================================================
  Fix Plan for Comment #{id}
=================================================================

Location:  {file}:{line}
Issue:     {issue_description}
Severity:  {Critical|High|Medium|Low}

Proposed Fix:
{fix_description}

Code Change:
```{language}
{diff_preview}
```

-----------------------------------------------------------------
Proceed with this fix? (yes/no/skip/show more)
```

---

### Stage 7: Verify

**Objective:** Verify fixes

**Output:**
```
Running verification...
- Build:  [Pass | Fail]
- Test:   [Pass (24/24) | Fail (2/24)]
- Lint:   [Pass | Warnings | Fail]
```

---

### Stage 8: Final Review

**Objective:** Post-fix review

**Output:**
```
Final Review:
- [Y] Fix addresses original issue
- [Y] No new issues introduced
- [Y] Code style consistent
```

---

### Stage 9: Push? (Confirmation Before Push)

**Objective:** Confirm whether to push

**Output Report:**
```
=================================================================
  PR Comment Fix - Summary
=================================================================

PR: {owner}/{repo}#{number}
Branch: {branch}

Fixed Comments: {fixed_count} / {total_count}

+---------------------------------------------------------------+
| [[Y]] Comment #123456: SQL Injection                          |
|     File: auth.ts:42                                          |
|     Fix: Added parameterized query                            |
|     Commit: a1b2c3d                                           |
+---------------------------------------------------------------+
| [[Y]] Comment #123457: Naming issue                           |
|     File: utils.ts:15                                         |
|     Fix: Renamed variable                                     |
|     Commit: d4e5f6g                                           |
+---------------------------------------------------------------+
| [[O]] Comment #123458: Skipped (false positive)               |
+---------------------------------------------------------------+

Verification:
  Build: [Y] Pass
  Test:  [Y] Pass (24/24)
  Lint:  [Y] Pass

-----------------------------------------------------------------
Push changes to remote? (yes/no/show commits)
```

**Confirmation Points:**
- **User confirmation required** before push
- Can choose to view specific commits

---

### Stage 10: Mark Resolved (Reply Confirmation)

**Objective:** Reply to each comment

**Confirmation (for each comment):**
```
=================================================================
  Reply to Comment #{id}
=================================================================

Original: {original_comment[0:100]}...

Proposed Reply:
{reply_text}

-----------------------------------------------------------------
Send this reply? (yes/no/edit/skip)
```

**Reply Options:**
- **[Resolved]** - Issue has been fixed
- **[Not Applicable]** - Issue does not exist or not applicable
- **[Needs Discussion]** - Requires further discussion
- **[Skip]** - Skip without reply

**Reply Guidelines:**
- **NO emoji** in replies
- Keep replies professional and concise
- Explain what was done or why not applicable
- Reference specific commits when applicable

**Example Replies:**

```
// Good - Resolved
This has been fixed in commit {sha}. Added parameterized queries 
to prevent SQL injection.

// Good - Not Applicable
This pattern is intentional for {reason}. The current implementation
follows {standard/pattern} used elsewhere in the codebase.

// Good - Needs Discussion
I understand the concern. However, changing this would impact
{dependency/performance}. Can we discuss alternative approaches?
```

---

### Stage 11: Summary Comment (Optional)

**Default:** Do NOT add summary comment

**If requested:**
```
Add a summary comment explaining all changes? (yes/no)
```

---

## Comment Fetching Implementation

### GitHub API

```typescript
// Fetch inline comments
const comments = await octokit.pulls.listReviewComments({
  owner, repo, pull_number: prNumber
});

// Fetch review comments (IMPORTANT - often missed)
const reviews = await octokit.pulls.listReviews({
  owner, repo, pull_number: prNumber
});

// Fetch general comments
const issueComments = await octokit.issues.listComments({
  owner, repo, issue_number: prNumber
});

// Combine all
const allComments = [
  ...comments.data,
  ...reviews.data,
  ...issueComments.data
];
```

### Common Issues

**Problem:** Missing review comments

**Solution:**
- `listReviewComments()` only returns inline comments on code
- `listReviews()` returns review submissions with body text
- Must fetch BOTH and combine

**Problem:** Pagination

**Solution:**
```typescript
// Handle pagination
const allComments = [];
let page = 1;
while (true) {
  const response = await octokit.pulls.listReviewComments({
    owner, repo, pull_number: prNumber, page, per_page: 100
  });
  if (response.data.length === 0) break;
  allComments.push(...response.data);
  page++;
}
```

---

## Scripts

### check-branch.sh
Check branch status and display PR information

### sync-pr.sh
Sync PR branch

### post-resolution.sh
Reply to comments

### dryrun.sh
Dryrun test

---

## Configuration

### Environment Variables

```bash
# GitHub (optional, auto-used if gh CLI installed)
export GITHUB_TOKEN=ghp_xxx

# GitLab (if using GitLab)
export GITLAB_TOKEN=glpat-xxx

# Custom build/test commands
export BUILD_CMD="npm run build"
export TEST_CMD="npm test"
export LINT_CMD="npm run lint"

# ECC configuration (optional)
export ECC_DEBUG=true              # Enable ECC debug logs
export ECC_SKIP_DETECTION=false    # Skip ECC detection
```

---

## Version History

### v2.2.0 (Current)
- **No emoji policy** in comment replies
- **Chinese to English** translation throughout skill
- **Fixed comment fetching** - explicitly fetch review comments
- **Improved pagination** handling for large PRs
- **Better reply guidelines** with examples

### v2.1.0
- ECC (Everything Claude Code) integration
- Automatic ECC detection
- Parallel review using ECC agents
- Language-specific reviewers (auto-selected)
- Graceful fallback to built-in agents

### v2.0.0
- Increased detailed log output
- Added confirmation steps for all critical operations
- Removed automatic summary comments
- Added multiple reply options

### v1.0.0
- Initial release

---

## Files

- `SKILL.md` - Main skill definition (this file)
- `README.md` - User documentation
- `ECC_INTEGRATION.md` - ECC integration guide
- `install.sh` / `install.ps1` - Installation scripts
- `agents/` - Agent definitions
- `scripts/` - Utility scripts
- `lib/` - ECC detector and utilities
- `tests/` - Test cases

---

## License

MIT License
