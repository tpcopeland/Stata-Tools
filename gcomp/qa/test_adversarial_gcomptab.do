* test_adversarial_gcomptab.do - Adversarial QA for gcomptab Excel/reporting
* Covers: e() contracts, matrix validation, named column lookup, option/path
*         validation, workbook replacement, xlsx cell fidelity, varabbrev, e().

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local testdir "`c(tmpdir)'"
local orig_varabbrev = c(varabbrev)

do "`qa_dir'/_qa_bootstrap.do"

capture which gcomptab
assert _rc == 0

**# Helpers

capture program drop _adv_mock_gcomp
program define _adv_mock_gcomp, eclass
    version 16.0
    syntax [, SCRAMBLED NOCDE ANALYSIS(string) MEDTYPE(string)]

    if "`analysis'" == "" local analysis "mediation"
    if "`medtype'" == "" local medtype "obe"

    tempname b V se_mat cin cip cibc cibca

    if "`nocde'" != "" {
        matrix `b' = (0.4321, 0.2102, 0.2219, 0.5136)
        matrix colnames `b' = tce nde nie pm
        matrix `V' = J(4, 4, 0)
        matrix colnames `V' = tce nde nie pm
        matrix rownames `V' = tce nde nie pm
        matrix `se_mat' = (0.0600, 0.0500, 0.0300, 0.1000)
        matrix colnames `se_mat' = tce nde nie pm
        matrix `cin' = (0.3145, 0.1122, 0.1631, 0.3176 \ ///
                        0.5497, 0.3082, 0.2807, 0.7096)
        matrix colnames `cin' = tce nde nie pm
    }
    else if "`scrambled'" != "" {
        matrix `b' = (0.5136, 0.1955, 0.2219, 0.4321, 0.2102)
        matrix colnames `b' = pm cde nie tce nde
        matrix `V' = J(5, 5, 0)
        matrix colnames `V' = pm cde nie tce nde
        matrix rownames `V' = pm cde nie tce nde
        matrix `se_mat' = (0.1000, 0.0400, 0.0300, 0.0600, 0.0500)
        matrix colnames `se_mat' = pm cde nie tce nde
        matrix `cin' = (0.3176, 0.1171, 0.1631, 0.3145, 0.1122 \ ///
                        0.7096, 0.2739, 0.2807, 0.5497, 0.3082)
        matrix colnames `cin' = pm cde nie tce nde
    }
    else {
        matrix `b' = (0.4321, 0.2102, 0.2219, 0.5136, 0.1955)
        matrix colnames `b' = tce nde nie pm cde
        matrix `V' = J(5, 5, 0)
        matrix colnames `V' = tce nde nie pm cde
        matrix rownames `V' = tce nde nie pm cde
        matrix `se_mat' = (0.0600, 0.0500, 0.0300, 0.1000, 0.0400)
        matrix colnames `se_mat' = tce nde nie pm cde
        matrix `cin' = (0.3145, 0.1122, 0.1631, 0.3176, 0.1171 \ ///
                        0.5497, 0.3082, 0.2807, 0.7096, 0.2739)
        matrix colnames `cin' = tce nde nie pm cde
    }

    forvalues j = 1/`=colsof(`V')' {
        matrix `V'[`j', `j'] = 0.01
    }

    matrix `cip' = `cin'
    matrix `cibc' = `cin'
    matrix `cibca' = `cin'
    matrix colnames `cip' = `: colnames `cin''
    matrix colnames `cibc' = `: colnames `cin''
    matrix colnames `cibca' = `: colnames `cin''

    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "`analysis'"
    ereturn local mediation_type "`medtype'"
    ereturn scalar tce = 0.4321
    ereturn scalar nde = 0.2102
    ereturn scalar nie = 0.2219
    ereturn scalar pm = 0.5136
    if "`nocde'" == "" {
        ereturn scalar cde = 0.1955
    }
    ereturn matrix se = `se_mat'
    ereturn matrix ci_normal = `cin'
    ereturn matrix ci_percentile = `cip'
    ereturn matrix ci_bc = `cibc'
    ereturn matrix ci_bca = `cibca'
end

capture program drop _adv_mock_no_analysis
program define _adv_mock_no_analysis, eclass
    version 16.0
    tempname b V se_mat cin
    matrix `b' = (0.4321, 0.2102, 0.2219, 0.5136, 0.1955)
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = I(5)
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local mediation_type "obe"
    matrix `se_mat' = (0.0600, 0.0500, 0.0300, 0.1000, 0.0400)
    matrix colnames `se_mat' = tce nde nie pm cde
    ereturn matrix se = `se_mat'
    matrix `cin' = (0.3145, 0.1122, 0.1631, 0.3176, 0.1171 \ ///
                    0.5497, 0.3082, 0.2807, 0.7096, 0.2739)
    matrix colnames `cin' = tce nde nie pm cde
    ereturn matrix ci_normal = `cin'
