* test_massdesas_quiet.do
*
* massdesas prints only its own summary: no filelist/cd/replace/levelsof
* output leaks to the console.
*
* Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
version 14.0

local qa_dir  "`c(pwd)'"
do "`qa_dir'/_massdesas_qa_common.do"
capture noisily _massdesas_qa_bootstrap
if _rc {
    display as text "RESULT: test_massdesas_quiet tests=0 pass=0 fail=1 skip=0"
    exit _rc
}

local tests = 0
local pass = 0
local fail = 0

tempfile tmpbase
local testdir = substr("`tmpbase'", 1, strlen("`tmpbase'") - 4)
local dir1 "`testdir'_quiet"
shell mkdir -p "`dir1'/sub"
local dir1r = subinstr("`dir1'", "\", "/", .)
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1:3), '`dir1r'/a.sas7bdat'); write_sas(data.frame(X=1:2), '`dir1r'/sub/b.sas7bdat')" > /dev/null 2>&1

**# 1. console output is the summary line only
local ++tests
capture noisily {
    confirm file "`dir1'/a.sas7bdat"
    tempfile outlog
    quietly log using "`outlog'", text replace name(mdq)
    massdesas, directory("`dir1'")
    local nconv = r(n_converted)
    quietly log close mdq
    assert `nconv' == 2
    tempname fh
    local nlines = 0
    local nsummary = 0
    local nleak = 0
    file open `fh' using "`outlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        local t = strtrim(`"`macval(line)'"')
        * skip the log header, command echo, and blank lines
        if `"`t'"' != "" & !inlist(substr(`"`t'"', 1, 1), ".", ">") & ///
            !regexm(`"`t'"', "^(name:|log:|log type:|opened on:|closed on:)") {
            local ++nlines
            if strpos(`"`t'"', "Conversion complete") local ++nsummary
            else local ++nleak
        }
        file read `fh' line
    }
    file close `fh'
    assert `nsummary' == 1
    assert `nleak' == 0
}
if _rc == 0 local ++pass
else {
    capture log close mdq
    display as error "FAIL: massdesas console output leaks internal commands"
    local ++fail
}

shell rm -rf "`dir1'"
_massdesas_qa_cleanup
display "RESULT: test_massdesas_quiet tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' exit 1
