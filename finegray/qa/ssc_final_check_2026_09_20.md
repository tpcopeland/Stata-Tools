# finegray 1.3.6: final pre-SSC check plan and report (2026-09-20)

## Purpose

A last, independent look at `finegray/` before submission to SSC, taken from the perspective of a biostatistician who will be judged by the users this package misleads, not by the tests it passes. The existing QA suite (139 files, 77 gated tests, R oracles) is strong evidence and is reused, not repeated. This check asks the questions a suite cannot ask about itself: is the estimator the one the documentation claims, does the variance default introduced in the last commit behave, does the package behave like a Stata command in every corner a user will poke, and is what ships what was tested.

## Orientation facts that shaped the plan

- Released version is 1.3.6 (2026/09/14) in every `*!` header, the help files, `finegray.pkg`, and README.
- The last full QA gate receipt (`qa/run_all_status.txt`) is dated 2026-09-14 09:41Z at head `ffbd2e7b` with uncommitted changes present. The final release commit `6665e688` (22:10 local) then changed `finegray.ado` by 61 lines. Its message says it made the fixed-weight variance the default, but the diff shows the variance default dates from August 2026 and the code change is a rewrite of `tsplit()` parsing so boundaries are used as typed rather than rounded through `numlist` (WS4 caught this; verified against `git show`). Either way, the shipped code has never been gated as committed. Re-running the full lane on HEAD is mandatory, not optional.
- The package ships 19 files (`finegray.pkg`), all present on disk; no shipped-but-unlisted or listed-but-missing file. `demo/`, `qa/`, and `README.md` are not shipped.
- `~/profile.do` prepends `~/Stata-Tools` to the adopath, so any "installed package" test on this machine is contaminated unless the profile is overridden with a cwd `profile.do`.
- R 4.6.1 with `cmprsk`, `survival`, `riskRegression`, `prodlim`, `mets` is available as an oracle.
- `/home/tpcopeland/Stata-Dev/_literature/finegray/` holds the primary sources (Fine and Gray 1999, Geskus 2011, Zhang, Zhang and Fine 2011, Lin, Wei and Ying 1993, Grambsch and Therneau 1994, Katsahian 2006, Zhou 2011/2012, Bellach 2019/2020, He and Yang 1998, and others) as PDFs, full-text Markdown, curated notes, `index.md`, a `references.bib`, and the `crrSC` and `crskdiag` R sources. WS1, WS4, and WS7 audit against these files, not against recalled formulas or recalled bibliographic details.

## Design principles

1. Delegate reading and running; reserve the orchestrator for judgement. Agents read the 19k lines of code and 1.3k lines of documentation and return findings in a fixed format. The orchestrator reads findings, verifies anything rated major or blocker with targeted reads, and decides.
2. Opus for derivation, simulation design, and adversarial statistical review. Sonnet for mechanical contract, consistency, packaging, and running the gate.
3. Read-only agents. No agent edits the repository. Fixes are applied by the orchestrator after verification, so every change has one accountable author and a single diff.
4. Do not duplicate the suite. Every agent first inventories what `qa/` already covers for its topic and targets the gaps.
5. Stata concurrency discipline: each job in its own working directory with a `profile.do` that pins `set processors`, per repository rules.

## Workstreams

