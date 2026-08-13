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

`test_regressions_1_9_0.do` pins the four defects fixed in 1.9.0 and lives in the core lane. Each of its checks was confirmed to fail against 1.8.0. It deliberately probes axes the rest of the suite does not: weight *variance* against an independent Cole-Hernan numerator oracle (not weight presence or mean), *which* weight the balance table uses (not whether its arithmetic is self-consistent), *interior* values of the `ipcw()` indicator (not its extremes), and the coherence of the `tvdiagnose` percent column as a distribution (not the arithmetic of any single row).

`test_tvweight_cumprod.do` pins the behaviour contracts of the in-place cumulative-product path introduced in 1.9.1 and lives in the core lane. Its known answers are hand-computed with dyadic weights (2, 0.5, 4, 8), so the released algorithm is never its own oracle and exact `==` is the correct comparison. Its highest-value check is C5: a period excluded by `markout` must leave a missing product on that row without restarting the person's running product on the rows after it. Removing the excluded-row sort key from `_tvweight_cumprod.ado` makes C5 report `cp[4]=.` instead of `8`, and making the helper fail unconditionally makes `tvweight, cumulative` exit with the helper's own return code while the plain per-period IPTW path still succeeds — that pair is the dispatch proof, since a public parity test can otherwise pass while the new code never runs.

`test_tvtools_v1141.do` pins the 1.14.1 display and artifact repairs and lives in the core lane. Its 20 checks read the user-facing console logs, inspect the committed manifest and exported `.dta` metadata, compare cumulative-weight diagnostics with independently recomputed summaries, and verify that graph and stored-estimate names are meaningful and collision-safe. The suite was run against 1.14.0 before implementation and all 20 checks failed.

`test_tvweight_v1150.do` pins the 1.15.0 longitudinal numerator contract and lives in the core lane. Its 13 checks compare treatment and censoring weights against independently fitted reduced-model probability oracles, inspect the returned numerator specifications and time-specific defaults, and verify that numerator terms are nested in their denominator models and require the corresponding stabilization mode. Before implementation, the original 10-check discriminator failed 6 checks because both new options were rejected and neither history-conditioned numerator could be constructed; the explicit default-model check was then added to pin the corrected IPCW documentation and return contract. The last two checks were added in 1.16.0 to close a coverage gap review found in the original suite: every 1.15.0 check used a binary exposure in panel mode, so the `mlogit` numerator arm and the no-`id()`/no-`time()` arm that omits `i.time` from the numerator both shipped untested. Each is now compared against a reduced model fitted in the suite, and `W15_NONPANEL_NUMERATOR` additionally pins that `r(numerator_model)` is exactly `numcovariates()` with no time term appended.

`test_tvage_v1160.do` pins the 1.16.0 `tvage` person-time contract and lives in the core lane. Both defects it guards were silent at rc=0 under a fully green 78-suite lane, so its 12 checks deliberately sit on axes the rest of the `tvage` QA never probed. Group A covers the refusal of an `entry()` earlier than `dob()`: `A4_PREBIRTH_NO_SILENT_LOSS` is the general form of the contract — `tvage` may refuse such input or accept it and conserve person-days, but never accept it and lose them — and against 1.15.0 it reports `rc=0 in=3660 out=3405`, the defect reproducing exactly. Group B covers the age-window drop: `B3_DROP_REPORTED_BY_DEFAULT` invokes `tvage` **without** its `noisily` option and reads the notice back out of a named log, which is where the old build printed nothing, while `B4_NO_DROP_NO_NOTICE` stops the notice from becoming one that always fires. `B2_DROP_RECONCILES` asserts non-missingness before the arithmetic, because an absent `r()` scalar reads back as system missing and `. == . + .` is true in Stata — without that guard the check passed vacuously against the pre-fix build. Group C is the conservation oracle the suite lacked: person-days are computed here rather than read from any `tvtools` return, and `C3_CONTIGUOUS_TILING` exists because a gap paired with an equal overlap conserves the total. Against 1.15.0 the suite reports 3/12; the three passes are the Group C coverage-gap checks, which pin behaviour that was never broken. Its log searches rejoin batch-log continuation lines first, since a `"> "` wrap at `c(linesize)` otherwise breaks a `strpos` for a reason unrelated to the behaviour under test.

