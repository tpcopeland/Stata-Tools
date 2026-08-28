*! test_tabtools_documentation_examples.do - executable self-contained help examples
version 17.0
clear all
set more off
set varabbrev off
capture log close _all

local tests = 0
local pass = 0
local fail = 0
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

* The commands below reproduce the self-contained auto-data examples verbatim.
local ++tests
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, spearman pvalues
    matrix _doc_pairwise_N = r(N)
    assert rowsof(_doc_pairwise_N) == 3
    assert colsof(_doc_pairwise_N) == 3
    crosstab rep78 foreign, label
    assert !missing(r(N))
    assert r(N) > 0
    desctab rep78 foreign, by(foreign)
    assert `"`r(varlist)'"' != ""
    assert `"`r(Dapa)'"' != ""
    matrix _doc_desctab = r(table)
    assert rowsof(_doc_desctab) > 0
    table1_tc rep78 foreign, by(foreign)
    assert `"`r(varlist)'"' != ""
    matrix _doc_table1 = r(table)
    assert rowsof(_doc_table1) > 0
    regress price mpg weight foreign
    matrix _doc_T = r(table)'
    puttab using table.xlsx, sheet("Coefs") matrix(_doc_T) ///
        title("OLS coefficients") digits(3)
    assert !missing(r(n_cols))
    assert r(n_cols) > 0
    tabtools
    assert !missing(r(n_commands))
    assert r(n_commands) > 0
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_tabtools_documentation_examples tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 9
