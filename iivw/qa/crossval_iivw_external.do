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
    dietox dietox_weight_coefs dietox_geeglm dietox_geeglm_pen ///
    dietox_geeglm_logit {
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
        local r_se_rx2 = se_rx2[1]
        local r_se_number = se_number[1]
        local r_se_size = se_size[1]
        restore

        assert abs(_b[rx2] - `r_rx2') < 1e-6
        assert abs(_b[number] - `r_number') < 1e-6
        assert abs(_b[size] - `r_size') < 1e-6
        assert abs(_se[rx2] - `r_se_rx2') < 1e-6
        assert abs(_se[number] - `r_se_number') < 1e-6
        assert abs(_se[size] - `r_se_size') < 1e-6

        iivw_weight, id(id) time(time) ///
            visit_cov(rx2 number size) efron nolog

        * Package normalizes _iivw_iw to mean 1; align R's weights to mean 1 too
        quietly summarize r_iivw if !missing(r_iivw), meanonly
        quietly replace r_iivw = r_iivw / r(mean)
        gen double diff_iw = abs(_iivw_iw - r_iivw)
        quietly summarize diff_iw, detail
        local max_diff = r(max)
        local mean_diff = r(mean)

        display as text "  bladder2 Cox SE diffs:"
        display as text "    rx2    " %12.9f (_se[rx2] - `r_se_rx2')
        display as text "    number " %12.9f (_se[number] - `r_se_number')
        display as text "    size   " %12.9f (_se[size] - `r_se_size')
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
        local r_se_cons = se_intercept[1]
        local r_se_age = se_age[1]
        local r_se_educ = se_educ[1]
        local r_se_black = se_black[1]
        local r_se_hispan = se_hispan[1]
        local r_se_married = se_married[1]
        local r_se_nodegree = se_nodegree[1]
        local r_se_re74 = se_re74[1]
        local r_se_re75 = se_re75[1]
        local r_se_num_cons = se_numerator_intercept[1]
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
        assert abs(_se[_cons] - `r_se_cons') / `r_se_cons' < 1e-4
        assert abs(_se[age] - `r_se_age') / `r_se_age' < 1e-4
        assert abs(_se[educ] - `r_se_educ') / `r_se_educ' < 1e-4
        assert abs(_se[black] - `r_se_black') / `r_se_black' < 1e-4
        assert abs(_se[hispan] - `r_se_hispan') / `r_se_hispan' < 1e-4
        assert abs(_se[married] - `r_se_married') / `r_se_married' < 1e-4
        assert abs(_se[nodegree] - `r_se_nodegree') / `r_se_nodegree' < 1e-4
        assert abs(_se[re74] - `r_se_re74') / `r_se_re74' < 1e-4
        assert abs(_se[re75] - `r_se_re75') / `r_se_re75' < 1e-4

        quietly summarize treat
        local s_num_cons = logit(r(mean))
        assert abs(`s_num_cons' - `r_num_cons') < 1e-10
        quietly logit treat, nolog
        assert abs(_se[_cons] - `r_se_num_cons') / `r_se_num_cons' < 1e-4

        iivw_weight, id(id) time(time) ///
            treat(treat) ///
            treat_cov(age educ black hispan married nodegree re74 re75) ///
            wtype(iptw) nolog

        gen double diff_tw = abs(_iivw_tw - r_iptw)
        quietly summarize diff_tw, detail
        local max_diff = r(max)
        local mean_diff = r(mean)

        display as text "  Lalonde logit SE diffs:"
        display as text "    numerator _cons rel diff  " ///
            %12.9f abs(_se[_cons] - `r_se_num_cons') / `r_se_num_cons'
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

        stset time, enter(time time_lag) failure(event_one) ///
            id(id) exit(time .)
        stcox cu_high, nohr efron nolog
        local s_num_cu_high = _b[cu_high]

        stcox cu_high startwt evit100 evit200, nohr efron nolog
        local s_den_cu_high = _b[cu_high]
        local s_den_startwt = _b[startwt]
        local s_den_evit100 = _b[evit100]
        local s_den_evit200 = _b[evit200]

        preserve
        bysort id (time): keep if _n == 1
        logit cu_high startwt evit100 evit200, nolog
        local s_ps_cons = _b[_cons]
        local s_ps_startwt = _b[startwt]
        local s_ps_evit100 = _b[evit100]
        local s_ps_evit200 = _b[evit200]
        quietly summarize cu_high
        local s_pr_treat = r(mean)
        restore

        preserve
        import delimited "`qa_dir'/crossval_iivw_external_dietox_weight_coefs.csv", ///
            clear asdouble
        local r_num_cu_high = num_cu_high[1]
        local r_den_cu_high = den_cu_high[1]
        local r_den_startwt = den_startwt[1]
        local r_den_evit100 = den_evit100[1]
        local r_den_evit200 = den_evit200[1]
        local r_ps_cons = ps_intercept[1]
        local r_ps_startwt = ps_startwt[1]
        local r_ps_evit100 = ps_evit100[1]
        local r_ps_evit200 = ps_evit200[1]
        local r_pr_treat = pr_treat[1]
        restore

        assert abs(`s_num_cu_high' - `r_num_cu_high') < 1e-7
        assert abs(`s_den_cu_high' - `r_den_cu_high') < 1e-7
        assert abs(`s_den_startwt' - `r_den_startwt') < 1e-7
        assert abs(`s_den_evit100' - `r_den_evit100') < 1e-7
        assert abs(`s_den_evit200' - `r_den_evit200') < 1e-7
        assert abs(`s_ps_cons' - `r_ps_cons') < 1e-7
        assert abs(`s_ps_startwt' - `r_ps_startwt') < 1e-7
        assert abs(`s_ps_evit100' - `r_ps_evit100') < 1e-7
        assert abs(`s_ps_evit200' - `r_ps_evit200') < 1e-7
        assert abs(`s_pr_treat' - `r_pr_treat') < 1e-12

        iivw_weight, id(id) time(time) ///
            visit_cov(cu_high startwt evit100 evit200) ///
            stabcov(cu_high) ///
            treat(cu_high) treat_cov(startwt evit100 evit200) ///
            efron nolog

        * Package normalizes the IIW component to mean 1; align R's IIW and
        * FIPTIW weights to mean 1 too (IPTW is unchanged by the normalization,
        * and the product identity below holds on either scale).
        quietly summarize r_iiw if !missing(r_iiw), meanonly
        quietly replace r_iiw = r_iiw / r(mean)
        tempvar s_fiptiw
        quietly summarize _iivw_weight if !missing(_iivw_weight), meanonly
        gen double `s_fiptiw' = _iivw_weight / r(mean)
        quietly summarize r_fiptiw if !missing(r_fiptiw), meanonly
        quietly replace r_fiptiw = r_fiptiw / r(mean)
        gen double diff_iiw = abs(_iivw_iw - r_iiw)
        gen double diff_iptw = abs(_iivw_tw - r_iptw)
        gen double diff_fiptiw = abs(`s_fiptiw' - r_fiptiw)
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
        local r_se_cons = se_intercept[1]
        local r_se_cu_high = se_cu_high[1]
        local r_se_feed0 = se_feed0[1]
        local r_se_time = se_time[1]
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

        display as text "  Dietox GEE robust SE relative differences:"
        display as text "    _cons   " %12.9f abs(_se[_cons] - `r_se_cons') / `r_se_cons'
        display as text "    cu_high " %12.9f abs(_se[cu_high] - `r_se_cu_high') / `r_se_cu_high'
        display as text "    feed0   " %12.9f abs(_se[feed0] - `r_se_feed0') / `r_se_feed0'
        display as text "    time    " %12.9f abs(_se[time] - `r_se_time') / `r_se_time'

        assert abs(_se[_cons] - `r_se_cons') / `r_se_cons' < 0.05
        assert abs(_se[cu_high] - `r_se_cu_high') / `r_se_cu_high' < 0.05
        assert abs(_se[feed0] - `r_se_feed0') / `r_se_feed0' < 0.05
        assert abs(_se[time] - `r_se_time') / `r_se_time' < 0.05
    }
    if _rc == 0 {
        display as result "  PASS: XV3 - FIPTIW weights plus GEE coefficients/SEs match Dietox references"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV3 - FIPTIW/Dietox comparison (error `=_rc')"
        local ++fail_count
    }
}

**# XV4: Outcome SE option paths match R alternatives

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        import delimited "`qa_dir'/crossval_iivw_external_dietox.csv", ///
            clear asdouble

        iivw_weight, id(id) time(time) ///
            visit_cov(cu_high startwt evit100 evit200) ///
            stabcov(cu_high) ///
            treat(cu_high) treat_cov(startwt evit100 evit200) ///
            efron nolog

        iivw_fit weight cu_high feed0, timespec(linear) ///
            cluster(pen) level(90) geeopts(iterate(60)) nolog

        local s_cons = _b[_cons]
        local s_cu_high = _b[cu_high]
        local s_feed0 = _b[feed0]
        local s_time = _b[time]
        local s_se_cons = _se[_cons]
        local s_se_cu_high = _se[cu_high]
        local s_se_feed0 = _se[feed0]
        local s_se_time = _se[time]
        assert "`e(iivw_cluster)'" == "pen"

        preserve
        import delimited "`qa_dir'/crossval_iivw_external_dietox_geeglm_pen.csv", ///
            clear asdouble
        local r_cons = intercept[1]
        local r_cu_high = cu_high[1]
        local r_feed0 = feed0[1]
        local r_time = time[1]
        local r_se_cons = se_intercept[1]
        local r_se_cu_high = se_cu_high[1]
        local r_se_feed0 = se_feed0[1]
        local r_se_time = se_time[1]
        restore

        assert abs(`s_cons' - `r_cons') < 1e-6
        assert abs(`s_cu_high' - `r_cu_high') < 1e-6
        assert abs(`s_feed0' - `r_feed0') < 1e-6
        assert abs(`s_time' - `r_time') < 1e-6

        display as text "  Dietox GEE cluster(pen) SE relative differences:"
        display as text "    _cons   " %12.9f abs(`s_se_cons' - `r_se_cons') / `r_se_cons'
        display as text "    cu_high " %12.9f abs(`s_se_cu_high' - `r_se_cu_high') / `r_se_cu_high'
        display as text "    feed0   " %12.9f abs(`s_se_feed0' - `r_se_feed0') / `r_se_feed0'
        display as text "    time    " %12.9f abs(`s_se_time' - `r_se_time') / `r_se_time'

        assert abs(`s_se_cons' - `r_se_cons') / `r_se_cons' < 0.10
        assert abs(`s_se_cu_high' - `r_se_cu_high') / `r_se_cu_high' < 0.10
        assert abs(`s_se_feed0' - `r_se_feed0') / `r_se_feed0' < 0.10
        assert abs(`s_se_time' - `r_se_time') / `r_se_time' < 0.10

        iivw_fit heavy cu_high feed0, timespec(linear) ///
            family(binomial) link(logit) nolog replace

        local s_cons = _b[_cons]
        local s_cu_high = _b[cu_high]
        local s_feed0 = _b[feed0]
        local s_time = _b[time]
        local s_se_cons = _se[_cons]
        local s_se_cu_high = _se[cu_high]
        local s_se_feed0 = _se[feed0]
        local s_se_time = _se[time]

        preserve
        import delimited "`qa_dir'/crossval_iivw_external_dietox_geeglm_logit.csv", ///
            clear asdouble
        local r_cons = intercept[1]
        local r_cu_high = cu_high[1]
        local r_feed0 = feed0[1]
        local r_time = time[1]
        local r_se_cons = se_intercept[1]
        local r_se_cu_high = se_cu_high[1]
        local r_se_feed0 = se_feed0[1]
        local r_se_time = se_time[1]
        restore

        assert abs(`s_cons' - `r_cons') < 1e-5
        assert abs(`s_cu_high' - `r_cu_high') < 1e-5
        assert abs(`s_feed0' - `r_feed0') < 1e-5
        assert abs(`s_time' - `r_time') < 1e-5

        display as text "  Dietox binomial-logit robust SE relative differences:"
        display as text "    _cons   " %12.9f abs(`s_se_cons' - `r_se_cons') / `r_se_cons'
        display as text "    cu_high " %12.9f abs(`s_se_cu_high' - `r_se_cu_high') / `r_se_cu_high'
        display as text "    feed0   " %12.9f abs(`s_se_feed0' - `r_se_feed0') / `r_se_feed0'
        display as text "    time    " %12.9f abs(`s_se_time' - `r_se_time') / `r_se_time'

        assert abs(`s_se_cons' - `r_se_cons') / `r_se_cons' < 0.10
        assert abs(`s_se_cu_high' - `r_se_cu_high') / `r_se_cu_high' < 0.10
        assert abs(`s_se_feed0' - `r_se_feed0') / `r_se_feed0' < 0.10
        assert abs(`s_se_time' - `r_se_time') / `r_se_time' < 0.10
    }
    if _rc == 0 {
        display as result "  PASS: XV4 - alternative SE option paths comparable with R"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV4 - alternative SE option comparison (error `=_rc')"
        local ++fail_count
    }
}

**# Summary

display as text ""
display as result "External Cross-Validation: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "  XV1: IIW vs survival::coxph bladder2"
display as text "  XV2: IPTW vs ipw::ipwpoint Lalonde"
display as text "  XV3: FIPTIW/outcome vs survival::coxph + geepack::geeglm Dietox"
display as text "  XV4: cluster(), level(), family()/link() SE option paths vs geeglm"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' EXTERNAL CROSS-VALIDATION TESTS FAILED"
    exit 1
}

display as result "RESULT: ALL `pass_count' EXTERNAL CROSS-VALIDATION TESTS PASSED"
clear