`test_tvmerge_frame_native.do` pins the frame-native source acquisition introduced in 1.9.1 and lives in the core lane. Most of it exists to watch state that no earlier suite could see. Sources are now held in tempnamed scratch frames, so F5-F7 count the frames left behind after a successful file merge, a successful `frames()` merge, and a failed merge — a leaked frame is silent until a later name collides or memory runs out. F8-F10 pin that a user-owned input frame is read and never mutated, in values and in sort order, because the command copies it rather than referencing it. F11 is the one intentional behaviour change in the release: `r(datasets)` reports the frame names for a `frames()` input, where it used to report the internal tempfile paths the frames had been serialised through, and it fails against the pre-1.9.1 code.

`test_tvevent_segments.do` pins the direct segment builder introduced in 1.9.1 and lives in the core lane. Its first four checks are an independent oracle rather than a restatement of the implementation: segments must cover exactly the person-time they came from, abut with no gap or overlap, be well formed, and number splits + 1. The pre-1.9.1 suites asserted event counts and row counts, which a builder that mis-set one boundary would still satisfy. S7 puts 200 split points inside one interval, which the released `reshape wide` path could only express as 200 variables. S13 uses an `id()` column literally named `__uid`: `frget varlist` silently skips a source whose name begins with `__` and still returns rc=0, which is exactly how the first draft of the builder failed. S10-S12 and S18-S19 count leaked scratch frames. S20 pins nested intervals, the only geometry in which the two ends of the coordinate index can drift apart unnoticed. The suite passes against the pre-1.9.1 code as well — Phase 2 is behaviour-preserving, so it is a regression net for the new implementation, not a discriminator between the two; the discriminating evidence is the fault injection recorded below.

## Benchmarks

`benchmark_*.do` files are manually invoked. They are not in `_tvtools_qa_manifest.do`, are not part of any lane, emit no `RESULT:` line, and contain no timing assertion. Do not add one to a correctness lane or change a pinned `RESULT:` count because a benchmark exists.

`benchmark_tvweight_cumprod.do` compares three implementations of the `tvweight` within-person cumulative product: the released 1.9.0 preserve/tempfile/merge block (replicated inside the file so the comparison survives the refactor), the shipped `_tvweight_cumprod.ado`, and a Mata kernel. Run it from a scratch copy of `qa/`, one fresh Stata process per invocation, serially:

```
stata-mp -b do benchmark_tvweight_cumprod.do <nrows> <nids> <rep> [all|legacy|candA|candB]
```

Repetition 0 is a discarded warm-up; odd and even repetitions alternate the execution order. Each run prints one `BENCH:` line with the elapsed times, the paired ratios, and the maximum absolute difference against the released algorithm. Use a single `impl` under `/usr/bin/time -v` when peak resident memory is wanted, so one process holds one implementation. Raw logs are not tracked.

`benchmark_tvmerge_workflow.do` measures the `tvmerge` merge workflow: two and three sources, sparse/moderate/dense overlap output, and a paired file-input versus `frames()`-input control built from byte-identical data.

```
stata-mp -b do benchmark_tvmerge_workflow.do <case> <scale> <rep>
```

`case` is `two`, `three`, `sparse`, `moderate`, `dense`, or `frames`. Because a merge is output-sensitive, every `BENCH:` line reports `M`, `U`, `K`, and the output row count next to the elapsed time; a timing without `K` is not interpretable. The `frames` case runs both input modes in one process and alternates their order with `rep`.

`benchmark_tvevent_workflow.do` measures the `tvevent` split/segment workflow: no events, boundary events, one internal event per person, one internal event per interval, and a paired using-file versus `frame()` control built from byte-identical intervals.

```
stata-mp -b do benchmark_tvevent_workflow.do <case> <scale> <rep>
```

`case` is `none`, `boundary`, `internal`, `dense`, or `frame`. Every `BENCH:` line reports `I` (interval rows in), `E` (event rows in), `S` (split points), and `Nout` beside the elapsed time, and asserts `Nout == I + S`. That assertion is not decoration: the first draft ran `type(single)`, under which `tvevent` truncates follow-up at the first event, so one internal event per person collapsed ten intervals to one output row and the benchmark measured truncation instead of segment construction. The guard reported `expected Nout=22000 but observed 2000`. Every case now runs `type(recurring)`, where all person-time is retained.

`benchmark_tvexpose_workflow.do` measures the default categorical `tvexpose` construction and the end-to-end chain: a non-empty source whose every row clips out, one episode per person, five clean non-overlapping episodes per person, a paired caller-replacement versus `frameout()` control on byte-identical inputs, and `tvexpose` → `tvexpose` → `tvmerge` → `tvevent` with every intermediate held in a frame.

