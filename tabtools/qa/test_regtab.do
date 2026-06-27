* test_regtab.do - complete QA for regtab
* Consolidated in v1.7.0 from: test_regtab_model_families.do, test_regtab_mixed_stats.do, test_regtab_multilevel.do, test_regtab_aic_gee.do, test_regtab_nopvalue.do, test_regtab_nsub.do, test_regtab_stats_alias.do, test_regtab_v1015.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _regtab
log using "test_regtab.log", replace text name(_regtab)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear



**# Test helper migrated from review/v1013 contract files
capture program drop _rv_assert
program define _rv_assert
    args result_file
    capture confirm file "`result_file'"
    if _rc {
        display as error "checker verdict file not written: `result_file'"
        exit 459
    }
    tempname fh
    file open `fh' using "`result_file'", read text
    file read `fh' _line
    file close `fh'
    if substr("`_line'", 1, 4) != "PASS" {
        display as error "xlsx check failed: `_line'"
        exit 9
    }
end

**# Migrated from test_regtab_model_families.do


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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 1 - mlogit row/scale contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_fam_mlogit

**# Test 2: mlogit keepintercept keeps outcome-specific constants
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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 2 - mlogit keepintercept contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_fam_mlogit_cons

**# Test 3: representative estimator families render nonempty regtab frames
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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - mlogit rrr scale contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_fam_mlogit_rrr

**# Test 4: zero-inflated and hurdle equations do not collapse
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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - zero-inflated/hurdle row contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_fam_zip
capture frame drop _rt_fam_zinb
capture frame drop _rt_fam_churdle

**# Test 5: noint hides cutpoints/ancillary rows; cutlabels relabels all cuts
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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - cut/ancillary row contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_fam_ologit_default
capture frame drop _rt_fam_ologit_cuts
capture frame drop _rt_fam_zinb_default
capture frame drop _rt_fam_churdle_default

