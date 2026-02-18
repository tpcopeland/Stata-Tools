# Skills Directory

Skills are "expertise hats" that provide domain-specific workflows, quality gates, and output formats for Stata package development.

## Critical Policy: No Subagents

**NEVER use the Task tool to spawn subagents.** All work is done directly by the main Claude session. Skills load instructions into context via the `Skill` tool.

## Available Skills (4)

| Skill | Slash Command | Purpose |
|-------|---------------|---------|
| `develop` | `/develop` | Create/modify .ado commands, add features, fix bugs, generate code |
| `reviewer` | `/reviewer` | Code review, audit, pattern detection, quality scoring |
| `test` | `/test` | Write functional tests and validation tests |
| `package` | `/package` | Run tests, validate structure, parse logs, check coverage |

## Mandatory Workflow

```
/develop → /reviewer → /test → /package
```

After writing .ado code, you MUST run `/reviewer`. After review approval, write tests with `/test` and run them with `/package`.

## Invoking Skills

### Method 1: Slash Commands (User)
```
/develop
/reviewer
/test
/package
```

### Method 2: Skill Tool (Claude)
```
Skill(skill="develop")
Skill(skill="reviewer")
```

### Method 3: Natural Language (Automatic)
The `user-prompt-skill-router.sh` hook detects keywords and suggests skills.

## Skill File Structure

```
.claude/skills/<skill>/
├── SKILL.md              # Core instructions (<500 lines)
├── workflows/            # Detailed workflows
├── references/           # Reference materials
└── anti-patterns.md      # Common mistakes (optional)
```

### Shared Resources

```
.claude/skills/_shared/
├── context-loading.md    # MCP-first context loading guidelines
└── delegation-rules.md   # Which skill delegates to which
```

## Tool Allocation

| Skill | Read | Write | Edit | Grep | Glob | Bash |
|-------|:----:|:-----:|:----:|:----:|:----:|:----:|
| develop | Y | Y | Y | Y | Y | Y |
| review | Y | Y | Y | Y | Y | |
| test | Y | Y | Y | Y | Y | Y |
| package | Y | Y | Y | Y | Y | Y |

**Note:** Task tool is NEVER allowed for any skill.

## When to Use Each Skill

| Task | Recommended Skill |
|------|-------------------|
| Create a new .ado command | `/develop` |
| Add a feature to existing command | `/develop` |
| Fix a bug in .ado file | `/develop` |
| Generate code from requirements | `/develop` |
| Review code for bugs/style | `/reviewer` |
| Audit .ado file | `/reviewer` |
| Write functional tests | `/test` |
| Write validation tests | `/test` |
| Run tests and check results | `/package` |
| Validate package structure | `/package` |
