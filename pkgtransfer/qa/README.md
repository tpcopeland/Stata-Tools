# pkgtransfer QA

The `pkgtransfer` QA suite covers transfer-script generation, local and online bundles, tracked-file handling, installer behavior, and known-answer output contracts. Run suites from this directory so their `c(pwd)`-based paths resolve.

## How to run

```bash
cd pkgtransfer/qa
stata-mp -b do run_all.do          # full lane (default)
stata-mp -b do run_all.do quick    # functional, regression, error, and isolation suites
stata-mp -b do run_all.do core     # quick plus the fixture and validation suites
stata-mp -b do run_all.do network  # opt-in: live internet sources and a local HTTP server
stata-mp -b do test_pkgtransfer_v113.do
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
| `test_pkgtransfer_errors.do` | Public parser rejection for download, OS, dofile, zipfile extension (with `download()`), and zipfile without `download()`; asserts rc and the displayed message. |
| `test_pkgtransfer_hostile.do` | Shell-metacharacter filenames and nonexistent-package refusal; asserts rc and the displayed message. |
| `validation_pkgtransfer.do` | Known-answer script content, filtering, filenames, return values, and mode contracts. |
| `test_pkgtransfer_v111.do` | Cross-package plugin/ordinary/metadata collisions, gtools-substring OS selection, output paths, GitHub bootstrap, session fingerprints, lifecycle replay, console/return parity, 54 hostile-string cells, and help rendering with a positive control. |
| `test_pkgtransfer_v113.do` | Byte-exact `restore` of trackers with headers, blank lines, pipes, quotes, tabs, and long lines; piped and long `d` lines in local and online bundles; `N` records as the only package-name source; relocated installer (archive base name); installer `replace` upgrade followed by `restore` on the resulting duplicate tracker; `os(MacOSX)` console platforms and every [R] net platform family; local-path omission note and URL-scheme rule; numbered never-overwritten `stata.trk` backups; standalone `restore` option refusal; whole-name plugin matching; rc 498 (plugin without platform record) and rc 693 (blocked bundle directory); tab-separated two-field `g` records with one plugin name in several platform directories (`traj` shape) in online bundles; online restore markers that keep the tracker source exactly. Fixture trackers include a header, a blank line, and a pipe. |
| `test_pkgtransfer_network.do` | Live-internet round trip (network lane): `fre` and `gtools` from SSC, `traj` from andrew.cmu.edu (tab-separated two-field `g` records, one plugin name in eight platform directories), and `datefix` from raw.githubusercontent.com through script-only output, `download(online)`, `download(local)` with each `os()`, a relocated install on a clean target where the `gtools` and `traj` plugins compute, and an exact `restore` of every live source. Unreachable sources fail. |
| `test_pkgtransfer_http.do` | Descriptor served by `python3 -m http.server` on 127.0.0.1 (network lane; Linux/macOS): `OSX.ARM64`, `G` case, `../` sources, tab-separated fields, and piped/quoted `d` text through online and local bundles, install of this platform's plugin on a target, and exact `restore`. A server that does not start fails. |
| `test_pkgtransfer_isolation.do` | Real caller installation and exact tracker/code preservation across the error and hostile suites. |
| `_qa_state.do` | Vendored session fingerprint helper. |
| `_qa_hostile.do` | Vendored hostile-string corpus. |
| `_qa_lifecycle.do` | Vendored lifecycle replay helper. |
| `_qa_parity.do` | Vendored surface-parity helper. |
| `_qa_fx_a7.do` | Vendored qa-lib A7 fixture helper (deterministic labelled datasets and owned file trees); the name is the qa-lib archetype name, used by the three fixture suites. |
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner. |

## Lane membership

| Lane | Suites |
|---|---|
| `quick` | `test_pkgtransfer.do`, `test_pkgtransfer_v104.do`, `test_pkgtransfer_v105.do`, `test_pkgtransfer_v110.do`, `test_pkgtransfer_installed.do`, `test_pkgtransfer_errors.do`, `test_pkgtransfer_hostile.do`, `test_pkgtransfer_v111.do`, `test_pkgtransfer_v113.do`, `test_pkgtransfer_isolation.do` |
| `core` | `quick` plus `validation_pkgtransfer_fixture_contract.do`, `validation_pkgtransfer_fixture_primitives.do`, `test_pkgtransfer_fixture_state.do`, and `validation_pkgtransfer.do` |
| `full` | Same membership as `core`; default release gate |
| `network` | `test_pkgtransfer_network.do` and `test_pkgtransfer_http.do` only; opt-in, needs internet access and `python3` |

`quick` is a subset of `core`; `core` and `full` are identical. `network` is separate so the release gate stays deterministic and offline; run it before a release that touches download, plugin, or restore code.

## Known gaps

- The deterministic lanes use local-path sources; real HTTP and live repositories are exercised only by the opt-in `network` lane, whose live sources (SSC, andrew.cmu.edu, GitHub) can move or go offline.
- Windows targets and Windows-written trackers are not exercised on a Windows machine.

## Coverage map

| Command | Regression witnesses |
|---|---|
| `pkgtransfer` | `test_pkgtransfer_v111.do` covers both bundle routes and published package/output returns; `test_pkgtransfer_v113.do` covers tracker and descriptor fidelity, the generated installer, `restore` backups and option refusal, OS platform families, the rc 498/693 routes, tab-separated two-field `g` records in online bundles, and exact online restore markers; `test_pkgtransfer_network.do` and `test_pkgtransfer_http.do` (network lane) cover live HTTP sources; `test_pkgtransfer_isolation.do` measures caller installation survival. Existing functional and validation suites cover the rest of the option and return surface. |

archetypes: A7(pkgtransfer)

## Canonical fixture adoption

Isolated tracker fixture produces exact alpha net-install and fre SSC installer commands; quote and extensionless path refusals preserve caller state. These are implemented suites; independent adoption signoff is pending. Remaining unexercised public routes and generic minima remain visible in the fixture census.

| File | Coverage | Lanes |
| --- | --- | --- |
| `validation_pkgtransfer_fixture_contract.do` | Canonical fixture truth and hostile contracts | core/full |
| `validation_pkgtransfer_fixture_primitives.do` | Exact generated installer text and hostile caller-data preservation | core/full |
| `test_pkgtransfer_fixture_state.do` | Exact absent/numeric/string native cv preservation, variable shadow, success/refusal and next import | core/full |
