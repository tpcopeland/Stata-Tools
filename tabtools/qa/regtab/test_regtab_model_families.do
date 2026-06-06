*! test_regtab_model_families.do - QA for regtab regression-family coverage
*! Focuses on multi-equation mlogit output plus a broad estimator smoke matrix.

clear all
set more off
version 17.0
set seed 20260531

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/regtab$") {
    local pkg_root = regexr("`_cwd'", "/qa/regtab$", "")
    local qa_dir = regexr("`_cwd'", "/regtab$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
    local qa_dir "`_cwd'"
}
else {
    local pkg_root "`_cwd'"
    local qa_dir "`pkg_root'/qa"
}

local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _rt_fam
log using "`output_dir'/test_regtab_model_families.log", replace text name(_rt_fam)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace
discard

local pass = 0
local fail = 0
local total = 0

capture program drop _rt_build_multiclass
program define _rt_build_multiclass
    version 17.0
    clear
    set obs 900
    gen double age_z = rnormal()
    gen double biomarker = rnormal()
    gen double xb2 = -0.25 + 0.70 * age_z - 0.25 * biomarker
    gen double xb3 =  0.30 - 0.35 * age_z + 0.65 * biomarker
    gen double denom = 1 + exp(xb2) + exp(xb3)
    gen double p1 = 1 / denom
    gen double p2 = exp(xb2) / denom
    gen double u = runiform()
    gen byte response = 1
    replace response = 2 if u > p1 & u <= p1 + p2
    replace response = 3 if u > p1 + p2
    label define response_lbl 1 "No response" 2 "Partial response" 3 "Complete response"
    label values response response_lbl
    label variable age_z "Age z-score"
    label variable biomarker "Biomarker level"
end

capture program drop _rt_build_zero_count
program define _rt_build_zero_count
    version 17.0
    clear
    set obs 1200
    gen double exposure_score = rnormal()
    gen double inflation_score = rnormal()
    gen double mu = exp(0.35 + 0.45 * exposure_score)
    gen byte structural_zero = runiform() < invlogit(-0.8 + 0.8 * inflation_score)
    gen byte event_count = cond(structural_zero, 0, rpoisson(mu))
    label variable event_count "Event count"
    label variable exposure_score "Exposure score"
    label variable inflation_score "Zero-inflation score"
end

capture program drop _rt_build_hurdle
program define _rt_build_hurdle
    version 17.0
    clear
    set obs 1200
    gen double dose_intensity = rnormal()
    gen double participation_score = rnormal()
    gen byte positive = runiform() < invlogit(-0.3 + 0.7 * participation_score)
    gen double annual_cost = cond(positive, ///
        exp(1 + 0.4 * dose_intensity + rnormal() * 0.5), 0)
    label variable annual_cost "Annual cost"
    label variable dose_intensity "Dose intensity"
    label variable participation_score "Participation score"
end

