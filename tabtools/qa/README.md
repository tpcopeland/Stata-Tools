# tabtools QA

Flat, command-level QA layout (consolidated in v1.7.0 from 85 per-directory files). One complete `test_<command>.do` per public command, one `validation_<command>.do` where known-answer validation exists, and focused package-level suites for cross-command, adversarial, deep-audit, and release contracts.

## How to run

```bash
cd tabtools/qa
stata-mp -b do run_all.do            # full lane (default)
stata-mp -b do run_all.do quick      # test_*.do only, minus adversarial
stata-mp -b do run_all.do release    # full + benchmark
stata-mp -b do run_all.do benchmark  # benchmark only
```

Every file is independently runnable from `qa/`: `stata-mp -b do test_regtab.do`. Each file installs the package itself (`net install ... from(<pkg_dir>)`), so single-file runs touch your real PLUS. `pkg_dir` is derived as `regexr("\`qa_dir'", "/qa$", "")` — anchored, so only the trailing component is stripped. Use that form in any new file: the unanchored `subinstr(..., "/qa", "", 1)` it replaced removed the *first* `/qa` anywhere in the path, so a checkout under a directory such as `qa_trap/` or `~/qa_projects/` had that substring eaten out of the middle of a directory name while the trailing `/qa` stayed put, and every suite died at `net install` with `r(601)`; `run_all.do` instead sandboxes PLUS/PERSONAL in `c(tmpdir)` and restores them afterwards. The runner sets `processors 1`, uses per-process temporary paths, and emits its own `RESULT:` sentinel. The full and release lanes install `simsum`, `siman`, `sencode`, and `labelsof` into that disposable tree and fail if a required oracle is unavailable. `crossval_tabtools.do` runs the R companion fresh in a temporary directory and verifies all four regenerated fixtures before using them.

Two restart/fresh-session contracts normally launch child Stata processes: the disk-backed profile restart in `test_tabtools.do` and the 21 help recipes in `test_tabtools_tips.do`. When a run must keep exactly one Stata process alive at a time, execute `tools/run_profile_restart.py` and `tools/run_help_recipes.py` first; both drivers run their Stata jobs strictly serially. Pass their result-file paths to the parent lane through `TABTOOLS_QA_PROFILE_RESTART_RESULT` and `TABTOOLS_QA_TIPS_RECIPES_RESULT`. The tests read and validate those handoffs instead of starting child processes.

The runner directs generated QA outputs to a per-run temporary directory. To remove ignored debris left by independent file runs:

```bash
bash clean_artifacts.sh
```

Skip a file by listing it in `_skip.txt` (one `file.do | reason` per line). Any skip fails the `full` and `release` lanes; only `quick` treats the list as advisory.

## Lane membership

`run_all.do` uses explicit, reviewed file lists rather than glob discovery.

| Lane | Files |
|------|-------|
| `quick` | 29 explicitly listed `test_*.do` files (all except `test_package_adversarial.do`) |
| `full` | 30 tests + 11 validations + `crossval_tabtools.do` (42 files) |
| `release` | `full` plus `benchmark_tabtools_speed.do` (43 files) |
| `benchmark` | `benchmark_tabtools_speed.do` only |

## Conventions

- `test_*` — functional/regression tests. `validation_*` — known-answer and
  invariant checks (hand-computable oracles). `crossval_*` — comparison
  against external R/Python implementations. `benchmark_*` — speed guardrails
  (release lane only).
- Files count tests with `test_count`/`pass_count`/`fail_count` locals and end
  with a machine-parseable sentinel: `RESULT: <name> tests=N pass=N fail=N`.
  A failing file exits nonzero.
- `test_package_release.do` renders every shipped `.sthlp` through Stata's SMCL interpreter and includes a deliberately broken positive control, so a no-op render oracle cannot pass.
- Sections inside consolidated files are marked `**# Migrated: <origin>` and
  keep their original assertions; Stata bookmarks (`**#`) give code folding.
