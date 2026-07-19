# gcomp QA

`run_qa.py` is the canonical fail-closed orchestrator. It runs every Stata suite in a fresh process, resolves the package working tree through `_qa_bootstrap.do`, moves batch logs to a temporary artifact directory, requires an exact terminal `RESULT:` record, and rejects unexplained bootstrap/jackknife `x` or `e` progress markers. `lanes.json` is the machine-readable inventory and budget contract; `feature_matrix.csv` maps every comprehensive-audit requirement to an expected behavior, oracle, and executable gate.

## Commands

Run from this `qa/` directory:

```bash
python3 run_qa.py --lane quick
python3 run_qa.py --lane core
python3 run_qa.py --lane external
python3 run_qa.py --lane slow
python3 run_qa.py --lane release
python3 run_qa.py --lane full
python3 run_qa.py --lane quick --shuffle --seed 20260713
python3 run_visual.py
```

Golden images are intentionally immutable during ordinary QA. After manually reviewing all three candidate pages, refresh them explicitly with `python3 run_visual.py --update-baseline`; the default command always compares against the committed baseline and fails closed on a page-count change, pixel-audit warning, or visual drift beyond 0.2%.

The compatibility commands `stata-mp -b do run_all.do` and `stata-mp -b do run_refactor_gate.do` delegate to the same orchestrator and emit their own aggregate sentinel. `python3 run_qa.py --self-test-parser` adversarially checks missing-sentinel and resampling-marker detection without starting Stata.

## Lane contracts

| Lane | Budget | Purpose | External dependencies |
| --- | ---: | --- | --- |
| Quick | 60 min | Error paths, audit regressions, parser/failure accounting, refactor guards | Stata; Python standard library |
| Core | 90 min | Main functional, adversarial, interaction, diagnostics, and known-answer validation | Stata |
| External | 120 min | Independent Python/R fixture regeneration and numerical parity | Stata, Python/numpy/pandas/statsmodels, R/mediation |
| Slow | 120 min | Stress, recovery, extended surface, and applied-readiness scenarios | Stata |
| Release | 40 min | Static distribution/docs/XLSX gate, isolated install smoke, printed examples | Stata; Python standard library |
| Full | 430 min | De-duplicated aggregate of quick, core, external, slow, and release | All above |
| Refactor | 40 min | Focused bootstrap/MSM/display/geometry/audit subset | Stata |
| Visual | developer/CI | LibreOffice render, pixel heuristics, and golden-PNG comparison | Stata, LibreOffice, pdftoppm, Pillow, numpy |

Budgets are hard upper bounds; each suite also has the timeout recorded below and in `lanes.json`. The aggregate fails if either bound is exceeded.

## Operational inventory

