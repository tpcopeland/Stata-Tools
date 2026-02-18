# Review Workflow

## Step-by-Step Process

### 1. Load Context
```
1. READ the code file
2. IDENTIFY file type (.ado command, .do script, .sthlp help)
3. CHECK for related files (help file, test file, package file)
4. Note the package name and current version
```

### 2. Structural Check (Lines 1-20)
- [ ] Version line: `*! command Version X.Y.Z  YYYY/MM/DD`
- [ ] Description line present
- [ ] Author line present
- [ ] Program class declared
- [ ] `program define command, rclass/eclass`
- [ ] `version 16.0` or `version 18.0`
- [ ] `set varabbrev off`

### 3. Sample Handling
- [ ] `syntax` statement present
- [ ] `marksample touse` if syntax has `[if] [in]`
- [ ] `markout` for option variables
- [ ] `quietly count if \`touse'` with check

### 4. Macro Safety
- [ ] All macro references use `` `name' `` format
- [ ] No macro names > 31 characters
- [ ] No spaces inside backticks
- [ ] No unclosed quotes

### 5. Tempvars
- [ ] All tempvars declared with `tempvar`
- [ ] All tempvar references use backticks
- [ ] No unnecessary `drop \`tempvar'`

### 6. Error Handling
- [ ] All `capture` followed by `_rc` check
- [ ] `_rc` saved immediately if subsequent commands run
- [ ] Clear error messages with codes

### 7. Returns & Documentation
- [ ] Return type matches program declaration
- [ ] All documented returns actually set
- [ ] Help file matches actual options
- [ ] Examples are correct

### 8. Version Consistency
Run: `.claude/scripts/check-versions.sh [package]`
