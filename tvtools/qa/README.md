# tvtools QA

The `tvtools` QA suite is flat and concern-oriented, with one curated lane runner and independently runnable suites at the `qa/` root. It covers the public commands, shared interval engines, method invariants, external parity, state preservation, documentation, and the installed release surface.

## How to run

```bash
cd tvtools/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do test_tvmerge.do       # one suite standalone
stata-mp -b do run_all.do release    # full lane plus release contracts
```

`python` is a legacy alias for `external`. Gate on the terminal `RESULT:` line and `run_all_status.txt`, because Stata batch-mode shell status is not the suite verdict.

## Isolation

`run_all.do` writes suite logs into `qa/`, so concurrent runs of the same lane can corrupt one another; a disagreement between `run_all.log` and a suite log is the tell. For concurrent or release-gate work, run from a scratch copy that preserves the repository layout and includes the required sibling directories.

| Sibling | Required by | Behavior if absent |
|---|---|---|
| `_data/` | Documentation and installed-example checks | Hard failure |
| `tabtools/` | Documentation/install smoke infrastructure | Hard failure |
| `rangematch/` | `test_tvm_overlap_drift_guard.do` | Hard failure in external/full/release |
| `psdash/` | `test_package_optional_integration.do` | Hard failure in external/full/release |

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use hand-computable or simulated-truth oracles; `crossval_*` files compare with independent Stata, Mata, R, or Python implementations; `benchmark_*` files are timing guardrails and never correctness gates; `baseline_*` files capture or replay a frozen behavioral surface by hand.
- Every gated suite ends with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure. Full and release lanes require zero skips.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` through `_tvtools_qa_common.do` and restore them after the run.
- Paths derive from `c(pwd)`; no suite contains a machine-local repository path.
- Canonical inputs are tracked in `data/`; `fixtures_manifest.tsv` records their checksums, schemas, producers, consumers, and lifecycle.
- Generated logs, datasets, tables, and graphs are gitignored; only reader-facing assets under `demo/` may be tracked generated files.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `crossval_tvsplit_lexis.do` | `Rscript` and R package `Epi` | Standalone external may skip only when `Rscript` is absent; full/release fail on any skip |
| `crossval_tvevent_recurring.do` | `Rscript` | Same policy |
| External/full/release integration | Sibling `rangematch` and `psdash` packages | Hard failure |
| Dialog release check | A graphical Stata session via `run_dialog_gui.sh` | Run separately from the batch runner |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_default_naming.do` | Derived output names and default naming contracts. |
| `test_dialogs_gui.do` | Interactive dialog parsing and submission behavior. |
| `test_display_contract.do` | Stable command output and display-side contracts. |
| `test_edge_cases.do` | Empty, singleton, boundary, and malformed inputs. |
| `test_extended_missing.do` | System and extended-missing handling across commands. |
| `test_frames_input.do` | Frame input and frame-preservation behavior. |
| `test_help_examples.do` | Executability of documented examples. |
| `test_integration.do` | Cross-command workflows and shared data contracts. |
| `test_options.do` | Public option behavior and option interactions. |
| `test_package_fixtures.do` | Fixture inventory, checksum, schema, and provenance contracts. |
| `test_package_optional_integration.do` | Optional `psdash` integration from an isolated install. |
| `test_package_release.do` | Version, manifest, install, help-render, menu, and distribution gates. |
| `test_package_runner_contract.do` | Lane manifest, pinned-result, bootstrap, and runner contracts. |
| `test_package_state.do` | Caller data, frame, setting, and estimation-state preservation. |
| `test_program_limits.do` | Stata program statement ceilings and safety margins. |
| `test_regressions.do` | Consolidated bug regressions, including exact schema comparison and metadata carry. |
| `test_regressions_1_9_0.do` | Diagnostics-helper extraction and associated release regressions. |
| `test_tvage.do` | `tvage` functional surface. |
| `test_tvage_v1160.do` | Calendar-age boundary regressions. |
| `test_tvband.do` | `tvband` functional surface. |
| `test_tvband_oracle.do` | Hand-enumerated `tvband` boundary oracle. |
| `test_tvbuild_commit.do` | Event stage, provenance, transaction, and rollback behavior. |
| `test_tvbuild_construct.do` | Construction, alignment, quantities, schema, and metadata. |
| `test_tvbuild_dryrun.do` | Parser, preflight, plan, refusals, and read-only dry runs. |
| `test_tvbuild_manifest_default.do` | Default and explicit provenance-manifest equivalence. |
| `test_tvbuild_regressions_1_10_2.do` | Specification, event-date, manifest, and parser regressions. |
| `test_tvdiagnose.do` | `tvdiagnose` functional surface. |
| `test_tvevent.do` | `tvevent` functional surface. |
| `test_tvevent_segments.do` | Event segmentation, clocks, and quantity propagation. |
| `test_tvexpose.do` | `tvexpose` functional surface. |
| `test_tvexpose_diagnostics.do` | Diagnostic dispatch and output-schema behavior. |
| `test_tvexpose_fastpath.do` | Fast-path eligibility and parity with the general engine. |
| `test_tvm_overlap_drift_guard.do` | Shared overlap engine against `rangematch` and a join oracle. |
| `test_tvm_point_engine.do` | Point-event Mata engine and unmatched-row behavior. |
| `test_tvmerge.do` | `tvmerge` functional and diagnostic-return contracts. |
| `test_tvmerge_frame_native.do` | Frame-native merge parity and source preservation. |
| `test_tvmerge_idname.do` | Output identifier renaming and downstream chaining. |
| `test_tvpanel.do` | `tvpanel` functional surface. |
| `test_tvspec.do` | Specification construction and equivalence with hand-built plans. |
| `test_tvsplit.do` | `tvsplit` functional surface. |
| `test_tvtools.do` | Dispatcher routing and package overview behavior. |
| `test_tvtools_catalog.do` | Dispatcher catalog completeness and classifications. |
| `test_tvtools_v1141.do` | Weighting and dispatcher regressions from the 1.14 line. |
| `test_tvweight.do` | `tvweight` functional surface. |
| `test_tvweight_cumprod.do` | Cumulative-weight product engine. |
| `test_tvweight_v1150.do` | Numerator-model and longitudinal-weight regressions. |
| `test_verbose.do` | Verbose diagnostic paths and messages. |

