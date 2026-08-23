# pkgtransfer QA

The `pkgtransfer` QA suite covers transfer-script generation, local and online bundles, tracked-file handling, installer behavior, and known-answer output contracts. Run suites from this directory so their `c(pwd)`-based paths resolve.

## How to run

```bash
cd pkgtransfer/qa
stata-mp -b do run_all.do          # full lane (default)
stata-mp -b do run_all.do quick    # functional and regression tests
stata-mp -b do run_all.do core     # quick plus validation
stata-mp -b do test_pkgtransfer_v105.do
stata-mp -b do test_pkgtransfer_v110.do
```

Gate on the terminal `RESULT: <name> tests=N pass=N fail=N skip=N` line, not Stata batch mode's shell status alone.

## Isolation

`_pkgtransfer_qa_common.do` creates temporary `PLUS` and `PERSONAL` directories, builds a synthetic `stata.trk`, and restores the caller's sysdirs. The suites do not read or modify the user's installed package registry. Because the lane writes logs in the shared `qa/` directory, run concurrent lanes from separate scratch copies of the repository layout.

## Conventions

- `test_*.do` files cover functional behavior and fixed-bug regressions; `validation_*.do` files verify deterministic output content and return values.
- Every runnable suite emits one terminal machine-readable `RESULT:` record and exits nonzero on failure.
- All paths derive from `c(pwd)` or temporary paths; no suite relies on a machine-local repository path.
- Transfer fixtures and generated `.do`, `.zip`, `.log`, and extracted files are disposable and are removed after each test.
- Tests inspect exact script, package-descriptor, plugin, and return-value content rather than treating file existence as sufficient evidence.
- There is no external R or Python implementation for this filesystem-packaging command; deterministic Stata known-answer checks provide the validation layer.

## File index

| File | Covers |
|---|---|
| `_pkgtransfer_qa_common.do` | Sandboxed `PLUS`/`PERSONAL` fixture setup and cleanup. |
| `test_pkgtransfer.do` | Public options, errors, script generation, transfer modes, cleanup, plugins, and installed-bundle behavior. |
| `test_pkgtransfer_v104.do` | Selector normalization, nested ordinary/plugin paths, traversal rejection, failure returns, generated-installer state, duplicate-source handling, and output-path quote guards. |
| `test_pkgtransfer_v105.do` | Version-3 distribution metadata, SSC and parent-relative plugin handling, directive-case and install witnesses, multi-plugin bundles, restore-marker namespacing, and runner isolation. |
| `test_pkgtransfer_v110.do` | Default all-platform plugin bundles, explicit OS filtering for local and online modes, removal of redundant target copies, and installation from a filtered descriptor. |
| `test_pkgtransfer_installed.do` | Fresh `net install`, installed-command execution, and bundled helper definitions in a local transfer archive. |
| `test_pkgtransfer_errors.do` | Exact public parser rejection for download, OS, dofile, and zipfile contracts. |
| `test_pkgtransfer_hostile.do` | Shell-metacharacter filenames and nonexistent-package refusal. |
| `validation_pkgtransfer.do` | Known-answer script content, filtering, filenames, return values, and mode contracts. |
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner. |

## Lane membership

| Lane | Suites |
|---|---|
| `quick` | Functional, regression, installed-user, and error-contract suites in `run_all.do`. |
| `core` | `quick` plus `validation_pkgtransfer.do` |
| `full` | Same membership as `core`; default release gate |

`quick` is a subset of `core`; `core` and `full` are identical because the package has no external-oracle or slow-test lane.

## Known gaps

- Network behavior is tested with local `file://`-style sources; availability and behavior of arbitrary third-party package repositories are outside the package's deterministic QA boundary.