**# Test 1: mlogit rows preserve outcome equations and use RRR scale
local ++total
capture noisily {
    _rt_build_multiclass
    collect clear
    collect: mlogit response age_z biomarker, baseoutcome(1)

    capture frame drop _rt_fam_mlogit
    regtab, frame(_rt_fam_mlogit, replace) stats(n ll aic bic r2)

    assert r(N_models) == 1
    assert "`r(coef_label)'" == "RRR"

    local partial_age = 0
    local complete_age = 0
    local partial_bio = 0
    local complete_bio = 0
    local bad_duplicate_age = 0
    frame _rt_fam_mlogit {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if "`row'" == "Age z-score" local bad_duplicate_age = 1
            if strpos("`row'", "Partial response") > 0 & strpos("`row'", "Age z-score") > 0 local partial_age = 1
            if strpos("`row'", "Complete response") > 0 & strpos("`row'", "Age z-score") > 0 local complete_age = 1
            if strpos("`row'", "Partial response") > 0 & strpos("`row'", "Biomarker level") > 0 local partial_bio = 1
            if strpos("`row'", "Complete response") > 0 & strpos("`row'", "Biomarker level") > 0 local complete_bio = 1
        }
    }
    assert `partial_age' == 1
    assert `complete_age' == 1
    assert `partial_bio' == 1
    assert `complete_bio' == 1
    assert `bad_duplicate_age' == 0
}
if _rc == 0 {
    display as result "  PASS: Test 1 - mlogit outcome-specific rows and RRR scale"
    local ++pass
}
else {
    display as error "  FAIL: Test 1 - mlogit row/scale contract (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_fam_mlogit

**# Test 2: mlogit keepintercept keeps outcome-specific constants
local ++total
capture noisily {
    _rt_build_multiclass
    collect clear
    collect: mlogit response age_z biomarker, baseoutcome(1)

    capture frame drop _rt_fam_mlogit_cons
    regtab, frame(_rt_fam_mlogit_cons, replace) keepintercept

    local partial_cons = 0
    local complete_cons = 0
    frame _rt_fam_mlogit_cons {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if strpos("`row'", "Partial response") > 0 & strpos("`row'", "Intercept") > 0 local partial_cons = 1
            if strpos("`row'", "Complete response") > 0 & strpos("`row'", "Intercept") > 0 local complete_cons = 1
        }
    }
    assert `partial_cons' == 1
    assert `complete_cons' == 1
}
if _rc == 0 {
    display as result "  PASS: Test 2 - mlogit keepintercept labels constants by outcome"
    local ++pass
}
else {
    display as error "  FAIL: Test 2 - mlogit keepintercept contract (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_fam_mlogit_cons

**# Test 3: representative estimator families render nonempty regtab frames
local ++total
capture noisily {
    _rt_build_multiclass
    collect clear
    collect: mlogit response age_z biomarker, baseoutcome(1) rrr

    tempname b_mlogit_rrr
    matrix `b_mlogit_rrr' = e(b)
    local cn_mlogit_rrr : colfullnames `b_mlogit_rrr'
    local ref_rrr = .
    local cpos = 0
    foreach cname of local cn_mlogit_rrr {
        local ++cpos
        if strpos("`cname'", ":age_z") > 0 & `ref_rrr' >= . {
            local ref_rrr = exp(`b_mlogit_rrr'[1, `cpos'])
        }
    }
    assert `ref_rrr' < .

    capture frame drop _rt_fam_mlogit_rrr
    regtab, frame(_rt_fam_mlogit_rrr, replace)

    local got_rrr = .
    frame _rt_fam_mlogit_rrr {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if strpos("`row'", "Partial response") > 0 & strpos("`row'", "Age z-score") > 0 {
                local got_rrr = real(strtrim(c1[`i']))
                continue, break
            }
        }
    }
    assert `got_rrr' < .
    assert abs(`got_rrr' - `ref_rrr') < 0.011
}
if _rc == 0 {
    display as result "  PASS: Test 3 - mlogit rrr option preserves RRR scale"
    local ++pass
}
else {
    display as error "  FAIL: Test 3 - mlogit rrr scale contract (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_fam_mlogit_rrr

**# Test 4: zero-inflated and hurdle equations do not collapse
local ++total
capture noisily {
    _rt_build_zero_count
    collect clear
    collect: zip event_count exposure_score, inflate(inflation_score)

    capture frame drop _rt_fam_zip
    regtab, frame(_rt_fam_zip, replace) keepintercept

    local zip_count_x = 0
    local zip_inflate_z = 0
    local zip_count_cons = 0
    local zip_inflate_cons = 0
    local zip_plain_cons = 0
    frame _rt_fam_zip {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if "`row'" == "Event count: Exposure score" local zip_count_x = 1
            if "`row'" == "Inflation equation: Zero-inflation score" local zip_inflate_z = 1
            if "`row'" == "Event count: Intercept" local zip_count_cons = 1
            if "`row'" == "Inflation equation: Intercept" local zip_inflate_cons = 1
            if "`row'" == "Intercept" local zip_plain_cons = 1
        }
    }
    assert `zip_count_x' == 1
    assert `zip_inflate_z' == 1
    assert `zip_count_cons' == 1
    assert `zip_inflate_cons' == 1
    assert `zip_plain_cons' == 0
    frame drop _rt_fam_zip

    _rt_build_zero_count
    collect clear
    collect: zinb event_count exposure_score, inflate(inflation_score)

    capture frame drop _rt_fam_zinb
    regtab, frame(_rt_fam_zinb, replace) keepintercept

    local zinb_count_x = 0
    local zinb_inflate_z = 0
    local zinb_alpha = 0
    frame _rt_fam_zinb {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if "`row'" == "Event count: Exposure score" local zinb_count_x = 1
            if "`row'" == "Inflation equation: Zero-inflation score" local zinb_inflate_z = 1
            if strpos("`row'", "Ancillary: alpha") > 0 local zinb_alpha = 1
        }
    }
    assert `zinb_count_x' == 1
    assert `zinb_inflate_z' == 1
    assert `zinb_alpha' == 1
    frame drop _rt_fam_zinb

    _rt_build_hurdle
    collect clear
    collect: churdle linear annual_cost dose_intensity, ///
        select(participation_score) ll(0)

    capture frame drop _rt_fam_churdle
    regtab, frame(_rt_fam_churdle, replace) keepintercept

    local hurd_outcome_x = 0
    local hurd_selection_z = 0
    local hurd_scale = 0
    local hurd_sigma = 0
    frame _rt_fam_churdle {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if "`row'" == "Annual cost: Dose intensity" local hurd_outcome_x = 1
            if "`row'" == "Selection equation: Participation score" local hurd_selection_z = 1
            if "`row'" == "Scale: Intercept" local hurd_scale = 1
            if "`row'" == "Ancillary: /sigma" local hurd_sigma = 1
        }
    }
    assert `hurd_outcome_x' == 1
    assert `hurd_selection_z' == 1
    assert `hurd_scale' == 1
    assert `hurd_sigma' == 1
    frame drop _rt_fam_churdle
}
if _rc == 0 {
    display as result "  PASS: Test 4 - zero-inflated and hurdle equation labels"
    local ++pass
}
else {
    display as error "  FAIL: Test 4 - zero-inflated/hurdle row contract (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_fam_zip
capture frame drop _rt_fam_zinb
capture frame drop _rt_fam_churdle

**# Test 5: noint hides cutpoints/ancillary rows; cutlabels relabels all cuts
local ++total
capture noisily {
    sysuse auto, clear
    keep if !missing(rep78)
    xtile price4 = price, nq(4)
    label define price4 1 "Low" 2 "Moderate" 3 "High" 4 "Very high", replace
    label values price4 price4
    label variable price4 "Price quartile"

    collect clear
    collect: ologit price4 mpg weight

    capture frame drop _rt_fam_ologit_default
    regtab, frame(_rt_fam_ologit_default, replace)

    local default_cut = 0
    frame _rt_fam_ologit_default {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if regexm(strlower("`row'"), "cut[0-9]+") local default_cut = 1
        }
    }
    assert `default_cut' == 0
    frame drop _rt_fam_ologit_default

    capture frame drop _rt_fam_ologit_cuts
    regtab, frame(_rt_fam_ologit_cuts, replace) keepintercept ///
        cutlabels("Low to Moderate \ Moderate to High \ High to Very high")

    local cut1_label = 0
    local cut2_label = 0
    local cut3_label = 0
    local raw_cut = 0
    frame _rt_fam_ologit_cuts {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if "`row'" == "Low to Moderate" local cut1_label = 1
            if "`row'" == "Moderate to High" local cut2_label = 1
            if "`row'" == "High to Very high" local cut3_label = 1
            if regexm(strlower("`row'"), "^/?cut[0-9]+$") local raw_cut = 1
        }
    }
    assert `cut1_label' == 1
    assert `cut2_label' == 1
    assert `cut3_label' == 1
    assert `raw_cut' == 0
    frame drop _rt_fam_ologit_cuts

    _rt_build_zero_count
    collect clear
    collect: zinb event_count exposure_score, inflate(inflation_score)

    capture frame drop _rt_fam_zinb_default
    regtab, frame(_rt_fam_zinb_default, replace)

    local zinb_ancillary = 0
    frame _rt_fam_zinb_default {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if strpos(strlower("`row'"), "alpha") > 0 local zinb_ancillary = 1
            if strpos(strlower("`row'"), "intercept") > 0 local zinb_ancillary = 1
        }
    }
    assert `zinb_ancillary' == 0
    frame drop _rt_fam_zinb_default

    _rt_build_hurdle
    collect clear
    collect: churdle linear annual_cost dose_intensity, ///
        select(participation_score) ll(0)

    capture frame drop _rt_fam_churdle_default
    regtab, frame(_rt_fam_churdle_default, replace)

    local hurdle_ancillary = 0
    frame _rt_fam_churdle_default {
        forvalues i = 4/`=_N' {
            local row = strtrim(A[`i'])
            if strpos(strlower("`row'"), "ancillary") > 0 local hurdle_ancillary = 1
            if strpos(strlower("`row'"), "scale") > 0 local hurdle_ancillary = 1
            if strpos(strlower("`row'"), "intercept") > 0 local hurdle_ancillary = 1
        }
    }
    assert `hurdle_ancillary' == 0
    frame drop _rt_fam_churdle_default
}
if _rc == 0 {
    display as result "  PASS: Test 5 - cutlabels and ancillary hiding contract"
    local ++pass
}
else {
    display as error "  FAIL: Test 5 - cut/ancillary row contract (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_fam_ologit_default
capture frame drop _rt_fam_ologit_cuts
capture frame drop _rt_fam_zinb_default
capture frame drop _rt_fam_churdle_default

**# Test 6: representative estimator families render nonempty regtab frames
local ++total
capture noisily {
    tempfile famdata
    sysuse auto, clear
    keep if !missing(rep78)
    xtile price3 = price, nq(3)
    gen double exposure = 1 + runiform()
    gen byte count_y = floor(rep78 + runiform() * 3)
    gen byte binary_y = foreign
    gen double gaussian_y = price / 1000
    gen byte panel_id = ceil(_n / 5)
    gen byte time_id = mod(_n - 1, 5) + 1
    save "`famdata'", replace

    local family_n 0

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: regress gaussian_y mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "Coef."
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: logit binary_y mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "OR"
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: probit binary_y mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace) coef("Coef.")
    assert r(N_rows) > 3
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: ologit price3 mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "OR"
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: poisson count_y mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "IRR"
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: nbreg count_y mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "IRR"
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: glm count_y mpg weight, family(poisson) link(log)
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "IRR"
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    xtset panel_id time_id
    collect clear
    collect: xtreg gaussian_y mpg weight, re
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace) coef("Coef.") noreeffects
    assert r(N_rows) > 3
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    stset exposure, failure(binary_y)
    collect clear
    collect: stcox mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace)
    assert r(N_rows) > 3
    assert "`r(coef_label)'" == "HR"
    frame drop _rt_fam_`family_n'

    local ++family_n
    use "`famdata'", clear
    collect clear
    collect: qreg gaussian_y mpg weight
    capture frame drop _rt_fam_`family_n'
    regtab, frame(_rt_fam_`family_n', replace) coef("Coef.")
    assert r(N_rows) > 3
    frame drop _rt_fam_`family_n'
}
if _rc == 0 {
    display as result "  PASS: Test 6 - representative estimator family smoke matrix"
    local ++pass
}
else {
    display as error "  FAIL: Test 6 - estimator family smoke matrix (rc=`=_rc')"
    local ++fail
}

