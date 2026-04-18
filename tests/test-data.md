# Test Data - Mock PR Comments

## Test Case 1: Mixed Comments (Security + Performance + Quality)

**PR URL:** `https://github.com/example/api-service/pull/42`
**Branch:** `feature/user-auth`

### Mock Comments

```json
{
  "pr_info": {
    "owner": "example",
    "repo": "api-service",
    "number": 42,
    "branch": "feature/user-auth",
    "base_branch": "main"
  },
  "comments": [
    {
      "id": "1001",
      "author": "security-bot",
      "body": "⚠️ SQL Injection Risk: User input is directly concatenated into the query. Use parameterized queries instead.",
      "path": "src/auth/login.ts",
      "line": 25,
      "type": "inline",
      "severity": "Critical"
    },
    {
      "id": "1002",
      "author": "senior-dev",
      "body": "This loop makes a database query per user (N+1 problem). Consider batching the queries.",
      "path": "src/user/service.ts",
      "line": 48,
      "type": "inline",
      "severity": "High"
    },
    {
      "id": "1003",
      "author": "code-reviewer",
      "body": "Variable name `d` is not descriptive. Use `currentDate` or similar.",
      "path": "src/utils/date.ts",
      "line": 12,
      "type": "inline",
      "severity": "Low"
    },
    {
      "id": "1004",
      "author": "team-lead",
      "body": "Great implementation! The error handling is comprehensive.",
      "path": null,
      "line": null,
      "type": "general",
      "severity": "Positive"
    },
    {
      "id": "1005",
      "author": "perf-bot",
      "body": "Consider caching this result. It's computed on every request but rarely changes.",
      "path": "src/config/loader.ts",
      "line": 33,
      "type": "inline",
      "severity": "Medium"
    },
    {
      "id": "1006",
      "author": "security-bot",
      "body": "API key is hardcoded. Move to environment variable.",
      "path": "src/external/payment.ts",
      "line": 8,
      "type": "inline",
      "severity": "Critical"
    },
    {
      "id": "1007",
      "author": "reviewer-2",
      "body": "This function is 80 lines long. Consider breaking it into smaller functions.",
      "path": "src/order/processor.ts",
      "line": 15,
      "type": "inline",
      "severity": "Medium"
    },
    {
      "id": "1008",
      "author": "qa-engineer",
      "body": "Add unit tests for the edge cases (empty input, null values).",
      "path": "src/auth/login.ts",
      "line": 20,
      "type": "inline",
      "severity": "Medium"
    }
  ]
}
```

### Expected Analysis Output

```json
{
  "analyses": [
    {
      "comment_id": "1001",
      "file": "src/auth/login.ts",
      "line": 25,
      "issue_description": "SQL Injection Risk",
      "exists": true,
      "valid": true,
      "severity": "Critical",
      "auto_fixable": true,
      "suggested_fix": "Use parameterized query with placeholders",
      "confidence": "high",
      "needs_human_review": false
    },
    {
      "comment_id": "1002",
      "file": "src/user/service.ts",
      "line": 48,
      "issue_description": "N+1 Query Problem",
      "exists": true,
      "valid": true,
      "severity": "High",
      "auto_fixable": true,
      "suggested_fix": "Use findMany with IN clause",
      "confidence": "high",
      "needs_human_review": false
    },
    {
      "comment_id": "1003",
      "file": "src/utils/date.ts",
      "line": 12,
      "issue_description": "Unclear variable name",
      "exists": true,
      "valid": true,
      "severity": "Low",
      "auto_fixable": true,
      "suggested_fix": "Rename to currentDate",
      "confidence": "high",
      "needs_human_review": false
    },
    {
      "comment_id": "1004",
      "file": null,
      "line": null,
      "issue_description": "Positive feedback",
      "exists": true,
      "valid": true,
      "severity": "Positive",
      "auto_fixable": false,
      "suggested_fix": null,
      "confidence": "high",
      "needs_human_review": false
    },
    {
      "comment_id": "1005",
      "file": "src/config/loader.ts",
      "line": 33,
      "issue_description": "Missing cache",
      "exists": true,
      "valid": true,
      "severity": "Medium",
      "auto_fixable": true,
      "suggested_fix": "Add Map-based caching with TTL",
      "confidence": "medium",
      "needs_human_review": false
    },
    {
      "comment_id": "1006",
      "file": "src/external/payment.ts",
      "line": 8,
      "issue_description": "Hardcoded API key",
      "exists": true,
      "valid": true,
      "severity": "Critical",
      "auto_fixable": true,
      "suggested_fix": "Use process.env.PAYMENT_API_KEY",
      "confidence": "high",
      "needs_human_review": false
    },
    {
      "comment_id": "1007",
      "file": "src/order/processor.ts",
      "line": 15,
      "issue_description": "Function too long",
      "exists": true,
      "valid": true,
      "severity": "Medium",
      "auto_fixable": false,
      "suggested_fix": "Extract into smaller functions",
      "confidence": "medium",
      "needs_human_review": true,
      "human_review_reason": "Requires understanding business logic to split correctly"
    },
    {
      "comment_id": "1008",
      "file": "src/auth/login.ts",
      "line": 20,
      "issue_description": "Missing unit tests",
      "exists": true,
      "valid": true,
      "severity": "Medium",
      "auto_fixable": false,
      "suggested_fix": "Add test cases for edge cases",
      "confidence": "high",
      "needs_human_review": false
    }
  ]
}
```

---

## Test Case 2: False Positive Detection

**PR URL:** `https://github.com/example/web-app/pull/15`

### Mock Comments

```json
{
  "comments": [
    {
      "id": "2001",
      "author": "reviewer",
      "body": "This should use useEffect instead of useState.",
      "path": "src/components/UserList.tsx",
      "line": 25,
      "type": "inline"
    },
    {
      "id": "2002",
      "author": "reviewer",
      "body": "Missing error handling here.",
      "path": "src/api/fetch.ts",
      "line": 10,
      "type": "inline"
    }
  ]
}
```

### Expected Analysis (False Positives)

```json
{
  "analyses": [
    {
      "comment_id": "2001",
      "exists": false,
      "valid": false,
      "reason": "Comment is based on outdated code. The current code already uses useEffect correctly.",
      "needs_human_review": false
    },
    {
      "comment_id": "2002",
      "exists": false,
      "valid": false,
      "reason": "Error handling is done in the caller function. This is intentional separation.",
      "needs_human_review": true,
      "human_review_reason": "Explain the error handling architecture"
    }
  ]
}
```

---

## Test Case 3: Conflicting Comments

```json
{
  "comments": [
    {
      "id": "3001",
      "author": "dev-a",
      "body": "Use async/await here for better readability.",
      "path": "src/service.ts",
      "line": 30,
      "type": "inline"
    },
    {
      "id": "3002",
      "author": "dev-b",
      "body": "Keep using .then() chains, async/await changes the execution flow.",
      "path": "src/service.ts",
      "line": 30,
      "type": "inline"
    }
  ]
}
```

### Expected Analysis

```json
{
  "conflict_detected": true,
  "conflicting_comments": ["3001", "3002"],
  "conflict_reason": "Contradictory suggestions for the same code location",
  "recommendation": "needs_human_review",
  "human_review_reason": "Both approaches are valid. Team should decide on standard."
}
```

---

## Version

- v1.0.0 - Initial test data
