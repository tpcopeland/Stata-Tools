# psdash QA

Run every lane from this `qa/` directory with `stata-mp`. The runner creates isolated PLUS and PERSONAL directories through `_psdash_bootstrap.do`; it does not rely on the user's installed copy.

## Lanes

```bash
stata-mp -b do run_all.do quick
stata-mp -b do run_all.do external
stata-mp -b do run_all.do full
```

- `quick` runs 44 functional, known-answer, adversarial, contract, documentation, install/autoload, regression, and Excel-fidelity suites.
- `external` runs three implementation-parity suites: direct R `cobalt` balance parity, independent Python formula checks, and statsmodels/scikit-learn reference datasets.
- `full` is the release gate and runs both sets. Omitting the lane is equivalent to `full`.

For concurrent or release evidence, use `python3 -m _devkit.stata_dev_cli qa run psdash --repo tools --mode full --isolated`. A manual scratch copy must preserve `{_data,tabtools,iivw,ltmle,msm,tmle,tte,psdash}` when those producer packages are present, and copied `qa/*.log` plus `qa/run_all_status.txt` must be removed before the run. A package-root `run_all.log` is not authoritative when another process may be using the same lane.

## Suite roles

- `test_*.do`: functional and regression behavior, including old-code-failing audit cases.
- `validation_*.do`: independent known-answer and invariant checks.
- `crossval_*.do`: external implementation/reference comparisons. A script that
  only hand-computes formulas belongs under `validation_`, not `crossval_`.
- `test_real_producer_integrations.do`: genuine producer executions for every
  producer present in the isolated layout; absent development-only producers are
  reported as skips rather than represented by fabricated positive controls.
- `tools/check_xlsx.py`: canonical workbook structure, numeric-cell, and presentation assertions.

Every behavioral fix belongs in a focused regression suite. A test should assert returned values and affected data, not only `_rc == 0` or file existence. Disposable logs, workbooks, graphs, and generated data are runtime artifacts and must not be committed outside deliberate `demo/` documentation assets.

## Runner inventory

The `quick` lane runs:

- `test_psdash.do`, `validation_psdash.do`, `validation_known_answers.do`, `validation_multigroup_longitudinal.do`, `validation_method_contracts.do`, `validation_extended_known_answers.do`
- `test_refactor_qa_bootstrap_contract.do`, `test_refactor_install_autoload.do`, `test_refactor_doc_contract.do`, `test_refactor_display_contracts.do`, `test_refactor_option_abbrev_contract.do`, `test_refactor_return_contracts.do`, `test_refactor_graph_export_failures.do`
- `test_saving_format_contract.do`, `test_qa_contract_gaps.do`
- `test_tmle_ltmle_contract.do`, `test_msm_tte_contract.do`, `test_iivw_contract.do`, `test_producer_contracts.do`, `test_real_producer_integrations.do`
- `test_multigroup_detect.do`, `test_multigroup_overlap_support.do`, `test_multigroup_balance_weights.do`, `test_multigroup_psvars_regression.do`
- `test_adversarial.do`, `test_detect_dispatch_adversarial.do`, `test_binary_balance_weights_adversarial.do`, `test_overlap_support_multigroup_adversarial.do`
- `test_v130_features.do`, `test_v140_features.do`, `test_v141_features.do`
- `test_rb01_verdict.do`, `test_rb02_gps_positivity.do`, `test_rb03_factor_expansion.do`, `test_rb0405_teffects_sample.do`, `test_rb06_estimand.do`, `test_rb08_vr_count.do`, `test_rb09_weight_thresholds.do`, `test_rb10_longitudinal.do`, `test_rb11_trim_guard.do`, `test_rb12_kimi_audit.do`
- `test_remaining_audit_regressions.do`, `test_excel_fidelity.do`, `test_return_surface_remaining.do`

The `external` lane runs `crossval_python_psdash.do`, `crossval_cobalt.do`, and `crossval_external_references.do`. The `cobalt` suite checks both binary and pairwise multi-group SMD, continuous variance-ratio, raw KS, and weighted-KS results; it also verifies invariance to rescaling the weights.

Every suite listed in `run_all.do` emits a machine-readable `RESULT:` line with
`tests = pass + fail + skip`. The runner emits its own final `RESULT:` summary.
Bootstrap failures must propagate immediately; tests may not hide a failed local
install behind `capture do _psdash_bootstrap.do`.
