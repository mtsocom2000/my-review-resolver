# GitHub API Reference

## PR Comments API

### 获取 PR 行内评论

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate
```

**响应字段:**
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

### 获取 PR 通用评论 (Issue Comments)

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
```

### 获取 PR 审查 (Reviews)

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
```

**响应字段:**
```json
{
  "id": 67890,
  "state": "APPROVED|CHANGES_REQUESTED|COMMENTED",
  "body": "Review summary",
  "user": { "login": "username" },
  "submitted_at": "2024-01-01T00:00:00Z"
}
```

### 回复评论

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST \
  -f body="Reply text"
```

### 发布总结评论

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  -X POST \
  -f body="Summary text"
```

---

## PR Info API

### 获取 PR 详情

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}
```

**响应字段:**
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

### 获取 PR 文件变更

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/files --paginate
```

**响应字段:**
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

### 检查分支

```bash
git branch --show-current
git remote -v
git status --porcelain
git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo "no upstream"
```

### 同步分支

```bash
git fetch origin branch
git merge origin/branch --no-edit
# 或
git rebase origin/branch
```

### 获取 commits 差异

```bash
git rev-list remote_commit..local_commit --oneline
```

---

## jq 过滤示例

### 提取评论关键信息

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | \
  jq '.[] | {id, path, line, body: .body[0:100], user: .user.login}'
```

### 按文件分组评论

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | \
  jq 'group_by(.path) | .[] | {file: .[0].path, count: length, comments: .}'
```

### 提取审查状态

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews | \
  jq '.[] | {user: .user.login, state: .state, body: .body}'
```

---

## Error Handling

### 常见错误

| HTTP 状态码 | 含义 | 处理 |
|-------------|------|------|
| 404 | 资源不存在 | 检查 owner/repo/pr_number |
| 403 | 无权限 | 检查 gh 认证 |
| 422 | 验证失败 | 检查参数格式 |
| 401 | 未认证 | 运行 `gh auth login` |

### 重试逻辑

```bash
# 带重试的 API 调用
retry_api() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if gh api "$@" 2>/dev/null; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying..."
        sleep 1
        ((attempt++))
    done
    
    return 1
}
```

---

## Rate Limits

| 类型 | 限制 |
|------|------|
| 核心 API | 5000 requests/hour |
| GraphQL | 5000 nodes/hour |
| Search | 30 requests/minute |

检查剩余配额:
```bash
gh api rate_limit
```

---

## Version

- v1.0.0 - Initial release