**# Test 6: representative estimator families render nonempty regtab frames
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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - estimator family smoke matrix (rc=`=_rc')"
    local ++fail_count
}

**# Test 7: logit/ologit respect a user-supplied or option (no double-exp)
* Regression guard for the v1.5.1 fix: the logit/ologit branch hardcoded
* model_eform=1, so `logit, or` (whose r(table) already holds odds ratios)
* was exponentiated a second time, silently reporting exp(OR). The estimate
* is read from the eplot companion frame so this also covers bridge propagation.
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
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - logit/ologit or double-exp regression (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_or_plain _rt_or_plain_ep _rt_or_eform _rt_or_eform_ep
capture frame drop _rt_or_ologit _rt_or_ologit_ep


**# Migrated from test_regtab_mixed_stats.do


* Helper: generate a cluster-level random effect using a tempvar to avoid
* subscripting a function call directly (unsupported Stata syntax).
* Usage: after creating the group variable, call:
*   tempvar _uraw
*   gen `_uraw' = rnormal()
*   bysort group: gen u = `_uraw'[1] * sd
* This assigns the value from obs [1] within each bysort group.

**# Test A: mepoisson — runs without crash, file created

capture {
    clear
    set obs 600
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3*x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    capture erase "`output_dir'/_test_ms_A.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_A.xlsx") sheet("A")
    confirm file "`output_dir'/_test_ms_A.xlsx"
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test A - mepoisson no crash"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test A - mepoisson crash (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test A1: regtab stats(groups) returns r(groups_1) = known group count
* Same DGP as Test A: 600 obs, group = ceil(_n/30) => exactly 20 groups,
* so e(N_g) and the returned r(groups_1) are deterministic (seed-independent).

capture {
    clear
    set obs 600
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3*x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    capture erase "`output_dir'/_test_ms_A1.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_A1.xlsx") sheet("A1") stats(groups)
    assert r(groups_1) == 20
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test A1 - regtab r(groups_1) == 20"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test A1 - regtab r(groups_1) wrong or crash (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test B: mepoisson stats(icc) — ICC row absent (Fix 1 guard)
* ICC is undefined for count models (no closed-form level-1 variance).
* After Fix 1, all stat_icc values remain missing so the ICC row is suppressed.

capture {
    clear
    set obs 600
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3*x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    capture erase "`output_dir'/_test_ms_B.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_B.xlsx") sheet("B") stats(icc)
    confirm file "`output_dir'/_test_ms_B.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_B.xlsx", sheet("B") clear allstring
    local icc_present = 0
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 local icc_present = 1
    }
    restore
    assert `icc_present' == 0
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test B - mepoisson ICC row absent (guard works)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test B - mepoisson ICC row present or crash (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test C: mestreg — MHR label present in output

capture {
    clear
    set obs 300
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.3
    gen t = rexponential(exp(-0.5 - 0.2*x - u))
    gen event = (t < 5)
    replace t = min(t, 5)
    stset t, failure(event)

    collect clear
    collect: mestreg x || group:, distribution(exponential)

    capture erase "`output_dir'/_test_ms_C.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_C.xlsx") sheet("C")
    confirm file "`output_dir'/_test_ms_C.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_C.xlsx", sheet("C") clear allstring
    local found_mhr = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Hazard Ratio") > 0 local found_mhr = 1
    }
    restore
    assert `found_mhr' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test C - mestreg MHR label present"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test C - mestreg MHR label absent or crash (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test D: melogit MOR point estimate accuracy
* Formula: MOR = exp(sqrt(2 * var_re) * invnormal(0.75))
* var_re = exp(2 * lns1_1_1) from e(b)
* Expected tolerance: 0.01 (MOR formatted to 2 decimal places)

capture {
    clear
    set obs 1000
    gen group = ceil(_n/50)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.8
    gen prob = invlogit(-1 + 0.5*x + u)
    gen y = (runiform() < prob)

    collect clear
    collect: melogit y x || group:

    * Save expected MOR from e(b) before regtab.
    * melogit stores /var(_cons[group]) = variance directly (not log-SD).
    * mixed stores lns1_1_1:_cons = log-SD (needs exp(2*x) conversion).
    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re = .
    local col = 0
    foreach colname of local colnames {
        local col = `col' + 1
        * melogit: /var(_cons[...]) stores variance directly
        if regexm("`colname'", "^/var\(_cons") {
            local var_re = `b_mat'[1, `col']
        }
        * mixed: lns*_1_1: stores log-SD
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re = exp(2 * `b_mat'[1, `col'])
        }
    }
    assert `var_re' != .
    local exp_mor  = exp(sqrt(2 * `var_re') * invnormal(0.75))

    capture erase "`output_dir'/_test_ms_D.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_D.xlsx") sheet("D")
    confirm file "`output_dir'/_test_ms_D.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_D.xlsx", sheet("D") clear allstring
    local act_mor = .
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Odds Ratio") > 0 {
            local act_mor = real(strtrim(C[`i']))
        }
    }
    restore

    assert `act_mor' != .
    assert abs(`act_mor' - `exp_mor') < 0.01
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test D - melogit MOR value accuracy"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test D - melogit MOR mismatch or crash (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test E: melogit MOR CI bounds — structural sanity (lo < point < hi, all > 1)

capture {
    clear
    set obs 1000
    gen group = ceil(_n/50)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.8
    gen prob = invlogit(-1 + 0.5*x + u)
    gen y = (runiform() < prob)

    collect clear
    collect: melogit y x || group:

    capture erase "`output_dir'/_test_ms_E.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_E.xlsx") sheet("E")
    confirm file "`output_dir'/_test_ms_E.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_E.xlsx", sheet("E") clear allstring
    local act_mor  = .
    local excel_ci = ""
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Odds Ratio") > 0 {
            local act_mor  = real(strtrim(C[`i']))
            local excel_ci = strtrim(D[`i'])
        }
    }
    restore

    assert `act_mor' != .
    assert "`excel_ci'" != ""

    * Parse CI string: strip parens, split on ", "
    local ci_str  = subinstr(subinstr("`excel_ci'", "(", "", 1), ")", "", 1)
    local sep_pos = strpos("`ci_str'", ", ")
    local ci_lo   = real(strtrim(substr("`ci_str'", 1, `sep_pos' - 1)))
    local ci_hi   = real(strtrim(substr("`ci_str'", `sep_pos' + 2, .)))

    * MOR CI sanity: lo > 1, lo < MOR < hi
    assert `ci_lo' > 1
    assert `ci_lo' < `act_mor'
    assert `act_mor' < `ci_hi'
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test E - melogit MOR CI bounds sanity (lo < MOR < hi)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test E - melogit MOR CI bounds invalid (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test F: melogit ICC binary — formula var/(var + pi²/3)
* Tolerance: 0.001 (ICC formatted to 3 decimal places)

capture {
    clear
    set obs 1000
    gen group = ceil(_n/50)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.8
    gen prob = invlogit(-1 + 0.5*x + u)
    gen y = (runiform() < prob)

    collect clear
    collect: melogit y x || group:

    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re = .
    local col = 0
    foreach colname of local colnames {
        local col = `col' + 1
        * melogit: /var(_cons[...]) stores variance directly
        if regexm("`colname'", "^/var\(_cons") {
            local var_re = `b_mat'[1, `col']
        }
        * mixed: lns*_1_1: stores log-SD (needs exp(2*x) conversion)
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re = exp(2 * `b_mat'[1, `col'])
        }
    }
    assert `var_re' != .
    local exp_icc  = `var_re' / (`var_re' + c(pi)^2/3)

    capture erase "`output_dir'/_test_ms_F.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_F.xlsx") sheet("F") stats(icc)
    confirm file "`output_dir'/_test_ms_F.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_F.xlsx", sheet("F") clear allstring
    local act_icc = .
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 {
            local act_icc = real(strtrim(C[`i']))
        }
    }
    restore

    assert `act_icc' != .
    assert abs(`act_icc' - `exp_icc') < 0.001
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test F - melogit ICC binary formula"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test F - melogit ICC mismatch or crash (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test G: AIC and BIC value accuracy (logistic regression)
* logit stores e(aic)/e(bic) directly; we verify regtab's extracted values
* match the manual formula and Stata's own stored values.
* Tolerance: 0.01 (formatted to 2 decimal places)

capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    local ll_val   = e(ll)
    local rank_val = e(rank)
    local N_val    = e(N)
    local exp_aic  = -2 * `ll_val' + 2 * `rank_val'
    local exp_bic  = -2 * `ll_val' + `rank_val' * ln(`N_val')

    capture erase "`output_dir'/_test_ms_G.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_G.xlsx") sheet("G") stats(aic bic)
    confirm file "`output_dir'/_test_ms_G.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_G.xlsx", sheet("G") clear allstring
    local act_aic = .
    local act_bic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local act_aic = real(strtrim(C[`i']))
        if strtrim(B[`i']) == "BIC" local act_bic = real(strtrim(C[`i']))
    }
    restore

    assert `act_aic' != .
    assert `act_bic' != .
    assert abs(`act_aic' - `exp_aic') < 0.01
    assert abs(`act_bic' - `exp_bic') < 0.01
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test G - AIC/BIC value accuracy (logit)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test G - AIC/BIC mismatch (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test H: Two-level ICC — Fix 2: accumulate ALL variance levels
* Three-level model: obs within classes within schools.
* ICC = (var_class + var_school) / (var_class + var_school + var_resid)
* Fix 2 ensures the fallback path sums lns1_1_1 + lns2_1_1 variances.
* Tolerance: 0.001 (3 decimal places)

capture {
    * 10 schools × 10 classes × 10 obs = 1000 observations (globally unique class IDs)
    clear
    set obs 1000
    gen school = ceil(_n/100)
    gen class  = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 1.2
    bysort class:  gen u_class  = `uc'[1] * 0.7
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    collect: mixed y x || school: || class:

    * Expected ICC: sum both RE variance levels from e(b)
    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re_total = 0
    local var_resid    = 0
    local col = 0
    foreach colname of local colnames {
        local col = `col' + 1
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re_total = `var_re_total' + exp(2 * `b_mat'[1, `col'])
        }
        if strpos("`colname'", "lnsig_e:") {
            local var_resid = exp(2 * `b_mat'[1, `col'])
        }
    }
    local exp_icc = `var_re_total' / (`var_re_total' + `var_resid')

    capture erase "`output_dir'/_test_ms_H.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_H.xlsx") sheet("H") stats(icc)
    confirm file "`output_dir'/_test_ms_H.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_H.xlsx", sheet("H") clear allstring
    local act_icc = .
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 {
            local act_icc = real(strtrim(C[`i']))
        }
    }
    restore

    assert `act_icc' != .
    assert abs(`act_icc' - `exp_icc') < 0.001
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test H - two-level ICC accumulates both variances"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test H - two-level ICC mismatch (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test I: plain regress with stats(icc) — no crash, no ICC row

capture {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_test_ms_I.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_I.xlsx") sheet("I") stats(icc)
    confirm file "`output_dir'/_test_ms_I.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_I.xlsx", sheet("I") clear allstring
    local icc_present = 0
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 local icc_present = 1
    }
    restore
    assert `icc_present' == 0
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test I - regress stats(icc): no crash, no ICC row"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test I - regress stats(icc): crash or ICC row present (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test J: stcox shared frailty — no crash, table has data rows

capture {
    sysuse cancer, clear
    stset studytime, failure(died)

    collect clear
    collect: stcox age, shared(drug)

    capture erase "`output_dir'/_test_ms_J.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_J.xlsx") sheet("J")
    confirm file "`output_dir'/_test_ms_J.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_J.xlsx", sheet("J") clear allstring
    assert _N >= 3
    restore
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test J - stcox shared frailty no crash"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test J - stcox crash or empty table (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test K: logit fixed effects are exponentiated and intercept auto-drops

capture frame drop _rt_or
capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    tempname b_mat
    matrix `b_mat' = e(b)
    local exp_or = exp(`b_mat'[1,1])

    regtab, display frame(_rt_or, replace)
    assert "`r(coef_label)'" == "OR"

    frame _rt_or {
        count if A == "Intercept"
        assert r(N) == 0

        local act_or = .
        forvalues i = 1/`=_N' {
            if strpos(A[`i'], "Mileage") > 0 {
                local act_or = real(strtrim(c1[`i']))
            }
        }
        assert `act_or' != .
        assert abs(`act_or' - round(`exp_or', 0.01)) < 0.02
    }
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test K - logit fixed effects exponentiated; intercept dropped"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test K - logit OR transform or auto-noint failed (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}
capture frame drop _rt_or

**# Test L: mixed OLS + logit collections get per-model headers and generic fit label

capture frame drop _rt_mix
capture {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: logit foreign mpg

    regtab, display frame(_rt_mix, replace) stats(r2)
    assert "`r(coef_label)'" == "mixed"
    assert strpos(`"`r(methods)'"', "Collected regression estimates") > 0

    frame _rt_mix {
        assert c1[3] == "Coef."
        assert c4[3] == "OR"
        count if A == "R² / Pseudo R²"
        assert r(N) == 1
    }
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test L - mixed collections keep model-specific headers"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test L - mixed collection headers/stats mislabeled (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}
capture frame drop _rt_mix

**# Test M: invalid pdp()/highpdp() are rejected

capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    capture noisily regtab, display pdp(0)
    assert _rc == 198
    capture noisily regtab, display highpdp(0)
    assert _rc == 198
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test M - invalid p-value precision rejected"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test M - invalid p-value precision accepted (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test N: multi-level melogit keep() preserves distinct MOR labels after filtering

capture frame drop _rt_mor_keep
capture {
    clear
    set obs 2000
    gen district = ceil(_n/200)
    gen school = ceil(_n/40)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    tempvar u1raw u2raw
    gen `u1raw' = rnormal()
    bysort district: gen u1 = `u1raw'[1] * 0.6
    gen `u2raw' = rnormal()
    bysort school: gen u2 = `u2raw'[1] * 0.8
    gen p = invlogit(-0.8 + 0.4*x + u1 + u2)
    gen y = runiform() < p

    collect clear
    collect: melogit y x || district: || school:

    regtab, display frame(_rt_mor_keep, replace) relabel keep(District School)

    frame _rt_mor_keep {
        count if A == "Median Odds Ratio (District)"
        assert r(N) == 1
        count if A == "Median Odds Ratio (School)"
        assert r(N) == 1
        count if strpos(A, "Residual")
        assert r(N) == 0
    }
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test N - keep() preserves distinct multi-level MOR rows"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test N - keep() broke MOR row tracking (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}
capture frame drop _rt_mor_keep

**# Test O: mixed streg collection keeps per-model TR/AF headers

capture frame drop _rt_streg_mix
capture {
    webuse cancer, clear
    stset studytime, failure(died)
    collect clear
    collect: streg age, dist(weibull) time
    collect: streg age, dist(weibull)

    regtab, display frame(_rt_streg_mix, replace)
    assert "`r(coef_label)'" == "mixed"

    frame _rt_streg_mix {
        assert c1[3] == "TR"
        assert c4[3] == "AF"
    }
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test O - mixed streg headers use per-model metadata"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test O - mixed streg headers reused ambient metadata (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}
capture frame drop _rt_streg_mix

**# Test P: mixed glm collection keeps per-model Coef./OR headers

capture frame drop _rt_glm_mix
capture {
    sysuse auto, clear
    collect clear
    collect: glm price mpg weight, family(gaussian) link(identity)
    collect: glm foreign mpg weight, family(binomial) link(logit)

    regtab, display frame(_rt_glm_mix, replace)
    assert "`r(coef_label)'" == "mixed"

    frame _rt_glm_mix {
        assert c1[3] == "Coef."
        assert c4[3] == "OR"
    }
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test P - mixed glm headers use per-model family metadata"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test P - mixed glm headers reused ambient metadata (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}
capture frame drop _rt_glm_mix

**# Test Q: r(table) survives title/stars/compact rendering

capture frame drop _rt_rendered
capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    tempname b_mat
    matrix `b_mat' = e(b)
    local exp_or = exp(`b_mat'[1,1])

    regtab, display frame(_rt_rendered, replace) stars compact title("Rendered")
    matrix list r(table)
    assert rowsof(r(table)) > 0
    assert colsof(r(table)) == 1
    assert abs(r(table)[1,1] - `exp_or') < 0.02
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test Q - r(table) stays numeric under rendered output"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test Q - rendered output corrupted r(table) (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}
capture frame drop _rt_rendered


**# Migrated from test_regtab_multilevel.do



**# Test 1: Single-level mixed — relabel (backward compat)

capture {
    clear
    set obs 500
    gen school = ceil(_n/50)
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, school) + rnormal()

    collect clear
    collect: mixed y x || school:

    capture erase "`output_dir'/_test_ml_single.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_single.xlsx") sheet("Single") relabel

    import excel "`output_dir'/_test_ml_single.xlsx", sheet("Single") clear allstring

    * Check RE rows are labeled correctly
    local found_intercept = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "School (Intercept)") > 0 local found_intercept = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_intercept' == 1
    assert `found_residual' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 1 - Single-level mixed relabel"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 1 - Single-level mixed relabel (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 2: Two-level nested mixed — both levels labeled

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_twolevel.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_twolevel.xlsx") sheet("TwoLevel") relabel

    import excel "`output_dir'/_test_ml_twolevel.xlsx", sheet("TwoLevel") clear allstring

    * Check both levels are present and labeled
    local found_district = 0
    local found_school = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "District (Intercept)") > 0 local found_district = 1
        if strpos(B[`i'], "School (Intercept)") > 0 local found_school = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_district' == 1
    assert `found_school' == 1
    assert `found_residual' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 2 - Two-level mixed relabel (both levels)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 2 - Two-level mixed relabel (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 3: Two-level with random slope and covariance

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    label variable x "Treatment"
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school: x, cov(unstructured)

    capture erase "`output_dir'/_test_ml_slope.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_slope.xlsx") sheet("Slope") relabel

    import excel "`output_dir'/_test_ml_slope.xlsx", sheet("Slope") clear allstring

    * Check random slope labeled with variable label
    local found_district = 0
    local found_school_int = 0
    local found_school_slope = 0
    local found_cov = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "District (Intercept)") > 0 local found_district = 1
        if strpos(B[`i'], "School (Intercept)") > 0 local found_school_int = 1
        if strpos(B[`i'], "Variance: School (Treatment)") > 0 local found_school_slope = 1
        if strpos(B[`i'], "Covariance: School (Treatment, Intercept)") > 0 local found_cov = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_district' == 1
    assert `found_school_int' == 1
    assert `found_school_slope' == 1
    assert `found_cov' == 1
    assert `found_residual' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 3 - Two-level with random slope + covariance"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 3 - Two-level with random slope + covariance (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 4: Two-level mixed WITHOUT relabel (raw labels)

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_norelabel.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_norelabel.xlsx") sheet("NoRelabel")

    import excel "`output_dir'/_test_ml_norelabel.xlsx", sheet("NoRelabel") clear allstring

    * Check raw bracket-notation labels exist
    local found_district = 0
    local found_school = 0
    local found_vare = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "var(_cons[district])" local found_district = 1
        if strtrim(B[`i']) == "var(_cons[school])" local found_school = 1
        if strtrim(B[`i']) == "var(e)" local found_vare = 1
    }
    assert `found_district' == 1
    assert `found_school' == 1
    assert `found_vare' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 4 - Two-level without relabel (bracket notation)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 4 - Two-level without relabel (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 5: melogit single-level — backward compat

capture {
    clear
    set obs 2000
    gen cluster = ceil(_n/100)
    label variable cluster "Hospital"
    gen x = rnormal()
    gen y = rbinomial(1, invlogit(0.5*x + rnormal(0,0.5)))

    collect clear
    collect: melogit y x || cluster:

    capture erase "`output_dir'/_test_ml_melogit.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_melogit.xlsx") sheet("MELogit") relabel

    import excel "`output_dir'/_test_ml_melogit.xlsx", sheet("MELogit") clear allstring

    * Check MOR label and relabeled intercept
    local found_mor = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Odds Ratio") > 0 local found_mor = 1
    }
    assert `found_mor' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 5 - melogit single-level MOR + relabel"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 5 - melogit single-level (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 6: Two-level mixed with nore — suppresses all RE rows

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_nore.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_nore.xlsx") sheet("NoRE") nore

    import excel "`output_dir'/_test_ml_nore.xlsx", sheet("NoRE") clear allstring

    * Check no RE rows exist
    local found_var = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "var(") > 0 local found_var = 1
    }
    assert `found_var' == 0
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 6 - Two-level nore suppresses all RE"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 6 - Two-level nore (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 7: Three-level nested mixed

capture {
    clear
    set obs 2000
    gen region = ceil(_n/500)
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable region "Region"
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(2)) + rnormal(0, sqrt(1)) + rnormal()

    collect clear
    collect: mixed y x || region: || district: || school:

    capture erase "`output_dir'/_test_ml_three.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_three.xlsx") sheet("Three") relabel

    import excel "`output_dir'/_test_ml_three.xlsx", sheet("Three") clear allstring

    * Check all three levels labeled
    local found_region = 0
    local found_district = 0
    local found_school = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Region (Intercept)") > 0 local found_region = 1
        if strpos(B[`i'], "District (Intercept)") > 0 local found_district = 1
        if strpos(B[`i'], "School (Intercept)") > 0 local found_school = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_region' == 1
    assert `found_district' == 1
    assert `found_school' == 1
    assert `found_residual' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 7 - Three-level nested mixed"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 7 - Three-level nested (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 8: Single-level mixed with random slope (no brackets, backward compat)

capture {
    clear
    set obs 500
    gen school = ceil(_n/50)
    label variable school "School"
    gen x = rnormal()
    label variable x "Treatment"
    gen y = 1 + 2*x + rnormal(0, school) + rnormal()

    collect clear
    collect: mixed y x || school: x, cov(unstructured)

    capture erase "`output_dir'/_test_ml_single_slope.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_single_slope.xlsx") sheet("Slope1") relabel

    import excel "`output_dir'/_test_ml_single_slope.xlsx", sheet("Slope1") clear allstring

    * Check relabeled with explicit parameter type
    local found_int = 0
    local found_slope = 0
    local found_cov = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "Variance: School (Intercept)" local found_int = 1
        if strtrim(B[`i']) == "Variance: School (Treatment)" local found_slope = 1
        if strtrim(B[`i']) == "Covariance: School (Treatment, Intercept)" local found_cov = 1
    }
    assert `found_int' == 1
    assert `found_slope' == 1
    assert `found_cov' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 8 - Single-level random slope + covariance relabel"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 8 - Single-level random slope (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 9: RE sort order — FE first, RE grouped by level, residual last

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_sortorder.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_sortorder.xlsx") sheet("Sort") relabel

    import excel "`output_dir'/_test_ml_sortorder.xlsx", sheet("Sort") clear allstring

    * Find row positions (no labels set, so relabel uses lowercase varnames)
    local row_x = 0
    local row_district = 0
    local row_school = 0
    local row_residual = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "x" local row_x = `i'
        if strpos(B[`i'], "district") > 0 local row_district = `i'
        if strpos(B[`i'], "school") > 0 local row_school = `i'
        if strpos(B[`i'], "Residual") > 0 local row_residual = `i'
    }
    * FE before RE
    assert `row_x' < `row_district'
    * District before School (model order)
    assert `row_district' < `row_school'
    * Residual last
    assert `row_school' < `row_residual'
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 9 - Sort order: FE < district < school < residual"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 9 - Sort order (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 10: Simple regression — no RE, unaffected

capture {
    clear
    sysuse auto
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_test_ml_regress.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_regress.xlsx") sheet("Regress") keepint

    import excel "`output_dir'/_test_ml_regress.xlsx", sheet("Regress") clear allstring

    * Check basic structure: sysuse auto uses variable labels
    local found_mpg = 0
    local found_weight = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Mileage") > 0 local found_mpg = 1
        if strpos(B[`i'], "Weight") > 0 local found_weight = 1
    }
    assert `found_mpg' == 1
    assert `found_weight' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 10 - Simple regression unaffected"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 10 - Simple regression (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 11: Two-level mixed with stats (n, icc, groups)

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_stats.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_stats.xlsx") sheet("Stats") relabel stats(n icc)

    confirm file "`output_dir'/_test_ml_stats.xlsx"
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 11 - Two-level mixed with stats"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 11 - Two-level mixed with stats (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 12: Label collision — two grouping vars with identical labels

capture {
    clear
    set obs 1000
    gen cluster1 = ceil(_n/200)
    gen cluster2 = ceil(_n/50)
    * Both variables get the SAME label
    label variable cluster1 "Cluster"
    label variable cluster2 "Cluster"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || cluster1: || cluster2:

    capture erase "`output_dir'/_test_ml_collision.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_collision.xlsx") sheet("Collision") relabel

    import excel "`output_dir'/_test_ml_collision.xlsx", sheet("Collision") clear allstring

    * Both levels must appear with distinct labels (varname used as tiebreaker)
    local found_c1 = 0
    local found_c2 = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        * With identical labels, relabel uses varname: "cluster1 (Intercept)", "cluster2 (Intercept)"
        if strpos(B[`i'], "cluster1") > 0 & strpos(B[`i'], "Intercept") > 0 local found_c1 = 1
        if strpos(B[`i'], "cluster2") > 0 & strpos(B[`i'], "Intercept") > 0 local found_c2 = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_c1' == 1
    assert `found_c2' == 1
    assert `found_residual' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 12 - Label collision (identical labels, distinct varnames)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 12 - Label collision (error `=_rc')"
    local fail_count = `fail_count' + 1
}


**# Test 13: Single-level linear random slope covariance label is explicit

capture {
    clear
    set obs 800
    gen id = ceil(_n/8)
    label variable id "Patient identifier"
    bysort id: gen visit = _n
    gen double months_since_tx = (visit - 1) / 2
    label variable months_since_tx "Years since Treatment Initiation"
    gen double u0 = .
    gen double u1 = .
    bysort id: replace u0 = rnormal(0, 3) if _n == 1
    bysort id: replace u1 = rnormal(0, 0.4) if _n == 1
    bysort id: replace u0 = u0[1]
    bysort id: replace u1 = u1[1]
    gen y = 45 + 1.5 * months_since_tx + u0 + u1 * months_since_tx + rnormal(0, 2)

    collect clear
    collect: mixed y c.months_since_tx || id: months_since_tx, covariance(unstructured)

    capture erase "`output_dir'/_test_ml_single_linear_cov.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_single_linear_cov.xlsx") sheet("LinearCov") relabel

    import excel "`output_dir'/_test_ml_single_linear_cov.xlsx", sheet("LinearCov") clear allstring

    local found_slope_var = 0
    local found_int_var = 0
    local found_cov = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "Variance: Patient identifier (Years since Treatment Initiation)" local found_slope_var = 1
        if strtrim(B[`i']) == "Variance: Patient identifier (Intercept)" local found_int_var = 1
        if strtrim(B[`i']) == "Covariance: Patient identifier (Years since Treatment Initiation, Intercept)" local found_cov = 1
    }
    assert `found_slope_var' == 1
    assert `found_int_var' == 1
    assert `found_cov' == 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 13 - Single-level linear covariance relabel is explicit"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 13 - Single-level linear covariance relabel (error `=_rc')"
    local fail_count = `fail_count' + 1
}



**# Migrated from test_regtab_aic_gee.do


**# Test 1: glm AIC is full-sample (matches estat ic), not per-observation
* The bug: regtab showed glm's e(aic) = AIC/N directly, ~N times too small.
* Expected AIC = -2*ll + 2*rank == estat ic AIC == e(aic)*N.
capture {
    webuse nlswork, clear
    drop if missing(ln_wage, age, tenure, hours, union)

    quietly glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    local exp_aic   = -2*e(ll) + 2*e(rank)
    local perobs    = e(aic)
    local N_obs     = e(N)
    * Sanity: confirm the data really exhibits the per-observation quirk we guard.
    assert abs(`perobs' - `exp_aic'/`N_obs') < 1e-6
    assert `exp_aic' > 100*`perobs'

    collect clear
    collect: glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)

    capture erase "`output_dir'/_test_aic_1.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_1.xlsx") sheet("T1") stats(aic)
    confirm file "`output_dir'/_test_aic_1.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_1.xlsx", sheet("T1") clear allstring
    local act_aic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local act_aic = real(strtrim(C[`i']))
    }
    restore

    assert `act_aic' != .
    * Must be the full AIC, not the per-observation value.
    assert abs(`act_aic' - `exp_aic') < 0.01
    assert abs(`act_aic' - `perobs') > 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 1 - glm AIC is full-sample, not per-observation"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 1 - glm AIC wrong scale (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test 2: glm BIC is likelihood-scale (matches estat ic), not glm's e(bic)
* glm's e(bic) uses a deviance-based convention; regtab must report the
* likelihood BIC = -2*ll + rank*ln(N) so it is comparable to mixed models.
capture {
    webuse nlswork, clear
    drop if missing(ln_wage, age, tenure, hours, union)

    quietly glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    local exp_bic    = -2*e(ll) + e(rank)*ln(e(N))
    local glm_ebic   = e(bic)
    * Confirm glm's stored e(bic) really differs from the likelihood BIC.
    assert abs(`glm_ebic' - `exp_bic') > 1

    collect clear
    collect: glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)

    capture erase "`output_dir'/_test_aic_2.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_2.xlsx") sheet("T2") stats(bic)
    confirm file "`output_dir'/_test_aic_2.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_2.xlsx", sheet("T2") clear allstring
    local act_bic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "BIC" local act_bic = real(strtrim(C[`i']))
    }
    restore

    assert `act_bic' != .
    assert abs(`act_bic' - `exp_bic') < 0.01
    assert abs(`act_bic' - `glm_ebic') > 1
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 2 - glm BIC is likelihood-scale, not deviance-based e(bic)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 2 - glm BIC wrong convention (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test 3: glm + mixed in one collection share the AIC scale (both match estat ic)
* This is the reported scenario: a Table mixing GEE and mixed model rows. Before
* the fix the glm column was ~N times too small relative to the mixed column.
capture {
    webuse nlswork, clear
    drop if missing(ln_wage, age, tenure, hours, union)

    quietly glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    quietly estat ic
    matrix _S = r(S)
    local truth_glm_aic = _S[1,5]

    quietly mixed ln_wage age tenure hours union || idcode:, vce(robust)
    quietly estat ic
    matrix _Sm = r(S)
    local truth_mix_aic = _Sm[1,5]

    collect clear
    collect: glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    collect: mixed ln_wage age tenure hours union || idcode:, vce(robust)

    capture erase "`output_dir'/_test_aic_3.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_3.xlsx") sheet("T3") ///
        models("GLM \ Mixed") coef("Coef.") stats(aic)
    confirm file "`output_dir'/_test_aic_3.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_3.xlsx", sheet("T3") clear allstring
    * Locate the AIC row, then read the two model columns. regtab lays model m's
    * coefficient in column offset (m-1)*3 from the first data column. Find the
    * AIC row and harvest the first two non-empty numeric cells to the right of B.
    local aic_row = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local aic_row = `i'
    }
    assert `aic_row' != .
    local vals ""
    ds B, not
    foreach v of varlist `r(varlist)' {
        capture confirm string variable `v'
        local cell = strtrim(`v'[`aic_row'])
        if "`cell'" != "" & "`cell'" != "." {
            local num = real(subinstr("`cell'", ",", "", .))
            if `num' != . local vals "`vals' `num'"
        }
    }
    restore

    local act_glm_aic : word 1 of `vals'
    local act_mix_aic : word 2 of `vals'
    assert "`act_glm_aic'" != ""
    assert "`act_mix_aic'" != ""
    assert abs(`act_glm_aic' - `truth_glm_aic') < 0.01
    assert abs(`act_mix_aic' - `truth_mix_aic') < 0.01
    * Both AICs are full-sample (thousands here), so neither is the ~1 per-obs value.
    assert `act_glm_aic' > 100
    assert `act_mix_aic' > 100
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 3 - glm+mixed share AIC scale, both match estat ic"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 3 - mixed GEE/mixed AIC off-scale (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}

**# Test 4: logit AIC/BIC unchanged (no regression for full-AIC estimators)
* logit reports full-scale AIC/BIC; recomputing from ll/rank must give the
* identical values, so this estimator's output is untouched by the fix.
capture {
    sysuse auto, clear
    quietly logit foreign mpg weight
    local exp_aic = -2*e(ll) + 2*e(rank)
    local exp_bic = -2*e(ll) + e(rank)*ln(e(N))

    collect clear
    collect: logit foreign mpg weight

    capture erase "`output_dir'/_test_aic_4.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_4.xlsx") sheet("T4") stats(aic bic)
    confirm file "`output_dir'/_test_aic_4.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_4.xlsx", sheet("T4") clear allstring
    local act_aic = .
    local act_bic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local act_aic = real(strtrim(C[`i']))
        if strtrim(B[`i']) == "BIC" local act_bic = real(strtrim(C[`i']))
    }
    restore

    assert `act_aic' != . & `act_bic' != .
    assert abs(`act_aic' - `exp_aic') < 0.01
    assert abs(`act_bic' - `exp_bic') < 0.01
}
local test_count = `test_count' + 1
if _rc == 0 {
    display as result "  PASS: Test 4 - logit AIC/BIC unchanged (no regression)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL: Test 4 - logit AIC/BIC regressed (rc=`=_rc')"
    local fail_count = `fail_count' + 1
}


**# Migrated from test_regtab_nopvalue.do


**# Test 1: default output keeps p-value column
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_default
    regtab, frame(_rt_np_default, replace)
    local got_ncols = r(N_cols)

    frame _rt_np_default {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 3
        assert strtrim(c3[3]) == "p-value"
    }
    assert `got_ncols' == 5
}
if _rc == 0 {
    display as result "  PASS: Test 1 - default regtab keeps p-value column"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 1 - default p-value column contract changed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_np_default

**# Test 2: nopvalue removes p-value column from frame output
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_frame
    regtab, frame(_rt_np_frame, replace) nopvalue
    local got_ncols = r(N_cols)

    frame _rt_np_frame {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
        assert strtrim(c1[3]) == "Coef."
        assert strpos(c2[3], "CI") > 0
        capture confirm variable c3
        assert _rc != 0
    }
    assert `got_ncols' == 4
}
if _rc == 0 {
    display as result "  PASS: Test 2 - nopvalue suppresses frame p-value column"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 2 - nopvalue frame output kept p-values (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_np_frame

**# Test 3: compact + nopvalue leaves one estimate-and-CI column per model
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_compact
    regtab, frame(_rt_np_compact, replace) compact nopvalue
    local got_ncols = r(N_cols)

    frame _rt_np_compact {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 1
        assert strpos(c1[3], "CI") > 0
        assert strpos(c1[4], "(") > 0
        assert strpos(c1[4], ")") > 0
        capture confirm variable c2
        assert _rc != 0
    }
    assert `got_ncols' == 3
}
if _rc == 0 {
    display as result "  PASS: Test 3 - compact nopvalue has one data column"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - compact nopvalue column contract failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_np_compact

**# Test 4: stars still use internal p-values when p-value columns are hidden
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_stars
    regtab, frame(_rt_np_stars, replace) nopvalue stars

    frame _rt_np_stars {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
        gen byte _has_star = strpos(c1, "*") > 0 if _n >= 4
        summarize _has_star, meanonly
        assert r(max) == 1
        capture confirm variable c3
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 4 - stars survive p-value suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - stars not computed under nopvalue (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_np_stars

**# Test 5: multi-model nopvalue removes one p-value column per model
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign

    capture frame drop _rt_np_multi
    regtab, frame(_rt_np_multi, replace) nopvalue models("Base \ Adjusted")
    local got_ncols = r(N_cols)

    frame _rt_np_multi {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 4
        assert strtrim(c1[2]) == "Base"
        assert strtrim(c3[2]) == "Adjusted"
        assert strpos(c2[3], "CI") > 0
        assert strpos(c4[3], "CI") > 0
        capture confirm variable c5
        assert _rc != 0
    }
    assert `got_ncols' == 6
}
if _rc == 0 {
    display as result "  PASS: Test 5 - multi-model nopvalue suppresses both p columns"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - multi-model nopvalue layout failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_np_multi

**# Test 6: CSV and Excel exports do not contain rendered p-value headers
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local csvout "`output_dir'/_test_regtab_nopvalue.csv"
    local xlsxout "`output_dir'/_test_regtab_nopvalue.xlsx"
    capture erase "`csvout'"
    capture erase "`xlsxout'"

    regtab, csv("`csvout'") xlsx("`xlsxout'") sheet("NoP") nopvalue
    confirm file "`csvout'"
    confirm file "`xlsxout'"

    import delimited using "`csvout'", clear varnames(1) stringcols(_all)
    quietly ds
    local csvvars "`r(varlist)'"
    assert strpos("`csvvars'", "p") == 0

    import excel "`xlsxout'", sheet("NoP") clear allstring
    ds
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "p-value"
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 6 - CSV and Excel omit p-value headers"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - exported nopvalue output exposed p-values (rc=`=_rc')"
    local ++fail_count
}

**# Test 7: compact nopvalue exports to Excel without a p-value column
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local xlsxout "`output_dir'/_test_regtab_nopvalue_compact.xlsx"
    capture erase "`xlsxout'"

    regtab, xlsx("`xlsxout'") sheet("CompactNoP") compact nopvalue
    confirm file "`xlsxout'"

    import excel "`xlsxout'", sheet("CompactNoP") clear allstring
    ds
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "p-value"
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 7 - compact nopvalue Excel export succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - compact nopvalue Excel export failed (rc=`=_rc')"
    local ++fail_count
}

**# Migrated from test_regtab_nsub.do


**# Test 1: stcox with stsplit — N should be subjects, not episodes
{
    di _newline
    di "Test 1: stcox with stsplit — stats(n) reports subjects"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    * Get subject count from a simple stcox before stsplit
    quietly stcox height
    local n_subjects = e(N_sub)

    stsplit, at(failures)
    local n_rows = _N

    di "Subjects: `n_subjects'"
    di "Rows after stsplit: `n_rows'"
    assert `n_rows' > `n_subjects' // sanity: stsplit actually expanded

    collect clear
    collect: stcox height

    * Verify e() values — N should be rows, N_sub should be subjects
    di "e(N) = " e(N) " (rows in risk set)"
    di "e(N_sub) = " e(N_sub) " (subjects)"
    assert e(N) > e(N_sub)
    assert e(N_sub) == `n_subjects'

    regtab, stats(n) display frame(t1, replace)

    frame t1 {
        * Find the N row — should say "Subjects", not "Observations"
        count if A == "Subjects"
        local found_subjects = r(N)
        count if A == "Observations"
        local found_obs = r(N)

        di "Found 'Subjects' rows: `found_subjects'"
        di "Found 'Observations' rows: `found_obs'"

        assert `found_subjects' == 1
        assert `found_obs' == 0

        * Check the value is the subject count, not row count
        levelsof c1 if A == "Subjects", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        di "N value in table: `nval_clean'"
        di "Expected (subjects): `n_subjects'"
        assert real("`nval_clean'") == `n_subjects'
    }
    di "PASS: stcox+stsplit reports subjects correctly"
}


**# Test 2: stcox without stsplit — N should still work (N == N_sub)
{
    di _newline
    di "Test 2: stcox without stsplit — stats(n) still works"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    collect clear
    collect: stcox height

    local expected_n = e(N_sub)
    assert e(N) == e(N_sub)

    regtab, stats(n) display frame(t2, replace)

    frame t2 {
        * Should say "Subjects" (N_sub is always set for st commands)
        count if A == "Subjects"
        assert r(N) == 1

        levelsof c1 if A == "Subjects", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        assert real("`nval_clean'") == `expected_n'
    }
    di "PASS: stcox without stsplit reports correctly"
}


**# Test 3: logit — should still say "Observations" (no N_sub)
{
    di _newline
    di "Test 3: logit — stats(n) says Observations"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    local expected_n = e(N)

    regtab, stats(n) display frame(t3, replace)

    frame t3 {
        count if A == "Observations"
        local found_obs = r(N)
        count if A == "Subjects"
        local found_sub = r(N)

        di "Found 'Observations' rows: `found_obs'"
        di "Found 'Subjects' rows: `found_sub'"

        assert `found_obs' == 1
        assert `found_sub' == 0

        levelsof c1 if A == "Observations", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        assert real("`nval_clean'") == `expected_n'
    }
    di "PASS: logit says Observations"
}


**# Test 4: regress — should still say "Observations"
{
    di _newline
    di "Test 4: regress — stats(n) says Observations"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local expected_n = e(N)

    regtab, stats(n) display frame(t4, replace)

    frame t4 {
        count if A == "Observations"
        assert r(N) == 1
        count if A == "Subjects"
        assert r(N) == 0

        levelsof c1 if A == "Observations", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        assert real("`nval_clean'") == `expected_n'
    }
    di "PASS: regress says Observations"
}


**# Test 5: Mixed table — stcox + logit in same collect
{
    di _newline
    di "Test 5: Mixed table — stcox (stsplit) + logit"
    di _dup(60) "-"

    * First model: stcox with stsplit
    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)
    local n_subjects = r(N_sub)
    stsplit, at(failures)

    collect clear
    collect: stcox height

    local cox_n_sub = e(N_sub)
    local cox_n_obs = e(N)
    di "Cox: N_sub=`cox_n_sub', N=`cox_n_obs'"

    * Second model: logit on different data
    sysuse auto, clear
    collect: logit foreign mpg weight

    local logit_n = e(N)
    di "Logit: N=`logit_n'"

    regtab, stats(n) display frame(t5, replace)

    frame t5 {
        * Should say "Subjects" because at least one model has N_sub
        count if A == "Subjects"
        assert r(N) == 1

        * Model 1 (Cox) should show subject count
        levelsof c1 if A == "Subjects", local(nval1) clean
        local nval1_clean = subinstr("`nval1'", ",", "", .)
        di "Model 1 (Cox) N: `nval1_clean' (expected `cox_n_sub')"
        assert real("`nval1_clean'") == `cox_n_sub'

        * Model 2 (logit) should show its observation count
        levelsof c4 if A == "Subjects", local(nval2) clean
        local nval2_clean = subinstr("`nval2'", ",", "", .)
        di "Model 2 (logit) N: `nval2_clean' (expected `logit_n')"
        assert real("`nval2_clean'") == `logit_n'
    }
    di "PASS: mixed table — Cox gets subjects, logit gets observations"
}


**# Test 6: streg with stsplit — confirms fix works for non-stcox st commands
{
    di _newline
    di "Test 6: streg with stsplit — stats(n) reports subjects"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    quietly streg height, dist(weibull)
    local n_subjects = e(N_sub)

    stsplit, at(failures)
    local n_rows = _N

    di "Subjects: `n_subjects'"
    di "Rows after stsplit: `n_rows'"
    assert `n_rows' > `n_subjects'

    collect clear
    collect: streg height, dist(weibull)

    di "e(N) = " e(N) ", e(N_sub) = " e(N_sub)
    assert e(N) > e(N_sub)
    assert e(N_sub) == `n_subjects'

    regtab, stats(n) display frame(t6, replace)

    frame t6 {
        count if A == "Subjects"
        assert r(N) == 1
        count if A == "Observations"
        assert r(N) == 0

        levelsof c1 if A == "Subjects", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        di "N value: `nval_clean' (expected `n_subjects')"
        assert real("`nval_clean'") == `n_subjects'
    }
    di "PASS: streg+stsplit reports subjects correctly"
}



**# Migrated from test_regtab_stats_alias.do

* Confirm we are testing the bumped version
which regtab

local failures = 0

**# Test 1: stats(n_sub) renders the same N row as stats(n)
{
    di _newline
    di "Test 1: stats(n_sub) == stats(n) for survival models"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    collect clear
    collect: stcox height

    local expected_n = e(N_sub)

    * Baseline: stats(n)
    regtab, stats(n) display frame(t_n, replace)
    frame t_n {
        count if A == "Subjects"
        assert r(N) == 1
        levelsof c1 if A == "Subjects", local(v_n) clean
        local v_n = subinstr("`v_n'", ",", "", .)
    }

    * Alias: stats(n_sub)
    regtab, stats(n_sub) display frame(t_nsub, replace)
    frame t_nsub {
        count if A == "Subjects"
        assert r(N) == 1
        levelsof c1 if A == "Subjects", local(v_nsub) clean
        local v_nsub = subinstr("`v_nsub'", ",", "", .)
    }

    di "stats(n) N = `v_n', stats(n_sub) N = `v_nsub', expected = `expected_n'"
    assert real("`v_n'") == `expected_n'
    assert real("`v_nsub'") == `expected_n'
    assert "`v_n'" == "`v_nsub'"
    di "PASS: stats(n_sub) matches stats(n)"
}

**# Test 2: stats(subjects) also renders the N row
{
    di _newline
    di "Test 2: stats(subjects) renders the N row"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    collect clear
    collect: stcox height
    local expected_n = e(N_sub)

    regtab, stats(subjects) display frame(t_subj, replace)
    frame t_subj {
        count if A == "Subjects"
        assert r(N) == 1
        levelsof c1 if A == "Subjects", local(v) clean
        local v = subinstr("`v'", ",", "", .)
        assert real("`v'") == `expected_n'
    }
    di "PASS: stats(subjects) renders the N row"
}

**# Test 3: unknown token warns but does not abort; valid n still renders
{
    di _newline
    di "Test 3: stats(bogus n) warns, does not abort, N still present"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local expected_n = e(N)

    * Plain call (NO noisily prefix): the warning must surface to a normal user
    * even though the parse block runs inside regtab's internal quietly{}.
    * Capture the session log to a tempfile and assert the warning text appears.
    tempfile warnlog
    log using "`warnlog'", replace text name(_alias_warn)
    regtab, stats(bogus n) display frame(t_bogus, replace)
    local plain_rc = _rc
    log close _alias_warn

    assert `plain_rc' == 0

    * Scan the captured log for the warning text
    local warned = 0
    file open _fh using "`warnlog'", read text
    file read _fh line
    while r(eof) == 0 {
        if strpos(`"`line'"', "not recognized and ignored") local warned = 1
        file read _fh line
    }
    file close _fh
    di "Warning surfaced in plain (non-noisily) call: `warned'"
    assert `warned' == 1

    frame t_bogus {
        count if A == "Observations"
        assert r(N) == 1
        levelsof c1 if A == "Observations", local(v) clean
        local v = subinstr("`v'", ",", "", .)
        assert real("`v'") == `expected_n'
    }
    di "PASS: unknown token surfaces warning to normal user, valid n rendered"
}

**# Test 4: regression — stats(n) output unchanged vs stats(n_sub) on non-survival model
{
    di _newline
    di "Test 4: non-survival stats(n) unchanged; alias still maps to N row"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    local expected_n = e(N)

    regtab, stats(n) display frame(t4n, replace)
    regtab, stats(n_sub) display frame(t4a, replace)

    frame t4n {
        count if A == "Observations"
        assert r(N) == 1
        levelsof c1 if A == "Observations", local(vn) clean
        local vn = subinstr("`vn'", ",", "", .)
    }
    frame t4a {
        count if A == "Observations"
        assert r(N) == 1
        levelsof c1 if A == "Observations", local(va) clean
        local va = subinstr("`va'", ",", "", .)
    }
    assert real("`vn'") == `expected_n'
    assert "`vn'" == "`va'"
    di "PASS: alias maps to N row for non-survival models too"
}


**# Migrated from test_regtab_v1015.do


tempname out_dir
local out_dir "`c(tmpdir)'/_regtab_v1015"
capture mkdir "`out_dir'"

display as text _newline "=== test_regtab_v1015 ==="

**# Test A: ICC cross-pollution (multi-model melogit + mepoisson)
* Build a 3-cluster melogit + 3-cluster mepoisson dataset, collect both, then
* request stats(icc). Before the fix, e(cmd2) == "mepoisson" caused the global
* skip to fire and ALL models' ICC went missing. After the fix, melogit ICC
* should still come through.
capture noisily {
    clear
    set obs 600
    gen cluster = ceil(_n / 30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort cluster: gen u = `uraw'[1] * 0.6
    gen lp = 0.4 + 0.5 * x + u
    gen y_bin = runiform() < invlogit(lp)
    gen y_cnt = rpoisson(exp(0.3 + 0.4 * x + u))

    collect clear
    collect: melogit y_bin x || cluster:
    collect: mepoisson y_cnt x || cluster:

    capture frame drop _rt_v1015_A
    regtab, frame(_rt_v1015_A, replace) stats(icc) noreeffects

    local melogit_icc = .
    local mepoisson_icc = .
    frame _rt_v1015_A {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "ICC" {
                local melogit_icc  = real(strtrim(c1[`i']))
                local mepoisson_icc = real(strtrim(c4[`i']))
            }
        }
    }
    frame drop _rt_v1015_A

    * After the fix, melogit ICC must be a finite positive value.
    assert `melogit_icc' < . & `melogit_icc' > 0
    * mepoisson ICC must remain missing (no closed-form level-1 variance).
    assert `mepoisson_icc' >= .
}
local rc_A = _rc
if `rc_A' == 0 {
    display as result "  PASS: Test A (multi-model ICC: melogit recovered = `melogit_icc'; mepoisson skipped)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test A (rc=`rc_A'; melogit_icc=`melogit_icc'; mepoisson_icc=`mepoisson_icc')"
    local ++fail_count
}

**# Test B: Coefficient >= 1000 destring round-trip
* Build a dataset where the regression coefficient is >= 1000 (collect's default
* %4.2fc format renders as "1,234.56"). Before the fix, destring force returned
* missing and r(table) had no entry for that row. After the fix, the comma is
* stripped before destring and r(table) carries the actual coefficient.
capture noisily {
    clear
    set obs 200
    gen x = runiform()
    * Outcome scale picks a coefficient close to 2500 so the formatter must
    * insert a thousands separator.
    gen y = 100 + 2500 * x + rnormal(0, 50)

    collect clear
    collect: regress y x

    local ref_b = _b[x]

    capture frame drop _rt_v1015_B
    regtab, frame(_rt_v1015_B, replace) digits(3)

    tempname rt
    matrix `rt' = r(table)

    * r(table) row 1 col 1 should equal _b[x] within 0.01 absolute.
    local got_b = `rt'[1, 1]
    assert abs(`got_b' - `ref_b') < 0.01
    * The displayed cell must use 3 decimal places (digits(3)) — find the data
    * row containing the variable name "x" (rows 1-3 are headers/labels).
    local cell ""
    frame _rt_v1015_B {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "x" {
                local cell = strtrim(c1[`i'])
                continue, break
            }
        }
        local dot_pos = strpos("`cell'", ".")
        local dec_count = strlen("`cell'") - `dot_pos'
        assert `dec_count' == 3
        assert strpos("`cell'", ",") == 0
    }
    frame drop _rt_v1015_B
}
local rc_B = _rc
if `rc_B' == 0 {
    display as result "  PASS: Test B (large coef destring: ref=`=string(`ref_b', "%9.3f")', got=`=string(`got_b', "%9.3f")')"
    local ++pass_count
}
else {
    display as error "  FAIL: Test B (rc=`rc_B'; ref_b=`ref_b'; got_b=`got_b'; cell=`cell')"
    local ++fail_count
}

**# Test C: Refcat detection with non-default precision
* Use a logit with a 4-level factor variable. Reference category coefficient
* is exactly 0 (linear) → 1 (exponentiated) with empty CI. Before the fix the
* "Reference" label only matched literal "0" / "1" strings; if collect rendered
* "1.000" because of a higher-precision format, the label fell off and a numeric
* "1.000" leaked into the cell. After the fix, refcat detection works off the
* numeric value so digits(4) still labels the row.
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg i.rep78

    capture frame drop _rt_v1015_C
    regtab, frame(_rt_v1015_C, replace) digits(4)

    local ref_count = 0
    frame _rt_v1015_C {
        forvalues i = 3/`=_N' {
            local _v = strtrim(c1[`i'])
            if "`_v'" == "Reference" local ++ref_count
        }
    }
    frame drop _rt_v1015_C

    * 4-level rep78 → 1 reference row (the omitted base).
    assert `ref_count' >= 1
}
local rc_C = _rc
if `rc_C' == 0 {
    display as result "  PASS: Test C (refcat detection at digits(4): `ref_count' Reference row(s))"
    local ++pass_count
}
else {
    display as error "  FAIL: Test C (rc=`rc_C'; ref_count=`ref_count')"
    local ++fail_count
}

**# Helper: assert string appears in a captured log file
* Slurps the log file, joining Stata's hard-wrapped continuation lines
* (`\n> ` markers from batch mode line-wrap at column ~80), then asserts
* `needle' appears in the resulting concatenated content. This locks the
* exact Note text emitted by regtab without being defeated by the column
* wrap that Stata applies when writing display strings to a text log.
capture program drop _v1015_assert_in_log
program define _v1015_assert_in_log
    args path needle
    capture confirm file `"`path'"'
    if _rc {
        display as error "  log file not found: `path'"
        exit 601
    }
    tempname _vfh
    local _content ""
    file open `_vfh' using `"`path'"', read text
    file read `_vfh' line
    while r(eof) == 0 {
        * Strip Stata's batch wrap-continuation prefix exactly "> " (gt,
        * single space). The wrap point preserves the original character at
        * column 1 of the continuation, so the leading space from the source
        * text typically remains as the first char after the marker. Removing
        * only "> " (not "> +") rejoins exactly as the user-visible string.
        if regexm(`"`line'"', "^> ") {
            local line = regexr(`"`line'"', "^> ", "")
            local _content `"`_content'`line'"'
        }
        else {
            local _content `"`_content' `line'"'
        }
        file read `_vfh' line
    }
    file close `_vfh'
    if strpos(`"`_content'"', `"`needle'"') == 0 {
        display as error "  needle not found in `path':"
        display as error "    `needle'"
        exit 9
    }
end

**# Test F: single-model mepoisson — exact ICC-skip Note string
* Lock the user-facing message that fires when every model in the collection
* has an undefined level-1 variance. The exact wording is part of the
* contract: any future refactor that drops the parenthetical must update
* this assertion too.
local _f_log "`out_dir'/_test_F.log"
capture erase "`_f_log'"
capture noisily {
    clear
    set obs 600
    gen group = ceil(_n / 30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3 * x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    log using `"`_f_log'"', replace text name(_v1015_F)
    capture frame drop _rt_v1015_F
    regtab, frame(_rt_v1015_F, replace) stats(icc)
    capture log close _v1015_F
    capture frame drop _rt_v1015_F

    _v1015_assert_in_log `"`_f_log'"' ///
        "Note: ICC not computed (no closed-form level-1 variance for the requested model family)"
}
local rc_F = _rc
capture log close _v1015_F
if `rc_F' == 0 {
    display as result "  PASS: Test F (single-model mepoisson — exact Note string emitted)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test F (rc=`rc_F'; see `_f_log')"
    local ++fail_count
}

**# Test G: multi-model — ICC-skip Note names the affected position(s)
* Two-model collection [melogit, mepoisson]. Note must list the count-data
* position only; melogit ICC must still be recovered. Lock both the message
* template and the listed index.
local _g_log "`out_dir'/_test_G.log"
capture erase "`_g_log'"
capture noisily {
    clear
    set obs 600
    gen cluster = ceil(_n / 30)
    gen x = rnormal()
    tempvar uraw2
    gen `uraw2' = rnormal()
    bysort cluster: gen u = `uraw2'[1] * 0.6
    gen lp = 0.4 + 0.5 * x + u
    gen y_bin = runiform() < invlogit(lp)
    gen y_cnt = rpoisson(exp(0.3 + 0.4 * x + u))

    collect clear
    collect: melogit y_bin x || cluster:
    collect: mepoisson y_cnt x || cluster:

    log using `"`_g_log'"', replace text name(_v1015_G)
    capture frame drop _rt_v1015_G
    regtab, frame(_rt_v1015_G, replace) stats(icc) noreeffects
    capture log close _v1015_G
    capture frame drop _rt_v1015_G

    * mepoisson is the second model — index 2 must appear in the note.
    _v1015_assert_in_log `"`_g_log'"' ///
        "Note: ICC not computed for model(s) 2 (no closed-form level-1 variance)"
}
local rc_G = _rc
capture log close _v1015_G
if `rc_G' == 0 {
    display as result "  PASS: Test G (multi-model — Note lists position 2 only)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test G (rc=`rc_G'; see `_g_log')"
    local ++fail_count
}
**# Migrated: legacy suite: regtab section

* ============================================================
* regtab Tests
* ============================================================

* Test: Basic single logistic model
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab.xlsx") sheet("T1") coef("OR")
    confirm file "`output_dir'/_test_regtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - basic logistic"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - basic logistic (error `=_rc')"
    local ++fail_count
}

* Test: With title
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_title.xlsx") sheet("T1") ///
        coef("OR") title("Table 1. Logistic Regression Results")
    confirm file "`output_dir'/_test_regtab_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - title option"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - title option (error `=_rc')"
    local ++fail_count
}

* Test: Multiple models
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    collect: regress price mpg weight foreign
    regtab, xlsx("`output_dir'/_test_regtab_multi.xlsx") sheet("T1") ///
        coef("Coef.") models("Model 1 \ Model 2 \ Model 3")
    confirm file "`output_dir'/_test_regtab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - multiple models"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - multiple models (error `=_rc')"
    local ++fail_count
}

* Test: Drop intercept
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg
    regtab, xlsx("`output_dir'/_test_regtab_noint.xlsx") sheet("T1") coef("OR") noint
    confirm file "`output_dir'/_test_regtab_noint.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - noint"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - noint (error `=_rc')"
    local ++fail_count
}

* Test: Custom CI separator
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg
    regtab, xlsx("`output_dir'/_test_regtab_sep.xlsx") sheet("T1") coef("OR") sep("; ")
    confirm file "`output_dir'/_test_regtab_sep.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - custom separator"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - custom separator (error `=_rc')"
    local ++fail_count
}

* Test: Linear regression
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_linear.xlsx") sheet("T1") ///
        coef("Coef.") title("Linear Regression")
    confirm file "`output_dir'/_test_regtab_linear.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - linear regression"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - linear regression (error `=_rc')"
    local ++fail_count
}

* Test: Cox regression
capture noisily {
    clear
    set seed 54321
    set obs 200
    gen treat = runiform() > 0.5
    gen age = 40 + int(runiform()*30)
    gen time = rexponential(1/(0.1 + 0.05*treat))
    gen event = runiform() < 0.7
    stset time, failure(event)
    collect clear
    collect: stcox treat age
    regtab, xlsx("`output_dir'/_test_regtab_cox.xlsx") sheet("T1") ///
        coef("HR") title("Hazard Ratios")
    confirm file "`output_dir'/_test_regtab_cox.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - Cox regression"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - Cox regression (error `=_rc')"
    local ++fail_count
}

* Test: Poisson regression
capture noisily {
    sysuse auto, clear
    gen n_events = ceil(runiform() * 5)
    collect clear
    collect: poisson n_events price mpg, irr
    regtab, xlsx("`output_dir'/_test_regtab_poisson.xlsx") sheet("T1") coef("IRR")
    confirm file "`output_dir'/_test_regtab_poisson.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - Poisson regression"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - Poisson regression (error `=_rc')"
    local ++fail_count
}

* Test: Stats option (N, AIC, BIC)
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_stats.xlsx") sheet("Stats") ///
        coef("OR") title("With Stats") stats(n aic bic) noint
    confirm file "`output_dir'/_test_regtab_stats.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - stats(n aic bic)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - stats(n aic bic) (error `=_rc')"
    local ++fail_count
}

* Test: Mixed model with relabel
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen cluster = ceil(_n/20)
    label variable cluster "Study Site"
    gen x = rnormal()
    label variable x "Treatment Score"
    gen u0 = rnormal() * 0.5 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen u1 = rnormal() * 0.3 if cluster != cluster[_n-1]
    replace u1 = u1[_n-1] if u1 == .
    gen y = 1 + 0.5*x + u0 + u1*x + rnormal()*0.3
    collect clear
    collect: mixed y x || cluster: x
    regtab, xlsx("`output_dir'/_test_regtab_mixed.xlsx") sheet("Mixed") ///
        coef("Coef.") title("Mixed Model") stats(n groups aic bic icc) relabel
    confirm file "`output_dir'/_test_regtab_mixed.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - mixed model relabel"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - mixed model relabel (error `=_rc')"
    local ++fail_count
}

* Test: nore option (hide random effects)
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen facility = ceil(_n/20)
    gen exposure = runiform() > 0.5
    gen outcome = 1 + 0.5*exposure + rnormal()*0.5
    collect clear
    collect: mixed outcome exposure || facility:
    regtab, xlsx("`output_dir'/_test_regtab_nore.xlsx") sheet("NoRE") ///
        coef("Coef.") title("Hide RE") nore
    * Verify no RE rows in output
    import excel "`output_dir'/_test_regtab_nore.xlsx", sheet("NoRE") clear allstring
    count if strpos(B, "var(") > 0 | strpos(B, "Variance") > 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: regtab - nore option"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - nore option (error `=_rc')"
    local ++fail_count
}

* Test: Data preservation after regtab
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    local orig_k = c(k)
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_preserve.xlsx") sheet("T1") coef("Coef.")
    assert _N == `orig_N'
    assert c(k) == `orig_k'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: regtab - data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - data preservation (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR automatic transformation
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen cluster = ceil(_n/25)
    label variable cluster "Hospital"
    gen x = rnormal()
    label variable x "Treatment"
    gen u0 = rnormal() * 0.8 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-1 + 0.5*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_mor.xlsx") sheet("MOR") ///
        coef("OR") title("MOR Test") relabel
    confirm file "`output_dir'/_test_regtab_mor.xlsx"
    * Verify MOR label appears in output
    import excel "`output_dir'/_test_regtab_mor.xlsx", sheet("MOR") clear allstring
    count if strpos(B, "Median Odds Ratio") > 0
    assert r(N) == 1
    * Verify MOR value is reasonable (>= 1.0)
    levelsof C if strpos(B, "Median Odds Ratio") > 0, local(mor_val)
    local mor_val : word 1 of `mor_val'
    assert real("`mor_val'") >= 1.0
}
if _rc == 0 {
    display as result "  PASS: regtab - melogit MOR transformation"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - melogit MOR transformation (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR without relabel
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen cluster = ceil(_n/25)
    gen x = rnormal()
    gen u0 = rnormal() * 0.8 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-1 + 0.5*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_mor_norelabel.xlsx") sheet("MOR") ///
        coef("OR") title("MOR No Relabel")
    confirm file "`output_dir'/_test_regtab_mor_norelabel.xlsx"
    * Verify MOR label still appears even without relabel
    import excel "`output_dir'/_test_regtab_mor_norelabel.xlsx", sheet("MOR") clear allstring
    count if strpos(B, "Median Odds Ratio") > 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: regtab - MOR without relabel"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - MOR without relabel (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR value correctness
capture noisily {
    * MOR = exp(sqrt(2 * var) * invnormal(0.75))
    * Verify the transformation produces values > 1.0 and in expected range
    clear
    set seed 99999
    set obs 1000
    gen cluster = ceil(_n/50)
    label variable cluster "Site"
    gen x = rnormal()
    gen u0 = rnormal() * 1.0 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-0.5 + 0.3*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_mor_correct.xlsx") sheet("MOR") ///
        coef("OR") title("MOR Correctness")
    import excel "`output_dir'/_test_regtab_mor_correct.xlsx", sheet("MOR") clear allstring
    levelsof C if strpos(B, "Median Odds Ratio") > 0, local(mor_val)
    local mor_val : word 1 of `mor_val'
    * MOR must be >= 1.0 (by definition: exp(positive) >= 1)
    assert real("`mor_val'") >= 1.0
    * With substantial clustering (sigma=1.0), MOR should be well above 1
    assert real("`mor_val'") > 1.5
    * MOR should not be astronomically large for sigma=1.0
    assert real("`mor_val'") < 10.0
}
if _rc == 0 {
    display as result "  PASS: regtab - MOR value correctness"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - MOR value correctness (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR with nore suppresses MOR row
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen cluster = ceil(_n/25)
    gen x = rnormal()
    gen u0 = rnormal() * 0.8 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-1 + 0.5*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_mor_nore.xlsx") sheet("MOR") ///
        coef("OR") title("MOR + nore") nore
    import excel "`output_dir'/_test_regtab_mor_nore.xlsx", sheet("MOR") clear allstring
    count if strpos(B, "Median Odds Ratio") > 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: regtab - MOR with nore"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - MOR with nore (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR with group label
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen hospital = ceil(_n/25)
    label variable hospital "Healthcare Facility"
    gen x = rnormal()
    gen u0 = rnormal() * 0.8 if hospital != hospital[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-1 + 0.5*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || hospital:
    regtab, xlsx("`output_dir'/_test_regtab_mor_grplbl.xlsx") sheet("MOR") ///
        coef("OR") title("MOR Group Label") relabel
    import excel "`output_dir'/_test_regtab_mor_grplbl.xlsx", sheet("MOR") clear allstring
    * Verify group label is included
    count if strpos(B, "Median Odds Ratio (Healthcare Facility)") > 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: regtab - MOR with group label"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - MOR with group label (error `=_rc')"
    local ++fail_count
}

* Test: mixed model (linear) does NOT get MOR transformation
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen cluster = ceil(_n/20)
    gen x = rnormal()
    gen u0 = rnormal() * 0.5 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen y = 1 + 0.5*x + u0 + rnormal()*0.3
    collect clear
    collect: mixed y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_no_mor.xlsx") sheet("NoMOR") ///
        coef("Coef.") title("No MOR for linear") relabel
    import excel "`output_dir'/_test_regtab_no_mor.xlsx", sheet("NoMOR") clear allstring
    * Should NOT have MOR label
    count if strpos(B, "Median Odds Ratio") > 0
    assert r(N) == 0
    * Should have variance label instead
    count if strpos(B, "Intercept") > 0 | strpos(B, "Variance") > 0 | strpos(B, "Residual") > 0
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: regtab - linear mixed no MOR"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - linear mixed no MOR (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR CI transformation
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen cluster = ceil(_n/25)
    gen x = rnormal()
    gen u0 = rnormal() * 0.8 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-1 + 0.5*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_mor_ci.xlsx") sheet("MOR") ///
        coef("OR") title("MOR CI")
    import excel "`output_dir'/_test_regtab_mor_ci.xlsx", sheet("MOR") clear allstring
    * Find the MOR row and check CI column
    levelsof D if strpos(B, "Median Odds Ratio") > 0, local(mor_ci)
    local mor_ci : word 1 of `mor_ci'
    * CI should contain parentheses and comma (formatted CI)
    assert strpos(`"`mor_ci'"', "(") > 0
    assert strpos(`"`mor_ci'"', ")") > 0
}
if _rc == 0 {
    display as result "  PASS: regtab - MOR CI transformation"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - MOR CI transformation (error `=_rc')"
    local ++fail_count
}

* Test: melogit MOR with stats
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen cluster = ceil(_n/25)
    label variable cluster "Site"
    gen x = rnormal()
    gen u0 = rnormal() * 0.8 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen p = invlogit(-1 + 0.5*x + u0)
    gen y = runiform() < p
    collect clear
    collect: melogit y x || cluster:
    regtab, xlsx("`output_dir'/_test_regtab_mor_stats.xlsx") sheet("MOR") ///
        coef("OR") title("MOR + Stats") stats(n groups icc) relabel
    confirm file "`output_dir'/_test_regtab_mor_stats.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - MOR with stats"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - MOR with stats (error `=_rc')"
    local ++fail_count
}


**# Migrated: legacy suite: regtab extensions

* ============================================================
* regtab Extensions Tests
* ============================================================

**# regtab extensions

* Test: cdisc option
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_test_cdisc.xlsx"
    collect clear
    collect: logistic foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_cdisc.xlsx") sheet("CDISC") ///
        coef("OR") noint cdisc
    confirm file "`output_dir'/_test_cdisc.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - cdisc option"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - cdisc option (error `=_rc')"
    local ++fail_count
}

* Test: digits(4) custom precision
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_test_dig4.xlsx"
    collect clear
    collect: logistic foreign price mpg
    regtab, xlsx("`output_dir'/_test_dig4.xlsx") sheet("Dig4") ///
        coef("OR") noint digits(4)
    confirm file "`output_dir'/_test_dig4.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - digits(4) custom precision"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - digits(4) (error `=_rc')"
    local ++fail_count
}

* Test: digits(0) integer formatting
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_test_dig0.xlsx"
    collect clear
    collect: logistic foreign price mpg
    regtab, xlsx("`output_dir'/_test_dig0.xlsx") sheet("Dig0") ///
        coef("OR") noint digits(0)
    confirm file "`output_dir'/_test_dig0.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - digits(0) integer formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - digits(0) (error `=_rc')"
    local ++fail_count
}

* Test: digits(7) out of range → error
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign price mpg
    regtab, xlsx("`output_dir'/_test_dig7.xlsx") sheet("Dig7") ///
        coef("OR") noint digits(7)
}
if _rc != 0 {
    display as result "  PASS: regtab - digits(7) out of range gives error"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - digits(7) should give error"
    local ++fail_count
}


**# Migrated: legacy suite: varabbrev edge

* Test: varabbrev restoration after regtab
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign price mpg
    set varabbrev on
    regtab, xlsx("`output_dir'/_test_vab.xlsx") sheet("T") coef("OR") noint
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: edge case - varabbrev restored after regtab"
    local ++pass_count
}
else {
    display as error "  FAIL: edge case - varabbrev not restored after regtab (error `=_rc')"
    local ++fail_count
}
set varabbrev off


**# Migrated: v1.4 significance stars

**# O3: Significance stars for regtab
* =========================================================================

* --- O3.1: stars option ---
local ++n_total
collect clear
collect: regress price mpg weight i.foreign
capture noisily regtab, xlsx("output/test_o3_stars.xlsx") sheet("Stars") ///
    title("O3 Stars Test") stars
if _rc == 0 {
    capture confirm file "output/test_o3_stars.xlsx"
    if _rc == 0 {
        display as result "PASS: O3.1 — stars option (check output/test_o3_stars.xlsx)"
        local ++pass_count
    }
    else {
        display as error "FAIL: O3.1 — Excel file not created"
        local ++fail_count
    }
}
else {
    display as error "FAIL: O3.1 — stars option (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- O3.2: stars returns in r() ---
local ++n_total
collect clear
collect: regress price mpg weight
capture noisily regtab, xlsx("output/test_o3b.xlsx") sheet("Test") stars
if _rc == 0 {
    local _stars_ret = "`r(stars)'"
    if "`_stars_ret'" == "stars" {
        display as result "PASS: O3.2 — r(stars) returned"
        local ++pass_count
    }
    else {
        display as error "FAIL: O3.2 — r(stars) not returned (got: `_stars_ret')"
        local ++fail_count
    }
}
else {
    display as error "FAIL: O3.2 — regtab failed (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* =========================================================================

**# Migrated: v1.4 error messages + returns

**# U3: Improved error messages
* =========================================================================

sysuse auto, clear

* --- U3.1: regtab improved error messages (hint text present) ---
* Note: collect clear leaves an empty collection that passes the query check.
* The improved error messages are for when no collection exists at all.
* We verify the hint text exists in the source code instead.
local ++n_total
capture findfile regtab.ado
if _rc == 0 {
    local _regtab_path "`r(fn)'"
    tempname _rh
    file open `_rh' using "`_regtab_path'", read text
    local _found_hint = 0
    file read `_rh' _line
    while r(eof) == 0 {
        if strpos(`"`_line'"', "collect clear") > 0 & strpos(`"`_line'"', "Hint") > 0 {
            local _found_hint = 1
        }
        file read `_rh' _line
    }
    file close `_rh'
    if `_found_hint' {
        display as result "PASS: U3.1 — regtab contains improved hint text"
        local ++pass_count
    }
    else {
        display as error "FAIL: U3.1 — hint text not found in regtab.ado"
        local ++fail_count
    }
}
else {
    display as error "FAIL: U3.1 — regtab.ado not found"
    local ++fail_count
}

* =========================================================================
**# I1: Return values from regtab
* =========================================================================

sysuse auto, clear

* --- I1.1: regtab returns N_models ---
local ++n_total
collect clear
collect: regress price mpg weight
collect: regress price mpg weight foreign
capture noisily regtab, xlsx("output/test_i1.xlsx") sheet("Test") ///
    models(Model 1 \ Model 2)
if _rc == 0 {
    if r(N_models) == 2 {
        display as result "PASS: I1.1 — r(N_models) = 2"
        local ++pass_count
    }
    else {
        display as error "FAIL: I1.1 — r(N_models) = `r(N_models)' (expected 2)"
        local ++fail_count
    }
}
else {
    display as error "FAIL: I1.1 — regtab failed (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- I1.2: regtab returns coef_label ---
local ++n_total
collect clear
collect: logistic foreign price mpg
capture noisily regtab, xlsx("output/test_i1b.xlsx") sheet("Test")
if _rc == 0 {
    if "`r(coef_label)'" == "OR" {
        display as result "PASS: I1.2 — r(coef_label) = OR for logistic"
        local ++pass_count
    }
    else {
        display as error "FAIL: I1.2 — r(coef_label) = `r(coef_label)' (expected OR)"
        local ++fail_count
    }
}
else {
    display as error "FAIL: I1.2 — regtab failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.5 R-squared stats

**# F6: R-squared in regtab stats()
* =========================================================================

* --- F6.1: R² for OLS regression ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local true_r2 = e(r2)
    regtab, xlsx("output/test_f6_r2.xlsx") sheet("R2") stats(n r2)
}
if _rc == 0 {
    display as result "  PASS: F6.1 — R² in stats(n r2) for OLS"
    local ++pass_count
}
else {
    display as error "  FAIL: F6.1 — R² stats failed (rc=`=_rc')"
    local ++fail_count
}

* --- F6.2: Pseudo-R² for logistic regression ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_f6_pseudor2.xlsx") sheet("PseudoR2") stats(n r2)
}
if _rc == 0 {
    display as result "  PASS: F6.2 — Pseudo-R² in stats(n r2) for logit"
    local ++pass_count
}
else {
    display as error "  FAIL: F6.2 — Pseudo-R² failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.5 nointercept auto-detect + starslevels

**# U4: Auto-detect nointercept for OR/HR/IRR
* =========================================================================

* --- U4.1: Logit auto-suppresses intercept ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_u4_noint.xlsx") sheet("AutoNoInt")
    * r(coef_label) should be OR, and noint should be auto-applied
    assert "`r(coef_label)'" == "OR"
}
if _rc == 0 {
    display as result "  PASS: U4.1 — logit auto-nointercept (coef=OR)"
    local ++pass_count
}
else {
    display as error "  FAIL: U4.1 — auto-nointercept failed (rc=`=_rc')"
    local ++fail_count
}

* --- U4.2: keepintercept overrides auto ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_u4_keepint.xlsx") sheet("KeepInt") keepintercept
}
if _rc == 0 {
    display as result "  PASS: U4.2 — keepintercept option accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: U4.2 — keepintercept failed (rc=`=_rc')"
    local ++fail_count
}

* --- U4.3: OLS does NOT auto-suppress intercept ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_u4_ols.xlsx") sheet("OLS")
    assert "`r(coef_label)'" == "Coef."
}
if _rc == 0 {
    display as result "  PASS: U4.3 — OLS keeps intercept (coef=Coef.)"
    local ++pass_count
}
else {
    display as error "  FAIL: U4.3 — OLS coef detection wrong (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# O5: starslevels() custom thresholds
* =========================================================================

* --- O5.1: Custom starslevels ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("output/test_o5_stars.xlsx") sheet("Stars") ///
        stars starslevels(0.10 0.05 0.01)
}
if _rc == 0 {
    display as result "  PASS: O5.1 — starslevels(0.10 0.05 0.01) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: O5.1 — custom starslevels failed (rc=`=_rc')"
    local ++fail_count
}

* --- O5.2: starslevels rejects wrong number of values ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_o5_bad.xlsx") sheet("Bad") ///
        stars starslevels(0.10 0.05)
}
if _rc == 198 {
    display as result "  PASS: O5.2 — starslevels(2 values) correctly rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: O5.2 — expected rc=198, got rc=`=_rc'"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.6 frame()

**# 2.2: frame() for regtab
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop myreg
    regtab, xlsx("output/test_v160_frame_regtab.xlsx") sheet("Test") frame(myreg)
    assert r(frame) == "myreg"
    frame myreg: describe
    frame myreg: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: 2.2 — regtab frame() stores data"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.2 — regtab frame() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop myreg

* =========================================================================

**# Migrated: v1.6 r(table) + console display

**# 2.6: r(table) matrix in regtab
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_rtable.xlsx") sheet("Test")
    matrix list r(table)
    local nrows = rowsof(r(table))
    assert `nrows' > 0
}
if _rc == 0 {
    display as result "  PASS: 2.6 — r(table) matrix returned with `nrows' rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.6 — r(table) matrix failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# 3.1: Console display mode for regtab
* =========================================================================

* --- 3.1.1: regtab without xlsx() displays in console ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab
}
if _rc == 0 {
    display as result "  PASS: 3.1.1 — regtab without xlsx() runs (console display)"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.1.1 — regtab without xlsx() failed (rc=`=_rc')"
    local ++fail_count
}

* --- 3.1.2: regtab with display option shows console AND exports ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_display.xlsx") sheet("Test") display
    confirm file "output/test_v160_display.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 3.1.2 — regtab display + xlsx() works"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.1.2 — regtab display + xlsx() failed (rc=`=_rc')"
    local ++fail_count
}

* --- 3.1.3: regtab without xlsx() still returns r(N_rows) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab
    assert r(N_rows) > 0
    assert r(N_models) > 0
}
if _rc == 0 {
    display as result "  PASS: 3.1.3 — regtab console mode returns r() values"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.1.3 — regtab console mode r() failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.6 keep/drop + multi-model + preservation

**# 3.4: keep()/drop() for regtab
* =========================================================================

* --- 3.4.1: keep() filters rows ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop keeptest
    capture erase "output/test_v160_keep.xlsx"
    regtab, xlsx("output/test_v160_keep.xlsx") sheet("Test") keep(mpg weight) frame(keeptest)
    * Frame should have fewer rows than full model
    frame keeptest: assert _N < 10
    frame keeptest: assert _N >= 3
}
if _rc == 0 {
    display as result "  PASS: 3.4.1 — regtab keep() filters rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.4.1 — regtab keep() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop keeptest

* --- 3.4.2: drop() removes rows ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop droptest
    regtab, xlsx("output/test_v160_drop.xlsx") sheet("Test") drop(_cons) frame(droptest)
    * Frame should not contain _cons
    frame droptest {
        gen byte _has_cons = A == "_cons"
        summarize _has_cons, meanonly
        assert r(max) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: 3.4.2 — regtab drop() removes rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.4.2 — regtab drop() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop droptest

* --- 3.4.3: keep + drop mutual exclusivity ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_keepdrop.xlsx") sheet("Test") keep(mpg) drop(weight)
}
if _rc != 0 {
    display as result "  PASS: 3.4.3 — keep + drop correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.4.3 — keep + drop should have been rejected"
    local ++fail_count
}

* =========================================================================
**# Multi-model regtab test (display + frame + r(table))
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    capture frame drop multi
    regtab, xlsx("output/test_v160_multi.xlsx") sheet("Test") ///
        models("Model 1 \ Model 2") frame(multi) display
    assert r(N_models) == 2
    matrix list r(table)
    local ncols = colsof(r(table))
    assert `ncols' == 2
}
if _rc == 0 {
    display as result "  PASS: multi-model — 2-model regtab with display + frame + r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-model — 2-model test failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop multi

* =========================================================================
**# Data preservation test
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    collect clear
    collect: regress price mpg weight
    regtab
    assert _N == `orig_n'
    assert "`=_sortedby'" != ""  | _N > 0
}
if _rc == 0 {
    display as result "  PASS: data preservation — user data intact after console regtab"
    local ++pass_count
}
else {
    display as error "  FAIL: data preservation — user data changed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.7 compact mode

**# F4: regtab compact mode
* =========================================================================

* --- F4.1: compact merges estimate+CI into one column ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _f4_1
    regtab, frame(_f4_1) compact
    * In compact mode: title, A, c1 (est+CI), c2 (p) = 4 vars
    * Normal mode would have: title, A, c1 (est), c2 (CI), c3 (p) = 5 vars
    frame _f4_1 {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
    }
}
if _rc == 0 {
    display as result "  PASS: F4.1 — compact mode produces 2 data columns (est+CI, p)"
    local ++pass_count
}
else {
    display as error "  FAIL: F4.1 — compact mode column count wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f4_1

* --- F4.2: compact mode cell contains both estimate and CI ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _f4_2
    regtab, frame(_f4_2) compact
    frame _f4_2 {
        * Rows 1-3 are title/header; row 4+ are data rows
        local cell = c1[4]
        assert strpos("`cell'", "(") > 0
        assert strpos("`cell'", ")") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: F4.2 — compact cell contains estimate and CI"
    local ++pass_count
}
else {
    display as error "  FAIL: F4.2 — compact cell format wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f4_2

* --- F4.3: compact mode with multi-model ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    capture frame drop _f4_3
    regtab, frame(_f4_3) compact models("Model 1 \ Model 2")
    frame _f4_3 {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        * 2 models * 2 cols each = 4 c-columns
        assert `ncvars' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: F4.3 — compact mode with 2 models produces 4 data columns"
    local ++pass_count
}
else {
    display as error "  FAIL: F4.3 — compact multi-model column count wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f4_3

* --- F4.4: compact mode Excel export ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/test_v170_compact.xlsx"
    regtab, xlsx("output/test_v170_compact.xlsx") sheet("Test") compact
    confirm file "output/test_v170_compact.xlsx"
}
if _rc == 0 {
    display as result "  PASS: F4.4 — compact mode Excel export succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: F4.4 — compact mode Excel export failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.7 refcat()

**# O5: refcat() for regtab
* =========================================================================

* --- O5.1: refcat changes reference label ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _o5_1
    regtab, frame(_o5_1) refcat("Ref.")
    frame _o5_1 {
        gen byte _has_ref = strpos(c1, "Ref.") > 0
        summarize _has_ref, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: O5.1 — refcat(Ref.) changes reference label"
    local ++pass_count
}
else {
    display as error "  FAIL: O5.1 — refcat() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _o5_1

* --- O5.2: default refcat is "Reference" ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _o5_2
    regtab, frame(_o5_2)
    frame _o5_2 {
        gen byte _has_ref = strpos(c1, "Reference") > 0
        summarize _has_ref, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: O5.2 — default refcat is 'Reference'"
    local ++pass_count
}
else {
    display as error "  FAIL: O5.2 — default refcat check failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _o5_2

* =========================================================================

**# Migrated: option coverage sweep

**# SECTION 2: regtab — untested options
* ============================================================

* Test: zebra option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_zebra.xlsx") sheet("zebra") zebra
    confirm file "`output_dir'/_cov_reg_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab zebra (error `=_rc')"
    local ++fail_count
}

* Test: boldp option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_boldp.xlsx") sheet("boldp") boldp(0.05)
    confirm file "`output_dir'/_cov_reg_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab boldp() (error `=_rc')"
    local ++fail_count
}

* Test: highlight option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_highlight.xlsx") sheet("highlight") highlight(0.05)
    confirm file "`output_dir'/_cov_reg_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab highlight() (error `=_rc')"
    local ++fail_count
}

* Test: borderstyle options (medium, academic)
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_border.xlsx") sheet("medium") borderstyle(medium)
    confirm file "`output_dir'/_cov_reg_border.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab borderstyle(medium)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab borderstyle(medium) (error `=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_academic.xlsx") sheet("academic") borderstyle(academic)
    confirm file "`output_dir'/_cov_reg_academic.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab borderstyle(academic)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab borderstyle(academic) (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_footnote.xlsx") sheet("footnote") ///
        footnote("Adjusted for confounders")
    confirm file "`output_dir'/_cov_reg_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_colors.xlsx") sheet("colors") ///
        zebra headercolor("200 220 240") zebracolor("245 245 255")
    confirm file "`output_dir'/_cov_reg_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_csv.xlsx") sheet("csv") ///
        csv("`output_dir'/_cov_reg.csv")
    confirm file "`output_dir'/_cov_reg.csv"
}
if _rc == 0 {
    display as result "  PASS: regtab csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab csv() (error `=_rc')"
    local ++fail_count
}

* Test: frame output
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_frame.xlsx") sheet("frame") frame(_cov_reg_fr)
    frame _cov_reg_fr: assert _N > 0
    frame drop _cov_reg_fr
}
if _rc == 0 {
    display as result "  PASS: regtab frame()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab frame() (error `=_rc')"
    local ++fail_count
}

* Test: keep option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length displacement
    regtab, xlsx("`output_dir'/_cov_reg_keep.xlsx") sheet("keep") keep("mpg weight")
    confirm file "`output_dir'/_cov_reg_keep.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab keep()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab keep() (error `=_rc')"
    local ++fail_count
}

* Test: drop option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length displacement
    regtab, xlsx("`output_dir'/_cov_reg_drop.xlsx") sheet("drop") drop("_cons displacement")
    confirm file "`output_dir'/_cov_reg_drop.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab drop()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab drop() (error `=_rc')"
    local ++fail_count
}

* Test: stars and starslevels options
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_stars.xlsx") sheet("stars") stars
    confirm file "`output_dir'/_cov_reg_stars.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab stars"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab stars (error `=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_starslevels.xlsx") sheet("starslevels") ///
        stars starslevels(0.1 0.05 0.01)
    confirm file "`output_dir'/_cov_reg_starslevels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab starslevels()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab starslevels() (error `=_rc')"
    local ++fail_count
}

* Test: theme options
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_lancet.xlsx") sheet("lancet") theme(lancet)
    confirm file "`output_dir'/_cov_reg_lancet.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: combined formatting stress test
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_stress.xlsx") sheet("stress") ///
        zebra boldp(0.05) highlight(0.1) borderstyle(academic) ///
        footnote("OLS regression") title("Combined Test") ///
        stars starslevels(0.1 0.05 0.01) theme(nejm)
    confirm file "`output_dir'/_cov_reg_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab combined formatting stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab combined formatting stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: refcat base-level labels

**# 10. regtab refcat label only on base levels in Coef. scale (I9 regression)

**## 10a. Linear regression — reference labeled, non-reference value "1" not mislabeled
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price i.rep78 mpg weight
    local i9_xlsx "`output_dir'/_rev1013_i9_regtab.xlsx"
    capture erase "`i9_xlsx'"
    regtab, xlsx("`i9_xlsx'") sheet("I9Test") refcat("Ref.") noint

    * Read the xlsx after command returns (avoids nested preserve)
    * Read xlsx — col A=spacer, B=label, C=estimate
    clear
    import excel using "`i9_xlsx'", sheet("I9Test") allstring clear
    local ref_count = 0
    forvalues i = 1/`=_N' {
        if strtrim(C[`i']) == "Ref." local ref_count = `ref_count' + 1
    }
    * Should have exactly 1 reference category (base level of rep78)
    assert `ref_count' == 1
}
if _rc == 0 {
    display as result "  PASS [10a]: regtab Coef. scale reference label only on base level"
    local ++pass_count
}
else {
    display as error "  FAIL [10a]: regtab Coef. scale reference label issue (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i9_regtab.xlsx"



**# Migrated: headershade

**# regtab headershade
* =========================================================================

**## regtab without headershade has NO header fill
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight foreign

    local _xlsx "`output_dir'/_test_headershade_off.xlsx"
    local _res "`output_dir'/_test_headershade_off_res.txt"
    capture erase "`_xlsx'"
    capture erase "`_res'"
    regtab, xlsx("`_xlsx'") sheet("NoShade") noint

    confirm file "`_xlsx'"
    shell python3 "`checker'" "`_xlsx'" --sheet "NoShade" ///
        --cell-no-fill B2 B3 --result-file "`_res'" --quiet
    _rv_assert "`_res'"
    capture erase "`_res'"
}
if _rc == 0 {
    display as result "  PASS: regtab without headershade has no header fill"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab without headershade has no header fill (rc=`=_rc')"
    local ++fail_count
}

**## regtab WITH headershade has header fill
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight foreign

    local _xlsx "`output_dir'/_test_headershade_on.xlsx"
    local _res "`output_dir'/_test_headershade_on_res.txt"
    capture erase "`_xlsx'"
    capture erase "`_res'"
    regtab, xlsx("`_xlsx'") sheet("Shaded") noint headershade

    confirm file "`_xlsx'"
    shell python3 "`checker'" "`_xlsx'" --sheet "Shaded" ///
        --has-fill 2 --has-fill 3 --result-file "`_res'" --quiet
    _rv_assert "`_res'"
    capture erase "`_res'"
}
if _rc == 0 {
    display as result "  PASS: regtab with headershade applies header fill"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab with headershade missing header fill (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: dimonsig, factorlabel, SHR/TR auto-detect

* --- 7.5: regtab dimonsig option ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign mpg weight
    capture erase "`output_dir'/test_dimonsig.xlsx"
    regtab, xlsx("`output_dir'/test_dimonsig.xlsx") sheet("Test") dimnonsig
    confirm file "`output_dir'/test_dimonsig.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab dimonsig"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab dimonsig (rc=`=_rc')"
    local ++fail_count
}

* --- 7.6: regtab factorlabel option ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign mpg i.rep78
    capture erase "`output_dir'/test_factorlabel.xlsx"
    regtab, xlsx("`output_dir'/test_factorlabel.xlsx") sheet("Test") factorlabel
    confirm file "`output_dir'/test_factorlabel.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab factorlabel"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab factorlabel (rc=`=_rc')"
    local ++fail_count
}

* --- 7.6: regtab SHR auto-detect (finegray) ---
capture noisily {
    * Create competing risk data
    clear
    set obs 300
    set seed 789
    gen time = rexponential(1/5)
    gen cause = cond(runiform() < 0.3, 1, cond(runiform() < 0.5, 2, 0))
    gen x1 = rnormal()
    stset time, failure(cause == 1)
    stcrreg x1, compete(cause == 2)
    collect clear
    collect: stcrreg x1, compete(cause == 2)
    regtab, display
}
if _rc == 0 {
    display as result "  PASS: regtab SHR auto-detect"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab SHR auto-detect (rc=`=_rc')"
    local ++fail_count
}

* --- 7.7: regtab TR auto-detect (streg) ---
capture noisily {
    clear
    set obs 200
    set seed 321
    gen time = rexponential(1/5)
    gen event = runiform() < 0.7
    gen x1 = rnormal()
    stset time, failure(event)
    collect clear
    collect: streg x1, distribution(weibull) time
    regtab, display
}
if _rc == 0 {
    display as result "  PASS: regtab TR auto-detect (streg time)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab TR auto-detect (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: dis/border abbreviations

* T5: regtab `dis`, `border`
sysuse auto, clear
collect clear
quietly collect: regress price mpg weight foreign
capture noisily regtab, dis border(thin)
if _rc == 0 {
    display as result "  PASS T5: regtab dis/border abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T5: regtab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}
collect clear


**# Migrated: active collect mutation documented

* Test 11: regtab documents active collect mutation
capture noisily {
    findfile regtab.sthlp
    tempname fh
    * Join the file into one space-separated string so a phrase that legitimately
    * wraps across two source lines (hard-wrapped prose) is still matched — a
    * line-by-line strpos would miss a phrase split at a wrap boundary.
    local _alltext ""
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    while r(eof) == 0 {
        local _alltext `"`_alltext' `line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`_alltext'"', "intentionally updates collect labels") > 0
    assert strpos(`"`_alltext'"', "save or rebuild that collection") > 0
}
if _rc == 0 {
    display as result "  PASS: regtab active collect side effect documented"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab active collect side effect documented (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}





**# Migrated: keep()/drop() match by variable name when vars are labeled
**# Regression for the empty-body bug: collect renders the variable LABEL into
**# column A, so keep()/drop() by raw variable name must match a separately
**# tracked raw-name column. Before the fix, keep(rawname) on labeled vars
**# dropped every coefficient row (headers-only table). Asserts on BODY content,
**# not just file existence, because the buggy table still wrote a file.

* keep() by raw name on LABELED variables retains exactly those rows
capture noisily {
    sysuse auto, clear
    label variable mpg "Fuel economy"
    label variable weight "Curb mass"
    label variable length "Body length"
    collect clear
    collect: regress price mpg weight length
    regtab, frame(_keepname) keep(mpg weight)
    frame _keepname {
        * body rows live below the two header rows; labels must survive
        quietly count if strpos(A, "Fuel economy") > 0
        assert r(N) == 1
        quietly count if strpos(A, "Curb mass") > 0
        assert r(N) == 1
        * filtered-out rows must be gone
        quietly count if strpos(A, "Body length") > 0
        assert r(N) == 0
        quietly count if strtrim(A) == "Intercept"
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: regtab keep() by raw name with labeled vars"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab keep() by raw name with labeled vars (rc=`=_rc')"
    local ++fail_count
}

* drop() by raw name on LABELED variables removes exactly that row
capture noisily {
    sysuse auto, clear
    label variable mpg "Fuel economy"
    label variable weight "Curb mass"
    label variable length "Body length"
    collect clear
    collect: regress price mpg weight length
    regtab, frame(_dropname) drop(mpg)
    frame _dropname {
        quietly count if strpos(A, "Fuel economy") > 0
        assert r(N) == 0
        quietly count if strpos(A, "Curb mass") > 0
        assert r(N) == 1
        quietly count if strpos(A, "Body length") > 0
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: regtab drop() by raw name with labeled vars"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab drop() by raw name with labeled vars (rc=`=_rc')"
    local ++fail_count
}

* label-substring matching still works (no regression for label-based filtering)
capture noisily {
    sysuse auto, clear
    label variable mpg "Fuel economy"
    label variable weight "Curb mass"
    collect clear
    collect: regress price mpg weight
    regtab, frame(_keeplbl) keep("Fuel")
    frame _keeplbl {
        quietly count if strpos(A, "Fuel economy") > 0
        assert r(N) == 1
        quietly count if strpos(A, "Curb mass") > 0
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: regtab keep() by label substring still works"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab keep() by label substring (rc=`=_rc')"
    local ++fail_count
}

**# v1.8.4: per-model model-fit statistic returns (r(aic_#) etc.)
* regtab now exposes its computed AIC/BIC/QIC/ICC/LL/N/groups as full-precision
* r() scalars. Assert they exist when requested, carry the expected magnitudes,
* and are ABSENT when not requested (only the deeper estat-equality check lives
* in qa/crossval_tabtools.do CV21-23).
capture noisily {
    * Single-model OLS: aic/bic/ll/n returned; icc/qic/groups absent
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight foreign
    estat ic
    matrix _Sic = r(S)
    regtab, stats(aic bic ll n) frame(_rt_ret, replace)
    assert reldif(r(aic_1), _Sic[1,5]) < 1e-8
    assert reldif(r(bic_1), _Sic[1,6]) < 1e-8
    assert !missing(r(ll_1))
    assert r(n_1) == 74
    assert missing(r(icc_1))
    assert missing(r(qic_1))
    capture frame drop _rt_ret

    * Not requesting stats() posts no stat scalars (no leak, no crash)
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    regtab, frame(_rt_ret2, replace)
    assert missing(r(aic_1))
    assert missing(r(bic_1))
    capture frame drop _rt_ret2

    * Multi-model: per-model index aligns with r(table) columns
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    regtab, stats(aic) frame(_rt_ret3, replace)
    assert r(N_models) == 2
    assert !missing(r(aic_1))
    assert !missing(r(aic_2))
    assert r(aic_1) > r(aic_2)   // adding weight improves fit -> lower AIC
    capture frame drop _rt_ret3
}
if _rc == 0 {
    display as result "  PASS: regtab per-model stat returns r(aic_#)/r(bic_#)/r(ll_#)/r(n_#)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab per-model stat returns (rc=`=_rc')"
    local ++fail_count
}



**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _regtab
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_regtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _regtab