end

capture program drop _adv_mock_bad_b_missing
program define _adv_mock_bad_b_missing, eclass
    version 16.0
    tempname b V se_mat cin
    matrix `b' = (0.4321, 0.2102, 0.5136, 0.1955)
    matrix colnames `b' = tce nde pm cde
    matrix `V' = I(4)
    matrix colnames `V' = tce nde pm cde
    matrix rownames `V' = tce nde pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix `se_mat' = (0.0600, 0.0500, 0.1000, 0.0400)
    matrix colnames `se_mat' = tce nde pm cde
    ereturn matrix se = `se_mat'
    matrix `cin' = J(2, 4, 0.1)
    matrix colnames `cin' = tce nde pm cde
    ereturn matrix ci_normal = `cin'
end

capture program drop _adv_mock_extra_no_cde
program define _adv_mock_extra_no_cde, eclass
    version 16.0
    tempname b V se_mat cin
    matrix `b' = (0.4321, 0.2102, 0.2219, 0.5136, 0.9999)
    matrix colnames `b' = tce nde nie pm extra
    matrix `V' = I(5)
    matrix colnames `V' = tce nde nie pm extra
    matrix rownames `V' = tce nde nie pm extra
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix `se_mat' = (0.0600, 0.0500, 0.0300, 0.1000, 0.0400)
    matrix colnames `se_mat' = tce nde nie pm extra
    ereturn matrix se = `se_mat'
    matrix `cin' = J(2, 5, 0.1)
    matrix colnames `cin' = tce nde nie pm extra
    ereturn matrix ci_normal = `cin'
end

capture program drop _adv_mock_bad_se_missing
program define _adv_mock_bad_se_missing, eclass
    version 16.0
    tempname b V se_mat cin
    matrix `b' = (0.4321, 0.2102, 0.2219, 0.5136, 0.1955)
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = I(5)
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix `se_mat' = (0.0600, 0.0500, 0.0300, 0.0400)
    matrix colnames `se_mat' = tce nde nie cde
    ereturn matrix se = `se_mat'
    matrix `cin' = (0.3145, 0.1122, 0.1631, 0.3176, 0.1171 \ ///
                    0.5497, 0.3082, 0.2807, 0.7096, 0.2739)
    matrix colnames `cin' = tce nde nie pm cde
    ereturn matrix ci_normal = `cin'
end

capture program drop _adv_mock_bad_ci_dim
program define _adv_mock_bad_ci_dim, eclass
    version 16.0
    _adv_mock_gcomp
    tempname badci
    matrix `badci' = J(3, 5, 0.1)
    matrix colnames `badci' = tce nde nie pm cde
    ereturn matrix ci_normal = `badci'
end

