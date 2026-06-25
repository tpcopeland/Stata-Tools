# kmplot QA

This directory contains the package QA for `kmplot`. Run suites from this
directory so all paths are derived from `c(pwd)`.

## Run

```stata
do run_all.do
do run_all.do quick
do run_all.do core
do run_all.do full
```

`full` is the default release gate.

## Layout

- `_kmplot_qa_common.do` installs `kmplot` from the local package path into
  temporary PLUS/PERSONAL sysdirs and defines shared file-content assertions.
- `run_all.do` is the curated lane runner.
- `test_kmplot.do` covers functional behavior, options, error handling,
  state restoration, graph export/save, richer returns, and regression paths.
- `validation_kmplot.do` checks numerical and survival-analysis invariants
  against Stata survival commands and hand-computed quantities.

## Coverage Map

| Surface | Covered by |
|---------|------------|
| Basic `kmplot` and `by()` workflows | `test_kmplot.do`, `validation_kmplot.do` |
| Confidence intervals, `level()`, and transforms | `test_kmplot.do`, `validation_kmplot.do` |
| Median lines and stored medians | `test_kmplot.do`, `validation_kmplot.do` |
| Risk table, `riskheight()`, `riskevents`, `riskcompact`, `riskmono`, `timepoints()` | `test_kmplot.do`, `validation_kmplot.do` |
| Delayed-entry risk-table counts | `validation_kmplot.do` |
| `landmark()` and returned landmark matrix | `test_kmplot.do`, `validation_kmplot.do` |
| `saving()` and `risksaving()` datasets | `test_kmplot.do` |
| Censor marks and `censorthin()` | `test_kmplot.do` |
| P-value computation, formatting, text, and positioning | `test_kmplot.do`, `validation_kmplot.do` |
| Rich reproducibility metadata and returned matrices | `test_kmplot.do` |
| Appearance, labels, scheme, graph name, aspect ratio | `test_kmplot.do` |
| `export()` success and failure paths | `test_kmplot.do`, `validation_kmplot.do` |
| Data preservation and session-state restoration | `test_kmplot.do`, `validation_kmplot.do` |

## Lane Membership

| Lane | Suites |
|------|--------|
| quick | `test_kmplot.do` |
| core | `test_kmplot.do`, `validation_kmplot.do` |
| full | `test_kmplot.do`, `validation_kmplot.do` |

Each suite prints a parseable `RESULT: <suite> tests=N pass=N fail=N` line.
