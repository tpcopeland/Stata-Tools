* run_all.do - Compatibility wrapper for the canonical full QA aggregate
* Usage: cd to qa/ and run: stata-mp -b do run_all.do

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
tempfile status
capture noisily shell python3 "`qa_dir'/run_qa.py" --lane full > "`status'"
local shell_rc = _rc

tempname fh
file open `fh' using "`status'", read text
file read `fh' line
local found 0
while r(eof) == 0 {
    display as text `"`line'"'
    if regexm(`"`line'"', "^RESULT: run_qa_full .* status=PASS$") local found 1
    file read `fh' line
}
file close `fh'

if `shell_rc' != 0 | !`found' {
    display "RESULT: run_all tests=1 pass=0 fail=1 status=FAIL"
    exit 1
}
display "RESULT: run_all tests=1 pass=1 fail=0 status=PASS"