- Under `run_all.do`, generated artifacts go to a disposable directory under `c(tmpdir)`; independent file runs use gitignored `output/`. `data/` holds tracked crossval fixtures. `baseline/` holds tracked semantic summaries; the manifest distinguishes regenerated gates from stored-only historical references.
- Several tests load Stata example data via `webuse` (network access required). `test_package_integration.do` additionally requires the sibling `eplot` package at `../../eplot` and exits 601 without it. Excel-content assertions require the vendored `tools/check_xlsx.py` and `python3` with `openpyxl`; a missing checker is a failure even when a Stata-native diagnostic can still run. `crossval_tabtools.do` requires `Rscript` plus Python with `numpy` and `statsmodels`. A full/release lane has zero acceptable hidden oracle skips.

## File index

### Per-command tests

| File | Covers | Notes |
|------|--------|-------|
| `test_table1_tc.do` | table1_tc | Core + weighted stats, nopvalue, auto-detect types, SMD guards, aggregation fast-path contracts, semantic edge contracts (all-missing row, one observation/group, long labels), dots progress option, pdp()/highpdp() 1-10 bound (1.9.11), v1.0.13–v1.5 regressions |
| `test_smallcells.do` | table1_tc | Small-cell threshold parsing, primary/complementary/derived masking, complementary-marker irredundancy, continuous and missingness dependencies, weighted/frequency-weight semantics, percent/row-percent/total/clear compositions, caller-state stability, sink parity, failure atomicity, and raw-leak attacks |
| `test_desctab.do` | desctab | Consolidated descriptive engine: mixed variables, forwarding parity, private-collection preservation, output sinks, small-cell disclosure control, crude/weighted frame staging, and error cleanup |
| `test_crosstab.do` | crosstab | Association measures (OR/RR/RD/chi2/Fisher/trend), zebra, digits, boldp bounds, zero-denominator and auto-Fisher regressions, plus strict smallcells counts/margins/derived returns, complementary-marker irredundancy, and all-sink parity |
| `test_corrtab.do` | corrtab | Pearson/Spearman, stars, shapes, pairwise-N p-value regression |
| `test_regtab.do` | regtab | Model families (OLS/logit/Cox/GEE/mixed/multilevel), stats() incl. AIC/BIC recompute and n_sub aliases, compact mode, keep/drop, refcat, frames, console display, nopvalue |
| `test_effecttab.do` | effecttab | margins/teffects collects, from() matrix path, IPTW PS-coefficient filtering, digits, frames, console-only returns, refcat() option (1.9.11) |
| `test_survtab.do` | survtab | KM estimates, medians, RMST (+difference, no-late-entry), events option, riskset, highlight bounds, ev abbreviation, user-variable collisions, pdp()/highpdp() 1-10 bound (1.9.11) |
| `test_stratetab.do` | stratetab | strate-file workflows, multi-outcome/exposure scaffolds, rateratio, console/frame modes without xlsx(), sheet validation, row-order regression, error handling, varabbrev restore |
| `test_comptab.do` | comptab | Composite tables from regtab/effecttab frames, varabbrev restore on error |
| `test_ci_level_provenance.do` | regtab, effecttab, `_tabtools_collect_ci_level` | CI-level provenance: key present/absent/non-default, explicit `level()` fallback only when provenance is absent, refusal without either source, and conflict guard. Guards the Stata 19 `r(459)` breakage (`collect save` omits the undocumented `ci-level` key) |
| `test_hrcomptab.do` | hrcomptab | stratetab scaffold + regtab model frames, rownames() patterns, reflabel() override + r(rateframe), xlsx success message |
| `test_puttab.do` | puttab | Dataset/frame/matrix sources, styling options, markdown-only mode |
| `test_stacktab.do` | stacktab | Workbook block assembly (vstack/hstack, columnmerge), frame replacement guard |
| `test_tabtools.do` | tabtools (controller) | Command listing/categories, set/get/clear round-trips, detail re-load, disk-backed profiles (sandboxes PERSONAL and supports a serial external restart-result handoff), r(version) vs header |
| `test_tabtools_tips.do` | tabtools_tips | Index display, README Quick Start execution, numerical incidence-rate contract, and all 21 help recipes in separate fresh Stata processes (strictly serial external handoff supported) |
| `test_tabtools_v1163.do` | table1_tc | v1.16.3 regression: mixed categorical and continuous `missingsummary` rows follow the variables they describe and retain their own group-specific counts |

