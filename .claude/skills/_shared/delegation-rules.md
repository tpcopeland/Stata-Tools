# Skill Delegation Rules

## Mandatory Workflow Chain

```
/develop → /reviewer → /test → /package
```

1. After writing or modifying .ado code, ALWAYS invoke `/reviewer`
2. After review approval, write tests with `/test`
3. Run tests and validate structure with `/package`

## Delegation Matrix

| From | To | When |
|------|----|----|
| `/develop` | `/reviewer` | After writing code (MANDATORY) |
| `/develop` | `/test` | After review approval |
| `/reviewer` | `/develop` | When fixes are needed |
| `/reviewer` | `/test` | After review approval |
| `/test` | `/develop` | When tests reveal bugs |
| `/test` | `/package` | To run tests |
| `/package` | `/develop` | When tests fail |
| `/package` | `/reviewer` | When code needs review |

## Which Skill for Which Task

| Task | Skill |
|------|-------|
| Create new .ado command | `/develop` |
| Add feature to existing command | `/develop` |
| Fix bug in .ado file | `/develop` |
| Generate code from requirements | `/develop` |
| Review code for bugs/style | `/reviewer` |
| Audit .ado file systematically | `/reviewer` |
| Score code quality | `/reviewer` |
| Write functional tests | `/test` |
| Write validation/correctness tests | `/test` |
| Run tests and parse results | `/package` |
| Validate package structure | `/package` |
| Check version consistency | `/package` |
