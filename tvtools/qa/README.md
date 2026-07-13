# tvtools QA suite

The tvtools QA suite is controlled by one manifest, `_tvtools_qa_manifest.do`. That manifest is the source of truth for lane membership, pinned assertion counts, and skip policy; `run_all.do` rejects missing, malformed, duplicated, truncated, or arithmetically inconsistent result sentinels.

## Run the suite

Run commands from this `qa/` directory so package-relative paths resolve correctly.

```bash
stata-mp -b do run_all.do quick
stata-mp -b do run_all.do core
stata-mp -b do run_all.do external
stata-mp -b do run_all.do full
stata-mp -b do run_all.do release
stata-mp -b do run_all.do meta
```

`full` is the default. `quick` runs functional and state-contract tests. `core` adds deterministic known-answer and pure-Stata parity suites. `external` contains the three R oracle suites and the optional `rangematch`/`psdash` integration contracts. `full` combines core and external and requires zero skips. `release` adds installed-user package, documentation, dialog, menu, and demo checks. `meta` tests the runner itself.

The runner validates its mode before changing the adopath, creates one unique workspace below `c(tmpdir)`, installs tvtools once into isolated PLUS/PERSONAL directories, copies canonical inputs once, and recursively removes the workspace after either passing or failing suites. A standalone suite performs the same isolated bootstrap when the runner marker is absent.

## Result contract

Every runnable suite emits exactly one final line in this form:

```text
RESULT: suite_name tests=N pass=N fail=N skip=N
```

The `skip=` field may be omitted when zero. Only external-oracle suites may report dependency-absence skips when run through the standalone `external` lane. An installed oracle that crashes, produces malformed output, or disagrees with Stata is a failure. `full` and `release` require zero skips.

## Suite organization

- `test_*.do` files cover public behavior, cross-command integration, runner contracts, session state, optional sibling packages, fixtures, and installed-user release reality.
- `validation_*.do` files use hand-computed or simulation-based known-answer oracles.
- `crossval_*.do` files compare against independent Stata implementations or external R implementations.
- `_tvtools_qa_common.do` owns isolated installation, workspace lifecycle, dependency probing, shared assertions, and result parsing.
- `_tvtools_qa_manifest.do` owns curated lanes and expected counts.
- `tools/fixture_manifest.py` generates or verifies fixture provenance and content metadata.

Core has no undeclared dependency on sibling Stata packages. `test_tvm_overlap_drift_guard.do` and `test_package_optional_integration.do` live in the external lane because they intentionally exercise `rangematch` and `psdash`.

## External dependencies

The external lane discovers `Rscript` through the shell `PATH`. It runs real parity checks using R and the required reference libraries; missing libraries are setup failures and must be installed before release testing. Optional Stata sibling packages are installed into the isolated test sysdir from their adjacent package directories.

## Fixtures

Tracked canonical DTA inputs live in `data/`. `fixtures_manifest.tsv` records every fixture's SHA-256 checksum, byte size, row/column count, variable schema, producer, runnable-root consumers, and lifecycle classification. The runner copies these inputs to its private workspace; suites write disposable products there and never modify the tracked source fixtures.

Regenerate the manifest only after intentional fixture review:

```bash
python3 tools/fixture_manifest.py --write
python3 tools/fixture_manifest.py --check
```

`test_package_fixtures.do` independently enforces exact inventory, schema/checksum parity, and nonempty producer/consumer classifications.

## Artifact policy

Logs, graphs, exported tables, external-oracle intermediates, and generated datasets are disposable and gitignored. Documentation assets under `demo/` are the only intentional generated artifacts outside the fixture inventory.