### Package-level tests (genuinely multi-command)

| File | Purpose |
|------|---------|
| `test_package_helpers.do` | Shared infrastructure contracts: `_tabtools_common` utilities (col letters, path/sheet/color validators including Excel boundary-apostrophe/reserved-name rules, detect_vartype + RNG preservation), Mata xlsx write/read backends, style-engine build/apply (with in-test legacy reference via `tools/style_engine_compare.py`), markdown writer, collect-JSON render, console display, column widths, Excel engine validation sweep |
| `test_package_integration.do` | Cross-command behavior: theme/defaults propagation (`tabtools set` → consumers), persistent digits/boldp, frame(name, replace) for all frame-capable commands, frame() pre-existing rejection, addrow()/pdp() across commands, CSV/markdown export parity, post-estimation e() preservation, eplot bridge + section folding (**requires sibling eplot**) |
| `test_package_adversarial.do` | Adversarial breakage sweep, 3-perspective stress suite, and export-failure r() survival contracts, including `puttab` dimensions |
| `test_package_hardening.do` | Hostile edge-case sweep across the shared export surface: extreme table shapes (single column/row, no title, title wider than table, sheet-reshape stale-cell clearing → B2 geometry), pathological cell content round-trip (pipes/commas/quotes/leading-`=`/negatives through md/csv/xlsx), locale (`set dp comma` must not corrupt numeric export), and re-run / session-state safety (varabbrev + data + frame restoration) |
| `test_deep_audit_core.do` | Critical destructive/silent-corruption regressions: Excel used ranges, frame alias/current-source transactions, semantic metadata, GLM scales, fweight/sample handling, and adversarial failures |
| `test_deep_audit_output.do` | Output/provenance regressions: CI levels, near-one p-values, zero effects, reserved labels, maximum precision, atomic sinks, trend errors, Markdown, medians, empty templates, and quotation preservation |
| `test_package_release.do` | Release gates: required artifacts, canonical metadata, manifest/install contracts, help versions, rendered-SMCL checks with a positive control, staged demo regeneration compared semantically with all 15 tracked workbooks, the required eplot integration demo (runs `demo_tabtools_eplot.do` and regenerates both forest PNGs), and regenerated golden-output digests vs `baseline/summaries/`; tracked demo assets are never rewritten by ordinary QA |
| `test_option_coverage.do` | Drives per-command OPTION coverage to 100% of the testable surface: every public option of every command is passed in a real invocation and accepted (see [Option coverage](#option-coverage)). Excludes `open` (GUI launch). |
| `test_synthesis_review.do` | Regression pins for the 1.12.0 synthesized four-reviewer audit: caller-visible return codes, CSV shape contracts, Markdown escaping, `puttab` order, `regtab` rules, `table1_tc` formatting, p-values, and the `stacktab` preview and CSV. Also pins the 1.12.1 raw-`puttab` blank-first-row rider. |
| `test_review_2026_08_13.do` | Regression pins for the 2026-08-13 review. R1–R3 are a live **reconstruction attack**, not a "was a percentage printed" check: the test plays a reader who has only the rendered page, recovers the percentage denominator by intersecting the intervals each published `count (percent)` pair implies, and subtracts. Before 1.15.0 that returned a primary-suppressed count exactly — `table1_tc, by(foreign) vars(rep78 cat) smallcells(5)` published `9 (43)` in a column headed `N=22`, which pins the denominator at 21 and yields `21 − 0 − 0 − 9 − 9 = 3`, the true value, under a table the engine had certified and with `N_secondary_suppressed == 0`. R3 repeats the attack under `total()`, `slashN`, `missingsummary`, and `percent_n`. R4/R5 pin the fix's scope: a protected variable publishes no percentage, an unprotected variable in the same table keeps all of them. R6 pins the refusal of a percent-only display, both explicit `percent` and the implicit percent-only default that `wt()` applies without `wtn`/`percent_n`. R7 pins the `corrtab` star legend against the threshold source. **All 7 fail on the 1.14.2 tree and pass on 1.15.0.** This file exists because the axis was uncovered: `validation_smallcells.do`'s V8 gate drives the engine directly with every cell and margin declared released, so it validates the engine against its own model and never sees a caller that under-declares one; `test_smallcells.do`'s raw-leak attack greps the CSV and Markdown for literal raw values, so it cannot see a value that is arithmetically recoverable rather than textually present |
| `test_tabtools_v1163.do` | Regression pin for 1.16.3: exact frame row order and exact group-specific missing counts prove that each `missingsummary` row follows its categorical or continuous parent instead of sorting ahead of a continuous row and appearing attached to the preceding variable. The attachment assertions fail on 1.16.2. |
| `test_xlsx_style_compaction.do` | Style-pool compaction contracts for 1.16.0. Stata's `xl()` never reuses a style record — a ranged `set_font()` appends two `<font>` entries per cell touched and every other cell-level operation appends one — so the pools grow with the number of styled cells and a large multi-sheet export dies at the 65,536-record font ceiling with the misleading `invalid font name` r(16147). The suite pins both halves of the fix: that `_tabtools_xlsx_compact_styles` collapses the pools, and that collapsing them moves nothing a reader sees. Format preservation is judged by `tools/check_style_compaction.py`, which resolves every cell of every sheet through **openpyxl** — font, fill, border, alignment, number format — plus row heights, column widths and merged ranges, rather than by re-reading the rewriter's own parse. Also pinned: a compacted workbook still accepts a further sheet and the sheet written first survives that round trip cell for cell; ten styled sheets hold the font pool at single digits (**5,861 records on 1.15.1**); an unrebuildable file is left byte for byte as `xl()` wrote it without failing the caller; a missing workbook is still r(601). **6 of the 10 fail on the 1.15.1 tree.** `stacktab` is pinned separately because it drives `xl()` directly instead of through the shared writer, so a search for the shared writer's call sites misses it: the same composite holds **163 font records on 1.15.1** and 8 on 1.16.0, cell-for-cell identical between the two. A 60-sheet `table1_tc` loop is the out-of-suite demonstration: 1.15.1 stops at sheet 56 with r(16147) and 65,430 fonts, 1.16.0 finishes all 60 holding 8 fonts and 60 cell formats. Three further contracts arrived with 1.16.1, **2 of which fail on the 1.16.0 tree**. An already-compact workbook must be left byte for byte alone: the fixture is an unstyled book written straight by `xl()`, chosen because every pool then holds one distinct record *and* because a rebuild re-zips the container to a different byte count — 1.16.0 rewrote it 2687 → 2659 bytes for no gain, once per sheet, on a file that grows with each one. The sheet-count guard in `_tt_xlsx_verify` must actually fire: `get_sheets()` returns an N-by-1 column vector, so 1.16.0 compared `cols()` — 1 against 1 — and the guard was unreachable, a dropped sheet being caught instead by the name comparison below it and reported under the wrong message. Sheet names carrying `&`, `<` or `'` must survive: they are XML-escaped in `workbook.xml` and decoded by `get_sheets()`, so comparing the two without resolving the entities would make such a workbook look like it had lost every sheet and would switch compaction off silently. That last one passes on 1.16.0, which read the names through a second `xl()` `load_book()` and never saw the escaped form — it guards the cheaper check that replaced it. Reaching `_tt_xlsx_verify` directly needs `run` on the `.ado`: the Mata an autoloaded ado compiles stays private to that file, so `mata describe` shows nothing and a top-level call gets r(3499) even though the program works, and the `run` must be preceded by `program drop` or it dies with r(110). One further contract arrived with **1.16.2**: `_tt_xlsx_files` must return paths separated by `/`. `dir()` prefixes every entry with the *platform* separator, so on Windows the list came back as `.\xl\styles.xml` while `_tt_xlsx_check_manifest` built its `prefix` and `skip` guards with `/`; neither matched, the verify subtree and the rebuilt archive were counted as original parts, and a correct rebuild was rejected with r(459) — which switched compaction off for the whole platform and put Windows back on the r(16147) font ceiling this suite exists to prevent. The test is a tautology on Unix and the discriminating case on Windows, which is exactly why it is pinned rather than assumed: nothing else in the suite would have caught a Unix-clean, Windows-broken helper |
| `test_issue_review_1_11_0.do` | Regression pins for the 1.11.0 issue review: per-model factor rendering, Excel merging, fixed-point precision, header and sink parity, Markdown headings, p-value grammar, legends, footnotes, negative-zero normalization, `stratetab` CI separators, console chatter, and trailing whitespace. |

### Validation (known answers, oracles, invariants)

| File | Covers |
|------|--------|
| `validation_table1_tc.do` | Mean/SD/median/percent/p-values vs `summarize`/`tabulate`, weighted expanded-data oracle, Yang–Dalton multinomial Mahalanobis SMD, coding invariance, two-level reduction, descriptive identities, and Excel cell accuracy |
| `validation_smallcells.do` | Independent bounded exhaustive 2x2/2x3 safety and irredundancy oracles for every small table, safe fail-closed cases, tight-bound false-green cases, hidden logical cells, truthful full-block fallback and threshold boundaries, engine input guards, and `.p`/`.s`/`.d` rendering |
| `validation_regtab.do` | Native-stats suite; coefficients/CIs/p-values vs `e()`, r(table) algebra, Excel accuracy, pdp formatting |
| `validation_effecttab.do` | ATE vs `e(b)`/`teffects`, SE/CI consistency, stored-results content |
| `validation_stratetab.do` | Structure/content of rate scaffolds, return values |
| `validation_survtab.do` | KM estimates vs `sts`, events/atrisk conservation, log-rank cross-checks, in-code RMST point/SE/CI bounds vs `stci, rmean` oracle, Excel survival probabilities, rendering checks (`tools/check_tabtools_render.py`) |
| `validation_crosstab.do` | Hand-computed 2x2 OR/RR/RD/chi2, counts vs `tabulate` |
| `validation_corrtab.do` | Correlations vs `pwcorr`/`spearman`, symmetry, in-code Pearson p-values (r->t->p) vs `regress` slope-p oracle + closed form, Spearman p passthrough, Excel accuracy |
| `validation_package.do` | Cross-command consistency (commands agree on shared statistics), universal sanity bounds, detect_vartype accuracy, set/get round-trip, comptab source-frame preservation, frame-Excel parity |

### Cross-validation and benchmarks

| File | Purpose |
|------|---------|
| `crossval_tabtools.do` | Runs `crossval_tabtools_companion.R` fresh, compares regenerated fixtures with tracked data, bridges manual formulas to public command frames/returns, and includes command-backed crosstab/stratetab checks plus **CV21–23** verifying `regtab` model-fit statistics against `estat ic`, `estat icc`, and an independent statsmodels fixed-scale GEE QICu oracle. |
| `benchmark_tabtools_speed.do` | Speed guardrails (release/benchmark lanes only) |

### Support

| Path | Contents |
|------|----------|
| `tools/` | Excel/Markdown/render checkers, semantic demo-tree and crossval-fixture comparators, `run_profile_restart.py` (two-phase serial profile restart), `run_help_recipes.py` (21 fresh Stata processes, run serially), `style_engine_compare.py`, `check_synthesis_style.py` (negative and paired border/alignment assertions that `check_xlsx.py` does not offer: a rule that must be *absent*, and a label cell that must *agree* with its value cells), and `option_coverage.py` |
| `data/` | Tracked crossval fixture CSVs (R reference results) |
| `baseline/` | Tracked golden-output digest TSVs + `baseline_manifest.tsv` (consumed by `test_package_release.do`) |
| `CROSSVAL_MODULE_MAP.md` | Package-to-oracle mapping for CV1–CV23 |
| `TOLERANCE_FRAMEWORK.md` | Numerical and display-tolerance policy |
| `fixtures_manifest.md` | Fixture ownership, regeneration, and consumer map |
| `_visual_stress_gen.do` | Manual disposable workbook generator; not a release-lane test |
| `output/` | Generated artifacts (gitignored) |
| `clean_artifacts.sh` | Deletes only ignored runtime artifacts from the package/QA roots and disposable `output/` contents |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|-----------|------------|-------------------|
| table1_tc | test_table1_tc, test_smallcells, test_tabtools_v1163 | validation_table1_tc, validation_smallcells | helpers (fast-collect), integration, adversarial, deep core/output, release, crossval |
| desctab | test_desctab | validation_table1_tc, validation_smallcells | helpers (collect render), integration |
| crosstab | test_crosstab | validation_crosstab, validation_smallcells | integration, adversarial, deep output, crossval |
| corrtab | test_corrtab | validation_corrtab | integration, adversarial |
| regtab | test_regtab | validation_regtab | helpers, integration, adversarial, deep core/output, release, crossval |
| effecttab | test_effecttab | validation_effecttab | integration, adversarial |
| survtab | test_survtab | validation_survtab | integration, adversarial, deep output |
| stratetab | test_stratetab | validation_stratetab | integration, adversarial, deep output, crossval |
| hrcomptab | test_hrcomptab | — | integration (eplot bridge), adversarial |
| comptab | test_comptab | validation_package (KE9) | integration (eplot bridge), adversarial |
| puttab | test_puttab | — | helpers (markdown), release |
| stacktab | test_stacktab | — | release |
| tabtools (controller) | test_tabtools | validation_package (V10) | integration (set propagation), release |
| tabtools_tips | test_tabtools_tips | — | release |

## Option coverage

Coverage here means **per-command option exercise**: an option counts only when
it is passed in a *real invocation of its own command* somewhere in the suite —
a bare token appearing in another command's test does not count. This is
stricter than a package-wide name scan (which trivially reports 100%).

- **Command coverage:** 16/16 (100%) — every public command has a test file.
- **Testable option coverage: 437/437 (100%)** — every testable public option of every
  command is passed in a real invocation and accepted.

`test_option_coverage.do` is the dedicated driver; `tools/option_coverage.py`
measures and verifies it (parses each `.ado` syntax block for the option
surface, scans `test_*.do`/`validation_*.do` for invocations, reports gaps).

| Command | Options | Testable | Exercised | Coverage |
|---------|--------:|---------:|----------:|---------:|
| `table1_tc` | 53 | 52 | 52 | 100.0% |
| `desctab` | 34 | 33 | 33 | 100.0% |
| `crosstab` | 32 | 31 | 31 | 100.0% |
| `corrtab` | 23 | 22 | 22 | 100.0% |
| `regtab` | 44 | 43 | 43 | 100.0% |
| `effecttab` | 34 | 33 | 33 | 100.0% |
| `survtab` | 32 | 31 | 31 | 100.0% |
| `stratetab` | 30 | 29 | 29 | 100.0% |
| `hrcomptab` | 25 | 24 | 24 | 100.0% |
| `comptab` | 28 | 27 | 27 | 100.0% |
| `puttab` | 18 | 17 | 17 | 100.0% |
| `stacktab` | 17 | 17 | 17 | 100.0% |
| `tabtools` | 10 | 10 | 10 | 100.0% |
| `tabtools_tips` | 1 | 0 | 0 | 100.0% |
| **Total** | **451** | **437** | **437** | **100%** |

**Excluded by design — `open` (14 commands).** It opens the workbook in the OS default application (`shell xdg-open`/`open`/`start`) and cannot be driven deterministically in batch, so it is not a testable coverage target. `tabtools_tips` exposes only `open`, so it has no testable surface.

Regenerate / verify:

```
python3 qa/tools/option_coverage.py          # table; exit status 1 on any gap
python3 qa/tools/option_coverage.py --json    # machine-readable
```
