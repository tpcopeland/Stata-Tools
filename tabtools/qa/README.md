# tabtools QA

The `tabtools` QA suite is flat and concern-oriented, with one curated lane runner and independently runnable suites at the `qa/` root. It covers command behavior, known answers, external parity, disclosure control, exported artifacts, documentation, and release contracts.

## How to run

```bash
cd tabtools/qa
stata-mp -b do run_all.do            # full lane (default correctness gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do run_all.do core       # functional and known-answer suites
stata-mp -b do test_desctab.do       # one suite standalone
```

`release` adds the benchmark to `full`; `benchmark` runs only the timing guardrail. Direct `run_all.do` users should gate on its terminal `RESULT:` line, because Stata batch shell status is not the suite verdict.

## Isolation

`run_all.do` sandboxes PLUS/PERSONAL and generated output under `c(tmpdir)`, installs the package from `../`, and restores the caller’s ado paths. Standalone suites install from `../` into the active PLUS, so use the runner when the real ado tree must remain untouched.

Concurrent runs of the same lane can collide through shared logs. Use a scratch copy preserving the sibling layout and remove copied `qa/*.log` plus `qa/run_all_status.txt`; a disagreement between `run_all.log` and a suite’s own log is the collision tell.

| Sibling | Required by | Behavior if absent |
|---|---|---|
| `_data/` | release demo regeneration | hard failure |
| `eplot/` | integration and release forest demos | hard failure |
| `tc_schemes/` | release demo regeneration | hard failure |
| `logdoc/` | release demo regeneration | hard failure |

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use known-answer or invariant oracles; `crossval_*` files compare against an independent implementation; `benchmark_*` files are timing guardrails, not correctness evidence.
- Every runnable suite ends with one `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure. The runner rejects missing, duplicate, empty, failing, or unreconciled receipts even when the child exits zero. Any skip fails `core`, `full`, `release`, and `benchmark`; `quick` treats skips as advisory.
- The runner sandboxes package installation and restores PLUS/PERSONAL; standalone files install from the package root for independent execution.
- Paths derive from `c(pwd)`; no suite uses a machine-local repository path.
- Synthetic data are generated at runtime; tracked cross-validation inputs live in `data/`, and fixture ownership is recorded in `fixtures_manifest.md`.
- Generated logs, workbooks, datasets, images, and `output/` contents are gitignored; tracked `demo/` assets and declared QA fixtures are the only generated-file exceptions.
- Consolidated sections use `**# Migrated:` bookmarks so retained contracts remain traceable.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| Runner receipt checks | Python 3 | hard failure |
| Excel/artifact suites | Python 3, `openpyxl`, and Pillow | hard failure |
| `crossval_tabtools.do` | `Rscript`; Python with `numpy` and `statsmodels` | hard failure |
| full/release bootstrap | Stata packages `simsum`, `siman`, `sencode`, and `labelsof` | installed into the sandbox; installation failure is fatal |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_ci_level_provenance.do` | Confidence-level provenance and explicit fallback contracts across model-table commands. |
| `test_column_widths.do` | `_tabtools_colwidth` unit contract (display width, `exclude()`, block wrap, varabbrev restore) and per-column xlsx width sizing for desctab/table1_tc, regtab, effecttab, and comptab, with the header-row wrap that replaces label-driven column widening. |
| `test_comptab.do` | Vertical composition, source-frame handling, option guards, and error-state restoration. |
| `test_review_2026_10_01_composition.do` | Model alignment in numeric companions, opaque labels, frame identity, and missing/duplicate companion refusals. |
| `test_review_2026_10_01_models.do` | Equation identity, reference-label collisions, case-sensitive frames, large matrix values, and collected-model labels. |
| `test_review_2026_10_01_statistics.do` | Translation-invariant Cochran trend tests and literal rate-table text and filename refusals. |
| `test_runner_contracts.do` | Private Stata child suites prove receipt enforcement, skip policy, argument refusals, exact nondefault sysdir restoration, and enclosing-lane receipt isolation. |
| `test_corrtab.do` | Pearson/Spearman output, stars, shapes, pairwise-N p-values, and undefined diagonals for degenerate Spearman variables. |
| `test_crosstab.do` | Association measures, weights, small-cell disclosure control, returns, and sink parity. |
| `test_deep_audit_core.do` | Destructive and silent-corruption regressions in frames, metadata, scales, weights, and samples. |
| `test_deep_audit_output.do` | CI provenance, formatting boundaries, atomic exports, quotation, and output normalization. |
| `test_desctab.do` | Direct descriptive-engine behavior, option semantics, returns, styles, sinks, and cleanup. |
| `test_effecttab.do` | Supported result sources, matrix mode, frames, formatting, and console returns. |
| `test_effecttab_omitted.do` | Constrained margins labelling: not-estimable and unidentified cells, factor row labels, `omitlabel()`/`emptylabel()`, and `r(table)` exclusion. |
| `test_effecttab_layout.do` | Excel body layout read back with openpyxl: Reference/Omitted merges confined to the model block that holds them (other models' CI and p cells intact), and top alignment across every body column. |
| `test_followups_2026_09_27.do` | Follow-ups to the 2026-09-26/27 packages: `xtgee` on the scale `glm` gives the same family/link, `nbreg` + `zip` ancillary and inflation rows, `title()`/`footnote()` text reaching xlsx, CSV and Markdown unexpanded in every command (read back with `tools/xlsx_facts.py` and `tools/md_facts.py`), `effecttab` `from()` headers, failed Markdown writes leaving the target intact, up-front `csv()` path checks in `regtab`/`effecttab`, covariates named like their own model's ancillary parameter or cutpoint, and confidence levels such as 99.9 shown as typed (never `99.90000000000001`) in headers, methods, CSV and frame characteristics. |
| `test_final_review_docs.do` | Executable corrected `stratetab` help and tips recipes using real `strate` output, including workbook values and labels. |
| `test_final_review_helpers.do` | Sparse Excel sheet dimensions, bounds errors, and caller-state preservation for `_tabtools_xlsx_read`. |
| `test_final_review_models.do` | Fallback-reader errors, stale active-estimate statistics/metadata rejection for `regtab` and `effecttab`, and `stratetab` rate-ratio methods provenance. |
| `test_audit_2026_09_02.do` | Extended missings, distinct missing categories, fractional category labels across output sinks, stable matrix identifiers, transactional frames, and strict private-helper contracts. |
| `test_audit_2026_09_26_fixes.do` | `stratetab` missing/non-positive scale rejection, `effecttab` methods text without ambient `e()`, unique `effecttab` `r(table)` row names (including `from()` names with spaces), and the vendored `check_xlsx.py` header-only guard. |
| `test_hrcomptab.do` | Rate/model scaffold composition, frame/workbook parity, eplot output, dependency-failure cleanup, and guards. |
| `test_issue_review_1_11_0.do` | Regression pins for factor rendering, merging, precision, labels, legends, and whitespace. |
| `test_option_coverage.do` | Real-invocation exercise of each public command’s option surface. |
| `test_output_sinks_markdown.do` | Output layer: colliding `xlsx()`/`csv()`/`markdown()` destinations refused with the seeded workbook byte-identical in every multi-sink command, the `.csv` contract, path normalisation, macro-safe Markdown text, replace-by-default and `mdappend`, rendered Markdown fidelity through `tools/check_md_render.py` (markdown-it-py), and `survtab` times beyond follow-up. |
| `test_package_adversarial.do` | Package-wide hostile inputs, state attacks, and export-failure return survival. |
| `test_package_hardening.do` | Extreme shapes, hostile cell content, locale behavior, and rerun safety. |
| `test_package_helpers.do` | Shared validators, renderers, Excel engines, styles, Markdown, and collection helpers. |
| `test_package_integration.do` | Persistent defaults, cross-command frames and exports, e() preservation, and eplot integration. |
| `test_package_release.do` | Metadata, manifest/install, help rendering and width, demos, and golden artifact digests. |
| `test_puttab.do` | Dataset/frame/matrix sources, styling, Markdown, and dimensions. |
| `test_puttab_stacktab_2026_09_27.do` | `puttab` blank `matrix()` label header in Markdown, quiet `frame()` load, no single-cell footnote merge; `stacktab` `borders(bottom(row #))`, `rows()` in sheet coordinates with and without `cols()`, case-insensitive `style(COLWIDTH())`, and CSV title/note rows. Workbook layout is read back with `tools/xlsx_facts.py` (openpyxl). |
| `test_regtab.do` | Model families, statistics, selection, display modes, frames, and p-value policies. |
| `test_regtab_omitted.do` | Base, collinear, and empty coefficient labelling per model, including `omitlabel()`/`emptylabel()`, `r(table)`, interaction cells, estimators whose collection records every constrained cell as empty (`nbreg`, `zinb`, `intreg`, `streg` weibull), and estimated levels with a missing CI bound. |
| `test_regtab_multieq_mixed.do` | Mixed and multi-equation layouts: factor header rows in multilevel models, rows and equations only a later model estimates (`mlogit`, `zip`/`zinb`, `ologit` + `mlogit`), blank overflowed transformed CIs, me* `relabel` of slope variances and covariances, `r(table)` row names, `mecloglog`/`mestreg`/`streg, time` scale, and `svy:` classification. |
| `test_regtab_backlog_2026_09_26.do` | Structural intercept/cutpoint/ancillary rows (covariates named or labelled `p`, `alpha`, `cut1`, ...; lognormal/loglogistic ancillary scale; per-model roles), AIC/BIC/QICu parameter count after few-cluster `vce(cluster)` against `estat ic`, `mestreg, time` random intercept, `bootstrap:`/`jackknife:`/`mi estimate:` classification with t-based mi intervals, per-equation factor headers, `stats(events r2_a rmse F mi_m fmi)`, the model-built methods sentence, and unique `r(table)` row names. |
| `test_regtab_crossmodel_ancillary.do` | A covariate and another model's ancillary parameter or cutpoint of the same name (`alpha` beside `nbreg`, `cut1` beside `ologit`, `ln_p`/`p` beside a Weibull) keep their own rows, in either model order, with and without `keepintercept`. |
| `test_review_2026_09_26_fixes.do` | Fixes from the independent review of 2.1.12: AIC/BIC/QICu count free parameters under robust-type `vce()` (base levels, `mlogit`'s base equation and linear constraints excluded, against `estat ic`; the few-cluster, few-replication and few-panel cap, with and without constraints), `bs`/`bstrap`/`bootstrap`/`jknife`/`jackknife` fits on the OR scale, the collection's result labels and levels left unchanged by `regtab`, `hetprobit`/`qreg`/`ivregress` methods nouns, and `~` rendering literally under GFM strikethrough (via `tools/check_md_render.py`). |
| `test_codex_audit_2026_09_26.do` | The nine Codex-audit findings of 2026-09-26: variable, value and collected labels holding a `$global`, backticks and quotes reach frames, xlsx, CSV and Markdown as typed in every table command; `frame()`/`eplotframe()` refused before any file is written (checksummed sentinels); `puttab` all-missing observations kept as Markdown rows; `puttab` `if`/`in` on source observations and `noembedheader`; `survtab` `by()` with no failures; `effecttab` numeric returns independent of `digits()` and `from()` range checks; `stacktab` top-level, quote-aware block parsing. Read back with `tools/xlsx_facts.py`, `tools/md_facts.py` and a field-level CSV parser. |
| `test_codex_parity_2026_09_26.do` | Scale edge cases from the R port's Codex audit: `table1_tc` weighted median and IQR unchanged when every weight is multiplied by 1e-12 to 1e-300 (overall and within `by()`), and automatic typing unchanged when values are multiplied by 1e100, 1e200 or 1e-100, in both the moment branch (over 5,000 values) and the Shapiro-Wilk branch. Oracles: `_pctile` on rescaled weights, hand moments, `swilk` on the unscaled variable. |
| `test_open_items_2026_09_27.do` | Open items after 68c37a90, from the R port: `regtab` classifies `clogit` like `logit` (OR header, odds ratios, `dimnonsig` null 1, no intercept beside `logistic`, "conditional logistic regression"); `comptab` vertical Reference merges per model, `r(sheet)` in the workbook's spelling, `eplotframe()` rows once in frame order, `modelf:rames` in help; `stratetab` reads `set dp comma` levels, handles an empty comparison exposure, marks rateratio frames `irr_ci` (refused by `comptab`), prints `0.0 (–)` for boundless zero-event rates, flattens the Markdown header, draws exposure rules from row positions, rounds at the exact unit, and splits a quoted `outcomeids()` list. |
| `test_codex_audit_2026_09_27.do` | The thirteen Codex-audit findings of 2026-09-27 (2.1.14), each failing before its fix: `survtab` RMST SE and CI against `stci, rmean` at a double event time, with `stset, id()` and delayed entry; `survtab` no-failure guard with failures only in missing-`by()` rows; `desctab`/`table1_tc` chi-square and Fisher tests on the displayed single Missing category, group codes above `c(maxlong)`, translation-invariant SDs against `summarize` (unweighted and `wt()`), and the caller's `e(b)`/`e(V)`/`e(sample)` and `predict` intact on success and failure; `effecttab, full` keeps same-named coefficients of every `teffects` equation (RA, AIPW) in `r(table)`, the plot frame and CSV, and reads relabelled `cmd`/`cmdline` metadata by level; `regtab`/`comptab` keep `y` and `Y` as distinct identities; `regtab` over 36k GEE working-correlation items in bounded time, with the fast collection reader matching the full scan; `stacktab columnmerge()` headers holding backticks, `$names`, quotes and quoted backslashes, and `style()` rejecting unknown, prefixed, trailing and duplicate groups; `puttab` on a sheet named `A"B`. Cells, sheet names and widths read back with openpyxl and compared in Mata. |
| `test_tabtools_state_sweep.do` | Session fingerprint (`_qa_state.do`) of all 14 public commands on a success and an early-error path, with a foreign active `regress` (predict round trip), a user matrix `T`, a scalar `table`, a user global and `varabbrev on` planted; only `r()` and Stata's own `S_#` saved-result globals may change. At pre-fix `166dfd10` it fails `desctab` and `table1_tc` (F07, e() replaced) and `stacktab` (F13, unknown `style()` group accepted). |
| `test_tabtools_surfaces.do` | Surface parity (`qa_surface_parity`) of one published value per command across `r()`, frame, CSV, workbook and console against native oracles (`correlate`, `tabulate`, `teffects` e(b), `regress`, `sts`, `stci`, the rate design, the source workbook) for `corrtab`, `crosstab`, `desctab`, `effecttab`, `puttab`, `regtab`, `stacktab`, `stratetab`, `survtab`, `tabtools`; hostile fixtures (`qa_hostile_missing`, `qa_hostile_codes`, `qa_hostile_times`, `qa_shift_invariance`); the `qa_hostile_strings` corpus through every `title()` (read back from the workbook), `stacktab columnmerge()` and `puttab sheet()`; `regtab` lifecycle (`qa_lifecycle`); `qa_counterfeit_twin` case twins through `regtab`/`comptab`. At `166dfd10` it fails F01, F02, F04, F05, F06, F09 and F10. Its two former open-ledger blocks (`puttab sheet()` re-expansion, `crosstab, trend missing`) were closed in 2.1.16 and now require the fixed behaviour. |
| `test_review_2026_09_29.do` | Reviewer findings of 2026-09-29 (2.1.15), each failing before its fix (18/18 red on 2.1.15): loading any shipped `.ado` leaves `matastrict` as found, and a caller's undeclared Mata function still compiles after the commands autoload; `crosstab, cochran` with a decreasing trend against R's `prop.trend.test` (chi2 20) and, for a 2x2 table, against `tabulate, chi2`; `trend` or `cochran` with `missing` refused; `crosstab` OR/RR/RD and Cochran-Armitage, `survtab by()`, and the `desctab`/`table1_tc` categorical SMD on fractional float levels equal to their integer-coded twins (`cc`/`cs` for the association measures); hostile `sheet()` names (a `$global`, a `` `name' `` pair, an unbalanced backtick, a double quote) written and returned byte for byte by `corrtab`, `crosstab`, `table1_tc`, `puttab`, `stacktab` (create and `append`), `regtab`, `effecttab`, `survtab`, `stratetab` and `comptab`, read back with `import excel, describe`. |
| `test_review_2026_08_13.do` | Disclosure-reconstruction attacks and correlation-star regression contracts. |
| `test_review_2026_09_15.do` | Treatment controls, raw coefficient identities, case and name collisions, cleared-data labels, and shipped-header agreement. |
| `test_review_2026_09_25_rates_puttab.do` | Label-matched `hrcomptab` HR placement against `stcox`, caller data/`c(filename)` preservation, `frame()`-scoped `if`/`in`, `%t` dates and negative zero in `puttab`, staged `stratetab` frames, and `strate` per(k) scaling. |
| `test_smallcells.do` | Small-cell parsing, masking, irredundancy, compositions, sink parity, and leak attacks. |
| `test_smallcells_derivable.do` | `desctab`/`table1_tc` `smallcells()` on counts that are not printed but follow from printed ones, each failing before its 2.1.17 fix (8/11 red on 2.1.16): an independent attacker reads only the published frame and recovers the missing count (group N minus printed levels, or from column percentages) and a binary's negative and missing counts (from `n/N` or the denominator `n (pct)` releases); the action-note fixtures, `missingsummary`/`slashN` cells unchanged, no over-protection when hidden counts are 0 or at least k, group and total N printed under `total()` with a second variable that adds back to them, `_tabtools_smallcells, fixedmargins` never withholding column or grand margins, r(498) naming the variable when only withholding N would protect it (data and `varabbrev` intact), a seeded sweep of 40 fixtures by 7 routes (516 recoverable counts on 2.1.16, none now), and `wtcompare` refused without `wtn`/`percent_n`. |
| `test_stacktab.do` | Workbook block assembly, stacking, column merging, Markdown, and frame guards. |
| `test_stratetab.do` | Rate-file workflows, multi-outcome scaffolds, ordering, sheets, and cleanup. |
| `test_survtab.do` | Kaplan-Meier, medians, RMST, events, risks, frequency-weighted expanded-data equivalence (RMST/CI, returned counts, complete rendered tables, and known event/risk counts), unsupported stset weights, formatting, and collisions. |
| `test_synthesis_review.do` | Caller-visible errors, sink shapes, escaping, formatting, and stack previews. |
| `test_table1_tc.do` | Front-end descriptive behavior, weights, formatting, SMDs, missingness, and historical regressions. |
| `test_table1_overflow.do` | `table1_tc` weighted cells when sums, products or squares exceed the double range: mean/SD, quantiles, `wtn`/`percent_n` effective counts, ESS, and the honest missing values that must stay missing. |
| `test_tabtools.do` | Controller listing, persistent defaults, profiles, reloads, and error guards. |
| `test_tabtools_documentation_examples.do` | Executable help examples and documented workflow contracts. |
| `test_tabtools_errors.do` | Exact association-measure errors, legal inverse input, and data preservation. |
| `test_tabtools_oracle.do` | Seeded command-catalog and category return-surface oracle. |
| `test_tabtools_tips.do` | Quick-reference behavior, README Quick Start, and fresh-session recipes. |
| `test_tabtools_v1163.do` | Missing-summary row attachment and group-specific count regression. |
| `test_tabtools_v202.do` | Caller Mata namespace preservation, unconditional stored results, and atomic multi-sink composition. |
| `test_theme_removed.do` | Rejection of the removed `theme()` surface. |
| `test_xlsx_style_compaction.do` | Style-pool compaction, workbook equivalence, verification guards, and platform paths. |
| `test_xlsx_deferred_styles.do` | Deferred (direct-XML) cell styling: rendered parity with immediate `xl()` styling for all rule operations, a 3,000-row styled table, the `xl()` fallback, `xl()`-rejected color names, stale-queue and invalid-rule guards. |

### Validation

| File | Covers |
|---|---|
| `validation_corrtab.do` | Correlations, symmetry, and p-values against native and closed-form oracles. |
| `validation_crosstab.do` | Hand-computed odds/risk measures, chi-squared statistics, and counts. |
| `validation_effecttab.do` | Treatment-effect values, standard errors, intervals, and stored results. |
| `validation_package.do` | Cross-command identities, sanity bounds, type detection, settings, and frame preservation. |
| `validation_regtab.do` | Coefficients, intervals, p-values, fit statistics, Excel values, and display precision. |
| `validation_regtab_return_contracts.do` | Exact OLS fit statistics, Cox event counts, and MI returns against the collected fits. |
| `validation_smallcells.do` | Bounded exhaustive safety and irredundancy oracles for disclosure control. |
| `validation_stratetab.do` | Rate scaffold structure, contents, and returns. |
| `validation_survtab.do` | Survival estimates, conservation, log-rank tests, RMST, Excel values, and rendering. |
| `validation_table1_tc.do` | Descriptive statistics, Yang–Dalton SMDs, coding invariance, identities, and Excel cells. |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_tabtools.do` + `crossval_tabtools_companion.R` | Fresh R formulas and Python statsmodels parity for statistical and model-fit contracts. |
| `crossval_crosstab_cochran.do` + `crossval_crosstab_cochran.R` | Native R `stats::prop.trend.test` parity under score translation, scaling, and direction changes. |

### Support and benchmarks

| Path | Contents |
|---|---|
| `run_all.do` | Curated lane manifest, sandbox installer, skip policy, and terminal status writer. |
| `benchmark_tabtools_speed.do` | Timing guardrail included only in `release`/`benchmark`. |
| `_visual_stress_gen.do` | Manual disposable workbook generator; not a gate. |
| `tools/` | Package-local Excel, Markdown (`check_md_render.py`, `md_facts.py`), SMCL-width, demo, style, crossval, and option-coverage validators. |
| `tools/check_suite_result.py`, `tools/runner_fixture.py` | Runner receipt validator, controlled child generator, and private Stata driver for its regression suite. |
| `data/`, `baseline/`, root QA fixtures | Tracked oracle inputs and semantic artifact summaries governed by `fixtures_manifest.md`. |
| `CROSSVAL_MODULE_MAP.md`, `TOLERANCE_FRAMEWORK.md` | Oracle ownership and numerical tolerance policy. |
| `clean_artifacts.sh`, `.gitignore` | Recoverable artifact cleanup and generated-file policy. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `table1_tc` | `test_table1_tc`, `test_smallcells`, `test_smallcells_derivable`, `test_tabtools_v1163`, `test_table1_overflow`, `test_codex_parity_2026_09_26`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29` | `validation_table1_tc`, `validation_smallcells` | `crossval_tabtools` | helpers, integration, adversarial, deep audit, release, output sinks, follow-ups, codex audit |
| `desctab` | `test_desctab`, `test_smallcells_derivable`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29` | `validation_table1_tc`, `validation_smallcells` | — | helpers, integration, option coverage, output sinks, follow-ups, codex audit |
| `crosstab` | `test_crosstab`, `test_review_2026_09_29`, `test_review_2026_10_01_statistics` | `validation_crosstab`, `validation_smallcells` | `crossval_tabtools`, `crossval_crosstab_cochran` | integration, adversarial, deep audit, output sinks, follow-ups, codex audit |
| `corrtab` | `test_corrtab`, `test_review_2026_09_29` | `validation_corrtab` | `crossval_tabtools` | integration, adversarial, output sinks, follow-ups, codex audit |
| `regtab` | `test_regtab`, `test_regtab_omitted`, `test_regtab_multieq_mixed`, `test_regtab_backlog_2026_09_26`, `test_followups_2026_09_27`, `test_review_2026_09_26_fixes`, `test_open_items_2026_09_27`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29`, `test_review_2026_10_01_models` | `validation_regtab`, `validation_regtab_return_contracts` | `crossval_tabtools` | helpers, integration, adversarial, deep audit, release, output sinks, codex audit |
| `effecttab` | `test_effecttab`, `test_effecttab_omitted`, `test_effecttab_layout`, `test_audit_2026_09_26_fixes`, `test_followups_2026_09_27`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29`, `test_review_2026_10_01_models` | `validation_effecttab` | `crossval_tabtools` | integration, adversarial, output sinks, codex audit |
| `survtab` | `test_survtab`, `test_output_sinks_markdown`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29` | `validation_survtab` | `crossval_tabtools` | integration, adversarial, deep audit, follow-ups, codex audit |
| `stratetab` | `test_stratetab`, `test_audit_2026_09_26_fixes`, `test_open_items_2026_09_27`, `test_review_2026_09_29`, `test_review_2026_10_01_statistics` | `validation_stratetab` | `crossval_tabtools` | integration, adversarial, deep audit, output sinks, follow-ups, codex audit |
| `hrcomptab` | `test_hrcomptab` | — | — | integration, adversarial, output sinks, follow-ups, codex audit |
| `comptab` | `test_comptab`, `test_open_items_2026_09_27`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29`, `test_review_2026_10_01_composition` | `validation_package` | — | integration, adversarial, output sinks, follow-ups, codex audit |
| `puttab` | `test_puttab`, `test_puttab_stacktab_2026_09_27`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29` | — | — | helpers, release, output sinks, follow-ups, 2.1.12 review fixes (Markdown `~`), codex audit |
| `stacktab` | `test_stacktab`, `test_puttab_stacktab_2026_09_27`, `test_codex_audit_2026_09_27`, `test_review_2026_09_29` | — | — | release, output sinks, follow-ups, codex audit |
| `tabtools` | `test_tabtools`, `test_tabtools_oracle` | `validation_package` | — | integration, release |
| `tabtools_tips` | `test_tabtools_tips` | — | — | release |

Adversarial axes, in cells (`check qa tabtools --view axes`: 54/54 owed cells probed): fingerprint 14 commands × 2 paths; parity 10/10 commands; hostile strings 10/10 commands through `title()` plus `columnmerge()` and `sheet()` (the 2 blocks that held open findings were closed in 2.1.16); hostile fixtures 4/4 (`corrtab`, `crosstab`, `desctab`, `survtab`); lifecycle `regtab` 1/1. The `desctab` lifecycle cell counts as probed only because the view's source window sees `qa_lifecycle` near a `desctab` call: `desctab` keeps no stored results, cache or file between calls (its `_dta[]` characteristics go to its own output frame), so a lifecycle block does not apply to it.

## Lane membership

`quick` is contained in `core`, `core` in `full`, and `full` in `release`; the explicit file list in `run_all.do` is authoritative.

| Lane | Suites |
|---|---|
| `quick` | Functional/regression suites except the adversarial sweep. |
| `core` | All functional/regression and known-answer validation suites. |
| `full` | All functional/regression suites, validation suites, and external cross-validation; default correctness gate. |
| `release` | `full` plus the timing benchmark. |
| `benchmark` | Timing benchmark only; run on demand. |

## Known gaps

The [2026-10-01 QA and review report](review_2026_10_01.md) records the bug regressions, numerical reference scope, review identity, and observed lane results.

Platform behavior outside the local Stata 17 Linux installation remains untested. The 2026-09-28 `puttab, sheet()` re-expansion and the Muse I1 `crosstab, trend missing` ledgers were fixed in 2.1.16 (`test_review_2026_09_29.do`), and `qa_surface_parity` now accepts a quoted sheet name with spaces (`d7e252c1`).

## Coverage verification

`tools/option_coverage.py` parses each public syntax surface and requires a real same-command invocation; `test_package_release.do` independently gates help rendering and synopt widths with positive controls.

```bash
python3 tools/option_coverage.py
python3 tools/check_sthlp_width.py ..
```

archetypes: A7(crosstab corrtab puttab desctab table1_tc tabtools survtab stratetab hrcomptab stacktab tabtools_tips) A6(puttab effecttab comptab) A1(regtab)

## Canonical fixture adoption

Exact sparse-code cross-tab counts, Spearman/pairwise N including undefined all-missing column, and actual workbook/CSV/Markdown coefficient cells with user/unrelated sheets preserved. These are implemented suites; independent adoption signoff is pending. Remaining unexercised public routes and generic minima remain visible in the fixture census.

| File | Coverage | Lanes |
| --- | --- | --- |
| `validation_tabtools_fixture_contract.do` | Canonical fixture truth and hostile contracts | quick/core/full/release |

| `validation_tabtools_fixture_descriptive.do` | Exact sparse-column N and mean±SD cell text, all-missing blanks and single-level refusal, desctab/front-end routes, all canonical LABELLED variants with full caller fingerprints | quick/core/full/release |

| `validation_tabtools_fixture_models.do` | Exact four-column ESTMAT payloads including permuted stripes/missing/unbounded limits, independent Gaussian sample OLS/Student intervals/p-values and sparse identities, selected composite cells, data-independent catalogue inventory; full caller fingerprints | quick/core/full/release |

| `validation_tabtools_fixture_catalogue_primitives.do` | Dataset-independent14-command/category identity and rendered tips contract across actual case/32-byte names, sparse signed codes, opaque strings, missing/one-row callers; full fingerprints | quick/core/full/release |
| `validation_tabtools_fixture_numeric_primitives.do` | Exact case/32-byte stripe identity and Pearson correlations, signed large-code count cells, all nine opaque label bytes, long-name means and explicit signed-group refusal with positive large-code mirrors | quick/core/full/release |
| `test_tabtools_fixture_files.do` | Both Excel spellings, exact correlation/count/mean workbook cells, stale report-sheet replacement, user sheets, extensionless and hostile filename refusals, owned-tree bytes and caller fingerprints | quick/core/full/release |
| `test_tabtools_fixture_path_macros.do` | Literal dollar/backtick paths with absent/opaque/matching macros, shared validator and all three writer alias routes; named198 causes and unchanged trees and non-r caller state | quick/core/full/release |
| `test_tabtools_fixture_rreturns.do` | Both Excel aliases refuse hostile filenames with original198 and exact empty/populated scalar/macro/matrix r() plus other caller-state equality; snapshot after logopen and comparison before logclose | quick/core/full/release |
| `test_tabtools_fixture_publication.do` | Populated caller r() is replaced by exact analytic scalars/matrices/macros on success and retained after named native16106 workbook-save failures; other caller state and file contents unchanged | quick/core/full/release |
| `validation_tabtools_fixture_domains.do` | Nine actual option sweeps (67 cells): numeric endpoints, missing/special values, invalid controls and exact correlation/count/ANOVA/suppression content; canonical domain helper | quick/core/full/release |
| `test_corrtab_fixture_stars.do` | Exact one/two/three significance-symbol counts and full-r caller fingerprints on distinct duplicate/four-threshold refusals with named198 causes | quick/core/full/release |
| `validation_corrtab_fixture_inputs.do` | Independent60-digit signed/large-code Pearson and tied-rank Spearman recovery, supported single-row missing C/P and N1 across frames/workbook/CSV/Markdown and accepted undefined components beside finite diagonals | quick/core/full/release |
| `test_corrtab_fixture_legacy.do` | Fresh absent/numeric/opaque native S_1/S_4/S_6 on Spearman success, early198, supported single-row N1 and late16106, with exact analytical/state/tree assertions | quick/core/full/release |
| `validation_tabtools_fixture_fonts.do` | Eight actual workbook writes check default/Latin/spaced/Unicode font bytes in native styles, exact report values and preserved user sheets/unrelated files; nominal string domain | quick/core/full/release |
| `validation_tabtools_fixture_strings.do` | All nine opaque variable-label byte strings in actual count/mean frames, exact numerical payloads and full caller fingerprints across crosstab/desctab/table1_tc | quick/core/full/release |
| `validation_tabtools_fixture_remaining.do` | Explicit canonical survival adapter: exact KM/RMST/logrank and event/person-time rates, symmetricHR composition, documented blank-category refusal, all six workbook cells/stale sheet/user sheet/stem preservation, real tips text | quick/core/full/release |
| `test_survtab_fixture_state.do` | Empty/foreign estimates; absent/opaque/empty legacy globals with long-name twins; native KM/RMST/median results and early/late rc preserved | quick/core/full/release |

## Numerical precision suites

These suites compare actual returned, dataset, text or workbook values to independently derived numerical truth. The runner defines their lane membership.

| File | Scope | Cases | Lanes |
| --- | --- | --- | --- |
| `validation_tabtools_precision.do` | Twelve public numerical writers: raw frame/table cells and strict independently calculated workbook values. PutTab checks its documented 6-place text. | 14 | core/full/release |
| `validation_stacktab_precision_controls.do` | Mixed signed/tiny/large/blank cells, independent daily calendar dates plus native formatted-string parity, exact default preformatted strings. | 3 | core/full/release |
