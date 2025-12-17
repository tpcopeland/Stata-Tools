# tvtools .ado conceptual audit

## tvmerge.ado

### 1) File existence validation forces `.dta` suffix
When validating input datasets, the command unconditionally appends `.dta` before `confirm file` and `use` checks (lines 104–117). This causes valid calls such as `tvmerge data1.dta data2.dta, ...` or paths that already include the extension to fail because the code looks for `data1.dta.dta`. A better approach would respect the user-provided filename or strip a trailing `.dta` before the check. Example failure:
```
. tvmerge data1.dta data2.dta, id(id) start(s1 s2) stop(e1 e2) exposure(x1 x2)
file data1.dta.dta not found
```

### 2) Exposure list length can exceed dataset count with silent truncation
The option parsing enforces `exposure()` to be *at least* the number of datasets (line 223) instead of exactly matching. If the user supplies more names than datasets—e.g., attempting to specify multiple exposures per dataset—the extra names are ignored later when looping over datasets. That silently drops user intent and misaligns expectations. A stricter equality check would surface the mistake immediately.

### 3) Duplicate exposure names are rejected even when expected
A duplicate-name guard (lines 246–259) errors out whenever the same exposure variable name is repeated across datasets. In practice, datasets commonly use the same variable name (e.g., `exposure`) across time-split files, and users rely on `generate()`/`prefix()` to differentiate outputs. Under the current logic, `tvmerge ds1 ds2, exposure(exposure exposure) ...` aborts even though it is a valid layout. Allowing duplicates—or only rejecting duplicates when no renaming is requested—would prevent unnecessary failures.

## tvexpose.ado

### 1) Point-time carryforward silently collapses nearby assessments
When `pointtime` is paired with `carryforward(#)`, the code extends each point measurement forward before any overlap handling, then applies the default `merge(120)` gap rule (lines 129 and 719–730). Separate assessments that are ≤120 days apart after carryforward are therefore coalesced into one long exposure spell, even if the user intended discrete assessment windows. A user would need to explicitly set `merge(0)` (or a smaller number) to avoid this silent bridging.

### 2) Events on exposure start/stop boundaries are dropped
Intervals are split only when `date` satisfies `start < date < stop` (lines 341 and 361), meaning events that occur exactly on the start date or exactly on the stop date of an interval are ignored. In most survival setups, events on the entry boundary (t0) or on the final day of risk should be adjudicated carefully; here they never generate a split or a failure flag. Users expecting inclusive boundaries must adjust their interval definitions manually (e.g., shifting stop dates by +1) or risk undercounting boundary events.
