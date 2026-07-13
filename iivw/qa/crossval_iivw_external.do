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
* Q5: a bad selector must be an error, not a silent zero-test pass.
* `do this.do 999' used to execute nothing and print "ALL TESTS PASSED".
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

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

* Sandbox PLUS/PERSONAL before installing: this suite is also spawned as a
* nested stata-mp by test_iivw_v200_qagate, and a child process does not inherit
* the parent's `sysdir set'. Without this, that nested run would net install
* into the user's real ado tree.
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap, pkgdir("`pkg_dir'")

**# R reference generation (fresh, sentinel-gated)
*
* Stata's `shell' NEVER propagates the child's exit status: _rc is 0 even when
* Rscript is missing or halts. The previous version of this file trusted _rc and
* then merely confirmed that the *tracked* CSVs existed -- which they always do.
* The retained crossval_iivw_external.log records the consequence: R died at
* line 99 with "there is no package called 'cobalt'", and the suite still
* reported "ALL 4 EXTERNAL CROSS-VALIDATION TESTS PASSED" at line 1332, from
* stale files. The gate certified a package it never tested.
*
* The contract now: preflight every R package the generator needs; regenerate
* every reference into a FRESH temporary directory; require a success sentinel
* that the shell can only create after Rscript exits 0; require the complete
* fresh output set; and compare Stata against those fresh files. A stale tracked
* CSV can no longer stand in for a reference that was never produced.

local rscript "`qa_dir'/crossval_iivw_external_refs.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R generator: `rscript'"
    exit 601
}

* Fresh output directory: nothing here predates this run.
tempfile _tstub
local ref_dir "`_tstub'_refs"
capture mkdir "`ref_dir'"
capture confirm file "`ref_dir'"
if _rc {
    display as error "could not create a temporary reference directory: `ref_dir'"
    exit 603
}

* --- Preflight: Rscript itself, then every package the generator loads --------
* The old dependency message named IrregLong/geepack/survival/nlme and omitted
* ipw and cobalt -- the two that actually broke the lane.
local rdeps survival ipw cobalt geepack
local rpre_ok "`ref_dir'/.preflight_ok"
capture erase "`rpre_ok'"
local rcheck "if (all(sapply(c('survival','ipw','cobalt','geepack'), requireNamespace, quietly=TRUE))) quit(status=0) else quit(status=1)"
shell Rscript -e "`rcheck'" > /dev/null 2>&1 && touch "`rpre_ok'"
capture confirm file "`rpre_ok'"
if _rc {
    display as error "R preflight failed"
    display as error "  crossval_iivw_external requires Rscript on PATH and these R packages:"
    display as error "    `rdeps'"
    display as error "  Install them with:"
    display as error `"    install.packages(c("survival","ipw","cobalt","geepack"))"'
    display as error "  Refusing to continue: without a live R oracle this lane would be"
    display as error "  comparing iivw against nothing."
    exit 198
}
capture erase "`rpre_ok'"

* --- Generate: sentinel only exists if Rscript exited 0 -----------------------
local rok "`ref_dir'/.generated_ok"
capture erase "`rok'"
shell Rscript "`rscript'" --outdir="`ref_dir'" && touch "`rok'"
capture confirm file "`rok'"
if _rc {
    display as error "R reference generation did not run to completion"
    display as error "  Rscript exited nonzero (Stata cannot see the child's status directly,"
    display as error "  so this is detected via a success sentinel)."
    display as error "  Refusing to continue rather than validating against stale references."
    exit 198
}
capture erase "`rok'"

* --- Require the COMPLETE fresh output set -----------------------------------
* Existence alone is not enough: each file must be new and nonempty. Every one
* of these was written by the run we just gated, in a directory that was empty
* moments ago, so existence here does mean freshness.
local ref_files bladder bladder_coefs lalonde lalonde_coefs ///
    dietox dietox_weight_coefs dietox_geeglm dietox_geeglm_pen ///
    dietox_geeglm_logit
foreach f of local ref_files {
    capture confirm file "`ref_dir'/crossval_iivw_external_`f'.csv"
    if _rc != 0 {
        display as error "R ran but did not write reference: crossval_iivw_external_`f'.csv"
        display as error "  the generator's declared output set is incomplete; not proceeding"
        exit 601
    }
    preserve
    capture import delimited "`ref_dir'/crossval_iivw_external_`f'.csv", clear varnames(1)
    local _imp_rc = _rc
    local _imp_N = _N
    restore
    if `_imp_rc' != 0 | `_imp_N' == 0 {
        display as error "reference crossval_iivw_external_`f'.csv is unreadable or empty"
        exit 601
    }
}
display as text "R references regenerated fresh in `ref_dir' (`: word count `ref_files'' files)"

local test_count = 0
local pass_count = 0
local fail_count = 0

**# XV1: IIW weights match survival::coxph on bladder2
*
* THIS IS THE LEGACY ARM, NOT THE ORACLE. Read the `endatlastvisit
* baseline(event)' below: those are the pre-2.0.0 semantics, and the R reference
* is built to match them -- observed event rows only, event_one = 1, no
* administrative-censoring tail. Both sides therefore compute the SAME reduced
* risk set, so this test cannot detect the omission of that tail. It could not
* have caught C1, and it did not.
*
* Its job now is narrow and worth keeping: it pins the 1.x behavior so the
* 2.0.0 change is a documented, tested break rather than a drift.
*
* The authoritative parity oracle is XV4b/XV4c in crossval_iivw.do, which runs
* iivw_weight WITH a follow-up window (maxfu 384) against IrregLong and demands
* an exact match on both the coefficient and the weights.

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        import delimited "`ref_dir'/crossval_iivw_external_bladder.csv", ///
            clear asdouble

        stset time, enter(time time_lag) failure(event_one) ///
            id(id) exit(time .)
        stcox rx2 number size, nohr efron nolog

        preserve
        import delimited "`ref_dir'/crossval_iivw_external_bladder_coefs.csv", ///
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

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
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
        import delimited "`ref_dir'/crossval_iivw_external_lalonde.csv", ///
            clear asdouble

        logit treat age educ black hispan married nodegree re74 re75, nolog

        preserve
        import delimited "`ref_dir'/crossval_iivw_external_lalonde_coefs.csv", ///
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
        import delimited "`ref_dir'/crossval_iivw_external_dietox.csv", ///
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
        import delimited "`ref_dir'/crossval_iivw_external_dietox_weight_coefs.csv", ///
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

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
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
        import delimited "`ref_dir'/crossval_iivw_external_dietox_geeglm.csv", ///
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
        import delimited "`ref_dir'/crossval_iivw_external_dietox.csv", ///
            clear asdouble

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
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
        import delimited "`ref_dir'/crossval_iivw_external_dietox_geeglm_pen.csv", ///
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
        import delimited "`ref_dir'/crossval_iivw_external_dietox_geeglm_logit.csv", ///
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

display as text "  XV1: IIW vs survival::coxph bladder2"
display as text "  XV2: IPTW vs ipw::ipwpoint Lalonde"
display as text "  XV3: FIPTIW/outcome vs survival::coxph + geepack::geeglm Dietox"
display as text "  XV4: cluster(), level(), family()/link() SE option paths vs geeglm"
iivw_qa_summary, name(crossval_iivw_external) tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') runonly(`run_only')

clear
