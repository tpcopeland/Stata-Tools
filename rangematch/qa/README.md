# rangematch QA suite

The `rangematch` QA suite uses a flat `qa/` root and one curated lane runner,
`run_all.do`. The tests cover the single public command through functional,
adversarial, routing, return-contract, documentation-example, install, release,
and known-answer validation suites. Test data are generated at runtime with
temporary files; generated logs are ignored.

## How to run

```bash
cd rangematch/qa
stata-mp -b do run_all.do
stata-mp -b do run_all.do quick
```

`full` is the default release gate and adds all validation suites to the
functional tests. `quick` runs the functional and release-surface suites only.
The runner uses an explicit suite list rather than auto-discovery and exits
nonzero if any suite fails. Every `.do` file is runnable directly from `qa/`.

## Conventions

- `test_*.do` files cover functional, option, state, regression, release, and
  adversarial contracts for the public command.
- `validation_*.do` files contain hand-computable or invariant oracles.
- **Every** suite emits exactly one terminal `RESULT: <name> tests=N pass=N fail=N`
  sentinel, and `run_all.do` requires one from every suite it calls green. rc=0
  alone cannot tell a suite that finished from one whose log was truncated or
  that died partway; 25 of 51 suites once emitted no sentinel at all. In an
  assert-driven suite a failed `assert` aborts the file, so the sentinel's
  *absence* is the failure signal — which is exactly why the runner checks for
  it rather than only reading rc.
- `run_all.do` sandboxes `PLUS` and `PERSONAL` under `c(tmpdir)` via
  `_rangematch_qa_common.do` and restores them unconditionally. No suite may
  `ado uninstall` against the caller's real tree or append the source directory
  to the adopath: the lane must not edit the environment of the person running
  it, and must test the installed copy rather than the source directory.
  `test_rangematch_lane_isolation.do` is the gate on both.
- Every suite declares `version 16.1`, the package's advertised floor.
  `test_release_integrity.do` enforces it across the directory. This bounds the
  syntax interpreter only; it is not a substitute for a real 16.1 binary.
- `_expected_warnings.txt` lists warnings the suite deliberately provokes, so
  `qa log-review` reports them separately instead of as issues to triage. It
  cannot suppress errors.
- Paths are derived from `c(pwd)` and temporary files. No QA file should depend
  on a machine-local repository path.
- Runtime debris (`*.log`, `*.smcl`, workbooks, generated data) stays untracked.
- Documentation is gated on **three** axes. `test_documentation_examples.do`
  covers the source/behavior axis (the examples run as printed);
  `test_rangematch_sthlp_render.do` covers the render axis (the Viewer prints
  what the source intends); `test_rangematch_doc_contract.do` covers the
  advertised-surface axis (what the README claims exists, exists and runs).
  Source-text checks cannot see a help file that is textually perfect and
  renders wrong, so the second gate is not redundant with the first — the lane
  once ran green while shipping a `{synopt}` row wide enough to corrupt every
  Stored Results row below it. Nor is the third redundant: the lane also ran
  green from the package's first published version through 1.3.3 while the
  README advertised a `sort` option that the parser rejects with rc=198,
  because every suite tested options the *code* has rather than options the
  *docs* promise.
- Doc suites parse the README and the `syntax` line rather than transcribing
  them. A hand-copied example sequence inside a test keeps passing after the
  README regresses, which is how the non-runnable example sequence survived;
  `test_rangematch_doc_contract.do` extracts and executes the published blocks.

## File Index

