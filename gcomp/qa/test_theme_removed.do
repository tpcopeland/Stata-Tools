*! gcomptab theme-option removal regression test
version 16.0
clear all
set more off

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

capture noisily gcomptab, theme(lancet)
assert _rc == 198
display as result "RESULT: test_theme_removed tests=1 pass=1 fail=0 status=PASS"
exit 0
