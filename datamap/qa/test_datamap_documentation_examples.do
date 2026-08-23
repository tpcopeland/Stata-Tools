*! Exact baseline examples from the four current datamap help files
*! Date: 2026-08-23

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
adopath ++ "`pkg_dir'"
local test_count = 0
local pass_count = 0
local fail_count = 0

* datamap.sthlp: the three self-contained getting-started examples.
foreach mode in text named json {
    local ++test_count
    capture noisily {
        sysuse auto, clear
        if "`mode'" == "text" datamap
        if "`mode'" == "named" datamap, output(auto_codebook.txt)
        if "`mode'" == "json" datamap, format(json) output(auto_map.json)
        assert r(nfiles) == 1 & r(nobs) == _N & r(nvars) > 0
        if "`mode'" == "text" confirm file "`qa_dir'/datamap.txt"
        if "`mode'" == "named" confirm file "`qa_dir'/auto_codebook.txt"
        if "`mode'" == "json" confirm file "`qa_dir'/auto_map.json"
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

* datadict.sthlp: all examples with displayed self-contained setup.
foreach mode in plain titled stats {
    local ++test_count
    capture noisily {
        sysuse auto, clear
        if "`mode'" == "plain" datadict
        if "`mode'" == "titled" datadict, title("Auto Dataset") author("Timothy P Copeland, Karolinska Institutet")
        if "`mode'" == "stats" datadict, missing stats output(auto_dict.md)
        assert r(nfiles) == 1 & r(nvars_total) > 0
        if "`mode'" == "stats" confirm file "`qa_dir'/auto_dict.md"
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

* datamvp.sthlp: basic and generated-indicator examples exactly as printed.
local ++test_count
capture noisily {
    sysuse auto, clear
    datamvp
    assert r(N) == _N & r(N_patterns) > 0
    datamvp, generate(m)
    tab m_pattern
    confirm variable m_pattern
}
if _rc == 0 local ++pass_count
else local ++fail_count

* datacheck.sthlp: basic in-memory profile exactly as printed.
local ++test_count
capture noisily {
    sysuse auto, clear
    datacheck
    assert r(N) == _N & r(n_checks) == 0
    assert r(n_string) == 1
    assert r(n_continuous) + r(n_categorical) + r(n_date) + r(n_string) > 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_datamap_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
