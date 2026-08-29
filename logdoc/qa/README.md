# logdoc QA

This flat suite tests `logdoc` conversion, session, batch, combine, replay, Python setup, and release-surface rendering. `run_all.do` owns the curated lane membership, and every suite is independently runnable from this directory.

## How to run

```bash
cd logdoc/qa
stata-mp -b do run_all.do                 # full release gate (default)
stata-mp -b do run_all.do quick            # fast functional lane
stata-mp -b do run_all.do core             # functional, validation, and current regressions
stata-mp -b do test_logdoc_v117.do         # one standalone suite
```

## Isolation

`run_all.do` installs into process-unique `PLUS` and `PERSONAL` directories under `c(tmpdir)` and restores the caller's sysdirs before exit. Concurrent runs of the same lane must still use separate scratch copies because batch-mode suite logs share this directory.

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` checks known output content and invariants. There is no `crossval_*` layer because this deterministic renderer has no independent external implementation.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N` and exits nonzero when `fail` is nonzero; the full lane permits no skips.
- The curated runner sandboxes `PLUS` and `PERSONAL` under `c(tmpdir)`, reinstalls `logdoc` from the package directory before each suite, and restores the caller's sysdirs.
- Paths derive from `c(pwd)`; no suite contains a machine-local repository path.
- Inputs are generated at runtime under `c(tmpdir)`; there are no tracked QA data fixtures.
- Generated `.log`, `.smcl`, `.dta`, `.xlsx`, and other temporary outputs are gitignored; tracked documentation assets remain under `demo/`.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_logdoc.do` | Core conversions, formats, run mode, return values, package install, and state restoration |
| `test_logdoc_py.do` | Python discovery, configuration, install actions, option errors, and session-state preservation |
| `test_logdoc_phase78.do` | Notebook, batch, append, email, annotation, diff, session, replay, and output-format behavior |
| `test_documentation_examples.do` | Installed-user README/help workflows for conversion, formats, session, `run`, batch/combine/diff, append/replay, and Python setup |
| `test_logdoc_refactor_guards.do` | Option, config, CSS, filtering, return-contract, RNG, and installed-user guard regressions |
| `test_logdoc_v111.do` | Version 1.1.1 renderer-failure, replay, PDF/docx, UTF-8, and config regressions |
| `test_logdoc_v112.do` | Version 1.1.2 shell-argument and embedded-quote forwarding regressions |
| `test_logdoc_v114.do` | Executable paths with spaces, SMCL help links, `r(compare)`, and the Stata help render oracle |
| `test_logdoc_v115.do` | Source/output collision, child-run failure, HTML structure and injection, renderer atomicity, direct-CLI validation, and platform regressions |
| `test_logdoc_v117.do` | Config allowlisting, dotted output paths, quoted comma filenames, zero-result batch errors, helper state restoration, and help-table width |
| `test_logdoc_hostile.do` | Shell-hostile paths, quoted space-containing paths, 31-character basenames, extended missing values, and caller-data preservation |
| `test_logdoc_errors.do` | Exact early and late public error codes, output non-creation, active-estimate preservation, and varabbrev restoration |

### Validation

| File | Covers |
|---|---|
| `validation_logdoc.do` | Known-answer HTML/Markdown/SMCL rendering and artifact-content validation |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner |
| `tools/_logdoc_check_sthlp_width.py` | Self-contained Stata Viewer column-width oracle for released help files |

## Coverage map

| Command/subcommand | Functional | Validation | Also exercised in |
|---|---|---|---|
| `logdoc` conversion | `test_logdoc.do` | `validation_logdoc.do` | Documentation examples, error contracts, Phase 7–8, refactor, and version regressions through v1.1.7 |
| `logdoc start` / `stop` | Phase 7–8 | — | Refactor guards and version regressions |
| `logdoc batch` | Phase 7–8 | — | Refactor guards and version regressions through v1.1.7 |
| `logdoc combine` | Phase 7–8 | — | Refactor guards and version regressions through v1.1.7 |
| `logdoc diff` | Phase 7–8 | — | Refactor guards |
| `logdoc replay` | Phase 7–8 | — | Refactor guards and version regressions |
| `logdoc_py` | `test_logdoc_py.do` | — | Error contracts and version/release-surface regressions through v1.1.7 |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate.

| Lane | Suites |
|---|---|
| `quick` | `test_logdoc.do`, `test_logdoc_py.do` |
| `core` | `quick` plus `validation_logdoc.do`, `test_logdoc_phase78.do`, `test_documentation_examples.do`, `test_logdoc_v114.do`, `test_logdoc_v115.do`, `test_logdoc_v117.do`, `test_logdoc_hostile.do`, and `test_logdoc_errors.do` |
| `full` (default) | `core` plus `test_logdoc_refactor_guards.do`, `test_logdoc_v111.do`, and `test_logdoc_v112.do` |
