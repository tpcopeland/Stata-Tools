* test_v191_balance.do -- psdash 1.9.1 balance-engine and psdash balance fixes
* Author: Timothy P Copeland, Karolinska Institutet
*
* Changes under test (findings from the 1.9.0 external review):
*   F1  two-level non-dyadic covariate constant within arms ({0.1, 0.3}):
*       arm proportions came from decimal macro arithmetic, so p = 1 - 1e-16,
*       var = 4e-18 and SMD = 1.342e+08, VR = .a. Now an exact 0/1 indicator
*       gives p = 0 or 1, so pooled SD = 0: SMD = . (UNDEFINED), VR = .
*   F2  covariate constant on the sample (x = 0.3) under unequal weights:
*       ULP drift in weighted means/variances produced SMD_Adj = ., VR_Adj =
*       0 or .a and a false IMBALANCED verdict. Now SMD = 0, VR = ., KS = 0.
*   F17 two-level VR_Adj had no n > 1 guard: 0 (binary) / .a (multigroup)
*       where VR_Raw is . for an arm with one valid observation.
*   M9  r(max_vr_raw/adj) = 1 when no covariate has an assessable VR; now .
*   F20 _psdash_expand_fv kept an omitted continuous term (o.mpg).
*   F14 distribution(): a 27-char name() failed late with r(198); a single
*       variable ignored title() and was named <name>_dist1 (now <name>_dist).
*       A name() too long for the suffix is refused before any output.
*   F18 strategies(att/atc) with an arm of all-zero weights exited 0.
*   F15 K = 2 treatment not coded 0/1: no r(n_ps_boundary)/r(n_ps_near_boundary)
*       and no positivity finding; strategies()/distribution() refusal now
*       names the recode.
*   M4  multi-group row with a missing SMD printed IMBALANCED (now UNDEFINED);
*       vrbounds(0.45 2.25) was displayed rounded to %3.1f.
*
* Fail-on-old: every test below fails on psdash 1.9.0.
* Assertions are exact (==) where the fix makes the value exact.
*
* Usage: cd psdash/qa && stata-mp -b do test_v191_balance.do
version 16.0
capture log close _all
log using test_v191_balance.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local skip = 0

capture program drop _v191_rec
program define _v191_rec
    args name rc
    if `rc' {
        display as error "FAIL: `name' (rc=`rc')"
        global V191_FAILED "$V191_FAILED `name'"
    }
    else display as result "PASS: `name'"
end
global V191_FAILED ""

* Text of a file into r(txt) count of a pattern (log-capture helper)
capture mata: mata drop _v191_count()
mata:
void _v191_count(string scalar f, string scalar pat)
{
    string colvector L
    real scalar i, n
    L = cat(f)
    n = 0
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], pat)) n++
    }
    st_numscalar("v191_n", n)
}
void _v191_rowhas(string scalar f, string scalar row, string scalar pat)
{
    string colvector L
    real scalar i, n
    L = cat(f)
    n = 0
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], row) & strpos(L[i], pat)) n++
    }
    st_numscalar("v191_n", n)
}
end

