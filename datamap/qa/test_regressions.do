*! test_regressions.do Version 1.0.0  2026/08/11
*! Adversarial regressions from the datamap 1.6.5 deep review
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
adopath ++ "`pkg_dir'"
discard

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

**# datacheck stored-result name collisions

local ++test_count
capture noisily {
    clear
    set obs 4
    generate byte abcdefghijklmnopqrstuvwxyza = mod(_n, 2)
    generate long abcdefghijklmnopqrstuvwxyzb = _n
    quietly datacheck, id(abcdefghijklmnopqrstuvwxyza \ abcdefghijklmnopqrstuvwxyzb)
    assert r(n_dup_abcdefghijklmnopqrstuvwxyz) == 2
    assert r(n_dup_abcdefghijklmnopqrstuvwx_2) == 0
}
local rc = _rc
_reg_record `rc' "datacheck disambiguates truncated duplicate-key returns"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# datadict quote and path fidelity

**## Apostrophes in document text round-trip exactly
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile dict
    local dictfile "`dict'.md"
    quietly datadict, output("`dictfile'") title("Patient's dictionary") ///
        notes("Clinician's note")
    tempname fh
    file open `fh' using "`dictfile'", read text
    local saw_title = 0
    local saw_notes = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "# Patient's dictionary") > 0 local saw_title = 1
        if strpos(`"`macval(line)'"', "Clinician's note") > 0 local saw_notes = 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_title' == 1
    assert `saw_notes' == 1
}
local rc = _rc
_reg_record `rc' "datadict preserves apostrophes in title() and notes()"
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
    quietly datadict, single("`source'") output("`dict'.md")
    confirm file "`dict'.md"
    erase "`source'"
}
local rc = _rc
capture erase "`c(tmpdir)'/patient's cohort.dta"
_reg_record `rc' "datadict accepts dataset paths containing apostrophes"
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
    quietly datamap, output("`map'.txt")
    tempname fh
    file open `fh' using "`map'.txt", read text
    local saw_memory = 0
    local saw_tempfile = 0
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == "DATASET: memory" local saw_memory = 1
        if strpos(`"`macval(line)'"', "DATASET: St") == 1 local saw_tempfile = 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_memory' == 1
    assert `saw_tempfile' == 0
}
local rc = _rc
_reg_record `rc' "datamap hides in-memory transport tempfiles"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**## datadict report identifies data in memory, not its tempfile
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile dict
    quietly datadict, output("`dict'.md")
    tempname fh
    file open `fh' using "`dict'.md", read text
    local saw_heading = 0
    local saw_source = 0
    local saw_tempfile = 0
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == "## 1. Data in memory" local saw_heading = 1
        if `"`macval(line)'"' == "**Source:** data in memory  " local saw_source = 1
        if strpos(`"`macval(line)'"', "/St") > 0 local saw_tempfile = 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_heading' == 1
    assert `saw_source' == 1
    assert `saw_tempfile' == 0
}
local rc = _rc
_reg_record `rc' "datadict hides in-memory transport tempfiles"
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
    quietly datamap, output("`mapout'.txt") saving("`mapmeta'", replace)
    preserve
    use "`mapmeta'", clear
    assert source == "memory"
    assert dataset == "memory"
    restore

    quietly datadict, output("`dictout'.md") saving("`dictmeta'", replace)
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
    confirm file "memory_map.txt"
    erase "memory_map.txt"

    local source "`scratch_dir'/datamap separate source.dta"
    quietly save "`source'", replace
    quietly datamap, single("`source'") separate
    confirm file "`scratch_dir'/datamap separate source_map.txt"
    erase "`source'"
    erase "`scratch_dir'/datamap separate source_map.txt"
    cd "`original_dir'"
}
local rc = _rc
capture cd "`qa_dir'"
capture erase "`c(tmpdir)'/memory_map.txt"
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
    quietly datadict, output("`dict'.md") title(`"`want'"')
    tempname fh
    file open `fh' using "`dict'.md", read text
    file read `fh' line
    local got `"`macval(line)'"'
    file close `fh'
    assert `"`macval(got)'"' == `"# `macval(want)'"'
}
local rc = _rc
_reg_record `rc' "datadict round-trips embedded double and single quotes"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**## Alternate memory outputs also hide transport tempfiles
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile json
    quietly datamap, output("`json'.json") format(json)
    tempname jfh
    file open `jfh' using "`json'.json", read text
    local saw_json_memory = 0
    local saw_json_tempfile = 0
    file read `jfh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `""name": "memory""') > 0 local saw_json_memory = 1
        if strpos(`"`macval(line)'"', `""name": "St"') > 0 local saw_json_tempfile = 1
        file read `jfh' line
    }
    file close `jfh'
    assert `saw_json_memory' == 1
    assert `saw_json_tempfile' == 0

    local original_dir "`c(pwd)'"
    cd "`c(tmpdir)'"
    quietly datadict, separate
    confirm file "memory_dictionary.md"
    tempname dfh
    file open `dfh' using "memory_dictionary.md", read text
    local saw_heading = 0
    local saw_memory_source = 0
    local saw_tempfile = 0
    file read `dfh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == "# Data Dictionary: Data in memory" local saw_heading = 1
        if `"`macval(line)'"' == "**Source:** data in memory  " local saw_memory_source = 1
        if strpos(`"`macval(line)'"', "/St") > 0 local saw_tempfile = 1
        file read `dfh' line
    }
    file close `dfh'
    assert `saw_heading' == 1
    assert `saw_memory_source' == 1
    assert `saw_tempfile' == 0
    erase "memory_dictionary.md"
    cd "`original_dir'"
}
local rc = _rc
capture cd "`qa_dir'"
capture erase "`c(tmpdir)'/memory_dictionary.md"
_reg_record `rc' "JSON and separate outputs preserve the memory identity"
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
    quietly datadict, output("`dict'.md") title(`"`want'"')
    tempname fh
    file open `fh' using "`dict'.md", read text
    file read `fh' line
    local got `"`macval(line)'"'
    file close `fh'
    assert `"`macval(got)'"' == `"# `macval(want)'"'
}
local rc = _rc
_reg_record `rc' "datadict preserves literal outer quotes"
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
    quietly datadict, output("`dict'.md") saving("`meta'", replace)
    preserve
    use "`meta'", clear
    assert dataset_label == `"`want'"'
    restore
}
local rc = _rc
_reg_record `rc' "datadict metadata preserves quoted dataset labels"
if `rc' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**## Output paths reject shell metacharacters and literal quotes
local ++test_count
capture noisily {
    sysuse auto, clear
    local badsemi "`c(tmpdir)'/datamap;unsafe.txt"
    capture noisily datamap, output(`"`badsemi'"')
    local maprc = _rc
    capture erase `"`badsemi'"'
    assert `maprc' == 198

    local badquote = "`c(tmpdir)'/datadict" + char(34) + "unsafe.md"
    capture noisily datadict, output(`"`macval(badquote)'"')
    local dictquoterc = _rc
    capture erase `"`macval(badquote)'"'
    assert `dictquoterc' == 198

    local badtick = "`c(tmpdir)'/datadict" + char(96) + "unsafe.md"
    capture noisily datadict, output(`"`macval(badtick)'"')
    local dicttickrc = _rc
    capture erase `"`macval(badtick)'"'
    assert `dicttickrc' != 0
}
local rc = _rc
_reg_record `rc' "datamap and datadict enforce output path guards"
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
