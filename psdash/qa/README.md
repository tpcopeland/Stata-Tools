# psdash QA

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
| `iivw`, `msm`, `tte`, `tmle`, `ltmle` | Producer-contract and real-integration suites | The unavailable producer case is recorded as a skip; the isolated release tree must include every available sibling. |
| `_data`, `tabtools` | Documentation/install and shared release-surface checks | Missing siblings are a hard failure in the isolated release tree. |

## Conventions

- `test_*` is functional or regression coverage; `validation_*` is a known-answer or invariant oracle; `crossval_*` compares against an independently implemented R/Python oracle.
- Every runnable suite emits exactly one terminal `RESULT: <name> tests=N pass=N fail=N [skip=N]` line before closing its log and exits nonzero on failure. `full` accepts no suite-level dependency skip.
- Suites sandbox PLUS and PERSONAL under `c(tmpdir)` through `_psdash_bootstrap.do`, reinstall `psdash` from the local package directory, and restore the caller's paths during cleanup.
- Paths derive from `c(pwd)`; data are generated at runtime except for explicitly named sibling-package fixtures.
- Generated logs, workbooks, graphs, and datasets are disposable and gitignored; only deliberate `demo/` documentation assets may be tracked.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `quick` / `test_excel_fidelity.do` | Python 3 and `openpyxl` | Suite failure. |
| `external` / `crossval_cobalt.do`, `crossval_public_studies.do` | `Rscript` and R packages `cobalt` and `MASS` | Lane exits with dependency skip. |
| `external` / `crossval_external_references.do` | Python 3, NumPy, pandas, statsmodels, and scikit-learn | Suite failure after the Python reference command cannot create its oracle files. |
| `external` / `crossval_python_psdash.do` | Python 3 standard library | Lane exits with dependency skip. |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_psdash.do` | Public binary commands, options, dispatch, returns, and exports. |
| `test_adversarial.do` | Invalid inputs, boundary cases, state cleanup, and router failures. |
| `test_binary_balance_weights_adversarial.do` | Binary balance and weight edge cases. |
| `test_combined_threshold_contract.do` | Combined threshold overrides and multi-group GPS verdict semantics. |
| `test_detect_dispatch_adversarial.do` | Installed autoload, detection contexts, and dispatcher routing. |
| `test_excel_fidelity.do` | Workbook schema, numeric cells, sheets, and presentation checks. |
| `test_iivw_contract.do` | Genuine, stale, tampered, and explicit-override iivw contracts. |
| `test_msm_tte_contract.do` | MSM/TTE contract rejection and manual override behavior. |
| `test_multigroup_balance_weights.do` | Multi-group balance and weight summaries. |
| `test_multigroup_detect.do` | Multi-group input mapping and detection. |
| `test_multigroup_overlap_support.do` | Multi-group overlap, support, trimming, and returned metrics. |
| `test_multigroup_psvars_regression.do` | Generalized-score orientation and `psvars()` regressions. |
| `test_overlap_support_multigroup_adversarial.do` | Binary and multi-group overlap/support edge cases. |
| `test_producer_contracts.do` | Compatibility-matrix rows, version gates, and installed producer guards. |
| `test_qa_contract_gaps.do` | Return-surface gaps and QA sentinel integrity. |
| `test_rb01_verdict.do` | Unified machine-readable findings and zero-panel rejection. |
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
| `test_remaining_audit_regressions.do` | Residual audit findings not owned by a narrower suite. |
| `test_return_surface_remaining.do` | Remaining conditional and failure-path return surfaces. |
| `test_saving_format_contract.do` | Saving extensions, replace parsing, and graph formats. |
| `test_tmle_ltmle_contract.do` | TMLE/LTMLE contract rejection and manual override behavior. |
| `test_v130_features.do` | Export/report and feature regressions introduced around v1.3.0. |
| `test_v140_features.do` | Variance-ratio, weight-cutoff, quantile-support, and related regressions. |
| `test_v141_features.do` | Option usability and documentation regressions. |
| `test_v164_regressions.do` | Treatment-only dispatch, built-in estimation samples, Crump alpha zero, point support, and source corrections. |
| `test_v169_regressions.do` | Varabbrev cleanup, option-combination errors, quoted Excel titles, internal program classes, and help rendering. |

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

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Explicit quick, external, and full lane membership and final sentinel. |
| `_psdash_bootstrap.do` | Relocatable PLUS/PERSONAL sandbox, local install, and cleanup. |
| `_cobalt_reference_psdash.R` | R `cobalt` oracle writer. |
| `_external_reference_psdash.py` | NumPy/pandas/statsmodels/scikit-learn reference generator. |
| `_psdash_python_reference.py` | Standard-library formula oracle. |
| `_public_studies_reference_psdash.R` | Public-study data, propensity-model, balance, support, and weight oracle generator. |
| `tools/check_xlsx.py` | Vendored workbook structure, numeric-cell, and presentation checker. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `psdash` | `test_psdash`, dispatch/refactor suites | — | — | Install/autoload and adversarial suites. |
| `psdash detect` | Detection, producer-contract, and sample-ledger suites | `validation_multigroup_longitudinal` | External reference workflows | Every auto-detected panel path. |
| `psdash overlap` | Binary/multi-group overlap and adversarial suites | Known-answer suites | Python, external references, and public studies | Combined and producer integrations. |
| `psdash balance` | Binary/multi-group balance, factors, VR, and export suites | Known-answer and method suites | R `cobalt`, Python, external references, and public studies | Combined and teffects paths. |
| `psdash weights` | Binary/multi-group weights, estimands, thresholds, and exports | Known-answer and method suites | Python, external references, and public studies | Combined and producer integrations. |
| `psdash support` | Binary/multi-group support, trimming, Crump, and guards | Known-answer and method suites | Python, external references, and public studies | Combined and GPS-positivity suites. |
| `psdash combined` | Verdict, threshold, common-sample, report, and longitudinal suites | Multi-group/longitudinal validation | External reference workflows | Real producer integrations. |

## Lane membership

`quick` and `external` are disjoint; `full = quick + external`, and `full` is the default release gate. The explicit authoritative suite lists live only in `run_all.do`: `quick` contains every `test_*` and `validation_*` suite listed above, while `external` contains every `crossval_*` suite.
