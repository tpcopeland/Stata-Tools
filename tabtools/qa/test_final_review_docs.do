*! test_final_review_docs.do Version 1.0.0  2026/09/09
*! Execute every corrected stratetab help recipe against output produced by
*! Stata's strate command, and check workbook cells.
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
set processors 1
version 17.0

capture log close _all
log using "test_final_review_docs.log", replace text name(_finaldocs)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local checker "`qa_dir'/tools/check_xlsx.py"
local test_count = 1
local pass_count = 0
local fail_count = 0

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture confirm file "`checker'"
if _rc {
    display as error "required vendored checker missing: `checker'"
    log close _finaldocs
    exit 601
}

* The checker writes PASS/FAIL to a file because shell's _rc is not reliable
* inside Stata. This also validates every workbook this review creates.
capture program drop _finaldocs_check_book
program define _finaldocs_check_book
    version 17.0
    syntax, BOOK(string) CHECKER(string) RESULT(string)
    capture erase "`result'"
    shell python3 "`checker'" "`book'" --sheet Results --min-rows 11 --min-cols 8 ///
        --result-file "`result'"
    confirm file "`result'"
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
    assert trim(`"`line'"') == "PASS"
end

capture noisily {
    * Generate eight named files from four real strate runs. The first four
    * stems match stratetab.sthlp; the second four match tabtools_tips.sthlp.
    set obs 120
    gen long id = _n
    gen double time = 1 + mod(_n, 10)
    gen byte event1 = inlist(mod(_n, 7), 0, 1)
    gen byte event2 = inlist(mod(_n, 11), 0)
    gen byte ssri = mod(_n, 3)
    gen byte snri = mod(_n + 1, 3)
    label define finaldocs_exp 0 "Unexposed" 1 "Low" 2 "High"
    label values ssri finaldocs_exp
    label values snri finaldocs_exp

    stset time, failure(event1) id(id)
    strate ssri, per(1) output("`output_dir'/rate_ssri_cv", replace)
    strate snri, per(1) output("`output_dir'/rate_snri_cv", replace)
    stset time, failure(event2) id(id)
    strate ssri, per(1) output("`output_dir'/rate_ssri_selfharm", replace)
    strate snri, per(1) output("`output_dir'/rate_snri_selfharm", replace)
    stset time, failure(event1) id(id)
    strate ssri, per(1) output("`output_dir'/rate_ssri_relapse", replace)
    strate snri, per(1) output("`output_dir'/rate_snri_relapse", replace)
    stset time, failure(event2) id(id)
    strate ssri, per(1) output("`output_dir'/rate_ssri_edss4", replace)
    strate snri, per(1) output("`output_dir'/rate_snri_edss4", replace)

    local f1 "`output_dir'/rate_ssri_cv"
    local f2 "`output_dir'/rate_ssri_selfharm"
    local f3 "`output_dir'/rate_snri_cv"
    local f4 "`output_dir'/rate_snri_selfharm"
    local g1 "`output_dir'/rate_ssri_relapse"
    local g2 "`output_dir'/rate_ssri_edss4"
    local g3 "`output_dir'/rate_snri_relapse"
    local g4 "`output_dir'/rate_snri_edss4"

    * stratetab.sthlp Example 1: labels, exposure/outcome layout, and cells.
    local book "`output_dir'/finaldocs_ex1.xlsx"
    stratetab, using("`f1'" "`f2'" "`f3'" "`f4'") xlsx("`book'") outcomes(2) ///
        outlabels(CV Event \ Self-Harm) explabels(SSRI \ SNRI) ///
        title("Incidence Rates per 1,000 Person-Years")
    assert r(N_exposures) == 2 & r(N_outcomes) == 2 & r(N_rows) == 11
    matrix A = r(rates)
    assert rowsof(A) == 6 & colsof(A) == 2
    assert reldif(A[1,1], 1000 * 11 / 220) < 1e-12
    assert reldif(A[1,2], 1000 * 3 / 220) < 1e-12
    _finaldocs_check_book, book("`book'") checker("`checker'") ///
        result("`output_dir'/finaldocs_ex1.check")
    import excel "`book'", sheet("Results") allstring clear
    assert A[1] == "Incidence Rates per 1,000 Person-Years"
    assert B[2] == "Exposure" & C[2] == "CV Event" & F[2] == "Self-Harm"
    assert B[4] == "SSRI" & B[8] == "SNRI"
    assert C[5] == "11" & D[5] == "220" & F[5] == "3" & G[5] == "220"
    display as result "DOC_EX1_PASS"

    * stratetab.sthlp Example 3: custom ratescale/pyscale and numeric cells.
    local book "`output_dir'/finaldocs_ex3.xlsx"
    stratetab, using("`f1'" "`f2'" "`f3'" "`f4'") xlsx("`book'") outcomes(2) ///
        ratescale(100) unitlabel(100) pyscale(1000) explabels(SSRI \ SNRI)
    assert r(N_exposures) == 2 & r(N_outcomes) == 2
    matrix B = r(rates)
    assert reldif(B[1,1], 100 * 11 / 220) < 1e-12
    _finaldocs_check_book, book("`book'") checker("`checker'") ///
        result("`output_dir'/finaldocs_ex3.check")
    import excel "`book'", sheet("Results") allstring clear
    assert C[5] == "11" & D[5] == "0" & E[5] == "5.0 (2.8, 9.0)"
    display as result "DOC_EX3_PASS"

    * stratetab.sthlp Example 4: rate precision and outcome/exposure labels.
    local book "`output_dir'/finaldocs_ex4.xlsx"
    stratetab, using("`f1'" "`f2'" "`f3'" "`f4'") xlsx("`book'") outcomes(2) ///
        outlabels(CV Event \ Self-Harm) explabels(SSRI \ SNRI) digits(2)
    assert r(N_exposures) == 2 & r(N_outcomes) == 2
    matrix C = r(rates)
    assert reldif(C[1,2], 1000 * 3 / 220) < 1e-12
    _finaldocs_check_book, book("`book'") checker("`checker'") ///
        result("`output_dir'/finaldocs_ex4.check")
    import excel "`book'", sheet("Results") allstring clear
    assert C[2] == "CV Event" & F[2] == "Self-Harm"
    assert C[5] == "11" & E[5] == "50.00 (27.69, 90.29)"
    display as result "DOC_EX4_PASS"

    * tabtools_tips.sthlp recipe: outcome-aligned names and labels.
    local book "`output_dir'/finaldocs_tips.xlsx"
    stratetab, using("`g1'" "`g2'" "`g3'" "`g4'") xlsx("`book'") outcomes(2) ///
        outlabels("Relapse \ EDSS 4") explabels("SSRI \ SNRI")
    assert r(N_exposures) == 2 & r(N_outcomes) == 2
    matrix D = r(rates)
    assert reldif(D[1,1], 1000 * 11 / 220) < 1e-12
    assert reldif(D[1,2], 1000 * 3 / 220) < 1e-12
    _finaldocs_check_book, book("`book'") checker("`checker'") ///
        result("`output_dir'/finaldocs_tips.check")
    import excel "`book'", sheet("Results") allstring clear
    assert C[2] == "Relapse" & F[2] == "EDSS 4"
    assert C[5] == "11" & F[5] == "3"
    display as result "DOC_TIPS_PASS"
}
local finaldocs_rc = _rc
if `finaldocs_rc' {
    display as error "FAIL: corrected stratetab documentation examples (rc=`finaldocs_rc')"
    local fail_count = 1
}
else {
    display as result "PASS: corrected stratetab documentation examples"
    local pass_count = 1
}
display "RESULT: test_final_review_docs tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _finaldocs
if `fail_count' > 0 exit 1
exit 0
