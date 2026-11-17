# psdash QA

<!-- archetypes: A1 A3 -->

The `psdash` QA suite is flat and concern-oriented: functional, regression, validation, and external-parity suites live at the `qa/` root and are driven by one curated runner. Every suite is independently runnable from this directory.

## How to run

```bash
cd psdash/qa
stata-mp -b do run_all.do             # full lane (default release gate)
stata-mp -b do run_all.do quick       # Stata functional and validation lane
stata-mp -b do test_psdash.do         # one suite, standalone
python3 -m _devkit.stata_dev_cli run qa psdash --repo tools --mode full --isolated
```

The legacy `external` lane runs only the external-oracle suites; `full` is `quick` plus `external`. Gate on the final `RESULT:` sentinel, not the process exit code alone.

## Isolation

`run_all.do` writes suite logs in the current `qa/` directory, so concurrent runs of the same lane can corrupt one another. For release evidence use the isolated CLI command above, which creates a scratch tree, removes copied logs and `run_all_status.txt`, and preserves the repository layout; disagreement between `run_all.log` and a suite log is evidence of a collision.

| Sibling | Required by | Behavior if absent |
|---|---|---|
| `iivw`, `msm`, `tte`, `targetlearn` | Producer-contract and real-integration suites; `targetlearn` supplies both `tmle` and `ltmle` | The unavailable producer case is recorded as a skip; the isolated release tree must include every available sibling. |
| `_data`, `tabtools` | Documentation/install and shared release-surface checks | Missing siblings are a hard failure in the isolated release tree. |

## Conventions

