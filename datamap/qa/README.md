# datamap QA suite

This flat suite covers the four public commands: `datamap`, `datadict`,
`datacheck`, and `datamvp`. `run_all.do` is a curated runner with an explicit
full lane; every suite can also be run directly from `qa/`.

## How to run

```bash
cd datamap/qa
stata-mp -b do run_all.do
stata-mp -b do test_datacheck.do
stata-mp -b do validation_datamvp.do
```

The runner reinstalls the package from its parent directory and exits nonzero
when any included suite fails. Run the complete suite sequentially: the tests
share the package-local generated data and Stata installation state.

## Conventions

- `test_*.do` are functional and regression suites; `validation_*.do` use
  known-answer or invariant checks.
- Suites print PASS/FAIL output and exit nonzero on failures. New suites should
  also finish with a `RESULT:` sentinel for machine parsing.
- Paths derive from `c(pwd)`; generated logs and temporary outputs are not
  package artifacts.
- The package has no external-reference cross-validation: its outputs are
  deterministic maps, dictionaries, and QC summaries, so hand-computable
  validations are the relevant independent oracle.

## File index

| File | Covers |
|------|--------|
| `test_datamap.do` | Core text/JSON maps, input modes, outputs, and options. |
| `test_datamap_bugfixes.do` | Focused historical map regressions. |
| `test_datamap_float_format.do` | Stable numeric formatting and gate messages. |
| `test_datamap_golden.do` | Normalized golden text and Markdown outputs. |
| `test_datamap_privacy.do` | Exclusions, small-cell protection, and JSON privacy. |
| `test_datamap_v11.do` | Classification, stored results, and validation regressions. |
| `test_datamap_v15.do` | Config, metadata, schema comparison, and shared contracts. |
| `test_datamap_v152.do` | High-cardinality, JSON-number, and identifier regressions. |
| `test_datamap_v154.do` | Privacy defaults, threshold validation, and graph-option regressions. |
| `test_datamap_v160.do` | Capped unique counts (`uniqcap()`), the frame-based report writers, and the shared fast counter in `datadict`. |
| `test_datamap_v2.do` | Historical map and dictionary behavior. |
| `test_datadict_v14.do` | Markdown dictionary routes and metadata exports. |
| `test_datacheck.do` | Profiles, gates, grouping, saved metadata, and privacy controls. |
| `test_datamvp.do` | Missingness patterns, graphs, paths, and return contracts. |
| `test_datamvp_labels.do` | Value-label and graph-label handling. |
| `validation_datamap.do` | Classification, output, and deterministic map invariants. |
| `validation_datamvp.do` | Known-answer missing-pattern and return-value checks. |
| `run_all.do` | Curated full-lane runner. |

## Coverage map

| Command | Functional | Validation | Cross-validation |
|---------|------------|------------|------------------|
| `datamap` | `test_datamap*.do`, `test_datamap_golden.do`, `test_datamap_privacy.do` | `validation_datamap.do` | N/A |
| `datadict` | `test_datadict_v14.do`, `test_datamap*.do` | `validation_datamap.do` | N/A |
| `datacheck` | `test_datacheck.do`, `test_datamap_float_format.do`, `test_datamap_v15.do` | Invariant checks in `test_datacheck.do` | N/A |
| `datamvp` | `test_datamvp.do`, `test_datamvp_labels.do` | `validation_datamvp.do` | N/A |

## Lane membership

| Lane | Suites |
|------|--------|
| `full` (default) | Every functional and validation suite listed above, in the explicit order in `run_all.do`. |
