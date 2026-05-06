clear all
set more off
version 16.0
set varabbrev off

* crossval_iivw_external.do
*
* External cross-validation of iivw against R reference implementations:
*   1. survival::coxph on survival::bladder2 for IIW weights
*   2. ipw::ipwpoint on cobalt::lalonde for IPTW weights
*   3. survival::coxph + geepack::geeglm on geepack::dietox for FIPTIW
*      weights and weighted independence-GEE outcome coefficients
*
* The companion R script regenerates all crossval_iivw_external_*.csv
* references in this directory.

args run_only
if "`run_only'" == "" local run_only = 0

**# Bootstrap

local here "`c(pwd)'"
local basename = substr("`here'", strrpos("`here'", "/") + 1, .)
if "`basename'" == "qa" {
    local qa_dir "`here'"
}
else {
    capture confirm file "`here'/crossval_iivw_external_refs.R"
    if _rc == 0 {
        local qa_dir "`here'"
    }
    else {
        capture confirm file "`here'/qa/crossval_iivw_external_refs.R"
        if _rc == 0 {
            local qa_dir "`here'/qa"
        }
        else {
            capture confirm file "`here'/iivw/qa/crossval_iivw_external_refs.R"
            if _rc == 0 {
                local qa_dir "`here'/iivw/qa"
            }
            else {
                display as error "could not locate crossval_iivw_external_refs.R"
                exit 601
            }
        }
    }
}
local pkg_dir "`qa_dir'/.."

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local rscript "`qa_dir'/crossval_iivw_external_refs.R"
capture noisily shell Rscript "`rscript'"
if _rc != 0 {
    display as error "R reference generation failed"
    exit _rc
}

foreach f in bladder bladder_coefs lalonde lalonde_coefs ///
    dietox dietox_weight_coefs dietox_geeglm {
    capture confirm file "`qa_dir'/crossval_iivw_external_`f'.csv"
    if _rc != 0 {
        display as error "missing reference file: crossval_iivw_external_`f'.csv"
        exit 601
    }
}

local test_count = 0
local pass_count = 0
local fail_count = 0

**# XV1: IIW weights match survival::coxph on bladder2

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        import delimited "`qa_dir'/crossval_iivw_external_bladder.csv", ///
            clear asdouble

        stset time, enter(time time_lag) failure(event_one) ///
            id(id) exit(time .)
        stcox rx2 number size, nohr efron nolog

        preserve
        import delimited "`qa_dir'/crossval_iivw_external_bladder_coefs.csv", ///
            clear asdouble
        local r_rx2 = rx2[1]
        local r_number = number[1]
        local r_size = size[1]
        restore

        assert abs(_b[rx2] - `r_rx2') < 1e-6
        assert abs(_b[number] - `r_number') < 1e-6
        assert abs(_b[size] - `r_size') < 1e-6

        iivw_weight, id(id) time(time) ///
            visit_cov(rx2 number size) efron nolog

        gen double diff_iw = abs(_iivw_iw - r_iivw)
        quietly summarize diff_iw, detail
        local max_diff = r(max)
        local mean_diff = r(mean)

        display as text "  bladder2 IIW max diff:  " %12.9f `max_diff'
        display as text "  bladder2 IIW mean diff: " %12.9f `mean_diff'
        assert `max_diff' < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: XV1 - IIW weights match survival::coxph bladder2"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV1 - IIW bladder2 comparison (error `=_rc')"
        local ++fail_count
    }
}

