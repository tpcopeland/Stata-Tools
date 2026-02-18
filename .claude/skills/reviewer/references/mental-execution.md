# Mental Execution Methodology

## When to Use
When Stata is unavailable or for complex code paths that need careful tracing.

## Trace Template

```
FILE: command.ado
TRACE: [normal|edge case|error path]
INPUT: [specific command and data state]

Step | Line | Code                     | Variables/State
-----|------|--------------------------|----------------
1    | 12   | syntax varlist...        | varlist = ...
2    | 14   | marksample touse         | touse created
...

RESULT: [success|failure with reason]
FINDING: [issue description or "clean"]
```

## Checklist

1. **Parse syntax** - What values do local macros hold?
2. **Check marksample** - What observations are marked?
3. **Trace loops** - What happens in each iteration?
4. **Verify conditions** - Do if/else branches go the right way?
5. **Check returns** - What values are stored?

## Variable Lifecycle Tracking

```
VARIABLE LIFECYCLE: varname
===========================
Created:     Line 45: tempvar varname
Initialized: Line 46: gen `varname' = 0
Modified:    Line 50: replace `varname' = x if condition
Used:        Line 60: summarize `varname'
Destroyed:   (auto at program end - tempvar)
STATUS: OK - properly managed
```

## Issues to Detect
1. Used before initialization
2. Modified after last use (dead code)
3. Never used
4. Escaped scope (tempvar referenced outside program)
5. Leaked resource (frame/file not cleaned up)
