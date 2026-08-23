# tc_schemes QA

This flat suite tests the public scheme catalogue's selection, return, error, and session-preservation contracts. `run_all.do` is the curated runner, and every suite is independently runnable from this directory.

## How to run

```bash
cd tc_schemes/qa
stata-mp -b do run_all.do          # full lane (default release gate)
stata-mp -b do run_all.do quick    # functional and error-contract lane
stata-mp -b do test_tc_schemes_errors.do
```

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` covers known-answer invariants. The deterministic catalogue has no independent external oracle.
- Every suite ends with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure.
- Each suite installs `tc_schemes` from `../` after removing an installed copy, so it exercises the package checkout rather than an ambient ado.
- Paths derive from `c(pwd)`; test data are generated at runtime; generated logs and artifacts are gitignored.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_tc_schemes.do` | Catalogue selection, counts, returns, graph availability, and public options. |
| `test_tc_schemes_errors.do` | Exact parser and mutually-exclusive-option errors, state preservation, and legal source normalization. |
| `test_tc_schemes_documentation_examples.do` | Literal safe help-file catalogue and graph examples with graph-structure assertions. |
| `test_tc_schemes_hostile.do` | Repeated-call stale-return resistance and empty-data/foreign-estimates session preservation. |

### Validation

| File | Covers |
|---|---|
| `validation_tc_schemes.do` | Known catalogue membership and scheme-file invariants. |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Curated `quick`, `core`, and default `full` lane runner. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `tc_schemes` | Functional, error-contract, and documentation-example suites | `validation_tc_schemes.do` | Curated full lane. |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate.

| Lane | Suites |
|---|---|
| `quick` | `test_tc_schemes.do`, `test_tc_schemes_errors.do`, `test_tc_schemes_documentation_examples.do`, `test_tc_schemes_hostile.do` |
| `core` | `quick` plus `validation_tc_schemes.do` |
| `full` | `core` |
