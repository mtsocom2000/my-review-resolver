---
name: pr-comment-fix
description: Use when given a GitHub/GitLab PR URL to check local branch sync status, fetch PR comments, analyze comment validity, apply fixes with multi-agent parallel review, verify build/tests pass, and optionally push and mark comments resolved
origin: custom
---

# PR Comment Fix

## Overview

根据 PR 评论自动分析、修复、验证代码的完整工作流。

**核心原则：**
1. 不盲目相信评论，先验证问题是否存在且合理
2. 修复后必须通过编译和测试
3. 推送前必须获得用户确认
4. 保持修复的原子性和可追溯性

## When to Use

- 用户提供 GitHub/GitLab PR URL
- 需要批量处理 PR 审查评论
- 需要根据评论修复代码并验证

## Scope Boundaries

**本技能处理：**
- GitHub/GitLab PR 评论获取和分析
- 本地分支状态检查和同步
- 多 Agent 并行评审
- 修复、编译、测试验证
- 推送确认和 resolved 标记

**不处理：**
- 创建新 PR
- 合并 PR
- 解决合并冲突（需人工介入）

---

## Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          PR Comment Fix Flow                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │ Stage 1 │───>│ Stage 2 │───>│ Stage 3 │───>│ Stage 4 │              │
│  │  Check  │    │  Sync   │    │  Fetch  │    │ Analyze │              │
│  │ Branch  │    │ Latest  │    │Comments │    │Comments │              │
│  └─────────┘    └─────────┘    └─────────┘    └────┬────┘              │
│                                                    │                    │
│                                                    v                    │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │ Stage 8 │<───│ Stage 7 │<───│ Stage 6 │<───│ Stage 5 │              │
│  │  Final  │    │ Verify  │    │  Apply  │    │Parallel │              │
│  │ Review  │    │Build+Test│   │  Fixes  │    │ Review  │              │
│  └────┬────┘    └─────────┘    └─────────┘    └─────────┘              │
│       │                                                                 │
│       v                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐                            │
│  │ Stage 9 │───>│ Stage 10│───>│   END   │                            │
│  │  Push?  │    │  Mark   │    │         │                            │
│  │ (Confirm)│   │Resolved │    │         │                            │
│  └─────────┘    └─────────┘    └─────────┘                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Stage Details

### Stage 1: Check Branch (检查分支)

**目标：** 确认本地代码与 PR 分支一致

**输入：** PR URL

**步骤：**

1. 解析 PR URL 获取：
   - `owner/repo`
   - PR 号码
   - 源分支名称

2. 检查本地 git 状态：
   ```bash
   git branch --show-current
   git remote -v
   git status --porcelain
   git rev-parse --abbrev-ref @'{u}' 2>/dev/null || echo "no upstream"
   ```

3. 判断是否匹配：
   - 当前分支名 == PR 源分支名
   - upstream 指向正确的 remote

**输出：**

| 状态 | 行动 |
|------|------|
| ✓ 匹配 | 继续 Stage 2 |
| ✗ 分支不匹配 | 提示用户切换分支 |
| ✗ 有未提交更改 | 提示用户先提交或 stash |
| ✗ 分支不存在 | 提示用户拉取分支 |

**分支不匹配时的提示：**
```
⚠️ 本地分支与 PR 不匹配

PR 分支：{owner}/{branch}
当前分支：{current_branch}

请执行以下命令切换分支：
  git fetch {remote}
  git checkout {branch}
  git pull {remote} {branch}

切换完成后请告诉我继续。
```

---

### Stage 2: Sync Latest (同步最新)

**目标：** 同步 PR 分支最新代码

**步骤：**
```bash
git fetch {remote} {branch}
git merge {remote}/{branch} --no-edit
# 或根据用户偏好使用 rebase
```

**检查点：**
- 合并是否成功
- 是否有冲突（有冲突则停止，需人工解决）

---

### Stage 3: Fetch Comments (获取评论)

**目标：** 获取 PR 所有评论

**GitHub API：**
```bash
# PR 行内评论
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --paginate | jq '.[] | {id, path, line, body, user, created_at}'

# PR 通用评论 (Issue comments)
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  --paginate | jq '.[] | {id, body, user, created_at}'

# PR 审查评论 (Reviews)
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
  --paginate | jq '.[] | {id, state, body, user}'
```

**GitLab API：**
```bash
# GitLab MR comments
curl --header "PRIVATE-TOKEN: {token}" \
  "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{mr_iid}/notes"
```

**提取信息：**
- 评论 ID
- 评论者
- 评论内容
- 文件路径 + 行号（行内评论）
- 评论类型（行内/通用/审查）

---

### Stage 4: Analyze Comments (分析评论)

**目标：** 分析每个评论的有效性和优先级

**分析维度：**

| 维度 | 说明 |
|------|------|
| **存在性** | 代码中是否真的有此问题 |
| **合理性** | 评论的建议是否正确 |
| **优先级** | Critical/High/Medium/Low |
| **可自动修复** | 是否可以通过代码修改自动修复 |

**输出表格：**

```markdown
| ID | 位置 | 问题描述 | 存在 | 合理 | 优先级 | 修复方式 |
|----|------|----------|------|------|--------|----------|
| 1  | auth.ts:42 | 缺少输入验证 | ✓ | ✓ | High | 自动 |
| 2  | utils.ts:15 | 命名不清晰 | ✓ | △ | Low | 需确认 |
| 3  | api.ts:88 | 性能问题 | ✗ | - | - | 误报 |
```