| ID | Model | Scope | Output |
|---|---|---|---|
| WS1 | opus | Derivation audit of the Mata engine: IPCW weights (Fine & Gray 1999; Geskus 2011), ZZF Weight 1 for delayed entry, tie handling, score and information, fixed-weight sandwich vs nuisance ("eta plus psi") variance, cluster and pweight adjustments, stratified baseline, piecewise TVC, Breslow baseline and CIF, Schoenfeld residuals for the diagnostic. Code vs formula, line by line where it matters. | `findings_WS1.md` |
| WS2 | opus | Independent Monte Carlo verification targeted at gaps in the existing `validation_*` suites: bias and CI coverage of the new default fixed-weight variance where it should differ most from the nuisance variance (censoring dependent on covariates, heavy competing risk), delayed entry with ties, pweights with clusters, small strata baseline. R `cmprsk::crr` and `survival::finegray` plus `coxph` as oracles. | `findings_WS2.md`, sim do-files and results |
| WS3 | sonnet | Stata integration contract: e() and r() completeness against [P] ereturn conventions, replay, `predict`, `margins`, `test`/`lincom`/`nlcom`, `estimates store`, `mi estimate`, `bootstrap:` prefix, `by:`/`svy:` rejection, `if`/`in`, missing values, factor-variable base and omitted levels, collinearity, `noconstant`, weight syntax, error-path cleanliness (no leaked temp vars, data unchanged after error), `version 16` compliance and absence of Stata 17+ features, Mata namespace hygiene. Live probes. | `findings_WS3.md` |
| WS4 | sonnet | Documentation consistency: every `syntax` option documented and vice versa across the four help files and README, defaults stated correctly (especially the variance default after `6665e688`), stored results documented vs actual `ereturn list`/`return list`, methods help vs code, version history completeness, terminology consistency, reference list bibliographic accuracy (flag for orchestrator verification). | `findings_WS4.md` |
| WS5 | sonnet | Packaging and SSC compliance: current SSC submission guidelines fetched from the source, `.pkg`/`.toc` format, `*!` header convention, clean-room `net install` into an isolated PLUS with the dev adopath removed, demo and help examples run from the installed copy only, no repo paths or `tabtools` dependence in shipped files, encoding and line endings, SMCL link integrity, name-collision check (`ssc describe`, `search`), Mata compile load time, package size. | `findings_WS5.md` |
| WS6 | sonnet | Run the full QA gate on HEAD following the isolation recipe in `qa/README.md`; report the receipt, every RESULT line, runtime, and any divergence from the 2026-09-14 receipt. | `findings_WS6.md`, receipt copy |
| WS7 | opus | Hostile-reviewer pass as a biostatistician user: defaults that could mislead, `stset` interactions (`enter`, `exit`, `origin`, `scale`, multiple records), `compete()` value edge cases, error message quality, agreement with `stcrreg` on `hypoxia` within documented tolerance, the "fast" claim against the benchmark logs, and whether the interpretation guidance (SHR vs cause-specific HR, no causal claims) is adequate. | `findings_WS7.md` |

## Finding format (all agents)

```
## F-WSn-NN: <short title>
severity: blocker | major | minor | note
file: <path>:<line>
claim: <one sentence>
evidence: <exact excerpt, command, or output>
proposed fix: <one or two sentences>
confidence: high | medium | low
```

Agents return at most 300 words: counts by severity, the top three findings, and the path of the findings file. Everything else stays in the file.

## Orchestrator protocol

1. Launch WS6 first (longest wall clock), then WS1 to WS5 and WS7 in the same batch.
2. On each return, read the findings file. For every blocker or major, open the cited lines and confirm or reject independently. Cross-check claims between agents where they overlap (WS1 vs WS2 on variance; WS4 vs WS3 on stored results; WS5 vs WS4 on version strings).
3. Decision rule. Documentation, packaging, and metadata defects: fix directly. Code defects that change numerical output: do not silently patch a released version. Record the finding, the proposed patch, and the affected tests, and leave the decision to the author, unless the defect is unambiguous, has a failing test, and the fix is local, in which case patch, rerun the affected suites, and bump to 1.3.7.
4. Rerun any QA suite touched by a fix. If the shipped ado files change at all, rerun the full lane before declaring done.
5. Write the report below. Delete nothing in `qa/`.

## Exit criteria

- Full QA lane PASS on the exact tree that will be submitted, receipt committed.
- Zero open blockers. Every major either fixed or recorded with the author's decision pending and stated.
- Documentation and code agree on the variance default and on every option default.
- Clean-room install passes with the dev adopath removed.
- SSC metadata conforms to the current submission instructions.

## Report

### Verdict

Ready to submit to SSC as a revision, once the gate receipt below is copied into `qa/run_all_status.txt` and the 1.3.7 tree is committed. No workstream found a wrong number. Every finding that survived verification was a documentation gap, a message-wording issue, or a default worth a stated decision, and the documentation gaps are closed in this tree.

### Numerical verification (independent of the QA suite)

