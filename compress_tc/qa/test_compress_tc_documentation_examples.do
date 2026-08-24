*! Exact executable examples from compress_tc.sthlp
*! Date: 2026-08-23

clear all
set more off
set varabbrev off
version 16.0

local qa_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local repo_dir = regexr("`pkg_dir'", "/compress_tc$", "")
adopath ++ "`pkg_dir'"
local test_count = 0
local pass_count = 0
local fail_count = 0

* The first eleven examples use a self-contained string fixture. Each printed
* compress_tc command is retained verbatim and followed by a result contract.
foreach example in all specific detail noreport nostrl nocompress quietly varsavings dryrun lowmem minlength {
    local ++test_count
    capture noisily {
        clear
        set obs 3
        gen str40 name = "patient " + string(_n)
        gen str40 address = "example address " + string(_n)
        gen str40 city = "Stockholm"
        if "`example'" == "all" compress_tc
        if "`example'" == "specific" compress_tc name address city
        if "`example'" == "detail" compress_tc, detail
        if "`example'" == "noreport" compress_tc, noreport
        if "`example'" == "nostrl" compress_tc, nostrl
        if "`example'" == "nocompress" compress_tc, nocompress
        if "`example'" == "quietly" compress_tc, quietly
        if "`example'" == "varsavings" compress_tc, varsavings
        if "`example'" == "dryrun" compress_tc, dryrun
        if "`example'" == "lowmem" compress_tc, lowmem
        if "`example'" == "minlength" compress_tc, minlength(20)
        assert !missing(r(bytes_initial), r(bytes_final), r(bytes_saved), r(pct_saved))
        assert r(bytes_initial) - r(bytes_final) == r(bytes_saved)
        if "`example'" == "specific" assert "`r(varlist)'" == "name address city"
        if "`example'" == "dryrun" {
            local name_type : type name
            assert "`name_type'" == "str40"
        }
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

* This line is printed immediately after the quietly example.
local ++test_count
capture noisily {
    clear
    set obs 1
    gen str40 name = "patient"
    compress_tc, quietly
    display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"
    assert !missing(r(bytes_saved), r(pct_saved))
}
if _rc == 0 local ++pass_count
else local ++fail_count

* The help file presents these shared fixtures as relative paths.  Resolve them
* from the repository root so the executable contract also works in an
* isolated qa/ lane.
local ++test_count
capture noisily {
    use "`repo_dir'/_data/prescriptions.dta", clear
    compress_tc
    assert !missing(r(k_converted))
    assert r(k_converted) >= 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    compress_tc atc drug_name, detail
    assert "`r(varlist)'" == "atc drug_name"
}
if _rc == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    use "`repo_dir'/_data/procedures.dta", clear
    compress_tc kva_code proc_description, detail
    assert "`r(varlist)'" == "kva_code proc_description"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_compress_tc_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
