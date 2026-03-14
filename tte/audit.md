# `tte` ADO Audit

Audit date: 2026-03-14

Scope:
- Reviewed every `.ado` file under `tte/`
- Ran the bundled functional suite in `tte/qa/test_tte.do` (`61/61` tests passed)
- Added targeted Stata repros for paths the bundled tests do not cover

The package is close to internally coherent, but several important failure modes are currently outside the test surface.

## Critical

### 1. User-supplied censoring is ignored by the core pipeline

Files:
- `tte_prepare.ado:167-168`
- `tte_expand.ado:48-60`
- `tte_expand.ado:147-258`
- `tte_expand.ado:310-321`
- `tte_fit.ado:243-245`
- `tte_fit.ado:304-306`

Problem:
- `tte_prepare` stores `censor()`, but `tte_expand` never uses it to stop follow-up.
- The only censoring logic applied during expansion is artificial adherence censoring inside `_tte_expand_censor`.
- `tte_fit` excludes only `` `prefix'censored == 0 ``. Natural/administrative censoring is never enforced.

Confirmed locally:
- A 3-row toy dataset with `cens==1` at period 1 still retained period 2 in the expanded trial data.

Impact:
- ITT/PP/AT analyses can include post-censor person-time that should be unobserved.
- Optional censoring weights do not fix this, because the rows after natural censoring are still present in the outcome model.

Solution:
- During expansion, compute the first natural censoring time from the original `censor()` variable for each `id` within each emulated trial.
- Drop follow-up after that point.
- Keep artificial and natural censoring separate, for example:
  - `` `prefix'art_censored ``
  - `` `prefix'nat_censored ``
  - `` `prefix'censored_any ``
- Fit the outcome model on `censored_any == 0`.
- If censoring weights are requested, model the correct censoring indicator explicitly instead of relying on the raw source variable alone.

### 2. `tte_weight, generate(...)` is broken downstream

Files:
- `tte_weight.ado:70`
- `tte_weight.ado:350-351`
- `tte_fit.ado:104-119`
- `tte_diagnose.ado:39-47`
- `tte_plot.ado:72-77`
- `tte_plot.ado:196-200`
- `tte_report.ado:107-133`

Problem:
- `tte_weight` stores the actual weight variable name in `_tte_weight_var`.
- Downstream commands ignore that metadata and hard-code `` `prefix'weight ``.

Confirmed locally:
- After `tte_weight, generate(mywt)`, `tte_fit` warned that no PP weights were found and fit an unweighted model.
- `tte_diagnose` then reported unweighted diagnostics on the same dataset.

Impact:
- Users can believe they are fitting weighted PP/AT models while actually running unweighted analyses.
- The same break affects diagnostics, plots, and reports.

Solution:
- Add a shared weight-variable resolver:
  - first read `char _dta[_tte_weight_var]`
  - then fall back to `` `prefix'weight ``
- Use that resolver in `tte_fit`, `tte_diagnose`, `tte_plot`, and `tte_report`.
- In the ITT branch of `tte_weight`, also set `_tte_weighted` and `_tte_weight_var`.
- When `tte_prepare` resets the pipeline, clear `_tte_weight_var` and `_tte_pscore_var` too.

## High

### 3. Balance diagnostics are computed on repeated follow-up rows, not at trial entry

Files:
- `tte_diagnose.ado:193-241`
- `tte_plot.ado:224-287`

Problem:
- SMDs are calculated over all expanded rows in each arm.
- Baseline covariates are frozen and repeated across follow-up, so longer-lived or uncensored clones are counted multiple times.

Confirmed locally:
- On `tte_example` after `tte_expand, maxfollowup(3)`, the unweighted age SMD was `0.07435` when computed over all rows but `0` at `_tte_followup == 0`.

Impact:
- The Love plot and reported balance are not baseline balance diagnostics.
- They are duration-weighted summaries that can create or hide imbalance.

