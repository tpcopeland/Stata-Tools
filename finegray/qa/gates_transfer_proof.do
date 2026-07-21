* gates_transfer_proof.do -- the reproducible half of run_status_gates.txt
*
*   stata-mp -b do gates_transfer_proof.do "<tree>" <TAG>
*
* Run it once per tree and diff the "R|" rows:
*
*   git archive <gated-commit> finegray | tar -x -C /tmp/gated
*   stata-mp -b do gates_transfer_proof.do /tmp/gated/finegray GATED
*   stata-mp -b do gates_transfer_proof.do ~/Stata-Tools/finegray CURRENT
*
* WHY THIS FILE EXISTS
* --------------------
* The 2026-07-18 receipt asserted the estimator core was unchanged since the
* gated tree, evidenced by "finegray z1 z2, compete(ev) cause(1) enter(time t0);
* seed 20260714, n=4000" reproducing four constants to 15 decimals.  That fit
* matches NO committed generator -- `_zzf_fix' (test_finegray_zzf.do) uses
* status/anyev, and `_mk_lt06' (test_finegray_fg06_vce.do) uses n=1500 -- so the
* receipt could not be re-checked when it mattered.  A receipt whose experiment
* cannot be re-run is not evidence.
*
* This file fixes that: the generators are copied from committed suites, and the
* verdict comes from diffing two trees rather than from transcribed constants,
* so it stays valid even if the numbers drift for a legitimate reason.
*
* RUN THE TWO TREES IN SEPARATE STATA SESSIONS.  Mata functions persist across
* `net install', so installing tree B over tree A leaves A's Mata resident and
* the fit dies at r(3001) "expected 13 arguments but received 14".  `discard'
* does not clear Mata functions either.  (That r(3001) is also the reason
* `_finegray_engine''s nuisance argument is REQUIRED rather than optional: a
* mixed-version state fails loudly instead of silently computing the wrong
* variance.)
*
* The four arms exercise the weight, the score, the robust variance, and the
* factorized cross-classified weight -- i.e. every numeric path the three
* delayed-entry gates measure.

args tree tag
clear all
set varabbrev off
version 16.0
capture log close _all
log using "gt4_`tag'.log", replace name(_g4)
* Uninstall first, matching every other suite in this package.  `net install,
* replace' overwrites the copy in the SAME adopath slot, but a second copy in a
* different slot (PLUS vs PERSONAL) still shadows the tree under test, and this
* script's whole purpose is to compare two specific trees -- a shadowed one
* would be diffed against itself without any error.
capture ado uninstall finegray
quietly net install finegray, from("`tree'") replace
discard
program define _mk_lt06
    syntax , n(integer)
    clear
    set seed 20260714
    quietly set obs `n'
    gen long id = _n
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen double t0 = runiform() * 2
    gen double t  = t0 + 0.2 + rexponential(1) * exp(-0.4 * z1)
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly replace ev = 0 if t > 8
    quietly replace t = 8 if t > 8
    quietly stset t, failure(ev) id(id) enter(time t0)
end
program define _zzf_fix
    syntax , n(integer) seed(integer)
    clear
    set seed `seed'
    quietly set obs `=`n' * 6'
    gen byte   z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen byte   g4 = ceil(runiform() * 4)
    gen double ez = exp(0.5 * z1 - 0.5 * z2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2
    gen double cens = min(rexponential(1 / 0.15), 6)
    gen double t0 = rexponential(1 / cond(z1 == 1, 1.6, 0.5))
    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0
    quietly drop if !(t0 < t)
    quietly keep in 1/`n'
    gen long id = _n
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
end
_mk_lt06, n(1500)
quietly finegray z1 z2, compete(ev) cause(1) nolog
display as text "R|`tag'|lt06_1500|" %21.16f _b[z1] "|" %21.16f _b[z2] "|" %21.16f _se[z1] "|" %21.16f _se[z2]
_mk_lt06, n(4000)
quietly finegray z1 z2, compete(ev) cause(1) nolog
display as text "R|`tag'|lt06_4000|" %21.16f _b[z1] "|" %21.16f _b[z2] "|" %21.16f _se[z1] "|" %21.16f _se[z2]
_zzf_fix, n(4000) seed(20260714)
quietly finegray z1 z2, compete(status) cause(1) nolog
display as text "R|`tag'|zzf_4000|" %21.16f _b[z1] "|" %21.16f _b[z2] "|" %21.16f _se[z1] "|" %21.16f _se[z2]
_zzf_fix, n(4000) seed(20260714)
quietly finegray z1 z2, compete(status) cause(1) strata(g4) truncstrata(z1) nolog
display as text "R|`tag'|zzf_fact|" %21.16f _b[z1] "|" %21.16f _b[z2] "|" %21.16f _se[z1] "|" %21.16f _se[z2]
capture log close _g4