**# XV2: IPTW weights match ipw::ipwpoint on Lalonde

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        import delimited "`qa_dir'/crossval_iivw_external_lalonde.csv", ///
            clear asdouble

        logit treat age educ black hispan married nodegree re74 re75, nolog

        preserve
        import delimited "`qa_dir'/crossval_iivw_external_lalonde_coefs.csv", ///
            clear asdouble
        local r_cons = intercept[1]
        local r_age = age[1]
        local r_educ = educ[1]
        local r_black = black[1]
        local r_hispan = hispan[1]
        local r_married = married[1]
        local r_nodegree = nodegree[1]
        local r_re74 = re74[1]
        local r_re75 = re75[1]
        local r_num_cons = numerator_intercept[1]
        restore

        assert abs(_b[_cons] - `r_cons') < 1e-7
        assert abs(_b[age] - `r_age') < 1e-7
        assert abs(_b[educ] - `r_educ') < 1e-7
        assert abs(_b[black] - `r_black') < 1e-7
        assert abs(_b[hispan] - `r_hispan') < 1e-7
        assert abs(_b[married] - `r_married') < 1e-7
        assert abs(_b[nodegree] - `r_nodegree') < 1e-7
        assert abs(_b[re74] - `r_re74') < 1e-10
        assert abs(_b[re75] - `r_re75') < 1e-10

        quietly summarize treat
        local s_num_cons = logit(r(mean))
        assert abs(`s_num_cons' - `r_num_cons') < 1e-10

        iivw_weight, id(id) time(time) ///
            treat(treat) ///
            treat_cov(age educ black hispan married nodegree re74 re75) ///
            wtype(iptw) nolog

        gen double diff_tw = abs(_iivw_tw - r_iptw)
        quietly summarize diff_tw, detail
        local max_diff = r(max)
        local mean_diff = r(mean)

        display as text "  Lalonde IPTW max diff:  " %12.9f `max_diff'
        display as text "  Lalonde IPTW mean diff: " %12.9f `mean_diff'
        assert `max_diff' < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: XV2 - IPTW weights match ipw::ipwpoint Lalonde"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV2 - IPTW Lalonde comparison (error `=_rc')"
        local ++fail_count
    }
}

**# XV3: FIPTIW weights and outcome coefficients match R on Dietox

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        import delimited "`qa_dir'/crossval_iivw_external_dietox.csv", ///
            clear asdouble

        iivw_weight, id(id) time(time) ///
            visit_cov(cu_high startwt evit100 evit200) ///
            stabcov(cu_high) ///
            treat(cu_high) treat_cov(startwt evit100 evit200) ///
            efron nolog

        gen double diff_iiw = abs(_iivw_iw - r_iiw)
        gen double diff_iptw = abs(_iivw_tw - r_iptw)
        gen double diff_fiptiw = abs(_iivw_weight - r_fiptiw)
        gen double diff_product = abs(_iivw_weight - _iivw_iw * _iivw_tw)

        foreach dvar in diff_iiw diff_iptw diff_fiptiw diff_product {
            quietly summarize `dvar', detail
            local max_`dvar' = r(max)
        }

        display as text "  Dietox IIW max diff:     " %12.9f `max_diff_iiw'
        display as text "  Dietox IPTW max diff:    " %12.9f `max_diff_iptw'
        display as text "  Dietox FIPTIW max diff:  " %12.9f `max_diff_fiptiw'
        display as text "  Product identity max diff:" %12.9f `max_diff_product'

        assert `max_diff_iiw' < 1e-6
        assert `max_diff_iptw' < 1e-6
        assert `max_diff_fiptiw' < 1e-6
        assert `max_diff_product' < 1e-10

        iivw_fit weight cu_high feed0, timespec(linear) nolog

        local s_cons = _b[_cons]
        local s_cu_high = _b[cu_high]
        local s_feed0 = _b[feed0]
        local s_time = _b[time]

        preserve
        import delimited "`qa_dir'/crossval_iivw_external_dietox_geeglm.csv", ///
            clear asdouble
        local r_cons = intercept[1]
        local r_cu_high = cu_high[1]
        local r_feed0 = feed0[1]
        local r_time = time[1]
        restore

        display as text "  Dietox GEE coefficients (Stata - R):"
        display as text "    _cons   " %12.9f (`s_cons' - `r_cons')
        display as text "    cu_high " %12.9f (`s_cu_high' - `r_cu_high')
        display as text "    feed0   " %12.9f (`s_feed0' - `r_feed0')
        display as text "    time    " %12.9f (`s_time' - `r_time')

        assert abs(`s_cons' - `r_cons') < 1e-6
        assert abs(`s_cu_high' - `r_cu_high') < 1e-6
        assert abs(`s_feed0' - `r_feed0') < 1e-6
        assert abs(`s_time' - `r_time') < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: XV3 - FIPTIW weights and GEE coefficients match Dietox references"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV3 - FIPTIW/Dietox comparison (error `=_rc')"
        local ++fail_count
    }
}

**# Summary

display as text ""
display as result "External Cross-Validation: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "  XV1: IIW vs survival::coxph bladder2"
display as text "  XV2: IPTW vs ipw::ipwpoint Lalonde"
display as text "  XV3: FIPTIW/outcome vs survival::coxph + geepack::geeglm Dietox"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' EXTERNAL CROSS-VALIDATION TESTS FAILED"
    exit 1
}

display as result "RESULT: ALL `pass_count' EXTERNAL CROSS-VALIDATION TESTS PASSED"
clear
