* test_rb03_factor_expansion.do — RB-03 factor-variable / interaction expansion
*
* Defect (audit probes F1/F2): _psdash_strip_fv stripped factor prefixes and split
* interaction terms at "#", so a covariate list of i.cat collapsed to the single
* integer-coded variable cat, and c.x##c.z collapsed to the two main effects with
* the interaction discarded. Balance was then assessed on arbitrary category codes
* (F1: same integer mean in both arms but sharply different category distributions
* read as SMD 0 / Adequate) and on main effects only (F2: a strongly imbalanced
* joint distribution read as balanced). The README claimed factor and interaction
* notation was "expanded transparently"; it was not.
*
* Fix: expand each term with Stata's own fvexpand/fvrevar into the fitted design
* columns -- one indicator per non-base level, one product per interaction cell --
* and assess balance on those. Applies to user-supplied covariates() and to terms
* auto-detected from a fitted logit/probit/mlogit/teffects model.
*
* Fail-on-old (shipped psdash 1.4.1, verified via git archive): covariates(i.cat)
* is rejected outright (r(101), factor operators not allowed in the numeric option)
* and the auto-detect path returns r(varlist) with the collapsed base variable
* names ("cat", "weight length" with no interaction). Every structural/oracle
* assertion below fails there.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb03_factor_expansion.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb03_factor_expansion.log", replace nomsg

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

* F1 generator: 3-level categorical with the SAME numeric mean (~2) in both arms
* but sharply different category distributions, and no perfect-prediction level.
*   treated: 45% cat=1, 10% cat=2, 45% cat=3    (mean ~2)
*   control: 10% cat=1, 80% cat=2, 10% cat=3    (mean ~2)
capture program drop _f1_data
program define _f1_data
    clear
    set obs 400
    set seed 7
    gen byte trt = _n > 200
    gen double u = runiform(0, 1)
    gen byte cat = .
    replace cat = cond(u < .45, 1, cond(u < .55, 2, 3)) if trt == 1
    replace cat = cond(u < .10, 1, cond(u < .90, 2, 3)) if trt == 0
    gen double ps = 0.5
end

* F2 generator: identical marginal distributions for x and z in both arms, but a
* different joint distribution (x,z positively associated in the treated arm,
* negatively in the control arm). Main-effect SMDs ~0; the interaction is imbalanced.
capture program drop _f2_data
program define _f2_data
    clear
    set obs 400
    set seed 11
    gen byte trt = _n > 200
    gen double x = rnormal()
    gen double z = rnormal()
    replace z = cond(trt == 1, 0.9 * x, -0.9 * x) + 0.30 * rnormal()
    * Standardize z within arm so its marginal mean/sd match across arms.
    quietly summarize z if trt == 1
    replace z = (z - r(mean)) / r(sd) if trt == 1
    quietly summarize z if trt == 0
    replace z = (z - r(mean)) / r(sd) if trt == 0
    gen double ps = 0.5
end

**# F1 — categorical imbalance is now visible (was SMD 0 / Adequate)
capture noisily {
    _f1_data
    psdash balance trt ps, covariates(i.cat) nowvar
    * Expanded to indicators for the two non-base levels (base = 1).
    assert strpos("`r(varlist)'", "2.cat") > 0
    assert strpos("`r(varlist)'", "3.cat") > 0
    assert strpos("`r(varlist)'", "1b.cat") == 0
    assert `: word count `r(varlist)'' == 2
    * Both indicators are strongly imbalanced; old code reported max SMD 0.
    assert r(n_imbalanced) == 2
    assert r(max_smd_raw) > 1
    assert r(n_warnings) >= 1
    assert strpos(`"`r(warnings)'"', "SMD threshold") > 0
}
_t "F1_categorical_imbalance_visible" `=_rc'

**# F2 — the fitted interaction column is assessed (was discarded)
capture noisily {
    _f2_data
    psdash balance trt ps, covariates(c.x##c.z) nowvar
    assert strpos("`r(varlist)'", "c.x#c.z") > 0
    assert `: word count `r(varlist)'' == 3
    * Main effects balanced, interaction strongly imbalanced -> exactly one
    * imbalanced column, driven by the joint term old code never built.
    assert r(n_imbalanced) == 1
    assert r(max_smd_raw) > 1
}
_t "F2_interaction_assessed" `=_rc'

**# Auto-detect from a fitted logit expands the design (one-arg PS form)
capture noisily {
    _f1_data
    quietly logit trt i.cat
    quietly predict double psl, pr
    psdash balance psl, nowvar
    assert strpos("`r(varlist)'", "2.cat") > 0
    assert strpos("`r(varlist)'", "3.cat") > 0
    assert r(max_smd_raw) > 1
}
_t "auto_detect_logit_expands_design" `=_rc'

**# Auto-detect from a fitted teffects model expands the design
capture noisily {
    _f1_data
    gen double y = rnormal()
    quietly teffects ipw (y) (trt i.cat), atet
    psdash balance
    assert strpos("`r(varlist)'", "2.cat") > 0
    * teffects IPW balances the design; the RAW categorical imbalance is exposed.
    assert r(max_smd_raw) > 1
}
_t "auto_detect_teffects_expands_design" `=_rc'

**# Recoding invariance — assessment depends on category structure, not codes
capture noisily {
    _f1_data
    psdash balance trt ps, covariates(i.cat) nowvar
    local base_smd = r(max_smd_raw)
    local base_nimb = r(n_imbalanced)
    * Recode the category VALUES to arbitrary integers; the design is identical.
    recode cat (1 = 10) (2 = 20) (3 = 30), gen(catr)
    psdash balance trt ps, covariates(i.catr) nowvar
    * Max SMD and imbalance count must be invariant to the relabeling. On the old
    * code, i.cat was rejected; on any integer-code scalarization these would move.
    assert reldif(r(max_smd_raw), `base_smd') < 1e-10
    assert r(n_imbalanced) == `base_nimb'
}
_t "recoding_invariance" `=_rc'

