* crossval_fixture_provenance.do - regenerate external fixtures without writes
* to the tracked data directory and fail on semantic drift
* qa-hygiene: no-package-code -- shells tools/verify_fixtures.py; no gcomp command runs here

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
tempfile result
* the Stata shell reports rc 0 for a child that failed, exited nonzero, or does
* not even exist, so python_rc was always 0 and contributed nothing to the
* verdict (proved in iivw/qa/test_iivw_v200_qagate.do, T1). The --result-file is
* the real sentinel: it exists only if the child ran far enough to write it.
* Opening it unguarded turned an absent python3 into an uncaught r(603) that
* aborted before any RESULT line was emitted.
capture noisily shell python3 "`qa_dir'/tools/verify_fixtures.py" --result-file "`result'"

local line ""
capture confirm file "`result'"
if _rc == 0 {
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
}

if "`line'" != "PASS" {
    display "RESULT: crossval_fixture_provenance tests=1 pass=0 fail=1 status=FAIL"
    exit 1
}
display "RESULT: crossval_fixture_provenance tests=1 pass=1 fail=0 status=PASS"
