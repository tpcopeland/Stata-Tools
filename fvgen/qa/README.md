# fvgen QA

<!-- archetypes: A1 A7 -->

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
| `test_regressions.do` | Review regressions for name collisions, exact reference-label mapping, stale-data guards, replay-failure restoration, nonconvergence rejection, native-refit model-equivalence guards (if-sample and `alllevels` + `noconstant` mismatches), `store()` clobber protection, partial value-label fallback, and string / `i(numlist)` rejection. |
| `test_fvgen_hostile.do` | Adversarial namespace collision and empty-data state preservation. |
| `test_fvgen_oracle.do` | Seeded row-level factor-indicator and product oracles plus generated-name shadow preservation. |
| `test_fixture_metadata.do` | Literal hostile labels through centered, factor, reference, interaction, simple-slope, square and continuous-product routes; Unicode80-character truncation; exact name twins/singleton and named factor-domain/empty-sample refusals. |
| `test_package_release.do` | Isolated install resolution, repeated autoload, every visible help workflow, and help-render integrity with a positive control. |

### Validation

| File | Covers |
|------|--------|
| `validation_fvgen.do` | Hand-computed dummy/product values, native model-space equivalence, and centering invariance. |
| `validation_fixture_matrix.do` | Twelve consumed A1 design/centering cases with independent weighted means and row arithmetic; two finite OLS native-factor active/stored clone and marginal-effect oracles. |

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
| `core` | `quick` plus `validation_fixture_truth`, `validation_fixture_matrix`, `test_fixture_metadata`, `test_ref`, `test_simple`, `test_errors`, `test_provenance`, `test_margins`, `test_regressions`, `test_fvgen_hostile`, `test_fvgen_oracle`, and `validation_fvgen` |
| `full` | `core` plus `test_package_release` |

Canonical fixture adoption is in progress. `3` cases in `validation_fixture_truth.do` ran with zero failures in an isolated copy; independent review is pending. Three cases compare every materialized indicator/product with its labelled-group arithmetic and verify drop removes exactly the six generated variables. Unsorted and label-gap variants are consumed.

| Added QA file | Role |
|---|---|
| `validation_fixture_truth.do` | Known-answer F/U suite; reached from the package runner |
| `_qa_fx_a7.do` | Byte-for-byte canonical fixture vendor |
| `_qa_fx_a1.do` | Byte-for-byte canonical cross-sectional fixture vendor |
| `_qa_hostile.do` | Byte-for-byte primitive/assertion helper vendor |
| `_qa_state.do` | Byte-for-byte session-fingerprint helper vendor |

The expanded matrix ran14/14 and the literal-metadata suite13/13 in private isolated copies after independent review of the1.2.7 transport patch. The matrix consumes every A1 minimum in requested factor/continuous roles; `separate` enters as a transformed continuous input and `near_positivity` as changed factor support, so neither is represented as an estimator claim. Every generated row is checked by arithmetic derived before the command. Finite OLS predictions and native marginal derivatives are checked independently of the candidate clone. The metadata suite checks actual read-back labels across nine hostile texts and each label path, preserving intentional suffixes and the documented80-character Unicode truncation. The source approval does not itself approve these new QA assertions.

Fixture coverage still owed: route-specific weight/reference/margins variants beyond these finite controls and writer contracts where applicable; no interval consumer is declared. Archetype declarations retain census obligations; a green runtime subset does not meet the full census.