| Suite | Class | Lane | Timeout | Dependency | Oracle or fixture | Generator / seed | Feature IDs |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| `test_errors.do` | functional | quick | 600s | Stata | explicit return-code matrix | fixed seeds in suite | option error surface |
| `test_audit_remediation.do` | adversarial/known-answer | quick | 2400s | Stata | 24 package-local audit probes | per-probe seeds | C01-C05, C07, C30, H01-H15, GCTAB-H02-H06, M01, M03 |
| `test_expected_resampling_failure.do` | adversarial | quick | 300s | Stata | fail-closed rc plus bounded progress markers | 606 | C06, Q02 |
| `test_gcomptab_regressions.do` | functional | quick | 600s | Stata | mocked result/value and workbook contracts | fixed | gcomptab regressions |
| `test_refactor_bootstrap_dispatch.do` | regression | quick/refactor | 600s | Stata | repeated-seed matrix identity | fixed | bootstrap dispatch |
| `test_refactor_msm_omitted.do` | regression | quick/refactor | 600s | Stata | full matrix stripes and omitted-term absence | fixed | C04 |
| `test_refactor_display_golden.do` | regression | quick/refactor | 600s | Stata | text snapshot predicates | fixed | display contract |
| `test_refactor_gcomptab_geometry.do` | regression | quick/refactor | 600s | Stata | workbook geometry/content | fixed | GCTAB-H01 |
| `test_gcomp.do` | functional | core | 1800s | Stata | command/e()/saved-output assertions | scenario seeds | broad public surface |
| `test_adversarial_gcomp.do` | adversarial | core | 1200s | Stata | state/error/covariance assertions | scenario seeds | H07, C06 |
| `test_gcomp_validation.do` | functional | core | 600s | Stata | invalid-role/panel/mode matrix | scenario seeds | validation surface |
| `test_gcomp_diagnostics.do` | functional | core | 900s | Stata | diagnostic schema/name checks | 42 | M03 |
| `test_interactions.do` | interaction | core | 1200s | Stata | targeted option-pair/error invariants | scenario seeds | mode interactions |
| `test_gcomp_imputation_mlogit.do` | functional | core | 900s | Stata | multinomial predicted-marginal oracle | fixed | H01, H12 |
| `test_gcomptab_doseresponse.do` | functional | core | 600s | Stata | dose-response values and mode isolation | fixed | table dose mode |
| `test_gcomptab_text_export.do` | functional | core | 600s | Stata | Markdown/CSV content predicates | fixed | GCTAB-H03 |
| `test_models.do` | functional | core | 600s | Stata | component-model table contracts | fixed | H15, GCTAB-H01 |
| `test_adversarial_gcomptab.do` | adversarial | core | 900s | Stata | path/state/format error matrix | fixed | GCTAB-H02-H06 |
| `validation_adversarial_gcomp.do` | validation | core | 600s | Stata | empty/support/error invariants | fixed | C07, H13 |
| `validation_extra.do` | validation | core | 1200s | Stata | CI/decomposition/stability invariants | 42 | inference surface |
| `validation_gcomp.do` | validation | core | 1800s | Stata | DGP and stored-result known answers | explicit per test | D01, C06 |
| `validation_timevarying.do` | validation | core | 900s | Stata | subject counts and final-row invariance | 20260421 | longitudinal core |
| `crossval_fixture_provenance.do` | provenance | external | 2400s | Python/R | cell-by-cell regenerated-fixture diff | `data/fixture_manifest.json` | Q06 |
| `crossval_gcomp.do` | cross-validation | external | 1200s | Stata + R fixture | analytical truth and R mediation | `generate_r_benchmarks.R`; 42/12345 | mediation triangulation |
| `crossval_external_replication.do` | cross-validation | external | 1200s | Stata + Python fixture | statsmodels plug-in effects | `generate_external_replication.py`; listed seeds | OBE/EOFU point effects |
| `crossval_mediation_se.do` | cross-validation | external | 1800s | Stata + Python fixture | statsmodels bootstrap point/SE/V | `generate_mediation_se_reference.py`; manifest | mediation inference |
| `crossval_timevarying_se.do` | cross-validation | external | 1800s | Stata + Python fixture | subject-bootstrap EOFU point/SE/V | `generate_timevarying_se_reference.py`; manifest | longitudinal inference |
| `crossval_intervention_imputation.do` | cross-validation | external | 1800s | Stata + Python fixture | dynamic/stochastic/imputation point/SE/V | `generate_intervention_imputation_reference.py`; manifest | H11-H12 |
| `crossval_timevarying.do` | cross-validation | external | 900s | Stata + NumPy fixture | forward-MC potential outcomes | `generate_timevarying_reference.py`; 20260421 | longitudinal level/direction |
| `crossval_longitudinal_extended.do` | cross-validation | external | 1800s | Stata + Python fixture | survival/longitudinal point/SE/V | `generate_longitudinal_extended_reference.py`; manifest | extended longitudinal |
| `crossval_mediation_extended.do` | cross-validation | external | 1800s | Stata + Python fixture | OCE/specific/linear point/SE/V | `generate_mediation_extended_reference.py`; manifest | extended mediation |
| `test_stress.do` | stress | slow | 1800s | Stata | finite/ordered/stability assertions | scenario seeds | numerical stress |
| `validation_gcomp_recovery.do` | known-answer | slow | 1800s | Stata | forward-simulation truth | documented seed | longitudinal recovery |
| `validation_gcomp_recovery_extended.do` | known-answer | slow | 2400s | Stata | finite-sample analytical DGP truth | documented seeds | estimand recovery |
| `validation_gcomp_recovery_surface.do` | known-answer | slow | 3600s | Stata | 15 bespoke analytical/forward DGPs | documented seeds | option-surface recovery |
| `validation_peripartum_readiness.do` | applied validation | slow | 2400s | Stata | study-shaped known-answer DGP | documented seed | applied mediation |
| `test_package_release.do` | release/static | release | 900s | Python stdlib | package/version/SMCL/XLSX semantic contract | shipped demo workbook | D01-D07, GCTAB-H01, Q05, Q08 |
| `test_install_smoke.do` | install smoke | release | 900s | Stata | isolated PLUS/PERSONAL command/helper discovery | fixed | Q03 |
| `test_doc_examples.do` | documentation | release | 1200s | Stata | printed executable examples | documented seeds | D03, D07 |

## External fixture policy

Ordinary cross-validation reads committed fixtures and never runs a generator in place. `crossval_fixture_provenance.do` copies `data/` to a temporary directory, verifies the pinned runtime versions, executes every command in `data/fixture_manifest.json`, and compares headers, row counts, string cells, and numeric cells to the committed files. A drift artifact is reported in the suite log; tracked fixtures are never rewritten. The manifest records method, command, seeds, and the narrow tolerance used only for serialization-level floating-point drift.

## Install and artifact hygiene

All source suites call `_qa_bootstrap.do`, which prepends the package directory, discards cached programs, and asserts the exact resolved paths for `gcomp.ado` and `gcomptab.ado`. Only `test_install_smoke.do` calls `net install`; it first prints `ado dir`, then uses temporary isolated `PLUS` and `PERSONAL` directories and restores them.

The orchestrator deletes any same-named stale batch log before launch and moves the fresh log to the reported `/tmp/gcomp-qa-<lane>-*` directory. Suites put generated workbooks, datasets, and explicit logs under `c(tmpdir)` and remove deliberate scratch outputs. A missing log, stale/missing terminal sentinel, nonzero Stata exit, timeout, budget overrun, or undeclared resampling failure marker fails the lane.

## Visual gate

`test_package_release.do` uses the vendored standard-library `tools/check_xlsx.py` for sheet identity/order, dimensions, content, numeric types, merges, fonts, borders, and content-fitting column widths. `run_visual.py` is developer/CI-only: its package-local LibreOffice/pdftoppm path runs blank/right-edge clipping heuristics and compares against the golden PNGs in `baseline/render/`.
