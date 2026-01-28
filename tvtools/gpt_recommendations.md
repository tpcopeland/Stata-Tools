# tvtools Review Recommendations (2025-02-14)

Scope:
- tvtools/*.ado and tvtools/_tvexpose_*.ado
- Related tests in _devkit/_testing/ and _devkit/_validation/ (spot-checked)

Notes:
- Static review only; no Stata execution in this pass.

## Test Execution (Stata batch)
- `/usr/local/stata17/stata-mp -b do _devkit/_testing/test_tvtools_comprehensive.do` → PASS (87/87). Log: `test_tvtools_comprehensive.log`.
- `/usr/local/stata17/stata-mp -b do _devkit/_validation/validation_tvtools_comprehensive.do` → PASS (16/16). Log: `validation_tvtools_comprehensive.log`.
- `/usr/local/stata17/stata-mp -b do _devkit/_testing/run_all_tests.do` → FAIL (1/17 files): `test_datefix.do` failed with r(602) because `datefix.sthlp` already exists. Log: `run_all_tests.log`.
- `/usr/local/stata17/stata-mp -b do run_all_validation.do` from `_devkit/_validation/` → PASS (3 suites). Log: `_devkit/_validation/run_all_validation.log`.
- Additional _devkit/_validation/ suites run individually: boundary_tests, test_boundary_edge, validation_tvtools_boundary, missing_data_tests, invariant_tests, time_varying_tests, stress_tests, integration_workflow_test, exhaustive_validation, reproducibility_tests, monte_carlo_validation, control_tests, helpfile_validation, validation_tvexpose, validation_tvevent, validation_tvmerge, validation_tvpipeline, validation_tvweight, validation_tvestimate → all PASS. Logs in `_devkit/_validation/*.log` (notably `_devkit/_validation/monte_carlo_validation.log` after extended runtime).

## High-priority Issues
- tvpipeline diagnose option always fails because tvdiagnose is called without any report flags (tvtools/tvpipeline.ado:320-328); tests expect this to pass (_devkit/_testing/test_tvpipeline.do:312-323). Best fix: call `tvdiagnose, ... all` (or a specific report option plus entry()/exit()) when diagnose is set, or make tvdiagnose default to `all` when no report option is provided.
- tvcalendar merge() option is computed but never used in the merge; merge() is effectively ignored (tvtools/tvcalendar.ado:78-102). Best fix: use `keepusing()` or subset `using` to merge() variables; exclude `datevar` by default when auto-selecting merge vars.
- tvweight uses logit for any 2-level exposure but does not enforce 0/1 coding; exposures coded 1/2 will be treated as all 1s by logit (tvtools/tvweight.ado:71-88,188-195). Best fix: require min==0 and max==1 for logit or recode to an indicator; otherwise auto-switch to mlogit or error with guidance.
- tvweight mlogit path uses `tempvar ps_`lev'` which breaks for non-integer/negative levels (invalid variable names) (tvtools/tvweight.ado:242-246). Best fix: use a single tempvar inside the loop and overwrite, or map levels to numeric indices and use safe names.
- tvdml accepts method(ridge|elasticnet) but never implements them and silently falls back to OLS/logit while reporting the chosen method (tvtools/tvdml.ado:68-171). Best fix: error if unsupported or implement ridge/elasticnet via `lasso` options.
- tvdml wraps lasso calls in `capture` and never checks _rc; failures leave residuals missing, making psi and SE undefined (tvtools/tvdml.ado:141-157,185-196). Best fix: check _rc and fall back to non-lasso or abort with a clear message.
- tvestimate divides by sum_aa without guarding against zero, producing missing/invalid psi (tvtools/tvestimate.ado:181-189). Best fix: if sum_aa==0, error with guidance (e.g., weak treatment variation) or return missing with a warning.
- tvestimate bootstrap variance uses `variance()` on a matrix that may contain missing values (failed reps), which returns missing SEs (tvtools/tvestimate.ado:203-247). Best fix: track valid reps, drop missing rows before variance, and warn if too few reps.
- tvdiagnose uses `distinct` (external SSC dependency) and renames variables to id/start/stop/study_entry/study_exit without collision handling (tvtools/tvdiagnose.ado:95-131). Best fix: replace `distinct` with built-in tagging, and rename with tempvars or `rename (old=new)` after safeguarding existing variable names.
- _tvexpose_overlaps assumes numeric id when formatting output; string IDs cause type mismatches (tvtools/_tvexpose_diagnose.ado:194-215). Best fix: use `string()` or conditional formatting for string IDs.

## Medium/Low-priority Issues
- tvbalance claims “pairwise comparisons” for multi-level exposures but compares reference vs all other levels combined (tvtools/tvbalance.ado:52-72). Best fix: update the message to reflect reference-vs-rest or implement true pairwise outputs.
- tvbalance uses hard-coded `__w2` variable name for ESS calculation; this can collide with user data (tvtools/tvbalance.ado:226-239). Best fix: use a tempvar instead of a fixed name.
- tvbalance love plot uses numeric y positions without labeling covariates; `ylabel(..., valuelabel)` has no labels to show (tvtools/tvbalance.ado:257-294). Best fix: encode covariate names to a labeled numeric variable (or use `labmask`) before plotting.
- tvplot sortby() accepts any variable name, but `egen mean()` fails for string variables (tvtools/tvplot.ado:131-138). Best fix: require numeric sortby or implement string-friendly alternatives.
- tvreport person-time uses stop-start rather than inclusive stop-start+1; inconsistent with tvexpose/tvevent interval handling (tvtools/tvreport.ado:69-72). Best fix: switch to `stop - start + 1` or explicitly document the convention.
- tvpipeline syntax treats START/STOP/EXPOSURE as strings, allowing invalid names to pass parse-time checks (tvtools/tvpipeline.ado:55-56). Best fix: change to `varname` so invalid names are caught early.

## Proposed Fixes with Before/After Snippets

### 1) tvpipeline diagnose should pass report flags
Before (tvtools/tvpipeline.ado:326-328):
```stata
capture noisily tvdiagnose, id(`id') start(start) stop(stop) exposure(tv_exposure)
```
After (choose one):
```stata
capture noisily tvdiagnose, id(`id') start(start) stop(stop) exposure(tv_exposure) all
```
or, if you want coverage detail:
```stata
capture noisily tvdiagnose, id(`id') start(start) stop(stop) exposure(tv_exposure) ///
    entry(`entry') exit(`exit') coverage gaps overlaps summarize
```

### 2) tvcalendar merge() is ignored
Before (tvtools/tvcalendar.ado:99-102):
```stata
quietly merge m:1 `datevar' using `"`using'"', keep(master match) nogenerate
```
After (use merge() vars if provided):
```stata
if "`merge'" != "" {
    quietly merge m:1 `datevar' using `"`using'"', ///
        keep(master match) keepusing(`merge') nogenerate
}
else {
    quietly merge m:1 `datevar' using `"`using'"', keep(master match) nogenerate
}
```

### 3) tvweight binary logit should enforce 0/1 coding
Before (tvtools/tvweight.ado:71-88):
```stata
quietly tab `exposure'
local n_levels = r(r)
if `n_levels' > 2 & "`model'" == "logit" {
    local model "mlogit"
}
```
After:
```stata
quietly tab `exposure' if `touse'
local n_levels = r(r)
if `n_levels' == 2 & "`model'" == "logit" {
    quietly summarize `exposure' if `touse'
    if r(min) != 0 | r(max) != 1 {
        display as error "logit requires 0/1 coding; recode or use model(mlogit)"
        exit 198
    }
}
```

### 4) tvweight mlogit tempvar naming breaks on non-integer levels
Before (tvtools/tvweight.ado:242-246):
```stata
tempvar ps_`lev'
predict double `ps_`lev'' if `touse', pr outcome(`lev')
replace `generate' = 1 / `ps_`lev'' if `exposure' == `lev' & `touse'
```
After:
```stata
tempvar ps_tmp
predict double `ps_tmp' if `touse', pr outcome(`lev')
replace `generate' = 1 / `ps_tmp' if `exposure' == `lev' & `touse'
```

### 5) tvdml: reject unsupported methods or implement them
Before (tvtools/tvdml.ado:68-73):
```stata
if !inlist("`method'", "lasso", "ridge", "elasticnet") {
    display as error "method() must be lasso, ridge, or elasticnet"
    exit 198
}
```
After (reject non-lasso until implemented):
```stata
if "`method'" != "lasso" {
    display as error "method(`method') not implemented; use method(lasso)"
    exit 198
}
```

### 6) tvdml: handle lasso failures explicitly
Before (tvtools/tvdml.ado:141-157):
```stata
quietly capture {
    lasso linear ...
    predict ...
}
```
After:
```stata
capture lasso linear `depvar' `covariates' if `touse' & `fold' != `k', nolog
if _rc {
    display as error "lasso failed; rerun with method(lasso) unavailable"
    exit _rc
}
predict double _y_hat if `touse' & `fold' == `k'
```

### 7) tvestimate: guard division by zero
Before (tvtools/tvestimate.ado:187-189):
```stata
local psi = `sum_ya' / `sum_aa'
```
After:
```stata
if `sum_aa' == 0 {
    display as error "G-estimation failed: sum(A*(A-ps)) == 0"
    exit 498
}
local psi = `sum_ya' / `sum_aa'
```

### 8) tvestimate bootstrap: ignore missing reps
Before (tvtools/tvestimate.ado:245-247):
```stata
mata: st_local("se_psi", strofreal(sqrt(variance(st_matrix("`psi_boot'")))))
```
After:
```stata
mata: st_matrix("`psi_boot'", select(st_matrix("`psi_boot'"), st_matrix("`psi_boot'") :!= .))
mata: st_local("se_psi", strofreal(sqrt(variance(st_matrix("`psi_boot'")))))
```

### 9) tvdiagnose: remove distinct dependency
Before (tvtools/tvdiagnose.ado:95-96):
```stata
quietly distinct `id'
local n_persons = r(ndistinct)
```
After:
```stata
tempvar _tag
quietly bysort `id': gen byte `_tag' = (_n == 1)
quietly count if `_tag'
local n_persons = r(N)
drop `_tag'
```

### 10) _tvexpose_overlaps: string id safe display
Before (tvtools/_tvexpose_diagnose.ado:213-214):
```stata
display as text "  ID " as result %6.0f `show_id' as text ///
```
After:
```stata
display as text "  ID " as result "`show_id'" as text ///
```

## Dependency/Testing Notes
- `distinct` is used in tvdiagnose, tvpass, tvpipeline, tvreport, and tvtrial without bundling (tvtools/tvdiagnose.ado:95-96; tvtools/tvpass.ado:71-72; tvtools/tvpipeline.ado:133-134; tvtools/tvreport.ado:62-63; tvtools/tvtrial.ado:397-398). Best fix: replace with built-in unique-ID counting or include a local fallback utility.
- _devkit/_testing/test_tvexpose.do installs `distinct` without capture, causing hard failures in restricted/offline environments (_devkit/_testing/test_tvexpose.do:95-99). Best fix: `capture quietly ssc install distinct` and provide a skip/warn path when unavailable.
