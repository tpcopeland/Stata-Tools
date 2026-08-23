* test_kmplot_errors.do
* Error-path contracts for kmplot
* Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* T1: stset is an early public prerequisite, and failure must not alter data.
local ++test_count
capture noisily {
    clear
    input id time fail group
    2 8 1 1
    1 3 0 2
    end
    sort id
    set varabbrev on
    capture noisily kmplot
    local call_rc = _rc
    assert `call_rc' == 119
    assert "`c(varabbrev)'" == "on"
    assert _N == 2
    assert id[1] == 1 & time[1] == 3 & fail[1] == 0 & group[1] == 2
    assert id[2] == 2 & time[2] == 8 & fail[2] == 1 & group[2] == 1
    stset time, failure(fail)
    kmplot, name(kmplot_errors_t1, replace)
    assert r(N) == 2
    graph drop kmplot_errors_t1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T2: a dependent option must error rather than silently doing nothing.
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly regress studytime drug
    sort studytime
    local first_time = studytime[1]
    capture noisily kmplot, medianannotate
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 48
    assert studytime[1] == `first_time'
    assert "`e(cmd)'" == "regress"
    kmplot, median medianannotate name(kmplot_errors_t2, replace)
    assert r(median_1) < .
    graph drop kmplot_errors_t2
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T3: pvalue is meaningful only across groups; a one-group request is rejected.
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen byte onegroup = 1
    stset studytime, failure(died)
    local orig_N = _N
    capture noisily kmplot, by(onegroup) pvalue
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == `orig_N'
    assert onegroup == 1
    replace onegroup = mod(_n, 2)
    kmplot, by(onegroup) pvalue name(kmplot_errors_t3, replace)
    assert r(n_groups) == 2
    assert r(p) < .
    graph drop kmplot_errors_t3
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T4: a late export-path guard must preserve the analytical data and not accept
* an unsafe path as a successful graph export.
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local orig_N = _N
    local bad_export "`c(tmpdir)'/kmplot_error;path.png"
    capture noisily kmplot, export("`bad_export'") name(kmplot_errors_t4, replace)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == `orig_N'
    capture confirm file "`bad_export'"
    assert _rc != 0
    kmplot, name(kmplot_errors_t4_ok, replace)
    assert r(N) == `orig_N'
    graph drop kmplot_errors_t4_ok
    capture graph drop kmplot_errors_t4
}
if _rc == 0 local ++pass_count
else local ++fail_count

if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display "RESULT: test_kmplot_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
