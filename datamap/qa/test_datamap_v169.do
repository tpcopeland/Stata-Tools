*! test_datamap_v169.do Version 1.0.0  2026/09/29
*! Regression coverage for the 1.6.9 fixes: date-format classification,
*! exclude() privacy in detectors, JSON escaping, caller-state safety,
*! float-precision gates, hostile string levels, and exact strL counts
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_datamap_v169.log", replace text

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local tmp_dir "`c(tmpdir)'/datamap_v169"
capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard

capture program drop _v169_record
program define _v169_record
    version 16.0
    args rc pass fail label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        c_local pass_count = `pass' + 1
        c_local fail_count = `fail'
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        c_local pass_count = `pass'
        c_local fail_count = `fail' + 1
    }
end

* Byte-exact file probes in Mata, so needles holding backticks, $ or quotes
* are never macro-expanded.
capture mata: mata drop _v169_slurp()
capture mata: mata drop _v169_has()
capture mata: mata drop _v169_ctrl()
mata:
string scalar _v169_slurp(string scalar path)
{
    real scalar fh, n
    string scalar s
    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fseek(fh, 0, -1)
    s = (n > 0 ? fread(fh, n) : "")
    fclose(fh)
    return(s)
}
real scalar _v169_has(string scalar path, string scalar needle)
{
    return(strpos(_v169_slurp(path), needle) > 0)
}
real scalar _v169_ctrl(string scalar path)
{
    string scalar s
    real scalar i, c, n
    s = _v169_slurp(path)
    n = 0
    for (i = 1; i <= strlen(s); i++) {
        c = ascii(substr(s, i, 1))
        if (c < 32 & c != 10 & c != 13) n++
    }
    return(n)
}
end

capture program drop _v169_has
program define _v169_has, rclass
    version 16.0
    args path
    tempname found
    mata: st_numscalar("`found'", _v169_has(st_local("path"), st_global("V169_NEEDLE")))
    return scalar found = `found'
end

**# T1: left-justified date formats (%-td, %-tc) classify as date
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double d1 = td(01jan2020) + _n
    format d1 %-td
    gen double tc1 = clock("01jan2020 10:00", "DMY hm") + _n * 1000
    format tc1 %-tc
    datamap, output("`tmp_dir'/t1.txt")
    local dv "`r(date_vars)'"
    assert `: list posof "d1" in dv' > 0
    assert `: list posof "tc1" in dv' > 0
    assert r(n_categorical) == 0
    * an exact date must never appear as a frequency cell
    global V169_NEEDLE "21916 = 21916"
    _v169_has "`tmp_dir'/t1.txt"
    assert r(found) == 0
    datacheck d1 tc1
    local dv "`r(date_vars)'"
    assert `: list posof "d1" in dv' > 0 & `: list posof "tc1" in dv' > 0
    datadict, output("`tmp_dir'/t1.md")
    mata: st_global("V169_NEEDLE", "| " + char(96) + "d1" + char(96) + " |  | Date |")
    _v169_has "`tmp_dir'/t1.md"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "%-td/%-tc classify as date in datamap, datacheck, datadict"

