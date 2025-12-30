# Stata Command Development Skill

**Trigger**: Use when creating a new Stata .ado command, adding features to existing commands, or fixing bugs in .ado files.

---

## Quick Reference

### Required Files for a New Command

```
mycommand/
├── mycommand.ado       # Main command (use _templates/TEMPLATE.ado)
├── mycommand.sthlp     # Help file (use _templates/TEMPLATE.sthlp)
├── mycommand.pkg       # Package metadata (use _templates/TEMPLATE.pkg)
├── stata.toc           # Table of contents (create: v 3 + package line)
├── mycommand.dlg       # Dialog (optional, use _templates/TEMPLATE.dlg)
└── README.md           # Documentation (use _templates/TEMPLATE_README.md)
```

### Scaffolding a New Command

Run: `.claude/scripts/scaffold-command.sh mycommand "Brief description"`

Or manually:
1. Copy templates from `_templates/` to new package folder
2. Replace all `TEMPLATE` with command name
3. Update dates (YYYY/MM/DD in .ado, DDmonYYYY in .sthlp, YYYYMMDD in .pkg)
4. Fill in descriptions and author info

---

## Mandatory Code Structure

Every .ado file MUST have:

```stata
*! mycommand Version 1.0.0  2025/01/15
*! Brief description
*! Author: Name
*! Program class: rclass

/* Block comment with syntax documentation */

program define mycommand, rclass
    version 18.0            // or 16.0 for compatibility
    set varabbrev off       // CRITICAL - prevents abbreviation bugs

    syntax ...              // Define syntax

    marksample touse        // Handle if/in conditions
    markout `touse' `optionvars'  // Include option variables

    quietly count if `touse'
    if r(N) == 0 error 2000  // Check for observations

    // ... main logic ...

    return scalar N = r(N)   // Return results
end
```

---

## Critical Error Patterns to Avoid

### 1. Macro Reference Errors (Most Common)
```stata
// WRONG - missing backticks
local myvar "price"
summarize myvar           // Tries to find literal "myvar"

// CORRECT
summarize `myvar'

// WRONG - macro name too long (>31 chars = silent truncation!)
local very_long_descriptive_name_one = 1
local very_long_descriptive_name_two = 2  // COLLISION!

// CORRECT - keep names ≤31 characters
local desc_name_one = 1
local desc_name_two = 2
```

### 2. Missing marksample/markout
```stata
// WRONG
syntax varlist [if] [in], BY(varname)
marksample touse
// Missing: markout `touse' `by'  <-- Option variables need markout!
```

### 3. Tempvar Without Backticks
```stata
// WRONG
tempvar mytemp
gen mytemp = price * 2    // Creates permanent "mytemp"!

// CORRECT
gen `mytemp' = price * 2
```

### 4. Unchecked capture
```stata
// WRONG
capture regress y x
predict yhat    // Fails if regression failed!

// CORRECT
capture regress y x
if _rc {
    display as error "Regression failed"
    exit _rc
}
predict yhat
```

### 5. _rc Gets Overwritten
```stata
// WRONG
capture noisily mycommand
display "Done"           // This succeeds, _rc = 0!
if _rc {                 // Always false
    handle_error
}

// CORRECT
capture noisily mycommand
local rc = _rc           // Save immediately
display "Done"
if `rc' {
    handle_error
}
```

---

## Validation Before Implementation

Before writing code, verify:

1. **Check existing patterns**: Look at similar commands in this repo
2. **Validate syntax design**: Required options use UPPERCASE abbreviation
3. **Plan return values**: Decide rclass/eclass/sclass
4. **Consider edge cases**: Empty data, single obs, all missing

---

## Version Management Checklist

When creating/updating a command, update ALL of these:

| File | Location | Format |
|------|----------|--------|
| .ado | Line 1 | `Version 1.0.0  YYYY/MM/DD` |
| .sthlp | Line 2 | `version 1.0.0  DDmonYYYY` |
| .pkg | Distribution-Date | `YYYYMMDD` |
| README.md | Version section | `1.0.0` |
| Root README.md | Package table | `1.0.0` |

**NEVER change `v 3` in .pkg or stata.toc** - this is file format version.

---

## After Implementation

1. Create functional test: `_testing/test_mycommand.do` (ask: "write tests for mycommand")
2. Create validation test: `_validation/validation_mycommand.do` (ask: "validate the command")
3. Run tests on VM with Stata 17/18
4. Add package to root README.md table

---

## Common Syntax Patterns

```stata
// Basic with required option
syntax varlist(numeric) [if] [in], REQuired(varname) [optional]

// With using clause
syntax using/ [, options]

// With weights
syntax varlist [aweight fweight] [if] [in]

// Constrained varlist
syntax varlist(numeric min=2 max=5) [if] [in]
```

---

## Help File (SMCL) Quick Reference

Key formatting:
- `{cmd:text}` - command style (bold blue)
- `{opt option}` - option style
- `{it:text}` - italic
- `{bf:text}` - bold
- `{p_end}` - end paragraph
- `{synopt:{opt name}}desc{p_end}` - option in synoptset table
- `{phang2}` - hanging indent for examples

---

## Template Locations

| Template | Purpose |
|----------|---------|
| `_templates/TEMPLATE.ado` | Main command with full structure |
| `_templates/TEMPLATE.sthlp` | Help file with all sections |
| `_templates/TEMPLATE.pkg` | Package metadata |
| `_templates/TEMPLATE.dlg` | Dialog with common controls |
| `_templates/TEMPLATE_README.md` | README with badges and formatting |
| `_templates/testing_TEMPLATE.do` | Functional test structure |
| `_templates/validation_TEMPLATE.do` | Validation test structure |

---

*For full error pattern catalog, see: `_testing/notes/ado_error_patterns.md`*
*For detailed development guide, see: `_guides/developing.md`*
