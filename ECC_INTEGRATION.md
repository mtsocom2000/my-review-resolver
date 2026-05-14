# ECC Integration Guide

## Overview

PR Comment Fix skill automatically integrates with ECC (Everything Claude Code) when available, providing enhanced multi-agent parallel review capabilities.

---

## How It Works

### Automatic Detection

At pipeline start, the skill runs the ECC detector script:

```
Running detection:
  tsx ./lib/ecc-detector.ts

If installed:      Use ECC agents for Stage 5 parallel review
If not installed:  Use built-in agents from agents/ (same pipeline, fewer specialized reviewers)
```

The detection result feeds into Stage 5 of the pipeline, selecting appropriate reviewers based on file extensions.

### Enhanced Review with ECC

When ECC is available, the skill spawns specialized agents in parallel:

- **Security**: ECC `security-reviewer` (always)
- **Performance**: ECC `performance-optimizer` (always)
- **Quality**: ECC `code-reviewer` (always)
- **Language-specific**: Selected by file extension (.ts → typescript-reviewer, .py → python-reviewer, etc.)

All agents receive the same input (diff + file contents + comment context) and return structured findings. Results are deduplicated and merged by the orchestrator.

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
git clone https://github.com/affaan-m/everything-claude-code.git
cd everything-claude-code
npm install
./install.sh --profile full
```

### Verify Installation

```bash
npx tsx lib/ecc-detector.ts
# Expected: ✅ ECC installed, Agents: 48
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

Automatically selected based on file type from Stage 6 (Parallel Review):

| File Type | ECC Agent (primary) | Built-in Agent (fallback) |
|-----------|--------------------|---------------------------|
| .ts, .tsx, .js, .jsx | `typescript-reviewer` | `agents/quality.md` |
| .py | `python-reviewer` | `agents/quality.md` |
| .java | `java-reviewer` | `agents/quality.md` |
| .go | `go-reviewer` | `agents/quality.md` |
| .rs | `rust-reviewer` | `agents/quality.md` |
| .kt | `kotlin-reviewer` | `agents/quality.md` |
| .cpp, .cc, .h | `cpp-reviewer` | `agents/quality.md` |
| .sql | `database-reviewer` | `agents/quality.md` |

---

## Pipeline Integration (v2.3.0+)

ECC agents are used in **Stage 6 (Parallel Review)**. The full pipeline:

```
Stage 0: URL Validation
Stage 1: Branch Check
Stage 2: Sync Latest
Stage 3: Fetch Comments
Stage 4: Analyze Comments (analyzer.md) — individual comment validity
Stage 5: Dependency Graph (dependency-analyzer.md) — NEW: clusters, conflicts, supersedes
Stage 6: Parallel Review — ECC agents OR built-in agents
Stage 7: Apply Fixes — follows resolution_order from Stage 5
Stage 8: Verify
Stage 9: Final Review (validator.md)
Stage 10: Push Confirmation
Stage 11: Reply to Comments
Stage 12: Summary (optional)
```

**Stage 5 (Dependency Graph) runs before Stage 6**, so ECC reviewers receive the clustered analysis context. This means the dependency-analyzer has already determined which comments share root causes before ECC agents start their parallel review.

---

## Fallback Behavior

If ECC is not installed:

1. **Built-in Agents**: Uses skill's built-in subagents from `agents/`:
   - `analyzer.md` — Comment validity analysis (Stage 4)
   - `dependency-analyzer.md` — Comment dependency graph (Stage 5) — NEW
   - `security.md` — Security review (Stage 6)
   - `performance.md` — Performance review (Stage 6)
   - `quality.md` — Code quality review (Stage 6)
   - `validator.md` — Post-fix validation (Stage 9)

2. **Same Workflow**: All stages work identically
   - Comment analysis
   - Parallel review
   - Fix application
   - Verification

3. **Graceful Degradation**: No user action required

---

## Configuration

Environment variables are documented in the main SKILL.md and README. Key ECC-related:

```bash
# ECC installation path (if non-standard)
export ECC_INSTALL_PATH=/path/to/ecc

# Enable debug logging
export ECC_DEBUG=true
```

No additional config file is needed. ECC detection is automatic via `lib/ecc-detector.ts`.

---

## Detection Method

The skill runs `tsx ./lib/ecc-detector.ts` at pre-flight. This script checks for:
1. ECC plugin installation (`~/.claude/agents/`)
2. Agent file count and names
3. ECC tooling availability (`npm list -g ecc-universal`)

Output is JSON `{installed: boolean, agents: string[], paths: {...}}`.

---

## Troubleshooting

### ECC Not Detected

**Symptom**: Skill reports "ECC not installed" but ECC is installed

**Solution**:
```bash
# Verify ECC agents directory
ls -la ~/.claude/agents/

# If empty, reinstall ECC minimal profile:
cd everything-claude-code
./install.sh --profile minimal --target claude
```

### Review takes too long

**Symptom**: Stage 6 parallel review is slow

**Solution**:
Stage 6 runs all review agents in parallel. If ECC has many agents, this can be slow. The SKILL.md specifies a 60-second timeout per agent, after which the pipeline proceeds without that agent's findings.

---

## Version History

### v2.3.0 (Current)
- Stage 5 Dependency Graph runs BEFORE ECC review — so dependency clusters feed into ECC agent context
- No TypeScript API import path — ECC is detected via `tsx` script execution, not import
- Architecture change: all API calls are script-backed, not model-generated

### v2.1.0
- ECC integration
- Automatic detection
- Graceful fallback
- Language-specific reviewers

---

## Support

- **ECC Issues**: https://github.com/affaan-m/everything-claude-code/issues
- **Skill Issues**: https://github.com/mtsocom2000/my-review-resolver/issues
