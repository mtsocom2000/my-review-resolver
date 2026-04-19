# PR Comment Fix Skill - Installation Guide

## Quick Install

### Automatic (Recommended)

```bash
# Clone the repository
git clone https://github.com/mtsocom2000/my-review-resolver.git
cd my-review-resolver/skills/pr-comment-fix

# Run auto-detect installer
./install.sh --auto

# Or install to all platforms
./install.sh --all
```

### Manual

**Claude Code:**
```bash
cp -r pr-comment-fix ~/.claude/skills/
```

**Cursor:**
```bash
cp -r pr-comment-fix ~/.cursor/skills/
```

**VSCode Copilot:**
```bash
cp -r pr-comment-fix ~/.vscode/copilot/skills/
```

**OpenCode:**
```bash
cp -r pr-comment-fix ~/.opencode/skills/
```

**Local Project:**
```bash
cp -r pr-comment-fix ./.claude/skills/
```

---

## Platform-Specific Instructions

### Claude Code

After installation:

```bash
# Load the skill
/skill load pr-comment-fix

# Or use directly
Help me fix PR comments on https://github.com/owner/repo/pull/1
```

### Cursor

1. Open Cursor Settings
2. Go to "Skills" or "Plugins"
3. Click "Add Skill"
4. Select the `pr-comment-fix` folder

Usage:
```
@pr-comment-fix Fix comments on https://github.com/owner/repo/pull/1
```

### VSCode (GitHub Copilot)

1. Open VSCode
2. Open Copilot Chat
3. Type `@pr-comment-fix` to use

### OpenCode

```bash
# Load skill
/skill load pr-comment-fix

# Or use command
/fix-pr https://github.com/owner/repo/pull/1
```

---

## Requirements

### Required
- Git (for branch operations)

### Optional
- GitHub CLI (`gh`) - For GitHub API access
- GitLab CLI (`glab`) - For GitLab API access

### Check Requirements

```bash
# Check if gh is installed
gh --version

# If not installed:
# macOS
brew install gh

# Linux
sudo apt install gh

# Or download from https://cli.github.com/
```

---

## Configuration

### GitHub Token (Optional)

For better API access, set environment variable:

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

Or add to `~/.config/pr-comment-fix/config`:

```bash
GITHUB_TOKEN=ghp_your_token_here
```

### GitLab Token (Optional)

```bash
export GITLAB_TOKEN=glpat_your_token_here
```

---

## Uninstall

```bash
# Run uninstaller
./install.sh --uninstall

# Or manually remove
rm -rf ~/.claude/skills/pr-comment-fix
rm -rf ~/.cursor/skills/pr-comment-fix
rm -rf ~/.vscode/copilot/skills/pr-comment-fix
rm -rf ~/.opencode/skills/pr-comment-fix
```

---

## Verify Installation

```bash
# Test with dryrun
./scripts/dryrun.sh

# Should output:
# ✓ All tests passed!
```

---

## Troubleshooting

### Skill not loading

1. Check file permissions:
   ```bash
   chmod +x install.sh scripts/*.sh
   ```

2. Verify SKILL.md exists:
   ```bash
   ls -la ~/.claude/skills/pr-comment-fix/SKILL.md
   ```

3. Restart your IDE/terminal

### API rate limits

If you hit GitHub API rate limits:
- Authenticate with `gh auth login`
- Or set `GITHUB_TOKEN` environment variable

### Branch sync issues

If branch sync fails:
```bash
# Manually sync
cd your-project
git fetch origin
git checkout your-branch
git pull origin your-branch
```

---

## Version

Current: **2.1.0**

See [SKILL.md](SKILL.md) for version history.

---

## Support

- **Issues:** https://github.com/mtsocom2000/my-review-resolver/issues
- **Discussions:** https://github.com/mtsocom2000/my-review-resolver/discussions
