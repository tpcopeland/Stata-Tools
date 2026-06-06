*! test_eplot_bridge.do - QA for tabtools eplot companion frames

clear all
set more off
version 17.0

local cwd "`c(pwd)'"
if regexm("`cwd'", "/qa/_package$") {
    local qa_dir = regexr("`cwd'", "/_package$", "")
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")
}
else if regexm("`cwd'", "/qa$") {
    local qa_dir "`cwd'"
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")
}
else if regexm("`cwd'", "/tabtools$") {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}
local tools_root = regexr("`pkg_dir'", "/tabtools$", "")
local eplot_dir "`tools_root'/eplot"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _eplot_bridge
log using "`output_dir'/test_eplot_bridge.log", replace text name(_eplot_bridge)

capture confirm file "`eplot_dir'/eplot.ado"
if _rc {
    display as error "Sibling eplot package not found at `eplot_dir'"
    log close _eplot_bridge
    exit 601
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
capture ado uninstall eplot
quietly net install eplot, from("`eplot_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _bridge_result
program define _bridge_result
    args ok msg
    if `ok' {
        display as result "  PASS: `msg'"
    }
    else {
        display as error "  FAIL: `msg' (rc=`=_rc')"
    }
end

foreach fr in _eb_reg _eb_reg2 _eb_reg_ep _eb_reg2_ep _eb_eff _eb_eff_ep ///
    _eb_comp _eb_comp_ep _eb_rates _eb_hr_model _eb_hr_model_ep _eb_hr _eb_hr_ep {
    capture frame drop `fr'
}
capture graph drop _all

* -------------------------------------------------------------------------
* 1. regtab emits a linked graph-ready eplot frame
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    regtab, frame(_eb_reg, replace) eplotframe(_eb_reg_ep, replace) coef("b")

    assert "`r(eplotframe)'" == "_eb_reg_ep"
    frame _eb_reg: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_reg_ep"
    capture frame _eb_reg: ds _eplot*
    assert _rc == 111

    frame _eb_reg_ep {
        confirm string variable label
        confirm numeric variable estimate
        confirm numeric variable ll
        confirm numeric variable ul
        confirm numeric variable pvalue
        confirm string variable rowtype
        count if rowtype == "effect" & estimate < . & ll < . & ul < .
        assert r(N) >= 2
        local source : char _dta[tabtools_source]
        assert "`source'" == "regtab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "regtab eplotframe() emits linked companion frame"
}
else {
    local ++fail_count
    _bridge_result 0 "regtab eplotframe() emits linked companion frame"
}

* -------------------------------------------------------------------------
* 2. eplot consumes the companion frame without changing active data
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 2
    gen byte sentinel = _n
    local active_frame "`c(frame)'"

    eplot, frame(_eb_reg_ep) labels(label) rowtype(rowtype) ///
        name(_eb_reg_plot, replace)

    assert "`c(frame)'" == "`active_frame'"
    assert _N == 2
    assert sentinel[2] == 2
    assert r(N) >= 2
    assert strpos(`"`r(cmd)'"', "scheme(") == 0
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "eplot frame() consumes tabtools companion frame"
}
else {
    local ++fail_count
    _bridge_result 0 "eplot frame() consumes tabtools companion frame"
}

* -------------------------------------------------------------------------
* 3. effecttab from() emits the same companion contract
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    matrix eff = (1.50, 0.80, 2.20, 0.040 \ 2.30, 1.10, 3.50, 0.001)
    matrix rownames eff = Age Sex

    effecttab, from(eff) frame(_eb_eff, replace) ///
        eplotframe(_eb_eff_ep, replace) effect("OR")

    assert "`r(eplotframe)'" == "_eb_eff_ep"
    frame _eb_eff: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_eff_ep"
    capture frame _eb_eff: ds _eplot*
    assert _rc == 111

    frame _eb_eff_ep {
        count if rowtype == "effect" & estimate < . & ll < . & ul < .
        assert r(N) == 2
        assert abs(estimate[1] - 1.50) < 1e-10
        local source : char _dta[tabtools_source]
        assert "`source'" == "effecttab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "effecttab eplotframe() emits linked companion frame"
}
else {
    local ++fail_count
    _bridge_result 0 "effecttab eplotframe() emits linked companion frame"
}
capture matrix drop eff

* -------------------------------------------------------------------------
* 4. comptab composes source companions and forest preserves table returns
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg length
    regtab, frame(_eb_reg2, replace) eplotframe(_eb_reg2_ep, replace) coef("b")

    comptab _eb_reg _eb_reg2, rows(1 2 \ 1 2) ///
        eplotframe(_eb_comp_ep, replace) frame(_eb_comp, replace) ///
        forest eplotoptions(name(_eb_comp_plot, replace))

    assert "`r(frame)'" == "_eb_comp"
    assert "`r(eplotframe)'" == "_eb_comp_ep"
    assert r(N_frames) == 2
    assert r(N_rows) >= 6
    frame _eb_comp: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_comp_ep"
    frame _eb_comp_ep {
        count if rowtype == "effect"
        assert r(N) >= 4
        local source : char _dta[tabtools_source]
        assert "`source'" == "comptab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "comptab forest composes companion frame and preserves returns"
}
else {
    local ++fail_count
    _bridge_result 0 "comptab forest composes companion frame and preserves returns"
}

* -------------------------------------------------------------------------
* 5. hrcomptab composes model companions and forest preserves returns
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _eb_exp 0 "None" 1 "Current", replace
    label values exposure _eb_exp
    save "`rate1'.dta", replace

    clear
    stratetab, using(`rate1') outcomes(1) frame(_eb_rates, replace) ///
        outlabels("Outcome") explabels("Exposure")

    clear
    set obs 80
    set seed 60606
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    regtab, frame(_eb_hr_model, replace) eplotframe(_eb_hr_model_ep, replace) ///
        noint coef("aHR")

    hrcomptab _eb_rates, modelframes(_eb_hr_model) rows(1) ///
        effect("aHR") eplotframe(_eb_hr_ep, replace) frame(_eb_hr, replace) ///
        forest eplotoptions(name(_eb_hr_plot, replace))

    assert "`r(frame)'" == "_eb_hr"
    assert "`r(eplotframe)'" == "_eb_hr_ep"
    assert r(N_modelframes) == 1
    frame _eb_hr: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_hr_ep"
    frame _eb_hr_ep {
        count if rowtype == "effect"
        assert r(N) >= 1
        local source : char _dta[tabtools_source]
        assert "`source'" == "hrcomptab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "hrcomptab forest composes companion frame and preserves returns"
}
else {
    local ++fail_count
    _bridge_result 0 "hrcomptab forest composes companion frame and preserves returns"
}

foreach fr in _eb_reg _eb_reg2 _eb_reg_ep _eb_reg2_ep _eb_eff _eb_eff_ep ///
    _eb_comp _eb_comp_ep _eb_rates _eb_hr_model _eb_hr_model_ep _eb_hr _eb_hr_ep {
    capture frame drop `fr'
}
capture graph drop _all

display _newline as text "tabtools eplot bridge QA: `pass_count'/`test_count' passed"
log close _eplot_bridge

if `fail_count' > 0 {
    exit 9
}
