# MSM .ado Audit

Date: 2026-03-14

Scope: all `.ado` files in `msm/`

Method:

- Static review of every `msm/*.ado` file.
- Targeted Stata 17 MP reproductions against `msm_example.dta`.
- The shipped regression suite still passes (`msm/qa/test_msm.do` reported `118/118 passed`), so several issues below are gaps in test coverage rather than already-known failures.

Severity guide:

- High: can silently change causal estimates, export stale/wrong results, or fit the wrong model.
- Medium: reproducible runtime failure, broken advertised option, or strong API/contract mismatch.
- Low: export/router/documentation defects or validation gaps that do not immediately corrupt core estimates.

## Findings

### 1. High: downstream commands trust whatever is currently in `e()`

Affected code:

- `msm/_msm_check_fitted.ado:10-18`
- `msm/msm_predict.ado:115-117`
- `msm/msm_sensitivity.ado:52-55`
- `msm/msm_report.ado:157-198`
- `msm/msm_table.ado:87-105`
- `msm/msm_table.ado:239-241`

Problem:

- `msm_fit` sets a dataset flag (`_msm_fitted`) but does not persist its own coefficient/vector state under package-owned names.
- `msm_predict`, `msm_sensitivity`, `msm_report`, and the coefficients branch of `msm_table` all read the live `e(b)` / `e(V)` from the most recent estimation command in the session.
- That means any unrelated `logit`, `regress`, `stcox`, etc. run after `msm_fit` can silently change later MSM output without clearing the `_msm_fitted` flag.

Reproduced:

```text
PRED_BEFORE=.03525275,.0298466
PRED_AFTER=.02973084,.03826808
ECMD=logit MSMCMD=.
```

That was from the same dataset and the same `msm_predict` call before and after an unrelated `logit outcome treatment age sex if period==0`.

Impact:

- Silent scientific corruption. The user can believe they are getting MSM predictions while actually using coefficients from a different model.

Fix:

- In `msm_fit`, persist the fitted state in package-owned matrices, for example `_msm_fit_b` and `_msm_fit_V`, plus metadata such as model type, treatment name, and confidence level.
- In downstream commands, verify that those package-owned matrices exist and use them instead of raw `e()`.
- Optionally repost the saved fit to `e()` inside downstream commands if a Stata postestimation command requires it.
- Strengthen `_msm_check_fitted` so it checks both the dataset flag and the saved fit objects.

Tests to add:

- Fit MSM, run an unrelated estimation command, then verify `msm_predict`, `msm_sensitivity`, `msm_report`, and `msm_table, coefficients` still use the original MSM fit.

### 2. High: `msm_prepare` does not clear stale downstream artifacts

Affected code:

- `msm/msm_prepare.ado:157-159`
- `msm/msm_fit.ado:241-249`
- `msm/msm_predict.ado:492-498`
- `msm/msm_diagnose.ado:229-267`
- `msm/msm_sensitivity.ado:233-243`
- `msm/msm_table.ado:109-174`
- `msm/msm_report.ado:104-111`

Problem:

- `msm_prepare` only clears `_msm_weighted` and `_msm_fitted`.
- It does not clear `_msm_model`, `_msm_period_spec`, `_msm_pred_saved`, `_msm_bal_saved`, `_msm_diag_saved`, `_msm_sens_saved`, or the persisted matrices (`_msm_pred_matrix`, `_msm_bal_matrix`).
- After a new `msm_prepare`, `msm_table` and `msm_report` can still see old objects and export/report stale results from an earlier analysis.

Reproduced:

```text
PRED_SAVED_BEFORE=1
PRED_SAVED_AFTER=1
TABLE_RC=0
```

After rerunning `msm_prepare`, `msm_table, predictions` still exported the old prediction matrix successfully.

Impact:

- Silent stale-result reuse after data remapping or partial reruns.

Fix:

- Add a cleanup block in `msm_prepare` that removes all MSM-derived flags, chars, and matrices, not just the weighted/fitted flags.
- Also clear package-owned fit matrices if finding 1 is fixed.
- Consider a dedicated internal cleanup helper invoked by `msm_prepare` and any command that invalidates downstream state.

Tests to add:

