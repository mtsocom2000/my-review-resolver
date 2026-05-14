# GitHub API Reference

## PR Comments API

### Fetch PR inline comments

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate
```

**Response fields:**
```json
{
  "id": 12345,
  "path": "src/file.ts",
  "line": 42,
  "body": "Comment text",
  "user": { "login": "username" },
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z",
  "commit_id": "abc123"
}
```

### Fetch PR general comments (Issue Comments)

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
```

### Fetch PR reviews

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
```

**Response fields:**
```json
{
  "id": 67890,
  "state": "APPROVED|CHANGES_REQUESTED|COMMENTED",
  "body": "Review summary",
  "user": { "login": "username" },
  "submitted_at": "2024-01-01T00:00:00Z"
}
```

### Reply to a comment

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST \
  -f body="Reply text"
```

### Post a summary comment

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  -X POST \
  -f body="Summary text"
```

---

## PR Info API

### Get PR details

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}
```

**Response fields:**
```json
{
  "number": 123,
  "title": "PR Title",
  "state": "open|closed",
  "head": {
    "ref": "feature-branch",
    "sha": "abc123",
    "repo": {
      "full_name": "owner/repo"
    }
  },
  "base": {
    "ref": "main",
    "sha": "def456"
  },
  "user": { "login": "author" },
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### Get PR file changes

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/files --paginate
```

**Response fields:**
```json
{
  "filename": "src/file.ts",
  "status": "added|modified|removed",
  "additions": 10,
  "deletions": 5,
  "changes": 15,
  "patch": "@@ -1,5 +1,10 @@\n..."
}
```

---

## Git Operations

### Check branch

```bash
git branch --show-current
git remote -v
git status --porcelain
git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo "no upstream"
```

### Sync branch

```bash
git fetch origin branch
git merge origin/branch --no-edit
# or
git rebase origin/branch
```

### Get commit differences

```bash
git rev-list remote_commit..local_commit --oneline
```

---

## jq Filter Examples

### Extract key comment info

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | \
  jq '.[] | {id, path, line, body: .body[0:100], user: .user.login}'
```

### Group comments by file

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | \
  jq 'group_by(.path) | .[] | {file: .[0].path, count: length, comments: .}'
```

### Extract review states

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews | \
  jq '.[] | {user: .user.login, state: .state, body: .body}'
```

---

## Error Handling

### Common errors

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 404 | Resource not found | Verify owner/repo/pr_number |
| 403 | No permission | Check gh authentication |
| 422 | Validation failed | Check parameter format |
| 401 | Not authenticated | Run `gh auth login` |

### Retry logic

```bash
# Retry wrapper for API calls
retry_api() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if gh api "$@" 2>/dev/null; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying..." >&2
        sleep 1
        ((attempt++))
    done
    
    return 1
}
```

---

## Rate Limits

| Type | Limit |
|------|-------|
| Core API | 5000 requests/hour |
| GraphQL | 5000 nodes/hour |
| Search | 30 requests/minute |

Check remaining quota:
```bash
gh api rate_limit | jq '{core: .resources.core.remaining, graphql: .resources.graphql.remaining}'
```

---

## Version

- v1.0.0 - Initial release
