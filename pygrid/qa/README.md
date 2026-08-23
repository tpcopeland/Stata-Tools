# pygrid QA

The `pygrid` QA suite is flat and concern-oriented, with one curated lane runner and independently runnable suites for functional behavior, known-answer validation, external parity, package contracts, and performance guardrails.

## How to run

```bash
cd pygrid/qa
stata-mp -b do run_all.do            # full lane (default gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do test_pygrid.do        # one suite standalone
```

The repository CLI can run the default gate in a scratch copy:

```bash
python3 -m _devkit.stata_dev_cli run qa pygrid --mode full --isolated
```

Gate on the final `RESULT:` sentinel. A missing sentinel, inconsistent arithmetic, suite error, or nonzero failure count is a hard failure.

## Isolation

`run_all.do` and the suites write logs in `qa/`, so concurrent runs of the same package can corrupt one another. Use the isolated CLI invocation above or a scratch copy that preserves the repository layout and starts without copied `qa/*.log` files.

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use hand-computable or independently constructed Stata oracles; `crossval_*` files compare with independent R or official Stata implementations; `benchmark_*` files are timing guardrails outside correctness lanes.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N skip=N` and exits nonzero on any failure; the `full` lane accepts no skipped suite.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` through `_pygrid_qa_common.do` so installed copies cannot shadow the adjacent source.
- Paths derive from `c(pwd)`; no suite contains a machine-local repository path.
- Test data are generated at runtime from deterministic inline fixtures and builders; `data/` is reserved for deliberate future fixtures.
- Generated logs and transient datasets are gitignored; only reader-facing assets under `demo/` may be tracked.
- Known-truth assertions pin row values and arithmetic identities, while package-contract QA checks installed helper discovery and rendered help rather than source existence alone.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `crossval` | `Rscript` and R package `survival` | Hard failure |
| `benchmark` | Sufficient memory for 1M-person grids and 10M-event data | Hard failure |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_pygrid.do` | Axes, date and identifier contracts, period rules, overlap rejection, output names, returns, state restoration, and error paths. |
| `test_pyattach.do` | Measures, zero filling, filters, exclusive bounds, grid integrity, orphan policies, identifier/date contracts, repeated calls, and rollback. |
| `test_package_contracts.do` | Installed helper autoloading, saved characteristics, rollback, package inventory, version placement, and SMCL rendering with a positive control. |
| `test_doc_examples.do` | Executable README and help workflows with semantic value assertions after local installation. |
| `test_pygrid_errors.do` | Exact public pygrid/pyattach failure codes and no-mutation contracts. |
| `test_pygrid_hostile.do` | Overlapping episode refusal under an adversarial denominator shape. |

### Validation

| File | Covers |
|---|---|
| `validation_pygrid_known_truth.do` | Hand-computed person-time, boundary dates, window restrictions, randomized partition identities, and input-order invariance. |
| `validation_pyattach_known_truth.do` | Zero-filled denominators, exact rates, orphan accounting, all-missing sums, and boundary assignments. |
| `validation_pyattach_reference.do` | Exact equality against a direct interval join, including repeated same-period episodes. |
| `validation_mogad_section4d.do` | Self-contained equality between six MOGAD-shaped manual tables and the `pygrid`/`pyattach` rewrite. |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_pygrid.do` + `crossval_pygrid.R` | R `survival::survSplit`, official Stata `stsplit`, and official Stata `strate`. |

### Support and performance

| Path | Contents |
|---|---|
| `run_all.do` | Explicit quick, core, crossval, full, and benchmark lane dispatch with failure propagation. |
| `_pygrid_qa_common.do` | Local install isolation, fixture construction, result accounting, and help-render oracle. |
| `benchmark_pygrid.do` | Scaling guardrails for large denominator grids and event attachments; benchmark lane only. |
| `data/` | Reserved fixture directory; current suites generate their data at runtime. |
| `README.md` | This contributor runbook and coverage index. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `pygrid` | `test_pygrid.do`, error contracts | `validation_pygrid_known_truth.do` | `crossval_pygrid.do` | Package contracts, doc examples, MOGAD rewrite, and attachment suites |
| `pyattach` | `test_pyattach.do` | `validation_pyattach_known_truth.do`, `validation_pyattach_reference.do` | `crossval_pygrid.do` | Package contracts, doc examples, and MOGAD rewrite |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default gate. The explicit suite lists in `run_all.do` are authoritative.

| Lane | Suites |
|---|---|
| `quick` | Functional, package-contract, and documentation-example suites |
| `core` | `quick` plus all known-answer and study-rewrite validations |
| `crossval` | R and official-Stata parity only |
| `full` | `core` plus `crossval` |
| `benchmark` | Performance guardrails only; run on demand |

## Known gaps

- The external MOGAD RWE0967 production pipeline cannot be rerun locally because its matched controls lack the required matched-case index dates. `validation_mogad_section4d.do` supplies a self-contained equivalence oracle; a production-data rerun remains an upstream study-data task.

## Benchmarks

Run `stata-mp -b do run_all.do benchmark` on demand. The suite fixes Stata to one processor and checks scaling ratios rather than absolute wall time, so it is a performance regression signal rather than a correctness or hardware comparison gate.