**# T2: JSON output stays valid with tab and other control bytes in labels
local ++test_count
capture noisily {
    clear
    set obs 20
    gen x = mod(_n, 2)
    label variable x "tab`=char(9)'here"
    gen y = mod(_n, 3)
    label variable y "bell`=char(1)'char"
    datamap, output("`tmp_dir'/t2.json") format(json)
    mata: st_numscalar("__v169_ctrl", _v169_ctrl("`tmp_dir'/t2.json"))
    assert scalar(__v169_ctrl) == 0
    mata: st_global("V169_NEEDLE", "tab" + char(92) + "there")
    _v169_has "`tmp_dir'/t2.json"
    assert r(found) == 1
    mata: st_global("V169_NEEDLE", "bell" + char(92) + "u0001char")
    _v169_has "`tmp_dir'/t2.json"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "JSON escapes raw control characters"

**# T3: caller matrices named vals/freqs survive text, JSON and binary routes
local ++test_count
capture noisily {
    clear
    set obs 30
    gen grp = mod(_n, 3)
    gen flag = mod(_n, 2)
    matrix vals = (99)
    matrix freqs = (77)
    datamap, output("`tmp_dir'/t3.txt") detect(binary)
    datamap, output("`tmp_dir'/t3.json") format(json)
    assert rowsof(vals) == 1 & vals[1,1] == 99
    assert rowsof(freqs) == 1 & freqs[1,1] == 77
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "user matrices vals/freqs are not clobbered"

**# T4: continuous stats below 1 in magnitude keep significant digits
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double conc = _n / 1000
    datamap, output("`tmp_dir'/t4.txt") continuous(conc)
    global V169_NEEDLE "Mean: .003"
    _v169_has "`tmp_dir'/t4.txt"
    assert r(found) == 1
    global V169_NEEDLE "Range: .001 to .005"
    _v169_has "`tmp_dir'/t4.txt"
    assert r(found) == 1
    mata: st_global("V169_NEEDLE", "Mean: 0" + char(10))
    _v169_has "`tmp_dir'/t4.txt"
    assert r(found) == 0
    * values >= 1 keep the historical 0.01 rounding
    clear
    set obs 4
    gen double w = _n + 0.123456
    datamap, output("`tmp_dir'/t4b.txt") continuous(w)
    global V169_NEEDLE "Mean: 2.62"
    _v169_has "`tmp_dir'/t4b.txt"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "small-scale continuous stats are not rounded to zero"

**# T5: exact counts work for strL (uniqcap(0) and panelid)
local ++test_count
capture noisily {
    clear
    set obs 40
    gen strL pid = "P" + string(ceil(_n / 2))
    gen strL notes = "n" + string(mod(_n, 7))
    _datamap_nuniq notes, countempty cap(0)
    assert r(n) == 7 & r(capped) == 0
    datamap, output("`tmp_dir'/t5.txt") uniqcap(0) panelid(pid)
    global V169_NEEDLE "Unique Units: 20"
    _v169_has "`tmp_dir'/t5.txt"
    assert r(found) == 1
    global V169_NEEDLE "Unique Values: 7"
    _v169_has "`tmp_dir'/t5.txt"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "strL exact distinct counts (uniqcap(0), panelid)"

**# T6: excluded variables leak through no summary or detector
local ++test_count
capture noisily {
    clear
    set obs 30
    gen double dob = td(05mar1951) + _n * 100
    format dob %td
    gen double visit = td(01jan2020) + _n
    format visit %td
    gen double followup_time = _n * 3.3
    gen double weight_s = 1 + _n / 10
    gen double stratum = mod(_n, 4)
    gen double patient_id = ceil(_n / 3)
    datamap, output("`tmp_dir'/t6.txt") ///
        exclude(dob followup_time weight_s stratum patient_id) ///
        detect(survival survey panel)
    * DESCRIPTION range comes from visit only
    global V169_NEEDLE "spans from 2020/01/02 to 2020/01/31"
    _v169_has "`tmp_dir'/t6.txt"
    assert r(found) == 1
    global V169_NEEDLE "1951/"
    _v169_has "`tmp_dir'/t6.txt"
    assert r(found) == 0
    global V169_NEEDLE "followup_time range"
    _v169_has "`tmp_dir'/t6.txt"
    assert r(found) == 0
    global V169_NEEDLE "range: 1.1 to 4"
    _v169_has "`tmp_dir'/t6.txt"
    assert r(found) == 0
    global V169_NEEDLE "(4 strata)"
    _v169_has "`tmp_dir'/t6.txt"
    assert r(found) == 0
    global V169_NEEDLE "Unique Units"
    _v169_has "`tmp_dir'/t6.txt"
    assert r(found) == 0
    * an explicit panelid() that is excluded withholds its unit count
    datamap, output("`tmp_dir'/t6b.txt") exclude(patient_id) panelid(patient_id)
    global V169_NEEDLE "units observed"
    _v169_has "`tmp_dir'/t6b.txt"
    assert r(found) == 0
    global V169_NEEDLE "Unique Units"
    _v169_has "`tmp_dir'/t6b.txt"
    assert r(found) == 0
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "exclude() withholds dates, ranges, weights, counts in detectors"

**# T7: event rate only under 0/1 coding
local ++test_count
capture noisily {
    clear
    set obs 30
    gen byte died = 1 + (_n > 20)
    gen double survtime = _n
    datamap, output("`tmp_dir'/t7.txt") detect(survival)
    global V169_NEEDLE "rate:"
    _v169_has "`tmp_dir'/t7.txt"
    assert r(found) == 0
    replace died = died - 1
    datamap, output("`tmp_dir'/t7b.txt") detect(survival)
    global V169_NEEDLE "died rate: 33.3%"
    _v169_has "`tmp_dir'/t7b.txt"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "survival event rate never exceeds 100%"

**# T8: survivalvars() selects the survival variables
local ++test_count
capture noisily {
    clear
    set obs 30
    gen double fu_days = 10 + _n
    gen byte dead = (_n > 20)
    gen double followup_time = _n * 3.3
    datamap, output("`tmp_dir'/t8.txt") survivalvars(fu_days dead)
    global V169_NEEDLE "fu_days range: 11 to 40"
    _v169_has "`tmp_dir'/t8.txt"
    assert r(found) == 1
    global V169_NEEDLE "Likely event indicators: dead"
    _v169_has "`tmp_dir'/t8.txt"
    assert r(found) == 1
    global V169_NEEDLE "Likely time variables: followup_time"
    _v169_has "`tmp_dir'/t8.txt"
    assert r(found) == 0
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "survivalvars() is honored"

**# T9: missing IDs do not fabricate a panel
local ++test_count
capture noisily {
    clear
    set obs 30
    gen double pat_id = cond(_n <= 10, ., _n)
    datamap, output("`tmp_dir'/t9.txt") detect(panel)
    global V169_NEEDLE "Panel Structure Detected"
    _v169_has "`tmp_dir'/t9.txt"
    assert r(found) == 0
    * genuine panel plus missing IDs: average over identified rows
    replace pat_id = ceil((_n - 10) / 4) if _n > 10
    datamap, output("`tmp_dir'/t9b.txt") detect(panel)
    global V169_NEEDLE "Unique Units: 5"
    _v169_has "`tmp_dir'/t9b.txt"
    assert r(found) == 1
    global V169_NEEDLE "Observations with missing ID: 10"
    _v169_has "`tmp_dir'/t9b.txt"
    assert r(found) == 1
    global V169_NEEDLE "Average Obs per Unit: 4"
    _v169_has "`tmp_dir'/t9b.txt"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "panel detection ignores missing IDs"

**# T10: saving() uses the report's unique-count cap
local ++test_count
capture noisily {
    clear
    set obs 3000
    gen long code = mod(_n, 1500)
    datamap, output("`tmp_dir'/t10.txt") maxcat(1500) uniqcap(2000) ///
        saving("`tmp_dir'/t10.dta", replace)
    datamap, output("`tmp_dir'/t10b.txt") uniqcap(0) ///
        saving("`tmp_dir'/t10b.dta", replace)
    use "`tmp_dir'/t10b.dta", clear
    assert unique[1] == 1500 & unique_capped[1] == 0
    use "`tmp_dir'/t10.dta", clear
    assert class[1] == "categorical" & unique[1] == 1500
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "saving() honors maxcat()/uniqcap()"

**# T11: datadict string levels with quotes and backticks
local ++test_count
capture noisily {
    clear
    set obs 30
    gen str20 q = cond(mod(_n, 2), `"say "hi""', "plain")
    gen str20 r = cond(mod(_n, 3) == 0, "a" + char(96) + "b", "c" + char(36) + "d")
    datadict, output("`tmp_dir'/t11.md") mincell(0) categorical(q r) stats
    global V169_NEEDLE `"say "hi" (15; 50.0%)"'
    _v169_has "`tmp_dir'/t11.md"
    assert r(found) == 1
    global V169_NEEDLE "a&#96;b (10; 33.3%)"
    _v169_has "`tmp_dir'/t11.md"
    assert r(found) == 1
    global V169_NEEDLE "c&#36;d (20; 66.7%)"
    _v169_has "`tmp_dir'/t11.md"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "datadict counts hostile string levels exactly"

**# T12: datacheck value/range gates compare floats at float precision
local ++test_count
capture noisily {
    clear
    set obs 20
    gen float dose = cond(mod(_n, 2), 0.1, 0.2)
    datacheck, allowed(dose 0.1 0.2) inrange(dose 0 0.2) warn
    assert r(n_violations) == 0
    datacheck, forbid(dose 0.1) warn
    assert r(n_violations) == 1
    datacheck, notvalues(dose 0.2) warn
    assert r(n_violations) == 1
    * bounds beyond float range must not flag every row
    datacheck, inrange(dose -1e40 1e40) warn
    assert r(n_violations) == 0
    datacheck, inrange(dose 0.15 1e40) warn
    assert r(n_violations) == 1
    * doubles keep exact comparison
    gen double ddose = 0.1
    datacheck, allowed(ddose 0.1) warn
    assert r(n_violations) == 0
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "datacheck float gates (allowed/inrange/forbid/notvalues)"

**# T13: datacheck display: span units and hostile/float levels
local ++test_count
capture noisily {
    clear
    set obs 20
    gen double ym = tm(2020m1) + _n
    format ym %tm
    gen str10 s = cond(mod(_n, 2), "a" + char(96) + "b", "plain")
    gen float f = cond(mod(_n, 2), 0.1, 0.2)
    capture log close _v169probe
    log using "`tmp_dir'/t13.log", text replace name(_v169probe)
    datacheck ym s f, categorical(s f)
    log close _v169probe
    global V169_NEEDLE "span=19 months"
    _v169_has "`tmp_dir'/t13.log"
    assert r(found) == 1
    global V169_NEEDLE "as result %9.0f"
    _v169_has "`tmp_dir'/t13.log"
    assert r(found) == 0
    mata: st_global("V169_NEEDLE", "    a" + char(96) + "b ")
    _v169_has "`tmp_dir'/t13.log"
    assert r(found) == 1
    global V169_NEEDLE ".1000000014901161"
    _v169_has "`tmp_dir'/t13.log"
    assert r(found) == 0
}
local test_rc = _rc
capture log close _v169probe
_v169_record `test_rc' `pass_count' `fail_count' "datacheck span units and level display"

**# T14: datamvp sort keeps input order on ties; matrix graph label is private
local ++test_count
capture noisily {
    clear
    set obs 12
    gen a = _n
    replace a = .a in 1/3
    gen b = _n
    replace b = .z in 2/5
    gen strL c = "x"
    replace c = "" in 6
    gen d = 1
    gen e = 1
    gen f = 1
    replace d = . in 7
    replace e = . in 8
    replace f = . in 9
    datamvp a b c d e f, sort
    assert "`r(varlist)'" == "b a c d e f"
    assert r(N_complete) == 3 & r(N_mv_total) == 11 & r(N_patterns) == 8
    label define _varlab 1 "mine"
    datamvp a b, graph(matrix) nodraw
    assert "`: label _varlab 1'" == "mine"
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "datamvp stable sort ties and private matrix label"

**# T15: float categorical levels display without IEEE noise
local ++test_count
capture noisily {
    clear
    set obs 30
    gen float tenth = mod(_n, 3) / 10
    datamap, output("`tmp_dir'/t15.txt") mincell(0)
    global V169_NEEDLE ".1 = .1: 10 (33.3%)"
    _v169_has "`tmp_dir'/t15.txt"
    assert r(found) == 1
    datamap, output("`tmp_dir'/t15.json") format(json) mincell(0)
    global V169_NEEDLE ".1000000014901161"
    _v169_has "`tmp_dir'/t15.txt"
    assert r(found) == 0
    _v169_has "`tmp_dir'/t15.json"
    assert r(found) == 0
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "float categorical levels print at float precision"

**# T16: datamvp gby()/over() graphs on non-integer float levels
local ++test_count
capture noisily {
    clear
    set obs 12
    gen a = _n
    replace a = . in 1/3
    gen b = _n
    replace b = . in 2/5
    gen float g = cond(_n <= 6, 0.1, 0.2)
    * over(): one serset holding every bar
    datamvp a b, graph(bar) over(g) nodraw gname(_v169_over)
    preserve
    serset use, clear
    sort overid varname
    * level 0.1 (overid 1): a 3/6 missing, b 4/6 missing; level 0.2: none
    assert _N == 4
    assert !missing(pctmiss)
    assert !missing(pctmiss[1]) & !missing(pctmiss[2])
    assert reldif(pctmiss[1], 50) < 1e-9 & reldif(pctmiss[2], 400/6) < 1e-9
    assert pctmiss[3] == 0 & pctmiss[4] == 0
    restore
    * gby(): one serset per facet; the first facet is level 0.1
    graph drop _v169_over
    serset clear
    datamvp a b, graph(bar) gby(g) nodraw gname(_v169_gby)
    preserve
    serset set 0
    serset use, clear
    assert !missing(_values)
    quietly summarize _values
    assert !missing(r(max)) & !missing(r(min))
    assert reldif(r(max), 400/6) < 1e-9 & reldif(r(min), 50) < 1e-9
    restore
    * pattern chart faceted by a float level must draw
    datamvp a b, graph(patterns) gby(g) nodraw gname(_v169_pat)
    graph drop _v169_gby _v169_pat
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "datamvp gby()/over() bars on float levels"

**# T17: datacheck never flags or lists excluded variables
local ++test_count
capture noisily {
    clear
    set obs 30
    gen a = cond(_n <= 4, ., _n)
    gen secret = cond(_n <= 10, ., 1)
    gen double k = _n
    capture log close _v169probe
    log using "`tmp_dir'/t17.log", text replace name(_v169probe)
    datacheck, exclude(secret) patterns
    local mv "`r(missing_vars)'"
    local fv "`r(flagged_vars)'"
    local nmv = r(n_missing_vars)
    log close _v169probe
    assert `: list posof "secret" in mv' == 0
    assert `: list posof "secret" in fv' == 0
    assert `: list posof "a" in mv' > 0
    assert `nmv' == 1
    * the datamvp pattern table must not profile it either
    global V169_NEEDLE "secret       |"
    _v169_has "`tmp_dir'/t17.log"
    assert r(found) == 0
}
local test_rc = _rc
capture log close _v169probe
_v169_record `test_rc' `pass_count' `fail_count' "datacheck exclude() stays out of missing/flagged lists"

**# T18: format(json) refuses text-only sections
local ++test_count
capture noisily {
    clear
    set obs 20
    gen double id = ceil(_n / 2)
    gen double x = _n
    foreach o in "detect(panel)" "autodetect" "panelid(id)" "survivalvars(x)" ///
        "samples(2)" "quality" "quality2(strict)" "missing(detail)" {
        capture datamap, format(json) output("`tmp_dir'/t18.json") `o'
        assert _rc == 198
    }
    datamap, format(json) output("`tmp_dir'/t18.json")
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "format(json) refuses detect/samples/quality/missing"

**# T19: missing(pattern) writes the joint missingness patterns
local ++test_count
capture noisily {
    clear
    set obs 30
    gen a = cond(_n <= 4, ., _n)
    gen b = cond(_n >= 27, ., _n)
    gen c = cond(_n <= 10, ., 1)
    gen double k = _n
    datamap, output("`tmp_dir'/t19a.txt") missing(detail)
    datamap, output("`tmp_dir'/t19b.txt") missing(pattern)
    global V169_NEEDLE "Distinct patterns"
    _v169_has "`tmp_dir'/t19a.txt"
    assert r(found) == 0
    global V169_NEEDLE "Pattern variables, in order: a b c"
    _v169_has "`tmp_dir'/t19b.txt"
    assert r(found) == 1
    global V169_NEEDLE "Distinct patterns: 4"
    _v169_has "`tmp_dir'/t19b.txt"
    assert r(found) == 1
    * hand counts: +++ 16, ++. 6 (rows 5-10), +.+ 4, .+. 4
    global V169_NEEDLE "+++: 16 (53.3%)"
    _v169_has "`tmp_dir'/t19b.txt"
    assert r(found) == 1
    global V169_NEEDLE "++.: 6 (20%)"
    _v169_has "`tmp_dir'/t19b.txt"
    assert r(found) == 1
    global V169_NEEDLE ".+.: suppressed (<5)"
    _v169_has "`tmp_dir'/t19b.txt"
    assert r(found) == 1
    * the caller's data and sort order are untouched
    assert k[1] == 1 & k[30] == 30
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "missing(pattern) differs from missing(detail)"

**# T20: string variables forced categorical get frequency tables
local ++test_count
capture noisily {
    clear
    set obs 30
    gen str12 s = cond(mod(_n, 3) == 0, "a" + char(96) + "b", ///
        cond(mod(_n, 3) == 1, `"say "hi""', "z" + char(36) + "x"))
    replace s = "" in 1
    datamap, output("`tmp_dir'/t20.txt") categorical(s) mincell(0)
    global V169_NEEDLE "(frequency table unavailable)"
    _v169_has "`tmp_dir'/t20.txt"
    assert r(found) == 0
    mata: st_global("V169_NEEDLE", char(34) + "a" + char(96) + "b" + char(34) + ": 10 (33.3%)")
    _v169_has "`tmp_dir'/t20.txt"
    assert r(found) == 1
    global V169_NEEDLE `""say "hi"": 9 (30.0%)"'
    _v169_has "`tmp_dir'/t20.txt"
    assert r(found) == 1
    mata: st_global("V169_NEEDLE", char(34) + "z" + char(36) + "x" + char(34) + ": 10 (33.3%)")
    _v169_has "`tmp_dir'/t20.txt"
    assert r(found) == 1
    datamap, output("`tmp_dir'/t20.json") format(json) categorical(s) mincell(5)
    mata: st_numscalar("__v169_ctrl", _v169_ctrl("`tmp_dir'/t20.json"))
    assert scalar(__v169_ctrl) == 0
    mata: st_global("V169_NEEDLE", char(34) + "value" + char(34) + ": " + char(34) + "say " + char(92) + char(34) + "hi" + char(92) + char(34) + char(34))
    _v169_has "`tmp_dir'/t20.json"
    assert r(found) == 1
    global V169_NEEDLE `""count": 9,"'
    _v169_has "`tmp_dir'/t20.json"
    assert r(found) == 1
}
local test_rc = _rc
_v169_record `test_rc' `pass_count' `fail_count' "string categorical frequency tables (text and JSON)"

macro drop V169_NEEDLE
display "RESULT: test_datamap_v169 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
if `fail_count' > 0 exit 1
