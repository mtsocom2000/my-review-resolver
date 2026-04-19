#!/usr/bin/env tsx
/**
 * ECC (Everything Claude Code) Detector
 * 
 * Detects if ECC is installed and provides agent invocation helpers.
 * This module is designed to be used by the pr-comment-fix skill.
 * 
 * Usage:
 *   import { detectECC, invokeECCReview } from './lib/ecc-detector';
 * 
 *   const ecc = detectECC();
 *   if (ecc.installed) {
 *     // Use ECC agents for parallel review
 *     const results = await invokeECCReview(diff, comment);
 *   } else {
 *     // Use fallback subagents
 *   }
 */

import { readFileSync, existsSync, readdirSync } from 'fs';
import { join } from 'path';

// ============================================================================
// Types
// ============================================================================

export interface ECCAgent {
  name: string;
  description: string;
  tools: string[];
  model: string;
  prompt: string;
  filePath: string;
}

export interface ECCRegistry {
  installed: boolean;
  installPath: string;
  agents: ECCAgent[];
  agentsByCategory: Record<string, ECCAgent[]>;
}

export interface ECCReviewResult {
  agent: string;
  status: 'success' | 'error';
  output: string;
  findings: Array<{
    severity: 'HIGH' | 'MEDIUM' | 'LOW';
    issue: string;
    suggestion: string;
  }>;
}

// ============================================================================
// Detection
// ============================================================================

/**
 * Detect if ECC is installed
 */
export function detectECC(): ECCRegistry {
  const registry: ECCRegistry = {
    installed: false,
    installPath: '',
    agents: [],
    agentsByCategory: {}
  };

  // Check install state
  const installStatePath = join(process.env.HOME || '~', '.claude/ecc/install-state.json');
  if (!existsSync(installStatePath)) {
    return registry;
  }

  // Check agents directory
  const agentsDir = join(process.env.HOME || '~', '.claude/agents');
  if (!existsSync(agentsDir)) {
    return registry;
  }

  registry.installed = true;
  registry.installPath = join(process.env.HOME || '~', '.claude');

  // Load all agents
  try {
    const agentFiles = readdirSync(agentsDir).filter(f => f.endsWith('.md'));
    
    for (const file of agentFiles) {
      const agent = parseAgentFile(join(agentsDir, file));
      if (agent) {
        registry.agents.push(agent);
        
        // Categorize
        const category = categorizeAgent(agent);
        if (!registry.agentsByCategory[category]) {
          registry.agentsByCategory[category] = [];
        }
        registry.agentsByCategory[category].push(agent);
      }
    }
  } catch (err) {
    console.error('Error loading ECC agents:', err);
  }

  return registry;
}

/**
 * Parse ECC agent markdown file
 */
