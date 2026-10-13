clear all
set more off
set varabbrev off
version 16.0

capture log close _all
log using "test_compress_tc_report.log", replace text nomsg

capture ado uninstall compress_tc
local pkg_dir = subinstr("`c(pwd)'", "/qa", "", 1)
adopath ++ "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0


capture program drop _ct_probe
program define _ct_probe, rclass
    syntax , OPTS(string)
    tempfile cap
    capture log close _ctp
    log using "`cap'", replace text name(_ctp)
    compress_tc, `opts'
    local saved = r(bytes_saved)
    local sb = r(bytes_strl)
    log close _ctp
    tempname fh
    local heap 0
    local lowhint 0
    local lownote 0
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Note: strL bytes live") local heap 1
        if strpos(`"`line'"', "use lowmem for measured") local lowhint 1
        if strpos(`"`line'"', "under lowmem, compress") local lownote 1
        file read `fh' line
    }
    file close `fh'
    return scalar saved = `saved'
    return scalar strl = `sb'
    return scalar heap = `heap'
    return scalar lowhint = `lowhint'
    return scalar lownote = `lownote'
end

* T1: report is self-explanatory: the per-variable table accounts for numeric
* retyping and the compress-vs-Overall difference is explained
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile cap
    log using "`cap'", replace text name(cap)
    compress_tc, varsavings
    local saved = r(bytes_saved)
    log close cap
    tempname fh
    local note 0
    local other 0
    local oline ""
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Overall below is measured against the original") local note 1
        if strpos(`"`line'"', "(other variables)") {
            local other 1
            local oline `"`line'"'
        }
        file read `fh' line
    }
    file close `fh'
    assert `note' == 1
    assert `other' == 1
    * four int -> byte conversions at 74 obs save 4*74 = 296 bytes
    assert strpos(`"`oline'"', "4 retyped") > 0
    assert strpos(`"`oline'"', "296 B") > 0
    * make (74 B) + other (296 B) = Overall saved
    assert `saved' == 74 + 296
}
if _rc == 0 {
    local ++pass_count
    display "PASS: T1 note and other-variables row"
}
else {
    local ++fail_count
    display "FAIL: T1 note and other-variables row"
}

* guard: T2 is expected green at HEAD (behaviour-preservation guard)
* T2: no explanatory note or other-variables row when nothing was strL-converted
* or retyped
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile cap2
    log using "`cap2'", replace text name(cap2)
    compress_tc make, nostrl varsavings
    log close cap2
    tempname fh
    local bad 0
    file open `fh' using "`cap2'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Overall below is measured") local bad 1
        if strpos(`"`line'"', "(other variables)") local bad 1
        file read `fh' line
    }
    file close `fh'
    assert `bad' == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS: T2 no spurious note or row"
}
else {
    local ++fail_count
    display "FAIL: T2 no spurious note or row"
}

* T3: dryrun projects exactly what a real run reports
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly compress_tc, quietly
    local real_saved = r(bytes_saved)
    local real_strl = r(bytes_strl)
    sysuse auto, clear
    quietly compress_tc, dryrun quietly
    assert r(bytes_saved) == `real_saved'
    assert r(bytes_strl) == `real_strl'
    assert r(bytes_saved) == 370
    assert r(bytes_strl) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS: T3 dryrun matches real run"
}
else {
    local ++fail_count
    display "FAIL: T3 dryrun matches real run"
}

* T4: the strL heap note prints only when a variable stays strL, and the
* lowmem suggestion is dropped under lowmem
local ++test_count
capture noisily {
    sysuse auto, clear
    _ct_probe, opts(varsavings)
    assert r(heap) == 0
    assert r(lowhint) == 0
    clear
    set obs 100
    gen str200 s = cond(mod(_n, 2), "a", "b") + 199 * "x"
    _ct_probe, opts(varsavings)
    assert r(heap) == 1
    assert r(lowhint) == 1
    clear
    set obs 100
    gen str200 s = cond(mod(_n, 2), "a", "b") + 199 * "x"
    _ct_probe, opts(varsavings lowmem)
    assert r(heap) == 1
    assert r(lowhint) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS: T4 strL heap note only when relevant"
}
else {
    local ++fail_count
    display "FAIL: T4 strL heap note only when relevant"
}

* T5: under lowmem the compress-vs-Overall note names the lowmem difference
local ++test_count
capture noisily {
    sysuse auto, clear
    _ct_probe, opts(lowmem)
    assert r(lownote) == 1
    assert r(saved) == 370
}
if _rc == 0 {
    local ++pass_count
    display "PASS: T5 lowmem note wording"
}
else {
    local ++fail_count
    display "FAIL: T5 lowmem note wording"
}

display "RESULT: test_compress_tc_report tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