```
stata-mp -b do benchmark_tvexpose_workflow.do <case> <scale> <rep>
```

`case` is `clipout`, `sparse`, `dense`, `frameout`, or `chain`. Every `BENCH:` line reports `M` (master persons in), `E` (source episode rows in), and `Nout` beside the elapsed time, because one source episode becomes between one and three output rows depending on where the study bounds fall. `Nout` is known by construction and asserted for every case except `chain`, whose cardinality the generator cannot predict because the merge intersects two different tilings. Like the `tvevent` benchmark it prints `BENCHADO:` and refuses to run when the resolved `tvexpose.ado` is not under the tree being tested.

Building the `chain` case surfaced a package inconsistency worth knowing before writing a workflow: `tvexpose` renames its structural bounds back to the caller's own `start()`/`stop()` option names on commit, but `tvmerge` does not — its output frame carries `id`, `start`, and `stop` whatever `id()` was passed.

Still owed: `tvweight` cumulative IPTW with and without IPCW end to end, and the remaining `tvweight` paired controls.

## Behavioural baselines

`baseline_*.do` files are manually invoked, are not in `_tvtools_qa_manifest.do`, and emit a `BASELINE:` line rather than a `RESULT:` line, because their verdict depends on a capture directory produced by a different build of the package.

`baseline_tvmerge_surface.do` freezes the complete observable `tvmerge` surface across 30 cases and replays it against a later build.

```
stata-mp -b do baseline_tvmerge_surface.do capture <dir>
stata-mp -b do baseline_tvmerge_surface.do compare <dir>
```

Every case records the full output dataset, observation and variable order, `sortedby`, storage types, display formats, variable labels, value-label names *and definitions*, the `tvtools_quantity`, `tvtools_history_point`, and `tvtools_quantity_unit` characteristics, the complete `r()` surface, the return code, and — on the negative paths — the caller's state after the failure. Comparison is exact; there is no tolerance anywhere.

Cases cover file versus `frames()` inputs, two and three sources, numeric and string IDs, zero emitted pairs, one-day and shared-boundary intervals, nested and many-to-many overlaps, rate/total/cumulative algebra, `keep()` payload with string variables and characteristics, `generate()`, `prefix()`, `startname()`/`stopname()`/`dateformat()`, `force`, `dropinvalid`, `frameout()` including the existing-target rejection, `saveas()`, the diagnostic options, full-row duplicate removal, duplicate rows that differ only in payload, `r(601)`/`r(610)`/`r(459)`/`r(498)`/`r(109)` negative paths, and a zero-variable caller.

Two absolute-path normalisations are applied to `r()` macros before comparison: the capture directory, and Stata tempfile stems. Both are per-run noise rather than contract. The normalisation deliberately renders a tempfile path as `<tempfile>` instead of deleting it, so a path that should have disappeared stays visible.

The harness was fault-injected rather than assumed to work. Reordering the output sort keys, changing the default `dateformat()`, disabling the full-row `duplicates drop`, and weakening the dedup key to `(id,start,stop)` are each detected. Removing the `_prop > 1` clamp is *not* detected, and no fixture can detect it: the intersection is always a subset of the source interval, so the ratio cannot exceed 1 under exact integer arithmetic. That clamp is unreachable defensive code and must still be preserved verbatim.

`baseline_tvevent_surface.do` does the same for `tvevent` across 44 cases, of which 31 succeed and 13 are negative paths.

```
stata-mp -b do baseline_tvevent_surface.do capture <dir>
stata-mp -b do baseline_tvevent_surface.do compare <dir>
```

It records everything the `tvmerge` baseline records, plus the *cells* of the `r(flow)` matrix rather than just its name, so a flow-accounting change cannot pass as a matching matrix list. Cases follow the required boundary list: events before entry and after exit, at start, strictly inside, at stop, one-day intervals, several internal dates in one interval supplied both unsorted and sorted (which must agree), same-day duplicates, primary and competing events on the same day, recurring events with `enum()`, gap-time, and total-time clocks, duplicate interval coordinates with distinct payloads, an ambiguous first event in two overlapping intervals, empty and all-missing event data, the three quantity algebras and the deprecated `continuous()` alias, string payloads with labels and characteristics, and `r(459)`/`r(498)`/`r(110)`/`r(109)`/`r(601)`/`r(198)`/`r(2000)` negative paths.