**存在性判断规则：**
- ✓ 存在：代码确实有问题
- △ 部分存在：问题存在但描述不准确
- ✗ 不存在：评论有误或已过时

**合理性判断规则：**
- ✓ 合理：建议正确且可行
- △ 部分合理：建议可行但不是最优
- ✗ 不合理：建议有误

---

### Stage 5: Parallel Review (多 Agent 并行评审)

**目标：** 多视角评审评论和分析结果

**Agent 分工：**

| Agent | 文件 | 职责 |
|-------|------|------|
| **Analyzer** | `agents/analyzer.md` | 逐条评论分析，判断有效性 |
| **Security** | `agents/security.md` | 安全相关问题评审 |
| **Performance** | `agents/performance.md` | 性能相关问题评审 |
| **Quality** | `agents/quality.md` | 代码质量问题评审 |

**并行执行模式：**
```markdown
同时启动所有相关 Agent，每个 Agent 独立评审后返回结果。
主 Agent 聚合所有结果，去重后生成最终修复列表。
```

**聚合规则：**
- 多个 Agent 都标记为 Critical → 优先处理
- Agent 意见不一致 → 标记需人工确认
- 所有 Agent 都认为无问题 → 跳过该评论

---

### Stage 6: Apply Fixes (应用修复)

**目标：** 应用修复

**修复策略：**

```
IF 评论提到具体修复方法 THEN
    按评论方法修复
ELSE IF 评论只描述问题 THEN
    自行寻找合理修复方法
    生成修复方案后请求用户确认
ELSE IF 不确定 THEN
    标记需要人工确认
    跳过该评论
END IF
```

**修复原则：**
1. 每次修复一个评论的问题（原子性）
2. 每个修复一个 commit
3. Commit message 格式：`fix: address PR comment #{id} - {description}`

---

### Stage 7: Verify (验证)

**目标：** 验证修复

**检查项：**

| 检查 | 命令 | 必须通过 |
|------|------|----------|
| 编译 | `npm run build` / `go build` / etc. | ✓ |
| 测试 | `npm test` / `go test` / etc. | ✓ |
| Lint | `npm run lint` / `golangci-lint` | △ |

**失败处理：**
- 编译失败 → 回滚修复，重新分析
- 测试失败 → 检查修复逻辑，修正
- Lint 失败 → 自动修复或提示用户

---

### Stage 8: Final Review (最终评审)

**目标：** 修复后评审

**检查项：**
- 修复是否符合原始代码意图
- 是否引入新问题
- 代码风格是否一致
- 是否有更好的实现方式

**Validator Agent：**
- 读取 `agents/validator.md`
- 对比修复前后的代码
- 运行额外检查

---

### Stage 9: Push? (推送确认)

**目标：** 确认是否推送

**输出报告：**
```
═══════════════════════════════════════════════════════
  PR Comment Fix - 修复完成报告
═══════════════════════════════════════════════════════

PR: {owner}/{repo}#{pr_number}
分支：{branch}

已修复问题：X / Y

┌─────────────────────────────────────────────────────┐
│ [✓] 问题 1: 缺少输入验证 (auth.ts:42)               │
│     修复：添加 zod schema 验证                       │
│     Commit: a1b2c3d                                  │
├─────────────────────────────────────────────────────┤
│ [✓] 问题 2: 命名不清晰 (utils.ts:15)                │
│     修复：重命名为 xxx                               │
│     Commit: d4e5f6g                                  │
├─────────────────────────────────────────────────────┤
│ [△] 问题 3: 需要人工确认 (api.ts:88)                │
│     原因：评论建议与现有架构冲突                     │
└─────────────────────────────────────────────────────┘

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

### Stage 10: Mark Resolved (标记已解决)

**目标：** 标记已解决的评论

**GitHub API：**
```bash
# 回复评论标记 resolved
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST -f body="✓ Resolved in commit {commit_sha}"

# 或者在 PR 中统一回复
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  -X POST -f body="已修复以下问题：\n- #1: 缺少输入验证\n- #2: 命名不清晰\n\nCommits: {commit_shas}"
```

**GitLab API：**
```bash
curl --request POST --header "PRIVATE-TOKEN: {token}" \
  "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{mr_iid}/notes/{note_id}/resolve"
```

---

## Common Mistakes

| 错误 | 后果 | 避免方法 |
|------|------|----------|
| 不验证评论直接修复 | 修复了不存在的问题 | Stage 4 强制分析 |
| 修复后不运行测试 | 引入回归 bug | Stage 7 强制验证 |
| 一次修复多个问题 | 难以定位问题 | 一个评论一个 commit |
| 不确认就推送 | 推送了错误的修复 | Stage 9 强制确认 |
| 忽略合并冲突 | 代码损坏 | Stage 2 冲突检测 |

---

## Scripts Reference

### check-branch.sh
```bash
#!/bin/bash
# 检查本地分支是否与 PR 匹配
```

### sync-pr.sh
```bash
#!/bin/bash
# 同步 PR 分支最新代码
```

### post-resolution.sh
```bash
#!/bin/bash
# 回复评论标记 resolved
```

---

## Related Skills

- `using-git-worktrees` - 使用 git worktree 隔离开发
- `test-driven-development` - TDD 修复流程
- `requesting-code-review` - 代码审查

---

## Version

- v1.0.0 - Initial release
