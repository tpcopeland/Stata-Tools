*! test_edss_fixture.do  1.0.0  2026/07/13
*! Schema and behavioral consumption test for the generated EDSS fixture

version 16.0
clear all
set more off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

use "`qa_dir'/data/edss_long.dta", clear
capture {
    isid id edss_dt
    assert _N == 6003
    tempvar id_tag
    egen byte `id_tag' = tag(id)
    quietly count if `id_tag'
    assert r(N) == 1000
    assert inrange(edss, 0, 10)
    local date_format : format edss_dt
    assert substr("`date_format'", 1, 3) == "%td"
}
local schema_ok = (_rc == 0)

sustainedss id edss edss_dt, threshold(5.5) keepall ///
    generate(fixture_sustained) quietly
local event_count = r(N_events)
quietly count if !missing(fixture_sustained)
local event_rows = r(N)
local behavior_ok = (`event_count' > 0 & `event_rows' > 0)

local pass = `schema_ok' + `behavior_ok'
local fail = 2 - `pass'
display "RESULT: test_edss_fixture tests=2 pass=`pass' fail=`fail'"
if `fail' > 0 exit 9

do "`qa_dir'/_setools_qa_common.do" teardown
