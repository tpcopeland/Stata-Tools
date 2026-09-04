# Fail-closed guard map — `missing-passes-*` sites

Stata's missing values compare *greater* than every finite number, and
`reldif(., .)` is exactly `0`. So `assert x > 0` and `assert reldif(a, b) < 1e-12`
are both satisfied when their operands are missing: a suite that only asserts
those two shapes cannot distinguish "the estimator produced the right number"
from "the estimator produced nothing".

The 2026-09-02 audit (FG-08A) linted this suite with `--no-waivers` and found
**42** such sites — 12 `missing-passes-assert` and 30 `missing-passes-reldif`.
This file is the per-site map of how each one is now closed. It is generated
against, and must be re-checked with:

```
python3 -m _devkit.stata_dev_cli check lint --file <qa file> --no-waivers
```

`qa/test_finegray_failclosed.do` is the executable half: it builds fixtures in
which each guarded quantity IS missing and proves the guard construct exits
nonzero, and proves the *unguarded* construct would have passed on the same
fixture.

## Guard constructs

| Id | Construct | Closes |
|---|---|---|
| G1 | `assert !missing(A, B)` on the line before `assert reldif(A, B) < tol` | scalar/matrix-cell `reldif` |
| G2 | `assert !missing(q)` on the line before `assert q <op> k` | scalar inequality (`r(N)`, `r(min)`, `r(max)`, `r(sd)`, `e(N)`, `e(N_clust)`, `r(bootstrap_success)`) |
| G3 | `assert !missing(A, B) if e(sample)` before a row-wise `assert reldif(A, B) < tol` | variable-to-variable `reldif` |
| G4 | `assert missing(A) == missing(B) if e(sample)` + `count if !missing(A, B, ...)` + `assert r(N) > 0` before a row-wise `reldif` | row-wise `reldif` where missingness is legitimately partial (CI limits) |
| G5 | `forvalues c { assert !missing(M1[1,`c'], M2[1,`c'], M3[1,`c']) }` before a block of matrix-cell `reldif`s | matrix-cell `reldif` block |
| W1 | `count if !missing(v)` + `assert r(N) == e(N)` before `summarize v` + range assert | all-missing generated column (waived: linter sees only the range assert). Measured: a range assert with an upper bound (`r(max) <= 1`) already closes on its own, because a missing `r(max)` is not `<= 1`; one without an upper bound (`r(min) >= 0 & r(max) > 0`) does not, and needs W1. |
| W2 | `assert r(N) > 0 & r(sd) > 0` — one `summarize`, two returns | all-missing column: `summarize` sets `r(N)` to **0**, not missing, so the first conjunct is false (waived) |
| W3 | `assert t[1] != t0[2]` before `assert reldif(t[1], t0[2]) < tol` | both-missing pair: `. != .` is `0` (waived) |
| W4 | `assert reldif(a, b) > 1e-15` before `assert reldif(a, b) < 1e-12` | both-missing pair: `reldif(., .) == 0` fails the lower bound (waived) |
| W5 | `assert e(converged) == 1` before `assert e(N) > 0` | a fit that posted nothing: `. == 1` is `0` (waived) |
| W6 | `assert !missing(el(e(b), 1, 1)) & !missing(e(ll))` on the line *after* the inequality | a fit that posted missing content (waived: the guard follows rather than precedes) |

## The 42 audited sites

Line numbers are `pre-fix (commit 8d15d1ef)` → `current working tree`.

### `test_finegray_adversarial_v130.do` (2)

| Pre-fix | Now | Guarded quantity | Guard |
|---|---|---|---|
| 1431 | 1432 | `r(N)` from `count if _nrec > 1 & rec == 1 & _d == 1` | G2 `assert !missing(r(N))` :1431 |
| 1459 | 1461 | `r(N)` from `count` after `stsplit` | G2 `assert !missing(r(N))` :1460 |

### `test_finegray_margins.do` (15)

| Pre-fix | Now | Guarded quantity | Guard |
|---|---|---|---|
| 144 | 145 | `e(ll)`, `` `ll_fv' `` | G1 :144 |
| 197 | 199 | `` `M1'[1,1] ``, `` `m0' `` | G1 :198 |
| 198 | 201 | `` `M1'[1,2] ``, `` `m1' `` | G1 :200 |
| 204 | 208 | `` `D'[1,2] ``, `` `m1'-`m0' `` | G1 :207 |
| 207 | 212 | `` `D'[1,2] ``, `` `dhand' `` | G1 :211 |
| 237 | 243 | `r(b)[1,1]`, `` `est'[1,1] `` (`predict(xb)` arm) | G1 :242 |
| 238 | 245 | `sqrt(r(V)[1,1])`, `` `se_hand' `` | G1 :244 |
| 240 | 248 | `r(b)[1,1]`, `` `est'[1,1] `` (default-`predict` arm) | G1 :247 |
| 241 | 250 | `sqrt(r(V)[1,1])`, `` `se_hand' `` | G1 :249 |
| 339 | 349 | `` `M1'[1,2] ``, `e(b)[1,4]*r(mean)` | G1 :348 |
| 341 | 352 | `` `M1'[1,1]-`M1'[1,2] ``, `e(b)[1,1]` | G1 :351 |
| 342 | 354 | `` `M1'[1,3]-`M1'[1,2] ``, `e(b)[1,3]` | G1 :353 |
| 508 | 521 | `r(N)` from `count if !missing(bs_cif_lci) & e(sample)` | G2 :520 |
| 538 | 552 | `r(estimate)`, `e(b)[1,2]+10*e(b)[1,5]` | G1 :551 |
| 579 | 594 | `r(b)[1,1]`, `e(b)[1,3]` | G1 :593 |

### `test_finegray_tvc.do` (6)

| Pre-fix | Now | Guarded quantity | Guard |
|---|---|---|---|
| 1026 | 1027 | `r(max)` of `_nrec` | G2 :1026 |
| 1186 | 1188 | `r(N)` from `count if status == 1` | G2 :1187 |
| 1410 | 1413 | `` `LO'[1,2] ``, `` `AT'[1,2] `` | G5 :1408-1410, G1 :1412 |
| 1411 | 1415 | `` `AT'[1,2] ``, `` `HI'[1,2] `` | G5 :1408-1410, G1 :1414 |
| 1412 | 1417 | `` `LO'[1,3] ``, `` `AT'[1,3] `` | G5 :1408-1410, G1 :1416 |
| 1413 | 1419 | `` `AT'[1,3] ``, `` `HI'[1,3] `` | G5 :1408-1410, G1 :1418 |

### `test_finegray_tvc_bstrata.do` (3)

| Pre-fix | Now | Guarded quantity | Guard |
|---|---|---|---|
| 393 | 394 | `r(min)` of `bchq` | G2 :393 (plus `count if e(sample) & missing(bchq)` = 0 at :390-391) |
| 399 | 401 | `r(min)` of `cifq` | G2 :400 (plus `count if e(sample) & missing(cifq)` = 0 at :397-398) |
| 578 | 581 | `r(bootstrap_success)` | G2 :580 |

### `test_finegray_weights.do` (15)

| Pre-fix | Now | Guarded quantity | Guard |
|---|---|---|---|
| 281 | 282 | `e(ll)`, `` `llw' `` | G1 :281 |
| 322 | 324 | `e(ll)`, `2.75*(`ll0'-`nf'*ln(2.75))` | G1 :323 |
| 323 | 326 | `e(ll_0)`, `2.75*(`ll00'-`nf'*ln(2.75))` | G1 :325 |
| 324 | 328 | `e(sum_w)`, `2.75*_N` | G1 :327 |
| 399 | 404 | `e(ll)`, `` `llp' `` | G1 :403 |
| 470 | 476 | `e(N)` (unweighted split fit) | G2 :475 |
| 479 | 486 | `e(N)` (`[pw=pw]` split fit) | G2 :485 |
| 547 | 555 | `h0c`, `h0a` (row-wise) | G3 :554 |
| 549 | 558 | `cifcc`, `cifa` (row-wise) | G3 :557 |
| 550 | 569 | `cifcc_lci/uci`, `cifac_lci/uci` (row-wise, partial missingness legitimate) | G4 :564-568 |
| 587 | 607 | `r(N)` from `count if s2 != s0 & s2 < .` | G2 :606 |
| 593 | 614 | `xbw`, `xbh` (row-wise) | G3 :613 |
| 695 | 717 | `e(sum_w)`, `r(sum)` | G1 :716 |
| 982 | 1183 | `e(sum_w)`, `` `swz' `` | G1 :1182 |
| 1022 | 1224 | `e(sum_w)`, `` `swpi' `` | G1 :1223 |

The second `r(N) > 0` site the audit counted in this file is now :568, guarded by
G4 (:567 `assert !missing(r(N))` after the `count` at :566).

### `validation_cluster_recovery.do` (1)

| Pre-fix | Now | Guarded quantity | Guard |
|---|---|---|---|
| 180 | 181 | `e(N_clust)` | G2 :180 (`assert e(converged) == 1` at :177 is a second, independent gate) |

## Sites adjudicated after the fix pass (2026-09-04)

Re-linting the current tree with `--no-waivers` found 13 raw `missing-passes-*`
sites — none of them among the 42 above.

**Genuine, now guarded:**

| Site | Quantity | Repair |
|---|---|---|
| `test_finegray.do` T98 (was :2269-2271) | `_fg_pelnode_1Xifp` | When the design build produces nothing — the interaction column **and** its main-effect column both all-missing — `reldif(., .) == 0` satisfies `count if reldif(...) > 1e-12` → `r(N) == 0`, and a missing `r(sd)` satisfies `r(sd) > 0`: both legs pass at once. (Measured: with a *finite* main effect and a missing product, `reldif(., finite)` is itself missing and the product leg already refused, so the hole was specifically the all-missing-design case.) Added W1 (`count if !missing(...)` + `assert r(N) == e(N)`) before the `reldif`, and `assert r(N) == e(N)` + `assert !missing(r(sd))` after the `summarize`. Reproduced as FC-12. |
| `test_finegray.do` T85 (was :2008) | `el(r(table),1,1)`, `_b[ifp]` | Added G1. |

**Waived false positives** (each guard verified present in the file before the
waiver was written):

| Site | Construct |
|---|---|
| `test_documentation_examples.do` (basehaz + basecshazard) | W1 |
| `test_finegray.do` T47 | W1 |
| `test_finegray_adversarial_v130.do` C6 boundary (`< 1e-13`) | W3 |
| `test_finegray_adversarial_v130.do` C6 boundary (`< 1e-12`) | W4 |
| `test_finegray_adversarial_v130.do` C6 `e(N)` | W5 |
| `test_finegray_adversarial_v130.do` C6 `e(N_fail)` | W5 |
| `test_finegray_fvgrammar.do` FG-05 `_xb` | W2 |
| `test_finegray_fvgrammar.do` FG-05 regression loop | W6 |
| `test_finegray_nullcase.do` NC-1p | W1 |
| `test_finegray_postest.do` design-rebuild | W2 |
| `validation_finegray.do` V39 near-separation | W6 |

The package-level `check package finegray --view findings` deduplicates
findings, so it reported 9 of these 13; the four it folded away
(`test_finegray_fvgrammar.do` regression loop, `test_finegray_nullcase.do`,
`test_finegray_postest.do`, `validation_finegray.do`) are waived here as well so
that removing a dedup partner cannot make them reappear unadjudicated.

## Executable evidence

`qa/test_finegray_failclosed.do` (quick lane) pins all eleven constructs plus the
T98 repair. Last run 2026-09-04:
`RESULT: test_finegray_failclosed tests=12 pass=12 fail=0`.
