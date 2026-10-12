* test_codescan_axes.do - qa-lib adversarial axis probes for both commands
*
* One cell per owed axis that check qa --view axes reported unprobed:
*   A1  codescan_describe  fingerprint-error  caller state on success + r(198)
*   A2  codescan           lifecycle          foreign fit A -> B -> restore A;
*                                             saving()/export() reproduce, and
*                                             a replace run leaves no stale rows
*   A3  codescan_describe  lifecycle          same, for the save() draft
*   A4  codescan           parity             prevalence in r(), console, CSV
*                                             and xlsx, through a window that
*                                             drops an id (denominator 2, not 3)
*   A5  codescan_describe  parity             top-code percent in r() and console
*   A6  codescan           hostile-strings    label() corpus round trip
*   A7  codescan           hostile-fixture    codes above maxlong, a prefix pair
*   A8  codescan_describe  hostile-fixture    the same codes, inventoried
*
* Every expected value comes from the fixture design written next to it or
* from a qa-lib generator's r(), never from codescan's own output.

clear all
version 16.0
set varabbrev off
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

quietly do "`qa_dir'/_qa_state.do"
quietly do "`qa_dir'/_qa_lifecycle.do"
quietly do "`qa_dir'/_qa_parity.do"
quietly do "`qa_dir'/_qa_hostile.do"

local _qa_va0 "`c(varabbrev)'"
local _tmp "`c(tmpdir)'"
if substr("`_tmp'", -1, 1) != "/" local _tmp "`_tmp'/"
tempfile _stem
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_csax"

* Setup rows (the help-file worked example). Visits relative to index 21915:
*   pid 1: 21914 E110/I10 (1 day), 21880 Z00/E119 (35 days)
*   pid 2: 21900 I50 (15 days), 22020 E102 (after index)
*   pid 3: 21910 Z00 (5 days)
capture program drop _csax_data
program define _csax_data
    clear
    quietly set obs 5
    generate long pid = cond(_n <= 2, 1, cond(_n <= 4, 2, 3))
    generate str6 dx1 = word("E110 Z00 I50 E102 Z00", _n)
    generate str6 dx2 = cond(_n == 1, "I10", cond(_n == 2, "E119", ""))
    generate double visit_dt = real(word("21914 21880 21900 22020 21910", _n))
    generate double index_dt = 21915
    format visit_dt index_dt %td
end

* Lifecycle companion: turn the files a run wrote into r() so qa_lifecycle
* compares them across fit A -> fit B -> restore A. CSV by checksum, .dta by
* datasignature (the .dta header carries a save timestamp).
capture program drop _csax_files
program define _csax_files, rclass
    local k 0
    foreach f of local 0 {
        local ++k
        if lower(substr(`"`f'"', -4, .)) == ".dta" {
            tempname fr
            frame create `fr'
            frame `fr' {
                quietly use `"`f'"', clear
                quietly datasignature
                local sig "`r(datasignature)'"
            }
            frame drop `fr'
            return local file`k' "`sig'"
        }
        else {
            quietly checksum `"`f'"'
            return scalar file`k' = r(checksum)
        }
    }
end


**# A1: codescan_describe fingerprint on success and on the error path

local ++test_count
capture noisily {
    _csax_data
    quietly regress visit_dt pid
    matrix top_codes = (1, 2)
    scalar n_unique = -1
    qa_state_snapshot, tag(csax_ok) rreturn
    codescan_describe dx1 dx2, top(3)
    * rclass: r() is documented to change; nothing else may.
    qa_state_compare, tag(csax_ok) allow(r)
    * Error path: Stata clears r() whenever an rclass program exits with an
    * error, so r() is not part of this fingerprint; everything else is.
    qa_state_snapshot, tag(csax_bad)
    * expect: REFUSED
    capture codescan_describe dx1 dx2, top(0)
    assert _rc == 198
    qa_state_compare, tag(csax_bad)
    assert e(cmd) == "regress"
    assert el(top_codes, 1, 2) == 2 & scalar(n_unique) == -1
}
if _rc == 0 {
    display as result "  PASS: A1 - describe leaves caller state intact (ok + r(198))"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 - describe fingerprint (error `=_rc')"
    local ++fail_count
}
capture matrix drop top_codes
capture scalar drop n_unique


**# A2: codescan lifecycle across foreign fits; replace leaves no stale rows

