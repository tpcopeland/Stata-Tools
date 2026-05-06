* test_errors.do - Focused error-path tests for gcomp + gcomptab
* Coverage: explicit rc assertions for uncovered high-value option guards
*   and mediation/table export failure modes

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local testdir "`c(tmpdir)'"

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

capture program drop _make_med_data
program define _make_med_data
    clear
    set seed 4201
    set obs 240
    gen double c = rnormal()
    gen byte x = rbinomial(1, invlogit(-0.4 + 0.2 * c))
    gen byte m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.3 * c))
    gen byte y = rbinomial(1, invlogit(-1.5 + 0.5 * m + 0.4 * x + 0.2 * c))
end

capture program drop _make_oce_data
program define _make_oce_data
    clear
    set seed 4202
    set obs 360
    gen double c = rnormal()
    gen byte x = mod(_n - 1, 3)
    gen byte m = rbinomial(1, invlogit(-0.4 + 0.25 * x + 0.15 * c))
    gen byte y = rbinomial(1, invlogit(-1.0 + 0.35 * m - 0.15 * x + 0.10 * c))
end

capture program drop _make_tv_data
program define _make_tv_data
    clear
    set seed 4203
    set obs 90
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L = rnormal() + 0.2 * time
    gen byte A = rbinomial(1, invlogit(-0.8 + 0.35 * L))
    gen byte Y = rbinomial(1, invlogit(-1.7 + 0.4 * L + 0.35 * A))
end

capture program drop _mock_gcomp_normal_only
program define _mock_gcomp_normal_only, eclass
    version 16.0

    tempname b V se_mat cin
    ereturn clear
    matrix `b' = (0.12, 0.08, 0.04, 0.333, 0.07)
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = J(5, 5, 0)
    matrix `V'[1,1] = 0.03^2
    matrix `V'[2,2] = 0.02^2
    matrix `V'[3,3] = 0.015^2
    matrix `V'[4,4] = 0.05^2
    matrix `V'[5,5] = 0.025^2
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"

    matrix `se_mat' = (0.03, 0.02, 0.015, 0.05, 0.025)
    matrix colnames `se_mat' = tce nde nie pm cde
    ereturn matrix se = `se_mat'

    matrix `cin' = (0.0612, 0.0408, 0.0106, 0.2350, 0.0210 \ ///
                    0.1788, 0.1192, 0.0694, 0.4310, 0.1190)
    matrix colnames `cin' = tce nde nie pm cde
    ereturn matrix ci_normal = `cin'
end

* ============================================================
* E1: Time-varying mode requires idvar()
* ============================================================

