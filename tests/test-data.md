# Test Data — Mock PR Comments (v2.2.0 JSON format)

These fixture files are structured to match the JSON output of `scripts/fetch-pr-comments.sh`.

---

## Test Case 1: Mixed Comments (Security + Performance + Quality)

```json
{
  "status": "ok",
  "owner": "example",
  "repo": "api",
  "number": 42,
  "pr_info": {
    "title": "Add user authentication module",
    "state": "open",
    "head": {"ref": "feature/auth", "sha": "abc123def"},
    "base": {"ref": "main", "sha": "789xyz"},
    "additions": 245,
    "deletions": 30,
    "changed_files": 5
  },
  "comments": {
    "inline": [
      {
        "id": 1,
        "body": "String interpolation in SQL query at line 42 allows injection — use parameterized queries instead",
        "path": "src/auth.ts",
        "line": 42,
        "author": "security-reviewer-1",
        "severity": "Critical"
      },
      {
        "id": 2,
        "body": "This function is 85 lines long. Consider extracting the JWT validation logic into a separate function",
        "path": "src/auth.ts",
        "line": 15,
        "author": "quality-reviewer-1",
        "severity": "Medium"
      },
      {
        "id": 3,
        "body": "N+1 query: fetching each role separately inside a loop. Use a JOIN or batch query",
        "path": "src/roles.ts",
        "line": 88,
        "author": "perf-reviewer-1",
        "severity": "High"
      },
      {
        "id": 4,
        "body": "Mix of tabs and spaces for indentation on lines 50-60",
        "path": "src/auth.ts",
        "line": 50,
        "author": "quality-reviewer-1",
        "severity": "Low"
      },
      {
        "id": 5,
        "body": "Hardcoded API key in source — should be moved to environment variable",
        "path": "src/config.ts",
        "line": 8,
        "author": "security-reviewer-1",
        "severity": "Critical"
      },
      {
        "id": 6,
        "body": "No error handling around catch block — unhandled promise rejections may cause crashes",
        "path": "src/service.ts",
        "line": 32,
        "author": "security-reviewer-1",
        "severity": "High"
      }
    ],
    "reviews": [
      {
        "id": 101,
        "body": "Overall the approach looks good. A few security concerns that need addressing before merge.",
        "state": "CHANGES_REQUESTED",
        "author": "lead-reviewer"
      }
    ],
    "general": [
      {
        "id": 201,
        "body": "Great start! I left some inline comments. The main concern is the SQL injection in auth.ts — that's a blocker.",
        "author": "lead-reviewer"
      }
    ]
  },
  "counts": {"inline": 6, "reviews": 1, "general": 1}
}
```

---

## Test Case 2: Overlap + Supersede Scenario

These comments exhibit OVERLAP and SUPERSEDE relationships that Stage 5 should detect.

```json
{
  "status": "ok",
  "owner": "test",
  "repo": "demo",
  "number": 7,
  "comments": {
    "inline": [
      {
        "id": 10,
        "body": "Add input validation for userId before database query",
        "path": "src/users.ts",
        "line": 40,
        "author": "reviewer-a",
        "severity": "Medium"
      },
      {
        "id": 11,
        "body": "SQL injection: userId is concatenated directly into query string",
        "path": "src/users.ts",
        "line": 41,
        "author": "reviewer-b",
        "severity": "Critical"
      },
      {
        "id": 12,
        "body": "N+1 query in user list endpoint — loading roles in a loop",
        "path": "src/users.ts",
        "line": 55,
        "author": "reviewer-a",
        "severity": "High"
      }
    ]
  }
}
```

**Expected Stage 5 analysis:**
- `id:10` and `id:11` → OVERLAP (same file, adjacent lines, SQL-related issues)
- `id:12` → SAME_ROOT with 10+11 (all three stem from raw SQL in handlers vs a shared query layer)
- Clustering: all 3 into cluster_1: "Extract query builder layer"
- Supersedes: fixing 10+11 (parameterized queries via query builder) partially supersedes 12 (N+1 is a different issue but same architectural fix)

---

## Test Case 3: Conflict Scenario

```json
{
  "status": "ok",
  "owner": "test",
  "repo": "webapp",
  "number": 14,
  "comments": {
    "inline": [
      {
        "id": 20,
        "body": "Use a global error boundary middleware instead of try/catch in every handler",
        "path": "src/routes/index.ts",
        "line": 5,
        "author": "reviewer-x",
        "severity": "Medium"
      },
      {
        "id": 21,
        "body": "Keep error handling inline — global middleware adds indirection for simple handlers",
        "path": "src/routes/index.ts",
        "line": 5,
        "author": "reviewer-y",
        "severity": "Low"
      }
    ]
  }
}
```

**Expected Stage 5 analysis:**
- `id:20` and `id:21` → CONFLICT (mutually exclusive approaches)
- `nature`: "architectural_choice"
- Must present both options to user. Do not auto-resolve.

---

## Test Case 4: All Independent Comments

```json
{
  "status": "ok",
  "owner": "test",
  "repo": "utils",
  "number": 3,
  "comments": {
    "inline": [
      {
        "id": 30,
        "body": "Use const instead of let for immutable variable",
        "path": "src/format.ts",
        "line": 12,
        "author": "reviewer-z",
        "severity": "Low"
      },
      {
        "id": 31,
        "body": "Add unit test for date formatting edge case (feb 29)",
        "path": "tests/format.test.ts",
        "line": 0,
        "author": "reviewer-z",
        "severity": "Medium"
      },
      {
        "id": 32,
        "body": "Update README to document the new formatDate parameter",
        "path": "README.md",
        "line": 0,
        "author": "reviewer-z",
        "severity": "Low"
      }
    ]
  }
}
```

**Expected Stage 5 analysis:** No edges. All independent. Resolution order: [30, 31, 32] (any order).
