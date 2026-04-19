# ECC Integration Guide

## Overview

PR Comment Fix skill automatically integrates with ECC (Everything Claude Code) when available, providing enhanced multi-agent parallel review capabilities.

---

## How It Works

### Automatic Detection

When the skill runs, it automatically detects ECC installation:

```typescript
import { detectECC } from './lib/ecc-detector';

const ecc = detectECC();
if (ecc.installed) {
  console.log(`✅ ECC detected: ${ecc.agents.length} agents available`);
} else {
  console.log('ℹ️ ECC not installed, using fallback agents');
}
```

### Enhanced Review with ECC

When ECC is available, the skill uses specialized agents for parallel review:

```
┌─────────────────────────────────────────────────────────────┐
│  PR Comment Received                                        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   ECC Installed?      │
              └───────────────────────┘
                     │          │
                Yes  │          │  No
                     ▼          ▼
        ┌─────────────────┐  ┌─────────────────┐
        │  ECC Agents     │  │  Fallback       │
        │  - security-    │  │  Agents         │
        │    reviewer     │  │  - Built-in     │
        │  - performance- │  │    subagents    │
        │    optimizer    │  │                 │
        │  - code-        │  │                 │
        │    reviewer     │  │                 │
        │  - language-    │  │                 │
        │    specific     │  │                 │
        └─────────────────┘  └─────────────────┘
                     │          │
                     └──────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  Consolidate Results  │
              └───────────────────────┘
```

---

## Installation

### Step 1: Install PR Comment Fix Skill

```bash
git clone https://github.com/mtsocom2000/my-review-resolver.git
cd my-review-resolver
./install.sh --auto
```

### Step 2 (Optional): Install ECC for Enhanced Review

```bash
# Clone ECC
git clone https://github.com/affaan-m/everything-claude-code.git
cd everything-claude-code

# Install dependencies
npm install

# Install agents and skills
./install.sh --profile full
```

### Verify Installation

```bash
# Check ECC
npx tsx lib/ecc-detector.ts

# Should output:
# ✅ ECC installed
#    Agents: 48
```

---

## Usage

### Basic Usage (No ECC Required)

```bash
# In Claude Code, Cursor, VSCode, or OpenCode
/fix-pr https://github.com/owner/repo/pull/42
```

### With ECC (Enhanced Review)

Same command, automatically uses ECC agents if available:

```bash
/fix-pr https://github.com/owner/repo/pull/42

# Output:
# ℹ️ ECC detected: 48 agents available
# 🚀 Running parallel review with ECC agents...
#    - security-reviewer: Analyzing...
#    - performance-optimizer: Analyzing...
#    - code-reviewer: Analyzing...
```

---

## ECC Agents Used

### Review Agents

| Agent | Purpose | When Used |
|-------|---------|-----------|
| `security-reviewer` | Security vulnerability detection | Always (if ECC installed) |
| `performance-optimizer` | Performance issue detection | Always (if ECC installed) |
| `code-reviewer` | General code quality | Always (if ECC installed) |

### Language-Specific Reviewers

Automatically selected based on file type:

| File Type | Agent |
|-----------|-------|
| .ts, .tsx, .js, .jsx | `typescript-reviewer` |
| .py | `python-reviewer` |
| .java | `java-reviewer` |
| .go | `go-reviewer` |
| .rs | `rust-reviewer` |
| .kt | `kotlin-reviewer` |
| .cpp, .cc, .h | `cpp-reviewer` |
| .sql | `database-reviewer` |

---

## Fallback Behavior

If ECC is not installed:

1. **Built-in Agents**: Uses skill's built-in subagents
   - `analyzer` - Comment analysis
   - `security` - Security review
   - `performance` - Performance review
   - `quality` - Code quality review
   - `validator` - Fix verification

2. **Same Workflow**: All stages work identically
   - Comment analysis
   - Parallel review
   - Fix application
   - Verification

3. **Graceful Degradation**: No user action required

---

## Configuration

### Environment Variables

```bash
# ECC installation path (if non-standard)
export ECC_INSTALL_PATH=/custom/path/to/ecc

# Enable debug logging
export ECC_DEBUG=true

# Skip ECC detection (always use fallback)
export ECC_SKIP_DETECTION=true
```

### Skill Configuration

In `~/.config/pr-comment-fix/config`:

```bash
# Prefer ECC agents (default: true)
ECC_PREFER_AGENTS=true

# Fallback timeout (ms)
ECC_FALLBACK_TIMEOUT=5000

# Parallel review agents
ECC_REVIEW_AGENTS=security-reviewer,performance-optimizer,code-reviewer
```

---

## API Reference

### detectECC()

Detect ECC installation.

```typescript
import { detectECC } from './lib/ecc-detector';

const ecc = detectECC();
console.log(ecc.installed);  // boolean
console.log(ecc.agents);     // ECCAgent[]
```

### getReviewAgents()

Get all review agents.

```typescript
import { getReviewAgents } from './lib/ecc-detector';

const agents = getReviewAgents();
// Returns: typescript-reviewer, security-reviewer, etc.
```

### buildParallelReviewTasks()

Build parallel review tasks for subagent spawning.

```typescript
import { buildParallelReviewTasks } from './lib/ecc-detector';

const tasks = buildParallelReviewTasks({
  diff: '...',
  comment: 'Add error handling',
  filePath: 'src/api.ts',
  language: 'typescript'
});

// Returns array of tasks for subagent spawning
```

---

## Troubleshooting

### ECC Not Detected

**Symptom**: Skill reports "ECC not installed" but you installed it

**Solution**:
```bash
# Verify ECC installation
ls -la ~/.claude/agents/

# Should show agent files
# If empty, reinstall ECC:
cd everything-claude-code
./install.sh --profile full
```

### Agent Loading Errors

**Symptom**: "Failed to load agent" errors

**Solution**:
```bash
# Check agent files
cat ~/.claude/agents/security-reviewer.md

# If corrupted, repair ECC
cd everything-claude-code
npx ecc repair
```

### Slow Review

**Symptom**: Parallel review takes too long

**Solution**:
```bash
# Reduce number of agents
export ECC_REVIEW_AGENTS=security-reviewer,code-reviewer

# Or skip ECC entirely
export ECC_SKIP_DETECTION=true
```

---

## Performance Comparison

| Configuration | Review Time | Coverage |
|---------------|-------------|----------|
| ECC (3 agents) | ~15-30s | Comprehensive |
| ECC (1 agent) | ~5-10s | Good |
| Fallback | ~5-10s | Basic |

---

## Version History

### v2.1.0 (Current)
- ✅ ECC integration
- ✅ Automatic detection
- ✅ Graceful fallback
- ✅ Language-specific reviewers

### v2.0.0
- Built-in subagents only
- No ECC integration

---

## Support

- **ECC Issues**: https://github.com/affaan-m/everything-claude-code/issues
- **Skill Issues**: https://github.com/mtsocom2000/my-review-resolver/issues

---

## License

MIT License - Same as parent project.