local ++test_count
capture noisily {
    local f_dta "`_tmp'`_tag'_a2.dta"
    local f_csv "`_tmp'`_tag'_a2.csv"
    _csax_data
    qa_lifecycle, fita(regress visit_dt pid) fitb(regress index_dt visit_dt if pid != 2) ///
        post(codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse preserve saving("`f_dta'", replace) export("`f_csv'", replace); _csax_files `f_dta' `f_csv')
    assert e(cmd) == "regress" & e(depvar) == "visit_dt"
    * Overwrite both files with a different design: no row or column of the
    * first design may survive.
    codescan dx1 dx2, define(chf "I50") id(pid) collapse preserve ///
        saving("`f_dta'", replace) export("`f_csv'", replace)
    preserve
    use "`f_dta'", clear
    capture confirm variable dm2
    assert _rc == 111
    assert _N == 3 & chf == (pid == 2)
    import delimited using "`f_csv'", clear varnames(1) stringcols(1)
    assert _N == 1 & condition[1] == "chf"
    restore
    * A failing call writes nothing new.
    capture erase "`_tmp'`_tag'_a2b.dta"
    * expect: REFUSED
    capture codescan dx1 dx2, define(bad "(") id(pid) collapse preserve ///
        saving("`_tmp'`_tag'_a2b.dta", replace)
    assert _rc == 198
    capture confirm file "`_tmp'`_tag'_a2b.dta"
    assert _rc == 601
    capture erase "`f_dta'"
    capture erase "`f_csv'"
}
if _rc == 0 {
    display as result "  PASS: A2 - codescan outputs reproduce after fit B; no stale rows"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 - codescan lifecycle (error `=_rc')"
    local ++fail_count
}


**# A3: codescan_describe lifecycle; the save() draft is rewritten whole

local ++test_count
capture noisily {
    local f_draft "`_tmp'`_tag'_a3.csv"
    _csax_data
    qa_lifecycle, fita(regress visit_dt pid) fitb(regress index_dt visit_dt if pid != 2) ///
        post(codescan_describe dx1 dx2, save("`f_draft'", replace); _csax_files `f_draft')
    assert e(cmd) == "regress" & e(depvar) == "visit_dt"
    * Design: dx1 alone has chapters E, I, Z; then only the I50 row is kept,
    * so a rewrite must hold chapter_I alone.
    keep if dx1 == "I50"
    codescan_describe dx1, save("`f_draft'", replace)
    preserve
    import delimited using "`f_draft'", clear varnames(1) stringcols(_all)
    assert _N == 1 & name[1] == "chapter_I"
    restore
    capture erase "`f_draft'"
}
if _rc == 0 {
    display as result "  PASS: A3 - describe draft reproduces after fit B; rewrite is whole"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 - describe lifecycle (error `=_rc')"
    local ++fail_count
}


**# A4: codescan prevalence parity across r(), console, CSV and workbook

* lookback(10) inclusive keeps visits 21905-21915: pid 1 (E110 at 21914) and
* pid 3 (Z00 at 21910). pid 2 has no row in the window, so the denominator is
* 2 ids and dm2 prevalence is 1/2 = 50 in every sink (not 1/3 of the cohort).
local ++test_count
capture noisily {
    local f_csv "`_tmp'`_tag'_a4.csv"
    local f_xlsx "`_tmp'`_tag'_a4.xlsx"
    local f_log "`_tmp'`_tag'_a4.log"
    _csax_data
    log using "`f_log'", name(csax_par) text replace
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(10) inclusive collapse preserve format(%9.4f) export("`f_csv'", replace)
    * log close clears r(): copy first.
    assert r(N) == 2
    matrix csax_S = r(summary)
    log close csax_par
    qa_surface_parity, expect(50) name(dm2 prevalence) result(el(csax_S,1,2)) ///
        log("`f_log'") logregex("^  dm2 +[0-9]+ +([0-9.]+)%") csv("`f_csv'" 2 6)
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(10) inclusive collapse preserve export("`f_xlsx'", replace)
    matrix csax_S = r(summary)
    qa_surface_parity, expect(50) name(dm2 prevalence xlsx) result(el(csax_S,1,2)) ///
        xlsx("`f_xlsx'" Sheet1 F2)
    matrix drop csax_S
    capture erase "`f_csv'"
    capture erase "`f_xlsx'"
    capture erase "`f_log'"
}
if _rc == 0 {
    display as result "  PASS: A4 - windowed prevalence 50% in every sink"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 - codescan surface parity (error `=_rc')"
    local ++fail_count
    capture log close csax_par
}
capture matrix drop csax_S


**# A5: codescan_describe top-code percent parity across r() and console

* dx1/dx2 hold 7 non-empty entries; Z00 appears twice: 2/7 of entries.
local ++test_count
capture noisily {
    local f_log "`_tmp'`_tag'_a5.log"
    _csax_data
    log using "`f_log'", name(csax_par) text replace
    codescan_describe dx1 dx2
    assert "`r(top_code_1)'" == "Z00" & r(n_entries) == 7
    matrix csax_T = r(top_codes)
    log close csax_par
    qa_surface_parity, expect(200/7) name(Z00 percent) result(el(csax_T,1,2)) ///
        log("`f_log'") logregex("^  Z00 +[0-9]+ +([0-9.]+)%")
    matrix drop csax_T
    capture erase "`f_log'"
}
if _rc == 0 {
    display as result "  PASS: A5 - describe percent agrees in r() and console"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 - describe surface parity (error `=_rc')"
    local ++fail_count
    capture log close csax_par
}
capture matrix drop csax_T


**# A6: label() hostile-string corpus reaches the variable label and export

* Contract: text with a double quote is refused with r(198); every other
* corpus string reaches the variable label and the export label column byte
* for byte.
capture program drop _csax_label
program define _csax_label
    args g csv
    clear
    quietly set obs 2
    generate str6 dx1 = cond(_n == 1, "E110", "Z00")
    mata: st_local("s", st_global("`g'"))
    codescan dx1, define(dm2 "E11") label(dm2 `"`macval(s)'"') export("`csv'", replace)
    mata: st_global("CSAX_VL", st_varlabel("dm2"))
    quietly import delimited using "`csv'", clear varnames(1) stringcols(_all) encoding("utf-8")
    mata: st_global("CSAX_CSV", st_sdata(1, "label"))
end
local ++test_count
capture noisily {
    local f_csv "`_tmp'`_tag'_a6.csv"
    qa_hostile_strings
    local corpus `r(names)'
    local nref 0
    foreach g of local corpus {
        mata: st_local("hasdq", strofreal(strpos(st_global("`g'"), char(34)) > 0))
        if `hasdq' {
            * expect: REFUSED
            capture _csax_label `g' "`f_csv'"
            assert _rc == 198
            local ++nref
        }
        else {
            _csax_label `g' "`f_csv'"
            qa_assert_text `g' CSAX_VL, property(label() text `g' as variable label)
            qa_assert_text `g' CSAX_CSV, property(label() text `g' in export label column)
        }
    }
    * TICKPAIR and DQ carry a double quote; the other seven must round-trip.
    assert `nref' == 2
    capture erase "`f_csv'"
}
if _rc == 0 {
    display as result "  PASS: A6 - label() corpus verbatim; double quotes refused"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 - label() hostile strings (error `=_rc')"
    local ++fail_count
}
capture macro drop CSAX_VL CSAX_CSV


**# A7: codescan on codes above maxlong and a prefix pair (tostring)

local ++test_count
capture noisily {
    qa_hostile_codes, clear
    assert r(ngroups) == 5
    codescan code, tostring ///
        define(b0 "3000000000" | b1 "3000000001" | neg "-7" | two "2$" | pre2 "2")
    * Oracles from the generator's design, by numeric equality on code.
    assert b0 == (code == 3000000000)
    assert b1 == (code == 3000000001)
    assert neg == (code == -7)
    assert two == (code == 2)
    assert pre2 == inlist(code, 2, 20)
    matrix csax_S = r(summary)
    assert el(csax_S, 1, 1) == 3 & el(csax_S, 2, 1) == 3 & el(csax_S, 5, 1) == 6
    matrix drop csax_S
}
if _rc == 0 {
    display as result "  PASS: A7 - adjacent codes above maxlong stay distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: A7 - codescan hostile codes (error `=_rc')"
    local ++fail_count
}
capture matrix drop csax_S


**# A8: codescan_describe inventories the hostile codes exactly

local ++test_count
capture noisily {
    qa_hostile_codes, clear
    local want `r(codes)'
    codescan_describe code, tostring
    assert r(n_unique) == 5 & r(n_entries) == 15
    local got ""
    forvalues i = 1/5 {
        local got "`got' `r(top_code_`i')'"
    }
    * Every generator code comes back exactly once, as its full digits.
    foreach c of local want {
        assert `: list c in got'
    }
    assert `: list sizeof got' == 5
    matrix csax_T = r(top_codes)
    forvalues i = 1/5 {
        assert el(csax_T, `i', 1) == 3
    }
    matrix drop csax_T
}
if _rc == 0 {
    display as result "  PASS: A8 - describe returns all five hostile codes exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: A8 - describe hostile codes (error `=_rc')"
    local ++fail_count
}
capture matrix drop csax_T


**# Summary

assert "`c(varabbrev)'" == "`_qa_va0'"
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_axes" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_axes tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
