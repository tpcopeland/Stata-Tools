* run_all.do - Compatibility wrapper for the canonical full QA aggregate
* qa-hygiene: no-package-code -- shells run_qa.py and parses its sentinel; child suites own install hygiene
* Usage: cd to qa/ and run: stata-mp -b do run_all.do

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
tempfile status
* the Stata shell reports rc 0 for a child that failed, exited nonzero, or does
* not even exist, so shell_rc was always 0 and contributed nothing to the
* verdict (proved in iivw/qa/test_iivw_v200_qagate.do, T1). What the gate
* actually rests on is found -- the PASS line parsed out of the captured
* stdout -- so the dead term is removed and the file is opened defensively.
capture noisily shell python3 "`qa_dir'/run_qa.py" --lane full > "`status'"

local found 0
capture confirm file "`status'"
if _rc == 0 {
    tempname fh
    file open `fh' using "`status'", read text
    file read `fh' line
    while r(eof) == 0 {
        display as text `"`line'"'
        if regexm(`"`line'"', "^RESULT: run_qa_full .* status=PASS$") local found 1
        file read `fh' line
    }
    file close `fh'
}

if !`found' {
    display "RESULT: run_all tests=1 pass=0 fail=1 status=FAIL"
    exit 1
}
display "RESULT: run_all tests=1 pass=1 fail=0 status=PASS"
