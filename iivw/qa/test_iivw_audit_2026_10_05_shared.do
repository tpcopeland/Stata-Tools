clear all
set more off
version 16.0
set varabbrev off

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_audit_2026_10_05_shared.do must be run from iivw/qa"
    log close _all
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Scratch directory for workbooks
tempfile wdbase
local wd "`wdbase'_d"
capture mkdir "`wd'"

capture program drop _ss_panel
program define _ss_panel
    version 16.0
    clear
    set obs 80
    set seed 782
    gen long id = _n
    gen double k = rnormal()
    gen byte a = runiform() < invlogit(.3*k)
    expand 6
    bysort id: gen double t = _n
    gen double y = 1 + a + k + rnormal()
    quietly drop if runiform() > invlogit(.4 + .9*k - .3*a) & t > 1
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(k) visit_cov(k) ///
        wtype(fiptiw) maxfu(7) nolog
end


* Sheet-name probes. The wanted name travels in Mata global SS_WANT so quotes
* and private-use characters are never re-parsed as macro text.
capture program drop _ss_has
program define _ss_has, rclass
    version 16.0
    args file
    quietly import excel using `"`file'"', describe
    local n = r(N_worksheet)
    local found = 0
    forvalues j = 1/`n' {
        mata: st_local("hit", strofreal(st_global("r(worksheet_`j')") == st_global("SS_WANT")))
        if `hit' local found = 1
    }
    return scalar found = `found'
    return scalar n = `n'
end

* A1 of the sheet named SS_WANT, returned in global SS_A1.
capture program drop _ss_a1
program define _ss_a1
    version 16.0
    args file
    mata: st_local("shq", st_global("SS_WANT"))
    preserve
    quietly import excel using `"`file'"', sheet(`"`macval(shq)'"') cellrange(A1:A1) allstring clear
    mata: st_global("SS_A1", st_sdata(1, 1))
    restore
end

* Seed workbook: sheet SS_N1 with A1=SS_V1 and sheet Other with A1=SS_V2.
capture program drop _ss_seed
program define _ss_seed
    version 16.0
    args file
    preserve
    clear
    set obs 1
    gen strL c = ""
    mata: st_sstore(1, 1, st_global("SS_V1"))
    mata: st_local("n1", st_global("SS_N1"))
    quietly export excel using `"`file'"', sheet(`"`macval(n1)'"') replace
    mata: st_sstore(1, 1, st_global("SS_V2"))
    quietly export excel using `"`file'"', sheet("Other", modify)
    restore
end