- `test_*` is functional or regression coverage; `validation_*` is a known-answer or invariant oracle; `crossval_*` compares against an independently implemented R/Python oracle.
- Every runnable suite emits exactly one terminal `RESULT: <name> tests=N pass=N fail=N [skip=N]` line before closing its log and exits nonzero on failure. `full` accepts no suite-level dependency skip.
- Suites sandbox PLUS and PERSONAL under `c(tmpdir)` through `_psdash_bootstrap.do`, reinstall `psdash` from the local package directory, and restore the caller's paths during cleanup.
- Paths derive from `c(pwd)`; data are generated at runtime except for explicitly named sibling-package fixtures.
- `STATA_QA_DATA` (environment variable) is a local directory of third-party QA source data, laid out `<package>/<set>/<file>`; it is not distributed with the repository. `_psdash_qa_extdata.do` looks there first, then falls back to a public download or an R regeneration, and checks every file it finds against a recorded byte length and Stata `checksum` CRC (r(459) on mismatch).
- Generated logs, workbooks, graphs, and datasets are disposable and gitignored; only deliberate `demo/` documentation assets may be tracked.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `quick` / `test_excel_fidelity.do` | Python 3 and `openpyxl` | Suite failure. |
| `external` / `crossval_cobalt.do`, `crossval_public_studies.do`, `crossval_binary_balance_cobalt.do` | `Rscript` and R packages `cobalt` (and `MASS` for the first two); `crossval_binary_balance_cobalt.do` also needs the NSW/CPS data (`STATA_QA_DATA`, else network download from users.nber.org) | Lane exits with dependency skip. A file failing its length/checksum guard is a suite failure. |
| `external` / `crossval_longitudinal_cobalt_weightit.do` | `Rscript` and R packages `cobalt` and `WeightIt`, plus the sibling `msm` package (and `tte` for its scenario) | Lane exits with dependency skip when R or its packages are missing; a scenario whose sibling producer is absent is skipped; if no scenario runs, the suite fails. |
| `external` / `crossval_multigroup_published_twang.do` | `STATA_QA_DATA` (`multigroup/aod_twang_ate_weights.csv`), else `Rscript` and R package `twang` 2.6.2 to regenerate it; the regeneration guard also needs `Rscript` and `twang` 2.6.2 | Neither source: dependency skip (exit 77). With the data but without R, the guard is skipped (partial receipt). A fixture failing its length/checksum guard is a suite failure. |
| `external` / `crossval_crump_rhc_published_support.do` | `STATA_QA_DATA` (`crump_rhc/rhc.csv`), else network download from hbiostat.org | Neither source: dependency skip (exit 77). A file failing its length/checksum guard is a suite failure. |
| `external` / `crossval_binary_balance_published_imbens2015.do` | `STATA_QA_DATA` (`binary_balance/nsw_dw.dta`, `cps_controls.dta`), else network download from users.nber.org | Neither source: dependency skip (exit 77). A file failing its length/checksum guard is a suite failure. |
| `external` / `crossval_external_references.do` | Python 3, NumPy, pandas, statsmodels, and scikit-learn | Suite failure after the Python reference command cannot create its oracle files. |
| `external` / `crossval_python_psdash.do` | Python 3 standard library | Lane exits with dependency skip. |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_v174_review_regressions.do` | One-arm degeneracy, complete-matrix weight scale invariance including incomplete covariates, and Crump first crossing; quick/full. |
| `test_psdash.do` | Public binary commands, options, dispatch, returns, and exports. |
| `test_adversarial.do` | Invalid inputs, boundary cases, state cleanup, and router failures. |
| `test_binary_balance_weights_adversarial.do` | Binary balance and weight edge cases. |
| `test_combined_threshold_contract.do` | Combined threshold overrides and multi-group GPS verdict semantics. |
| `test_detect_dispatch_adversarial.do` | Installed autoload, detection contexts, and dispatcher routing. |
| `test_documentation_examples.do` | Exact README binary quickstart and multi-group recipe with convergence, sample, mapping, and diagnostic-result assertions. |
| `test_excel_fidelity.do` | Workbook schema, numeric cells, presentation, and exact combined-report titles on all binary and multi-group sheets. |
| `test_iivw_contract.do` | Genuine, stale, tampered, and explicit-override iivw contracts. |
| `test_psdash_nullcase.do` | Degenerate-artifact (fail-open) contracts for `psdash weights`: `wvar()` combined with `iivwcomponent()` is refused instead of silently letting the component selection win, unsigned `_dta[_iivw_*]` characteristics cannot select the component, an explicit `wvar()` alone is still honoured, and the `_psdash_require_meta` helper contract. |
| `test_msm_tte_contract.do` | MSM/TTE contract rejection and manual override behavior. |
| `test_multigroup_balance_weights.do` | Multi-group balance and weight summaries. |
| `test_multigroup_detect.do` | Multi-group input mapping and detection. |
| `test_multigroup_overlap_support.do` | Multi-group overlap, support, trimming, and returned metrics. |
| `test_multigroup_psvars_regression.do` | Generalized-score orientation and `psvars()` regressions. |
| `test_overlap_support_multigroup_adversarial.do` | Binary and multi-group overlap/support edge cases. |
| `test_producer_contracts.do` | Compatibility-matrix rows, version gates, and installed producer guards. |
| `test_qa_contract_gaps.do` | Return-surface gaps and QA sentinel integrity, including the parser-readability scan over every suite sentinel. |
| `test_rb01_verdict.do` | Unified machine-readable findings and zero-panel rejection. |
| `test_quiet_warnings.do` | `quietly` suppresses the panel Warning lines and the verdict word on overlap, weights, support and balance; r(n_warnings) keeps the findings. |
| `test_rb02_gps_positivity.do` | Full-vector generalized-positivity findings. |
| `test_rb03_factor_expansion.do` | Factor-variable expansion and detection. |
| `test_rb0405_teffects_sample.do` | Teffects estimation-sample fidelity and exclusion ledger. |
| `test_rb06_estimand.do` | ATE/ATT/ATC weight formulas and estimand behavior. |
| `test_rb08_vr_count.do` | Variance-ratio count and adjusted/raw status selection. |
| `test_rb09_weight_thresholds.do` | Weight dominance, per-arm ESS, cutoffs, and undefined weights. |
| `test_rb10_longitudinal.do` | Longitudinal period mapping, ESS, and missingness. |
| `test_rb11_trim_guard.do` | Trimming guards that preserve treatment-arm identifiability. |
| `test_rb12_kimi_audit.do` | GPS mapping, common samples, trimming, and report regressions. |
| `test_real_producer_integrations.do` | Genuine iivw, msm, tte, tmle, and ltmle executions when present. |
| `test_refactor_display_contracts.do` | Display text and presentation contracts. |
| `test_refactor_doc_contract.do` | Help/README syntax, option, return, and distribution contracts. |
| `test_refactor_graph_export_failures.do` | Analytical returns and cleanup after graph-export failures. |
| `test_refactor_install_autoload.do` | Installed-user discovery of public commands and helpers. |
| `test_refactor_option_abbrev_contract.do` | Documented option abbreviations and parser behavior. |
| `test_refactor_qa_bootstrap_contract.do` | Isolated install bootstrap and cleanup. |
| `test_refactor_return_contracts.do` | Public scalar, macro, and matrix return contracts. |
| `test_release_combined.do` | Combined-report failure payloads, period-name collision rejection, and longitudinal scale invariance. |
| `test_release_detect.do` | Empty/incomplete score rejection and repeated detector-state clearing. |
| `test_release_numeric.do` | Extreme-scale weight diagnostics and missing numeric-option rejection. |
| `test_remaining_audit_regressions.do` | Residual audit findings not owned by a narrower suite. |
| `test_return_surface_remaining.do` | Remaining conditional and failure-path return surfaces. |
| `test_saving_format_contract.do` | Saving extensions, replace parsing, and graph formats. |
| `test_tmle_ltmle_contract.do` | TMLE/LTMLE contract rejection and manual override behavior. |
| `test_v130_features.do` | Export/report and feature regressions introduced around v1.3.0. |
| `test_v140_features.do` | Variance-ratio, weight-cutoff, quantile-support, and related regressions. |
| `test_v141_features.do` | Option usability and documentation regressions. |
| `test_v164_regressions.do` | Treatment-only dispatch, built-in estimation samples, Crump alpha zero, point support, and source corrections. |
| `test_v169_regressions.do` | Varabbrev cleanup, option-combination errors, quoted Excel titles, internal program classes, and help rendering. |
| `test_v171_audit_regressions.do` | Multi-group weight boundaries and ledgers, factor-variable endpoints, reduced-arm mlogit rejection, and stable detect labels. |
| `test_v173_audit_regressions.do` | Exact common-support bounds (overlap, support, qtrim, `generate()`, multi-group, longitudinal) against a scalar oracle, two-valued double covariates classified binary, treatment-only `matched` balance, `strategies()` boundary refusal, weighted KS against an independent ECDF, value-labelled raw/adjusted multi-group Love plots, verbatim hostile value labels, whole-count histogram axes, and separated, aligned balance-table cells. |
| `test_v180_regressions.do` | Scheme-driven series colours, Love-plot labels, `balance` with `nograph`, support reference-line legend entry, and multi-group legend text; every graph assertion reads the exported SVG; quick/full. |
| `test_v181_regressions.do` | Support graph (and the combined dashboard support panel) labels the x axis over the full 0 to 1 scale so the Crump and common-support lines sit inside the drawn axis, and a user `xlabel()` still overrides; reads the saved graph; quick/full. |
| `test_v190_overlap_support_graphs.do` | Aligned overlap-histogram bins, labelled common-support bound keys that render as dashes in the dashboard, canonical multi-group arm colours in box plots, explained positivity-floor lines, and the shared multi-group density legend; reads saved graphs and exported SVGs; quick/full. |
| `test_v190_weights_graphs.do` | Within-arm fraction histograms on both routes, default label formats and text sizes, the weight = 1 and omitted-tail notes (including a user `xlabel()`), and statistics unchanged by the display range; quick/full. |
| `test_v190_balance_graphs.do` | Love-plot x range fitted to 0, the threshold and every plotted SMD (no fixed ±0.5 floor), shaded \|SMD\| < threshold band replacing the threshold lines, height scaled to the covariate count, single shared legend and raw-vs-weighted styling on the distribution graph, dodged multi-group comparisons with raw-to-adjusted connectors, and unchanged balance returns; quick/full. |
| `test_v190_dashboard_summary.do` | Binary dashboard Diagnostic Summary scorecard (verdict equals `r(verdict)` for PASS and FAIL, rows for executed panels only), `supportgraph` restoring the support density panel, `nooverlap` moving the support graph into the overlap slot, unchanged multi-group layout and `r()` returns, and longitudinal rejection; quick/full. |
| `test_v191_balance.do` | Two-level non-dyadic and constant covariates (exact SMD/VR/KS), two-level `VR_Adj` single-observation guard, missing `r(max_vr_*)` with no assessable VR, omitted `o.x` terms, `distribution()` naming and `title()` on one variable, `strategies()` zero-weight arm refusal, and K = 2 non-0/1 positivity counts and recode messages; quick/full. |
| `test_v191_detect_weights.do` | No leaked `_psdash_ps_*` after multi-valued `teffects`, post-`mlogit` weight generation and K > 2 `atc` refusal, `e(cmdline)` weight expressions, `reference()` on 0/1 treatments across routes, all-missing PS, `trim(0)`/`truncate(0)` range errors, K = 2 non-0/1 weight positivity, `generate()` collision and early-error rules, and the binary `xlsx()` rows; quick/full. |
| `test_v191_overlap_support_combined.do` | Float non-integer longitudinal periods, missing `r(max_pct_outside)` without two-arm periods, `auto-generated` labels instead of tempvar names in combined output and report sheets, combined `threshold()` validation with the balance panel skipped, `report()` write-failure handling, support `generate()`/`threshold()`/`qtrim()` validation, `sheet()` and quoted `title()` handling, quiet compact overlap, and longitudinal option refusals; quick/full. |
| `test_v192_weights_balance_combined.do` | Case-insensitive `estimand()` in weights/balance/combined and the multi-group ATT `stabilize` refusal, user `xscale()` axis control in weights graphs, `distribution()` legend/combined scheme from `graphoptions()`, missing `r(max_smd_*)`/`r(max_ks_*)` when undefined, K >= 10 Love-plot markers, binary `psvars()` note, `xlsx()` after a failed `saving()`, and quoted `title()` on the cross-sectional and longitudinal combined routes; quick/full. |
| `test_v192_detect.do` | Lower-case `r(estimand)`, `r(n_estimation)`/`r(n_excluded)` after auto-detection, missing PS excluded from near-boundary counts, active `tmle`/`ltmle` ignoring stale `_dta[]`, reduced-arm and `control(1)` `teffects`, `e(cmdline)` parsing (`(treat, logit)`, options, `if(...)`), producer `estimand()` conflicts, contradictory positional/`psvars()` inputs, `reference()` arity, `psdash , option`, and grouped factor notation; quick/full (exit 77 when a producer is unavailable). |
| `test_v192_overlap_support.do` | Case-insensitive `estimand()` in overlap/support including `compare` ESS weights, singleton post-trim arm refusal before `generate()` mutates data, non-finite `bwidth()`, the undefined-IPTW ESS note, the Crump no-interior-PS error, multi-group mean-GPS header widths, and `xlsx()` after a failed `saving()`; quick/full. |

### Validation

| File | Covers |
|---|---|
| `validation_psdash.do` | Broad hand-calculated binary and multi-group invariants. |
| `validation_known_answers.do` | Focused known-answer overlap, balance, weights, support, and Crump results. |
| `validation_extended_known_answers.do` | Extended row-level and boundary known answers. |
| `validation_method_contracts.do` | Documented estimator definitions and invariant contracts. |
| `validation_multigroup_longitudinal.do` | Multi-group and longitudinal known-answer matrices and counts. |
| `validation_public_known_answers.do` | Exact tied-AUC, quantile-support, and uneven-group ESS answers. |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_cobalt.do` | R `cobalt` binary and pairwise multi-group SMD, variance-ratio, and KS parity. |
| `crossval_external_references.do` | statsmodels/scikit-learn reference datasets and independently calculated diagnostics. |
| `crossval_public_studies.do` | R/cobalt parity on the public Lalonde job-training and MASS low-birth-weight study data. |
| `crossval_python_psdash.do` | Independent Python formula implementation for core diagnostics. |
| `crossval_binary_balance_cobalt.do` | R `cobalt` parity on the vendored Dehejia-Wahba NSW/CPS data (fitted ATT and ATE IPTW weights): raw and weighted mean, SMD and KS for all rows, VR for continuous rows. |
| `crossval_longitudinal_cobalt_weightit.do` | R `cobalt` and `WeightIt` parity for `psdash combined` longitudinal period counts, PS means, weight summaries, quantiles and ESS on real msm, heavy-tailed msm, and (when a sibling `tte` is present) tte producer output. |
| `crossval_binary_balance_published_imbens2015.do` | Published reproduction of Imbens (2015) Tables 10 and 16 (raw means, SMD, VR) on the NSW/CPS data; tolerance half a printed unit, plus 0.0028·\|SMD\| on binary rows for the p(1-p) vs n-1 variance convention. Weighted balance has no published target here. |
| `crossval_crump_rhc_published_support.do` | Published reproduction of Crump et al. (2009) §4 on the right heart catheterization data: 72-covariate logit coded per Li, Morgan and Zaslavsky (2018), alpha-hat 0.1026 to one 0.001 grid step, the 18% trimmed share, and Table 2 cells exact (870/40, 2671/2057, 10/87). |
| `crossval_multigroup_published_twang.do` | Published reproduction of the twang `mnps` AOD tutorial (Burgette, Griffin and McCaffrey, twang 2.6.2 vignette, §2.3; method of McCaffrey et al. 2013): 3-arm pairwise weighted means and KS against the printed `bal.table`, at half a printed unit. SMD and VR are not asserted (twang pools the SD over all arms). |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Explicit quick, external, and full lane membership and final sentinel. |
| `_psdash_bootstrap.do` | Relocatable PLUS/PERSONAL sandbox, local install, and cleanup. |
| `_cobalt_reference_psdash.R` | R `cobalt` oracle writer. |
| `_external_reference_psdash.py` | NumPy/pandas/statsmodels/scikit-learn reference generator. |
| `_psdash_python_reference.py` | Standard-library formula oracle. |
| `_public_studies_reference_psdash.R` | Public-study data, propensity-model, balance, support, and weight oracle generator. |
| `_binary_balance_reference_psdash.R` | R `cobalt` oracle writer for `crossval_binary_balance_cobalt.do`. |
| `_longitudinal_reference_psdash.R` | R `cobalt`/`WeightIt` oracle writer for `crossval_longitudinal_cobalt_weightit.do`. |
| `_psdash_qa_extdata.do` | Defines `_psdash_qa_extfile`: finds third-party source data (`STATA_QA_DATA`, else download, else R regeneration) and verifies its length and checksum CRC. |
| `_multigroup_reference_twang.R` | Re-fits the twang `mnps` vignette model to regenerate and guard the weights fixture `aod_twang_ate_weights.csv`. |
| `data/crump_rhc/` | `SOURCE.md` only: provenance, sha256, licence and the requested attribution for `rhc.csv` (hbiostat.org), which is not vendored. |
| `data/binary_balance/` | `SOURCE.md` only: provenance, sha256, CC BY-NC 2.0 licence and the required attribution for the Dehejia-Wahba NSW/CPS files, which are not vendored. |
| `data/multigroup/` | Tables transcribed from the printed twang vignette (`twang_mnps_*_printed.csv`, numbers, not data) and `SOURCE.md` with the provenance of `aod_twang_ate_weights.csv`, which is not vendored. |
| `tools/check_xlsx.py` | Vendored workbook structure, numeric-cell, and presentation checker. |
| `tools/check_artifact.py` | PNG/PDF signatures, dimensions, page-object, and termination checks. |
| `tools/check_result_sentinels.py` | Refuses `RESULT:` sentinels the CLI parser cannot read: padded values, fields split across display arguments, an in-string display format, or a count built through one. `--selftest` re-proves all four refusals in the same run. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `psdash` | `test_psdash`, dispatch/refactor suites | — | — | Install/autoload and adversarial suites. |
| `psdash detect` | Detection, producer-contract, and sample-ledger suites | `validation_multigroup_longitudinal` | `crossval_external_references` | Every auto-detected panel path. |
| `psdash overlap` | Binary/multi-group overlap and adversarial suites | Known-answer suites | `crossval_python_psdash`, `crossval_external_references`, `crossval_public_studies` | Combined and producer integrations. |
| `psdash balance` | Binary/multi-group balance, factors, VR, and export suites | Known-answer and method suites | `crossval_cobalt`, `crossval_python_psdash`, `crossval_external_references`, `crossval_public_studies`, `crossval_binary_balance_cobalt`, `crossval_binary_balance_published_imbens2015`, `crossval_multigroup_published_twang` | Combined and teffects paths. |
| `psdash weights` | Binary/multi-group weights, estimands, thresholds, and exports | Known-answer and method suites | `crossval_python_psdash`, `crossval_external_references`, `crossval_public_studies` | Combined and producer integrations. |
| `psdash support` | Binary/multi-group support, trimming, Crump, and guards | Known-answer and method suites | `crossval_python_psdash`, `crossval_external_references`, `crossval_public_studies`, `crossval_crump_rhc_published_support` | Combined and GPS-positivity suites. |
| `psdash combined` | Verdict, threshold, common-sample, report, and longitudinal suites | Multi-group/longitudinal validation | `crossval_longitudinal_cobalt_weightit` | Real producer integrations. |

