* benchmark_tabtools_speed.do - representative tabtools speed smoke benchmark
* Run from tabtools/qa, or via: stata-mp -b do run_all.do benchmark

clear all
set more off
set varabbrev off
version 17.0

capture log close _bench_speed

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local qa_dir "`_cwd'"
}
else {
    local qa_dir "`_cwd'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

log using "`output_dir'/benchmark_tabtools_speed.log", replace text name(_bench_speed)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local strict : env TABTOOLS_BENCH_STRICT
local strict = lower(strtrim("`strict'"))
local default_budget = cond(inlist("`strict'", "1", "true", "yes", "strict"), 15, 60)

local result_file "`output_dir'/benchmark_tabtools_speed.tsv"
tempname benchfh
file open `benchfh' using "`result_file'", write replace text
file write `benchfh' "scenario" _tab "seconds" _tab "budget_seconds" _tab "observations" _tab "status" _n

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _bench_dataset
program define _bench_dataset
    clear
    set obs 2500
    set seed 20260523
    gen long id = _n
    gen byte group = mod(_n, 3)
    gen byte treated = mod(_n, 2)
    gen byte female = runiform() > .48
    gen byte smoker = runiform() > .72
    gen double age = 50 + 12 * rnormal()
    gen double bmi = 26 + 4 * rnormal()
    gen double sbp = 120 + 15 * rnormal()
    gen double dbp = 75 + 10 * rnormal()
    gen double chol = 5 + 1.1 * rnormal()
    gen double hba1c = 39 + 8 * rnormal()
    gen double marker1 = rnormal()
    gen double marker2 = .45 * marker1 + rnormal()
    gen double marker3 = .25 * marker1 - .35 * marker2 + rnormal()
    gen double marker4 = rnormal()
    gen double outcome = 12 + 1.4 * treated - .08 * age + .25 * bmi + 2 * female + rnormal() * 5
    gen byte event = runiform() < invlogit(-2 + .35 * treated + .02 * age + .3 * female)
    label define group_lbl 0 "Control" 1 "Dose A" 2 "Dose B"
    label values group group_lbl
    label define yesno 0 "No" 1 "Yes"
    label values treated yesno
    label values female yesno
    label values smoker yesno
end

**# Benchmarks

local ++test_count
local scenario "table1_tc_medium_xlsx"
local budget = `default_budget'
timer clear 1
capture noisily {
    _bench_dataset
    capture erase "`output_dir'/benchmark_table1_tc.xlsx"
    timer on 1
    table1_tc, vars(age contn \ bmi contn \ sbp contn \ dbp contn \ chol contn \ ///
        hba1c contn \ female bin \ smoker bin) by(treated) ///
        xlsx("`output_dir'/benchmark_table1_tc.xlsx") sheet("Table1")
    timer off 1
    confirm file "`output_dir'/benchmark_table1_tc.xlsx"
}
local rc = _rc
capture timer off 1
capture quietly timer list 1
if _rc == 0 local elapsed = r(t1)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %9.3f (`elapsed') _tab %9.0f (`budget') _tab %9.0f (2500) _tab "`status'" _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %6.3f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %6.3f `elapsed'' budget=`budget'"
    local ++fail_count
}

local ++test_count
local scenario "corrtab_medium_xlsx"
local budget = `default_budget'
timer clear 2
capture noisily {
    _bench_dataset
    capture erase "`output_dir'/benchmark_corrtab.xlsx"
    timer on 2
    corrtab age bmi sbp dbp chol hba1c marker1 marker2 marker3 marker4, ///
        xlsx("`output_dir'/benchmark_corrtab.xlsx") sheet("Corr")
    timer off 2
    confirm file "`output_dir'/benchmark_corrtab.xlsx"
}
local rc = _rc
capture timer off 2
capture quietly timer list 2
if _rc == 0 local elapsed = r(t2)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %9.3f (`elapsed') _tab %9.0f (`budget') _tab %9.0f (2500) _tab "`status'" _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %6.3f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %6.3f `elapsed'' budget=`budget'"
    local ++fail_count
}

local ++test_count
local scenario "regtab_medium_xlsx"
local budget = `default_budget'
timer clear 3
capture noisily {
    _bench_dataset
    collect clear
    collect: regress outcome treated age bmi female smoker marker1 marker2 marker3 marker4
    capture erase "`output_dir'/benchmark_regtab.xlsx"
    timer on 3
    regtab, xlsx("`output_dir'/benchmark_regtab.xlsx") sheet("Reg")
    timer off 3
    confirm file "`output_dir'/benchmark_regtab.xlsx"
}
local rc = _rc
capture timer off 3
capture quietly timer list 3
if _rc == 0 local elapsed = r(t3)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %9.3f (`elapsed') _tab %9.0f (`budget') _tab %9.0f (2500) _tab "`status'" _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %6.3f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %6.3f `elapsed'' budget=`budget'"
    local ++fail_count
}

local ++test_count
local scenario "desctab_collect_xlsx"
local budget = `default_budget'
timer clear 4
capture noisily {
    _bench_dataset
    collect clear
    collect: table group, statistic(mean age) statistic(sd age) statistic(count age)
    capture erase "`output_dir'/benchmark_desctab.xlsx"
    timer on 4
    desctab, xlsx("`output_dir'/benchmark_desctab.xlsx") sheet("Desc")
    timer off 4
    confirm file "`output_dir'/benchmark_desctab.xlsx"
}
local rc = _rc
capture timer off 4
capture quietly timer list 4
if _rc == 0 local elapsed = r(t4)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %9.3f (`elapsed') _tab %9.0f (`budget') _tab %9.0f (2500) _tab "`status'" _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %6.3f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %6.3f `elapsed'' budget=`budget'"
    local ++fail_count
}

file close `benchfh'

display as result "Benchmark QA: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "Benchmark results: `result_file'"
if `fail_count' > 0 {
    display as error "SOME BENCHMARKS FAILED"
    log close _bench_speed
    exit 1
}

display as result "ALL BENCHMARKS PASSED"
log close _bench_speed
