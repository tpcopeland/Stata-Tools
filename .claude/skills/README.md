# Skills Directory

This directory contains all skills that Claude uses for Stata package development tasks. Skills are "expertise hats" that provide domain-specific workflows, quality gates, and output formats.

**Note:** In Claude Code, commands and skills have been merged. All skills can be invoked with `/skill-name` (e.g., `/stata-develop`).

## Critical Policy: No Subagents

**NEVER use the Task tool to spawn subagents when invoking skills.** All work must be done directly by the main Claude session.

- Skills are NOT subagents - they are "expertise hats" that provide context
- Use `WebSearch` and `WebFetch` directly for web searches
- Use `Glob`, `Grep`, and `Read` directly for codebase exploration
- Invoke skills via the `Skill` tool, which loads instructions into context

**Why:** Subagents hallucinate, produce inconsistent results, and waste tokens.

## Available Skills

### Workflow Skills (invoke with /skill-name)

| Skill | Purpose | Invoke When |
|-------|---------|-------------|
| `stata-develop` | Development guidance for creating/modifying commands | Creating new .ado files, adding features, fixing bugs |
| `stata-test` | Functional testing workflow | Writing `test_*.do` files that verify commands run |
| `stata-validate` | Known-answer validation guidance | Writing `validation_*.do` files that verify correctness |
| `stata-audit` | Code review and error detection | Auditing .ado files, finding bugs |

### Expertise Skills (auto-suggested by hooks)

| Skill | Purpose | Invoke When |
|-------|---------|-------------|
| `code-reviewer` | Review Stata package code for bugs and style | Editing/reviewing .ado or .do files |
| `stata-code-generator` | Generate new commands following conventions | Generating code from requirements |
| `package-tester` | Run tests and validate package structure | Testing packages, parsing results |

## Invoking Skills

### Method 1: Slash Commands (User)
Users can invoke any skill directly with `/skill-name`:
```
/stata-develop
/stata-test
/stata-validate
/stata-audit
/code-reviewer
/package-tester
```

### Method 2: Skill Tool (Claude)
Claude invokes skills using the `Skill` tool:
```
Skill(skill="stata-develop")
Skill(skill="code-reviewer")
```

### Method 3: Natural Language (Automatic)
The `user-prompt-skill-router.sh` hook detects relevant keywords and suggests skills:
```
"Review the tvexpose.ado file" -> suggests code-reviewer
"Run tests for the package" -> suggests package-tester
"Create a new command" -> suggests stata-code-generator
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
2. **Invocation**: User types `/name` or Claude calls `Skill(skill="name")`
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
| stata-develop | Y | Y | Y | Y | Y | Y |
| stata-test | Y | Y | Y | Y | Y | Y |
| stata-validate | Y | Y | Y | Y | Y | Y |
| stata-audit | Y | Y | Y | Y | Y | |
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
stata-develop
├── delegates to -> code-reviewer (for validation)
├── delegates to -> stata-test (for writing tests)
└── delegates to -> stata-validate (for correctness tests)

stata-code-generator
├── delegates to -> code-reviewer (for validation)
└── references -> existing .ado files (for patterns)

code-reviewer
├── delegates to -> package-tester (for running tests after fixes)
└── references -> stata-common-errors.md (for known patterns)

package-tester
├── delegates to -> code-reviewer (if tests fail)
└── creates -> development logs (if novel errors)

stata-audit
├── delegates to -> stata-develop (for implementing fixes)
└── delegates to -> package-tester (for verification)
```

## Skill Categories

### When to Use Each Skill

| Task | Recommended Skill |
|------|-------------------|
| Create a new .ado command | `/stata-develop` |
| Add a feature to existing command | `/stata-develop` |
| Fix a bug in .ado file | `/stata-develop` |
| Write functional tests | `/stata-test` |
| Write correctness validation tests | `/stata-validate` |
| Review code for bugs/style | `/stata-audit` or `/code-reviewer` |
| Generate code from requirements | `/stata-code-generator` |
| Run tests and check results | `/package-tester` |