## Lane membership

`quick` and `external` are disjoint; `full = quick + external`, and `full` is the default release gate. The explicit authoritative suite lists live only in `run_all.do`: `quick` contains every `test_*` and `validation_*` suite listed above, while `external` contains every `crossval_*` suite.

Canonical fixture adoption is in progress. `3` cases in `validation_fixture_truth.do` ran with zero failures in an isolated copy; independent review is pending. Three cases align true propensity scores on actual covariate keys (including relabelled codes), then check mean inverse probability weights and total/arm ESS against independently summed moments through psdash_weights.

| Added QA file | Role |
|---|---|
| `validation_fixture_truth.do` | Known-answer F/U suite; reached from the package runner |
| `_qa_fx_a1.do` | Byte-for-byte canonical fixture vendor |
| `_qa_hostile.do` | Byte-for-byte primitive/assertion helper vendor |

Fixture coverage still owed: A3 producer/manual period routes, modified/overlap estimands, A1 outcome separation and remaining A3 minima. A1 `separate` changes only y, which no manual PS diagnostic consumes; it is not credited by a dummy mutation. Automatic PS-estimation separation requires a treatment-model fixture, separately adjudicated. Archetype declarations retain these obligations; a green runtime subset does not meet the full census.

Canonical direct route extension: `validation_fixture_routes.do` ran12/12 with zero failures. Every public command consumes F plus unsorted, collinear, single-level covariate, absent factor base, multi-digit codes, missing subgroup/whole column, zero/extreme weights, near positivity and shifted covariates. Mathematical oracles use supplied-weight means/ESS, raw and unbiased weighted moments, Bernoulli variance and complete weighted ECDF supremum distances. The dashboard uses its documented common complete-case sample; standalone balance reports incomplete covariates. A wholly missing common covariate refuses2000 with its actual message and unchanged caller data/e/settings fingerprint. The shift SMD uses the inherited qa_shift_invariance tolerance1e-6; ordinary cells use1e-10.