Building it exposed two fixture defects that reasoning about it did not. The first interval fixture carried the `tvtools_quantity` characteristics, and `tvevent` refuses a marked column that arrives without its option, so 30 of 40 cases froze that `r(498)` refusal as the baseline and left the segment builder untouched by any of them; the characteristics now live in a second fixture used only by the cases that pass the matching options. And `eventlabel()` takes `value "Label"` pairs, so the original label case recorded an `r(198)` instead of a label.

It was fault-injected rather than assumed to work. Six single-line defects in the code the refactor *replaced* are each detected: an off-by-one segment start (7 cases), the split rule `date < stop` weakened to `<=` (1), the final dedup key weakened to `(id,start,stop), force` (1), the `total()` apportionment ratio dropped (4), the output sort order changed (30), and segment numbering reversed (1). Six injections into the *new* builder are also each detected, by the baseline and by `test_tvevent_segments.do` independently: a wrong segment start (8 baseline cases), a wrong trailing-segment start (8), a segment count off by one (8), the within-coordinate dedup weakened (2), and either side of the coordinate index re-keyed (1 each).

Two of those injections were **not** detected by earlier fixture sets, and both are the same lesson: a geometry that no one thought to write down.

The split-rule injection needs overlapping intervals plus `type(recurring)`. The point engine already restricts split discovery to `start <= date < stop`, so a date can only reach an interval it does not split by being joined across a *different* interval of the same person, and under `type(single)` that same geometry is refused as ambiguous first. Case V42 supplies it.

The coordinate-index injection needs **nested** intervals. The builder numbers coordinates during split discovery and regenerates that numbering for payload rows; both sides must key on `(id, start, stop)` in the same order. For abutting or partially overlapping intervals, `(id, start, stop)` and `(id, stop, start)` order the coordinates identically, so re-keying one side changed nothing anywhere in a 43-case set. Only a nested pair separates them, and only if the two coordinates end with different segment counts. Case V43 supplies both.

`baseline_tvexpose_surface.do` does the same for `tvexpose` across 74 cases: 21 records for the calls the categorical fast path is allowed to claim (including both the caller and the target frame for each of the three `frameout()` cases), 40 for their nearest ineligible neighbours, and 13 for state and negative paths.

```
stata-mp -b do baseline_tvexpose_surface.do capture <dir>
stata-mp -b do baseline_tvexpose_surface.do compare <dir>
```

The eligible cases cover numeric and fixed-width string ids, a non-empty source whose rows all clip out, source ids absent from the master, persons with no episode, one-day windows and one-day episodes, episodes clipped at entry / at exit / at both / wholly outside, adjacent same-category and different-category episodes and positive uncovered gaps, negative and zero and positive whole-number codes under a negative reference, default and explicit generated names, a source with and without a value label on the exposure column, `referencelabel()`, `label()`, `keepdates`, `frameout()` creation and replacement and its `r(110)` refusal, a repeated call, and a fresh call after `discard`. The ineligible series carries one case for every excluded option family plus all five overlap geometries — same-class, different-class, nesting, exact duplicates, and a shared endpoint.

Two harness defects surfaced while building it, neither by reasoning about it. `r(combine_map)` legitimately contains double quotes (`101="1+2"`), and embedding one unescaped ended the record line early and killed the run at `r(132)` two cases downstream, after silently capturing 50 of 74. And the `validate` option writes `tv_validation.dta` into the working directory, so without `replace` the *second* run of the harness in the same directory failed at `r(602)` — capture succeeded and compare did not.

It was fault-injected rather than assumed to work. Seven single-line defects in the code the fast path replaces are each detected: the baseline row carrying `reference + 1` (57 cases), the final observable output sort reordered (56), the closing `compress` removed (56), the post-exposure row starting a day late (55), the default reference-label text changed (47), the gap row starting a day late (41), and the gap rule `> 0` weakened to `>= 0` on both halves (12). Six injections into the *new* builder are also each detected, by the baseline and by `test_tvexpose_fastpath.do` independently.

Two injections are recorded as undetected, correctly. The `sort id start stop` before `compress` is dominated by the identical sort at commit time, so that intermediate ordering is genuinely unobservable — the reported injection targets the observable one. And patching only the `__gap_start` half of the gap rule heals itself, because `__gap_stop` stays at its initialised `0` and the final truncation drops the bogus row.

