*! test_regressions.do Version 1.0.0  2026/08/11
*! Adversarial regressions from the datamap 1.6.5 deep review
*! 2026-11-10 (datamap 2.0.0): datadict, the text layout and format(json) are
*! removed.  The datadict regressions (7, 8, 10, 14, 16, 17, 18) run on datamap's
*! Markdown writer in document mode; 9, 11, 12 read the Markdown/saving()
*! identity of data in memory ("## 1. Data in memory", "- Source: data in
*! memory", source/dataset "memory", memory_map.md); 15 lost its JSON half
*! (REMOVED FEATURE: no JSON writer, so no "name": "memory" key) and keeps the
*! separate half.  Documents are read through _qa_md.do (Mata): a document line
*! may end in a backtick, which stops a macro line reader.
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do "`qa_dir'/_qa_md.do"

* is the FIRST line of a document exactly the text in global REG_WANT prefixed "# "?
* (Mata: want holds quotes the macro layer would re-read)
capture program drop _reg_firstline
program define _reg_firstline, rclass
    version 16.0
    args file
    mata: st_numscalar("__rg_ok", _qa_md_cat(st_local("file"))[1] == "# " + st_global("REG_WANT"))
    return scalar ok = scalar(__rg_ok)
    scalar drop __rg_ok
end

capture program drop _reg_record
program define _reg_record
    version 16.0
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label' (error `rc')"
    }
end

**# datamvp output-name safety

