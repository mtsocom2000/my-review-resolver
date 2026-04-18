# PR Comment Fix Skill

根据 PR 评论自动分析、修复、验证代码的完整工作流。

## 快速开始

### 安装

```bash
# 复制到技能目录
cp -r pr-comment-fix ~/.openclaw/workspace/skills/

# 或在 Claude Code 中加载
/skill load pr-comment-fix
```

### 使用

```
处理 GitHub PR 评论：
  /pr-comment-fix https://github.com/owner/repo/pull/42

处理 GitLab MR 评论：
  /pr-comment-fix https://gitlab.com/owner/repo/-/merge_requests/42
```

---

## 功能特性

### 10 阶段工作流

```
1. Check Branch     → 检查本地分支是否匹配
2. Sync Latest      → 同步 PR 最新代码
3. Fetch Comments   → 获取所有 PR 评论
4. Analyze Comments → 分析评论有效性
5. Parallel Review  → 多 Agent 并行评审
6. Apply Fixes      → 应用修复
7. Verify           → 编译 + 测试验证
8. Final Review     → 修复后评审
9. Push?            → 推送确认
10. Mark Resolved   → 标记已解决
```

### 多 Agent 并行评审

| Agent | 职责 |
|-------|------|
| **Analyzer** | 逐条评论分析，判断有效性 |
| **Security** | 安全相关问题评审 |
| **Performance** | 性能相关问题评审 |
| **Quality** | 代码质量问题评审 |
| **Validator** | 修复后验证 |

### 核心原则

1. **不盲目相信评论** - 先验证问题是否存在且合理
2. **修复后必须验证** - 编译和测试必须通过
3. **推送前必须确认** - 用户明确批准后才推送
4. **保持原子性** - 每个修复一个 commit

---

## 目录结构

```
pr-comment-fix/
├── SKILL.md                      # 主技能定义
├── README.md                     # 本文档
├── agents/
│   ├── analyzer.md               # 评论分析 Agent
│   ├── security.md               # 安全评审 Agent
│   ├── performance.md            # 性能评审 Agent
│   ├── quality.md                # 质量评审 Agent
│   └── validator.md              # 验证 Agent
├── scripts/
│   ├── check-branch.sh           # 分支检查脚本
│   ├── sync-pr.sh                # PR 同步脚本
│   ├── post-resolution.sh        # Resolved 标记脚本
│   └── dryrun.sh                 # Dryrun 验证脚本
├── references/
│   ├── github-api.md             # GitHub API 参考
│   └── comment-patterns.md       # 评论模式参考
└── tests/
    ├── test-data.md              # 测试数据
    └── test-cases.md             # 测试用例
```

---

## 使用示例

### 示例 1: 标准修复流程

