# PR Comment Patterns

## 常见评论类型及处理方式

---

## 1. 安全类评论

### 模式识别
```
关键词：security, inject, validate, sanitize, auth, token, secret, credential
```

### 示例
```
⚠️ This user input should be validated before use.
🔒 Consider using parameterized query to prevent SQL injection.
🔑 Don't hardcode API keys, use environment variables.
```

### 处理策略
- **优先级:** High 或 Critical
- **自动修复:** 是（有明确模式）
- **验证:** 必须通过安全扫描

### 修复模板

**输入验证:**
```typescript
// ❌ Before
const userId = req.query.id;

// ✅ After
import { z } from 'zod';
const userId = z.string().uuid().parse(req.query.id);
```

**参数化查询:**
```typescript
// ❌ Before
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ After
const query = 'SELECT * FROM users WHERE id = $1';
await db.query(query, [userId]);
```

---

## 2. 性能类评论

### 模式识别
```
关键词：performance, slow, n+1, query, cache, memory, optimize, efficient
```

### 示例
```
⚡ This loop makes a database query per iteration (N+1 problem).
⚡ Consider caching this expensive computation.
⚡ This could cause memory issues with large datasets.
```

### 处理策略
- **优先级:** Medium 或 High
- **自动修复:** 部分（需了解数据量）
- **验证:** 性能测试或代码审查

### 修复模板

**N+1 查询:**
```typescript
// ❌ Before
for (const userId of userIds) {
  const user = await db.user.find({ where: { id: userId } });
}

// ✅ After
const users = await db.user.findMany({
  where: { id: { in: userIds } }
});
```

**添加缓存:**
```typescript
// ❌ Before
async function getData(id: string) {
  return expensiveOperation(id);
}

// ✅ After
const cache = new Map<string, any>();
async function getData(id: string) {
  if (cache.has(id)) return cache.get(id);
  const result = await expensiveOperation(id);
  cache.set(id, result);
  return result;
}
```

---

## 3. 代码质量类评论

### 模式识别
```
关键词：refactor, duplicate, complex, clean, simplify, extract, abstract
```

### 示例
```
📝 This logic is duplicated in 3 places.
📝 This function is too long, consider breaking it down.
📝 Could use a more descriptive variable name.
```

### 处理策略
- **优先级:** Medium
- **自动修复:** 部分
- **验证:** 代码审查

### 修复模板

**提取函数:**
```typescript
// ❌ Before
function processOrder(order: Order) {
  // 50 lines of code doing multiple things
  // validate...
  // calculate...
  // save...
  // notify...
}

// ✅ After
function processOrder(order: Order) {
  validateOrder(order);
  const total = calculateTotal(order);
  saveOrder(order, total);
  sendConfirmation(order);
}
```

**消除重复:**
```typescript
// ❌ Before
function getActiveUsers() {
  return users.filter(u => u.status === 'active').map(u => u.name);
}
function getActivePosts() {
  return posts.filter(p => p.status === 'active').map(p => p.title);
}

// ✅ After
function getActiveItems<T>(items: T[], statusField: string, nameField: string) {
  return items
    .filter(i => i[statusField] === 'active')
    .map(i => i[nameField]);
}
```

---

## 4. 风格类评论

### 模式识别
```
关键词：naming, style, convention, format, lint, consistent, pattern
```

### 示例
```
🎨 Variable name could be more descriptive.
🎨 This doesn't follow our naming convention.
🎨 Consider using camelCase here.
```

### 处理策略
- **优先级:** Low
- **自动修复:** 是
- **验证:** Lint 检查

### 修复模板

**命名改进:**
```typescript
// ❌ Before
const d = new Date();
const arr = [];
function proc(data) { }

// ✅ After
const currentDate = new Date();
const activeUsers = [];
function processUserData(userData: UserData) { }
```

---

## 5. 测试类评论

### 模式识别
```
关键词：test, coverage, edge case, assert, mock, unit test
```

### 示例
```
✅ Add a test for this edge case.
✅ This should have unit tests.
✅ Consider adding integration tests.
```

### 处理策略
- **优先级:** Medium
- **自动修复:** 部分
- **验证:** 运行测试

### 修复模板

**添加测试:**
```typescript
// ✅ Add test file
describe('calculateDiscount', () => {
  it('should return 0 for new users', () => {
    expect(calculateDiscount({ level: 0 })).toBe(0);
  });
  
  it('should return 10% for premium users', () => {
    expect(calculateDiscount({ level: 1 })).toBe(0.1);
  });
  
  it('should handle invalid input', () => {
    expect(() => calculateDiscount(null)).toThrow();
  });
});
```

---

## 6. 文档类评论

### 模式识别
```
关键词：document, comment, jsdoc, readme, explain, clarify
```

### 示例
```
📖 Add JSDoc for this function.
📖 This complex logic needs a comment.
📖 Update the README with usage examples.
```

### 处理策略
- **优先级:** Low
- **自动修复:** 是
- **验证:** 文档审查

### 修复模板

**添加 JSDoc:**
```typescript
// ✅ Before
function calculate(a, b) { return a + b; }

// ✅ After
/**
 * Calculates the sum of two numbers
 * @param a - First number
 * @param b - Second number
 * @returns The sum of a and b
 */
function calculate(a: number, b: number): number {
  return a + b;
}
```

---

## 7. 架构类评论

### 模式识别
```
关键词：architecture, design, pattern, structure, module, layer, separation
```

### 示例
```
🏗️ This should be in a separate service.
🏗️ Consider using the repository pattern.
🏗️ This breaks the separation of concerns.
```

### 处理策略
- **优先级:** High
- **自动修复:** 否（需人工决策）
- **验证:** 架构审查

### 处理建议
- 标记为需要人工确认
- 提供多个可行方案
- 说明各方案的权衡

---

## Comment Severity Classification

| 级别 | 标识 | 响应时间 | 示例 |
|------|------|----------|------|
| **Critical** | 🔴 | 立即 | 安全漏洞、数据损坏 |
| **High** | 🟠 | 24h | 功能错误、严重 bug |
| **Medium** | 🟡 | 本周 | 代码质量、性能优化 |
| **Low** | 🟢 | 有空时 | 风格、命名、文档 |

---

## Response Templates

### 接受建议
```
Thanks for the feedback! I've addressed this in commit {sha}.
```

### 部分接受
```
Good point! I've implemented a partial fix in {sha}. 
For the remaining issue, I think {alternative} might be better because {reason}.
```

### 礼貌拒绝
```
I appreciate the suggestion! However, I'm going to keep it as-is because {reason}.
This aligns with our team's decision in {reference}.
```

### 需要澄清
```
Could you clarify what you mean by {specific}? I want to make sure I understand correctly.
```

---

## Version

- v1.0.0 - Initial release