### Validation

| File | Covers |
|---|---|
| `validation_audit_tvdiagnose.do` | Adversarial diagnostic counts and graph state. |
| `validation_audit_tvevent.do` | Adversarial event mapping and validation counts. |
| `validation_audit_tvexpose.do` | Adversarial exposure geometry and algebra. |
| `validation_audit_tvmerge.do` | Merge geometry, diagnostics, invalid-row accounting, and dynamic returns. |
| `validation_audit_tvpanel.do` | Panel-grid and carried-history invariants. |
| `validation_audit_tvsplit.do` | Multi-axis split invariants. |
| `validation_audit_tvweight.do` | Weight, balance, overlap, and positivity invariants. |
| `validation_boundary.do` | Cross-command boundary cases. |
| `validation_contracts.do` | Shared interval and quantity contracts. |
| `validation_dgp_known_answers.do` | Simulated-truth workflows. |
| `validation_dgp_known_answers2.do` | Additional simulated-truth workflows. |
| `validation_flow.do` | Attrition-matrix counts and labels. |
| `validation_known_answers.do` | Hand-computed package-wide results. |
| `validation_phase0_semantics.do` | Foundational interval and role semantics. |
| `validation_supplemental.do` | Supplemental invariants and edge oracles. |
| `validation_tvage.do` | Exact age-boundary answers. |
| `validation_tvband.do` | Exact single-axis band answers. |
| `validation_tvbuild_conservation.do` | End-to-end `tvbuild` person-time and quantity conservation. |
| `validation_tvdiagnose.do` | Known diagnostic counts. |
| `validation_tvevent.do` | Known event placement and clock values. |
| `validation_tvexpose.do` | Known exposure tilings and durations. |
| `validation_tvexpose_statetime.do` | Known exposure-state time histories. |
| `validation_tvmerge.do` | Known merged intervals and quantity values. |
| `validation_tvpanel.do` | Known fixed-width panel rows. |
| `validation_tvsplit.do` | Known multi-axis split rows. |
| `validation_tvweight.do` | Known weight calculations. |
| `validation_tvweight_balance.do` | Known balance metrics. |
| `validation_tvweight_msm_recovery.do` | Longitudinal MSM parameter recovery. |
| `validation_tvweight_recovery.do` | Treatment-effect recovery under weighting. |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_tvevent_recurring.do` | Independent R recurrent-event construction. |
| `crossval_tvexpose_expand.do` | Day-expanded exposure oracle. |
| `crossval_tvmerge_mata.do` | Day-expanded and join-based merge oracles. |
| `crossval_tvsplit_lexis.do` | Stata `stsplit`, R `Epi`, and explicit cut enumeration. |
| `crossval_tvtools.do` | Independent package-wide formula and workflow comparisons. |
| `crossval_tvweight_ipcw.do` | Independent censoring-weight implementation. |

### Manual baselines and benchmarks

| File | Covers |
|---|---|
| `baseline_tvevent_surface.do` | Manual capture/replay of the full `tvevent` surface. |
| `baseline_tvexpose_surface.do` | Manual capture/replay of the full `tvexpose` surface. |
| `baseline_tvmerge_surface.do` | Manual capture/replay of the full `tvmerge` surface. |
| `benchmark_tvbuild.do` | `tvbuild` workflow timing; not a correctness gate. |
| `benchmark_tvevent_workflow.do` | Event-workflow timing; not a correctness gate. |
| `benchmark_tvexpose_dose_shape.do` | Dose-engine shape timing; not a correctness gate. |
| `benchmark_tvexpose_workflow.do` | Exposure-workflow timing; not a correctness gate. |
| `benchmark_tvmerge_workflow.do` | Merge-workflow timing; not a correctness gate. |
| `benchmark_tvpanel_cumulative_shape.do` | Cumulative-panel shape timing; not a correctness gate. |
| `benchmark_tvweight_cumprod.do` | Cumulative-weight timing; not a correctness gate. |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Canonical lane runner and terminal result aggregation. |
| `_tvtools_qa_common.do` | Sandboxed install, cleanup, result parsing, exact comparison, and shared assertions. |
| `_tvtools_qa_manifest.do` | Authoritative lane membership, pinned result counts, and skip policy. |
| `data/generate_test_data.do` | Regenerates selected canonical fixtures for deliberate review. |
| `data/`, `fixtures_manifest.tsv` | Tracked inputs and their checksum/schema provenance. |
| `tools/fixture_manifest.py` | Fixture-manifest writer and checker. |
| `run_dialog_gui.sh` | Graphical-session wrapper for `test_dialogs_gui.do`. |
| `.gitignore` | Disposable artifact policy. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `tvtools` | `test_tvtools`, `test_tvtools_catalog` | `validation_known_answers` | `crossval_tvtools` | integration, state, release |
| `tvbuild` | dryrun, construct, commit, manifest, regressions | `validation_tvbuild_conservation` | frozen primitive pipelines | integration, state, fixtures |
| `tvspec` | `test_tvspec` | hand-built plan equivalence | — | `tvbuild` suites |
| `tvexpose` | command, diagnostics, fast path | exposure audit and known answers | `crossval_tvexpose_expand` | integration, state, edge cases |
| `tvmerge` | command, frame-native, `idname()` | merge audit and known answers | `crossval_tvmerge_mata`, drift guard | integration, state, edge cases |
| `tvevent` | command and segments | event audit and known answers | `crossval_tvevent_recurring` | integration, state, edge cases |
| `tvdiagnose` | `test_tvdiagnose` | diagnostic audit and known answers | `crossval_tvtools` | integration and verbose paths |
| `tvweight` | command, cumulative product, regressions | balance and recovery suites | `crossval_tvweight_ipcw`, `crossval_tvtools` | optional integration and state |
| `tvage` | command and regression suites | `validation_tvage` | `crossval_tvtools` | naming and missing-value suites |
| `tvband` | command and hand oracle | `validation_tvband` | — | naming and missing-value suites |
| `tvsplit` | `test_tvsplit` | split audit and known answers | `crossval_tvsplit_lexis` | options and missing-value suites |
| `tvpanel` | `test_tvpanel` | panel audit and known answers | — | integration and missing-value suites |

## Lane membership

`quick` is contained in `core`, which is contained in `full`; `full` is the default release gate. `_tvtools_qa_manifest.do` is the sole executable membership list.

| Lane | Suites |
|---|---|
| `quick` | Public-command functional suites plus option, integration, edge, state, frame, naming, help-example, and runner contracts. |
| `core` | `quick` plus regressions, `tvbuild` phases, known-answer validation, audits, fixture checks, program limits, and in-Stata cross-validation. |
| `external` | R and sibling-package parity/integration suites; `python` is an alias. |
| `full` | `core` plus `external`, with zero skips allowed. |
| `release` | `full` plus distribution/install/help/menu contracts; GUI dialogs remain delegated to `run_dialog_gui.sh`. |
| `meta` | Runner-contract suite only. |
| Manual | `baseline_*` capture/replay and `benchmark_*` timing files are invoked directly and are not correctness lanes. |