* One reporter call with the sheet/title carried in Mata globals.
capture program drop _ss_one
program define _ss_one
    version 16.0
    args cmd file flag
    mata: st_local("title", st_global("SS_TITLE"))
    mata: st_local("sh", st_global("SS_WANT"))
    if "`cmd'" == "balance" {
        iivw_balance k, xlsx(`"`file'"') sheet(`"`macval(sh)'"') title(`"`macval(title)'"') `flag'
    }
    if "`cmd'" == "exogtest" {
        capture drop _iivw_exog_y_lag1
        iivw_exogtest y, id(id) time(t) maxfu(7) nolog xlsx(`"`file'"') sheet(`"`macval(sh)'"') title(`"`macval(title)'"') `flag'
    }
    if "`cmd'" == "diagnose" {
        iivw_diagnose k, unweighted(su) weighted(sw) adjusted(sa) force xlsx(`"`file'"') sheet(`"`macval(sh)'"') title(`"`macval(title)'"') `flag'
    }
end

local q = char(34)

**# SS01 - sheet-name transport is reversible

local ++test_count
capture noisily {
    _ss_panel
    local f "`wd'/collision.xlsx"
    mata: st_global("SS_N1", "Sheet" + char(34) + "Name")
    mata: st_global("SS_V1", "CALLER KEEP 742")
    mata: st_global("SS_V2", "OTHER KEEP 993")
    _ss_seed "`f'"
    mata: st_global("SS_WANT", "Sheet" + uchar(57344) + "Name")
    mata: st_local("want", st_global("SS_WANT"))
    iivw_balance k, xlsx("`f'") sheet(`"`want'"') replace
    mata: st_local("got", st_global("r(sheet)"))
    assert `"`macval(got)'"' == `"`want'"'
    _ss_has "`f'"
    assert r(found) == 1
    assert r(n) == 3
    _ss_a1 "`f'"
    assert `"${SS_A1}"' == "IIVW balance diagnostic"
    mata: st_global("SS_WANT", "Sheet" + char(34) + "Name")
    _ss_has "`f'"
    assert r(found) == 1
    _ss_a1 "`f'"
    assert `"${SS_A1}"' == "CALLER KEEP 742"
    mata: st_global("SS_WANT", "Other")
    _ss_a1 "`f'"
    assert `"${SS_A1}"' == "OTHER KEEP 993"
}
if _rc == 0 {
    display as result "  PASS: SS01a - literal U+E000 in sheet() does not overwrite a quote-named sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: SS01a (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SS01a"
}

* Three reporters x names that stress the escape: real quote plus ")", the
* escape code followed by 0/1 literals, a lone private character.
local ++test_count
capture noisily {
    _ss_panel
    quietly regress y k
    estimates store su
    quietly regress y k a
    estimates store sw
    quietly regress y k a t
    estimates store sa
    mata: st_global("SS_TITLE", char(36) + "FOREIGN " + char(96) + "paired" + char(39) + " " + char(34) + "T)" + uchar(57344) + uchar(57345))
    mata: st_global("SS_N1", "Caller")
    mata: st_global("SS_V1", "CALLER KEEP 924")
    mata: st_global("SS_V2", "unused")
    forvalues j = 1/3 {
        if `j' == 1 mata: st_global("SS_WANT", "A " + char(34) + "B) C")
        if `j' == 2 mata: st_global("SS_WANT", "M" + uchar(57344) + "0" + uchar(57344) + "1" + uchar(57345) + " Q")
        if `j' == 3 mata: st_global("SS_WANT", "U" + uchar(57345) + " R")
        mata: st_local("want", st_global("SS_WANT"))
        foreach cmd in balance exogtest diagnose {
            local f "`wd'/`cmd'`j'.xlsx"
            _ss_seed "`f'"
            _ss_one `cmd' "`f'"
            mata: st_local("got", st_global("r(sheet)"))
            assert `"`macval(got)'"' == `"`want'"'
            _ss_has "`f'"
            assert r(found) == 1
            _ss_a1 "`f'"
            assert `"${SS_A1}"' == `"`macval(title)'"' | 1
            mata: st_local("a1", st_global("SS_A1"))
            mata: assert(st_local("a1") == st_global("SS_TITLE"))
            * same-sheet replace must hit the same sheet, not a decoded twin
            _ss_one `cmd' "`f'" replace
            mata: st_local("got", st_global("r(sheet)"))
            assert `"`macval(got)'"' == `"`want'"'
            _ss_has "`f'"
            assert r(found) == 1
            assert r(n) == 3
            mata: st_global("SS_WANT2", st_global("SS_WANT"))
            mata: st_global("SS_WANT", "Caller")
            _ss_a1 "`f'"
            assert `"${SS_A1}"' == "CALLER KEEP 924"
            mata: st_global("SS_WANT", st_global("SS_WANT2"))
        }
    }
}
if _rc == 0 {
    display as result "  PASS: SS01b - balance/exogtest/diagnose preserve exact sheet names and titles, modify and replace"
    local ++pass_count
}
else {
    display as error "  FAIL: SS01b (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SS01b"
}

**# SS02 - standard layout writes string cells literally

local ++test_count
capture noisily {
    capture frame drop sstab
    frame create sstab str30 lab double val
    frame post sstab ("x") (1.5)
    frame post sstab ("y") (2.5)
    frame sstab: mata: st_sstore(1, "lab", char(36) + "SSFOREIGN " + char(96) + "mac" + char(39))
    global SSFOREIGN "EXPANDED"
    local mac "EXPANDED"
    local f "`wd'/standard.xlsx"
    _iivw_export_table, tableframe(sstab) xlsx("`f'") layout(standard) replace
    preserve
    quietly import excel using "`f'", clear allstring
    gen byte hit = 0
    foreach v of varlist _all {
        mata: st_local("n", strofreal(sum(st_sdata(., "`v'") :== (char(36) + "SSFOREIGN " + char(96) + "mac" + char(39)))))
        quietly replace hit = hit + `n' in 1
    }
    quietly summ hit
    assert r(sum) >= 1
    restore
    * numeric cell stays numeric
    quietly import excel using "`f'", clear cellrange(B4:B4)
    capture confirm numeric variable B
    assert _rc == 0
    assert B[1] == 1.5
    * all-string frame still creates a workbook
    capture frame drop sstab2
    frame create sstab2 str30 a str30 b
    frame post sstab2 ("tmp") ("z")
    frame sstab2: mata: st_sstore(1, "a", char(36) + "FOREIGN " + char(96) + "pair" + char(39))
    local f2 "`wd'/standard2.xlsx"
    _iivw_export_table, tableframe(sstab2) xlsx("`f2'") layout(standard) replace
    quietly import excel using "`f2'", clear allstring
    local seen = 0
    foreach v of varlist _all {
        mata: st_local("n", strofreal(sum(st_sdata(., "`v'") :== (char(36) + "FOREIGN " + char(96) + "pair" + char(39)))))
        local seen = `seen' + `n'
    }
    assert `seen' >= 1
    macro drop SSFOREIGN
}
if _rc == 0 {
    display as result "  PASS: SS02 - standard layout string cells are raw text"
    local ++pass_count
}
else {
    display as error "  FAIL: SS02 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SS02"
}

**# SS03 - worksheet-length message states bytes

local ++test_count
capture noisily {
    capture frame drop sstab3
    frame create sstab3 str10 a double b
    frame post sstab3 ("x") (1)
    local long = 16 * "ä"
    tempname lg
    local lgfile "`wd'/ss03.txt"
    quietly log using "`lgfile'", text replace name(ss03)
    capture noisily _iivw_export_table, tableframe(sstab3) xlsx("`wd'/long.xlsx") sheet(`"`long'"') layout(tabtools)
    local rc = _rc
    quietly log close ss03
    assert `rc' == 198
    mata: st_local("txt", cat("`lgfile'")[1])
    mata: st_numscalar("__hit", sum(strpos(cat("`lgfile'"), "31 UTF-8 bytes")))
    assert scalar(__hit) >= 1
    mata: st_numscalar("__bad", sum(strpos(cat("`lgfile'"), "31 characters")))
    assert scalar(__bad) == 0
    * 15 two-byte characters (30 bytes) is accepted
    local ok = 15 * "ä"
    _iivw_export_table, tableframe(sstab3) xlsx("`wd'/ok.xlsx") sheet(`"`ok'"') layout(tabtools) replace
}
if _rc == 0 {
    display as result "  PASS: SS03 - sheet() length message names UTF-8 bytes"
    local ++pass_count
}
else {
    display as error "  FAIL: SS03 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SS03"
}

**# SS04 - malformed explicit version is refused

local ++test_count
capture noisily {
    local vd "`wd'/verado"
    capture mkdir "`vd'"
    capture findfile iivw.ado
    local src "`r(fn)'"
    local ok 1
    * cases: header token -> expected rc (0 = accepted)
    local nc = 0
    foreach c in "4.3.4" "..." "4.3" "4.3.4.1" "4.3.4-beta" "x4.3.4" {
        local ++nc
        tempname fin fout
        file open `fin' using "`src'", read text
        file open `fout' using "`vd'/iivw.ado", write text replace
        file read `fin' line
        file write `fout' "*! iivw Version `c'  2026/09/30" _n
        file read `fin' line
        while r(eof) == 0 {
            file write `fout' `"`macval(line)'"' _n
            file read `fin' line
        }
        file close `fin'
        file close `fout'
        adopath ++ "`vd'"
        capture program drop iivw
        capture noisily iivw
        local rc = _rc
        local ver "`r(version)'"
        adopath - "`vd'"
        capture program drop iivw
        if "`c'" == "4.3.4" {
            assert `rc' == 0
            assert "`ver'" == "4.3.4"
        }
        else {
            assert `rc' != 0
        }
    }
}
if _rc == 0 {
    display as result "  PASS: SS04 - only a strict MAJOR.MINOR.PATCH header version is accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: SS04 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' SS04"
}
capture adopath - "`wd'/verado"
capture program drop iivw

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED: `failed_tests'"
    display "RESULT: test_iivw_audit_2026_10_05_shared tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_audit_2026_10_05_shared tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
