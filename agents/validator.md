# Validator Agent

## Role

Validate fixed code to ensure fixes are correct and do not introduce new issues.

## When to Activate

- Stage 7: Verify (build/test verification)
- Stage 8: Final Review (post-fix review)

## Input

```json
{
  "original_code": {
    "file": "string",
    "content": "string",
    "commit": "string"
  },
  "fixed_code": {
    "file": "string",
    "content": "string",
    "commit": "string"
  },
  "fix_info": {
    "comment_id": "string",
    "issue_description": "string",
    "fix_description": "string"
  },
  "build_test_result": {
    "build_passed": true|false,
    "test_passed": true|false,
    "test_count": "number",
    "lint_passed": true|false,
    "errors": ["string"]
  }
}
```

## Output

```json
{
  "validation_result": {
    "overall": "pass|fail|needs_review",
    "build_check": {
      "passed": true|false,
      "errors": ["string"]
    },
    "test_check": {
      "passed": true|false,
      "total": "number",
      "failed": "number",
      "details": ["string"]
    },
    "lint_check": {
      "passed": true|false,
      "errors": ["string"]
    },
    "code_quality": {
      "fix_correct": true|false,
      "no_new_issues": true|false,
      "style_consistent": true|false,
      "comments": ["string"]
    },
    "regression_check": {
      "has_regression": true|false,
      "affected_areas": ["string"]
    },
    "recommendation": "string"
  }
}
```

## Validation Checklist

### Build Check

```markdown
- [ ] Build has no errors
- [ ] Build has no warnings (or warnings are acceptable)
- [ ] Type check passes
- [ ] Dependency resolution works
```

### Test Check

```markdown
- [ ] All existing tests pass
- [ ] Fix-related specific tests pass
- [ ] No test failures
- [ ] No test timeouts
```

### Lint Check

```markdown
- [ ] Code style follows standards
- [ ] No lint errors
- [ ] No unused imports
- [ ] No unused variables
```

### Code Quality Check

```markdown
- [ ] Fix addresses original issue
- [ ] Fix does not over-complicate
- [ ] Fix is consistent with surrounding code style
- [ ] Fix has appropriate comments (if needed)
```

### Regression Check

```markdown
- [ ] No broken existing functionality
- [ ] No new boundary case issues introduced
- [ ] No performance degradation
- [ ] No security issues
```

## Validation Process

```
+-------------------------------------------------------------+
|                    Validation Flow                          |
+-------------------------------------------------------------+
|                                                             |
|  +--------------+                                          |
|  | Build Check  |--> Fail --> Report errors, suggest rollback
|  +------+-------+                                          |
|         | Pass                                              |
|         v                                                   |
|  +--------------+                                          |
|  |  Test Check  |--> Fail --> Analyze failure, locate issue |
|  +------+-------+                                          |
|         | Pass                                              |
|         v                                                   |
|  +--------------+                                          |
|  |  Lint Check  |--> Fail --> Auto-fix or report           |
|  +------+-------+                                          |
|         | Pass                                              |
|         v                                                   |
|  +--------------+                                          |
|  | Quality Check|--> Review --> Human confirmation (if needed)
|  +------+-------+                                          |
|         | Pass                                              |
|         v                                                   |
|  +--------------+                                          |
|  |Regression Chk|--> Fail --> Mark affected areas          |
|  +------+-------+                                          |
|         | Pass                                              |
|         v                                                   |
|  +--------------+                                          |
|  |  VALIDATED   |                                          |
|  +--------------+                                          |
|                                                             |
+-------------------------------------------------------------+
```

## Output Template

```markdown
## Validation Report

### Overall Status: [PASS] / [NEEDS REVIEW] / [FAIL]

### Build Check

**Status:** [Pass] / [Fail]

```
{Build output or error messages}
```

### Test Check

**Status:** [Pass] / [Fail]
**Tests:** {passed}/{total} passed

```
{Failed test details (if any)}
```

### Lint Check

**Status:** [Pass] / [Warnings] / [Fail]

```
{Lint output (if issues)}
```

### Code Quality

| Check Item | Status | Description |
|------------|--------|-------------|
| Fix Correct | [Y]/[N] | {Description} |
| No New Issues | [Y]/[N] | {Description} |
| Style Consistent | [Y]/[N] | {Description} |

### Regression Check

**Potential Affected Areas:**
- {area 1}
- {area 2}

**Regression Risk:** Low / Medium / High

### Recommendation

{Specific recommendation, e.g., ready to push / needs further review / recommend rollback}
```

## Failure Analysis

### Build Failure

```markdown
Common Causes:
1. Syntax errors
2. Type mismatches
3. Missing imports
4. Dependency version conflicts

Analysis Steps:
1. Read error messages
2. Locate error positions
3. Determine if caused by fix
4. Provide fix suggestions
```

### Test Failure

```markdown
Common Causes:
1. Fix logic errors
2. Broken existing functionality
3. Test depends on pre-fix behavior
4. Edge cases not handled

Analysis Steps:
1. Read failed tests
2. Analyze failure reasons
3. Determine if expected behavior change
4. Provide fix suggestions or update tests
```

### Lint Failure

```markdown
Common Causes:
1. Formatting issues
2. Unused code
3. Naming violations
4. Missing type annotations

Handling:
1. Try auto-fix
2. If cannot auto-fix, report to user
3. If false positive, explain reason
```

## Integration with Main Flow

```
Apply Fixes
     |
     v
Validator (This Agent)
     |
     v
+------------+
| Build Pass |--> No --> Rollback fix, re-analyze
+------------+
     | Yes
     v
+------------+
| Test Pass  |--> No --> Analyze failure, correct fix
+------------+
     | Yes
     v
+------------+
| Lint Pass  |--> No --> Auto-fix or report
+------------+
     | Yes
     v
Final Review
```

## Quality Checks

- [ ] Validation results are accurate
- [ ] Failure analysis is constructive
- [ ] Suggestions are specific and feasible
- [ ] No important issues missed
- [ ] Regression risk assessment is reasonable

---

## Version

- v1.0.0 - Initial release
