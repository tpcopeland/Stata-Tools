*! test_datamap_v200_collector_limits.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 1 review fixes: the collector's variables frame takes
*! long special-character text, holds no fixed-width str2045 cells, and the
*! level cells read only their own levels rows
*! 2026-11-10 (datamap 2.0.0 Phase 2): datadict is removed; where these tests ran
*! datadict they run datamap in document mode (title()) or in its filelist mode,
*! and the cells are datamap's ("<value> <label>: n (p%)")
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_collector_limits.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
* tempfile names repeat across suites in one runner session: own suffix
local work "`base'_v200lwork"
capture mkdir "`work'"
capture mkdir "`work'/plus"
capture mkdir "`work'/personal"
capture mkdir "`work'/run"
mata: assert(direxists(st_local("work") + "/plus") & direxists(st_local("work") + "/run"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
local tests = 0
local pass = 0
local fail = 0
local cwd0 "`c(pwd)'"

**# L1 a note of 2,000 double quotes and a characteristic of 2,000 backticks and dollar signs
* 2026-11-10: every datamap run (plain or document mode) posts the variables frame, also
* without saving().  The text cells were char()-joined -frame post-
* expressions, and from about 650 quotes they exceeded the expression limit:
* rc 130 with no saving(), where 1.10.6 ran.  Each run here must succeed, and
* saving() must hold the text verbatim.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 20
    generate long id = _n
    generate double x = _n / 7
    local q = 2000 * char(34)
    local bd = 1000 * (char(96) + char(36))
    mata: st_global("x[note1]", st_local("q"))
    mata: st_global("x[note0]", "1")
    mata: st_global("x[blob]", st_local("bd"))
    quietly save "l1.dta", replace

    * no saving(): both commands, data in memory and a file
    quietly datamap, output(l1_mem.md)
    quietly datamap, single(l1) output(l1_file.md)
    quietly datamap, output(l1_mem2.md) title("T")
    quietly datamap, single(l1) output(l1_file2.md) title("T")
    * the run kept the user's data
    assert c(N) == 20
    mata: assert(st_global("x[note1]") == st_local("q"))

    * saving(): the cells are the text, byte for byte
    quietly datamap, single(l1) output(l1_s.md) saving(l1_dm, replace)
    preserve
    quietly use "l1_dm.dta", clear
    quietly keep if variable == "x"
    assert _N == 1
    confirm str2045 variable notes characteristics
    mata: assert(st_sdata(1, "notes") == st_local("q"))
    mata: assert(st_sdata(1, "characteristics") == "blob=" + st_local("bd"))
    restore

    quietly datamap, single(l1) output(l1_s2.md) title("T") saving(l1_dd, replace)
    preserve
    quietly use "l1_dd.dta", clear
    quietly keep if variable == "x"
    assert _N == 1
    confirm str2045 variable notes characteristics
    * document mode writes the same saving() cells: the text, byte for byte
    mata: assert(st_sdata(1, "notes") == st_local("q"))
    mata: assert(st_sdata(1, "characteristics") == "blob=" + st_local("bd"))
    restore

    * text past 2045 bytes is cut on a character boundary, never an error
    clear
    quietly set obs 5
    generate byte y = _n
    local q3 = 3000 * char(34)
    mata: st_global("y[note1]", st_local("q3"))
    mata: st_global("y[note0]", "1")
    quietly datamap, output(l1_long.md) saving(l1_long, replace)
    quietly use "l1_long.dta", clear
    quietly keep if variable == "y"
    mata: assert(st_sdata(1, "notes") == 2045 * char(34))
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L1 2,000 quotes, backticks and dollar signs in a note and a characteristic (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L1 2,000 quotes, backticks and dollar signs in a note and a characteristic"'
}

**# L2 the variables frame holds its text as strL; saving() writes str2045
* 2026-11-10: the frame held 8 str2045 columns, about 16 KB per variable row
* on every run, saving() or not.  Three 2,000-variable files under nofreq
* nostats and no saving() then needed about 100 MB of row storage (rc 909 at
* a 96m cap).  The cap is tested with 1m memory segments: at the default
* 32m, every non-empty frame reserves a segment, and that per-frame floor
* (the collector's frame count) is not what this test pins.

capture noisily {
    tempname V
    _datamap_post_metadata_rows, create frame(`V')
    frame `V' {
        confirm strL variable source output dataset dataset_label ///
            variable_label notes characteristics datasignature
        confirm str16 variable source_command
        confirm str32 variable variable display_format value_label
        confirm str20 variable storage_type class
    }
    frame drop `V'

    quietly cd "`work'/run"
    clear
    quietly set obs 10
    forvalues i = 1/2000 {
        quietly generate byte w`i' = mod(_n, 3)
    }
    quietly save "l2w1.dta", replace
    quietly copy "l2w1.dta" "l2w2.dta", replace
    quietly copy "l2w1.dta" "l2w3.dta", replace
    clear
    local _mm = c(max_memory)
    local _sg = c(segmentsize)
    set segmentsize 1m
    set max_memory 96m
    capture noisily datamap, filelist(l2w1 l2w2 l2w3) output(l2.txt) nofreq nostats
    local _l2rc = _rc
    clear
    set max_memory `_mm'
    set segmentsize `_sg'
    assert `_l2rc' == 0
    confirm file "l2.txt"
}
local rc = _rc
capture clear
capture set max_memory `_mm'
capture set segmentsize `_sg'
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L2 strL text in the variables frame; 3 x 2,000 variables under max_memory 96m (1m segments) (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L2 strL text in the variables frame; 3 x 2,000 variables under max_memory 96m (1m segments)"'
}

capture mata: mata drop _l3rows()
mata:
// table rows ("|" lines after "### Variables") of section k of file f
string colvector _l3rows(string scalar f, real scalar k)
{
    string colvector t, out
    real scalar i, sec, intab
    t = cat(f)
    out = J(0, 1, "")
    sec = 0
    intab = 0
    for (i = 1; i <= rows(t); i++) {
        if (regexm(t[i], "^## [0-9]+[.] ")) {
            sec++
            intab = 0
        }
        // 2026-11-10 (2.0.0 Phase 3, F1): any other "## " heading (the
        // Linkage section after the last dataset) ends the table
        else if (substr(t[i], 1, 3) == "## ") intab = 0
        if (t[i] == "### Variables") intab = 1
        if (sec == k & intab & substr(t[i], 1, 1) == "|") out = out \ t[i]
    }
    return(out)
}
end

**# L3 datamap over several files: each file's table equals its own single-file run
* 2026-11-10: the level cells read only their variable's rows of the levels
* frame (first and last row, from one index per dataset) instead of the frame
* of every dataset so far, whose scan grew with the number of files.  The
* files differ in values, names and labels, so a cell reading another
* dataset's or variable's rows prints a different table.

capture noisily {
    quietly cd "`work'/run"
    local _t1 = "one " + char(96) + "x' " + char(36) + "y"
    local _t2 = "two " + char(34) + "q" + char(34)
    label define l3lab 0 "zero" 1 `"`_t1'"' 2 `"`_t2'"', replace
    forvalues j = 1/4 {
        clear
        quietly set obs `=40 + 10 * `j''
        generate byte c1 = mod(_n * `j', 5)
        generate byte c2 = mod(_n, 3)
        label values c2 l3lab
        generate str4 s1 = substr("abcd", 1 + mod(_n, `j' + 1), 1)
        * 60+ distinct values: no levels rows (more than maxfreq)
        generate int many = _n
        if `j' != 2 generate byte only`j' = mod(_n, 2)
        quietly replace c1 = . in 1/`j'
        quietly replace c2 = .a in 2
        quietly save "l3f`j'.dta", replace
    }
    quietly datamap, filelist(l3f1 l3f2 l3f3 l3f4) output(l3all.md)
    forvalues j = 1/4 {
        quietly datamap, single(l3f`j') output(l3one`j'.md)
    }
    forvalues j = 1/4 {
        mata: st_local("_n1", strofreal(rows(_l3rows("l3all.md", `j'))))
        mata: st_local("_eq", strofreal(_l3rows("l3all.md", `j') == _l3rows("l3one`j'.md", 1)))
        display "L3 file `j': rows `_n1' equal `_eq'"
        * the header, its rule, then one row per variable
        quietly describe using "l3f`j'.dta"
        assert `_n1' == 2 + r(k)
        assert `_eq' == 1
    }
    * the cells are counts of these data, not merely equal: file 3, c1
    * the row text holds backticks: it stays in Mata
    clear
    quietly use "l3f3.dta"
    quietly count if c1 == 0
    local _k0 = r(N)
    local _p0 = strtrim(string(100 * `_k0' / _N, "%9.1f"))
    mata: _l3r = _l3rows("l3all.md", 3)
    mata: _l3r = select(_l3r, strpos(_l3r, "| " + char(96) + "c1" + char(96) + " |") :== 1)
    mata: assert(rows(_l3r) == 1)
    mata: assert(strpos(_l3r, "| 0: " + st_local("_k0") + " (" + st_local("_p0") + "%)<br>1: ") > 0)
    mata: printf("L3 c1 row of file 3: %s\n", _l3r)
    capture mata: mata drop _l3r
}
local rc = _rc
capture mata: mata drop _l3rows()
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L3 datamap multi-file tables equal single-file tables (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L3 datamap multi-file tables equal single-file tables"'
}

**# L4 one observation: a missing summary in %21x form is stored as missing
* 2026-11-10: the variables row is stored by Mata, which reads each summary
* from its %21x text.  r(sd) of one observation is missing, and its %21x
* text (1.0000000000000X+3ff) is not a number to strtoreal(): the first
* Mata build stopped with r(198) there (validation_datamap_fixture_contract,
* single_row).

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 1
    generate double x = 2.5
    generate double z = -1e300
    quietly datamap, output(l4.txt) continuous(x z) saving(l4, replace)
    quietly use "l4.dta", clear
    quietly keep if variable == "x"
    assert _N == 1
    assert mean == 2.5 & p50 == 2.5 & p25 == 2.5 & p75 == 2.5
    assert min == 2.5 & max == 2.5
    assert sd == . & N == 1 & missing == 0
    quietly use "l4.dta", clear
    quietly keep if variable == "z"
    assert mean == -1e300 & sd == .
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L4 one observation: sd stored as missing, the other summaries exact (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L4 one observation: sd stored as missing, the other summaries exact"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_collector_limits tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
