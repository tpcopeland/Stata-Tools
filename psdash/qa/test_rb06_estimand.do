* test_rb06_estimand.do — RB-06 estimand integrity for arbitrary treatment codings
*
* RB-06 defect (audit probe E1): for a binary treatment coded with values other
* than 0/1 (e.g. 3/5), psdash routed weight generation through the multi-group
* path, where estimand(atc) silently fell back to generalized ATE weights
* (w = 1/P(A=a|X)) while still returning r(estimand)=atc. Likewise estimand(att)
* produced control-targeted (atc-shaped) weights. Results therefore depended on
* the arbitrary numeric coding: recoding 0/1 -> 3/5 changed the weights. For a
* multi-valued treatment (K>2) estimand(atc) was accepted and produced generalized
* ATE weights under a false atc label. Existing QA (test_v141 ATC1) approved
* atc==ate for K=3, institutionalizing the defect.
*
* Fix: (1) map arbitrary binary levels to a documented reference(control)/other
* (treated) arm and compute correct, recoding-invariant ate/att/atc weights keyed
* to own-PS (the same formulas the 0/1 panel path uses); (2) reject estimand(atc)
* for K>2 with r(198) instead of substituting ATE weights under an atc label;
* (3) never return r(estimand)=atc when ATE weights were used.
*
* Fail-on-old (shipped psdash 1.4.1): for the 3/5 fixture, atc/att weights equal
* the ATE / control-targeted fallback (not the textbook binary values); recoding
* 0/1 -> 3/5 changes the weights (T5 fails); K=3 estimand(atc) returns rc=0 with
* r(estimand)=atc (T6/T7 expect rc=198). Every known-answer assertion below fails
* on old and passes on new.
*
* Three false greens named and defused:
*   FG1  the 3/5 weights match the 0/1 weights only because both are wrong the
*        same way -> T1/T2/T3 assert the ABSOLUTE textbook values from the fixture
*        PS (control=1, treated=(1-e)/e, etc.), not merely cross-coding equality.
*   FG2  the K>2 atc rejection is really psdash rejecting the dataset wholesale ->
*        T6/T9 keep the SAME data and require estimand(ate)/estimand(att) to
*        succeed with the correct r(estimand) (positive control).
*   FG3  r(estimand) is checked but the weights are not (a right label on wrong
*        numbers) -> every estimand test asserts BOTH the materialized weight
*        values AND r(estimand); T4 requires atc/att/ate to genuinely differ.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb06_estimand.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb06_estimand.log", replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture do "`qa_dir'/_psdash_bootstrap.do"

global N_PASS = 0
global N_FAIL = 0
global FAILED ""

capture program drop _t
program define _t
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global N_PASS = $N_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global N_FAIL = $N_FAIL + 1
        global FAILED "$FAILED `id'"
    }
end

* Binary fixture: treatment coded 3/5 (reference/control = 3, treated = 5),
* known PS e = P(A=5|X). NOTE: an `input ... end' block inside `program define'
* would terminate the program (Stata pitfall), so the fixture is built with
* set obs + replace.
capture program drop _bin35
program define _bin35
    clear
    set obs 6
    gen byte trt = cond(_n <= 3, 3, 5)
    gen double e = .
    replace e = 0.20 in 1
    replace e = 0.40 in 2
    replace e = 0.60 in 3
    replace e = 0.25 in 4
    replace e = 0.50 in 5
    replace e = 0.75 in 6
end

**# T1 — K=2 arbitrary levels: ATC known-answer (control=1, treated=(1-e)/e)
capture noisily {
    _bin35
    * Fixture is discriminating: both arms present, PS spans (0,1).
    quietly count if trt == 3
    assert r(N) == 3
    quietly count if trt == 5
    assert r(N) == 3
    psdash weights trt e, estimand(atc) truncate(999) generate(w) nograph
    assert "`r(estimand)'" == "atc"
    assert abs(w - 1) < 1e-12                if trt == 3
    assert reldif(w, (1 - e) / e) < 1e-12    if trt == 5
}
_t "k2_arbitrary_atc_known_answer" `=_rc'

**# T2 — K=2 arbitrary levels: ATT known-answer (treated=1, control=e/(1-e))
capture noisily {
    _bin35
    psdash weights trt e, estimand(att) truncate(999) generate(w) nograph
    assert "`r(estimand)'" == "att"
    assert abs(w - 1) < 1e-12                if trt == 5
    assert reldif(w, e / (1 - e)) < 1e-12    if trt == 3
}
_t "k2_arbitrary_att_known_answer" `=_rc'

**# T3 — K=2 arbitrary levels: ATE known-answer (control=1/(1-e), treated=1/e)
capture noisily {
    _bin35
    psdash weights trt e, estimand(ate) truncate(999) generate(w) nograph
    assert "`r(estimand)'" == "ate"
    assert reldif(w, 1 / (1 - e)) < 1e-12    if trt == 3
    assert reldif(w, 1 / e) < 1e-12          if trt == 5
}
_t "k2_arbitrary_ate_known_answer" `=_rc'

**# T4 — the three estimands genuinely differ on this fixture (not all-equal)
capture noisily {
    _bin35
    psdash weights trt e, estimand(atc) truncate(999) generate(w_atc) nograph
    _bin35
    psdash weights trt e, estimand(att) truncate(999) generate(w_att) nograph
    _bin35
    psdash weights trt e, estimand(ate) truncate(999) generate(w_ate) nograph
    * Same-row comparison requires a common dataset; rebuild once and recompute.
    _bin35
    quietly psdash weights trt e, estimand(atc) truncate(999) generate(a) nograph
    quietly psdash weights trt e, estimand(att) truncate(999) generate(b) nograph
    quietly psdash weights trt e, estimand(ate) truncate(999) generate(c) nograph
    * At e=0.5 (row 5, treated): ate=2 but att=atc=1 -> ate distinguishes.
    assert reldif(c, 2) < 1e-12 & abs(a - 1) < 1e-12 & abs(b - 1) < 1e-12 in 5
    * At e=0.2 (row 1, control): atc=1, att=0.25, ate=1.25 -> all three differ.
    assert abs(a - 1) < 1e-12 & reldif(b, 0.25) < 1e-12 & reldif(c, 1.25) < 1e-12 in 1
}
_t "k2_estimands_are_distinct" `=_rc'