| Check | Result |
|---|---|
| Coefficients vs `stcrreg`, hypoxia and tied simulated data | agree to 4.6e-11 and 2.2e-13 (WS7, WS1) |
| `nuisance` e(V) vs `stcrreg` e(V) | 3.0e-15 (WS1), 3.3e-12 hypoxia (WS7), 2.3e-6 on 80 fresh simulated sets (WS2) |
| Default fixed-weight SE vs `stcrreg` SE | 3e-6 to 2.4e-4 relative on hypoxia (WS7); mean 1 percent, max 8.9 percent on simulated V entries (WS2) |
| ZZF Weight 1 vs Geskus expanded dataset refit with `stcox` | 7.7e-16 pooled, 1.2e-15 tied, 1.8e-16 stratified (WS1) |
| No competing events vs `stcox, breslow` | 9.3e-16 (WS1); vs `stcox, efron` 0.067 on integer times (WS7) |
| Delayed entry vs `survival::finegray(Surv(L,t,.)) + coxph` | 4.4e-11 mean abs diff (WS2) |
| CIF at t = 1, 5, 8 vs `stcrreg predict, basecif` and `stcurve, cif` | exact and 1e-8 (WS7) |
| Monte Carlo: 5 scenarios, 7,740 fits | zero failures, zero non-convergence; coverage 0.936 to 0.970, all inside the pre-declared 0.925 to 0.975 band (WS2) |
| Default vs `nuisance` coverage | identical to three decimals in all 16 cells; SE within 0.5 percent (WS2) |
| Speed claim | 126.7x vs claimed 136.0x at N = 2,000 (WS7) |

### QA gates

Full lane on HEAD `050b2d90` before any edit: `RESULT: run_all tests=77 pass=77 fail=0 skip=0`, fg02 PASS, wrapper PASS, transfer gate PASS (4 arms identical vs c7ca4445), 28 min. Two suites gained one passing test each relative to the 09-14 receipt (`test_finegray_tvc` 33 to 34, `crossval_finegray` 50 to 51); nothing was lost. Receipt copies in the session scratchpad under `ssc_check/gate/`.

Full lane on the 1.3.7 tree: `RESULT: run_all tests=77 pass=77 fail=0 skip=0`, fg02 PASS, wrapper PASS, transfer gate PASS (4 arms identical vs c7ca4445), 2026-09-20T20:26Z to 20:51Z, run tree matches the source repository (342 tracked files, manifest a95b0e37). Per-suite RESULT lines identical to the HEAD run. This receipt is now `qa/run_all_status.txt`; it reads `uncommitted-changes-present` until the 1.3.7 tree is committed.

Documentation suites rerun on the patched source: `test_finegray_sthlp_render` 8/8, `test_documentation_examples` 78/78. Clean-room `net install` into an isolated PLUS with the dev adopath removed: PASS, including all five help files, the Quick Start, `set varabbrev off`, and the GitHub raw URL, which serves the current tree (WS5).

### Changes made in this tree (version 1.3.7, 2026-09-20; no estimation code changed)

- `finegray_methods.sthlp`: "Interpreting the SHR" paragraph (not a relative risk, non-collapsible, retained-risk-set caveat, report the CIF and cause-specific hazards alongside; Latouche 2013, Austin/Lee/Fine 2016, Austin/Fine 2017 added to the references and citation scope); "Ties" paragraph stating Breslow with no `ties()` option; "The censoring-survivor floor" paragraph; the variance paragraph no longer claims the fixed-weight meat is consistent for the Fine and Gray meat and now states the real grounds for the default plus the simulation evidence; "Two conventions the papers leave open" in Left truncation (half-open at-risk indicator, all-or-nothing tie ordering); the `qa/README.md` pointer now goes to the GitHub URL; version stamp.
- `finegray.sthlp`: Remarks carry the interpretive caution and the Breslow statement; `bstrata()` carries the thin-strata caveat; version stamp updated.
- `finegray_predict.sthlp`: definition of the Schoenfeld residual after a `[pweight=]` fit and why `finegray_phtest` refuses it; version stamp. `finegray_cif.sthlp`, `finegray_phtest.sthlp`: version stamps.
- `README.md`: interpretation paragraph, simulation sentence in "Which Standard Error Am I Getting?", five new Assumptions and Limits bullets (Breslow ties, restricting follow-up with `exit()`/`origin()`/`scale()` and the failure-indicator message, thin `bstrata()` strata, `finegray_predict, cif` on changed data), three references, 1.3.7 history entry.
- All 14 `.ado`: header to 1.3.7 2026/09/20; four em dashes in comments replaced by `--` (all 14 ado files are now pure ASCII; the only non-ASCII byte left in the shipped set is the ü in Rüschendorf in the methods references, which Stata 14+ renders; the dev linter accepts `--` as the waiver-reason separator).
- `finegray.pkg`: title in SSC `module for ...` form; Distribution-Date 20260920. Root `README.md` badge.