`tvexpose`'s closing `duplicates drop id exp_start exp_stop exp_value, force` is unreachable defensive code, like `tvmerge`'s `_prop > 1` clamp. An instrumented build reporting the surplus row count immediately before that line reaches it 59 times across the 74 cases and finds a surplus of 0 every time; a dedicated probe with exact duplicate source episodes under `dose`, `split`, `layer`, and the default reports 0 as well, because the upstream containment-removal loop and the overlap resolvers always eliminate the duplicate first. Preserve it verbatim.

### The shipped-help-file inventory check

`test_package_release.do`'s render check used to assert `n_sthlp == 10` — a hardcoded inventory count. Adding `tvbuild.sthlp` made it fail, for the right reason but with the wrong message, and the fix of bumping the number to 11 would have gone stale again at the next help file. It now compares the `.sthlp` files in the package directory against the ones `tvtools.pkg` declares, in both directions. Fault-injected: an undeclared `.sthlp` in the directory fails, and a `.pkg` line whose file is missing fails. The old count check would have caught the first by accident and missed the second entirely.

The same suite also asserts that every shipped `.sthlp` declares each `{marker}` and each `{title:}` exactly once, and that `tvbuild` and all ten `_tvbuild_*` helpers resolve from the isolated install. Both are 1.10.1 additions and both close axes that were open when `tvbuild` shipped. `tvbuild.sthlp` had carried its entire body twice — Options through Examples, in two copies that had drifted apart — past a full green lane, because every doc check the file faced asks whether required content is *present*, and a duplicated body is present twice. The marker half is the sharper one: Stata resolves a jump to the first definition, so the second copy of every section is unreachable. The install half is coverage that was simply missing: the release suite listed ten of the eleven public commands and four of the twenty-two helpers, and named no `tvbuild` file at all.

The `.pkg` is read in Mata, not through a Stata macro. `tvtools.pkg` carries a menu block full of quotes and backticks; pulling it through `fileread()` into a local re-expands them and the parser reads its own macro expansion — that failed with `r(198)` before the Mata version.

### tvbuild, Phases 4A-4D

`tvbuild` is covered by four suites, split by what they can falsify.

`test_tvbuild_dryrun.do` (75 checks) covers everything `tvbuild` does before the first kernel: the public syntax, the specification normalizer, the complete read-only preflight, the plan display, and the `dryrun` return surface.

`test_tvbuild_construct.do` (48 checks) covers construction and alignment. Its point is that values alone cannot distinguish "tvbuild dispatched the shared engines correctly" from "tvbuild did something else that happened to agree": `B1`-`B7` therefore compare against the **frozen primitive sequence** — `tvexpose`, then `tvexpose` twice plus `tvmerge` — with `cf _all` on the committed columns. `B2` builds from a source *frame*, which `tvexpose` cannot take at all, so a wrapper-calling implementation could not pass it. `B4` compares **both** public input forms against a hand-written expected tiling, because comparing them only against each other passes while a shared normalizer bug makes both wrong. `B13` pins that abutting equal-category episodes collapse, which the plan says they should not and the released layer kernel says they do. `C6` pins that coverage is the interval union and not the sum of row lengths, on a fixture where the two disagree by 101 days. `M1`-`M11` assert the committed variable order, storage types, formats, variable labels, value-label assignments *and definitions*, characteristics, and the dataset label as separate categories, because `datasignature` sees none of them.

`test_tvbuild_commit.do` (35 checks) covers the event stage, provenance, and the transaction. `E12a`-`E12c` are the 1.10.1 regression for `eventlabel()`, which failed with `r(198)` for every value from the day `tvbuild` shipped: `tvevent` declares the option `string asis` and splices it straight into `label define`, so the compound quotes `_tvbuild_event` added — correct for a plain `string` destination — handed it one quoted string where it needed a `value "Label"` pair. All three fail on 1.10.0. `E2`-`E7` compare against the frozen `tvevent` sequence including competing risks and a recurring wide stub with `enum()` and gap time. `T5`-`T7` do not take the rollback's word for it: they fingerprint the pre-existing destination's data signature, variable list, storage types, formats, labels, and characteristics before and after a failure. `T6` forces the failure to land **between the two commits** — the only window in which the output frame has already been written, so the only one that exercises the restore rather than the drop — by shadowing `_tvbuild_manifest` with a stub that yields an empty frame. Its pre-existing destination is deliberately built with a *different* schema, because two runs that agree cannot tell a restored backup from a backup that was never restored.