- Full pipeline to `msm_predict`, rerun `msm_prepare`, then confirm `msm_table` and `msm_report` refuse to use old predictions/model/balance output.

### 3. High: the Cox branch calls `stset` without `id()`

Affected code:

- `msm/msm_fit.ado:205-212`

Problem:

- The Cox branch creates multiple-record survival data but calls:
  `stset _time_exit [pw=_msm_weight] if _esample, enter(_time_enter) failure(_failure)`
- It never supplies `id(`id')`.
- For person-period data that is a core contract violation; Stata has no subject identifier in the st settings.

Reproduced:

```text
ST_ID= ST_T=_t
```

After `msm_fit, model(cox)`, `_dta[st_id]` was blank.

Impact:

- Multiple rows from the same individual are not explicitly tied together in the survival declaration.
- This undermines the Cox implementation for the exact data structure the package is built around.

Fix:

- Change the Cox branch to `stset ..., id(`id') enter(`_time_enter') failure(`_failure')`.
- Preserve and restore prior st settings if the dataset was already `stset`.
- Add validation that `(id, period)` does not imply overlapping intervals before `stset`.

Tests to add:

- After `msm_fit, model(cox)`, assert that `_dta[st_id]` equals the mapped id variable.

### 4. High: extreme treatment/censoring probabilities are silently converted into weight 1

Affected code:

- `msm/msm_weight.ado:408-425`
- `msm/msm_weight.ado:519-522`

Problem:

- `_tw_t` and `_cw_t` start at `1`.
- They are only replaced when predicted probabilities fall inside hard-coded bounds.
- For near-deterministic cases, the code prints a warning but leaves the period weight at `1` instead of truncating probabilities, marking the weight missing, or stopping.

Example from the code path:

- Treated observations only update when `denom_pr > 0.001`.
- Untreated observations only update when `denom_pr < 0.999`.
- Censoring weights only update when `denom_pr < 0.999`.

Impact:

- The most positivity-sensitive observations are silently neutralized.
- That biases the weights toward 1 exactly where the analysis should either truncate explicitly or fail loudly.

Fix:

- Replace the current guards with explicit probability truncation, for example `p = min(max(p, eps), 1-eps)`.
- Or mark those observations missing and stop with an informative positivity error.
- Do not let the default initialized value `1` stand in as a fallback weight.

Tests to add:

- Construct a dataset with predicted treatment probability above the bound and verify the weight is either truncated or the command errors, never silently set to 1.

### 5. High: `generate()` / prefix support is documented but not implemented

Affected code:

- `msm/msm_prepare.ado:38-49`
- `msm/msm_prepare.ado:147-155`
- `msm/_msm_get_settings.ado:20-31`
- `msm/_msm_check_weighted.ado:21-26`
- `msm/msm_weight.ado:79-89`
- `msm/msm_weight.ado:166-169`
- `msm/msm_fit.ado:100-115`

Problem:

- `msm_prepare` accepts `generate(string)` and stores it in `_msm_prefix`.
- The rest of the package still hardcodes `_msm_*` variable names.
- `_msm_weight_var` is even stored as a char, but the package never actually consults it.

Reproduced:

```text
PREFIX=foo_
FOO_WEIGHT_RC=111
MSM_WEIGHT_RC=0
```

So the stored prefix changed, but the generated weight variable still had the hard-coded `_msm_` name.

Impact:

- The public API promises namespace control that users do not actually get.
- This also makes it impossible to run multiple MSM analyses side by side in the same dataset.

Fix:

- Either implement prefix-aware naming consistently across all generated variables and helpers, or remove/deprecate the option from the public interface.
- If implemented, `_msm_check_weighted` and all downstream code should read the stored variable names rather than hard-coded `_msm_*`.

Tests to add:

- Run `msm_prepare, generate(foo_)` and verify all generated variables and checks use the `foo_` namespace.

### 6. Medium: repeated natural-spline fits fail on leftover `_msm_per_ns*` variables

Affected code:

- `msm/msm_fit.ado:113-120`
- `msm/_msm_natural_spline.ado:51-52`
- `msm/_msm_natural_spline.ado:70`
- `msm/_msm_natural_spline.ado:79-95`

Problem:

- `msm_fit` drops `_msm_period_sq` and `_msm_period_cu` before reuse.
- It does not drop old `_msm_per_ns*` variables before calling `_msm_natural_spline`.

Reproduced:

```text
variable _msm_per_ns1 already defined
RC=110
```

Impact:

- A user cannot rerun `msm_fit, period_spec(ns(...))` on the same dataset without manually cleaning generated variables.

Fix:

- Before spline generation, `capture drop _msm_per_ns*`.
- Better: generate spline basis as tempvars and persist only the names actually used by the current fit.

Tests to add:

- Call `msm_fit, period_spec(ns(3))` twice in a row and assert the second run succeeds.

### 7. Medium: `msm_plot, type(survival)` overwrites saved prediction results

Affected code:

- `msm/msm_plot.ado:179-186`
- `msm/msm_predict.ado:492-498`

Problem:

- The survival plot internally calls `msm_predict`.
- `msm_predict` always persists `_msm_pred_matrix` and related chars.
- So plotting is not read-only; it rewrites prediction artifacts that `msm_table` later exports.

Reproduced:

```text
PRED_COLS_BEFORE=10
PRED_COLS_AFTER=7, ROWS_AFTER=2
STRATEGY_AFTER=both
```

An existing `difference` prediction matrix was overwritten by a smaller matrix from the plotting call.

Impact:

- Plotting can silently downgrade or replace the user's saved predictions.

Fix:

- Add an internal `nopersist` option to `msm_predict` and use it from `msm_plot`.
- Or save/restore the prior prediction matrix and chars around the internal plotting call.

Tests to add:

- Save predictions, call `msm_plot, type(survival)`, then verify the saved prediction matrix is unchanged.

### 8. Medium: `bootstrap()` is advertised but unusable with the weighted models

Affected code:

- `msm/msm_fit.ado:177-180`
- `msm/msm_fit.ado:192-194`
- `msm/msm_fit.ado:223-225`

Problem:

- The bootstrap branches wrap `glm` / `regress` / `stcox` calls that still include weights.
- Stata rejects this path with `weights not allowed`.

Reproduced:

```text
weights not allowed
RC=101
```

Impact:

- A documented option is broken at runtime.

Fix:

- Either remove `bootstrap()` until it is implemented correctly, or replace it with a package-owned cluster bootstrap wrapper that resamples ids and refits internally.
- At minimum, fail fast with a package-specific error message instead of surfacing the raw Stata error.

Tests to add:

- Add an expected-failure test now, then convert it to a success test once a real bootstrap implementation exists.

### 9. Medium: `msm_predict` assumes `outcome_cov()` variables are baseline/time-invariant

Affected code:

- `msm/msm_fit.ado:41-43`
- `msm/msm_predict.ado:126-137`
- `msm/msm_predict.ado:636-645`

Problem:

- `msm_fit` accepts any numeric `outcome_cov(varlist)`.
- `msm_predict` then reduces the data to the first period only and uses those observed covariate values for every future time point.
- If a user includes a time-varying covariate in the outcome model, prediction is no longer evaluating the fitted model on the intended covariate history.

Impact:

- Counterfactual predictions can be internally inconsistent with the fitted MSM specification.

Fix:

- Either restrict `outcome_cov()` to baseline covariates and validate that in `msm_fit`, or redesign prediction so it evaluates on an explicit covariate path rather than baseline rows only.
- Document the rule clearly in help and README once decided.

Tests to add:

- Include a time-varying covariate in `outcome_cov()` and assert the command either rejects it or handles it via a documented path.

### 10. Medium: confidence levels are hard-coded to 95% in report/export layers

Affected code:

- `msm/msm_table.ado:266-290`
- `msm/msm_table.ado:913-917`
- `msm/msm_report.ado:183-185`
- `msm/msm_report.ado:264-265`

Problem:

- `_msm_tbl_coef` labels `95% CI` and uses `invnormal(0.975)` regardless of the level used in `msm_fit`.
- `_msm_tbl_sens` writes `95% CI` regardless of the level used in `msm_sensitivity`.
- `msm_report` similarly hardcodes `1.96`.

Impact:

- Tables can mislabel or miscompute intervals after non-default `level()` settings.

Fix:

- Persist the fit and sensitivity confidence levels in chars or matrices and consume those values in the report/export code.
- If a separate reporting level is desired, expose `level()` directly in `msm_report` and `msm_table`.

Tests to add:

- Fit at `level(90)` and verify all exported labels and interval endpoints reflect 90%, not 95%.

### 11. Medium: `varabbrev` leaks out of failing commands

Affected code:

- Pattern appears in most programs, for example:
  - `msm/msm_prepare.ado:29-32`
  - `msm/msm_validate.ado:24-27`
  - `msm/msm_weight.ado:37-40`
  - `msm/msm_fit.ado:32-35`
  - `msm/msm_predict.ado:34-37`

Problem:

- Commands save the current setting, then `set varabbrev off`, but only restore it at the normal success exit.
- Any early `exit` leaves the user's session mutated.

Reproduced:

```text
BEFORE more=on varabbrev=on
RC=198
AFTER more=on varabbrev=off
```

Impact:

- Session-level side effects after errors make later interactive work behave differently.

Fix:

- Wrap each command body in a capture/cleanup pattern:
  1. save the original settings
  2. `capture noisily { ... }`
  3. store `_rc`
  4. restore settings
  5. `exit` with the stored return code if nonzero

Tests to add:

- Force an error in each major command and assert `c(varabbrev)` is unchanged afterward.

### 12. Low-Medium: `censor_n_cov()` without `censor_d_cov()` is silently ignored

Affected code:

- `msm/msm_weight.ado:46-50`
- `msm/msm_weight.ado:146-156`

Problem:

- IPCW is only triggered when `censor_d_cov()` is present.
- Supplying `censor_n_cov()` alone produces no censoring weights and no error.

Reproduced:

```text
RC=0
CW_RC=111
```

The command succeeded, but `_msm_cw_weight` was never created.

Impact:

- Easy user foot-gun: a misspecified call is accepted silently.

Fix:

- Add validation that `censor_n_cov()` requires `censor_d_cov()`.
- Also reject any IPCW option when no censor variable was mapped.

Tests to add:

- Assert that `censor_n_cov()` without `censor_d_cov()` returns a package-specific error.

### 13. Low: protocol export does not escape user text and truncates Excel descriptions

Affected code:

- `msm/msm_protocol.ado:98-105`
- `msm/msm_protocol.ado:127-143`
- `msm/msm_protocol.ado:165-178`

Problem:

- CSV export writes raw strings without escaping embedded quotes or commas.
- LaTeX export writes raw text without escaping `%`, `_`, `&`, `#`, etc.
- Excel export uses `str244 description`, so longer protocol text is truncated.

Impact:

- Broken CSV/LaTeX output for realistic prose inputs and silent truncation in Excel.

Fix:

- Escape CSV quotes by doubling them.
- Escape TeX special characters before writing LaTeX.
- Use `strL` for free-text export staging variables in Stata 16+.

Tests to add:

- Export protocol text containing commas, quotes, `%`, `_`, and more than 244 characters.

### 14. Low: the package router omits `msm_table`

Affected code:

- `msm/msm.ado:28-31`
- `msm/msm.ado:63-81`

Problem:

- `msm.ado` reports `n_commands = 10` and the command list excludes `msm_table`, even though the package ships it and the README documents it.

Impact:

- Users reading the router output get an incomplete view of the package.

Fix:

- Add `msm_table` to the command list, increment the command count, and include it in the displayed workflow/reporting section.

Tests to add:

- Assert that `msm, list` includes `msm_table`.

## Recommended Fix Order

1. Fix the saved-fit/state model first: findings 1 and 2.
2. Repair the Cox implementation: finding 3.
3. Fix weight edge handling: finding 4.
4. Decide whether prefix support is real or should be removed: finding 5.
5. Clean up runtime/API defects: findings 6, 7, 8, 9, 10, 11, 12.
6. Then address export/router polish: findings 13 and 14.

## Minimum Regression Tests Missing Today

- Downstream commands remain stable after unrelated estimation commands.
- `msm_prepare` clears all persisted MSM artifacts.
- Repeated `period_spec(ns(...))` fits succeed.
- `msm_plot, type(survival)` is read-only with respect to saved predictions.
- Cox `stset` includes the subject id.
- Non-default confidence levels propagate into every report/export path.
