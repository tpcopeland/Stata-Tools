# datamap QA

The suite covers the four public commands: `datamap`, `datadict`, `datacheck`, and `datamvp`. The curated runner defaults to the full lane; every suite can also be run directly from `qa/`.

## How to run

```bash
cd datamap/qa
stata-mp -b do run_all.do
stata-mp -b do run_all.do quick
stata-mp -b do test_regressions.do
```

The runner reinstalls `datamap` from the package parent, redirects PLUS and PERSONAL to temporary directories, runs suites sequentially, restores the original system directories, and exits nonzero when a suite fails. Direct suite runs use their own package setup but do not inherit the runner's installation sandbox.

## Conventions

- `test_*` files contain functional and regression coverage; `validation_*` files contain hand-computable known-answer and invariant checks; `crossval_*` is reserved for an independent external implementation; `benchmark_*` is reserved for timing and is never a correctness gate.
- Every runnable suite ends with exactly one `RESULT: <name> tests=N pass=N fail=N` sentinel and exits nonzero when a check fails. The full lane permits no skips.
- `run_all.do` redirects PLUS and PERSONAL below `c(tmpdir)` before installing from the package parent, then restores both directories.
- Paths derive from `c(pwd)`; no suite uses a machine-local path.
- Test datasets are generated at runtime from built-in or seeded synthetic data.
- Generated logs and disposable `.dta`, graph, and document outputs are gitignored; only documentation assets under `demo/` may be tracked.
- The package has no external-reference cross-validation because its deterministic maps, dictionaries, and QC summaries use hand-computable known answers and invariants as their correctness oracle.

## File index

### Functional and regression suites

| File | Covers |
|------|--------|
| `test_datamap.do` | Core text and JSON maps, input modes, outputs, and options. |
| `test_datamap_errors.do` | Exact error classes and state restoration across invalid inputs. |
| `test_datamap_documentation_examples.do` | Executability of the shipped README and help-file workflows. |
| `test_datamap_bugfixes.do` | Focused historical map regressions. |
| `test_datamap_paths.do` | Parenthesized metadata paths across metadata writers. |
| `test_datamap_float_format.do` | Stable numeric formatting and gate messages. |
| `test_datamap_golden.do` | Normalized golden text and Markdown outputs. |
| `test_datamap_privacy.do` | Exclusions, small-cell protection, and JSON privacy. |
| `test_datamap_v2.do` | Historical map and dictionary behavior. |
| `test_datamap_v11.do` | Classification, stored results, and validation regressions. |
| `test_datamap_v15.do` | Config, metadata, schema comparison, and shared contracts. |
| `test_datamap_v152.do` | High-cardinality, JSON-number, and identifier regressions. |
| `test_datamap_v154.do` | Privacy defaults, threshold validation, and graph-option regressions. |
| `test_datamap_v160.do` | Capped unique counts, frame-based writers, and the shared counter. |
| `test_datamap_v168.do` | Hostile text payloads, graph-label round-trips, helper state restoration, help widths, and QA-index synchronization. |
| `test_datadict_v14.do` | Markdown dictionary routes and metadata exports. |
| `test_datacheck.do` | Profiles, gates, grouping, saved metadata, and privacy controls. |
| `test_datamvp.do` | Missingness patterns, graphs, paths, and return contracts. |
| `test_datamvp_labels.do` | Value-label and graph-label handling. |
| `test_datamvp_oracle.do` | Hand-computable missing-pattern counts, filters, ordering, and monotonicity. |
| `test_regressions.do` | Collision safety, strict graph parsing, return preservation, quoted paths and metadata, stable memory identity, and separate output. |
| `test_help_render.do` | Help-file rendering and a literal-SMCL positive control. |

### Validation suites

| File | Covers |
|------|--------|
| `validation_datamap.do` | Classification, output, and deterministic map invariants. |
| `validation_datamvp.do` | Known-answer missing-pattern and stored-result checks. |

### Runner

| File | Purpose |
|------|---------|
| `run_all.do` | Validates the lane, sandboxes installation state, installs the local package, runs suites, and emits a lane sentinel. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|------------|------------|-------------------|
| `datamap` | `test_datamap*.do`, `test_regressions.do` | `validation_datamap.do` | Documentation and help-render suites |
| `datadict` | `test_datadict_v14.do`, `test_datamap*.do`, `test_regressions.do` | `validation_datamap.do` | `test_datamap_v168.do` hostile-text regressions |
| `datacheck` | `test_datacheck.do`, `test_datamap_float_format.do`, `test_datamap_v15.do`, `test_regressions.do` | Invariants in `test_datacheck.do` | Documentation examples |
| `datamvp` | `test_datamvp.do`, `test_datamvp_labels.do`, `test_regressions.do` | `validation_datamvp.do`, `test_datamvp_oracle.do` | `test_datamap_v168.do` hostile-label regressions |

## Lane membership

`quick` is contained in `core`, which is contained in `full`; `full` is the default release gate. The explicit suite list in `run_all.do` is authoritative.

| Lane | Suites |
|------|--------|
| `quick` | Primary command suites, exact error checks, high-value regressions, documentation examples, help rendering, and current-release regressions. |
| `core` | Every functional, regression, help-render, and validation suite in the file index. |
| `full` (default) | Currently the same suites as `core`; reserved for future external-oracle or slow coverage. |