`test_tvbuild_regressions_1_10_2.do` (18 checks) pins the four defects fixed at 1.10.2, all of which left computed values correct and broke what `tvbuild` reported about them. Measured against a pristine 1.10.1 tree, 6 of the 18 fail: `V1` (a non-numeric `tvbuild_spec_version` characteristic exited `r(111)` "two not found", because Stata's `&` does not short-circuit and the guard's numeric comparison resolved the characteristic as a *variable name*), `E1` (a master column merely sharing the `eventdate()` prefix was nominated as an event date by a bare `ds` glob), `Q1`/`Q2` (the provenance manifest stored `rate( tv_dose)` while `r(rate_vars)` read `tv_dose`, because the trim happened at the return surface after the manifest was built), and `N1`/`N2` (a two-token `start_var` reached an internal option and surfaced as `r(103)`, naming neither the row nor the column). The other 12 are guards, and two of them are the reason this suite is worth reading: `E3` and `E4` were **expected** to fail on 1.10.1 and did not, because the greedy glob passed the malformed stubs through to `tvevent`, whose own resolution rejected them. So 1.10.1's preflight was simultaneously over-rejecting and under-checking, and only the first was visible in an rc. `E3`/`E4` now pin that the preflight agrees with the engine rather than relying on that backstop.

A defect found by the help-example suite is pinned by `B14`/`B15`: `input` does not expand macros in its data lines, so a specification cell written as a tempfile macro is stored literally — and the local that reads it back **does** expand it, because Stata re-scans substituted text. The locator silently read as empty. `_tvbuild_normalize_spec.ado` now refuses any cell containing a backtick, dollar sign, or double quote, tested with `char()` so the test cannot be undone by its own quoting.

Three `tvbuild`-specific false greens shaped it. **"It never validated anything"** — a dry run that returns `rc=0` on a plan it never inspected is indistinguishable from one that did, so every `R*` case is a plan a real preflight must reject, and several of them (`R30`-`R35`) reach checks that need the source loaded and joined to the master. **"Both input forms share one normalizer bug"** — `P3` compares the inline and one-row `specframe()` forms against each other, which would pass while both were wrong; `P4` compares each against a hand-written expected plan. **"The plan was right while the session drifted"** — `S1`-`S8` assert the caller's data signature, variable list, sort order, the frame list, the value-label namespace, active `e()`, `c(varabbrev)`, and the current frame, across success *and* failure paths, because the failure paths are where a half-built scratch frame survives. `S12` closes the §6.6 half: every helper resolves and a plan still runs after `discard`, with no development adopath in play.

It was fault-injected rather than assumed to work. Seven single-line defects are each detected: swapping `input_vars` and `output_vars` in the shared normalizer (27 cases), disabling the episode-overlap check (3), counting source rows after clipping instead of before (2, including `P4`), writing one variable into the master during preflight (2), disabling the reference-coded-episode check (1), disabling the strict-coverage check (1), and allowing a destination frame to alias an input (3).

One injection is recorded as undetected, correctly. Emptying `tvbuild`'s scratch-frame cleanup loop changes nothing observable, because **Stata drops a `tempname` frame automatically when the program that created the name ends — including on the error path, where it also restores the current frame**. Probed directly: a program that creates a `tempname` frame, switches into it, and then errors leaves the frame list and the current frame exactly as they were. The explicit cleanup stays as defense in depth and because a non-`tempname` frame would not be covered, but no test can discriminate it, and claiming otherwise would be a false green of its own.

### tvmerge's output key

`test_tvmerge_idname.do` covers `idname()`. `tvmerge` renames the caller's `id()` to the literal name `id` for its internal work and, before this change, committed it under that name — so a cohort keyed on `pid` came back keyed on `id`, and chaining into `tvevent`, `tvdiagnose`, `tvweight`, or a second `tvmerge` needed a `rename` spliced between the calls. `tvexpose` has always restored its `id()`, `start()`, and `stop()` names on the way out.

M6 is the test that matters, and it asserts both directions: the `tvevent` chain succeeds with `idname(pid)` and fails without it. A passing chain on its own would not show the default was ever a problem. M4 pins that only the name changed, by renaming the key back and comparing `datasignature` against the default run — a rename that also re-sorted, or dropped the variable label, would pass a name check alone. M8-M12 are the refusals, all of them before a source is opened, with M12 asserting the caller's data survived the refusal.

