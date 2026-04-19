---
name: pr-comment-fix
description: Use when given a GitHub/GitLab PR URL to check local branch sync status, fetch PR comments, analyze comment validity, apply fixes with multi-agent parallel review (using ECC agents if available), verify build/tests pass, and optionally push and mark comments resolved
origin: custom
version: 2.1.0
ecc-integration: true
---

# PR Comment Fix v2

## Overview

根据 PR 评论自动分析、修复、验证代码的完整工作流。

**核心原则：**
1. 不盲目相信评论，先验证问题是否存在且合理
2. 修复后必须通过编译和测试
3. **所有关键操作必须获得用户确认**
4. 保持修复的原子性和可追溯性
5. **详细日志输出每个步骤**

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

## When to Use

- 用户提供 GitHub/GitLab PR URL
- 需要批量处理 PR 审查评论
- 需要根据评论修复代码并验证

---

## Workflow

```
Stage 1: PR Info & Branch Check (详细日志 + 确认)
    ↓
Stage 2: Sync Latest (确认)
    ↓
Stage 3: Fetch Comments
    ↓
Stage 4: Analyze Comments (显示分析表格)
    ↓
Stage 5: Parallel Review (多 Agent)
    ↓
Stage 6: Apply Fixes (每个修复需确认)
    ↓
Stage 7: Verify (编译 + 测试)
    ↓
Stage 8: Final Review
    ↓
Stage 9: Push? (推送前确认)
    ↓
Stage 10: Mark Resolved (每个回复需确认)
    ↓
END
```

---

## Stage Details

### Stage 1: PR Info & Branch Check

**目标：** 显示 PR 详细信息，确认本地分支状态

**输出日志：**
```
═══════════════════════════════════════════════
  PR Comment Fix - PR Information
═══════════════════════════════════════════════

PR:          {owner}/{repo}#{number}
Title:       {pr_title}
Branch:      {head_branch} → {base_branch}
State:       {open|closed|merged}

Commits:     {commit_count}
Comments:    {comment_count} total
  - Inline:      {inline_count}
  - General:     {general_count}
Reviews:     {review_count} total
  - ✓ APPROVE:   {approve_count}
  - ✗ CHANGES:  {changes_count}
  - ○ COMMENTED: {commented_count}

Changed Files: {changed_files}
Additions:     {additions}
Deletions:     {deletions}

Description:   {✓ Present | ✗ Empty}
Assignees:     {assignees_count}
Labels:        {labels_count}

═══════════════════════════════════════════════
  Local Branch Status
═══════════════════════════════════════════════

Current Branch:  {current_branch}
Expected Branch: {pr_branch}
Match:           {✓ Yes | ✗ No}

Upstream:        {upstream_remote}
Uncommitted:     {uncommitted_count} files

═══════════════════════════════════════════════
```

**确认点：**
- 分支不匹配 → **询问**是否切换
- 有未提交更改 → **询问**如何处理 (stash/commit/abort)

---

### Stage 2: Sync Latest

**目标：** 同步 PR 分支最新代码

**确认点：**
- 同步前显示本地和远程 commit 差异
- **询问**是否继续同步

---

### Stage 3: Fetch Comments

**目标：** 获取所有 PR 评论

**输出：**
```
Fetched {count} comments:
- {id}: {path}:{line} - {body[0:50]}...
- ...
```

---

### Stage 4: Analyze Comments

**目标：** 分析每个评论的有效性

**输出表格：**
```
═══════════════════════════════════════════════
  Comment Analysis
═══════════════════════════════════════════════

| ID       | Location      | Issue          | Exists | Valid | Priority | Fix    |
|----------|---------------|----------------|--------|-------|----------|--------|
| 123456   | file.ts:42    | SQL Injection  | ✓      | ✓     | Critical | Auto   |
| 123457   | utils.ts:15   | Naming         | ✓      | △     | Low      | Review |
| 123458   | api.ts:88     | Performance    | ✗      | -     | -        | Skip   |

═══════════════════════════════════════════════
```

