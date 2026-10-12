*! validation_logdoc_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Validation: high-precision numerical text (15 significant digits, near-one, tiny, large)
* survives SMCL-to-markdown conversion unchanged.
version 16.0
clear all
set more off
capture log close _all
log using "validation_logdoc_precision.log", text replace
local qadir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qadir'/logdoc.pkg"
if _rc == 0 {
    local pkg_dir "`qadir'"
}
else {
    local pkg_dir = regexr("`qadir'", "/qa/?$", "")
}
capture confirm file "`pkg_dir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}
capture ado uninstall logdoc
quietly net install logdoc, from("`pkg_dir'") replace
local tests 0
local pass 0
local fail 0

**# literal high precision numerical transcript retained
local ++tests
capture noisily {
    clear
    tempfile stem
    local input "`stem'.smcl"
    local output "`stem'.md"
    tempname fh
    file open `fh' using "`input'", write text replace
    file write `fh' "{smcl}" _n
    file write `fh' "{txt}precise 0.12345678912345" _n
    file write `fh' "{txt}nearone 0.999999981" _n
    file write `fh' "{txt}tiny 1.2345678912345e-12" _n
    file write `fh' "{txt}big 1234567891234.5" _n
    file close `fh'
    quietly logdoc using "`input'", output("`output'") format(md) preformatted quiet replace
    assert "`r(format)'"=="md"
    python: from pathlib import Path; from sfi import Macro; _text=Path(Macro.getLocal('output')).read_text(); assert all(token in _text for token in ['precise 0.12345678912345','nearone 0.999999981','tiny 1.2345678912345e-12','big 1234567891234.5'])
    erase "`input'"
    erase "`output'"

}
if _rc {
    local ++fail
    display as error "FAIL: literal high precision numerical transcript retained; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: literal high precision numerical transcript retained"
}

display "RESULT: validation_logdoc_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
