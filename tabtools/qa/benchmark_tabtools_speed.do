* benchmark_tabtools_speed.do - upper-end tabtools speed benchmark
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
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

log using "`output_dir'/benchmark_tabtools_speed.log", replace text name(_bench_speed)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local strict : env TABTOOLS_BENCH_STRICT
local strict = lower(strtrim("`strict'"))
local default_budget = cond(inlist("`strict'", "1", "true", "yes", "strict"), 60, 300)

local result_file "`output_dir'/benchmark_tabtools_speed.tsv"
tempname benchfh worktag
local work_dir "`c(tmpdir)'/tabtools_bench_`worktag'"
capture mkdir "`work_dir'"

file open `benchfh' using "`result_file'", write replace text
file write `benchfh' "scenario" _tab "seconds" _tab "budget_seconds" _tab ///
    "observations" _tab "status" _tab "rc" _n

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _bench_dataset
program define _bench_dataset
    syntax, OBS(integer) [GROUPS(integer 4)]
    clear
    set obs `obs'
    set seed 20260523

    gen long id = _n
    gen byte group = mod(_n, `groups')
    gen byte treatment = mod(_n, 2)
    gen byte sex = runiform() > .48
    gen byte smoker = runiform() > .72
    gen byte diabetes = runiform() < invlogit(-2 + .02 * (_n / `obs') + .4 * treatment)
    gen byte hypertension = runiform() < .35
    gen byte prior_event = runiform() < .18
    gen byte statin = runiform() < .42
    gen byte region = ceil(5 * runiform())

    gen double age = 50 + 12 * rnormal() + 2 * treatment
    gen double bmi = 26 + 4 * rnormal() + .8 * smoker
    gen double sbp = 120 + 15 * rnormal() + 4 * hypertension
    gen double dbp = 75 + 10 * rnormal() + 2 * hypertension
    gen double chol = 5 + 1.1 * rnormal() + .25 * diabetes
    gen double hba1c = 39 + 8 * rnormal() + 7 * diabetes
    gen double egfr = 85 + 18 * rnormal() - .35 * age
    gen double crp = exp(.25 + .6 * rnormal() + .15 * smoker)

    forvalues j = 1/60 {
        gen double x`j' = rnormal() + .015 * age + .18 * treatment + .08 * group
        label variable x`j' "Marker `j'"
    }
    forvalues j = 1/12 {
        gen byte b`j' = runiform() < invlogit(-.7 + .2 * treatment + .03 * age + .05 * `j')
        label variable b`j' "Binary feature `j'"
    }
    forvalues j = 1/10 {
        gen byte c`j' = ceil(5 * runiform())
        label variable c`j' "Category feature `j'"
    }

    gen double outcome = 12 + 1.4 * treatment - .08 * age + .25 * bmi + ///
        2 * sex + .15 * sbp - .09 * egfr + .45 * x1 - .30 * x2 + rnormal() * 6

    label define group_lbl 0 "Control" 1 "Dose A" 2 "Dose B" 3 "Dose C", replace
    label values group group_lbl
    label define yesno 0 "No" 1 "Yes", replace
    label values treatment yesno
    label values sex yesno
    label values smoker yesno
    label values diabetes yesno
    label values hypertension yesno
    label values prior_event yesno
    label values statin yesno
    forvalues j = 1/12 {
        label values b`j' yesno
    }
    label define cat5 1 "Very low" 2 "Low" 3 "Medium" 4 "High" 5 "Very high", replace
    label values region cat5
    forvalues j = 1/10 {
        label values c`j' cat5
    }
end

capture program drop _bench_surv_dataset
program define _bench_surv_dataset
    syntax, OBS(integer)
    clear
    set obs `obs'
    set seed 20260523
    gen byte treatment = runiform() < .5
    gen double age = 58 + 11 * rnormal()
    gen byte sex = runiform() > .5
    gen double linear = -.20 * treatment + .015 * (age - 58) + .12 * sex
    gen double event_time = rexponential(exp(1.65 - linear))
    gen double censor_time = runiform() * 13
    gen double time = min(event_time, censor_time)
    gen byte event = event_time <= censor_time
    replace time = .05 if time < .05
    label define txlbl 0 "Control" 1 "Treatment", replace
    label values treatment txlbl
    stset time, failure(event)
end

**# Benchmarks

local ++test_count
local scenario "table1_tc_wide_grouped_xlsx"
local budget = `default_budget'
local obs = 20000
local xlsx "`work_dir'/`scenario'.xlsx"
local t1vars "age contn \ bmi contn \ sbp contn \ dbp contn \ chol contn \ hba1c contn \ egfr contn \ crp conts"
forvalues j = 1/28 {
    local t1vars "`t1vars' \ x`j' contn"
}
foreach v in sex smoker diabetes hypertension prior_event statin {
    local t1vars "`t1vars' \ `v' bin"
}
forvalues j = 1/6 {
    local t1vars "`t1vars' \ c`j' cat"
}
timer clear 1
capture noisily {
    _bench_dataset, obs(`obs') groups(4)
    capture erase "`xlsx'"
    timer on 1
    table1_tc, vars(`t1vars') by(group) total(after) headerperc ///
        missingsummary xlsx("`xlsx'") sheet("Table1") ///
        title("Benchmark: wide grouped Table 1")
    timer off 1
    confirm file "`xlsx'"
}
local rc = _rc
capture timer off 1
capture quietly timer list 1
if _rc == 0 local elapsed = r(t1)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %12.6f (`elapsed') _tab %9.0f (`budget') ///
    _tab %9.0f (`obs') _tab "`status'" _tab %9.0f (`rc') _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %9.6f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %9.6f `elapsed'' budget=`budget'"
    local ++fail_count
}
capture erase "`xlsx'"

local ++test_count
local scenario "corrtab_wide_full_pvalues_xlsx"
local budget = `default_budget'
local obs = 20000
local xlsx "`work_dir'/`scenario'.xlsx"
timer clear 2
capture noisily {
    _bench_dataset, obs(`obs') groups(4)
    capture erase "`xlsx'"
    timer on 2
    corrtab x1-x40, full pvalues xlsx("`xlsx'") sheet("Corr") ///
        title("Benchmark: 40-variable correlation matrix")
    timer off 2
    confirm file "`xlsx'"
}
local rc = _rc
capture timer off 2
capture quietly timer list 2
if _rc == 0 local elapsed = r(t2)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %12.6f (`elapsed') _tab %9.0f (`budget') ///
    _tab %9.0f (`obs') _tab "`status'" _tab %9.0f (`rc') _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %9.6f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %9.6f `elapsed'' budget=`budget'"
    local ++fail_count
}
capture erase "`xlsx'"

local ++test_count
local scenario "regtab_five_model_xlsx"
local budget = `default_budget'
local obs = 50000
local xlsx "`work_dir'/`scenario'.xlsx"
timer clear 3
capture noisily {
    _bench_dataset, obs(`obs') groups(4)
    collect clear
    collect: regress outcome i.treatment age sex
    collect: regress outcome i.treatment age sex bmi sbp dbp
    collect: regress outcome i.treatment age sex bmi sbp dbp chol hba1c x1-x8
    collect: regress outcome i.treatment##c.age i.group sex bmi sbp dbp x1-x12
    collect: regress outcome i.treatment##c.x1 i.sex i.group age bmi sbp dbp chol hba1c x2-x20
    capture erase "`xlsx'"
    timer on 3
    regtab, xlsx("`xlsx'") sheet("Reg") noint compact ///
        models("Base \ Clinical \ Biomarkers \ Interaction \ Full") ///
        title("Benchmark: five collected regression models")
    timer off 3
    confirm file "`xlsx'"
}
local rc = _rc
capture timer off 3
capture quietly timer list 3
if _rc == 0 local elapsed = r(t3)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %12.6f (`elapsed') _tab %9.0f (`budget') ///
    _tab %9.0f (`obs') _tab "`status'" _tab %9.0f (`rc') _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %9.6f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %9.6f `elapsed'' budget=`budget'"
    local ++fail_count
}
capture erase "`xlsx'"

local ++test_count
local scenario "desctab_wide_collect_xlsx"
local budget = `default_budget'
local obs = 30000
local xlsx "`work_dir'/`scenario'.xlsx"
local dstats ""
forvalues j = 1/18 {
    local dstats "`dstats' statistic(count x`j') statistic(mean x`j') statistic(sd x`j')"
}
timer clear 4
capture noisily {
    _bench_dataset, obs(`obs') groups(4)
    collect clear
    collect: table group, `dstats'
    capture erase "`xlsx'"
    timer on 4
    desctab, xlsx("`xlsx'") sheet("Desc") ///
        title("Benchmark: wide grouped descriptive table")
    timer off 4
    confirm file "`xlsx'"
}
local rc = _rc
capture timer off 4
capture quietly timer list 4
if _rc == 0 local elapsed = r(t4)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %12.6f (`elapsed') _tab %9.0f (`budget') ///
    _tab %9.0f (`obs') _tab "`status'" _tab %9.0f (`rc') _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %9.6f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %9.6f `elapsed'' budget=`budget'"
    local ++fail_count
}
capture erase "`xlsx'"

local ++test_count
local scenario "survtab_grouped_riskset_xlsx"
local budget = `default_budget'
local obs = 5000
local xlsx "`work_dir'/`scenario'.xlsx"
timer clear 5
capture noisily {
    _bench_surv_dataset, obs(`obs')
    capture erase "`xlsx'"
    timer on 5
    survtab, times(1 3 5 8 10) by(treatment) median riskset ///
        difference xlsx("`xlsx'") sheet("Survival") ///
        title("Benchmark: grouped survival table")
    timer off 5
    confirm file "`xlsx'"
}
local rc = _rc
capture timer off 5
capture quietly timer list 5
if _rc == 0 local elapsed = r(t5)
else local elapsed = .
local status "PASS"
if `rc' != 0 | missing(`elapsed') | `elapsed' > `budget' local status "FAIL"
file write `benchfh' "`scenario'" _tab %12.6f (`elapsed') _tab %9.0f (`budget') ///
    _tab %9.0f (`obs') _tab "`status'" _tab %9.0f (`rc') _n
if "`status'" == "PASS" {
    display as result "  PASS: `scenario' (`: display %9.6f `elapsed'' sec)"
    local ++pass_count
}
else {
    display as error "  FAIL: `scenario' rc=`rc' elapsed=`: display %9.6f `elapsed'' budget=`budget'"
    local ++fail_count
}
capture erase "`xlsx'"

file close `benchfh'

display as result "Benchmark QA: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "Benchmark results: `result_file'"
if `fail_count' > 0 {
    display as error "SOME BENCHMARKS FAILED"
    log close _bench_speed
    capture shell rm -rf "`work_dir'"
    exit 1
}

display as result "ALL BENCHMARKS PASSED"
log close _bench_speed
capture shell rm -rf "`work_dir'"