**## Existing variables are rejected without partial output
local ++test_count
capture noisily {
    clear
    set obs 2
    generate double x = cond(_n == 1, ., 1)
    generate byte m_x = 42
    capture noisily datamvp x, generate(m)
    local cmdrc = _rc
    assert `cmdrc' == 110
    assert m_x == 42
    capture confirm variable m_pattern
    assert _rc == 111
    capture confirm variable m_nmiss
    assert _rc == 111
}
local rc = _rc
_reg_record `rc' "datamvp refuses existing generate() targets atomically"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## Reserved summary names cannot collide with source-variable indicators
local ++test_count
capture noisily {
    clear
    set obs 2
    generate double pattern = cond(_n == 1, ., 1)
    capture noisily datamvp pattern, generate(m)
    local cmdrc = _rc
    assert `cmdrc' == 198
    capture confirm variable m_pattern
    assert _rc == 111
    capture confirm variable m_nmiss
    assert _rc == 111
}
local rc = _rc
_reg_record `rc' "datamvp rejects reserved indicator-name collisions"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# datamvp matrix parser and error returns

**## Unknown matrix suboptions are errors
local ++test_count
capture noisily {
    clear
    set obs 3
    generate double x = cond(_n == 2, ., _n)
    capture noisily datamvp x, graph(matrix, bogus) nodraw
    assert _rc == 198
}
local rc = _rc
_reg_record `rc' "graph(matrix) rejects unknown suboptions"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**## Documented matrix suboptions still compose
local ++test_count
capture noisily {
    clear
    set obs 4
    generate double x = cond(inlist(_n, 2, 4), ., _n)
    generate double y = cond(_n == 3, ., _n)
    datamvp x y, graph(matrix, sample(2) sort) nodraw
    assert r(N) == 4
    assert r(N_vars) == 2
}
local rc = _rc
_reg_record `rc' "graph(matrix, sample() sort) remains valid"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**## Analytical returns survive a graph-side failure
local ++test_count
capture noisily {
    clear
    set obs 3
    generate double x = cond(_n == 2, ., _n)
    capture noisily datamvp x, graph(bar) nodraw graphoptions(not_a_graph_option)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert r(N) == 3
    assert r(N_vars) == 1
    assert r(N_mv_total) == 1
}
local rc = _rc
_reg_record `rc' "datamvp posts analytical returns before graph failure"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# dataprobe stored-result name collisions

local ++test_count
capture noisily {
    clear
    set obs 4
    generate byte abcdefghijklmnopqrstuvwxyza = mod(_n, 2)
    generate long abcdefghijklmnopqrstuvwxyzb = _n
    quietly dataprobe, id(abcdefghijklmnopqrstuvwxyza \ abcdefghijklmnopqrstuvwxyzb)
    assert r(n_dup_abcdefghijklmnopqrstuvwxyz) == 2
    assert r(n_dup_abcdefghijklmnopqrstuvwx_2) == 0
}
local rc = _rc
_reg_record `rc' "dataprobe disambiguates truncated duplicate-key returns"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# document-mode quote and path fidelity (was datadict)

**## Apostrophes in document text round-trip exactly
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile dict
    local dictfile "`dict'.md"
    quietly datamap, output("`dictfile'") title("Patient's dictionary") ///
        notes("Clinician's note")
    qa_md_contains using "`dictfile'", needle("# Patient's dictionary") exact
    assert r(n) == 1
    qa_md_contains using "`dictfile'", needle("Clinician's note") exact
    assert r(n) == 1
}
local rc = _rc
_reg_record `rc' "datamap preserves apostrophes in title() and notes()"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**## Apostrophes in dataset paths are not deleted
local ++test_count
capture noisily {
    sysuse auto, clear
    local source "`c(tmpdir)'/patient's cohort.dta"
    tempfile dict
    quietly save "`source'", replace
    quietly datamap, single("`source'") output("`dict'.md") title("T")
    confirm file "`dict'.md"
    * the apostrophe is in the Source line, not deleted
    qa_md_contains using "`dict'.md", needle("patient's cohort.dta")
    assert r(n) == 1
    erase "`source'"
}
local rc = _rc
capture erase "`c(tmpdir)'/patient's cohort.dta"
_reg_record `rc' "datamap accepts dataset paths containing apostrophes"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# In-memory source identity

**## datamap report identifies data in memory, not its tempfile
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile map
    quietly datamap, output("`map'.md")
    qa_md_contains using "`map'.md", needle("## 1. Data in memory") exact
    assert r(n) == 1
    qa_md_contains using "`map'.md", needle("- Source: data in memory") exact
    assert r(n) == 1
    qa_md_regex using "`map'.md", re("/St[0-9]")
    assert r(n) == 0
}
local rc = _rc
_reg_record `rc' "datamap hides in-memory transport tempfiles"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**## datamap document mode identifies data in memory, not its tempfile
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile dict
    quietly datamap, output("`dict'.md") title("T")
    qa_md_contains using "`dict'.md", needle("## 1. Data in memory") exact
    assert r(n) == 1
    qa_md_contains using "`dict'.md", needle("- Source: data in memory") exact
    assert r(n) == 1
    qa_md_regex using "`dict'.md", re("/St[0-9]")
    assert r(n) == 0
}
local rc = _rc
_reg_record `rc' "datamap document mode hides in-memory transport tempfiles"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**## Saved metadata uses the public memory identity
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile mapout mapmeta dictout dictmeta
    quietly datamap, output("`mapout'.md") saving("`mapmeta'", replace)
    preserve
    use "`mapmeta'", clear
    assert source == "memory"
    assert dataset == "memory"
    restore

    quietly datamap, output("`dictout'.md") saving("`dictmeta'", replace) title("T")
    preserve
    use "`dictmeta'", clear
    assert source == "memory"
    assert dataset == "memory"
    restore
}
local rc = _rc
_reg_record `rc' "in-memory metadata never exposes transport tempfiles"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**## separate works for memory and single-file inputs
local ++test_count
capture noisily {
    sysuse auto, clear
    local original_dir "`c(pwd)'"
    local scratch_dir "`c(tmpdir)'"
    cd "`scratch_dir'"
    quietly datamap, separate
    confirm file "memory_map.md"
    qa_md_contains using "memory_map.md", needle("## 1. Data in memory") exact
    assert r(n) == 1
    qa_md_rows using "memory_map.md"
    assert r(n) == 12
    erase "memory_map.md"

    local source "`scratch_dir'/datamap separate source.dta"
    quietly save "`source'", replace
    quietly datamap, single("`source'") separate
    confirm file "`scratch_dir'/datamap separate source_map.md"
    qa_md_contains using "`scratch_dir'/datamap separate source_map.md", needle("## 1. datamap separate source") exact
    assert r(n) == 1
    erase "`source'"
    erase "`scratch_dir'/datamap separate source_map.md"
    cd "`original_dir'"
}
local rc = _rc
capture cd "`qa_dir'"
capture erase "`c(tmpdir)'/memory_map.md"
capture erase "`c(tmpdir)'/datamap separate source.dta"
capture erase "`c(tmpdir)'/datamap separate source_map.txt"
_reg_record `rc' "datamap separate supports memory and single() inputs"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**# False-green probes after the first passing regression run

**## A collision in a late target still prevents every earlier generation
local ++test_count
capture noisily {
    clear
    set obs 2
    generate double x = cond(_n == 1, ., 1)
    generate int m_nmiss = 77
    capture noisily datamvp x, generate(m)
    local cmdrc = _rc
    assert `cmdrc' == 110
    assert m_nmiss == 77
    capture confirm variable m_x
    assert _rc == 111
    capture confirm variable m_pattern
    assert _rc == 111
}
local rc = _rc
_reg_record `rc' "datamvp late-target collision is atomic"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**## Embedded double and single quotes survive the helper boundary
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile dict
    local want `"Cohort "A" patient's dictionary"'
    quietly datamap, output("`dict'.md") title(`"`want'"')
    global REG_WANT `"`want'"'
    _reg_firstline "`dict'.md"
    assert r(ok) == 1
}
local rc = _rc
_reg_record `rc' "datamap round-trips embedded double and single quotes"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**## Separate output also hides transport tempfiles (was: alternate memory outputs)
local ++test_count
capture noisily {
    * 2026-11-10: the JSON half ("name": "memory") is removed with format(json)
    local original_dir "`c(pwd)'"
    cd "`c(tmpdir)'"
    quietly datamap, separate title("T")
    confirm file "memory_map.md"
    qa_md_contains using "memory_map.md", needle("- Source: data in memory") exact
    assert r(n) == 1
    qa_md_contains using "memory_map.md", needle("## 1. Data in memory") exact
    assert r(n) == 1
    qa_md_regex using "memory_map.md", re("/St[0-9]")
    assert r(n) == 0
    erase "memory_map.md"
    cd "`original_dir'"
}
local rc = _rc
capture cd "`qa_dir'"
capture erase "`c(tmpdir)'/memory_map.md"
_reg_record `rc' "separate output preserves the memory identity (JSON half removed)"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**## Literal outer quotes are content, not parser delimiters
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile dict
    local want `""Quoted patient's dictionary""'
    quietly datamap, output("`dict'.md") title(`"`want'"')
    global REG_WANT `"`want'"'
    _reg_firstline "`dict'.md"
    assert r(ok) == 1
}
local rc = _rc
_reg_record `rc' "datamap preserves literal outer quotes"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**## Quoted dataset labels survive metadata posting
local ++test_count
capture noisily {
    sysuse auto, clear
    local want `"Patient's "quoted" cohort"'
    label data `"`want'"'
    tempfile dict meta
    quietly datamap, output("`dict'.md") saving("`meta'", replace) title("T")
    preserve
    use "`meta'", clear
    assert dataset_label == `"`want'"'
    restore
}
local rc = _rc
_reg_record `rc' "datamap metadata preserves quoted dataset labels"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**## Output paths reject shell metacharacters and literal quotes
local ++test_count
capture noisily {
    sysuse auto, clear
    local badsemi "`c(tmpdir)'/datamap;unsafe.md"
    capture noisily datamap, output(`"`badsemi'"')
    local maprc = _rc
    capture erase `"`badsemi'"'
    assert `maprc' == 198

    local badquote = "`c(tmpdir)'/datamap" + char(34) + "unsafe.md"
    capture noisily datamap, output(`"`macval(badquote)'"') title("T")
    local dictquoterc = _rc
    capture erase `"`macval(badquote)'"'
    assert `dictquoterc' == 198

    local badtick = "`c(tmpdir)'/datamap" + char(96) + "unsafe.md"
    capture noisily datamap, output(`"`macval(badtick)'"') title("T")
    local dicttickrc = _rc
    capture erase `"`macval(badtick)'"'
    assert `dicttickrc' != 0
}
local rc = _rc
_reg_record `rc' "datamap (plain and document mode) enforces output path guards"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}

**# Summary

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    exit 1
}