**# T1 (F1) binary: {0.3, 0.1} constant within arms -> SMD ., VR .
capture noisily {
    clear
    set obs 40
    generate byte t = _n <= 20
    generate double x = cond(_n <= 20, 0.3, 0.1)
    set seed 1
    generate double w = 0.5 + runiform()
    psdash balance t, covariates(x) wvar(w) nograph
    matrix B = r(balance)
    assert B[1,1] == 0.3 & B[1,2] == 0.1
    assert B[1,3] == .
    assert B[1,4] == .
    assert B[1,8] == .
    assert B[1,9] == .
    assert r(n_imbalanced) == 1
    assert r(max_smd_raw) == 0
    psdash balance t, covariates(x) nowvar nograph
    matrix B = r(balance)
    assert B[1,3] == . & B[1,4] == .
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F1_binary_twolevel_separated `rc'

**# T2 (F1) multigroup K = 3: same covariate, every contrast SMD ., VR .
capture noisily {
    clear
    set obs 60
    generate byte g = ceil(_n/20)
    generate double x = cond(g == 1, 0.3, 0.1)
    set seed 2
    generate double w = 0.5 + runiform()
    psdash balance g, covariates(x) wvar(w) nograph
    matrix B = r(balance)
    * raw contrasts in cols 1-10, adjusted in 11-20; SMD at +3, VR at +4
    foreach c in 3 8 13 18 {
        assert B[1,`c'] == .
        assert B[1,`c'+1] == .
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F1_multigroup_twolevel_separated `rc'

**# T3 (F2) binary: constant x = 0.3 under unequal weights, seven seeds
capture noisily {
    forvalues s = 190/196 {
        clear
        set seed `s'
        set obs 200
        generate byte t = runiform() < .5
        generate double x = 0.3
        generate double x2 = rnormal()
        generate double w = exp(rnormal())
        quietly psdash balance t, covariates(x x2) wvar(w) nograph ks
        matrix B = r(balance)
        assert B[1,1] == 0.3 & B[1,2] == 0.3 & B[1,6] == 0.3 & B[1,7] == 0.3
        assert B[1,3] == 0 & B[1,8] == 0
        assert B[1,4] == . & B[1,9] == .
        assert B[1,5] == 0 & B[1,10] == 0
        * the verdict counts only x2
        local e_imb = (abs(B[2,8]) > 0.1)
        local e_vr = (B[2,9] < 0.5 | B[2,9] > 2)
        assert r(n_imbalanced) == `e_imb'
        assert r(n_vr_imbalanced) == `e_vr'
        assert r(max_vr_adj) == B[2,9]
        assert r(max_smd_adj) == abs(B[2,8])
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F2_binary_constant_weighted `rc'

**# T4 (F2) multigroup: constant x = 0.3 under unequal weights
capture noisily {
    forvalues s = 190/193 {
        clear
        set seed `s'
        set obs 300
        generate byte g = 1 + floor(3*runiform())
        generate double x = 0.3
        generate double x2 = rnormal()
        generate double w = exp(rnormal())
        quietly psdash balance g, covariates(x x2) wvar(w) nograph
        matrix B = r(balance)
        foreach b in 0 5 10 15 {
            assert B[1,`b'+1] == 0.3 & B[1,`b'+2] == 0.3
            assert B[1,`b'+3] == 0
            assert B[1,`b'+4] == .
            assert B[1,`b'+5] == 0
        }
        local e_imb = (abs(B[2,13]) > 0.1 | abs(B[2,18]) > 0.1)
        assert r(n_imbalanced) == `e_imb'
        local e_vr = (B[2,14] < 0.5 | B[2,14] > 2 | B[2,19] < 0.5 | B[2,19] > 2)
        assert r(n_vr_imbalanced) == `e_vr'
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F2_multigroup_constant_weighted `rc'

**# T5 (F17) two-level VR_Adj is . when an arm has one valid observation
capture noisily {
    clear
    set obs 40
    generate byte t = _n <= 20
    generate double x = cond(mod(_n, 2), 1, 0)
    replace x = . if t == 1 & _n > 1
    set seed 3
    generate double w = 0.5 + runiform()
    psdash balance t, covariates(x) wvar(w) nograph
    matrix B = r(balance)
    assert B[1,4] == .
    assert B[1,9] == .
    clear
    set obs 60
    generate byte g = ceil(_n/20)
    generate double x = cond(mod(_n, 2), 1, 0)
    replace x = . if g == 2 & _n > 21
    set seed 3
    generate double w = 0.5 + runiform()
    psdash balance g, covariates(x) wvar(w) nograph
    matrix B = r(balance)
    * contrast 2v1 (one valid obs in group 2): raw col 4, adjusted col 14
    assert B[1,4] == .
    assert B[1,14] == .
    * contrast 3v1 keeps a defined VR on both scales
    assert !missing(B[1,9]) & !missing(B[1,19])
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F17_twolevel_vradj_guard `rc'

**# T6 (M9) no assessable VR -> r(max_vr_*) missing; an exact VR of 1 still registers
capture noisily {
    sysuse auto, clear
    generate byte hi = price > 6000
    generate double w = 1 + mpg/10
    psdash balance foreign, covariates(hi) nowvar nograph
    assert r(max_vr_raw) == .
    psdash balance foreign, covariates(hi) wvar(w) nograph
    assert r(max_vr_raw) == . & r(max_vr_adj) == .
    generate byte g = 1 + (rep78 > 3) + foreign if rep78 < .
    psdash balance g, covariates(hi) wvar(w) nograph
    assert r(max_vr_raw) == . & r(max_vr_adj) == .
    * guard: identical arms give VR exactly 1, which must be the maximum
    clear
    set obs 8
    generate byte t = _n <= 4
    generate double x = mod(_n - 1, 4)
    generate byte b = mod(_n, 2)
    psdash balance t, covariates(x b) nowvar nograph
    assert r(max_vr_raw) == 1
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec M9_max_vr_no_assessable `rc'

**# T7 (F20) omitted continuous term o.mpg is not an assessable covariate
capture noisily {
    sysuse auto, clear
    _psdash_expand_fv o.mpg weight
    assert `"`r(labels)'"' == "weight"
    assert "`r(keepidx)'" == "2"
    assert r(k) == 1
    psdash balance foreign, covariates(o.mpg weight) nowvar nograph
    assert rowsof(r(balance)) == 1
    assert "`r(varlist)'" == "weight"
    * guard: factor base/omitted levels still dropped, others kept
    _psdash_expand_fv io(3).rep78
    assert `"`r(labels)'"' == "2.rep78 4.rep78 5.rep78"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F20_omitted_continuous `rc'

**# T8 (F14) distribution() name() length boundaries: 27 chars (one variable) and
**# 26 chars (two) work; 28 (one) and 27 (two) are refused before any output
capture noisily {
    sysuse auto, clear
    generate double w = 1 + mpg/20
    generate double ps = invlogit(-1 + .02*mpg)
    graph drop _all
    * boundaries: 32 - strlen("_dist") = 27 with one variable,
    * 32 - strlen("_dist2") = 26 with two
    local nm26 "abcdefghijklmnopqrstuvwxyz"
    local nm27 "abcdefghijklmnopqrstuvwxyz1"
    local nm28 "abcdefghijklmnopqrstuvwxyz12"
    assert strlen("`nm26'") == 26 & strlen("`nm27'") == 27 & strlen("`nm28'") == 28
    * 27 chars, one variable: succeeds, figure is <name>_dist only
    psdash balance foreign ps, covariates(mpg weight) wvar(w) distribution(mpg) name(`nm27')
    quietly graph dir
    assert strtrim(`"`r(list)'"') == "`nm27'_dist"
    * 26 chars, two variables: succeeds, figure plus both panels
    graph drop _all
    psdash balance foreign ps, covariates(mpg weight) wvar(w) ///
        distribution(mpg weight) name(`nm26')
    quietly graph dir
    local gl `"`r(list)'"'
    local gl : list sort gl
    assert "`gl'" == "`nm26'_dist `nm26'_dist1 `nm26'_dist2"
    * 28 chars, one variable / 27 chars, two variables: refused up front,
    * no results posted, no graphs drawn
    foreach spec in "`nm28'|mpg" "`nm27'|mpg weight" {
        gettoken snm sdv : spec, parse("|")
        local sdv = substr("`sdv'", 2, .)
        graph drop _all
        return clear
        capture noisily psdash balance foreign ps, covariates(mpg weight) wvar(w) ///
            distribution(`sdv') name(`snm')
        assert _rc == 198
        capture confirm matrix r(balance)
        assert _rc != 0
        quietly graph dir
        assert strtrim(`"`r(list)'"') == ""
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F14_dist_name_length `rc'

**# T9 (F14) single-variable distribution(): <name>_dist, honours title()
capture noisily {
    sysuse auto, clear
    generate double w = 1 + mpg/20
    generate double ps = invlogit(-1 + .02*mpg)
    graph drop _all
    psdash balance foreign ps, covariates(mpg weight) wvar(w) distribution(mpg) ///
        title("Custom Title") name(myg)
    quietly graph dir
    assert strtrim(`"`r(list)'"') == "myg_dist"
    graph describe myg_dist
    assert strpos(`"`r(command)'"', "Custom Title") > 0
    assert strpos(`"`r(command)'"', `""Mileage (mpg)", size(medium)"') == 0
    * without title() the lone panel keeps the covariate label
    graph drop _all
    psdash balance foreign ps, covariates(mpg weight) wvar(w) distribution(mpg) name(myh)
    graph describe myh_dist
    assert strpos(`"`r(command)'"', `""Mileage (mpg)", size(medium)"') > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F14_dist_single_name_title `rc'

**# T10 (F18) strategies(att/atc) with an all-zero-weight arm is refused
capture noisily {
    clear
    set seed 5
    set obs 200
    generate byte t = _n <= 100
    generate double x = rnormal()
    generate double ps = cond(t == 1, .6, 0)
    generate double w1 = 1
    capture psdash balance t ps, covariates(x) estimand(att) nograph
    assert _rc == 198
    capture noisily psdash balance t ps, covariates(x) wvar(w1) strategies(raw att)
    assert _rc == 198
    * the balance results are still posted, as for the other strategies() refusal
    confirm matrix r(balance)
    replace ps = cond(t == 1, 1, .4)
    capture noisily psdash balance t ps, covariates(x) wvar(w1) strategies(raw atc)
    assert _rc == 198
    * guard: a valid strategy set still runs
    replace ps = cond(t == 1, .6, .4)
    psdash balance t ps, covariates(x) wvar(w1) strategies(raw ate att atc)
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F18_strategies_zero_arm `rc'

**# T11 (F15) K = 2 coded 1/2: positivity scalars and finding match the 0/1 coding
capture noisily {
    clear
    set seed 6
    set obs 300
    generate double x = rnormal()
    generate byte t01 = runiform() < invlogit(x)
    generate byte t12 = t01 + 1
    generate double ps = invlogit(x)
    replace ps = 0.995 in 1
    replace ps = 1 in 2
    psdash balance t01 ps, covariates(x) nowvar nograph
    local b01 = r(n_ps_boundary)
    local n01 = r(n_ps_near_boundary)
    local w01 = r(n_warnings)
    local s01 `"`r(warnings)'"'
    assert `b01' == 1 & `n01' == 1
    psdash balance t12 ps, covariates(x) nowvar nograph
    assert r(K) == 2
    assert r(n_ps_boundary) == `b01'
    assert r(n_ps_near_boundary) == `n01'
    assert r(n_warnings) == `w01'
    assert strpos(`"`r(warnings)'"', "1 exact-PS-boundary observation(s)") > 0
    * no PS: zero counts, as the 0/1 path posts
    generate double w = 1
    psdash balance t12, covariates(x) wvar(w) nograph
    assert r(n_ps_boundary) == 0 & r(n_ps_near_boundary) == 0
    * overlays still refused for a non-0/1 coding, before any output
    replace ps = invlogit(x) in 2
    return clear
    capture psdash balance t12 ps, covariates(x) strategies(raw ate)
    assert _rc == 198
    capture confirm matrix r(balance)
    assert _rc != 0
    capture psdash balance t12 ps, covariates(x) distribution(x)
    assert _rc == 198
    * guard: K = 3 posts no single-PS positivity scalars
    generate byte g3 = 1 + floor(3*runiform())
    psdash balance g3, covariates(x) wvar(w) nograph
    capture confirm scalar r(n_ps_boundary)
    assert _rc != 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec F15_k2_noncoded_positivity `rc'

**# T12 (M4) multigroup UNDEFINED row status; vrbounds() shown unrounded
capture noisily {
    clear
    set seed 8
    set obs 60
    generate byte g = ceil(_n/20)
    generate double xconst = cond(g == 1, 1, 2)
    replace xconst = 5 if g == 3
    generate double zwide = rnormal() * cond(g == 2, 4, 1)
    tempfile lg
    log using "`lg'", text replace name(_v191lg)
    psdash balance g, covariates(xconst zwide) nowvar nograph vrbounds(0.45 2.25)
    * log close replaces r(): read the results first
    matrix B = r(balance)
    local nvr = r(n_vr_imbalanced)
    log close _v191lg
    assert B[1,3] == . & B[1,8] == .
    assert `nvr' == 1
    mata: _v191_rowhas(st_local("lg"), "xconst |", "UNDEFINED")
    assert scalar(v191_n) == 1
    mata: _v191_rowhas(st_local("lg"), "xconst |", "IMBALANCED")
    assert scalar(v191_n) == 0
    mata: _v191_count(st_local("lg"), "VR outside [0.45, 2.25]:")
    assert scalar(v191_n) == 1
    * binary display keeps the default text and shows the user bounds verbatim
    generate byte t = g == 2
    log using "`lg'", text replace name(_v191lg)
    psdash balance t, covariates(zwide) nowvar nograph
    psdash balance t, covariates(zwide) nowvar nograph vrbounds(0.45 2.25)
    log close _v191lg
    mata: _v191_count(st_local("lg"), "VR outside [0.5, 2.0]:")
    assert scalar(v191_n) == 1
    mata: _v191_count(st_local("lg"), "VR outside [0.45, 2.25]:")
    assert scalar(v191_n) == 1
    scalar drop v191_n
}
local rc = _rc
capture log close _v191lg
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec M4_mg_undefined_vrbounds `rc'

graph drop _all
display "RESULT: test_v191_balance tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V191_FAILED"
global V191_FAILED
_psdash_qa_cleanup
log close
if `fail' exit 1