capture program drop _adv_mock_bad_ci_names
program define _adv_mock_bad_ci_names, eclass
    version 16.0
    _adv_mock_gcomp
    tempname badci
    matrix `badci' = J(2, 5, 0.1)
    matrix colnames `badci' = tce nde nie cde extra
    ereturn matrix ci_normal = `badci'
end

capture program drop _adv_mock_missing_percentile
program define _adv_mock_missing_percentile, eclass
    version 16.0
    tempname b V se_mat cin
    matrix `b' = (0.4321, 0.2102, 0.2219, 0.5136, 0.1955)
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = I(5)
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix `se_mat' = (0.0600, 0.0500, 0.0300, 0.1000, 0.0400)
    matrix colnames `se_mat' = tce nde nie pm cde
    ereturn matrix se = `se_mat'
    matrix `cin' = (0.3145, 0.1122, 0.1631, 0.3176, 0.1171 \ ///
                    0.5497, 0.3082, 0.2807, 0.7096, 0.2739)
    matrix colnames `cin' = tce nde nie pm cde
    ereturn matrix ci_normal = `cin'
end

**# E() Contract Handling

local ++test_count
local no_gcomp_xlsx "`testdir'/_adv_gcomptab_no_gcomp.xlsx"
capture erase "`no_gcomp_xlsx'"
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    capture gcomptab, xlsx("`no_gcomp_xlsx'") sheet("NoGcomp")
    assert _rc == 119
    capture confirm file "`no_gcomp_xlsx'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: A1 non-gcomp e() is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 non-gcomp e() guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
