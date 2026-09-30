# cstat_surv QA

The curated runner exercises functional, documentation-example, validation, and independent cross-validation suites.

archetypes: A2

## How to run

```bash
cd cstat_surv/qa
stata-mp -b do run_all.do
stata-mp -b do test_cstat_surv_documentation_examples.do
```

## Conventions

- `test_*` files cover functional and documentation-example behavior; `validation_*` files use known-answer invariants; `crossval_*` files use independent comparators.
- Each suite emits a terminal `RESULT:` sentinel and exits nonzero on failure.
- Run in an isolated scratch copy because batch logs otherwise collide.
- Paths derive from `c(pwd)`; no machine-local paths are permitted.
- Fixtures are built at runtime or supplied by Stata's `webuse`.
- Generated logs and artifacts are disposable.

## File index

| File | Covers |
|---|---|
| `test_cstat_surv.do` | Functional C-statistic behavior and pair accounting. |
| `test_cstat_surv_errors.do` | Exact pre-estimation, non-Cox, and invalid-level errors with e() preservation. |
| `test_cstat_surv_hostile.do` | 32-character covariate names, extended missingness, repeat calls, and refused-path data/e() preservation. |
| `test_cstat_surv_documentation_examples.do` | Exact self-contained help setup, Cox fit, and C-statistic example. |
| `validation_cstat_surv.do` | Known-answer and identity checks. |
| `crossval_cstat_surv.do` | Independent cross-validation. |
| `crossval_cstat_surv_sksurv.do` | scikit-survival comparator. |
| `test_fixture_entry.do` | Named delayed-entry refusal with complete caller-state fingerprints, both varabbrev settings, and entry outside the Cox sample. |
| `test_fixture_tvc.do` | Named explicit/default time-varying-score refusal with full caller fingerprints and static-model controls under both varabbrev settings. |
| `validation_fixture_truth.do` | Weibull population concordance recovery, independently enumerated pair counts and jackknife on both event definitions, A2 hostile cases, exact time-rank transport, and confidence-level boundaries. |
| `_qa_fx_a2.do` | Byte-for-byte vendored single-record survival and competing-risk generators with truth/provenance. |
| `_qa_hostile.do` | Vendored primitive time values and missing-guarded equality oracle. |
| `_qa_state.do` | Vendored complete caller-state fingerprints. |
| `_qa_metamorphic.do` | Vendored option-domain sweeps and metamorphic relations. |
| `tools/crossval_cstat_surv_sksurv.py` | Native scikit-survival pair-accounting oracle. |
| `run_all.do` | Curated full runner. |

## Coverage map

| Command | Functional | Validation | Cross-validation |
|---|---|---|---|
| `cstat_surv` | Functional, error, hostile, documentation-example, `test_fixture_entry.do`, and `test_fixture_tvc.do` suites | `validation_cstat_surv.do`, `validation_fixture_truth.do` | `crossval_cstat_surv.do`, `crossval_cstat_surv_sksurv.do` |

## Lane membership

The default runner executes every indexed suite.