**# T5 — recoding invariance oracle: 0/1 (panel path) == 3/5 (detect mg path)
* Two independent code paths must agree row-by-row for every estimand. Old code
* was NOT invariant (0/1 correct, 3/5 = fallback), so this fails on old.
capture noisily {
    clear
    set seed 20260719
    set obs 400
    gen double x = rnormal()
    gen double e = invlogit(0.6 * x)          // PS bounded away from 0/1 (no trunc bite)
    gen byte a01 = runiform() < e
    gen byte a35 = cond(a01 == 1, 5, 3)
    * Both arms must be populated for the comparison to be meaningful.
    quietly count if a01 == 1
    assert r(N) > 50 & r(N) < 350
    foreach est in atc att ate {
        quietly psdash weights a01 e, estimand(`est') truncate(1e6) generate(w01_`est') nograph
        quietly psdash weights a35 e, estimand(`est') truncate(1e6) generate(w35_`est') nograph
        assert reldif(w01_`est', w35_`est') < 1e-12
    }
}
_t "recoding_invariance_oracle" `=_rc'

**# T6 — K>2: estimand(atc) rejected (r198); ate/att positive control succeeds
capture noisily {
    clear
    set seed 7
    set obs 600
    gen g = mod(_n, 3)
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    quietly mlogit g x1 x2
    predict double p0 p1 p2, pr
    capture noisily psdash weights g, psvars(p0 p1 p2) estimand(atc) nograph
    assert _rc == 198
    * Positive control: same data, ate and att succeed with the right label.
    psdash weights g, psvars(p0 p1 p2) estimand(ate) nograph
    assert "`r(estimand)'" == "ate"
    psdash weights g, psvars(p0 p1 p2) estimand(att) nograph
    assert "`r(estimand)'" == "att"
}
_t "k3_atc_rejected_with_positive_control" `=_rc'

**# T7 — combined propagates the K>2 atc rejection (no fall-through to a verdict)
capture noisily {
    clear
    set seed 7
    set obs 600
    gen g = mod(_n, 3)
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    quietly mlogit g x1 x2
    predict double p0 p1 p2, pr
    capture noisily psdash combined g, covariates(x1 x2) psvars(p0 p1 p2) estimand(atc)
    assert _rc == 198
}
_t "combined_k3_atc_rejected" `=_rc'

**# T8 — teffects K=2 arbitrary levels: recoding invariance for every estimand
* teffects PS is invariant to relabeling, so 0/1 and 3/5 must give identical
* weights. Old routed 3/5 through the mg atc=ate fallback -> different.
capture noisily {
    clear
    set seed 314
    set obs 500
    gen double x = rnormal()
    gen byte a01 = runiform() < invlogit(0.5 * x)
    gen byte a35 = cond(a01 == 1, 5, 3)
    gen double y = a01 + x + rnormal()
    foreach est in atc att ate {
        quietly teffects ipw (y) (a01 x)
        quietly psdash weights, estimand(`est') nograph
        local m01 = r(mean_wt)
        local e01 = r(ess)
        assert "`r(estimand)'" == "`est'"
        quietly teffects ipw (y) (a35 x)
        quietly psdash weights, estimand(`est') nograph
        assert "`r(estimand)'" == "`est'"
        assert reldif(r(mean_wt), `m01') < 1e-8
        assert reldif(r(ess), `e01') < 1e-8
    }
}
_t "teffects_k2_arbitrary_recoding_invariance" `=_rc'

**# T9 — teffects K>2: estimand(atc) rejected (r198); ate positive control
capture noisily {
    clear
    set seed 909
    set obs 900
    gen double x = rnormal()
    * Ordered 3-level assignment with noise -> populated cells, no perfect fit.
    gen double lat = 0.8 * x + rnormal()
    gen byte g = 0
    replace g = 1 if lat > -0.5
    replace g = 2 if lat > 0.6
    gen double y = g + x + rnormal()
    quietly teffects ipw (y) (g x)
    local te_rc = _rc
    * Only exercise the guard if teffects itself converged on this data.
    if `te_rc' == 0 {
        capture noisily psdash weights, estimand(atc) nograph
        assert _rc == 198
        psdash weights, estimand(ate) nograph
        assert "`r(estimand)'" == "ate"
    }
    else {
        display as text "  (note: teffects K=3 did not converge on this seed; guard covered by T6/T7)"
    }
}
_t "teffects_k3_atc_rejected" `=_rc'

display as text _n "RESULT: test_rb06_estimand tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
