* test_finegray_oracles.do -- frozen-reference integrity and refusal contract.
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "test_finegray_oracles.log", text replace
local qa_dir "`c(pwd)'"
tempfile result status
shell Rscript "`qa_dir'/test_finegray_oracles.R" > "`result'" 2>&1 && echo 0 > "`status'" || echo 1 > "`status'"
confirm file "`status'"
tempname fh
file open `fh' using "`status'", read text
file read `fh' line
file close `fh'
local rc = real(strtrim("`line'"))
type "`result'"
log close
if `rc' != 0 exit 9
