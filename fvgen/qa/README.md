# fvgen QA

The `fvgen` QA suite is flat and concern-oriented, with one curated lane runner and independently runnable suites covering generation, provenance, margins replay, installed-user behavior, and known-answer equivalence.

## How to run

From the package QA directory:

```bash
cd fvgen/qa
stata-mp -b do run_all.do          # full lane (default release gate)
stata-mp -b do run_all.do quick    # fastest functional smoke
stata-mp -b do run_all.do core     # functional, error, state, and validation coverage
stata-mp -b do test_regressions.do # one suite standalone
```

`run_all.do` requires one well-formed, arithmetically reconciled `RESULT:` sentinel from every suite and exits nonzero on a suite failure or contract failure.

## Isolation

Each suite redirects `PLUS` and `PERSONAL` to temporary directories through `_fvgen_qa_common.do`, uninstalls any package copy visible in that sandbox, and installs the local source. Use the devkit isolated runner when another process may be running the same lane, because Stata batch logs otherwise share the live `qa/` directory.

## Conventions

- `test_*` files provide functional and regression coverage; `validation_*` files provide hand-computed and invariant oracles; `crossval_*` is reserved for parity against an independent external implementation; `benchmark_*` is reserved for timing guardrails outside correctness lanes.
- Every runnable suite ends with exactly one `RESULT: <name> tests=N pass=N fail=N [skip=N]` sentinel and exits nonzero on failure. The full release gate accepts no skips.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` through `_fvgen_qa_common.do`, so they do not use the user's installed copy.
- Paths derive from `c(pwd)`; no suite contains a machine-local path.
- Test data are generated at runtime from seeded builders or explicit hand-computed inputs; no `.dta` fixtures are tracked.
- Generated `.log`, `.smcl`, `.dta`, workbook, and image artifacts are disposable and gitignored; only documented assets under `demo/` may be tracked.
- Stata bookmarks (`**#` and `**##`) identify foldable test sections.

`fvgen` is a deterministic transform, so known-answer and native-design validation are the correctness oracles; no external cross-validation layer is needed.

## File index

### Functional and regression tests

| File | Covers |
|------|--------|
| `test_fvgen.do` | Core generation surface, returns, labels, naming, options, missingness, qualifiers, all four weight types, and weighted level discovery. |
| `test_ref.do` | Per-factor reference levels, native `ibN.` equivalence, quoted value-label resolution, `alllevels`, and `fvset` preservation. |
| `test_simple.do` | Per-group slope parameterization, labels, multi-level moderators, retained main effects, and `simple()` with `center`. |
| `test_errors.do` | Exact error codes for unsupported specifications and options plus `varabbrev` restoration on success and failure. |
| `test_provenance.do` | Variable and dataset provenance, teardown returns, idempotence, pass-through survival, and strict drop syntax. |
| `test_margins.do` | Active and stored margins clones, estimator-family and VCE parity, survey replay, store replacement, and unsupported paths. |
| `test_regressions.do` | Review regressions for name collisions, exact reference-label mapping, stale-data guards, replay-failure restoration, and nonconvergence rejection. |
| `test_fvgen_hostile.do` | Adversarial namespace collision and empty-data state preservation. |
| `test_fvgen_oracle.do` | Seeded row-level factor-indicator and product oracles plus generated-name shadow preservation. |
| `test_package_release.do` | Isolated install resolution, repeated autoload, every visible help workflow, and help-render integrity with a positive control. |

### Validation

| File | Covers |
|------|--------|
| `validation_fvgen.do` | Hand-computed dummy/product values, native model-space equivalence, and centering invariance. |

### Support

| File | Covers |
|------|--------|
| `_fvgen_qa_common.do` | Sandboxed local-install bootstrap and seeded synthetic-data builder. |
| `run_all.do` | Curated `quick`, `core`, and `full` lane membership plus suite-sentinel enforcement. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|------------|------------|-------------------|
| `fvgen` | `test_fvgen`, `test_ref`, `test_simple`, `test_errors`, `test_provenance`, `test_margins`, `test_regressions` | `validation_fvgen`, `test_fvgen_oracle` | `test_fvgen_hostile`, `test_package_release` |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate.

| Lane | Suites |
|------|--------|
| `quick` | `test_fvgen` |
| `core` | `quick` plus `test_ref`, `test_simple`, `test_errors`, `test_provenance`, `test_margins`, `test_regressions`, `test_fvgen_hostile`, `test_fvgen_oracle`, and `validation_fvgen` |
| `full` | `core` plus `test_package_release` |
