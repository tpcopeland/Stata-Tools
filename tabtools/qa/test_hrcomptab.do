*! test_hrcomptab.do - Focused QA for hrcomptab

clear all
set varabbrev off
version 17.0

capture log close _hrcomptab
log using "test_hrcomptab.log", replace text name(_hrcomptab)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local xlsx_checker "`qa_dir'/tools/check_xlsx.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

* -------------------------------------------------------------------------
* Build stable rate/model frames once
* -------------------------------------------------------------------------
tempfile rate11 rate12 rate21 rate22

clear
set obs 2
gen exposure = _n - 1
gen double _D = cond(_n == 1, 10, 20)
gen double _Y = cond(_n == 1, 1000, 1100)
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label variable _Lower "Lower 95% confidence limit"
label variable _Upper "Upper 95% confidence limit"
label define _hrc_exp2 0 "None" 1 "Current", replace
label values exposure _hrc_exp2
save "`rate11'.dta", replace

clear
set obs 2
gen exposure = _n - 1
gen double _D = cond(_n == 1, 5, 8)
gen double _Y = cond(_n == 1, 900, 950)
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label variable _Lower "Lower 95% confidence limit"
label variable _Upper "Upper 95% confidence limit"
label define _hrc_exp2b 0 "None" 1 "Current", replace
label values exposure _hrc_exp2b
save "`rate12'.dta", replace

clear
set obs 3
gen exposure = _n - 1
gen double _D = cond(_n == 1, 10, cond(_n == 2, 4, 6))
gen double _Y = cond(_n == 1, 1000, cond(_n == 2, 300, 400))
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label variable _Lower "Lower 95% confidence limit"
label variable _Upper "Upper 95% confidence limit"
label define _hrc_exp3 0 "None" 1 "Low" 2 "High", replace
label values exposure _hrc_exp3
save "`rate21'.dta", replace

clear
set obs 3
gen exposure = _n - 1
gen double _D = cond(_n == 1, 5, cond(_n == 2, 2, 4))
gen double _Y = cond(_n == 1, 900, cond(_n == 2, 250, 350))
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label variable _Lower "Lower 95% confidence limit"
label variable _Upper "Upper 95% confidence limit"
label define _hrc_exp3b 0 "None" 1 "Low" 2 "High", replace
label values exposure _hrc_exp3b
save "`rate22'.dta", replace

