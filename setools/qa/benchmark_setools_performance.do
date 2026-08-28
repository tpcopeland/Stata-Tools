*! benchmark_setools_performance.do  1.0.0  2026/08/28
*! Registry-scale timing fixture for longitudinal setools engines

version 16.0
capture log close _all
set more off
args n_persons
if "`n_persons'" == "" local n_persons 100000
confirm integer number `n_persons'
if `n_persons' <= 0 exit 198

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup_runner "`pkg_dir'"

tempfile visits relapses
clear
set seed 28082026
set obs `=`n_persons' * 10'
gen long id = ceil(_n / 10)
sort id
by id: gen byte visit = _n
gen long visit_date = 20000 + 120 * (visit - 1)
gen long dx_date = 19800
gen double edss = 2
replace edss = 3.5 if inlist(visit, 2, 4)
replace edss = 2.5 if inlist(visit, 3, 5)
replace edss = 4.0 if inlist(visit, 6, 8, 9, 10)
replace edss = 3.0 if visit == 7
format visit_date dx_date %td
drop visit
compress
save `visits', replace

clear
set obs `=`n_persons' * 2'
gen long id = ceil(_n / 2)
sort id
by id: gen long relapse_date = 20150 + 360 * (_n - 1)
format relapse_date %td
compress
save `relapses', replace

timer clear

use `visits', clear
timer on 1
capture noisily pira id edss visit_date, dxdate(dx_date) ///
    relapses("`relapses'") keepall quietly generate(_bench_pira) ///
    rawgenerate(_bench_raw)
local rc_pira = _rc
timer off 1
if `rc_pira' exit `rc_pira'

use `visits', clear
timer on 2
capture noisily pira id edss visit_date, dxdate(dx_date) ///
    relapses("`relapses'") rebaselinerelapse keepall quietly ///
    generate(_bench_pira) rawgenerate(_bench_raw)
local rc_pira_rebase = _rc
timer off 2
if `rc_pira_rebase' exit `rc_pira_rebase'

use `visits', clear
timer on 3
capture noisily cdp id edss visit_date, dxdate(dx_date) keepall quietly ///
    generate(_bench_cdp)
local rc_cdp = _rc
timer off 3
if `rc_cdp' exit `rc_cdp'

use `visits', clear
timer on 4
capture noisily sustainedss id edss visit_date, threshold(3) ///
    keepall quietly generate(_bench_ss)
local rc_ss = _rc
local ss_iterations = r(iterations)
timer off 4
if `rc_ss' exit `rc_ss'

quietly timer list
local t_pira = strtrim(strofreal(r(t1), "%9.3f"))
local t_pira_rebase = strtrim(strofreal(r(t2), "%9.3f"))
local t_cdp = strtrim(strofreal(r(t3), "%9.3f"))
local t_ss = strtrim(strofreal(r(t4), "%9.3f"))

display as text "benchmark persons visits relapses seconds iterations"
display as result "pira `n_persons' `=`n_persons' * 10' `=`n_persons' * 2' `t_pira' ."
display as result "pira_rebaseline `n_persons' `=`n_persons' * 10' `=`n_persons' * 2' `t_pira_rebase' ."
display as result "cdp `n_persons' `=`n_persons' * 10' 0 `t_cdp' ."
display as result "sustainedss `n_persons' `=`n_persons' * 10' 0 `t_ss' `ss_iterations'"
display "RESULT: benchmark_setools_performance tests=4 pass=4 fail=0"

do "`qa_dir'/_setools_qa_common.do" teardown_runner
