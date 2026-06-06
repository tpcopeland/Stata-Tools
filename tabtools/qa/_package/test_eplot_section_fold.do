*! test_eplot_section_fold.do - QA for single-row section folding in eplot frames
*!
*! A section that owns exactly one plotted row is redundant in a forest plot.
*! comptab/hrcomptab now fold the section label into that single row in the
*! eplot companion frame, while the rendered Excel/console table is unchanged.

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

capture log close _eplot_fold
log using "`output_dir'/test_eplot_section_fold.log", replace text name(_eplot_fold)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fold_result
program define _fold_result
    args ok msg
    if `ok' {
        display as result "  PASS: `msg'"
    }
    else {
        display as error "  FAIL: `msg' (rc=`=_rc')"
    }
end

foreach fr in _ef_m1 _ef_m1_ep _ef_m2 _ef_m2_ep _ef_multi _ef_multi_ep ///
    _ef_comp _ef_comp_ep _ef_comp_ns _ef_comp_ns_ep _ef_comp_mx _ef_comp_mx_ep ///
    _ef_rates _ef_hr_model _ef_hr_model_ep _ef_hr _ef_hr_ep {
    capture frame drop `fr'
}

* Two single-coefficient model frames (one selected row each)
sysuse auto, clear
collect clear
collect: regress price mpg weight
regtab, frame(_ef_m1, replace) eplotframe(_ef_m1_ep, replace) noint coef("b")

collect clear
collect: regress price mpg weight length
regtab, frame(_ef_m2, replace) eplotframe(_ef_m2_ep, replace) noint coef("b")

* A model frame contributing two selected rows under one section
collect clear
collect: regress price mpg weight length
regtab, frame(_ef_multi, replace) eplotframe(_ef_multi_ep, replace) noint coef("b")

* -------------------------------------------------------------------------
* 1. Single-row sections fold: label replaced, no standalone section rows
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    comptab _ef_m1 _ef_m2, rows(1 \ 1) section("Crude" \ "Adjusted") ///
        frame(_ef_comp, replace) eplotframe(_ef_comp_ep, replace)

    frame _ef_comp_ep {
        count if rowtype == "section"
        assert r(N) == 0
        count if rowtype == "effect"
        assert r(N) == 2
        * Folded rows carry the section label, not the coefficient name
        count if label == "Crude" & rowtype == "effect" & estimate < .
        assert r(N) == 1
        count if label == "Adjusted" & rowtype == "effect" & estimate < .
        assert r(N) == 1
        count if label == "mpg"
        assert r(N) == 0
        * The section column still records provenance
        count if section == "Crude"
        assert r(N) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "single-row sections fold label into the effect row"
}
else {
    local ++fail_count
    _fold_result 0 "single-row sections fold label into the effect row"
}

* -------------------------------------------------------------------------
* 2. Rendered table is unchanged: section headers still present in display frame
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    frame _ef_comp {
        count if A == "Crude"
        assert r(N) == 1
        count if A == "Adjusted"
        assert r(N) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "rendered table keeps its section header rows"
}
else {
    local ++fail_count
    _fold_result 0 "rendered table keeps its section header rows"
}

* -------------------------------------------------------------------------
* 3. Multi-row section keeps its header and original row labels
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    comptab _ef_multi, rows(1 2) section("Block") ///
        frame(_ef_comp_mx, replace) eplotframe(_ef_comp_mx_ep, replace)

    frame _ef_comp_mx_ep {
        count if rowtype == "section" & label == "Block"
        assert r(N) == 1
        count if rowtype == "effect"
        assert r(N) == 2
        * Two-child section retains the coefficient names, not the section label
        count if label == "Block" & rowtype == "effect"
        assert r(N) == 0
        count if rowtype == "effect" & section == "Block"
        assert r(N) == 2
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "multi-row section keeps header and original labels"
}
else {
    local ++fail_count
    _fold_result 0 "multi-row section keeps header and original labels"
}

* -------------------------------------------------------------------------
* 4. No section() requested: baseline unchanged (no section rows, real labels)
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    comptab _ef_m1 _ef_m2, rows(1 \ 1) ///
        frame(_ef_comp_ns, replace) eplotframe(_ef_comp_ns_ep, replace)

    frame _ef_comp_ns_ep {
        count if rowtype == "section"
        assert r(N) == 0
        count if rowtype == "effect"
        assert r(N) == 2
        * Original source labels (variable labels) are preserved, not folded
        count if label == "Mileage (mpg)" & rowtype == "effect"
        assert r(N) == 2
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "no section() leaves companion frame unchanged"
}
else {
    local ++fail_count
    _fold_result 0 "no section() leaves companion frame unchanged"
}

* -------------------------------------------------------------------------
* 5. hrcomptab multi-child section (reference + effect) still emits its header
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
    label define _ef_exp 0 "None" 1 "Current", replace
    label values exposure _ef_exp
    save "`rate1'.dta", replace

    clear
    stratetab, using(`rate1') outcomes(1) frame(_ef_rates, replace) ///
        outlabels("Outcome") explabels("Exposure")

    clear
    set obs 80
    set seed 60606
    gen byte treated = mod(_n, 2)
    gen double yv = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress yv treated
    regtab, frame(_ef_hr_model, replace) eplotframe(_ef_hr_model_ep, replace) ///
        noint coef("aHR")

    hrcomptab _ef_rates, modelframes(_ef_hr_model) rows(1) effect("aHR") ///
        frame(_ef_hr, replace) eplotframe(_ef_hr_ep, replace)

    frame _ef_hr_ep {
        * "Exposure" owns a reference ("None") + one effect ("Current"):
        * two children, so the section header is retained, not folded.
        count if rowtype == "section"
        assert r(N) >= 1
        count if rowtype == "effect"
        assert r(N) >= 1
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "hrcomptab multi-child section retains its header"
}
else {
    local ++fail_count
    _fold_result 0 "hrcomptab multi-child section retains its header"
}

foreach fr in _ef_m1 _ef_m1_ep _ef_m2 _ef_m2_ep _ef_multi _ef_multi_ep ///
    _ef_comp _ef_comp_ep _ef_comp_ns _ef_comp_ns_ep _ef_comp_mx _ef_comp_mx_ep ///
    _ef_rates _ef_hr_model _ef_hr_model_ep _ef_hr _ef_hr_ep {
    capture frame drop `fr'
}

display _newline as text "tabtools eplot section-fold QA: `pass_count'/`test_count' passed"
log close _eplot_fold

if `fail_count' > 0 {
    exit 9
}
