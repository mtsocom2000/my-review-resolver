# Test Cases

## Test 1: Branch Check - Match

**Input:**
- PR URL: `https://github.com/example/api/pull/42`
- PR Branch: `feature/auth`
- Local Branch: `feature/auth`
- Uncommitted Changes: None

**Expected Output:**
```
match=true
reason=none
action=proceed_to_sync
```

---

## Test 2: Branch Check - Mismatch

**Input:**
- PR URL: `https://github.com/example/api/pull/42`
- PR Branch: `feature/auth`
- Local Branch: `main`
- Uncommitted Changes: None

**Expected Output:**
```
match=false
reason=branch_mismatch
action=prompt_user_to_switch
message="当前分支 (main) 与 PR 分支 (feature/auth) 不匹配"
```

---

## Test 3: Branch Check - Uncommitted Changes

**Input:**
- PR URL: `https://github.com/example/api/pull/42`
- PR Branch: `feature/auth`
- Local Branch: `feature/auth`
- Uncommitted Changes: `M src/auth.ts`

**Expected Output:**
```
match=false
reason=uncommitted_changes
action=prompt_user_to_handle_changes
options=["stash", "commit", "abort"]
```

---

## Test 4: Comment Analysis - Security Issue

**Input:**
```json
{
  "comment": {
    "id": "1001",
    "body": "SQL Injection Risk: User input directly concatenated",
    "path": "src/auth.ts",
    "line": 25
  },
  "code_context": "const query = 'SELECT * FROM users WHERE id = ' + userId;"
}
```

**Expected Output:**
```json
{
  "comment_id": "1001",
  "exists": true,
  "valid": true,
  "severity": "Critical",
  "auto_fixable": true,
  "suggested_fix": "Use parameterized query",
  "confidence": "high",
  "needs_human_review": false
}
```

---

## Test 5: Comment Analysis - False Positive

**Input:**
```json
{
  "comment": {
    "id": "1002",
    "body": "Missing null check",
    "path": "src/utils.ts",
    "line": 10
  },
  "code_context": "// This function guarantees non-null output per API contract"
}
```

**Expected Output:**
```json
{
  "comment_id": "1002",
  "exists": false,
  "valid": false,
  "reason": "API contract guarantees non-null, check is unnecessary",
  "needs_human_review": true,
  "human_review_reason": "Explain API contract in response"
}
```

---

## Test 6: Multi-Agent Parallel Review

**Input:**
```json
{
  "comments": [
    {"id": "1", "body": "Add input validation", "path": "src/api.ts", "line": 10},
    {"id": "2", "body": "N+1 query issue", "path": "src/service.ts", "line": 25},
    {"id": "3", "body": "Rename variable", "path": "src/utils.ts", "line": 5}
  ]
}
```

**Expected Agent Dispatch:**
```
Analyzer Agent    → All 3 comments
Security Agent    → Comment 1 (input validation)
Performance Agent → Comment 2 (N+1 query)
Quality Agent     → Comment 3 (naming)
```

**Expected Aggregation:**
```json
{
  "total_comments": 3,
  "analyzed": 3,
  "security_issues": 1,
  "performance_issues": 1,
  "quality_issues": 1,
  "false_positives": 0,
  "needs_human_review": 0
}
```

---

## Test 7: Fix Application - With Specific Suggestion

**Input:**
```json
{
  "comment_id": "1001",
  "issue": "Hardcoded API key",
  "suggested_fix": "Move to environment variable",
  "original_code": "const API_KEY = 'sk-123456';",
  "file": "src/config.ts"
}
```

**Expected Fix:**
```typescript
// Before
const API_KEY = 'sk-123456';

// After
const API_KEY = process.env.API_KEY || '';

if (!API_KEY) {
  throw new Error('API_KEY environment variable is required');
}
```

**Expected Commit Message:**
```
fix: address PR comment #1001 - Hardcoded API key

Move API key to environment variable for security.
```

---

## Test 8: Fix Application - No Specific Suggestion

**Input:**
```json
{
  "comment_id": "1002",
  "issue": "Function too complex",
  "suggested_fix": null,
  "original_code": "// 80 line function",
  "file": "src/processor.ts"
}
```

**Expected Action:**
```
1. Analyze function structure
2. Identify logical sections
3. Propose split plan to user
4. Wait for user confirmation
5. Apply approved plan
```

**Expected Output to User:**
```
评论 #1002 建议：函数过于复杂

分析结果:
- 当前函数：80 行，圈复杂度 15
- 可拆分为 3 个函数：
  1. validateInput() - 15 行
  2. processData() - 45 行
  3. formatOutput() - 20 行

修复方案:
[方案 A] 拆分为 3 个私有函数
[方案 B] 保持结构，添加注释
[方案 C] 跳过，需要更大重构

请选择 (A/B/C):
```

