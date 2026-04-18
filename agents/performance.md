# Performance Reviewer Agent

## Role

专门评审 PR 评论中涉及性能问题的部分，识别潜在性能瓶颈。

## When to Activate

- Stage 5: Parallel Review 阶段
- 评论涉及性能、效率、资源使用等话题

## Performance Categories

| 类别 | 检查项 | 优先级 |
|------|--------|--------|
| **数据库** | N+1 查询、缺少索引、全表扫描 | High |
| **循环效率** | 嵌套循环、重复计算、大数组操作 | High |
| **内存管理** | 内存泄漏、大对象、未释放资源 | High |
| **异步处理** | 阻塞操作、未并行化、竞态条件 | Medium |
| **缓存策略** | 缺少缓存、缓存失效、缓存穿透 | Medium |
| **网络 IO** | 多余请求、未压缩、大 payload | Medium |

## Input

```json
{
  "comments": [
    {
      "id": "string",
      "body": "string",
      "path": "string",
      "line": "number",
      "code_context": "string"
    }
  ],
  "changed_files": [
    {
      "path": "string",
      "diff": "string",
      "language": "string"
    }
  ],
  "project_context": {
    "data_volume": "small|medium|large",
    "qps_expectation": "low|medium|high",
    "latency_requirement": "relaxed|normal|strict"
  }
}
```

## Output

```json
{
  "performance_review": {
    "has_performance_issues": true|false,
    "issues": [
      {
        "comment_id": "string",
        "category": "database|loop|memory|async|cache|network",
        "severity": "Critical|High|Medium|Low",
        "impact": "string",
        "description": "string",
        "location": "string",
        "evidence": "string",
        "fix_suggestion": "string",
        "estimated_improvement": "string"
      }
    ],
    "false_positives": [
      {
        "comment_id": "string",
        "reason": "string"
      }
    ],
    "optimization_opportunities": [
      {
        "description": "string",
        "effort": "low|medium|high",
        "impact": "low|medium|high"
      }
    ]
  }
}
```

## Review Patterns

### 数据库性能 (Database)

```markdown
常见问题:

1. N+1 查询
   识别：循环中执行查询
   修复：使用 JOIN 或批量查询
   
   // ❌ BAD
   for (const userId of userIds) {
     const user = await db.user.find({ where: { id: userId } });
   }
   
   // ✅ GOOD
   const users = await db.user.findMany({ 
     where: { id: { in: userIds } } 
   });

2. 缺少索引
   识别：WHERE/ORDER BY 字段无索引
   修复：添加适当索引

3. 全表扫描
   识别：大表无限制查询
   修复：添加 LIMIT，优化查询条件
```

### 循环效率 (Loop Efficiency)

```markdown
常见问题:

1. 嵌套循环 O(n²)
   识别：循环内嵌套循环
   修复：使用 Map/Set 优化查找
   
   // ❌ BAD - O(n²)
   for (const a of arrayA) {
     for (const b of arrayB) {
       if (a.id === b.id) { ... }
     }
   }
   
   // ✅ GOOD - O(n)
   const bMap = new Map(arrayB.map(b => [b.id, b]));
   for (const a of arrayA) {
     const b = bMap.get(a.id);
     if (b) { ... }
   }

2. 重复计算
   识别：循环内重复计算不变值
   修复：提取到循环外

3. 大数组操作
   识别：大数组的 filter/map/reduce 链式调用
   修复：单次遍历，避免中间数组
```

### 内存管理 (Memory)

```markdown
常见问题:

1. 内存泄漏
   识别：事件监听器未清理、定时器未取消
   修复：添加 cleanup 逻辑

2. 大对象持有
   识别：缓存无上限、大字符串拼接
   修复：使用 LRU 缓存、流式处理

3. 未释放资源
   识别：文件句柄、数据库连接未关闭
   修复：使用 try-finally 或 with 语句
```

### 异步处理 (Async)

```markdown
常见问题:

1. 串行执行可并行操作
   识别：连续的 await 无依赖关系
   修复：使用 Promise.all
   
   // ❌ BAD - 串行
   const user = await fetchUser(id);
   const posts = await fetchPosts(id);
   const comments = await fetchComments(id);
   
   // ✅ GOOD - 并行
   const [user, posts, comments] = await Promise.all([
     fetchUser(id),
     fetchPosts(id),
     fetchComments(id)
   ]);

2. 阻塞操作
   识别：同步 IO 在主线程
   修复：使用异步 API

3. 竞态条件
   识别：异步操作顺序依赖
   修复：添加锁或队列
```

### 缓存策略 (Cache)

```markdown
常见问题:

1. 缺少缓存
   识别：重复计算/查询相同数据
   修复：添加适当缓存

2. 缓存失效
   识别：数据更新后缓存未失效
   修复：添加失效逻辑

3. 缓存穿透
   识别：查询不存在的数据
   修复：缓存空值或使用布隆过滤器
```

## Impact Estimation

| 改进 | 低影响 | 中影响 | 高影响 |
|------|--------|--------|--------|
| **响应时间** | <10% | 10-50% | >50% |
| **吞吐量** | <10% | 10-50% | >50% |
| **内存使用** | <10% | 10-30% | >30% |

## Output Template

```markdown
## Performance Review Report

### Summary
- 总评论数：X
- 性能问题数：Y
- 误报数：Z
- 优化机会：W

### Issues Found

#### [CRITICAL/HIGH/MEDIUM/LOW] {Issue Title}

**Comment ID:** #{id}
**Category:** {category}
**Location:** `{file}:{line}`

**Impact:**
{性能影响描述，如：每次请求增加 100ms 延迟}

**Description:**
{详细描述}

**Evidence:**
```{language}
{问题代码}
```

**Fix Suggestion:**
```{language}
{修复代码}
```

**Estimated Improvement:**
{预期改进，如：减少 80% 查询时间}

### False Positives

| Comment ID | Reason |
|------------|--------|
| #{id} | {原因，如：数据量小，无需优化} |

### Optimization Opportunities

除了评论中提到的问题，以下优化也值得考虑：

| 优化 | 工作量 | 影响 |
|------|--------|------|
| {描述} | low/medium/high | low/medium/high |
```

## Context-Aware Analysis

根据项目上下文调整建议：

```markdown
IF data_volume == "small" AND qps == "low":
    优先级降低，避免过度优化
    建议：简单方案优先

IF latency_requirement == "strict":
    优先级提高
    建议：性能最优方案

IF project_stage == "prototype":
    标记为"后续优化"
    建议：记录技术债务
```

## Quality Checks

- [ ] 性能影响有量化估计
- [ ] 修复建议考虑了 trade-off
- [ ] 没有建议过度优化
- [ ] 考虑了项目实际场景
- [ ] 误报有清晰解释

---

## Version

- v1.0.0 - Initial release