```
用户：处理这个 PR 的评论 https://github.com/example/api/pull/42

Agent:
══════════════════════════════════════════════
  Stage 1: Check Branch
══════════════════════════════════════════════
✓ 本地分支与 PR 匹配：feature/auth

══════════════════════════════════════════════
  Stage 2: Sync Latest
══════════════════════════════════════════════
✓ 已同步最新代码 (origin/feature/auth)

══════════════════════════════════════════════
  Stage 3: Fetch Comments
══════════════════════════════════════════════
✓ 获取 8 条评论

══════════════════════════════════════════════
  Stage 4: Analyze Comments
══════════════════════════════════════════════
| ID   | 位置            | 问题           | 存在 | 合理 | 优先级  |
|------|-----------------|----------------|------|------|---------|
| 1001 | auth.ts:25      | SQL 注入风险    | ✓    | ✓    | Critical|
| 1002 | service.ts:48   | N+1 查询        | ✓    | ✓    | High    |
| 1003 | utils.ts:12     | 命名不清晰      | ✓    | ✓    | Low     |
| 1004 | -               | 正面评价        | -    | -    | Positive|
| 1005 | config.ts:33    | 缺少缓存        | ✓    | ✓    | Medium  |
| 1006 | payment.ts:8    | 硬编码 API 密钥   | ✓    | ✓    | Critical|
| 1007 | processor.ts:15 | 函数过长        | ✓    | △    | Medium  |
| 1008 | auth.ts:20      | 缺少单元测试    | ✓    | ✓    | Medium  |

══════════════════════════════════════════════
  Stage 5: Parallel Review
══════════════════════════════════════════════
✓ Security Agent: 2 个安全问题
✓ Performance Agent: 1 个性能问题
✓ Quality Agent: 3 个质量问题

══════════════════════════════════════════════
  Stage 6-8: Apply Fixes & Verify
══════════════════════════════════════════════
✓ 修复 1: SQL 注入风险 (使用参数化查询)
✓ 修复 2: N+1 查询 (批量查询)
✓ 修复 3: 命名改进 (d → currentDate)
✓ 修复 4: 添加缓存 (Map-based)
✓ 修复 5: API 密钥移至环境变量
△ 修复 6: 函数重构 (需人工确认)

编译：✓ 通过
测试：✓ 通过 (24/24)
Lint: ✓ 通过

══════════════════════════════════════════════
  Stage 9: Push Confirmation
══════════════════════════════════════════════
已修复 5 个问题，1 个需人工确认

是否推送到远端？(yes/no/show)
```

### 示例 2: 仅分析不修复

```
用户：分析一下这个 PR 的评论，先不修复
https://github.com/example/api/pull/42

Agent:
分析完成，共 8 条评论：
- 有效问题：6 个
- 误报：1 个
- 需人工确认：1 个

详细报告已生成，确认要开始修复吗？(yes/no)
```

### 示例 3: 处理特定评论

```
用户：只修复评论 1001 和 1002 提到的问题
https://github.com/example/api/pull/42

Agent:
将修复以下评论：
- #1001: SQL 注入风险
- #1002: N+1 查询

其他评论将跳过。确认？(yes/no)
```

---

## 配置

### 环境变量

```bash
# GitHub (可选，如已安装 gh CLI 则自动使用)
export GITHUB_TOKEN=ghp_xxx

# GitLab (如使用 GitLab)
export GITLAB_TOKEN=glpat-xxx

# 自定义构建/测试命令
export BUILD_CMD="npm run build"
export TEST_CMD="npm test"
export LINT_CMD="npm run lint"
```

### 自定义 Agent 提示

编辑 `agents/*.md` 文件调整 Agent 行为。

---

## 测试

### 运行 Dryrun

```bash
./scripts/dryrun.sh
```

### 运行特定测试

```bash
# 分支检查测试
./scripts/check-branch.sh https://github.com/owner/repo/pull/42

# 同步测试
./scripts/sync-pr.sh origin feature/branch
```

---

## 故障排除

### 问题：无法获取 PR 信息

**原因：** GitHub CLI 未安装或未认证

**解决：**
```bash
# 安装 gh CLI
brew install gh  # macOS
sudo apt install gh  # Linux

# 认证
gh auth login
```

### 问题：构建失败

**原因：** 修复引入了错误

**解决：**
1. 查看错误信息
2. 运行 `/pr-comment-fix rollback` 回滚
3. 手动修复或调整 Agent 提示

### 问题：评论标记为 resolved 失败

**原因：** 评论 ID 无效或权限不足

**解决：**
1. 确认 PR URL 正确
2. 确认有写入权限
3. 手动在 GitHub 上标记

---

## 贡献

欢迎提交 Issue 和 PR！

### 开发流程

1. Fork 本仓库
2. 创建分支 `git checkout -b feature/xxx`
3. 修改技能文件
4. 运行 dryrun 测试
5. 提交 PR

---

## 许可证

MIT License

---

## 版本历史

### v1.0.0 (2026-04-18)

- Initial release
- 10 阶段工作流
- 5 个 Agent 定义
- 3 个脚本工具
- 完整测试用例

---

## 参考

- [everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- [superpowers](https://github.com/obra/superpowers)
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)
