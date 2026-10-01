# datamap QA

The suite covers the five public commands: `datamap`, `datadict`, `datacheck`, `dataqa`, and `datamvp`. The curated runner defaults to the full lane; every suite can also be run directly from `qa/`.

## How to run

```bash
cd datamap/qa
stata-mp -b do run_all.do
stata-mp -b do run_all.do quick
stata-mp -b do run_all.do benchmark
stata-mp -b do test_regressions.do
```

The runner reinstalls `datamap` from the package parent, redirects PLUS and PERSONAL to temporary directories, runs suites sequentially, restores the original system directories, and exits nonzero when a suite fails. Direct suite runs use their own package setup but do not inherit the runner's installation sandbox.

## Conventions

- `test_*` files contain functional and regression coverage; `validation_*` files contain hand-computable known-answer and invariant checks; `crossval_*` is reserved for an independent external implementation; `benchmark_*` is reserved for timing and is never a correctness gate.
- Every runnable suite ends with exactly one `RESULT: <name> tests=N pass=N fail=N` sentinel and exits nonzero when a check fails. The full lane permits no skips.
- `run_all.do` redirects PLUS and PERSONAL below `c(tmpdir)` before installing from the package parent, then restores both directories.
- Paths derive from `c(pwd)`; no suite uses a machine-local path.
- Test datasets are generated at runtime from built-in or seeded synthetic data.
- Generated logs and disposable `.dta`, graph, and document outputs are gitignored; only documentation assets under `demo/` may be tracked.
- The package has no external-reference cross-validation because its deterministic maps, dictionaries, and QC summaries use hand-computable known answers and invariants as their correctness oracle.

## File index

### Functional and regression suites

