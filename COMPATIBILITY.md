# Platform Compatibility

## Subagent Dependencies

**Current Status: ✅ NO subagent dependencies**

The PR Comment Fix skill v2.1 does **NOT** use subagents or parallel task execution. All operations are performed by the main agent.

### Why No Subagents?

1. **Simplicity** - Easier to install and debug
2. **Compatibility** - Works on all platforms without special configuration
3. **User Control** - All decisions go through user confirmations
4. **Traceability** - Clear execution flow, easy to follow logs

### Future Enhancement (Optional)

If needed, we could add optional subagent support for:

```markdown
Stage 5: Parallel Review (Optional)
├── Analyzer Agent (subagent)
├── Security Agent (subagent)
├── Performance Agent (subagent)
└── Quality Agent (subagent)
```

This would require:
- Platform support for subagents (Claude Code ✅, Cursor ⚠️, VSCode ❌)
- Additional configuration
- More complex installation

**Current Decision:** Keep it simple, no subagent dependencies.

---

## Platform Support Matrix

| Platform | Support | Install Method (Linux/macOS) | Install Method (Windows) | Notes |
|----------|---------|------------------------------|--------------------------|-------|
| **Claude Code** | ✅ Full | `./install.sh --claude` | `.\install.ps1 -Target claude` | Native skill support |
| **Cursor** | ✅ Full | `./install.sh --cursor` | `.\install.ps1 -Target cursor` | Via skills directory |
| **VSCode Copilot** | ✅ Basic | `./install.sh --vscode` | `.\install.ps1 -Target vscode` | SKILL.md only |
| **OpenCode** | ✅ Full | `./install.sh --opencode` | `.\install.ps1 -Target opencode` | Native skill support |
| **Local Project** | ✅ Full | `./install.sh --local` | `.\install.ps1 -Target local` | Project-specific |

---

## Feature Availability

| Feature | Claude Code | Cursor | VSCode | OpenCode |
|---------|-------------|--------|--------|----------|
| PR Info Logging | ✅ | ✅ | ✅ | ✅ |
| Branch Check | ✅ | ✅ | ✅ | ✅ |
| Comment Analysis | ✅ | ✅ | ✅ | ✅ |
| Fix Confirmation | ✅ | ✅ | ✅ | ✅ |
| Push Confirmation | ✅ | ✅ | ✅ | ✅ |
| Reply Confirmation | ✅ | ✅ | ✅ | ✅ |
| Scripts (dryrun, etc.) | ✅ | ✅ | ❌ | ✅ |
| Agents (analyzer, etc.) | ✅ | ⚠️ | ❌ | ✅ |

**Legend:**
- ✅ Full support
- ⚠️ Partial support (may need configuration)
- ❌ Not supported

---

## Installation Requirements

### All Platforms
- Git (required)
- Bash shell (for install script)

### Optional
- GitHub CLI (`gh`) - For GitHub API
- GitLab CLI (`glab`) - For GitLab API
- Node.js (for future enhancements)

---

## Known Limitations

### VSCode Copilot
- Only loads SKILL.md (no scripts or agents)
- Manual execution required
- No automatic skill loading

### Cursor
- Agent files may not auto-load
- Scripts need manual execution
- Best used via chat interface

### Claude Code & OpenCode
- Full feature support
- Automatic skill loading
- Scripts and agents fully functional

---

## Recommendations

**For Development:**
- Use Claude Code or OpenCode for full features
- Install globally: `./install.sh --all`

**For Production:**
- Install to local project: `./install.sh --local`
- Version control the `.claude/skills/` directory

**For Testing:**
- Use dryrun script: `./scripts/dryrun.sh`
- Test with real PR after dryrun passes

---

## Troubleshooting by Platform

### Claude Code
```bash
# Check skill loaded
/skill list

# Reload if needed
/skill reload pr-comment-fix
```

### Cursor
```bash
# Check skills directory
ls ~/.cursor/skills/pr-comment-fix

# Restart Cursor if not showing
```

### VSCode
```bash
# Check Copilot chat
# Type: @pr-comment-fix

# If not found, check:
ls ~/.vscode/copilot/skills/pr-comment-fix
```

### OpenCode
```bash
# List skills
/skill list

# Load skill
/skill load pr-comment-fix
```
