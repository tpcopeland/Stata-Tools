* test_collect_json_render_contracts.do - raw collect .stjson renderer contracts
* Run from tabtools/qa or tabtools/qa/_package.

clear all
set more off
set varabbrev off
version 17.0

capture log close _collect_json
log using "test_collect_json_render_contracts.log", replace text name(_collect_json)

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local qa_dir "`_cwd'"
}
else {
    local qa_dir "`_cwd'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which _tabtools_collect_render_current

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helper Contracts

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign

    collect layout (cmdset) (result[cmd cmdline])
    preserve
    _tabtools_collect_render_current, type(meta) rowdim(cmdset) ///
        results(cmd cmdline) dropempty
    assert _N == 3
    assert c(k) == 3
    assert B[1] == "Command"
    assert C[1] == "Command line as typed"
    assert A[2] == "1"
    assert B[2] == "regress"
    assert strpos(C[3], "foreign") > 0
    restore
}
if _rc == 0 {
    display as result "  PASS: metadata layout renders from collect .stjson"
    local ++pass_count
}
else {
    display as error "  FAIL: metadata layout render (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    collect label levels result _r_b "Coef.", modify
    collect label levels result _r_ci "95% CI", modify
    collect label levels result _r_p "p-value", modify
    collect layout (colname) (cmdset#result[_r_b _r_ci _r_p])

    preserve
    _tabtools_collect_render_current, type(main) rowdim(colname) coldim(cmdset) ///
        results(_r_b _r_ci _r_p) sep(", ")
    assert _N == 6
    assert c(k) == 7
    assert A[3] == "Mileage (mpg)"
    assert B[3] != ""
    assert strpos(C[3], ", ") > 0
    assert D[3] != ""
    assert E[5] != ""
    assert G[6] != ""
    restore
}
if _rc == 0 {
    display as result "  PASS: regression main layout renders raw coefficients and CIs"
    local ++pass_count
}
else {
    display as error "  FAIL: regression main layout render (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 1000
    set seed 12345
    gen school = ceil(_n/100)
    gen class = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 1.2
    bysort class: gen u_class = `uc'[1] * 0.7
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    quietly collect: mixed y x || school: || class:
    collect label levels result _r_b "Coef.", modify
    collect label levels result _r_ci "95% CI", modify
    collect label levels result _r_p "p-value", modify
    collect style cell result[_r_ci], warn sformat("(%s)") cidelimiter(", ")
    collect layout (coleq#colname) (cmdset#result[_r_b _r_ci _r_p]) ()

    preserve
    _tabtools_collect_render_current, type(main) rowdim(coleq#colname) ///
        coldim(cmdset) results(_r_b _r_ci _r_p) sep(", ")
    assert _N == 11
    assert c(k) == 4
    assert A[3] == "y"
    assert A[4] == "x"
    assert A[6] == "school"
    assert A[7] == "var(_cons)"
    assert A[8] == "class"
    assert A[9] == "var(_cons)"
    assert A[10] == "Residual"
    assert A[11] == "var(e)"
    assert B[4] != ""
    assert strpos(C[4], ", ") > 0
    assert B[7] != ""
    assert B[9] != ""
    assert B[11] != ""
    restore
}
if _rc == 0 {
    display as result "  PASS: multilevel coleq#colname main layout renders without workbook fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: multilevel coleq#colname raw render (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.foreign mpg
    collect label levels result _r_b "Coef.", modify
    collect label levels result _r_ci "95% CI", modify
    collect label levels result _r_p "p-value", modify
    collect layout (colname) (cmdset#result[_r_b _r_ci _r_p])

    preserve
    _tabtools_collect_render_current, type(main) rowdim(colname) coldim(cmdset) ///
        results(_r_b _r_ci _r_p) sep(", ")
    quietly count if A == "foreign"
    assert r(N) == 0
    restore

    preserve
    _tabtools_collect_render_current, type(main) rowdim(colname) coldim(cmdset) ///
        results(_r_b _r_ci _r_p) sep(", ") factorparents
    quietly count if A == "foreign"
    assert r(N) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: factor parent rows are opt-in for regtab compatibility"
    local ++pass_count
}
else {
    display as error "  FAIL: factor parent opt-in contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture frame drop _cj_fv
    sysuse auto, clear
    gen byte education = cond(rep78 <= 2, 1, cond(rep78 <= 4, 2, 3))
    label define _cj_edulab 1 "Primary" 2 "Secondary" 3 "Tertiary"
    label values education _cj_edulab
    label variable education "Education level"

    collect clear
    quietly collect: regress price i.education mpg
    regtab, frame(_cj_fv, replace)

    frame _cj_fv: gen long _rowid = _n
    frame _cj_fv: quietly count if A == "Education level"
    assert r(N) == 1
    frame _cj_fv: quietly summarize _rowid if A == "Education level", meanonly
    local _parent = r(min)
    local _level1 = `_parent' + 1
    local _level2 = `_parent' + 2
    local _level3 = `_parent' + 3
    frame _cj_fv: assert substr(A[`_parent'], 1, 1) != " "
    frame _cj_fv: assert A[`_level1'] == "  Primary"
    frame _cj_fv: assert A[`_level2'] == "  Secondary"
    frame _cj_fv: assert A[`_level3'] == "  Tertiary"
    frame _cj_fv: assert strtrim(A[`_level2']) == "Secondary"
    frame drop _cj_fv

    capture frame drop _cj_fv_drop
    regtab, frame(_cj_fv_drop, replace) drop(2.education 3.education)
    frame _cj_fv_drop: quietly count if strpos(A, "Secondary") | strpos(A, "Tertiary")
    assert r(N) == 0
    frame _cj_fv_drop: quietly count if A == "Education level" | strpos(A, "Primary")
    assert r(N) >= 1
    frame drop _cj_fv_drop
}
if _rc == 0 {
    display as result "  PASS: regtab factor rows use variable labels with indented levels"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab factor variable row labels (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    foreach rlevel in N ll rank not_a_result {
        capture collect label levels result `rlevel' "`rlevel'", modify
    }
    collect layout (cmdset) (result[N ll rank not_a_result])

    preserve
    _tabtools_collect_render_current, type(stats) rowdim(cmdset) ///
        results(N ll rank not_a_result) dropempty
    assert _N == 3
    assert c(k) == 4
    assert B[1] == "N"
    assert C[1] == "ll"
    assert D[1] == "rank"
    assert real(B[2]) == 74
    assert real(D[3]) == 4
    restore
}
if _rc == 0 {
    display as result "  PASS: stats layout drops absent result columns"
    local ++pass_count
}
else {
    display as error "  FAIL: stats layout render (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 1000
    set seed 12345
    gen school = ceil(_n/100)
    gen class = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 1.2
    bysort class: gen u_class = `uc'[1] * 0.7
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    quietly collect: mixed y x || school: || class:

    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re_total = 0
    local var_resid = 0
    local col = 0
    foreach colname of local colnames {
        local ++col
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re_total = `var_re_total' + exp(2 * `b_mat'[1, `col'])
        }
        if strpos("`colname'", "lnsig_e:") {
            local var_resid = exp(2 * `b_mat'[1, `col'])
        }
    }

    collect layout (cmdset) (colname[var(_cons) var(e)]#result[_r_b])
    preserve
    _tabtools_collect_render_current, type(icc) rowdim(cmdset) coldim(colname) ///
        collevels("var(_cons) var(e)") results(_r_b)
    local got_re = real(B[2])
    local got_resid = real(C[2])
    restore

    assert abs(`got_re' - `var_re_total') < 1e-8
    assert abs(`got_resid' - `var_resid') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: ICC render sums duplicate random-intercept variances"
    local ++pass_count
}
else {
    display as error "  FAIL: ICC variance aggregation contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: table rep78 foreign, statistic(mean price) ///
        statistic(sd price) statistic(frequency)
    collect layout (rep78) (foreign#result[mean sd frequency])

    preserve
    _tabtools_collect_render_current, type(desctab) rowdim(rep78) coldim(foreign) ///
        results(mean sd frequency)
    assert _N >= 8
    assert c(k) == 10
    assert B[2] == "Domestic"
    assert E[2] == "Foreign"
    assert H[2] == "Total"
    assert B[3] == "Mean"
    assert D[3] == "Frequency"
    assert A[4] == "Repair record 1978"
    assert A[_N] == "Total"
    restore
}
if _rc == 0 {
    display as result "  PASS: desctab coldim layout renders group/stat headers"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab coldim layout render (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: table rep78 foreign, statistic(mean price) ///
        statistic(frequency)
    collect layout (rep78#foreign) (result[mean frequency])

    preserve
    _tabtools_collect_render_current, type(desctab) rowdim(rep78#foreign) ///
        results(mean frequency)
    assert _N == 18
    assert c(k) == 3
    assert B[1] == "Mean"
    assert C[1] == "Frequency"
    assert A[2] == "Repair record 1978#Car origin"
    assert A[3] == "1 > Domestic"
    assert A[4] == "1 > Total"
    assert A[8] == "3 > Foreign"
    assert A[_N] == "Total > Total"
    assert B[3] != ""
    assert C[_N] != ""
    restore

    capture frame drop _cj_desc_compound
    desctab, frame(_cj_desc_compound)
    frame _cj_desc_compound: assert A[3] == "Repair record 1978#Car origin"
    frame _cj_desc_compound: assert A[4] == "1 > Domestic"
    frame _cj_desc_compound: assert c1[4] == "2"
    frame drop _cj_desc_compound
}
if _rc == 0 {
    display as result "  PASS: desctab compound row layout renders without workbook fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab compound row layout render (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte highmpg = mpg > 20
    label define _cj_highmpg 0 "Low MPG" 1 "High MPG"
    label values highmpg _cj_highmpg
    label variable highmpg "Mileage band"

    collect clear
    quietly collect: table rep78 foreign highmpg, statistic(mean price) ///
        statistic(frequency)
    collect layout (rep78) (foreign#highmpg#result[mean frequency])

    preserve
    _tabtools_collect_render_current, type(desctab) rowdim(rep78) ///
        coldim(foreign#highmpg) results(mean frequency)
    assert _N == 10
    assert c(k) == 19
    assert B[1] == "Car origin#Mileage band"
    assert B[2] == "Domestic > Low MPG"
    assert B[3] == "Mean"
    assert C[3] == "Frequency"
    assert A[4] == "Repair record 1978"
    assert A[5] == "1"
    assert B[5] != ""
    assert C[5] != ""
    assert R[10] != ""
    assert S[10] != ""
    restore

    capture frame drop _cj_desc_colcompound
    desctab, frame(_cj_desc_colcompound)
    frame _cj_desc_colcompound: assert A[2] == "Repair record 1978"
    frame _cj_desc_colcompound: assert c1[2] == "Domestic > Low MPG"
    frame _cj_desc_colcompound: assert c1[3] == "Frequency"
    frame _cj_desc_colcompound: assert c2[3] == "Mean"
    frame _cj_desc_colcompound: assert A[4] == "1"
    frame drop _cj_desc_colcompound
}
if _rc == 0 {
    display as result "  PASS: desctab compound column layout renders without workbook fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab compound column layout render (rc=`=_rc')"
    local ++fail_count
}

**# Public Command Smoke

local ++test_count
capture noisily {
    capture frame drop _cj_reg
    capture frame drop _cj_eff
    capture frame drop _cj_desc

    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    regtab, stats(N ll aic bic r2) frame(_cj_reg)
    frame _cj_reg: assert _N > 5
    frame drop _cj_reg

    sysuse auto, clear
    collect clear
    quietly collect: teffects ipw (price) (foreign mpg weight)
    effecttab, frame(_cj_eff)
    frame _cj_eff: assert _N >= 4
    frame drop _cj_eff

    sysuse auto, clear
    collect clear
    quietly collect: table rep78 foreign, statistic(mean price) ///
        statistic(sd price) statistic(frequency)
    desctab, frame(_cj_desc)
    frame _cj_desc: assert _N > 5
    frame drop _cj_desc
}
if _rc == 0 {
    display as result "  PASS: public commands run through raw collect render path"
    local ++pass_count
}
else {
    display as error "  FAIL: public command smoke (rc=`=_rc')"
    local ++fail_count
}

display as result "Collect JSON render QA: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _collect_json
    exit 1
}

display as result "ALL COLLECT JSON RENDER TESTS PASSED"
log close _collect_json
