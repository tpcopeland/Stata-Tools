# swimlane QA

The `swimlane` QA suite is flat and concern-oriented, with a curated lane runner and independently runnable suites for functional behavior, regressions, exports, state preservation, and canonical-table validation.

## How to run

```bash
cd swimlane/qa
stata-mp -b do run_all.do                 # full lane (default gate)
stata-mp -b do run_all.do quick           # fast functional lane
stata-mp -b do test_documentation_examples.do  # one suite standalone
```

`run_all.do` exits nonzero through its terminal Stata status when any suite fails; the machine-readable evidence is the final `RESULT:` line in each log.

## Isolation

Each suite writes a same-named `.log` in `qa/`, so never run the same package lane concurrently from the live tree. For concurrent or gate runs, use a scratch copy that preserves the repository layout and remove copied `qa/*.log` files before starting.

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use hand-computable known-answer or invariant oracles. This deterministic plotting package has no external `crossval_*` layer.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N` and exits nonzero on any failure; skips are not used.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` through `_swimlane_qa_common.do`, install from the local package directory, and run in a disposable Stata process without touching the user's ado tree.
- Paths derive from `c(pwd)` or `c(tmpdir)`; no suite contains a machine-local path.
- Test data are generated at runtime by inline fixtures and deterministic builders in `_swimlane_qa_common.do`.
- Generated `.log`, `.smcl`, `.dta`, `.gph`, and image artifacts are disposable and gitignored; tracked generated documentation assets live only under `demo/`.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_basic.do` | Minimal wide, long-state, and `stset` render paths. |
| `test_data_preservation.do` | Caller data, `varabbrev`, and `more` preservation on success and error paths. |
| `test_density.do` | All-subject retention, schema/rank metadata, deterministic single- and multi-key ordering, density preset overrides, selective labels, independent block headers and color groups, bar/line canonical equality, physical lane sizing, marker/continuation policies, and persistent render metadata. |
| `test_documentation_examples.do` | Installed-user README and help workflows, including long and wide inputs, frames, interval layers, exports, dense layouts, pagination, and documented sorting recipes. |
| `test_errors.do` | Invalid input shapes, option combinations, display labels, external events, interval layers, bounds, paths, empty samples, and graph/frame preservation on early and late output errors. |
| `test_export.do` | Canonical CSV, Markdown, DTA, and frame output plus return survival after side-effect failure. |
| `test_features.do` | Long and external events, date formats including absolute wide events and readable calendar axes, compact facets, display labels, palettes, custom overlays, state ordering, censoring, bar labels, and command reconstruction. |
| `test_options.do` | Styling, graph save/export, grouping, and `nostset` behavior. |
| `test_regressions.do` | Deep-review regressions for string roles, canonical-name collisions, pre-collapse intervals, event-only state rows, `stset` analysis-sample contracts, protected frames, help workflows, missing values, and destructive output-option parsing. |
| `test_return_values.do` | Exact documented scalar, macro, matrix, audit-count, grouping, series, and truncation return contracts. |

### Validation

| File | Covers |
|---|---|
| `validation_canonical_tables.do` | Hand-checked canonical rows, exact interval layers, geometry and out-of-span audits, event coordinates, state labels, lane order, and truncation. |

### Support

| File | Contents |
|---|---|
| `_swimlane_qa_common.do` | Sandboxed local-install bootstrap and deterministic wide, long, event, interval, geometry, date, and survival fixtures. |
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner. |

## Coverage map

| Command | Functional and regression | Validation | Also exercised in |
|---|---|---|---|
| `swimlane` | All `test_*.do` suites | `validation_canonical_tables.do` | Installed-helper smoke in `_swimlane_qa_common.do` and literal README/help workflows in `test_documentation_examples.do`. |

## Lane membership

`quick` ⊆ `core` = `full`; `full` is the default gate.

| Lane | Suites |
|---|---|
| `quick` | `test_basic.do`, `test_return_values.do`, `test_errors.do`, `test_data_preservation.do`, and `test_regressions.do` |
| `core` | `quick` plus `validation_canonical_tables.do`, `test_export.do`, `test_options.do`, `test_features.do`, `test_density.do`, and `test_documentation_examples.do` |
| `full` | Same membership as `core` |

## Known gaps

The package lane exercises graph creation and inspects named graph/file contracts, while the SMCL render axis is gated separately with `artifact help swimlane` during documentation and review workflows.