local no_analysis_xlsx "`testdir'/_adv_gcomptab_no_analysis.xlsx"
capture erase "`no_analysis_xlsx'"
capture noisily {
    _adv_mock_no_analysis
    capture gcomptab, xlsx("`no_analysis_xlsx'") sheet("NoAnalysis")
    assert _rc == 119
    capture confirm file "`no_analysis_xlsx'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: A2 missing e(analysis_type) is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 missing analysis_type guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
local tv_xlsx "`testdir'/_adv_gcomptab_timevarying.xlsx"
capture erase "`tv_xlsx'"
capture noisily {
    _adv_mock_gcomp, analysis(time_varying)
    capture gcomptab, xlsx("`tv_xlsx'") sheet("TimeVarying")
    assert _rc == 119
    capture confirm file "`tv_xlsx'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: A3 unsupported time-varying analysis is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 unsupported analysis guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
local oce_xlsx "`testdir'/_adv_gcomptab_oce.xlsx"
capture erase "`oce_xlsx'"
capture noisily {
    _adv_mock_gcomp, medtype(oce)
    capture gcomptab, xlsx("`oce_xlsx'") sheet("OCE")
    assert _rc == 198
    capture confirm file "`oce_xlsx'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: A4 unsupported oce mediation is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 oce guard (error `=_rc')"
    local ++fail_count
}

**# Matrix Contract Validation

local ++test_count
capture noisily {
    _adv_mock_bad_b_missing
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_b.xlsx") sheet("BadB")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A5 e(b) missing required effect column returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 e(b) required column validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_b.xlsx"

local ++test_count
capture noisily {
    _adv_mock_extra_no_cde
    gcomptab, xlsx("`testdir'/_adv_gcomptab_extra.xlsx") sheet("Extra")
    assert r(N_effects) == 4
    assert r(has_cde) == 0
    assert r(tce) == 0.4321
    assert r(pm) == 0.5136
}
if _rc == 0 {
    display as result "  PASS: A6 additional non-effect columns are ignored by name"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 named extra-column handling (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_extra.xlsx"

local ++test_count
capture noisily {
    _adv_mock_bad_se_missing
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_se.xlsx") sheet("BadSE")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A7 e(se) missing required column returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: A7 e(se) column validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_se.xlsx"

local ++test_count
capture noisily {
    _adv_mock_missing_percentile
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_missing_pct.xlsx") ///
        sheet("MissingPct") ci(percentile)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: A8 missing requested CI matrix returns rc 111"
    local ++pass_count
}
else {
    display as error "  FAIL: A8 missing CI matrix guard (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_missing_pct.xlsx"

local ++test_count
capture noisily {
    _adv_mock_bad_ci_dim
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_ci_dim.xlsx") sheet("BadCIDim")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A9 malformed CI matrix dimensions return rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: A9 CI dimension validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_ci_dim.xlsx"

local ++test_count
capture noisily {
    _adv_mock_bad_ci_names
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_ci_names.xlsx") sheet("BadCINames")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A10 CI matrix missing required column returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: A10 CI column validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_ci_names.xlsx"

**# Named Column Lookup

local ++test_count
local scramble_xlsx "`testdir'/_adv_gcomptab_scrambled.xlsx"
capture erase "`scramble_xlsx'"
capture noisily {
    _adv_mock_gcomp, scrambled
    gcomptab, xlsx("`scramble_xlsx'") sheet("Scrambled") decimal(4)
    assert reldif(r(tce), 0.4321) < 1e-12
    assert reldif(r(nde), 0.2102) < 1e-12
    assert reldif(r(nie), 0.2219) < 1e-12
    assert reldif(r(pm), 0.5136) < 1e-12
    assert reldif(r(cde), 0.1955) < 1e-12
    import excel "`scramble_xlsx'", sheet("Scrambled") allstring clear
    assert B[3] == "Total Causal Effect (TCE)"
    assert abs(real(C[3]) - 0.4321) < 1e-12
    assert abs(real(C[4]) - 0.2102) < 1e-12
    assert abs(real(C[5]) - 0.2219) < 1e-12
    assert abs(real(C[6]) - 0.5136) < 1e-12
    assert abs(real(C[7]) - 0.1955) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: A11 named column lookup ignores matrix order"
    local ++pass_count
}
else {
    display as error "  FAIL: A11 named column lookup (error `=_rc')"
    local ++fail_count
}
capture erase "`scramble_xlsx'"

**# Option Validation

local ++test_count
capture noisily {
    _adv_mock_gcomp
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_dec0.xlsx") sheet("Dec0") decimal(0)
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_dec7.xlsx") sheet("Dec7") decimal(7)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A12 decimal() lower and upper bounds are enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: A12 decimal bounds (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_dec0.xlsx"
capture erase "`testdir'/_adv_gcomptab_dec7.xlsx"

local ++test_count
capture noisily {
    _adv_mock_gcomp
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_font.xlsx") ///
        sheet("BadFont") font("Bad;Font")
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_font0.xlsx") ///
        sheet("Font0") fontsize(0)
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_font73.xlsx") ///
        sheet("Font73") fontsize(73)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A13 font()/fontsize() invalid values are refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A13 font/fontsize validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_font.xlsx"
capture erase "`testdir'/_adv_gcomptab_font0.xlsx"
capture erase "`testdir'/_adv_gcomptab_font73.xlsx"

local ++test_count
capture noisily {
    _adv_mock_gcomp
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_border.xlsx") ///
        sheet("Border") borderstyle(thick)
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bold_neg.xlsx") ///
        sheet("BoldNeg") boldp(-0.01)
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bold_one.xlsx") ///
        sheet("BoldOne") boldp(1)
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_high_neg.xlsx") ///
        sheet("HighNeg") highlight(-0.01)
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_high_one.xlsx") ///
        sheet("HighOne") highlight(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A14 borderstyle()/boldp()/highlight() boundaries are enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: A14 formatting boundary validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_border.xlsx"
capture erase "`testdir'/_adv_gcomptab_bold_neg.xlsx"
capture erase "`testdir'/_adv_gcomptab_bold_one.xlsx"
capture erase "`testdir'/_adv_gcomptab_high_neg.xlsx"
capture erase "`testdir'/_adv_gcomptab_high_one.xlsx"

**# Excel Path And Sheet Validation

local ++test_count
local longsheet "12345678901234567890123456789012"
capture noisily {
    _adv_mock_gcomp
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_ext.xls") sheet("BadExt")
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad;path.xlsx") sheet("BadPath")
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_long_sheet.xlsx") sheet("`longsheet'")
    assert _rc == 198
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_bad_sheet.xlsx") sheet("Bad[Sheet]")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A15 xlsx()/sheet() invalid values are refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A15 Excel path/sheet validation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_bad_ext.xls"
capture erase "`testdir'/_adv_gcomptab_bad;path.xlsx"
capture erase "`testdir'/_adv_gcomptab_long_sheet.xlsx"
capture erase "`testdir'/_adv_gcomptab_bad_sheet.xlsx"

**# Exported XLSX Content And Formatting

local ++test_count
local content_xlsx "`testdir'/_adv_gcomptab_content.xlsx"
capture erase "`content_xlsx'"
capture noisily {
    _adv_mock_gcomp
    gcomptab, xlsx("`content_xlsx'") sheet("Content") ///
        title("Adversarial Content") effect("Risk Difference") ///
        labels("Total \ Direct \ Indirect \ Mediated \ Controlled") ///
        decimal(3) footnote("QA footnote")
    confirm file "`content_xlsx'"

    local py_ok "0"
    local py_msg ""
    python:
from sfi import Macro
from openpyxl import load_workbook

try:
    xlsx = r"""`content_xlsx'"""
    wb = load_workbook(xlsx, data_only=False)
    ws = wb["Content"]

    def close(got, expected, tol=1e-12):
        return got is not None and abs(float(got) - expected) <= tol

    assert ws["A1"].value == "Adversarial Content", ws["A1"].value
    assert ws["B2"].value == "Effect", ws["B2"].value
    assert ws["C2"].value == "Risk Difference", ws["C2"].value
    assert ws["D2"].value == "95% CI", ws["D2"].value
    assert ws["E2"].value == "SE", ws["E2"].value
    assert ws["B3"].value == "Total", ws["B3"].value
    assert ws["B4"].value == "Direct", ws["B4"].value
    assert ws["B5"].value == "Indirect", ws["B5"].value
    assert ws["B6"].value == "Mediated", ws["B6"].value
    assert ws["B7"].value == "Controlled", ws["B7"].value
    assert close(ws["C3"].value, 0.432), ws["C3"].value
    assert close(ws["C4"].value, 0.210), ws["C4"].value
    assert close(ws["C5"].value, 0.222), ws["C5"].value
    assert close(ws["C6"].value, 0.514), ws["C6"].value
    assert close(ws["C7"].value, 0.196), ws["C7"].value
    assert isinstance(ws["C3"].value, (int, float)), type(ws["C3"].value)
    assert isinstance(ws["E3"].value, (int, float)), type(ws["E3"].value)
    assert close(ws["E3"].value, 0.060), ws["E3"].value
    ci_text = str(ws["D3"].value)
    assert ci_text.startswith("(") and ci_text.endswith(")"), ci_text
    assert "0.315" in ci_text and "0.550" in ci_text, ci_text
    assert ws["B8"].value == "QA footnote", ws["B8"].value
    Macro.setLocal("py_ok", "1")
    Macro.setLocal("py_msg", "")
except Exception as exc:
    Macro.setLocal("py_ok", "0")
    Macro.setLocal("py_msg", str(exc)[:500])
end
    assert "`py_ok'" == "1"
}
if _rc == 0 {
    display as result "  PASS: A16 exported xlsx cell values and numeric types are faithful"
    local ++pass_count
}
else {
    display as error "  FAIL: A16 xlsx content fidelity (error `=_rc')"
    if "`py_msg'" != "" display as error "    Python detail: `py_msg'"
    local ++fail_count
}
capture erase "`content_xlsx'"

local ++test_count
local fmt_xlsx "`testdir'/_adv_gcomptab_format.xlsx"
capture erase "`fmt_xlsx'"
capture noisily {
    _adv_mock_gcomp
    gcomptab, xlsx("`fmt_xlsx'") sheet("Fmt") ///
        title("Formatted Table") font("Calibri") fontsize(11) ///
        borderstyle(thin) headershade zebra boldp(0.05) highlight(0.05)
    confirm file "`fmt_xlsx'"

    local py_ok "0"
    local py_msg ""
    python:
from sfi import Macro
from openpyxl import load_workbook

try:
    wb = load_workbook(r"""`fmt_xlsx'""", data_only=False)
    ws = wb["Fmt"]

    def rgb(cell):
        color = cell.fill.fgColor
        return (color.rgb or color.indexed or color.theme or "")

    assert ws["A1"].font.bold is True, ws["A1"].font.bold
    assert ws["A1"].font.name == "Calibri", ws["A1"].font.name
    assert abs(float(ws["A1"].font.sz) - 13.0) < 1e-9, ws["A1"].font.sz
    assert ws["B2"].font.bold is True, ws["B2"].font.bold
    assert ws["B2"].border.top.style == "thin", ws["B2"].border.top.style
    assert ws["B2"].border.bottom.style == "thin", ws["B2"].border.bottom.style
    assert str(rgb(ws["B2"])).upper().endswith("DBE5F1"), rgb(ws["B2"])
    assert ws["C3"].font.bold is True, ws["C3"].font.bold
    assert ws["D3"].font.bold is True, ws["D3"].font.bold
    assert ws["E3"].font.bold is True, ws["E3"].font.bold
    assert str(rgb(ws["B3"])).upper().endswith("FFFFCC"), rgb(ws["B3"])
    assert str(rgb(ws["C3"])).upper().endswith("FFFFCC"), rgb(ws["C3"])
    Macro.setLocal("py_ok", "1")
    Macro.setLocal("py_msg", "")
except Exception as exc:
    Macro.setLocal("py_ok", "0")
    Macro.setLocal("py_msg", str(exc)[:500])
end
    assert "`py_ok'" == "1"
}
if _rc == 0 {
    display as result "  PASS: A17 font, border, boldp, highlight formatting is applied"
    local ++pass_count
}
else {
    display as error "  FAIL: A17 xlsx formatting fidelity (error `=_rc')"
    if "`py_msg'" != "" display as error "    Python detail: `py_msg'"
    local ++fail_count
}
capture erase "`fmt_xlsx'"

**# Workbook Replacement Semantics

local ++test_count
local replace_xlsx "`testdir'/_adv_gcomptab_replace.xlsx"
capture erase "`replace_xlsx'"
capture noisily {
    putexcel set "`replace_xlsx'", sheet("Keep") replace
    putexcel A1 = "KEEP"
    putexcel B2 = 987
    putexcel set "`replace_xlsx'", sheet("ReplaceMe") modify
    putexcel A1 = "OLD"
    putexcel B7 = "STALE"
    capture putexcel clear

    _adv_mock_gcomp
    gcomptab, xlsx("`replace_xlsx'") sheet("ReplaceMe") title("First With CDE")
    _adv_mock_gcomp, nocde
    gcomptab, xlsx("`replace_xlsx'") sheet("ReplaceMe") title("Second Without CDE")

    local py_ok "0"
    local py_msg ""
    python:
from sfi import Macro
from openpyxl import load_workbook

try:
    wb = load_workbook(r"""`replace_xlsx'""", data_only=False)
    assert "Keep" in wb.sheetnames, wb.sheetnames
    assert "ReplaceMe" in wb.sheetnames, wb.sheetnames
    keep = wb["Keep"]
    repl = wb["ReplaceMe"]
    assert keep["A1"].value == "KEEP", keep["A1"].value
    assert keep["B2"].value == 987, keep["B2"].value
    assert repl["A1"].value == "Second Without CDE", repl["A1"].value
    assert repl["B3"].value == "Total Causal Effect (TCE)", repl["B3"].value
    assert repl["B6"].value == "Proportion Mediated (PM)", repl["B6"].value
    assert repl["B7"].value in (None, ""), repl["B7"].value
    assert repl["C7"].value in (None, ""), repl["C7"].value
    assert repl["E7"].value in (None, ""), repl["E7"].value
    Macro.setLocal("py_ok", "1")
    Macro.setLocal("py_msg", "")
except Exception as exc:
    Macro.setLocal("py_ok", "0")
    Macro.setLocal("py_msg", str(exc)[:500])
end
    assert "`py_ok'" == "1"
}
if _rc == 0 {
    display as result "  PASS: A18 sheetreplace preserves other sheets and removes stale rows"
    local ++pass_count
}
else {
    display as error "  FAIL: A18 workbook replacement semantics (error `=_rc')"
    if "`py_msg'" != "" display as error "    Python detail: `py_msg'"
    local ++fail_count
}
capture erase "`replace_xlsx'"

**# State Preservation

local ++test_count
capture noisily {
    set varabbrev off
    _adv_mock_gcomp
    gcomptab, xlsx("`testdir'/_adv_gcomptab_va_success.xlsx") sheet("VASuccess")
    assert "`c(varabbrev)'" == "off"

    set varabbrev on
    _adv_mock_bad_ci_dim
    capture gcomptab, xlsx("`testdir'/_adv_gcomptab_va_error.xlsx") sheet("VAError")
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: A19 varabbrev is restored on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: A19 varabbrev restoration (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_adv_gcomptab_va_success.xlsx"
capture erase "`testdir'/_adv_gcomptab_va_error.xlsx"
set varabbrev `orig_varabbrev'

local ++test_count
local e_xlsx "`testdir'/_adv_gcomptab_e_preserve.xlsx"
capture erase "`e_xlsx'"
capture noisily {
    _adv_mock_gcomp, scrambled
    local cmd_before "`e(cmd)'"
    local type_before "`e(analysis_type)'"
    local med_before "`e(mediation_type)'"
    tempname eb_before eb_after eb_diff maxdiff
    matrix `eb_before' = e(b)

    gcomptab, xlsx("`e_xlsx'") sheet("EPreserve")
    assert "`e(cmd)'" == "`cmd_before'"
    assert "`e(analysis_type)'" == "`type_before'"
    assert "`e(mediation_type)'" == "`med_before'"
    matrix `eb_after' = e(b)
    matrix `eb_diff' = `eb_after' - `eb_before'
    mata: st_numscalar("`maxdiff'", max(abs(st_matrix("`eb_diff'"))))
    assert `maxdiff' < 1e-12

    capture gcomptab, xlsx("`e_xlsx'") sheet("BadBorder") borderstyle(thick)
    assert _rc == 198
    assert "`e(cmd)'" == "`cmd_before'"
    assert "`e(analysis_type)'" == "`type_before'"
    assert "`e(mediation_type)'" == "`med_before'"
    matrix `eb_after' = e(b)
    matrix `eb_diff' = `eb_after' - `eb_before'
    mata: st_numscalar("`maxdiff'", max(abs(st_matrix("`eb_diff'"))))
    assert `maxdiff' < 1e-12
}
if _rc == 0 {
    display as result "  PASS: A20 active e() is preserved on success and validation error"
    local ++pass_count
}
else {
    display as error "  FAIL: A20 active e() preservation (error `=_rc')"
    local ++fail_count
}
capture erase "`e_xlsx'"

**# Cleanup

set varabbrev `orig_varabbrev'

foreach p in _adv_mock_gcomp _adv_mock_no_analysis _adv_mock_bad_b_missing ///
    _adv_mock_extra_no_cde _adv_mock_bad_se_missing ///
    _adv_mock_bad_ci_dim _adv_mock_bad_ci_names ///
    _adv_mock_missing_percentile {
    capture program drop `p'
}

local adv_files : dir "`testdir'" files "_adv_gcomptab*.xlsx"
foreach f of local adv_files {
    capture erase "`testdir'/`f'"
}

**# Summary

display ""
display as result "test_adversarial_gcomptab Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_adversarial_gcomptab tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "FAIL"
    exit 1
}
else {
    display "RESULT: test_adversarial_gcomptab tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    display as result "PASS"
}