Solution:
- Restrict balance calculations to trial entry only: `` `prefix'followup == 0 ``.
- Use one row per `id`-`trial` at baseline.
- Feed that corrected matrix into `tte_plot, type(balance)`.

### 4. Positivity is checked only in aggregate, not by period/trial

Files:
- `tte_validate.ado:272-285`

Problem:
- Check 8 pools all eligible observations across all periods.
- A period with only treated or only untreated eligible subjects still passes if some other period has both values.

Confirmed locally:
- A 2-period toy dataset with period 0 entirely untreated still passed check 8.

Impact:
- Period-specific positivity violations reach weighting and model fitting.
- That creates avoidable separation, extreme weights, and non-identification.

Solution:
- Compute positivity per `period` in the prepared data.
- Ideally also expose a post-expansion check by emulated trial.
- Under `verbose`, return the offending periods/trials.

## Medium

### 5. `strict` does not actually convert all warnings into errors

Files:
- `tte_validate.ado:84-99`
- `tte_validate.ado:120-129`
- `tte_validate.ado:222-230`
- `tte_validate.ado:257-259`
- `tte_validate.ado:298-300`
- `tte_validate.ado:317-319`
- `tte_validate.ado:349-360`

Problem:
- Some warnings honor `strict`.
- Others do not.
- Small per-period sample size and very low event count remain warnings even under `strict`.
- Check 9 emits only a note and never affects warning/error counts.

Confirmed locally:
- A 12-observation zero-event dataset returned `rc=0`, `r(n_warnings)=1`, and `r(n_errors)=0` under `tte_validate, strict`.

Impact:
- `strict` is not a reliable pre-fit gate even though the UI says it is.

Solution:
- Centralize warning handling so every warning path promotes to an error when `strict` is set.
- Decide whether period-numbering messages are warnings or informational notes, then implement that consistently.

### 6. The public interface and the actual parsers have drifted apart

Files:
- `tte_expand.ado:40-42`
- `tte_diagnose.ado:26-27`
- `tte_weight.ado:45-50`
- `tte_fit.ado:42-46`
- `_tte_memory_estimate.ado:8-36`

Problem:
- Several advertised options are not parsed or implemented in the `.ado` layer:
  - `tte_expand`: no `chunk_size()` or `keepvars()`
  - `tte_diagnose`: no `weight_summary`, `by_period`, or `export()`
  - `tte_weight`: no `stabilized`
  - `tte_fit`: no `robust`
- `_tte_memory_estimate` is effectively dead code because chunked expansion is unreachable.

Impact:
- Help/README-driven usage fails at runtime or promises controls that do not exist.

Solution:
- Either implement the missing options end-to-end or remove them from the user-facing contract immediately.
- If an option is intentionally always-on, document it as always-on instead of exposing a dead switch.

### 7. The saved “propensity score” is not a baseline treatment PS, but the diagnostics treat it as one

Files:
- `tte_weight.ado:470-473`
- `tte_weight.ado:563-566`
- `tte_diagnose.ado:302-345`
- `tte_plot.ado:318-327`
- `tte_plot.ado:356-376`

Problem:
- `save_ps` stores the denominator prediction from the switch model used for adherence weighting.
- That is not the same object as a baseline treatment-assignment propensity score.
- `tte_diagnose, equipoise` and the PS/equipoise plots then treat it as standard treatment PS overlap.

Impact:
- The overlap/equipoise outputs are methodologically mislabeled.
- In PP/AT settings they can be actively misleading.

Solution:
- Estimate and store a separate baseline assignment PS if overlap/equipoise diagnostics are intended.
- Otherwise rename the saved quantity to reflect what it actually is and disable equipoise/PS diagnostics for it.

## Low

### 8. Text exports do not escape user content, and report output is inconsistent across formats

Files:
- `tte_protocol.ado:187-194`
- `tte_protocol.ado:255-271`
- `tte_report.ado:214-324`
- `tte_report.ado:439-450`

Problem:
- CSV and LaTeX exports interpolate raw user text without escaping commas, quotes, line breaks, `%`, `&`, `_`, `\`, and similar characters.
- `tte_report, predictions(...)` only uses the prediction matrix in the Excel branch; display and CSV silently ignore it.

Impact:
- Real manuscript/protocol text can produce malformed exports.
- Report contents differ materially by output format.

Solution:
- Add CSV quoting/escaping helpers.
- Add LaTeX escaping helpers.
- Either implement `predictions()` consistently across display/CSV/Excel or document that it is Excel-only.

## Recommended fix order

1. Fix natural censoring handling in `tte_expand` and `tte_fit`.
2. Fix weight-variable resolution across all downstream commands.
3. Correct baseline-only balance diagnostics and per-period positivity validation.
4. Make `strict` behavior consistent.
5. Bring the documented interface back into sync with the code.
