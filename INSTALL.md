# PR Comment Fix Skill — Installation Guide

## Quick Install

```bash
git clone https://github.com/mtsocom2000/my-review-resolver.git
cd my-review-resolver
./install.sh --auto
```

---

## Requirements

### Required
- `bash` 4+
- `jq` (for JSON processing in scripts)
- Git

### Required for primary mode
- `gh` CLI (authenticated) — for fetching comments and posting replies
  - Install: `brew install gh` / `sudo apt install gh` / https://cli.github.com/
  - Authenticate: `gh auth login`

### Optional fallback
- MCP tools (GitHub MCP server) — used when `gh` CLI is not available
  - Configure your AI agent's MCP settings to include a GitHub MCP server

### Optional enhancement
- ECC (Everything Claude Code) — enables specialized parallel review agents
  - Install: `git clone https://github.com/affaan-m/everything-claude-code.git && cd everything-claude-code && npm install && ./install.sh --profile minimal`

---

## Manual Install (per platform)

### Claude Code

```bash
# Project-level (recommended)
mkdir -p .claude/skills/pr-comment-fix
cp SKILL.md lib/ecc-detector.ts .claude/skills/pr-comment-fix/
cp -r agents scripts references tests .claude/skills/pr-comment-fix/

# Or user-level
mkdir -p ~/.claude/skills/pr-comment-fix
cp -r * ~/.claude/skills/pr-comment-fix/
```

### VS Code Copilot

```bash
# Project-level
mkdir -p .github/skills/pr-comment-fix
cp -r * .github/skills/pr-comment-fix/

# Or user-level
mkdir -p ~/.copilot/skills/pr-comment-fix
cp -r * ~/.copilot/skills/pr-comment-fix/
```

### Cursor

```bash
mkdir -p ~/.cursor/skills/pr-comment-fix
cp -r * ~/.cursor/skills/pr-comment-fix/
```

### OpenCode

```bash
mkdir -p ~/.opencode/skills/pr-comment-fix
cp -r * ~/.opencode/skills/pr-comment-fix/
```

---

## Verify Installation

```bash
# Check all scripts are executable
ls -la scripts/*.sh

# Test with dryrun
DRY_RUN=true bash scripts/check-branch.sh https://github.com/example/repo/pull/1
# Expected: JSON output, no actual git operations

# Check ECC detector (optional)
npx tsx lib/ecc-detector.ts
```

---

## After Install

The skill auto-triggers when you provide a PR URL. To test:
- In Claude Code: paste `https://github.com/owner/repo/pull/42`
- In VS Code Copilot: type `/pr-comment-fix https://github.com/owner/repo/pull/42`

---

## Uninstall

```bash
# Remove from all platforms
./install.sh --uninstall

# Or manually
rm -rf ~/.claude/skills/pr-comment-fix
rm -rf ~/.github/skills/pr-comment-fix
rm -rf ~/.copilot/skills/pr-comment-fix
rm -rf ~/.cursor/skills/pr-comment-fix
```

---

## Version

Current: **2.3.0**

See [README.md](README.md) for changelog.