`id` had to be exempted from the internal-name conflict list: it is both the internal working name and the released default output name. The rename that applies `idname()` is the last statement before the result is committed, so no internal consumer ever sees the new name.

### Program statement limits

`test_program_limits.do` exists because a Stata program may hold at most 3500 statements and tvexpose.ado held 3498. A program over the limit does not load: `run` exits `r(1000)`, the command does not exist afterwards, and the only symptom a user sees is `command tvexpose is unrecognized` from the next call. Wrapping one span of tvexpose.ado in a single further `if` was enough to trigger it. Moving the report-only diagnostics block into `_tvexpose_diagnostics.ado` restored 247 statements of margin, which the suite reports in its log.

L1-L3 measure the ceiling against synthetic programs rather than trusting the constant, so a future Stata that moves it says so instead of silently invalidating the margin. L5 onward splice `$LIMIT_MARGIN` real statements into every program each shipped `.ado` defines and require the file to still load — an exact test, because it asks Stata the question directly rather than reimplementing its statement counter. It fails while there is still room to act. The splicer runs in Mata on purpose: reading `.ado` source through Stata locals re-expands the backticks in the code being read, so the scanner would be parsing its own macro expansion.

`test_tvexpose_diagnostics.do` guards the behaviour of the span that moved. Its dispatch proof (D3) swaps a sentinel stub in for the installed helper: `check` and `validate` must reach it and a plain call must not. Without that, the six report-only checks would pass just as happily if every option branch were dead code. D11 pins a defect the move surfaced — with a continuous exposure type the `summarize` restore sat inside the categorical branch, so that arm returned an undocumented `period_length` column welded onto the committed schema. D11 fails on the pre-1.9.1 code and passes after.

Core has no undeclared dependency on sibling Stata packages. `test_tvm_overlap_drift_guard.do` and `test_package_optional_integration.do` live in the external lane because they intentionally exercise `rangematch` and `psdash`.

## Coverage map

| Surface | Functional, option, and state contracts | Known-answer validation | Independent oracle or cross-validation |
|---|---|---|---|
| `tvage` | `test_tvage.do`, `test_tvage_v1160.do`, `test_default_naming.do`, `test_extended_missing.do` | `validation_tvage.do`, DGP and boundary suites | `crossval_tvtools.do` |
| `tvband` | `test_tvband.do`, `test_default_naming.do`, `test_extended_missing.do` | `validation_tvband.do`, DGP and boundary suites | Hand-enumerated boundaries in the validation suites |
| `tvsplit` | `test_tvsplit.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvsplit.do`, `validation_audit_tvsplit.do`, DGP suites | `crossval_tvsplit_lexis.do` |
| `tvevent` | `test_tvevent.do`, `test_tvevent_segments.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvevent.do`, `validation_audit_tvevent.do`, DGP suites | `crossval_tvevent_recurring.do` |
| `tvexpose` | `test_tvexpose.do`, `test_tvexpose_fastpath.do`, `test_tvexpose_diagnostics.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvexpose.do`, `validation_tvexpose_statetime.do`, `validation_audit_tvexpose.do`, DGP suites | `crossval_tvexpose_expand.do` |
| `tvmerge` | `test_tvmerge.do`, `test_tvmerge_frame_native.do`, `test_tvmerge_idname.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvmerge.do`, `validation_audit_tvmerge.do`, DGP suites | `crossval_tvmerge_mata.do`, `test_tvm_overlap_drift_guard.do` |
| `tvpanel` | `test_tvpanel.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvpanel.do`, `validation_audit_tvpanel.do`, DGP suites | Hand-enumerated panel rows in the validation suites |
| `tvweight` | `test_tvweight.do`, `test_tvweight_cumprod.do`, `test_tvweight_v1150.do`, `test_tvtools_v1141.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvweight.do`, balance and recovery suites, `validation_audit_tvweight.do` | `crossval_tvweight_ipcw.do`, `crossval_tvtools.do` |
| `tvspec` | `test_tvspec.do` | Plan equivalence: the same specification built by hand and by `tvspec`, compared through `tvbuild` with `cf _all` on both the committed frame and the manifest | The hand-built specification frame is the oracle; the declared storage types are pinned against a fixed list outside that comparison |
| `tvdiagnose` | `test_tvdiagnose.do`, `test_options.do`, `test_extended_missing.do` | `validation_tvdiagnose.do`, `validation_audit_tvdiagnose.do` | `crossval_tvtools.do` |
| Dispatcher and workflows | `test_tvtools.do`, `test_tvtools_catalog.do`, `test_tvtools_v1141.do`, `test_integration.do`, flow, frame, naming, verbose, edge, regression, and state suites | `validation_known_answers.do`, DGP, boundary, tvbuild conservation, and supplemental suites | Cross-command checks in `crossval_tvtools.do` |
| `tvbuild` | `test_tvbuild_dryrun.do`, `test_tvbuild_construct.do`, `test_tvbuild_commit.do`, `test_tvbuild_manifest_default.do`, `test_tvbuild_regressions_1_10_2.do` | Frozen `tvexpose`/`tvmerge`/`tvevent` sequences compared with `cf _all`, plus hand-written expected plans and tilings | Refusal cases a real preflight must reject; forced commit failures with byte-and-metadata rollback checks |
| Distribution surface | Runner, fixtures, help examples, optional integration, release, and `test_program_limits.do` suites | Manifest-pinned result counts and fixture checksums | Installed-user, SMCL render, dialog, menu, and demo checks |

