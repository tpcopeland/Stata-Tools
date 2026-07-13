* crossval_fixture_provenance.do - regenerate external fixtures without writes
* to the tracked data directory and fail on semantic drift

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
tempfile result
capture noisily shell python3 "`qa_dir'/tools/verify_fixtures.py" --result-file "`result'"
local python_rc = _rc

tempname fh
file open `fh' using "`result'", read text
file read `fh' line
file close `fh'

if `python_rc' != 0 | "`line'" != "PASS" {
    display "RESULT: crossval_fixture_provenance tests=1 pass=0 fail=1 status=FAIL"
    exit 1
}
display "RESULT: crossval_fixture_provenance tests=1 pass=1 fail=0 status=PASS"