| File | Covers |
|------|--------|
| `test_datamap.do` | Core text and JSON maps, input modes, outputs, and options. |
| `test_datamap_errors.do` | Exact error classes and state restoration across invalid inputs. |
| `test_datamap_documentation_examples.do` | Executability of the shipped README and help-file workflows. |
| `test_datamap_bugfixes.do` | Focused historical map regressions; the 1.8.1 review: complementary suppression in text, JSON, binary, missing-pattern, and `datadict` outputs; survival event rate and complete-case count under `mincell()`; `datesafe` survival time ranges; `exclude()` wildcards, ranges (refused before output when unresolvable or reversed in a file), and the no-match note; quoted `filelist()` names and the whole-list form; zero-observation files; shared value-label levels; excluded-variable `saving()` rows; string `unique` without the empty string. |
| `test_datamap_paths.do` | Parenthesized metadata paths across metadata writers. |
| `test_datamap_float_format.do` | Stable numeric formatting and gate messages. |
| `test_datamap_golden.do` | Normalized golden text and Markdown outputs. |
| `test_datamap_privacy.do` | Exclusions, small-cell protection, JSON privacy, and the `maskrare` contract: masked gate counts, `isid()` derived counts, profile and groupwise blocks, complementary suppression, the `patterns` table, the ledger, and the masking tag. |
| `test_datamap_v2.do` | Historical map and dictionary behavior. |
| `test_datamap_v11.do` | Classification, stored results, and validation regressions. |
| `test_datamap_v15.do` | Config, metadata, schema comparison, and shared contracts. |
| `test_datamap_v152.do` | High-cardinality, JSON-number, and identifier regressions; the string distinct count excludes the empty string. |
| `test_datamap_v154.do` | Privacy defaults, threshold validation, and graph-option regressions. |
| `test_datamap_v160.do` | Capped unique counts, frame-based writers, and the shared counter. |
| `test_datamap_v168.do` | Hostile text payloads, graph-label round-trips, helper state restoration, help widths, and QA-index synchronization. |
| `test_datamap_v169.do` | Left-justified date formats, exclude() privacy in the description and detectors, JSON control-character escaping, caller matrices, small-scale and float-level display, exact strL counts, saving() caps, hostile string levels, float-precision gates, datamvp tie order and float-level gby()/over() graphs, datacheck exclude() consistency, JSON refusal of text-only sections, missing(pattern), and string categorical frequencies. |
| `test_datamap_v171.do` | Date-safe metadata in memory/file daily/datetime routes, exact double counts, separate destination collision refusal, deferred grouping, complete-data sorting, caller scratch-name collisions, config/console parity, and tetrachoric fallback diagnostics. |
| `test_datamap_v180.do` | Date-string range bounds (ISO, slash, `%tm`, `%tc`) and refusal of a variable-name bound in `inrange()`, `stat()`, and `coverage()`; date-formatted extremes in `inrange()` messages; SCHEMA COMPARE N masking; `groupstat()` bands that test small groups under `maskrare`; `dataqa report` run attribution, `dataqa export` refusal reasons, and `dataqa compare` on withheld and zero baselines; `jumps()` independence from row order; zero counts under masking; `ledger()` and `dataqa set ledger()` quoting. |
| `test_datamap_v182.do` | 1.8.2 regressions: `datacheck, by()` GROUPWISE SUMMARY and MISSINGNESS against a per-group `count if` oracle (string group with a missing level, extended missings, `strL`, an excluded variable, every variable excluded), no frame left behind and data order unchanged; frequency-table and `datamvp` pattern-graph ties in level/pattern order across five row orders; `datadict` date, string, and labelled rows and `saving()` percentiles on a categorical row; `datamvp, correlate` equal to `tetrachoric` on the full indicators, and the Pearson fallback; caller `S_1`/`S_FN`/`S_FNDATE` returned byte for byte by all four commands on success and refusal paths; `saving()` notes and characteristics kept literally. |
| `test_datadict_v14.do` | Markdown dictionary routes and metadata exports; complementary suppression, `exclude()` wildcards and unresolvable ranges, and quoted `filelist()` paths. |
| `test_datacheck.do` | Profiles, gates, grouping, saved metadata, and privacy controls; the 1.8.1 review: `checks()` `isid`/`expectn` rows beside the command line, quoted `checks()` values, `makespec()` round trips (including `$` levels), numeric `regex()`, missing codes in `forbid()`/`notvalues()`, masked DATE-window and KEY STRUCTURE complements, excluded Miss% and `inrange()` extremes, quoted `keyset()` filenames, and no `.%` in any masked block. |
| `test_datacheck_gates.do` | `rule()`, `stat()`, and `binary()` gates, `checks()` rows for them, the PASS line, `r(singlelevel_vars)`, `maskrare` p1/p99 in place of extremes, silence under `quietly`, and `violations()`/`makespec()` to a new frame with `replace`; the gate, band, and review families (`events()`, `intervals()`, `keyset()`, `constant()`, the `sum`, `n`, `distinct`, `pmiss`, `ess`, and `ratio` statistics of `stat()` and its per-entry conditions, multi-variable and open `inrange()`, `bands()`/`bandwarn`, `review()`, `complete()`, `jumps()`, `heaping()`, `coverage()`, `groupstat()`, `sets()`), their `checks()` rows, the named verdict, `minversion()`, and gate parity between the `gatesonly` fast path, the varlist form, and profile mode; the 1.8.1 review: failing gates on untested data (`events()` all-missing covariate, `groupstat()` empty scope or no group tested, `intervals()` missing id), float precision at `intervals()` `tol()`, `jumps()` `ratio()`, and `groupstat()` percentile bounds, complement masking in `stat()` and `sets(values)`, whole-quoted and comma-bearing `keyset()` specs, `complete()`, `heaping()`, and `coverage()` shares as `[masked]`/`n/a`, the date-format refusal message, `groupstat()` column separation and full-precision failing values |
| `test_dataqa.do` | `dataqa set` and the precedence of explicit, session, and config defaults; `ledger()` rows; `dataqa report` against the golden register draft; `dataqa assert`, `export`, and `compare`; ledger error handling; `dataqa set replace`, the latest call per gate (keyed on the expectation) in `report`, `assert`, `export`, and `compare`, and the `export` refusal of the source ledger |
| `test_datamvp.do` | Missingness patterns, graphs, paths, and return contracts; pooling under `mincell()`, `top()` in the table, masked variable table and summary, comma widths, `bytable()`, and session defaults; graphs under masking (withheld `graph(bar)` cells with and without `gby()`/`over()`, `graph(patterns)` limited to table-shown patterns, `graph(patterns)` with `gby()` dropping small group patterns, `graph(matrix)` refused) the matrix display sample leaving the RNG state unchanged, and masked summary and monotone shares printed without `.%`. |
| `test_datamvp_labels.do` | Value-label and graph-label handling. |
| `test_datamvp_oracle.do` | Hand-computable missing-pattern counts, filters, ordering, and monotonicity. |
| `test_regressions.do` | Collision safety, strict graph parsing, return preservation, quoted paths and metadata, stable memory identity, and separate output. |
| `test_help_render.do` | Help-file rendering and a literal-SMCL positive control. |

### Validation suites

| File | Covers |
|------|--------|
| `validation_datamap.do` | Classification, output, and deterministic map invariants. |
| `validation_datamvp.do` | Known-answer missing-pattern and stored-result checks. |
| `validation_datamap_precision.do` | Unrounded JSON and metadata summary doubles against independent truth; see Numerical precision suites. |
| `validation_dataqa_writer_precision.do` | Ledger and export stat values at full precision; see Numerical precision suites. |

### Benchmark suites

| File | Covers |
|------|--------|
| `benchmark_gatesonly.do` | `gatesonly` cost on a 1M-row, 44-column interval file (fast path at most twice the varlist form; `by(year)` without the profile scan) and identical verdicts with and without a varlist. Timing only; run it in its own lane. |

### Runner

| File | Purpose |
|------|---------|
| `_qa_state.do` | Vendored session fingerprints used by the current-release regression suite. |
| `_qa_parity.do` | Vendored report/metadata privacy parity assertions used by the current-release regression suite. |
| `_qa_hostile.do` | Vendored hostile double fixtures used by the current-release regression suite. |
| `_qa_fx_a7.do` | Canonical labelled-data and owned-file fixtures. |
| `_qa_metamorphic.do` | Canonical option-domain and estimator-relation helpers. |
| `run_all.do` | Validates the lane, sandboxes installation state, installs the local package, runs suites, and emits a lane sentinel. |