## Lane membership

| Manifest group | `quick` | `core` | `external` | `full` | `release` | `meta` |
|---|---:|---:|---:|---:|---:|---:|
| `quick_suites` | yes | yes | no | yes | yes | no |
| `core_only_suites` | no | yes | no | yes | yes | no |
| `external_suites` | no | no | yes | yes | yes | no |
| `test_package_release.do` | no | no | no | no | yes | no |
| `test_package_runner_contract.do` | through `quick_suites` | through `quick_suites` | no | through `quick_suites` | through `quick_suites` | yes |

The executable filename membership and pinned assertion counts live only in `_tvtools_qa_manifest.do`; this avoids a second runner list that can drift. The suite index below is the human-readable inventory.

## Suite index

Functional and release-contract suites: `test_default_naming.do`, `test_dialogs_gui.do`, `test_display_contract.do`, `test_edge_cases.do`, `test_extended_missing.do`, `test_frames_input.do`, `test_help_examples.do`, `test_integration.do`, `test_options.do`, `test_package_fixtures.do`, `test_package_optional_integration.do`, `test_package_release.do`, `test_package_runner_contract.do`, `test_package_state.do`, `test_regressions.do`, `test_regressions_1_9_0.do`, `test_tvage.do`, `test_tvage_v1160.do`, `test_tvband.do`, `test_tvdiagnose.do`, `test_tvevent.do`, `test_tvexpose.do`, `test_tvexpose_diagnostics.do`, `test_tvexpose_fastpath.do`, `test_program_limits.do`, `test_tvm_overlap_drift_guard.do`, `test_tvm_point_engine.do`, `test_tvmerge.do`, `test_tvmerge_idname.do`, `test_tvpanel.do`, `test_tvbuild_dryrun.do`, `test_tvbuild_regressions_1_10_2.do`, `test_tvsplit.do`, `test_tvtools.do`, `test_tvtools_v1141.do`, `test_tvweight.do`, `test_tvweight_cumprod.do`, `test_tvweight_v1150.do`, and `test_verbose.do`.

Known-answer and simulation suites: `validation_audit_tvdiagnose.do`, `validation_audit_tvevent.do`, `validation_audit_tvexpose.do`, `validation_audit_tvmerge.do`, `validation_audit_tvpanel.do`, `validation_audit_tvsplit.do`, `validation_audit_tvweight.do`, `validation_boundary.do`, `validation_contracts.do`, `validation_dgp_known_answers.do`, `validation_dgp_known_answers2.do`, `validation_flow.do`, `validation_known_answers.do`, `validation_phase0_semantics.do`, `validation_tvbuild_conservation.do`, `validation_supplemental.do`, `validation_tvage.do`, `validation_tvband.do`, `validation_tvdiagnose.do`, `validation_tvevent.do`, `validation_tvexpose.do`, `validation_tvexpose_statetime.do`, `validation_tvmerge.do`, `validation_tvpanel.do`, `validation_tvsplit.do`, `validation_tvweight.do`, `validation_tvweight_balance.do`, `validation_tvweight_msm_recovery.do`, and `validation_tvweight_recovery.do`.

Independent parity suites: `crossval_tvevent_recurring.do`, `crossval_tvexpose_expand.do`, `crossval_tvmerge_mata.do`, `crossval_tvsplit_lexis.do`, `crossval_tvtools.do`, and `crossval_tvweight_ipcw.do`.

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