function parseAgentFile(filePath: string): ECCAgent | null {
  try {
    const content = readFileSync(filePath, 'utf-8');
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
    
    if (!frontmatterMatch) return null;

    const [, frontmatterStr, prompt] = frontmatterMatch;
    
    const nameMatch = frontmatterStr.match(/^name:\s*(.+)$/m);
    const descMatch = frontmatterStr.match(/^description:\s*(.+)$/m);
    const toolsMatch = frontmatterStr.match(/^tools:\s*\[(.+)\]/m);
    const modelMatch = frontmatterStr.match(/^model:\s*(.+)$/m);

    return {
      name: nameMatch?.[1]?.trim() || 'unknown',
      description: descMatch?.[1]?.trim() || '',
      tools: toolsMatch?.[1]?.split(',').map(t => t.trim().replace(/"/g, '')) || [],
      model: modelMatch?.[1]?.trim() || 'sonnet',
      prompt: prompt.trim(),
      filePath
    };
  } catch (err) {
    return null;
  }
}

/**
 * Categorize agent by name/purpose
 */
function categorizeAgent(agent: ECCAgent): string {
  const name = agent.name.toLowerCase();
  
  if (name.includes('review')) return 'review';
  if (name.includes('build') || name.includes('resolver')) return 'debug';
  if (name.includes('architect')) return 'architecture';
  if (name.includes('test')) return 'testing';
  if (name.includes('doc')) return 'documentation';
  if (name.includes('security')) return 'security';
  if (name.includes('performance')) return 'performance';
  
  return 'general';
}

// ============================================================================
// Review Agents
// ============================================================================

/**
 * Get review agents for parallel review
 */
export function getReviewAgents(): ECCAgent[] {
  const registry = detectECC();
  return registry.agentsByCategory['review'] || [];
}

/**
 * Get security review agent
 */
export function getSecurityAgent(): ECCAgent | null {
  const registry = detectECC();
  return registry.agents.find(a => a.name === 'security-reviewer') || null;
}

/**
 * Get performance review agent
 */
export function getPerformanceAgent(): ECCAgent | null {
  const registry = detectECC();
  return registry.agents.find(a => a.name === 'performance-optimizer') || null;
}

/**
 * Get code quality agent
 */
export function getQualityAgent(): ECCAgent | null {
  const registry = detectECC();
  return registry.agents.find(a => a.name === 'code-reviewer') || null;
}

// ============================================================================
// Agent Invocation (for subagent systems)
// ============================================================================

/**
 * Build prompt for ECC agent invocation
 * 
 * This is designed to be used with OpenClaw sessions_spawn or similar
 */
export function buildAgentPrompt(
  agent: ECCAgent,
  task: string,
  context?: {
    diff?: string;
    comment?: string;
    filePath?: string;
    language?: string;
  }
): string {
  const sections: string[] = [];

  // Agent identity
  sections.push(`
# ECC Agent: ${agent.name}

${agent.description}

## Your Tools
You have access to: ${agent.tools.join(', ')}

## Your Instructions
${agent.prompt}
`.trim());

  // Context
  if (context) {
    const contextParts: string[] = [];
    
    if (context.diff) {
      contextParts.push(`
## Code Diff
\`\`\`diff
${context.diff}
\`\`\``);
    }
    
    if (context.comment) {
      contextParts.push(`
## PR Comment to Address
"""
${context.comment}
"""`);
    }
    
    if (context.filePath) {
      contextParts.push(`
## File Path
${context.filePath}`);
    }
    
    if (context.language) {
      contextParts.push(`
## Language
${context.language}`);
    }
    
    if (contextParts.length > 0) {
      sections.push(contextParts.join('\n'));
    }
  }

  // Task
  sections.push(`
## Current Task

${task}

## Execution

Follow your instructions above to complete the task.
Use your available tools effectively.
Report findings in a structured format with severity levels.
`.trim());

  return sections.join('\n\n');
}

// ============================================================================
// Parallel Review (for pr-comment-fix skill)
// ============================================================================

export interface ParallelReviewInput {
  diff: string;
  comment: string;
  filePath: string;
  language?: string;
}

/**
 * Execute parallel review using ECC agents
 * 
 * Returns results from multiple agents for comprehensive analysis
 */
export function buildParallelReviewTasks(input: ParallelReviewInput): Array<{
  agentName: string;
  prompt: string;
  category: string;
}> {
  const tasks: Array<{ agentName: string; prompt: string; category: string }> = [];
  
  // Security review
  const securityAgent = getSecurityAgent();
  if (securityAgent) {
    tasks.push({
      agentName: 'security-reviewer',
      category: 'security',
      prompt: buildAgentPrompt(securityAgent, `
Analyze this code change for security vulnerabilities:

1. Check for:
   - SQL injection
   - XSS vulnerabilities
   - Hardcoded secrets
   - Authentication/authorization issues
   - Input validation problems

2. Rate severity: HIGH/MEDIUM/LOW

3. Provide specific fix suggestions
`, {
        diff: input.diff,
        comment: input.comment,
        filePath: input.filePath,
        language: input.language
      })
    });
  }
  
  // Performance review
  const performanceAgent = getPerformanceAgent();
  if (performanceAgent) {
    tasks.push({
      agentName: 'performance-optimizer',
      category: 'performance',
      prompt: buildAgentPrompt(performanceAgent, `
Analyze this code change for performance issues:

1. Check for:
   - N+1 queries
   - Inefficient loops
   - Memory leaks
   - Unnecessary computations
   - Caching opportunities

2. Rate impact: HIGH/MEDIUM/LOW

3. Provide optimization suggestions
`, {
        diff: input.diff,
        comment: input.comment,
        filePath: input.filePath,
        language: input.language
      })
    });
  }
  
  // Code quality review
  const qualityAgent = getQualityAgent();
  if (qualityAgent) {
    tasks.push({
      agentName: 'code-reviewer',
      category: 'quality',
      prompt: buildAgentPrompt(qualityAgent, `
Analyze this code change for quality issues:

1. Check for:
   - Code style violations
   - Naming issues
   - Function complexity
   - Missing tests
   - Documentation gaps

2. Rate importance: HIGH/MEDIUM/LOW

3. Provide improvement suggestions
`, {
        diff: input.diff,
        comment: input.comment,
        filePath: input.filePath,
        language: input.language
      })
    });
  }
  
  return tasks;
}

// ============================================================================
// CLI Entry Point (for testing)
// ============================================================================

if (require.main === module) {
  console.log('=== ECC Detector ===\n');
  
  const registry = detectECC();
  
  if (!registry.installed) {
    console.log('❌ ECC not installed');
    console.log('\nInstall with:');
    console.log('  git clone https://github.com/affaan-m/everything-claude-code');
    console.log('  cd everything-claude-code');
    console.log('  ./install.sh --profile full');
    process.exit(0);
  }
  
  console.log('✅ ECC installed');
  console.log(`   Path: ${registry.installPath}`);
  console.log(`   Agents: ${registry.agents.length}`);
  console.log('');
  
  console.log('Agents by category:');
  for (const [category, agents] of Object.entries(registry.agentsByCategory)) {
    console.log(`\n  ${category}:`);
    for (const agent of agents.slice(0, 5)) {
      console.log(`    - ${agent.name}: ${agent.description.slice(0, 60)}...`);
    }
    if (agents.length > 5) {
      console.log(`    ... and ${agents.length - 5} more`);
    }
  }
  
  console.log('\n\n=== Review Agents ===');
  const reviewAgents = getReviewAgents();
  console.log(`Found ${reviewAgents.length} review agents:`);
  for (const agent of reviewAgents) {
    console.log(`  - ${agent.name} (${agent.model})`);
  }
}
