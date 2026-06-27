# tvtools QA suite

Flat, concern-then-command `qa/` layout driven by one lane-based `run_all.do`.
tvtools builds time-varying datasets for survival analysis (commands `tvage`,
`tvdiagnose`, `tvevent`, `tvexpose`, `tvmerge`, `tvweight`, and the `tvtools`
dispatcher). This suite was consolidated from two append-grown monoliths
(`test_tvtools.do`, 354 functional tests; `validation_tvtools.do`, 558
validation tests) into per-command and per-concern suites. Merged origins are
preserved verbatim under `**# ===== merged from … =====` banners. Large
append-grown regions that lived inside a single `capture noisily {}` scope and
intermixed commands could not be cut per command without changing their
semantics; those are kept intact in the cross-cutting concern suites
(`test_options`, `test_integration`, `test_edge_cases`, `test_regressions`,
`validation_boundary`, `validation_pipeline`, `validation_supplemental`).

## How to run

```bash
cd tvtools/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do run_all.do core       # quick + regressions + validation oracles
stata-mp -b do run_all.do python     # cross-validation parity only
```

`run_all.do` runs a curated per-lane suite list (not auto-discovery), sources
the shared `_tvtools_qa_common.do` scaffold, sandboxes PLUS/PERSONAL under
`c(tmpdir)` via `_tvtools_qa_bootstrap` (the real ado tree is never touched),
and exits nonzero if any suite fails. Every file is independently runnable from
`qa/` (e.g. `stata-mp -b do test_tvexpose.do`); each one re-sources the scaffold
and re-bootstraps after its own `clear all`.

## Conventions

- Prefixes: `test_*` (functional/regression), `validation_*` (hand-computable
  known-answer / invariant oracles), `crossval_*` (parity vs an external
  reference implementation).
- Every suite ends with the machine-parseable sentinel
  `RESULT: <name> tests=N pass=N fail=N` and `exit 1` on any failure.
- Consolidated suites preserve their origin bodies verbatim under
  `**# ===== merged from … =====` banners; section labels are comments, not
  decorative `display` lines.
- Shared assertion/verification helpers (`assert_exact`, `assert_approx`,
  `_validate_tvexpose_output`, `_verify_ptime_conserved`, `_verify_no_overlap`,
  `_check_log`) and the `run_test`/`test_pass`/`test_fail` harness live in
  `_tvtools_qa_common.do`.
- Tracked input fixtures live in `data/`; suites derive paths from `c(pwd)` and
  never hard-code absolute paths. Generated logs/datasets are gitignored.

## File index

### Command-level functional tests
| File | Command | Notes |
|------|---------|-------|
| `test_tvage.do` | tvage | Age-interval creation, grouping, expanded edge cases |
| `test_tvevent.do` | tvevent | Event splitting and interval construction |
| `test_tvexpose.do` | tvexpose | Time-varying exposure creation |
| `test_tvmerge.do` | tvmerge | Multi-dataset interval merging |
| `test_tvpanel.do` | tvpanel | Fixed-width person-period panel construction, option/return coverage, label and temp-name regressions |
| `test_tvweight.do` | tvweight | IPTW weights + comprehensive option coverage |
| `test_tvdiagnose.do` | tvdiagnose | Coverage/gap/overlap diagnostics |
| `test_tvtools.do` | tvtools | Dispatcher command routing |

### Cross-cutting concern tests
| File | Covers | Notes |
|------|--------|-------|
| `test_options.do` | tvexpose/tvmerge/tvevent option groups | Revived from a previously-dead `test_pass` harness block (see Residual notes) |
| `test_integration.do` | cross-command pipelines + per-command gap coverage | Single `capture` scope; intermixes commands |
| `test_edge_cases.do` | edge cases + stress tests | Revived from previously non-gating local counters |
| `test_regressions.do` | gap coverage, deliberation/review fixes, Codex audit fixes, bug-fix regressions | Version- and review-specific regressions |
| `test_verbose.do` | verbose option across tvexpose/tvdiagnose/tvmerge | Log-content assertions via `_check_log` |

### Validation (hand-computable oracles)
| File | Covers |
|------|--------|
| `validation_tvage.do` | tvage age math + expanded validation |
| `validation_tvevent.do` | tvevent splitting + person-time conservation |
| `validation_tvexpose.do` | tvexpose exposure tracking + person-time |
| `validation_tvmerge.do` | tvmerge correctness + person-time additivity |
| `validation_tvweight.do` | tvweight IPTW properties + expanded validation |
| `validation_tvdiagnose.do` | tvdiagnose deep validation |
| `validation_boundary.do` | event/interval boundary correctness, tvexpose boundary |
| `validation_pipeline.do` | end-to-end pipeline + continuous/person-time conservation |
| `validation_supplemental.do` | cross-command math validation, return-value completeness, invariants |
| `validation_known_answers.do` | hand-computed tvexpose→tvmerge→tvage→tvevent workflows |

### Cross-validation
| File | Purpose |
|------|---------|
| `crossval_tvtools.do` | Parity against the external reference implementation |

### Support
| Path | Contents |
|------|----------|
| `_tvtools_qa_common.do` | Sandboxed install bootstrap, shared helpers, test globals |
| `run_all.do` | Curated lane runner (quick/core/python/full) |
| `data/` | Tracked input fixtures + `generate_test_data.do` |
| `.gitignore` | Ignore generated logs/datasets/artifacts |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---------|-----------|-----------|-----------|-------------------|
| tvage | `test_tvage` | `validation_tvage`, `validation_known_answers` | `crossval_tvtools` | `test_options`, `test_regressions`, `validation_pipeline`, `validation_supplemental` |
| tvdiagnose | `test_tvdiagnose` | `validation_tvdiagnose` | `crossval_tvtools` | `test_integration`, `test_verbose`, `test_regressions`, `validation_supplemental` |
| tvevent | `test_tvevent` | `validation_tvevent`, `validation_known_answers`, `validation_boundary` | — | `test_options`, `test_regressions`, `validation_pipeline`, `validation_supplemental` |
| tvexpose | `test_tvexpose` | `validation_tvexpose`, `validation_boundary` | `crossval_tvtools` | `test_options`, `test_integration`, `test_verbose`, `test_regressions`, `validation_pipeline`, `validation_supplemental` |
| tvmerge | `test_tvmerge` | `validation_tvmerge` | `crossval_tvtools` | `test_options`, `test_integration`, `test_verbose`, `test_regressions`, `validation_supplemental` |
| tvpanel | `test_tvpanel` | — | — | `test_regressions` |
| tvtools (dispatcher) | `test_tvtools` | — | — | — |
| tvweight | `test_tvweight` | `validation_tvweight` | `crossval_tvtools` | `test_options`, `test_regressions`, `validation_supplemental` |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | `test_tvage`, `test_tvevent`, `test_tvexpose`, `test_tvmerge`, `test_tvpanel`, `test_tvweight`, `test_tvdiagnose`, `test_tvtools`, `test_options`, `test_integration`, `test_edge_cases`, `test_verbose` |
| `core` | `quick` + `test_regressions`, `validation_known_answers`, `validation_tvage`, `validation_tvevent`, `validation_tvexpose`, `validation_tvmerge`, `validation_tvweight`, `validation_tvdiagnose`, `validation_boundary`, `validation_pipeline`, `validation_supplemental` |
| `python` | `crossval_tvtools` |
| `full` *(default)* | `core` + `python` |