**确认点：**
- 显示分析结果后**询问**是否继续修复
- 标记为 "Skip" 的评论**询问**是否确认跳过

---

### Stage 5: Parallel Review

**目标：** 多 Agent 并行评审

**输出：**
```
Running parallel review...
- Analyzer Agent:    {count} comments analyzed
- Security Agent:    {count} security issues
- Performance Agent: {count} performance issues
- Quality Agent:     {count} quality issues
```

---

### Stage 6: Apply Fixes

**目标：** 应用修复

**确认点（每个评论）：**
```
═══════════════════════════════════════════════
  Fix Plan for Comment #{id}
═══════════════════════════════════════════════

Location:  {file}:{line}
Issue:     {issue_description}
Severity:  {Critical|High|Medium|Low}

Proposed Fix:
{fix_description}

Code Change:
```{language}
{diff_preview}
```

───────────────────────────────────────────────
Proceed with this fix? (yes/no/skip/show more)
```

---

### Stage 7: Verify

**目标：** 验证修复

**输出：**
```
Running verification...
- Build:  {✓ Pass | ✗ Fail}
- Test:   {✓ Pass (24/24) | ✗ Fail (2/24)}
- Lint:   {✓ Pass | ⚠ Warnings | ✗ Fail}
```

---

### Stage 8: Final Review

**目标：** 修复后评审

**输出：**
```
Final Review:
- ✓ Fix addresses original issue
- ✓ No new issues introduced
- ✓ Code style consistent
```

---

### Stage 9: Push? (推送前确认)

**目标：** 确认是否推送

**输出报告：**
```
═══════════════════════════════════════════════
  PR Comment Fix - Summary
═══════════════════════════════════════════════

PR: {owner}/{repo}#{number}
Branch: {branch}

Fixed Comments: {fixed_count} / {total_count}

┌─────────────────────────────────────────────┐
│ [✓] Comment #123456: SQL Injection          │
│     File: auth.ts:42                        │
│     Fix: Added parameterized query          │
│     Commit: a1b2c3d                         │
├─────────────────────────────────────────────┤
│ [✓] Comment #123457: Naming issue           │
│     File: utils.ts:15                       │
│     Fix: Renamed variable                   │
│     Commit: d4e5f6g                         │
├─────────────────────────────────────────────┤
│ [○] Comment #123458: Skipped (false positive)│
└─────────────────────────────────────────────┘

Verification:
  Build: ✓ Pass
  Test:  ✓ Pass (24/24)
  Lint:  ✓ Pass

───────────────────────────────────────────────
Push changes to remote? (yes/no/show commits)
```

**确认点：**
- **必须用户确认**才推送
- 可以选择查看具体 commits

---

### Stage 10: Mark Resolved (回复确认)

**目标：** 回复每条评论

**确认点（每条评论）：**
```
═══════════════════════════════════════════════
  Reply to Comment #{id}
═══════════════════════════════════════════════

Original: {original_comment[0:100]}...

Proposed Reply:
{reply_text}

───────────────────────────────────────────────
Send this reply? (yes/no/edit/skip)
```

**回复选项：**
- ✅ **Resolved** - 问题已修复
- ○ **Not Applicable** - 问题不存在或不适用
- ❓ **Needs Discussion** - 需要进一步讨论
- ⏭️ **Skip** - 跳过不回复

---

### Stage 11: Summary Comment (可选)

**默认：** 不添加总结评论

**如需要：**
```
Add a summary comment explaining all changes? (yes/no)
```

---

## Scripts

### check-branch.sh
检查分支状态，显示 PR 信息

### sync-pr.sh
同步 PR 分支

### post-resolution.sh
回复评论

### dryrun.sh
Dryrun 测试

---

## Version History

### v2.0.0
- 增加详细日志输出
- 所有关键操作添加确认步骤
- 移除自动添加总结评论
- 支持多种回复选项

### v1.0.0
- Initial release
