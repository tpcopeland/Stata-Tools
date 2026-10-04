*! Exact baseline examples from the five current datamap help files and README
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

* The examples write to the working directory under their default names.
* Each output is erased before its example runs, so a file left by an
* earlier run cannot satisfy confirm file, and again at the end.
local doc_outputs datamap.txt auto_codebook.txt auto_map.json data_dictionary.md auto_dict.md
foreach f of local doc_outputs {
    capture erase "`qa_dir'/`f'"
}

* datamap.sthlp: the three self-contained getting-started examples.
foreach mode in text named json {
    local ++test_count
    capture noisily {
        sysuse auto, clear
        if "`mode'" == "text" datamap
        if "`mode'" == "named" datamap, output(auto_codebook.txt)
        if "`mode'" == "json" datamap, format(json) output(auto_map.json)
        assert !missing(r(nvars))
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
        assert !missing(r(nvars_total))
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
    assert !missing(r(N_patterns))
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
    assert !missing(r(n_string))
    assert r(n_continuous) + r(n_categorical) + r(n_date) + r(n_string) > 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

* datacheck.sthlp (1.8.0): the gate, band, statistic, review, ledger, and
* version examples exactly as printed.
local ++test_count
capture noisily {
    sysuse auto, clear
    datacheck, gatesonly expectn(74) isid(make) notmissing(price mpg) inrange(price weight 0 . \ mpg 10 50)
    assert r(n_violations) == 0 & r(n_checks) == 4
    datacheck, gatesonly isid(make) rule("heavy": weight > 1500) bands(expectn(70 80) stat(mean mpg 18 25 \ median price 4000 6000)) bandwarn maskrare
    assert r(n_violations) == 0 & r(maskrare) == 1
    datacheck, gatesonly stat(sum foreign 22 22 \ distinct rep78 5 5 \ mean mpg 20 30 if foreign)
    assert r(n_violations) == 0
    datacheck, gatesonly review("cheap": price < 4000) complete(rep78 mpg) groupstat(mean price mpg, by(foreign))
    assert r(n_reviews) == 4 & r(n_checks) == 0
    tempfile ledger
    datacheck, gatesonly isid(make) name(auto_cars) ledger("`ledger'", run(demo))
    assert r(ledger_seq) == 1 & "`r(dataset)'" == "auto_cars"
    capture datacheck, minversion(1.8.0)
    assert _rc == 0
    datacheck, rare(5) mincell(5) maskrare show(flagged)
}
if _rc == 0 local ++pass_count
else local ++fail_count

* dataqa.sthlp: the example sequence exactly as printed.
local ++test_count
capture noisily {
    tempfile ledger
    dataqa set maskrare mincell(5) ledger("`ledger'") run(demo)
    sysuse auto, clear
    datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)
    sysuse lifeexp, clear
    datacheck, gatesonly isid(country) name(lifeexp)
    dataqa report
    assert r(n_datasets) == 2 & r(n_failed) == 0
    dataqa assert, expect(auto_cars lifeexp)
    tempfile release
    dataqa export, saving("`release'") replace
    assert r(N) >= 1
    dataqa set clear
    assert `"$DATAMAP_DQ"' == ""
}
if _rc == 0 local ++pass_count
else local ++fail_count
macro drop DATAMAP_DQ

* datamvp.sthlp (1.8.0) and README example 10.
local ++test_count
capture noisily {
    sysuse auto, clear
    datamvp price mpg rep78 headroom, maskrare percent bytable(foreign)
    assert r(mincell) == 5 & rowsof(r(miss_by)) == 1
    datamvp price mpg rep78 headroom, top(3)
    assert r(N_patterns_pooled) == 0
    tempfile ledger
    dataqa set maskrare mincell(5) ledger("`ledger'") run(demo)
    sysuse auto, clear
    datacheck, gatesonly isid(make) rule("heavy": weight > 1500) bands(expectn(70 80) stat(mean mpg 18 25)) name(auto_cars)
    dataqa report
    dataqa assert, expect(auto_cars)
    dataqa set clear
}
if _rc == 0 local ++pass_count
else local ++fail_count
macro drop DATAMAP_DQ

foreach f of local doc_outputs {
    capture erase "`qa_dir'/`f'"
}

display "RESULT: test_datamap_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