### Decisions left to the author

1. Default variance. The default sandwich omits the psi (estimated-G) term that Fine and Gray eq. 7-8, `stcrreg` and `crr` include; `nuisance` is exact against `stcrreg`. WS2 measured the omission at 0 to 0.5 percent of the SE with identical coverage in designs built to widen it, so the current default is defensible and is now documented as an approximation. Switching the default would change every previously reported SE. (WS1-02)
2. Message hints, each a small code change with tests pinning current text: "gaps or overlaps" could name resampling under `bootstrap:` with `id()` (WS3-01, downgraded from blocker: the documented wrapper works); "compete() and stset failure indicator do not match" could name `exit()` and stset-on-cause (WS7-03); `finegray_predict, cif` could print a note when the data signature has changed (WS7-04); `cause()`/`compete()` refusals could list the values present (WS7-09); zero competing events could warn as `stcrreg` does (WS7-08); CIF horizons past follow-up (WS7-14).
3. Small contract gaps: `e(vcetype)` unset (WS3-02); `noheader` not implemented (WS3-03); plain `predict` returns xb without saying so (WS7-06); `e(N)` counts subjects where `stcrreg` counts records, undocumented (WS7-07).
4. Housekeeping in code: unreachable `do_scale` Schoenfeld rescaling blocks could be deleted (WS1-08); risk-set sums have no log-sum-exp centring, so extreme linear predictors fail as nonconvergence rather than being absorbed (WS1-07); the benchmark times the default variance against `stcrreg`'s nuisance-adjusted one, which the Performance section could say (WS7-11).
5. Conventions: `*!` header format is `Version 1.3.7  2026/09/20` where the common SSC form is `version 1.3.7 20sep2026` (WS5-04); `references.bib` in the literature folder parses Wogu's compound surname differently from the verified notes (WS4-04).
6. The version bump to 1.3.7 was my decision because shipped files changed; revert to 1.3.6 if you prefer to submit under the gated number, in which case the receipt must be regenerated.

### Rejected or downgraded agent findings

- WS3-01 "bootstrap: prefix unusable" (blocker): the README and help document the wrapper that re-runs `stset` on the resampled ids; verified running. Downgraded to a message hint.
- WS7-05 "error messages truncated at linesize 80" (minor): Stata wraps with a `>` continuation; verified. Rejected.
- WS5-01 "SSC already hosts finegray" (blocker): the README already marks 1.3.2 as the current SSC release. Process note: submit as a revision.
- My own orientation fact that commit `6665e688` changed the variance default was wrong (WS4 caught it; `git show` confirms a `tsplit()` parsing change).

### SSC submission steps (from Baum's instructions, fetched 2026-09-20)

1. Zip the 14 `.ado` and 5 `.sthlp` files only. Do not include `finegray.pkg` or `stata.toc`; SSC generates the package file. Keep both in GitHub for `net install`.
2. Email the archive maintainer, stating that this is a revision of the existing `finegray` package (currently listed with Distribution-Date 20260909) and giving the title and abstract from the pkg `d` lines.
3. Before zipping: commit the 1.3.7 tree with the new receipt in `qa/run_all_status.txt`, and push so the GitHub raw install serves 1.3.7.

### Token accounting

Agents: WS1 opus 299k, WS2 opus 156k, WS7 opus 211k, WS3 sonnet 179k, WS4 sonnet 177k, WS5 sonnet 129k, WS6 sonnet 141k over two invocations. Orchestrator reads were confined to findings files, cited lines, and the passages edited.
