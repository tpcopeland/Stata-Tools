clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

capture program drop mock_med
program define mock_med, eclass
    matrix b = (1.1, .7, .4, .36)
    matrix colnames b = tce nde nie pm
    matrix V = I(4) * .01
    matrix colnames V = tce nde nie pm
    matrix rownames V = tce nde nie pm
    ereturn post b V
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix se = (.1, .1, .1, .1)
    matrix colnames se = tce nde nie pm
    ereturn matrix se = se
    matrix ci = (.9, .5, .2, .1 \ 1.3, .9, .6, .62)
    matrix colnames ci = tce nde nie pm
    ereturn matrix ci_normal = ci
end

mock_med
local xlsx "/tmp/gcomptab adversarial labels.xlsx"
local md "/tmp/gcomptab adversarial labels.md"
local csv "/tmp/gcomptab adversarial labels.csv"
local q = char(34)
local title `"A 160-character title with a pipe |, quote `q'inside`q', Unicode Ångström Ελληνικά, and enough trailing text to ensure no fixed-width staging variable can truncate this workbook title 1234567890"'
local labels `"=SUM(A1:A2) | `q'quoted`q' Ångström \ Direct | path \ Indirect `q'quoted`q' \ Proportion mediated"'
capture erase `"`xlsx'"'
capture erase `"`md'"'
capture erase `"`csv'"'
gcomptab, xlsx(`"`xlsx'"') sheet("Mediation & QA") ///
    title(`"`title'"') labels(`"`labels'"') markdown(`"`md'"') csv(`"`csv'"')
assert r(N_effects) == 4
assert r(has_cde) == 0
display "RESULT: gcomptab_text_adversarial_probe status=PASS"

capture erase `"`xlsx'"'
capture erase `"`md'"'
capture erase `"`csv'"'

display "RESULT: test_gcomptab_text_adversarial tests=1 pass=1 fail=0 status=PASS"

