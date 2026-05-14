# Platform Compatibility

## Subagent Dependencies

**Status: ✅ Subagent-based for Stages 4, 5, 6, 9**

| Stage | Agent | Required | Fallback |
|-------|-------|----------|----------|
| 4 (Analyze) | `agents/analyzer.md` | Yes, for auto-analysis | Manual per-comment assessment |
| 5 (Dependency Graph) | `agents/dependency-analyzer.md` | Yes, for clustering | Flat sequential order |
| 6 (Parallel Review) | `agents/security.md`, `agents/performance.md`, `agents/quality.md` | Yes, for review insights | Skip review, proceed with Stage 4 analysis only |
| 9 (Final Review) | `agents/validator.md` | Yes, for verification | Manual verification by user |

If any subagent cannot be spawned (environment limitation), the model should:
1. Try ECC agents as replacement (for Stage 6)
2. Fall back to sequential execution (same logic, no parallelism)
3. If agents are completely unavailable, proceed without that stage's output and flag the gap to the user

## Tool Dependencies

| Tool | Stage | Fallback |
|------|-------|----------|
| `gh` CLI | 2, 3, 11 | MCP tools |
| `jq` | all script stages | grep/sed in some scripts |
| `bash 4+` | all script stages | None (scripts require bash) |

## Platform Support

| Platform | Skill Loading | Subagents | MCP Fallback | Notes |
|----------|--------------|-----------|--------------|-------|
| Claude Code | ✅ SKILL.md | ✅ Full support | ✅ Via MCP tools | Primary target |
| VS Code Copilot | ✅ AgentSkills | ⚠️ Limited (context fork) | ✅ Via Copilot MCP | Stage 5 may run sequentially |
| Cursor | ✅ AgentSkills | ⚠️ Limited | ❌ Check docs | Tested with ECC integration |
| OpenCode | ✅ AgentSkills | ⚠️ Custom plugin needed | ❌ | Requires manual config |

## Version Compatibility

| Skill version | Min Claude Code | Min Copilot | Notes |
|---------------|----------------|-------------|-------|
| v2.2.0 | 1.0+ | 1.0+ (agent skills) | MCP fallback requires MCP server configured |
| v2.1.0 | 1.0+ | N/A | ECC integration |
| v2.0.0 | 1.0+ | N/A | Initial subagent-based pipeline |
