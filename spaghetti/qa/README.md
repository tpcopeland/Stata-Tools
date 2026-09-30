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

archetypes: A3

- `test_*` covers functional and regression behavior; `validation_*` covers known-answer and invariant checks; no external cross-validation applies.
- Every suite emits a terminal `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure.
- Suites reinstall from `../` with their existing package-local install pattern; this runner does not provide a PLUS/PERSONAL sandbox.
- Paths derive from `c(pwd)`; seeded or noiseless data are generated at runtime and generated artifacts are disposable and gitignored.

## Dependencies

| Suite | Needs | If missing |
|---|---|---|
| Documentation examples | Stata `webuse nlswork` access | Hard failure |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_fixture_names.do` | Long-name invariance for actual public output values and returned identities. |
| `test_spaghetti.do` | Public options, graph behavior, and edge cases. |
| `test_spaghetti_documentation_examples.do` | Literal safe help workflows on `nlswork` with returned-result assertions. |
| `test_spaghetti_errors.do` | Exact incompatible-option error paths with data preservation assertions. |
| `test_spaghetti_hostile.do` | Excess-group and extended-missing hostile-input contracts. |

### Validation

| File | Covers |
|---|---|
| `validation_fixture_contract.do` | Exact person, row, group and sample returns on noiseless trajectories, shuffled rows, single-time subjects and overlapping or empty groups; graphs are removed after assertions. |
| `validation_spaghetti.do` | Sampling, group-mean, confidence-interval, and returned-value invariants. |

### Support

| Path | Contents |
|---|---|
| `_qa_fx_a3.do` | Byte-identical vendored qa-lib helper; never edited here. |
| `_qa_metamorphic.do` | Byte-identical vendored qa-lib helper; never edited here. |
| `_qa_state.do` | Byte-identical vendored qa-lib helper; never edited here. |
| `run_all.do` | Curated `quick`, `core`, and default `full` runner. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `spaghetti` | Functional, documentation-example, error-contract and `test_fixture_names.do` suites | `validation_spaghetti.do`, `validation_fixture_contract.do` | Curated full lane. |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate.

| Lane | Suites |
|---|---|
| `quick` | Functional, documentation-example, exact error and hostile-input suites listed in run_all.do. |
| `core` | Quick plus general validation and canonical trajectory/name contracts. |
| `full` | `core` |

## Known gaps

Canonical mean-curve rendering and noiseless return invariants do not establish stochastic estimator recovery.
