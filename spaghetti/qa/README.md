# spaghetti QA

This flat suite covers the public trajectory plot command, its deterministic invariants, and literal safe help examples. `run_all.do` is the curated runner and each suite runs from this directory.

## How to run

```bash
cd spaghetti/qa
stata-mp -b do run_all.do          # default full lane
stata-mp -b do run_all.do quick
stata-mp -b do test_spaghetti_documentation_examples.do
```

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` covers known-answer and invariant checks; no external cross-validation applies.
- Every suite emits a terminal `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure.
- Each suite reinstalls the package from `../`; paths derive from `c(pwd)` and generated artifacts are disposable.

## Dependencies

| Suite | Needs | If missing |
|---|---|---|
| Documentation examples | Stata `webuse nlswork` access | Hard failure |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_spaghetti.do` | Public options, graph behavior, and edge cases. |
| `test_spaghetti_documentation_examples.do` | Literal safe help workflows on `nlswork` with returned-result assertions. |
| `test_spaghetti_errors.do` | Exact incompatible-option error paths with data preservation assertions. |
| `test_spaghetti_hostile.do` | Excess-group and extended-missing hostile-input contracts. |

### Validation

| File | Covers |
|---|---|
| `validation_spaghetti.do` | Sampling, group-mean, confidence-interval, and returned-value invariants. |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Curated `quick`, `core`, and default `full` runner. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `spaghetti` | Functional, documentation-example, and error-contract suites | `validation_spaghetti.do` | Curated full lane. |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate.

| Lane | Suites |
|---|---|
| `quick` | `test_spaghetti.do`, `test_spaghetti_documentation_examples.do` |
| `core` | `quick` plus `validation_spaghetti.do` |
| `full` | `core` |
