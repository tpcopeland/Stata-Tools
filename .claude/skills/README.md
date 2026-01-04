# Skills Directory

This directory contains specialized skills that Claude invokes to handle Stata package development tasks. Skills are "expertise hats" that provide domain-specific workflows, quality gates, and output formats.

## Critical Policy: No Subagents

**NEVER use the Task tool to spawn subagents when invoking skills.** All work must be done directly by the main Claude session.

- Skills are NOT subagents - they are "expertise hats" that provide context
- Use `WebSearch` and `WebFetch` directly for web searches
- Use `Glob`, `Grep`, and `Read` directly for codebase exploration
- Invoke skills via the `Skill` tool, which loads instructions into context

**Why:** Subagents hallucinate, produce inconsistent results, and waste tokens.

## Available Skills

| Skill | Purpose | Invoke When |
|-------|---------|-------------|
| `code-reviewer` | Review Stata package code for bugs and style | Editing/reviewing .ado or .do files |
| `stata-code-generator` | Generate new commands following conventions | Creating new .ado files |
| `package-tester` | Run tests and validate package structure | Testing packages |

## Invoking Skills

### Method 1: Slash Commands (User)
Users can invoke skills directly with `/skill-name`:
```
/code-reviewer
/package-tester
```

### Method 2: Skill Tool (Claude)
Claude invokes skills using the `Skill` tool:
```
Skill(skill="code-reviewer")
Skill(skill="package-tester")
```

### Method 3: Natural Language (Automatic)
The `user-prompt-skill-router.sh` hook detects relevant keywords and suggests skills:
```
"Review the tvexpose.ado file" -> suggests code-reviewer
"Run tests for the package" -> suggests package-tester
```

## Skill File Structure

Each skill follows this structure:

```
.claude/skills/<skill-name>/
└── SKILL.md          # Skill definition with YAML frontmatter
```

### YAML Frontmatter Format

```yaml
---
name: skill-name
description: Brief description (shown in skill listings)
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---
```

## Skill Workflow

1. **Detection**: User prompt or file context suggests a skill
2. **Invocation**: Claude calls `Skill(skill="name")` or user types `/name`
3. **Activation**: Skill instructions are loaded into context
4. **Execution**: Claude follows skill's workflows and quality gates
5. **Output**: Results formatted per skill's output template

## Adding New Skills

1. Create directory: `.claude/skills/<skill-name>/`
2. Create `SKILL.md` with YAML frontmatter and instructions
3. Follow the established pattern from existing skills
4. Update this README with the new skill
5. Add patterns to `.claude/scripts/user-prompt-skill-router.sh`

## Tool Allocation by Skill

| Skill | Read | Write | Edit | Grep | Glob | Bash |
|-------|:----:|:-----:|:----:|:----:|:----:|:----:|
| code-reviewer | Y | Y | Y | Y | Y | |
| stata-code-generator | Y | Y | Y | Y | Y | Y |
| package-tester | Y | Y | Y | Y | Y | Y |

**Note:** Task tool is NEVER allowed for any skill.

## Quality Gates

All skills that produce artifacts include:
- Checklists for completeness
- Domain scoring (target: 90%+)
- Anti-patterns to avoid
- Output format templates

## Skill Dependencies

Skills can delegate to each other for specialized tasks:

```
code-reviewer
├── delegates to -> package-tester (for running tests after fixes)
└── references -> stata-common-errors.md (for known patterns)

stata-code-generator
├── delegates to -> code-reviewer (for validation)
└── references -> existing .ado files (for patterns)

package-tester
├── delegates to -> code-reviewer (if tests fail)
└── creates -> development logs (if novel errors)
```

## Relationship to Slash Commands

The `.claude/commands/` directory contains slash commands (e.g., `/stata-develop`). These provide task-specific guidance and can work alongside skills:

| Commands | Skills |
|----------|--------|
| Invoked explicitly by user | Auto-suggested by hooks |
| Focus on workflow guidance | Focus on expertise/patterns |
| `/stata-develop`, `/stata-audit` | `code-reviewer`, `package-tester` |