**# Test 7: logit/ologit respect a user-supplied or option (no double-exp)
* Regression guard for the v1.5.1 fix: the logit/ologit branch hardcoded
* model_eform=1, so `logit, or` (whose r(table) already holds odds ratios)
* was exponentiated a second time, silently reporting exp(OR). The estimate
* is read from the eplot companion frame so this also covers bridge propagation.
local ++total
capture noisily {
    sysuse auto, clear

    * Ground-truth OR from e(b): logit coefficients are log-odds regardless of or
    quietly logit foreign mpg weight
    local _truth_mpg = exp(_b[mpg])

    * Path A: plain logit -> regtab applies eform itself
    collect clear
    collect: logit foreign mpg weight
    capture frame drop _rt_or_plain_ep
    regtab, frame(_rt_or_plain, replace) eplotframe(_rt_or_plain_ep, replace) coef("OR")
    frame _rt_or_plain_ep {
        quietly count if strpos(label, "Mileage") > 0
        assert r(N) == 1
        quietly summarize estimate if strpos(label, "Mileage") > 0, meanonly
        local _plain_mpg = r(mean)
    }

    * Path B: logit, or -> regtab must NOT re-exponentiate
    collect clear
    collect: logit foreign mpg weight, or
    capture frame drop _rt_or_eform_ep
    regtab, frame(_rt_or_eform, replace) eplotframe(_rt_or_eform_ep, replace) coef("OR")
    frame _rt_or_eform_ep {
        quietly summarize estimate if strpos(label, "Mileage") > 0, meanonly
        local _eform_mpg = r(mean)
    }

    assert abs(`_plain_mpg' - `_truth_mpg') < 1e-6
    assert abs(`_eform_mpg' - `_truth_mpg') < 1e-6
    assert abs(`_eform_mpg' - `_plain_mpg') < 1e-9

    * ologit, or must likewise single-exponentiate
    quietly ologit rep78 mpg weight
    local _truth_o_mpg = exp(_b[mpg])
    collect clear
    collect: ologit rep78 mpg weight, or
    capture frame drop _rt_or_ologit_ep
    regtab, frame(_rt_or_ologit, replace) eplotframe(_rt_or_ologit_ep, replace) coef("OR")
    frame _rt_or_ologit_ep {
        quietly summarize estimate if strpos(label, "Mileage") > 0, meanonly
        local _ologit_mpg = r(mean)
    }
    assert abs(`_ologit_mpg' - `_truth_o_mpg') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: Test 7 - logit/ologit or option single-exponentiates"
    local ++pass
}
else {
    display as error "  FAIL: Test 7 - logit/ologit or double-exp regression (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_or_plain _rt_or_plain_ep _rt_or_eform _rt_or_eform_ep
capture frame drop _rt_or_ologit _rt_or_ologit_ep

display as result "Results: `pass'/`total' passed, `fail' failed"
if `fail' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab_model_families tests=`total' pass=`pass' fail=`fail'"
    capture log close _rt_fam
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_regtab_model_families tests=`total' pass=`pass' fail=`fail'"
capture log close _rt_fam