| File | Coverage |
|---|---|
| `validation_fixture_routes.do` | Seven public manual binary PS routes and meaningful A1 consumed-role operators; quick/full |
| `_qa_state.do` | Current byte-for-byte caller-state helper vendor |

## Evidence layers

| Route | Recovery | Reference parity | Published reproduction | Inference calibration |
|---|---|---|---|---|
| `psdash balance` binary SMD/VR/KS, raw and weighted | `validation_known_answers.do` | `crossval_cobalt.do`; `crossval_python_psdash.do`; `crossval_external_references.do`; `crossval_public_studies.do`; `crossval_binary_balance_cobalt.do` | `crossval_binary_balance_published_imbens2015.do` | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash balance` multi-group pairwise SMD/VR/KS | `validation_multigroup_longitudinal.do` | `crossval_cobalt.do`; `crossval_external_references.do` | `crossval_multigroup_published_twang.do` | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash weights` binary IPTW ATE/ATT/ATC, ESS | `validation_known_answers.do` | `crossval_python_psdash.do`; `crossval_external_references.do`; `crossval_public_studies.do` | none: deterministic transform of the supplied propensity scores into closed-form IPTW weights | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash weights` multi-group GPS weights, ESS | `validation_multigroup_longitudinal.do` | `crossval_external_references.do` | none: deterministic transform of the supplied propensity scores into closed-form IPTW weights | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash overlap` binary PS overlap, AUC | `validation_known_answers.do` | `crossval_python_psdash.do`; `crossval_external_references.do`; `crossval_public_studies.do` | none: paper publishes no worked example of the overlap statistics this route computes (AUC, group PS means and ranges, share outside min-max support); Crump et al. (2009) show the right heart catheterization propensity scores only as histograms (Fig. 1) with no printed AUC, mean, minimum or maximum, and Li, Morgan and Zaslavsky (2018), the other RHC reanalysis checked, print none either; the printed Crump numbers (alpha 0.1026, Table 2 trimming counts) are covered by the `psdash support` reproduction suite | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash overlap` multi-group full-vector GPS positivity | `validation_method_contracts.do` | `crossval_external_references.do` | none: data unavailable: no grounding paper prints a number this route computes (min_j e_j or full-vector GPS positivity): McCaffrey et al. 2013 and Li & Li 2019 show GPS distributions only as figures; McCaffrey's CSAT/GAIN microdata are not public (twang AOD is a 600-youth subset that does not reproduce its Table 3: non-Hispanic white share 0.16/0.20/0.175 vs 0.67/0.51/0.35), Li & Li's MEPS 2009 analysis sample (N=20,446) could not be reconstructed from the public file (best 22,087), and Yoshida et al. 2017 use simulated data plus proprietary claims | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash support` binary common support and Crump trimming | `validation_known_answers.do` | `crossval_python_psdash.do`; `crossval_external_references.do`; `crossval_public_studies.do` | `crossval_crump_rhc_published_support.do` | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash support` multi-group GPS-floor trimming | `validation_method_contracts.do` | `crossval_external_references.do` | none: data unavailable: no grounding paper prints a retained-sample or trimming count for a GPS-floor rule: Li & Li 2019 trims by optimal sum of inverse GPS (a different rule) and shows results only as Table 2 effective sample sizes on a MEPS 2009 sample (N=20,446) that could not be reconstructed from the public file (best 22,087), McCaffrey et al. 2013 endorse no threshold and use non-public CSAT data, and Yoshida et al. 2017 use simulated and proprietary claims data | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |
| `psdash combined` longitudinal period overlap and weights | `validation_multigroup_longitudinal.do` | `crossval_longitudinal_cobalt_weightit.do` | none: no grounding paper (psdash combined's longitudinal route only summarises the propensity scores and weights that a verified msm, tte or ltmle producer stamps, and the psdash literature corpus holds no longitudinal paper whose printed numbers this route computes; the public worked examples found print weights no psdash producer generates: van der Wal and Geskus 2011 doi:10.18637/jss.v043.i13 fits Cox-model (family survival) stabilised weights in all its longitudinal examples, and on its haartdat data msm_weight, the closest pooled-logistic producer, refuses with r(459) because absorbing HAART separates its lagged-treatment term; Fewell et al. 2004 doi:10.1177/1536867X0400400403 prints a pooled-logistic weight summary on private cohort data) | none: no inference reported; psdash computes descriptive diagnostics without standard errors, intervals, or p-values |

## Known gaps

- Published reproduction of binary balance covers the raw (unweighted) half only (Imbens 2015 Tables 10 and 16); no public target for weighted/IPTW or matched-sample published balance was found (the Austin papers use non-public ICES Ontario data; NHEFS has no published before/after-IPTW SMD table; Imbens Table 18's matched column could not be reproduced from the text). KS has no published target. Weighted balance is covered by `cobalt` parity.
- Multi-group published reproduction covers pairwise weighted means and KS only; SMD and VR have no published target whose definition matches psdash (twang pools the SD over all arms).
- `crossval_multigroup_published_twang.do` gives a full receipt only on a host with `Rscript` and twang 2.6.2; with the weights from `STATA_QA_DATA` but without them its regeneration guard is skipped and the receipt is partial.
- `crossval_longitudinal_cobalt_weightit.do` runs its tte scenario only when a sibling `tte` package is present; ltmle producers are not exercised by the parity suite.
- The `.sthlp` render axis is checked by `artifact help` / `check package`, not by this lane.