| File | Covers |
|------|--------|
| `run_all.do` | Curated `quick` and `full` lane runner |
| `_rangematch_qa_common.do` | Shared sandboxed bootstrap (`_rm_qa_bootstrap` / `_rm_qa_teardown`) |
| `_expected_warnings.txt` | Warnings the suite provokes on purpose; consumed by `qa log-review` |
| `test_install.do` | Local install, public command resolution, basic installed-user run |
| `test_documentation_examples.do` | README/help examples as installed-user workflows |
| `test_rangematch_doc_contract.do` | Advertised-surface axis: every option the README's syntax blocks advertise is accepted by the parser; the published example sequence is extracted and run verbatim; missing-bound semantics (lower-only, upper-only, both); demo is repository-only while `net get` delivers the benchmark |
| `test_rangematch_demo_contract.do` | Demo hygiene: runs the real demo with a stale `PERSONAL` copy seeded ahead of it and a forced mid-demo error, then asserts the failure propagates, both sysdirs are restored, and the logs are closed |
| `test_rangematch_lane_isolation.do` | RM-I17 gate: the bootstrap sandboxes both ado trees, resolves the command from the sandbox, leaves a (simulated) user's installed copy untouched, and restores exactly on teardown |
| `test_rangematch_bench_smoke.do` | RM-I19 gate: the shipped `bench_rangematch.do` exits nonzero when rangematch errors, completes against the real command, and a hand-computed fixture yields exactly 17 pairs |
| `test_release_integrity.do` | Version/date/package surface and release metadata |
| `test_rangematch_sthlp_render.do` | Help-file **render** axis: `{synopt}` descriptions fit the Viewer column, and no source line breaks after sentence-ending punctuation |
| `test_rangematch_basic.do` | Basic point-in-interval joins, unmatched rows, naming, maxpairs |
| `test_rangematch_by.do` | `by()` partitioning and grouped joins |
| `test_rangematch_overlap.do` | Interval-overlap mode and overlap option interactions |
| `test_rangematch_missing*.do` | Missing-bound policy and missing-option edge cases |
| `test_rangematch_missing.do` | Baseline missing-bound behavior |
| `test_rangematch_missing_option.do` | `missing()` policy and routing cases |
| `test_rangematch_missing_option_extra.do` | Extended missing-policy interactions |
| `test_rangematch_adversarial.do` | Parser failures, cleanup, varabbrev, collisions, internal-name regressions |
| `test_rangematch_return_contract.do` | Stored-result scalars and locals across output modes |
| `test_rangematch_routing_contract.do` | `frame()`, `saving()`, `dryrun`, and `count` routing contracts |
| `test_rangematch_display_contract.do` | Display-only and count/dryrun display contracts |
| `test_rangematch_backend_equivalence.do` | Binary/sweep/overlap backend equivalence checks |
| `test_rangematch_backend_diff.do` | Differential sweep-versus-binary backend grid |
| `test_rangematch_edge_topup.do` | Zero-row, missing-bound, maxpairs-boundary, and restore edge cases |
| `test_rangematch_float_warn.do` | Float precision warnings and false-positive guards |
| `test_rangematch_labels.do` | Variable, value-label, and dataset-label preservation |
| `test_rangematch_missing_using.do` | Using-side missing-key/bound policies |
| `test_rangematch_overlap_inverted.do` | Inverted using-interval warning and return contract |
| `test_rangematch_provenance.do` | `usingid()` reports the original using row across every `missing()` policy, source, and ordering |
| `test_rangematch_interval_validity.do` | Closure-aware interval nonemptiness: inverted and open-degenerate intervals emit no matches |
| `test_rangematch_group_types.do` | Numeric `by()` group keys survive the direct/catalog paths across integer storage widths |
| `test_rangematch_frame_safety.do` | `frame()` may not name the using source frame; source preservation and cleanup |
| `test_rangematch_internal_names.do` | User variables matching private pair-index and tempvar-style names across frames/backends; error-path marker, frame, data, and session-state cleanup |
| `test_rangematch_option_grammar.do` | Empty required arguments, `keepusing()` varlist expansion, empty-side `missing(drop)`, `r(saving)` path normalization |
| `test_rangematch_missing_key_labels.do` | `missing()` policy over the master key where it is a matching input (`r(N_master_key_missing)`), no counts posted under `missing(error)`, and value-label collision resolution under collision-free names |
| `test_rangematch_ties_random.do` | Random tie-breaking, seed reproducibility, and RNG restoration |
| `test_rangematch_saving_matrix.do` | Saved-output routing and matrix-like result consistency |
| `test_rangematch_abbrev.do` | Minimum option abbreviations |
| `test_rangematch_v*.do` | Regression suites named for the release that fixed the bug. Only versions that actually shipped get a `v` name — six suites were once named `v140`–`v148` for releases that never existed (the package went 1.0.0 → 1.3.3), and are now named for the behavior they guard instead |
| `test_rangematch_v101.do` | v1.0.1 file/frame source regressions |
| `test_rangematch_v110.do` | v1.1.0 overlap and routing regressions |
| `test_rangematch_v120.do` | v1.2.0 missing and precision regressions |
| `test_rangematch_v130.do` | v1.3.0 random ties and inverted intervals |
| `test_rangematch_v132.do` | v1.3.2 deterministic overlap ordering and lower-bound maxpairs messaging |
| `test_rangematch_v133.do` | v1.3.3 maxpairs, session-state, naming, label, and return-gate regressions |
| `test_rangematch_regress_options_output.do` | Option and output-contract regressions: `keepusing()` pre-validation, date/datetime format preservation, stats-gated density results, `tolerance()` boundaries, output order |
| `test_rangematch_regress_performance.do` | Performance-path regressions |
| `test_rangematch_regress_backend_selection.do` | Backend selection: automatic sweep for monotone joins, binary fallback for nonmonotone intervals |
| `test_rangematch_regress_sweep_options.do` | Sweep path across option modes: unmatched/stats/assert/count/dryrun |
| `test_rangematch_regress_distance.do` | `distance()` conformability at single-row edges and backend routing |
| `test_rangematch_regress_mata_surface.do` | Mata backend version handshake; dead functions absent, live functions callable |
| `test_rangematch_v16compat.do` | Stata 16.1 compatibility surface |
| `validation_rangematch_oracle.do` | Known-answer oracle scenarios |
| `validation_rangematch_manual.do` | Manual count/statistic validation |
| `validation_rangematch_nearest.do` | Nearest/ties validation scenarios |
| `validation_rangematch_known_answers.do` | 21 hand-computed scenarios: 4 closure rules, inverted/degenerate intervals, wildcard vs literal open bounds, `missing()` policy, scalar key-offsets, `by()` isolation, match statistics, `maxpairs()` guard, point-mode distance, tolerance boundaries, full-outer accounting, overlap incl. open-ended bounds |
| `validation_rangematch_overlap_oracle.do` | Overlap backend vs a brute-force `cross` oracle (both closures, `tolerance()`, every interval relation), emission order, and the scaling contract |

## Coverage Map

| Command | Functional | Validation | Cross-val | Also Exercised In |
|---------|------------|------------|-----------|-------------------|
| `rangematch` | install, basic, by, overlap, missing, adversarial, return/routing/display/backend/saving, version regressions | known_answers, manual, nearest, oracle, overlap_oracle | N/A | documentation examples, doc contract (advertised surface), demo contract (sysdir/log hygiene), and release integrity |

`rangematch` is a deterministic data-join command, so no external R/Python
cross-validation suite is required. The validation layer uses hand-built oracle
datasets and invariant checks.

## Lane Membership

| Lane | Suites |
|------|--------|
| `quick` | All `test_*.do` suites listed in `run_all.do`, including the complete backend, edge, label, missing-using, tie, behavior-named regression, documentation, doc-contract, demo-contract, lane-isolation, benchmark-smoke, install, and release gates |
| `full` | All `quick` suites plus `validation_rangematch_oracle.do`, `validation_rangematch_manual.do`, `validation_rangematch_nearest.do`, `validation_rangematch_known_answers.do`, `validation_rangematch_overlap_oracle.do` |