### Canonical fixture suites

| File | Coverage | Lanes |
| --- | --- | --- |
| `validation_datamap_fixture_contract.do` | Canonical fixture truth and hostile contracts | core/full |
| `validation_datamap_fixture_primitives.do` | All five commands: exact case/32-byte schema, numeric/string code frequencies, dictionary rows, QC/missingness and actual masked ledger release | core/full |
| `test_datamap_fixture_domains.do` | All four numeric-option surfaces: declared lower domains, missing/fractional refusals and exact JSON/dictionary/QC/missingness payloads | core/full |
| `test_datamvp_fixture_groupgap.do` | Missing-value named-cause/state refusals and exact retained series plus rendered SVG spacing ratios | core/full |
| `test_datamap_fixture_files.do` | Four actual writer routes: hostile-path refusal, exact extensionless text/dictionary/pattern content and complete owned-tree mutation policy | core/full |
| `test_datacheck_fixture_ledger_quotes.do` | Simple/compound space/Unicode ledger paths, exact append rows/sequences/run labels and separate directory/leaf-quote named-cause refusals | core/full |
| `test_datamvp_fixture_reshape_state.do` | Absent/opaque16native aliases across four graphs, no-missing shortcut and early/late refusals; exact real filename/next native graph, next native reshape, pattern I/O and caller-owned preserve | core/full |
| `test_datamap_fixture_option_strings.do` | All four graph types plus invalid-category refusal on an exact known missingness adapter; actual new ledger row payload and missing-parent filename refusal | core/full |
| `test_datamvp_fixture_state.do` | Caller legacy-global preservation controls | core/full |
| `validation_datadict_fixture_contract.do` | Exact means/cardinality/missingness/labels/date formats in metadata plus real rendered dictionary summaries, all six LABELLED variants and full caller fingerprint | core/full |

| `validation_dataqa_fixture_contract.do` | All six LABELLED variants: exact ledger gates, masked release cells, register text and three independently corrupted baseline fields | core/full |
| `test_dataqa_fixture_state.do` | Fresh matastrict off/on preserved across comparison success and early/late refusals; existing output bytes retained | core/full |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|------------|------------|-------------------|
| `datamap` | `test_datamap*.do`, `test_regressions.do` | `validation_datamap.do` | Documentation and help-render suites |
| `datadict` | `test_datadict_v14.do`, `test_datamap*.do`, `test_regressions.do` | `validation_datamap.do` | `test_datamap_v168.do` hostile-text regressions |
| `datacheck` | `test_datacheck.do`, `test_datacheck_gates.do`, `test_datamap_privacy.do`, `test_datamap_float_format.do`, `test_datamap_v15.do`, `test_datamap_v182.do`, `test_regressions.do` | Invariants in `test_datacheck.do`; hand-computed family oracles in `test_datacheck_gates.do` | Documentation examples, `benchmark_gatesonly.do` |
| `dataqa` | `test_dataqa.do` | Golden register draft `golden/dataqa_report.md` | `test_datamap_privacy.do` (ledger masking) |
| `datamvp` | `test_datamvp.do`, `test_datamvp_labels.do`, `test_datamap_v182.do`, `test_regressions.do` | `validation_datamvp.do`, `test_datamvp_oracle.do` | `test_datamap_v168.do` hostile-label regressions |

## Lane membership

`quick` is contained in `core`, which is contained in `full`; `full` is the default release gate. The explicit suite list in `run_all.do` is authoritative.

| Lane | Suites |
|------|--------|
| `quick` | Primary command suites, exact error checks, high-value regressions, documentation examples, help rendering, and current-release regressions. |
| `core` | Every functional, regression, help-render, and validation suite in the file index. |
| `full` (default) | Currently the same suites as `core`; reserved for future external-oracle or slow coverage. |
| `benchmark` | `benchmark_gatesonly.do` only; timing, never part of the release gate. |

archetypes: A7(datamap datamvp datacheck datadict dataqa)

## Canonical fixture adoption

Exact JSON means, empty all-missing summaries, sparse code frequencies, missingness and QC gates; existing/undefined S_2 preserved on success, no-missing, early and late refusal. These are implemented suites; independent adoption signoff is pending. Remaining unexercised public routes and generic minima remain visible in the fixture census.

## Numerical precision suites

These suites compare actual returned, dataset, text or workbook values to independently derived numerical truth. Lane membership below follows the existing runner; full-lane results after these additions remain unverified.

| File | Scope | Cases | Lanes |
| --- | --- | --- | --- |
| `validation_datamap_precision.do` | Unrounded JSON and raw metadata/dictionary summary doubles; valid masked stat ledger/export rows. | 5 | core/full |
| `validation_dataqa_writer_precision.do` | Tiny relative stat comparison flags and raw groupstat ledger/export values, labels/masking and keys. | 2 | core/full |