local ++test_count
capture noisily {
    _make_tv_data
    capture gcomp Y L A id time, outcome(Y) ///
        tvar(time) varyingcovariates(L) ///
        commands(L: regress, Y: logit, A: logit) ///
        equations(L: A, Y: L A, A: L) ///
        intvars(A) interventions(A_: A_=1, A_: A_=0) ///
        sim(20) samples(1) seed(1) eofu
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E1 missing idvar() returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E1 missing idvar() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* E2: Time-varying mode requires interventions()
* ============================================================

local ++test_count
capture noisily {
    _make_tv_data
    capture gcomp Y L A id time, outcome(Y) ///
        idvar(id) tvar(time) varyingcovariates(L) ///
        commands(L: regress, Y: logit, A: logit) ///
        equations(L: A, Y: L A, A: L) ///
        intvars(A) sim(20) samples(1) seed(2) eofu
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E2 missing interventions() returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E2 missing interventions() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* E3: exposure() is invalid without mediation
* ============================================================

local ++test_count
capture noisily {
    _make_tv_data
    capture gcomp Y L A id time, outcome(Y) ///
        idvar(id) tvar(time) varyingcovariates(L) ///
        commands(L: regress, Y: logit, A: logit) ///
        equations(L: A, Y: L A, A: L) ///
        intvars(A) interventions(A_: A_=1, A_: A_=0) ///
        exposure(A) sim(20) samples(1) seed(3) eofu
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E3 exposure() without mediation returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E3 exposure() without mediation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* E4: specific requires both baseline() and alternative()
* ============================================================

local ++test_count
capture noisily {
    _make_med_data
    capture gcomp y m x c, outcome(y) mediation specific ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) baseline(x: 0) ///
        sim(20) samples(1) seed(4)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E4 specific missing alternative() returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E4 specific missing alternative() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* E5: dynamic is invalid with mediation
* ============================================================

local ++test_count
capture noisily {
    _make_med_data
    capture gcomp y m x c, outcome(y) mediation obe dynamic ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(20) samples(1) seed(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E5 dynamic + mediation returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E5 dynamic + mediation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* E6: logOR and logRR cannot be combined
* ============================================================

local ++test_count
capture noisily {
    _make_med_data
    capture gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) logOR logRR sim(20) samples(1) seed(6)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E6 logOR + logRR returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E6 logOR + logRR (error `=_rc')"
    local ++fail_count
}

* ============================================================
* E7: gcomptab rejects oce mediation results
* ============================================================

local ++test_count
local oce_xlsx "`testdir'/gcomp_oce_error.xlsx"
capture erase "`oce_xlsx'"
capture noisily {
    _make_oce_data
    gcomp y m x c, outcome(y) mediation oce ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(40) samples(3) seed(7)
    capture gcomptab, xlsx("`oce_xlsx'") sheet("OCE")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E7 gcomptab after oce mediation returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E7 gcomptab after oce mediation (error `=_rc')"
    local ++fail_count
}
capture erase "`oce_xlsx'"

* ============================================================
* E8: percentile CI export requires e(ci_percentile)
* ============================================================

local ++test_count
local pct_xlsx "`testdir'/gcomp_ci_percentile_error.xlsx"
capture erase "`pct_xlsx'"
capture noisily {
    ereturn clear
    capture program drop _mock_gcomp_missing_pct
    program define _mock_gcomp_missing_pct, eclass
        version 16.0
        tempname b V se_mat cin
        matrix `b' = (0.12, 0.08, 0.04, 0.333, 0.07)
        matrix colnames `b' = tce nde nie pm cde
        matrix `V' = J(5, 5, 0)
        matrix `V'[1,1] = 0.03^2
        matrix `V'[2,2] = 0.02^2
        matrix `V'[3,3] = 0.015^2
        matrix `V'[4,4] = 0.05^2
        matrix `V'[5,5] = 0.025^2
        matrix colnames `V' = tce nde nie pm cde
        matrix rownames `V' = tce nde nie pm cde
        ereturn post `b' `V'
        ereturn local cmd "gcomp"
        ereturn local analysis_type "mediation"
        ereturn local mediation_type "obe"
        matrix `se_mat' = (0.03, 0.02, 0.015, 0.05, 0.025)
        matrix colnames `se_mat' = tce nde nie pm cde
        ereturn matrix se = `se_mat'
        matrix `cin' = (0.0612, 0.0408, 0.0106, 0.2350, 0.0210 \ ///
                        0.1788, 0.1192, 0.0694, 0.4310, 0.1190)
        matrix colnames `cin' = tce nde nie pm cde
        ereturn matrix ci_normal = `cin'
    end
    _mock_gcomp_missing_pct
    capture matrix list e(ci_percentile)
    assert _rc == 111
    capture gcomptab, xlsx("`pct_xlsx'") sheet("Percentile") ci(percentile)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: E8 missing ci_percentile returns rc 111"
    local ++pass_count
}
else {
    display as error "  FAIL: E8 missing ci_percentile (error `=_rc')"
    local ++fail_count
}
capture erase "`pct_xlsx'"

* ============================================================
* E9: decimal() out of range returns rc 198
* ============================================================

local ++test_count
local dec_xlsx "`testdir'/gcomp_decimal_error.xlsx"
capture erase "`dec_xlsx'"
capture noisily {
    _mock_gcomp_normal_only
    capture gcomptab, xlsx("`dec_xlsx'") sheet("Decimal") decimal(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E9 invalid decimal() returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E9 invalid decimal() (error `=_rc')"
    local ++fail_count
}
capture erase "`dec_xlsx'"

* ============================================================
* E10: boldp() out of range returns rc 198
* ============================================================

local ++test_count
local bold_xlsx "`testdir'/gcomp_boldp_error.xlsx"
capture erase "`bold_xlsx'"
capture noisily {
    _mock_gcomp_normal_only
    capture gcomptab, xlsx("`bold_xlsx'") sheet("BoldP") boldp(1.2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E10 invalid boldp() returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E10 invalid boldp() (error `=_rc')"
    local ++fail_count
}
capture erase "`bold_xlsx'"

* ============================================================
* E11: highlight() out of range returns rc 198
* ============================================================

local ++test_count
local hi_xlsx "`testdir'/gcomp_highlight_error.xlsx"
capture erase "`hi_xlsx'"
capture noisily {
    _mock_gcomp_normal_only
    capture gcomptab, xlsx("`hi_xlsx'") sheet("Highlight") highlight(1.1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E11 invalid highlight() returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E11 invalid highlight() (error `=_rc')"
    local ++fail_count
}
capture erase "`hi_xlsx'"

* ============================================================
* E12: samples(1) is rejected before bootstrap
* ============================================================

local ++test_count
capture noisily {
    _make_med_data
    capture gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(50) samples(1) seed(12)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E12 samples(1) returns package rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E12 samples(1) validation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "test_errors Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_errors tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
