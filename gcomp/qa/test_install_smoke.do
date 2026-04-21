* test_install_smoke.do - Fresh-install smoke tests for gcomp
* Coverage: isolated PLUS/PERSONAL install, command/help discovery,
*   helper discoverability, Excel helper autoload, and installed
*   mediation + time-varying smoke paths

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

local public_cmds gcomp gcomptab
local help_targets gcomp gcomptab
local helper_ados _gcomp_bootstrap _gcomp_bootstrap_impl _gcomp_xl_common

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname smoke_id
local smoke_tag = subinstr("`smoke_id'", "__", "", .)
local plus_dir "`testdir'/gcomp_plus_`smoke_tag'"
local personal_dir "`testdir'/gcomp_personal_`smoke_tag'"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace

capture program drop _make_med_data
program define _make_med_data
    clear
    set seed 4101
    set obs 300
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.4 + 0.2 * c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.3 * c))
    gen double y = rbinomial(1, invlogit(-1.4 + 0.5 * m + 0.4 * x + 0.2 * c))
end

capture program drop _make_tv_data
program define _make_tv_data
    clear
    set seed 20260421
    set obs 360
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0

    bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1

    bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2

    bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3

    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1

    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3
end

* ============================================================
* I1: Public commands are discoverable after isolated install
* ============================================================

local ++test_count
capture noisily {
    foreach cmd of local public_cmds {
        capture which `cmd'
        assert _rc == 0
    }
}
if _rc == 0 {
    display as result "  PASS: I1 installed gcomp and gcomptab are discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: I1 command discovery (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I2: Main ado/help resolve inside isolated PLUS tree
* ============================================================

local ++test_count
capture noisily {
    capture findfile gcomp.ado
    assert _rc == 0
    assert strpos("`r(fn)'", "`plus_dir'") > 0

    capture findfile gcomp.sthlp
    assert _rc == 0
    assert strpos("`r(fn)'", "`plus_dir'") > 0
}
if _rc == 0 {
    display as result "  PASS: I2 gcomp ado/help resolve inside isolated PLUS"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 gcomp PLUS-tree resolution (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I3: Help discovery works for gcomp and gcomptab
* ============================================================

local ++test_count
capture noisily {
    foreach target of local help_targets {
        capture quietly help `target'
        assert _rc == 0
        capture findfile `target'.sthlp
        assert _rc == 0
        assert strpos("`r(fn)'", "`plus_dir'") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: I3 help discovery works after isolated install"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 help discovery (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I4: Helper ado files are discoverable after install
* ============================================================

local ++test_count
capture noisily {
    foreach helper of local helper_ados {
        capture findfile `helper'.ado
        assert _rc == 0
        assert strpos("`r(fn)'", "`plus_dir'") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: I4 helper ado files are discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: I4 helper discoverability (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I5: Excel helper is not preloaded before first gcomptab call
* ============================================================

local ++test_count
capture noisily {
    capture program list _gcomp_validate_path
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: I5 Excel helper is not preloaded"
    local ++pass_count
}
else {
    display as error "  FAIL: I5 helper preloaded unexpectedly (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I6: Installed mediation fit runs after isolated install
* ============================================================

local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(50) samples(3) seed(4103)
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    assert e(N) == _N
}
if _rc == 0 {
    display as result "  PASS: I6 installed mediation gcomp fit runs"
    local ++pass_count
}
else {
    display as error "  FAIL: I6 installed mediation fit (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I7: gcomptab creates workbook and auto-loads Excel helper
* ============================================================

local ++test_count
local smoke_xlsx "`testdir'/gcomp_install_smoke_`smoke_tag'.xlsx"
capture erase "`smoke_xlsx'"
capture noisily {
    gcomptab, xlsx("`smoke_xlsx'") sheet("Smoke")
    confirm file "`smoke_xlsx'"
    capture program list _gcomp_validate_path
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: I7 gcomptab export works and helper autoloads"
    local ++pass_count
}
else {
    display as error "  FAIL: I7 gcomptab/helper autoload (error `=_rc')"
    local ++fail_count
}
capture erase "`smoke_xlsx'"

* ============================================================
* I8: Installed time-varying eofu fit returns nondegenerate POs
* ============================================================

local ++test_count
capture noisily {
    _make_tv_data
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        sim(120) samples(3) seed(20260421) eofu
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "time_varying"
    assert e(N) == 120
    tempname _eb
    matrix `_eb' = e(b)
    local PO1 = `_eb'[1,1]
    local PO2 = `_eb'[1,2]
    local PO3 = `_eb'[1,3]
    assert colsof(`_eb') == 3
    assert `PO1' >= 0 & `PO1' <= 1
    assert `PO2' >= 0 & `PO2' <= 1
    assert `PO3' >= 0 & `PO3' <= 1
    assert abs(`PO1' - `PO2') > 0.01
    assert `PO1' < `PO2'
    assert `PO3' > `PO1' & `PO3' < `PO2'
}
if _rc == 0 {
    display as result "  PASS: I8 installed time-varying eofu fit returns ordered nondegenerate POs"
    local ++pass_count
}
else {
    display as error "  FAIL: I8 installed time-varying fit (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup + summary
* ============================================================

display ""
display as result "test_install_smoke Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_install_smoke tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
}
else {
    display as result "PASS"
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard

if `fail_count' > 0 {
    exit 1
}
