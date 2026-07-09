# logdoc QA suite

This flat suite tests `logdoc` conversion, session, batch, combine, replay, and Python-setup behavior. `run_all.do` uses an explicit full-suite list and exits nonzero if any suite fails. Each file derives the package root from `c(pwd)` and can be run directly from `qa/`.

## How to run

```bash
cd logdoc/qa
stata-mp -b do run_all.do
stata-mp -b do test_logdoc_v112.do
```

The full runner reinstalls only `logdoc` before each suite to avoid an installed copy shadowing the package under test. Tests generate inputs and outputs under `c(tmpdir)`; logs and other runtime artifacts are not fixtures.

## Conventions

- `test_*.do` files cover functional and regression behavior; `validation_*.do` checks output content and invariants.
- Tests use `capture noisily`, pass/fail counters, and a nonzero exit when a suite fails.
- Test inputs are generated at runtime and all paths are derived from `c(pwd)` or `c(tmpdir)`.
- No cross-validation lane is needed: logdoc is a deterministic renderer, not an estimator with an independent statistical implementation.

## File index

| File | Covers |
|---|---|
| `test_logdoc.do` | Core conversions, formats, run mode, return values, package install, and state restoration |
| `test_logdoc_py.do` | Python discovery, configuration, install actions, option errors, and session-state preservation |
| `test_logdoc_phase78.do` | Notebook, batch, append, email, annotation, diff, session, replay, and output-format behavior |
| `test_logdoc_refactor_guards.do` | Option, config, CSS, filtering, return-contract, RNG, and installed-user guard regressions |
| `test_logdoc_v111.do` | Version 1.1.1 renderer-failure, replay, PDF/docx, UTF-8, and config regressions |
| `test_logdoc_v112.do` | Version 1.1.2 shell-argument and embedded-quote forwarding regressions |
| `validation_logdoc.do` | Known-answer HTML/Markdown/SMCL rendering and artifact-content validation |
| `run_all.do` | Curated full-suite runner |

## Coverage map

| Command/subcommand | Functional | Validation | Also exercised in |
|---|---|---|---|
| `logdoc` conversion | `test_logdoc.do` | `validation_logdoc.do` | Phase 7–8, refactor, v1.1.1, and v1.1.2 regressions |
| `logdoc start` / `stop` | Phase 7–8 | — | Refactor guards and v1.1.1 regressions |
| `logdoc batch` | Phase 7–8 | — | Refactor guards and v1.1.2 quote regression |
| `logdoc combine` | Phase 7–8 | — | Refactor guards and v1.1.1 regressions |
| `logdoc diff` | Phase 7–8 | — | Refactor guards |
| `logdoc replay` | Phase 7–8 | — | Refactor guards, v1.1.1, and v1.1.2 regressions |
| `logdoc_py` | `test_logdoc_py.do` | — | v1.1.1 and v1.1.2 regressions |

## Lane membership

| Lane | Suites |
|---|---|
| `full` (default) | All six functional/regression suites and `validation_logdoc.do` |
