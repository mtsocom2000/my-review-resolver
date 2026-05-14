# PR Comment Patterns

## Common Comment Types and Response Strategies

---

## 1. Security Comments

### Pattern Recognition
```
Keywords: security, injection, validate, sanitize, auth, token, secret, credential, xss, csrf
```

### Examples
```
This user input should be validated before use.
Consider using parameterized query to prevent SQL injection.
Don't hardcode API keys, use environment variables.
```

### Strategy
- **Priority:** High or Critical
- **Auto-fix:** Yes (well-defined patterns)
- **Verification:** Must pass security scan

### Fix Templates

**Input validation:**
```typescript
// Before
const userId = req.query.id;

// After
import { z } from 'zod';
const userId = z.string().uuid().parse(req.query.id);
```

**Parameterized queries:**
```typescript
// Before
const query = `SELECT * FROM users WHERE id = ${userId}`;

// After
const query = 'SELECT * FROM users WHERE id = $1';
await db.query(query, [userId]);
```

---

## 2. Performance Comments

### Pattern Recognition
```
Keywords: performance, slow, n+1, query, cache, memory, optimize, efficient, bottleneck
```

### Examples
```
This loop makes a database query per iteration (N+1 problem).
Consider caching this expensive computation.
This could cause memory issues with large datasets.
```

### Strategy
- **Priority:** Medium or High
- **Auto-fix:** Partial (requires data volume context)
- **Verification:** Performance test or code review

### Fix Templates

**N+1 Queries:**
```typescript
// Before
for (const userId of userIds) {
  const user = await db.user.find({ where: { id: userId } });
}

// After
const users = await db.user.findMany({
  where: { id: { in: userIds } }
});
```

**Add caching:**
```typescript
// Before
async function getData(id: string) {
  return expensiveOperation(id);
}

// After
const cache = new Map<string, any>();
async function getData(id: string) {
  if (cache.has(id)) return cache.get(id);
  const result = await expensiveOperation(id);
  cache.set(id, result);
  return result;
}
```

---

## 3. Code Quality Comments

### Pattern Recognition
```
Keywords: refactor, duplicate, complex, clean, simplify, extract, abstract, magic number
```

### Examples
```
This logic is duplicated in 3 places.
This function is too long, consider breaking it down.
Could use a more descriptive variable name.
```

### Strategy
- **Priority:** Medium
- **Auto-fix:** Partial
- **Verification:** Code review

### Fix Templates

**Extract function:**
```typescript
// Before
function processOrder(order: Order) {
  // 50 lines doing multiple things:
  // validate, calculate, save, notify...
}

// After
function processOrder(order: Order) {
  validateOrder(order);
  const total = calculateTotal(order);
  saveOrder(order, total);
  sendConfirmation(order);
}
```

**Eliminate duplication:**
```typescript
// Before
function getActiveUsers() {
  return users.filter(u => u.status === 'active').map(u => u.name);
}
function getActivePosts() {
  return posts.filter(p => p.status === 'active').map(p => p.title);
}

// After
function getActiveItems<T>(items: T[], statusField: string, nameField: string) {
  return items
    .filter(i => i[statusField] === 'active')
    .map(i => i[nameField]);
}
```

---

## 4. Style Comments

### Pattern Recognition
```
Keywords: naming, style, convention, format, lint, consistent, pattern, camelCase
```

### Examples
```
Variable name could be more descriptive.
This doesn't follow our naming convention.
Consider using camelCase here.
```

### Strategy
- **Priority:** Low
- **Auto-fix:** Yes
- **Verification:** Lint check

### Fix Templates

**Naming improvements:**
```typescript
// Before
const d = new Date();
const arr = [];
function proc(data) { }

// After
const currentDate = new Date();
const activeUsers = [];
function processUserData(userData: UserData) { }
```

---

## 5. Test Comments

### Pattern Recognition
```
Keywords: test, coverage, edge case, assert, mock, unit test, integration test
```

### Examples
```
Add a test for this edge case.
This should have unit tests.
Consider adding integration tests.
```

### Strategy
- **Priority:** Medium
- **Auto-fix:** Partial
- **Verification:** Run tests

### Fix Templates

**Add tests:**
```typescript
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

## 6. Documentation Comments

### Pattern Recognition
```
Keywords: document, comment, jsdoc, readme, explain, clarify, documentation
```

### Examples
```
Add JSDoc for this function.
This complex logic needs a comment.
Update the README with usage examples.
```

### Strategy
- **Priority:** Low
- **Auto-fix:** Yes
- **Verification:** Documentation review

### Fix Templates

**Add JSDoc:**
```typescript
// Before
function calculate(a, b) { return a + b; }

// After
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

## 7. Architecture Comments

### Pattern Recognition
```
Keywords: architecture, design, pattern, structure, module, layer, separation of concerns
```

### Examples
```
This should be in a separate service.
Consider using the repository pattern.
This breaks the separation of concerns.
```

### Strategy
- **Priority:** High
- **Auto-fix:** No (requires human decision)
- **Verification:** Architecture review

### Handling
- Mark as needs-human-confirmation
- Provide multiple viable approaches with trade-offs
- Each approach should state which comments it resolves

---

## Comment Severity Classification

| Level | Label | Response Time | Examples |
|-------|-------|---------------|----------|
| **Critical** | 🔴 | Immediate | Security vulnerability, data corruption |
| **High** | 🟠 | 24h | Functional bug, significant defect |
| **Medium** | 🟡 | This sprint | Code quality, performance optimization |
| **Low** | 🟢 | When possible | Style, naming, documentation |

---

## Response Templates

### Accept suggestion
```
Thanks for the feedback! I've addressed this in commit {sha}.
```

### Partially accept
```
Good point! I've implemented a partial fix in {sha}. 
For the remaining issue, I think {alternative} would be better because {reason}.
```

### Politely decline
```
I appreciate the suggestion — staying with the current approach because {reason}.
This aligns with {reference}.
```

### Needs clarification
```
Could you clarify what you mean by {specific}? I want to make sure I address the right concern.
```

---

## Version

- v1.0.0 - Initial release