**# Base-level change — the imbalance verdict is preserved; base is dropped
capture noisily {
    _f1_data
    psdash balance trt ps, covariates(i.cat) nowvar
    local nimb_default = r(n_imbalanced)
    * ib2.cat moves the omitted reference to level 2.
    psdash balance trt ps, covariates(ib2.cat) nowvar
    assert strpos("`r(varlist)'", "1.cat") > 0
    assert strpos("`r(varlist)'", "2b.cat") == 0
    assert strpos("`r(varlist)'", "2.cat") == 0    // level 2 is now the base
    * The design still detects imbalance regardless of which level is the base.
    assert r(n_imbalanced) >= 1
    assert `nimb_default' >= 1
}
_t "base_level_change_invariance" `=_rc'

**# Multi-group treatment: factor covariate is expanded per non-base level
capture noisily {
    clear
    set obs 600
    set seed 5
    gen byte trt3 = mod(_n, 3)
    gen double u = runiform(0, 1)
    gen byte cat = .
    replace cat = cond(u < .45, 1, cond(u < .55, 2, 3)) if trt3 != 0
    replace cat = cond(u < .10, 1, cond(u < .90, 2, 3)) if trt3 == 0
    gen double p1 = 1/3
    gen double p2 = 1/3
    gen double p3 = 1/3
    psdash balance trt3, covariates(i.cat) nowvar psvars(p1 p2 p3)
    assert strpos("`r(varlist)'", "2.cat") > 0
    assert strpos("`r(varlist)'", "3.cat") > 0
    assert r(K) == 3
}
_t "multigroup_factor_expansion" `=_rc'

**# Independent oracle — SMD of a hand-built indicator matches the expanded column
* Uses a 2-level factor so i.cat2 expands to the single indicator 1.cat2, whose
* SMD equals the SMD of a manually generated 0/1 variable. The oracle is built
* with gen()/summarize (a different code path from fvexpand/fvrevar).
capture noisily {
    clear
    set obs 300
    set seed 21
    gen byte trt = _n > 150
    gen double u = runiform(0, 1)
    * Different category probabilities by arm -> real indicator imbalance.
    gen byte cat2 = cond(trt == 1, u < .70, u < .30)
    gen double ps = 0.5
    * Hand-computed SMD of the (cat2==1) indicator.
    gen byte ind = (cat2 == 1)
    quietly summarize ind if trt == 1
    local mt = r(mean)
    local vt = r(Var)
    quietly summarize ind if trt == 0
    local mc = r(mean)
    local vc = r(Var)
    local sd_pool = sqrt((`vt' + `vc') / 2)
    local smd_hand = abs((`mt' - `mc') / `sd_pool')
    drop ind
    psdash balance trt ps, covariates(i.cat2) nowvar
    assert `: word count `r(varlist)'' == 1
    assert strpos("`r(varlist)'", "1.cat2") > 0
    assert reldif(r(max_smd_raw), `smd_hand') < 1e-8
}
_t "independent_oracle_indicator_smd" `=_rc'

**# Backward compatibility — plain (non-factor) covariates are unchanged
capture noisily {
    clear
    set obs 300
    set seed 3
    gen byte trt = _n > 150
    gen double a = rnormal() + 0.3 * trt
    gen double b = rnormal()
    gen double ps = 0.5
    psdash balance trt ps, covariates(a b) nowvar
    * No expansion: r(varlist) is exactly the supplied varlist, in order.
    assert "`r(varlist)'" == "a b"
    assert `: word count `r(varlist)'' == 2
}
_t "plain_covariates_backward_compat" `=_rc'

**# Helper enumeration — _psdash_expand_fv labels/keepidx/base vars
capture noisily {
    _f2_data                              // has continuous x, z
    gen byte cat = 1 + mod(_n, 3)         // add a 3-level factor
    _psdash_expand_fv i.cat , touse()
    assert "`r(labels)'" == "2.cat 3.cat"
    assert "`r(keepidx)'" == "2 3"        // fvexpand: 1b.cat 2.cat 3.cat
    assert r(nall) == 3
    assert r(k) == 2
    assert "`r(basevars)'" == "cat"
    _psdash_expand_fv c.x##c.z , touse()  // continuous ## interaction
    assert "`r(labels)'" == "x z c.x#c.z"
    assert r(k) == 3
    assert "`r(basevars)'" == "x z"
}
_t "helper_enumeration_labels" `=_rc'

**# Helper mapping error — an unreconstructable spec is refused, not padded
capture noisily {
    clear
    set obs 50
    gen double x = rnormal()
    * A term referencing a variable that is not in the data cannot be mapped to a
    * design column; the helper must error explicitly rather than return nothing.
    capture _psdash_expand_fv i.no_such_var , touse()
    assert _rc == 459
}
_t "helper_refuses_unreconstructable_spec" `=_rc'

display as text _n "RESULT: test_rb03_factor_expansion tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