---

## Test 9: Verification - Build Pass

**Input:**
```json
{
  "build_command": "npm run build",
  "build_output": "✓ Build completed in 2.3s",
  "exit_code": 0
}
```

**Expected Output:**
```json
{
  "build_check": {
    "passed": true,
    "errors": [],
    "warnings": []
  },
  "action": "proceed_to_test"
}
```

---

## Test 10: Verification - Build Fail

**Input:**
```json
{
  "build_command": "npm run build",
  "build_output": "error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'",
  "exit_code": 1
}
```

**Expected Output:**
```json
{
  "build_check": {
    "passed": false,
    "errors": [
      "TS2345: Argument of type 'string' is not assignable to parameter of type 'number' at src/service.ts:42"
    ]
  },
  "action": "rollback_and_reanalyze",
  "rollback_target": "commit_before_fix"
}
```

---

## Test 11: Verification - Test Pass

**Input:**
```json
{
  "test_command": "npm test",
  "test_output": "Tests: 24 passed, 0 failed",
  "exit_code": 0
}
```

**Expected Output:**
```json
{
  "test_check": {
    "passed": true,
    "total": 24,
    "failed": 0,
    "details": []
  },
  "action": "proceed_to_lint"
}
```

---

## Test 12: Verification - Test Fail

**Input:**
```json
{
  "test_command": "npm test",
  "test_output": "Tests: 23 passed, 1 failed\nFAIL: should handle empty input",
  "exit_code": 1
}
```

**Expected Output:**
```json
{
  "test_check": {
    "passed": false,
    "total": 24,
    "failed": 1,
    "details": [
      "FAIL: should handle empty input - Expected truthy value, received falsy"
    ]
  },
  "action": "analyze_failure",
  "analysis": {
    "is_fix_related": true,
    "suggested_action": "Update fix to handle empty input case"
  }
}
```

---

## Test 13: Push Confirmation

**Input:**
```json
{
  "fixed_comments": 5,
  "skipped_comments": 1,
  "build_passed": true,
  "test_passed": true,
  "lint_passed": true
}
```

**Expected Output:**
```
═══════════════════════════════════════════════════════
  PR Comment Fix - 修复完成报告
═══════════════════════════════════════════════════════

已修复问题：5 / 6

[✓] 问题 1: SQL Injection Risk (src/auth.ts:25)
[✓] 问题 2: N+1 Query (src/service.ts:48)
[✓] 问题 3: Variable Naming (src/utils.ts:12)
[✓] 问题 4: Missing Cache (src/config.ts:33)
[✓] 问题 5: Hardcoded API Key (src/payment.ts:8)
[△] 问题 6: Function Complexity - 需人工确认

验证结果:
  编译：✓ 通过
  测试：✓ 通过 (24/24)
  Lint: ✓ 通过

─────────────────────────────────────────────────────

是否推送到远端？

  yes  - 推送所有修复 commits
  no   - 保留本地，不推送
  show - 查看具体修改内容
```

---

## Test 14: Mark Resolved

**Input:**
```json
{
  "pr_url": "https://github.com/example/api/pull/42",
  "resolved_comment_ids": ["1001", "1002", "1003"],
  "commit_sha": "abc123def"
}
```

**Expected API Calls:**
```bash
gh api repos/example/api/pulls/42/comments/1001/replies -X POST -f body="✓ Resolved in commit abc123d"
gh api repos/example/api/pulls/42/comments/1002/replies -X POST -f body="✓ Resolved in commit abc123d"
gh api repos/example/api/pulls/42/comments/1003/replies -X POST -f body="✓ Resolved in commit abc123d"
```

**Expected Summary Comment:**
```markdown
## PR Comment Fix - Resolved

已修复以下问题:

- Comment #1001: SQL Injection Risk
- Comment #1002: N+1 Query
- Comment #1003: Variable Naming

修复已推送到 commit: abc123def
```

---

## Edge Cases

### EC1: PR with No Comments

**Input:** PR with 0 comments
**Expected:** Skip analysis, report "No comments to process"

### EC2: All Comments Are False Positives

**Input:** All comments marked as invalid
**Expected:** Report "All comments appear to be false positives", skip fix

### EC3: Merge Conflict During Sync

**Input:** Git merge conflict
**Expected:** Stop, prompt user to resolve manually

### EC4: Build Tool Not Found

**Input:** `npm` not installed
**Expected:** Detect and suggest alternative or manual verification

### EC5: GitHub CLI Not Authenticated

**Input:** `gh api` returns 401
**Expected:** Prompt user to run `gh auth login`

---

## Version

- v1.0.0 - Initial test cases