clear
stratetab, using(`rate11' `rate12' `rate21' `rate22') outcomes(2) ///
    frame(hrc_rates, replace) ///
    outlabels("Outcome 1" \ "Outcome 2") ///
    outcomeids("t1" \ "t2") ///
    explabels("Binary HRT" \ "Dose Category")

clear
set obs 240
set seed 20260417
gen byte treated = mod(_n, 2)
gen double t1 = 1 + 12 * runiform() * exp(-0.35 * treated)
gen byte d1 = mod(_n, 4) != 0
gen double t2 = 1 + 10 * runiform() * exp(-0.20 * treated)
gen byte d2 = mod(_n, 5) != 0
collect clear
stset t1, failure(d1)
collect: stcox treated, nolog
stset t2, failure(d2)
collect: stcox treated, nolog
capture frame drop hrc_bin
capture frame drop hrc_bin_plot
regtab, models("Outcome 1" \ "Outcome 2") frame(hrc_bin) ///
    eplotframe(hrc_bin_plot, replace) noint
capture frame drop hrc_bin_comp
capture frame drop hrc_bin_comp_plot
regtab, models("Outcome 1" \ "Outcome 2") compact frame(hrc_bin_comp) ///
    eplotframe(hrc_bin_comp_plot, replace) noint

* A semantically identical source with model blocks intentionally reversed.
collect clear
stset t2, failure(d2)
collect: stcox treated, nolog
stset t1, failure(d1)
collect: stcox treated, nolog
capture frame drop hrc_bin_rev
regtab, models("Outcome 2" \ "Outcome 1") frame(hrc_bin_rev) noint

clear
set obs 300
set seed 20260418
gen byte dose = mod(_n, 3)
gen double t1 = 1 + 12 * runiform() * exp(-0.20 * (dose == 1) - 0.35 * (dose == 2))
gen byte d1 = mod(_n, 4) != 0
gen double t2 = 1 + 10 * runiform() * exp(-0.10 * (dose == 1) - 0.25 * (dose == 2))
gen byte d2 = mod(_n, 5) != 0
collect clear
stset t1, failure(d1)
collect: stcox i.dose, nolog
stset t2, failure(d2)
collect: stcox i.dose, nolog
capture frame drop hrc_dose
capture frame drop hrc_dose_plot
regtab, models("Outcome 1" \ "Outcome 2") frame(hrc_dose) ///
    eplotframe(hrc_dose_plot, replace) noint

capture frame drop hrc_cmp3
frame copy hrc_bin_comp hrc_cmp3
frame hrc_cmp3 {
    gen str244 c5 = c1
    gen str244 c6 = c2
}

* -------------------------------------------------------------------------
* 1. rows() workflow with frame output
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_final
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rows(1 \ 3/4) ///
	        outcomemap("Outcome 1" \ "Outcome 2") ///
        effect("aHR") ///
        frame(hrc_final, replace)

    assert r(N_outcomes) == 2
    assert r(N_sections) == 2
    assert r(N_modelrows) == 3
    assert "`r(frame)'" == "hrc_final"
    assert "`r(modelframes)'" == "hrc_bin hrc_dose"
    assert "`r(effect)'" == "aHR"

    frame hrc_final {
        assert _N == 10
        assert c1[4] == "Binary HRT"
        assert c1[7] == "Dose Category"
        assert c5[5] == "Reference"
        assert c10[5] == "Reference"
        assert c5[8] == "Reference"
        assert c10[8] == "Reference"
        assert strpos(c5[6], "(") > 0
        assert strpos(c10[6], "(") > 0
        assert c6[6] != "p-value"
        assert c11[6] != "p-value"
    }
    capture frame drop hrc_final
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rows() composes the final scaffold"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rows() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final

**# 1a. Unified comptab rate mode matches the compatibility wrapper
local ++test_count
capture noisily {
    local _wrapper_xlsx "`output_dir'/hrcomptab_wrapper_parity.xlsx"
    local _direct_xlsx "`output_dir'/comptab_rate_parity.xlsx"
    local _xml_result "`output_dir'/comptab_rate_xml_parity.txt"
    capture erase "`_wrapper_xlsx'"
    capture erase "`_direct_xlsx'"
    capture erase "`_xml_result'"
    capture frame drop hrc_wrapper_parity
    capture frame drop hrc_direct_parity

    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
        effect("aHR") frame(hrc_wrapper_parity, replace) ///
        xlsx("`_wrapper_xlsx'") sheet("Parity")

    local _hr_N_rows = r(N_rows)
    local _hr_N_outcomes = r(N_outcomes)
    local _hr_N_sections = r(N_sections)
    local _hr_N_modelrows = r(N_modelrows)
    local _hr_N_modelframes = r(N_modelframes)
    local _hr_ci_level = r(ci_level)
    local _hr_rateframe "`r(rateframe)'"
    local _hr_modelframes "`r(modelframes)'"
    local _hr_effect "`r(effect)'"
    frame hrc_wrapper_parity: save "`output_dir'/hrcomptab_wrapper_parity.dta", replace

    comptab hrc_bin hrc_dose, rateframe(hrc_rates) ///
        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
        effect("aHR") frame(hrc_direct_parity, replace) ///
        xlsx("`_direct_xlsx'") sheet("Parity")

    assert r(N_rows) == `_hr_N_rows'
    assert r(N_outcomes) == `_hr_N_outcomes'
    assert r(N_sections) == `_hr_N_sections'
    assert r(N_modelrows) == `_hr_N_modelrows'
    assert r(N_modelframes) == `_hr_N_modelframes'
    assert !missing(r(ci_level), `_hr_ci_level')
    assert reldif(r(ci_level), `_hr_ci_level') < 1e-12
    assert "`r(rateframe)'" == "`_hr_rateframe'"
    assert "`r(modelframes)'" == "`_hr_modelframes'"
    assert "`r(effect)'" == "`_hr_effect'"
    frame hrc_direct_parity: cf _all using "`output_dir'/hrcomptab_wrapper_parity.dta"

    ! python3 -c "import sys,zipfile; a=zipfile.ZipFile(sys.argv[1]); b=zipfile.ZipFile(sys.argv[2]); names=[n for n in a.namelist() if n.startswith('xl/worksheets/') or n=='xl/styles.xml']; ok=set(names)==set(n for n in b.namelist() if n.startswith('xl/worksheets/') or n=='xl/styles.xml') and all(a.read(n)==b.read(n) for n in names); open(sys.argv[3],'w').write('PASS' if ok else 'FAIL')" "`_wrapper_xlsx'" "`_direct_xlsx'" "`_xml_result'"
    tempname _xfh
    file open `_xfh' using "`_xml_result'", read text
    file read `_xfh' _xml_line
    file close `_xfh'
    assert "`_xml_line'" == "PASS"

    capture frame drop hrc_wrapper_parity
    capture frame drop hrc_direct_parity
    capture erase "`output_dir'/hrcomptab_wrapper_parity.dta"
    capture erase "`_wrapper_xlsx'"
    capture erase "`_direct_xlsx'"
    capture erase "`_xml_result'"
}
if _rc == 0 {
    display as result "  PASS: comptab rate mode and hrcomptab have identical analytical output and workbook XML"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab/hrcomptab parity (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_wrapper_parity
capture frame drop hrc_direct_parity
capture erase "`output_dir'/hrcomptab_wrapper_parity.dta"
capture erase "`output_dir'/hrcomptab_wrapper_parity.xlsx"
capture erase "`output_dir'/comptab_rate_parity.xlsx"
capture erase "`output_dir'/comptab_rate_xml_parity.txt"

**# 1b. Explicit modelframes() mapping and mode-specific option guards
local ++test_count
capture noisily {
    comptab, rateframe(hrc_rates) modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2")
    assert r(N_outcomes) == 2
    assert "`r(rateframe)'" == "hrc_rates"
    assert "`r(modelframes)'" == "hrc_bin hrc_dose"

    capture comptab hrc_bin hrc_dose, rateframe(hrc_rates) ///
        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") compact
    assert _rc == 198

    capture comptab hrc_bin, rows(1) effect("aHR")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: comptab explicit rate mapping and mode-specific option guards"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab rate mapping/option guards (rc=`=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 1c. reflabel() overrides inferred reference text; r(rateframe) returns source
*     Clarity audit MINOR-4 (2026-06-13): reflabel and r(rateframe) untested.
*     Same rows()/effect() as test 1 so reference-row positions match.
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_reflab
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") effect("aHR") reflabel("Ref. group") ///
        frame(hrc_reflab, replace)

    assert "`r(rateframe)'" == "hrc_rates"

    frame hrc_reflab {
        assert c5[5]  == "Ref. group"
        assert c10[5] == "Ref. group"
        assert c5[8]  == "Ref. group"
        assert c10[8] == "Ref. group"
        * The default "Reference" text must no longer appear anywhere.
        local _saw_default 0
        foreach _v of varlist c* {
            quietly count if strtrim(`_v') == "Reference"
            if r(N) > 0 local _saw_default 1
        }
        assert `_saw_default' == 0
    }
    capture frame drop hrc_reflab
}
if _rc == 0 {
    display as result "  PASS: hrcomptab reflabel() + r(rateframe)"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab reflabel()/r(rateframe) (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_reflab

* -------------------------------------------------------------------------
* 2. rownames() workflow
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_final2
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rownames("treated" \ "1 2") outcomemap("Outcome 1" \ "Outcome 2") ///
        frame(hrc_final2, replace)
    assert r(N_modelrows) == 3
    frame hrc_final2 {
        assert c5[6] != ""
        assert c10[9] != ""
    }
    capture frame drop hrc_final2
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rownames() matches rendered labels"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rownames() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final2

* -------------------------------------------------------------------------
* 2b. rownames() minimum-abbreviation rown() (regression: ROWNAMES was
*     all-caps so rown() failed rc=198 despite the help documenting it)
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_final2b
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rown("treated" \ "1 2") outcomemap("Outcome 1" \ "Outcome 2") ///
        frame(hrc_final2b, replace)
    assert r(N_modelrows) == 3
    capture frame drop hrc_final2b
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rown() abbreviation accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rown() abbreviation (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final2b

* -------------------------------------------------------------------------
* 3. Reversed model blocks align to rate outcomes by explicit identity
* -------------------------------------------------------------------------
local ++test_count
frame hrc_bin: local _want_o1 = strtrim(c1[4] + " " + c2[4])
frame hrc_bin: local _want_o2 = strtrim(c4[4] + " " + c5[4])
capture noisily {
    capture frame drop hrc_reversed
    hrcomptab hrc_rates, modelframes(hrc_bin_rev hrc_dose) ///
        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
        frame(hrc_reversed, replace)
    frame hrc_reversed: assert c5[6] == `"`_want_o1'"'
    frame hrc_reversed: assert c10[6] == `"`_want_o2'"'
    frame hrc_reversed: assert c5[3] == "aHR (95% CI)"
    assert r(ci_level) == 95
}
if _rc == 0 {
    display as result "  PASS: hrcomptab aligns reversed model blocks and CI provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab reversed-model alignment (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_reversed

* -------------------------------------------------------------------------
* 3b. Ambiguous analytical outcome IDs require mapping; hostile provenance fails
* -------------------------------------------------------------------------
local ++test_count
capture frame drop hrc_by_id
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
    rows(1 \ 3/4) frame(hrc_by_id, replace)
local _hrc_by_id_rc = _rc
capture frame drop hrc_bad_ci
capture frame drop hrc_bad_scale
capture frame drop hrc_bad_stats
frame copy hrc_bin hrc_bad_ci
frame copy hrc_bin hrc_bad_scale
frame copy hrc_bin hrc_bad_stats
frame hrc_bad_ci: char _dta[tabtools_ci_level] "90"
frame hrc_bad_scale: char _dta[tabtools_effect_scale_1] "OR"
frame hrc_bad_stats: char _dta[tabtools_statistic_ids] "ci estimate pvalue"
frame hrc_bin: quietly datasignature
local _hrc_bin_sig `"`r(datasignature)'"'
capture noisily hrcomptab hrc_rates, modelframes(hrc_bad_ci hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2")
local _hrc_bad_ci_rc = _rc
capture noisily hrcomptab hrc_rates, modelframes(hrc_bad_scale hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2")
local _hrc_bad_scale_rc = _rc
capture noisily hrcomptab hrc_rates, modelframes(hrc_bad_stats hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2")
local _hrc_bad_stats_rc = _rc
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 1")
local _hrc_duplicate_map_rc = _rc
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Unknown" \ "Outcome 2")
local _hrc_unknown_map_rc = _rc
capture noisily {
    assert `_hrc_by_id_rc' == 198
    assert `_hrc_bad_ci_rc' == 198
    assert `_hrc_bad_scale_rc' == 198
    assert inlist(`_hrc_bad_stats_rc', 198, 459)
    assert `_hrc_duplicate_map_rc' == 198
    assert `_hrc_unknown_map_rc' == 198
    frame hrc_rates: local _hrc_id1 : char _dta[tabtools_outcome_id_1]
    frame hrc_rates: local _hrc_id2 : char _dta[tabtools_outcome_id_2]
    assert "`_hrc_id1'" == "t1"
    assert "`_hrc_id2'" == "t2"
    frame hrc_bin: quietly datasignature
    assert `"`r(datasignature)'"' == `"`_hrc_bin_sig'"'
}
if _rc == 0 {
    display as result "  PASS: hrcomptab enforces outcome, CI, statistic, and HR-scale provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab provenance adversaries (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_by_id
capture frame drop hrc_bad_ci
capture frame drop hrc_bad_scale
capture frame drop hrc_bad_stats

* -------------------------------------------------------------------------
* 4. Complete frame graph and post-stage rollback preserve every frame
* -------------------------------------------------------------------------
local ++test_count
capture frame drop hrc_tx_display
capture frame drop hrc_tx_plot
frame create hrc_tx_display
frame hrc_tx_display: set obs 1
frame hrc_tx_display: generate str20 sentinel = "display-old"
frame create hrc_tx_plot
frame hrc_tx_plot: set obs 1
frame hrc_tx_plot: generate str20 sentinel = "plot-old"
frame hrc_rates: quietly datasignature
local _hrc_rate_sig `"`r(datasignature)'"'
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
    frame(hrc_rates, replace)
local _hrc_source_alias_rc = _rc
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
    eplotframe(hrc_bin_plot, replace)
local _hrc_companion_alias_rc = _rc
global TABTOOLS_QA_HRC_STAGE_FAIL 1
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
    rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
    frame(hrc_tx_display, replace) eplotframe(hrc_tx_plot, replace)
local _hrc_stage_rc = _rc
global TABTOOLS_QA_HRC_STAGE_FAIL
capture noisily {
    assert `_hrc_source_alias_rc' == 198
    assert `_hrc_companion_alias_rc' == 198
    assert `_hrc_stage_rc' == 459
    frame hrc_rates: quietly datasignature
    assert `"`r(datasignature)'"' == `"`_hrc_rate_sig'"'
    frame hrc_tx_display: assert sentinel[1] == "display-old"
    frame hrc_tx_plot: assert sentinel[1] == "plot-old"
}
if _rc == 0 {
    display as result "  PASS: hrcomptab frame graph and post-stage rollback are non-destructive"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab frame transaction (rc=`=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 5. Ambiguous mixed layouts are rejected
* -------------------------------------------------------------------------
local ++test_count
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_cmp3) ///
 rows(1 \ 1)
if _rc == 198 {
    display as result "  PASS: hrcomptab rejects mixed standard/compact layouts"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab mixed-layout rejection (expected 198, got `=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 4. Explicit formatting reaches workbook styles
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    quietly tabtools set clear
    local xlsx "`output_dir'/test_hrcomptab_apa.xlsx"
    capture erase "`xlsx'"
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rows(1 \ 3/4) ///
	        outcomemap("Outcome 1" \ "Outcome 2") ///
        xlsx("`xlsx'") sheet("Style") font("Times New Roman") fontsize(12) ///
        borderstyle(academic) headershade zebra
    confirm file "`xlsx'"
    tempfile style_ok
    capture erase "`style_ok'"
    quietly shell python3 "`xlsx_checker'" "`xlsx'" --sheet "Style" ///
        --font "Times New Roman" --fontsize 12 ///
        --result-file "`style_ok'" --quiet
    confirm file "`style_ok'"
    tempname _apa_style_fh
    file open `_apa_style_fh' using "`style_ok'", read text
    file read `_apa_style_fh' _apa_style_result
    file close `_apa_style_fh'
    assert `"`_apa_style_result'"' == "PASS"
}
if _rc == 0 {
    display as result "  PASS: hrcomptab explicit formatting reaches workbook styles"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab explicit formatting workbook styles (rc=`=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 5. tabtools set font/fontsize defaults propagate into hrcomptab
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    quietly tabtools set clear
    quietly tabtools set font "Courier New"
    quietly tabtools set fontsize 13
    local xlsx "`output_dir'/test_hrcomptab_defaults.xlsx"
    capture erase "`xlsx'"
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rows(1 \ 3/4) ///
	        outcomemap("Outcome 1" \ "Outcome 2") ///
        excel("`xlsx'") sheet("Defaults")
    confirm file "`xlsx'"
    tempfile style_ok
    capture erase "`style_ok'"
    quietly shell python3 "`xlsx_checker'" "`xlsx'" --sheet "Defaults" ///
        --font "Courier New" --fontsize 13 ///
        --result-file "`style_ok'" --quiet
    confirm file "`style_ok'"
    tempname _default_style_fh
    file open `_default_style_fh' using "`style_ok'", read text
    file read `_default_style_fh' _default_style_result
    file close `_default_style_fh'
    assert `"`_default_style_result'"' == "PASS"
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: hrcomptab honors tabtools set font/fontsize defaults"
    local ++pass_count
}
else {
    local _test_rc = _rc
    capture noisily tabtools set clear
    display as error "  FAIL: hrcomptab persistent formatting defaults (rc=`_test_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 6. frame()-only output automatically previews the completed table
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    local preview_log "`output_dir'/test_hrcomptab_preview_off.log"
    capture erase "`preview_log'"
    capture log close _preview_off
    log using "`preview_log'", replace text name(_preview_off)
    capture frame drop hrc_nodisplay
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
        frame(hrc_nodisplay, replace)
    log close _preview_off
    local preview_text ""
    tempname fh
    file open `fh' using "`preview_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        local preview_text `"`preview_text'`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`preview_text'"', "Binary HRT") > 0
    capture frame drop hrc_nodisplay
}
if _rc == 0 {
    display as result "  PASS: hrcomptab frame()-only path auto-previews"
    local ++pass_count
}
else {
    capture log close _preview_off
    display as error "  FAIL: hrcomptab frame()-only auto-preview (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_nodisplay

* -------------------------------------------------------------------------
* 7. table is previewed to the console by default
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    local preview_log "`output_dir'/test_hrcomptab_preview_on.log"
    capture erase "`preview_log'"
    capture log close _preview_on
    log using "`preview_log'", replace text name(_preview_on)
    capture frame drop hrc_display
	    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
	        rows(1 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2") ///
        frame(hrc_display, replace)
    log close _preview_on
    local preview_text ""
    tempname fh
    file open `fh' using "`preview_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        local preview_text `"`preview_text'`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`preview_text'"', "Binary HRT") > 0
    capture frame drop hrc_display
}
if _rc == 0 {
    display as result "  PASS: hrcomptab previews to console by default"
    local ++pass_count
}
else {
    capture log close _preview_on
    display as error "  FAIL: hrcomptab console preview (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_display
**# Migrated: xlsx success message

**# 5. hrcomptab xlsx success message is visible

**## 5a. Export confirmation message appears in log output
capture noisily {
    * Build minimal stratetab frame
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    label define _hrc_exp 0 "None" 1 "Current", replace
    label values exposure _hrc_exp
    tempfile hrc_rate
    save "`hrc_rate'.dta", replace

    clear
    capture frame drop _hrc_rf
    stratetab, using(`hrc_rate') outcomes(1) frame(_hrc_rf, replace)

    * Build minimal regtab frame
    clear
	    set obs 120
	    set seed 20260427
	    gen byte treated = mod(_n, 2)
	    gen double time = 1 + 10 * runiform() * exp(-0.30 * treated)
	    gen byte failed = mod(_n, 4) != 0
	    stset time, failure(failed)
	    collect clear
	    collect: stcox treated, nolog
	    capture frame drop _hrc_mf
	    regtab, models("Event") frame(_hrc_mf) noint

    * Run hrcomptab with xlsx and capture output to a file
    clear
    local hrclog_path "`output_dir'/_rev1013_hrc_check"
    capture log close _hrccheck
    log using "`hrclog_path'", replace text name(_hrccheck)
	    hrcomptab _hrc_rf, modelframes(_hrc_mf) rows(1) outcomemap(Event) ///
        xlsx("`output_dir'/_rev1013_hrcomptab.xlsx") ///
        sheet("Test")
    log close _hrccheck

    * Read back the log and search for the success message
    tempname fh2
    local found_msg 0
    file open `fh2' using "`hrclog_path'.log", read text
    file read `fh2' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Exported") > 0 & strpos(`"`line'"', "cols to") > 0 {
            local found_msg 1
        }
        file read `fh2' line
    }
    file close `fh2'
    assert `found_msg' == 1

    * Cleanup frames
    capture frame drop _hrc_rf
    capture frame drop _hrc_mf
}
if _rc == 0 {
    display as result "  PASS [5a]: hrcomptab xlsx success message visible in output"
    local ++pass_count
}
else {
    display as error "  FAIL [5a]: hrcomptab xlsx success message not found (rc=`=_rc')"
    local ++fail_count
    capture frame drop _hrc_rf
    capture frame drop _hrc_mf
}
capture erase "`output_dir'/_rev1013_hrcomptab.xlsx"
capture erase "`output_dir'/_rev1013_hrc_check.log"



**# Migrated: rownames() pattern matching

**# QA Gap 5: hrcomptab rownames() pattern matching

**## 5a. rownames() with unique match works
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    gen byte agecat = cond(age < 55, 1, cond(age < 65, 2, 3))
    label define agelab 1 "<55" 2 "55-64" 3 "65+"
    label values agecat agelab

    * Use a real file path (tempfile gets cleaned up inside capture noisily)
    local _strate_path "`output_dir'/_test_strate_5a"
    capture erase "`_strate_path'.dta"
    strate agecat, per(1000) output("`_strate_path'", replace)

    capture frame drop _str_test
    stratetab, using("`_strate_path'") outcomes(1) ///
        outlabels("Event") explabels("Age") frame(_str_test)

    collect clear
    collect: stcox i.agecat, nolog
    capture frame drop _reg_test
 regtab, models("Event") frame(_reg_test) coef(HR)

    * hrcomptab with rownames — "55" should match "55-64" in regtab
    capture frame drop _hrc_test
    hrcomptab _str_test, modelframes(_reg_test) ///
	 rownames(55) outcomemap(Event) frame(_hrc_test)

    frame _hrc_test {
        assert _N > 3
    }
    capture frame drop _hrc_test
    capture frame drop _str_test
    capture frame drop _reg_test
    capture erase "`_strate_path'.dta"
}
if _rc == 0 {
    display as result "  PASS [5a]: hrcomptab rownames() with unique match"
    local ++pass_count
}
else {
    display as error "  FAIL [5a]: hrcomptab rownames (rc=`=_rc')"
    local ++fail_count
}

**## 5b. rownames() with non-matching pattern errors correctly
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    gen byte agecat = cond(age < 55, 1, cond(age < 65, 2, 3))
    label define agelab2 1 "<55" 2 "55-64" 3 "65+"
    label values agecat agelab2

    local _strate_path2 "`output_dir'/_test_strate_5b"
    capture erase "`_strate_path2'.dta"
    strate agecat, per(1000) output("`_strate_path2'", replace)

    capture frame drop _str_test2
    stratetab, using("`_strate_path2'") outcomes(1) ///
        outlabels("Event") explabels("Age") frame(_str_test2)

    collect clear
    collect: stcox i.agecat, nolog
    capture frame drop _reg_test2
 regtab, models("Event") frame(_reg_test2) coef(HR)

	    capture hrcomptab _str_test2, modelframes(_reg_test2) ///
	 rownames(NONEXISTENT_PATTERN) outcomemap(Event)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS [5b]: hrcomptab rownames() with no match errors rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL [5b]: hrcomptab non-matching rownames should give rc=198, got rc=`=_rc'"
    local ++fail_count
}
capture frame drop _str_test2
capture frame drop _reg_test2
capture erase "`output_dir'/_test_strate_5b.dta"





display as result "hrcomptab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_hrcomptab tests=`_tc' pass=`pass_count' fail=`fail_count'"
quietly tabtools set clear
if `fail_count' > 0 exit 1

log close _hrcomptab
