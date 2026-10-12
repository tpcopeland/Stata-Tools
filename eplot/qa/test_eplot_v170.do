*! test_eplot_v170.do - Regression tests for eplot 1.7.0
*! Data and frame modes: a row with no estimate or no interval is left out
*! with a note naming it (labels() text or observation number, at most five
*! then a count), type() structural rows are never named, and a row with
*! exactly one missing limit exits 198 naming it, inside if/in only.
*! Multi-model msymbol(): one symbol per model in model order, one symbol for
*! all, and a count mismatch refused.  Hostile label text (` $ ' and quotes,
*! from labels(), variable labels and value labels) drawn exactly and kept
*! verbatim in a note listing several rows, read from
*! the exported SVG, and carried exactly into export() and back via frame().
*! eform axis titles for 16 estimation commands compared, case-insensitively,
*! with the exponentiated-column header of each command's own replayed table,
*! and the generic title where Stata's column reads exp(b).

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v170.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap
do "`qa_dir'/_qa_hostile.do"

global V170_CAPN 0
local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Runs a command with its console output captured in a text file (in the
* caller's tempfile directory, so it outlives this program) and returns the
* file (r(file)), the command's rc (r(rc)) and, when it ran,
* its r(N) and r(k) (log close clears r(), so they are copied first).
capture program drop _v170_capture
program define _v170_capture, rclass
    version 16.0
    gettoken cmd 0 : 0
    global V170_CAPN = $V170_CAPN + 1
    local f "`c(tmpdir)'/v170_capture_$V170_CAPN.log"
    local ls = c(linesize)
    set linesize 255
    quietly log using `"`f'"', text name(_v170cap) replace
    capture noisily `cmd'
    local rc = _rc
    set linesize `ls'
    local N = r(N)
    local k = r(k)
    quietly log close _v170cap
    return local file `"`f'"'
    return scalar rc = `rc'
    return scalar N = `N'
    return scalar k = `k'
end

* r(n) = number of occurrences of the text held in global V170_NEEDLE in a
* file (the needle travels in a global so it is never macro-expanded).
capture program drop _v170_count
program define _v170_count, rclass
    version 16.0
    args file
    mata: st_numscalar("r(n)", _v170_occ(`"`file'"', st_global("V170_NEEDLE")))
    return scalar n = r(n)
end
mata:
real scalar _v170_occ(string scalar fn, string scalar needle)
{
    real scalar fh, n
    string scalar txt, chunk
    // fread, not fget: an SVG can be one line longer than fget returns.
    fh = fopen(fn, "r")
    txt = ""
    while ((chunk = fread(fh, 65536)) != J(0, 0, "")) txt = txt + chunk
    fclose(fh)
    // Stata's SVG writer turns the blanks of a text with a leading blank
    // into no-break spaces; compare them as blanks.
    txt = subinstr(txt, uchar(160), " ")
    n = 0
    while (strpos(txt, needle)) {
        n++
        txt = substr(txt, strpos(txt, needle) + strlen(needle), .)
    }
    return(n)
}
end

* r(header) = the coefficient-column header of the first estimation table in
* a captured log ("Odds ratio", "IRR", "exp(b)", ...): Stata's own name for
* the exponentiated column, the oracle for eplot's eform axis title.
capture program drop _v170_header
program define _v170_header, rclass
    version 16.0
    args file
    mata: st_global("r(header)", _v170_hdr(`"`file'"'))
    return local header `"`r(header)'"'
end
mata:
string scalar _v170_hdr(string scalar fn)
{
    real scalar fh, p, q
    string scalar line
    fh = fopen(fn, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        p = strpos(line, "|")
        q = strpos(strlower(line), "std. err.")
        if (p & q > p) {
            fclose(fh)
            return(strtrim(substr(line, p + 1, q - p - 1)))
        }
    }
    fclose(fh)
    return("")
}
end

**# I1: rows with a missing estimate or interval are named, not dropped silently
**## 1. labelled rows: note names them, r(N)/r(k) count only plotted rows
local ++test_count
capture noisily {
    clear
    input str12 study double(es lci uci)
    "Study A" 0.5 0.2 0.8
    "Gone"    .   .   .
    "Pt only" 0.4 .   .
    "No est"  .   0.1 0.3
    "Study B" 0.3 0.1 0.5
    end
    _v170_capture `"eplot es lci uci, labels(study) nodraw"'
    assert r(rc) == 0
    local f `"`r(file)'"'
    assert r(N) == 2 & r(k) == 2
    global V170_NEEDLE "(note: 3 row(s) not plotted because the estimate or the interval is missing: Gone, Pt only, No est;"
    _v170_count `"`f'"'
    assert r(n) == 1
    global V170_NEEDLE "give them type() code 2"
    _v170_count `"`f'"'
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 2. no labels(): observation numbers, five shown then a count
local ++test_count
capture noisily {
    clear
    set obs 12
    gen double es = cond(_n <= 4 | _n >= 9, ., 1)
    gen double lo = 0.5
    gen double hi = 2
    _v170_capture `"eplot es lo hi, nodraw"'
    assert r(rc) == 0
    global V170_NEEDLE "missing: obs 1, obs 2, obs 3, obs 4, obs 9, and 3 more;"
    _v170_count `"`r(file)'"'
    assert r(n) == 1
    * Rows outside if/in are neither plotted nor named.
    _v170_capture `"eplot es lo hi in 3/10, nodraw"'
    assert r(rc) == 0
    global V170_NEEDLE "(note: 4 row(s) not plotted because the estimate or the interval is missing: obs 3, obs 4, obs 9, obs 10;"
    _v170_count `"`r(file)'"'
    assert r(n) == 1
    * Nothing missing: no note at all.
    _v170_capture `"eplot es lo hi in 5/8, nodraw"'
    global V170_NEEDLE "not plotted because"
    _v170_count `"`r(file)'"'
    assert r(n) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 3. type(): structural rows are kept and never named; type 2 shows the row
local ++test_count
capture noisily {
    clear
    input str12 study double(es lci uci) byte t
    "Header"  .   .   .   0
    "Study A" 0.5 0.2 0.8 1
    "Absent"  .   .   .   1
    "Shown"   .   .   .   2
    "Spacer"  .   .   .   6
    "Overall" .   .   .   5
    end
    _v170_capture `"eplot es lci uci, labels(study) type(t) nodraw"'
    assert r(rc) == 0
    local f `"`r(file)'"'
    * Header, Study A, Shown, Spacer are display rows; Absent and Overall
    * (a pooled row without an estimate) are left out and named.
    assert r(N) == 4 & r(k) == 1
    global V170_NEEDLE "(note: 2 row(s) not plotted because the estimate or the interval is missing: Absent, Overall;"
    _v170_count `"`f'"'
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 4. exactly one missing limit: r(198) naming the row, data and frame modes
local ++test_count
capture noisily {
    clear
    input str12 study double(es lci uci) byte t
    "Study A" 0.5 0.2 0.8 1
    "Half lo" 0.4 .   0.6 1
    "Half hi" .   0.1 .   1
    "Hdr"     .   0.1 .   0
    end
    _v170_capture `"eplot es lci uci, labels(study) type(t) nodraw"'
    assert r(rc) == 198
    local f `"`r(file)'"'
    global V170_NEEDLE "confidence limits must be supplied as complete lower/upper pairs;"
    _v170_count `"`f'"'
    assert r(n) == 1
    * The type-0 row with one limit is structural and not named.
    global V170_NEEDLE "2 effect row(s) have exactly one missing limit: Half lo, Half hi"
    _v170_count `"`f'"'
    assert r(n) == 1
    * Outside if/in the half row is not consulted.
    eplot es lci uci in 1, labels(study) nodraw
    assert r(k) == 1
    capture frame drop v170_fr
    frame put study es lci uci t, into(v170_fr)
    frame v170_fr: rename (study es lci uci t) (label estimate ll ul rowtype)
    capture eplot, frame(v170_fr) nodraw
    assert _rc == 198
    frame drop v170_fr
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 4b. hostile labels in a note listing several rows stay verbatim
local ++test_count
capture noisily {
    global QA_HS_GLB "EXPANDED"
    clear
    quietly set obs 4
    gen str40 lab = ""
    mata: st_sstore(1, "lab", "Bad" + char(96) + "x" + char(39) + " " + char(36) + "QA_HS_GLB")
    mata: st_sstore(2, "lab", "Lone " + char(96) + "tick")
    replace lab = "Plain" in 3
    replace lab = "Kept" in 4
    gen double es = cond(_n == 4, 1, .)
    gen double lo = 0.5
    gen double hi = 2
    _v170_capture `"eplot es lo hi, labels(lab) nodraw"'
    assert r(rc) == 0
    mata: st_global("V170_NEEDLE", "missing: Bad" + char(96) + "x" + char(39) + " " + char(36) + "QA_HS_GLB, Lone " + char(96) + "tick, Plain;")
    _v170_count `"`r(file)'"'
    assert r(n) == 1
    * The refusal path lists its rows the same way.
    replace hi = . in 1/2
    replace es = 1 in 1/2
    _v170_capture `"eplot es lo hi, labels(lab) nodraw"'
    assert r(rc) == 198
    mata: st_global("V170_NEEDLE", "exactly one missing limit: Bad" + char(96) + "x" + char(39) + " " + char(36) + "QA_HS_GLB, Lone " + char(96) + "tick")
    _v170_count `"`r(file)'"'
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# M6: per-model marker symbols
**## 5. msymbol(O D T) in model order; one symbol for all; count refused
local ++test_count
capture noisily {
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight foreign
    estimates store m2
    quietly regress price mpg
    estimates store m3
    eplot m1 m2 m3, drop(_cons) msymbol(O D T) nodraw
    local c `"`r(cmd)'"'
    assert regexm(`"`c'"', "model_id == 1 & _rowtype == 1, msymbol\(O\)")
    assert regexm(`"`c'"', "model_id == 2 & _rowtype == 1, msymbol\(D\)")
    assert regexm(`"`c'"', "model_id == 3 & _rowtype == 1, msymbol\(T\)")
    eplot m1 m2 m3, drop(_cons) msymbol(Sh) nodraw
    local c `"`r(cmd)'"'
    forvalues m = 1/3 {
        assert regexm(`"`c'"', "model_id == `m' & _rowtype == 1, msymbol\(Sh\)")
    }
    * Default unchanged: O for every model.
    eplot m1 m2 m3, drop(_cons) nodraw
    local c `"`r(cmd)'"'
    forvalues m = 1/3 {
        assert regexm(`"`c'"', "model_id == `m' & _rowtype == 1, msymbol\(O\)")
    }
    capture eplot m1 m2 m3, drop(_cons) msymbol(O D) nodraw
    assert _rc == 198
    capture eplot m1 m2, drop(_cons) msymbol(O D T) nodraw
    assert _rc == 198
    * With a style preset the explicit list still wins.
    eplot m1 m2, drop(_cons) style(lancet) msymbol(D T) nodraw
    local c `"`r(cmd)'"'
    assert regexm(`"`c'"', "model_id == 1 & _rowtype == 1, msymbol\(D\)")
    assert regexm(`"`c'"', "model_id == 2 & _rowtype == 1, msymbol\(T\)")
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# N6: eform axis title names the column Stata's own table names
**## 5b. title matches the replayed table header, model by model
local ++test_count
capture noisily {
    local bad ""
    local n_checked 0
    * Model i: data setup s<i> (one or two commands in s<i>a/s<i>b), the
    * estimation command e<i>, and the replay option o<i> that makes Stata
    * label its exponentiated column.
    local auto "sysuse auto, clear"
    local s1 "`auto'"
    local e1 "ologit rep78 mpg weight"
    local o1 "or"
    local s2 "`auto'"
    local e2 "mlogit rep78 mpg if rep78 >= 3"
    local o2 "rrr"
    local s3 "`auto'"
    local e3 "glm foreign mpg, family(binomial) link(logit)"
    local o3 "eform"
    local s4 "`auto'"
    local e4 "glm foreign mpg, family(binomial) link(log)"
    local o4 "eform"
    local s5 "`auto'"
    local e5 "glm rep78 mpg, family(poisson) link(log)"
    local o5 "eform"
    local s6 "`auto'"
    local e6 "glm rep78 mpg, family(nbinomial) link(log)"
    local o6 "eform"
    local s7 "`auto'"
    local e7 "zip rep78 mpg, inflate(weight)"
    local o7 "irr"
    local s8 "`auto'"
    local e8 "tnbreg rep78 mpg"
    local o8 "irr"
    local s9 "`auto'"
    local e9 "tpoisson rep78 mpg"
    local o9 "irr"
    local s10 "`auto'"
    local e10 "gnbreg rep78 mpg"
    local o10 "irr"
    local s11 "`auto'"
    local e11 "binreg foreign mpg, rr"
    local o11 "rr"
    local s12 "`auto'"
    local e12 "logit foreign mpg"
    local o12 "or"
    local s13 "webuse cancer, clear"
    local t13 "stset studytime, failure(died)"
    local e13 "streg age drug, dist(weibull) time"
    local o13 "tr"
    local s14 "webuse cancer, clear"
    local t14 "stset studytime, failure(died)"
    local e14 "streg age drug, dist(weibull)"
    local o14 "hr"
    local s15 "webuse hypoxia, clear"
    local t15 "stset dftime, failure(failtype==1)"
    local e15 "stcrreg ifp tumsize pelnode, compete(failtype==2)"
    local o15 ""
    local s16 "`auto'"
    local e16 "meologit rep78 mpg || turn:"
    local o16 "or"
    forvalues i = 1/16 {
        quietly `s`i''
        if "`t`i''" != "" quietly `t`i''
        quietly `e`i''
        local ecmd "`e(cmd)'"
        * Replay through the user-facing command (meglm/gsem post cmd2).
        if "`e(cmd2)'" != "" local ecmd "`e(cmd2)'"
        _v170_capture `"`ecmd', `o`i''"'
        _v170_header `"`r(file)'"'
        local want `"`r(header)'"'
        if `"`want'"' == "" {
            display as error "model `i': no table header captured"
            local bad "`bad' `i'"
            continue
        }
        quietly eplot ., eform nodraw
        local cmd `"`r(cmd)'"'
        local p0 = strpos(`"`cmd'"', "xtitle(`" + char(34))
        local p1 = strpos(`"`cmd'"', " (95% CI)" + char(34) + "')")
        if !`p0' | `p1' <= `p0' {
            display as error "model `i': no default title in r(cmd)"
            local bad "`bad' `i'"
            continue
        }
        local got = substr(`"`cmd'"', `p0' + 9, `p1' - `p0' - 9)
        local ++n_checked
        * Stata's table abbreviates "Haz. ratio"; eplot spells it out.
        local want = subinstr(lower(`"`want'"'), "haz. ratio", "hazard ratio", 1)
        if lower(`"`got'"') != `"`want'"' {
            display as error `"model `i' (`e`i''): eplot title "`got'", Stata header "`want'""'
            local bad "`bad' `i'"
        }
    }
    assert `n_checked' == 16
    if "`bad'" != "" exit 9
    * A column Stata calls exp(b) (cloglog) keeps the generic title.
    sysuse auto, clear
    quietly cloglog foreign mpg
    quietly eplot ., eform nodraw
    assert strpos(`"`r(cmd)'"', `"xtitle(`"Effect (95% CI)"')"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Hostile label text is drawn exactly
**## 6. labels(): every corpus string appears verbatim in the rendered SVG
local ++test_count
capture noisily {
    qa_hostile_strings
    local names `"`r(names)'"'
    local n : word count `names'
    clear
    quietly set obs `n'
    gen str80 lab = ""
    forvalues i = 1/`n' {
        local g : word `i' of `names'
        mata: st_sstore(`i', "lab", st_global("`g'"))
    }
    gen double es = _n / 10
    gen double lo = es - 0.05
    gen double hi = es + 0.05
    tempfile svg
    eplot es lo hi, labels(lab) name(v170_hs, replace)
    quietly graph export `"`svg'.svg"', as(svg) replace
    local bad ""
    forvalues i = 1/`n' {
        local g : word `i' of `names'
        * The corpus holds no < > or &, which SVG would escape; Stata's
        * SVG writer leaves double quotes as they are.
        mata: st_global("V170_NEEDLE", strtrim(st_global("`g'")))
        _v170_count `"`svg'.svg"'
        if r(n) < 1 local bad "`bad' `g'"
    }
    if "`bad'" != "" {
        display as error "labels not drawn verbatim:`bad'"
        exit 9
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
capture graph drop v170_hs

**## 7. variable and value labels with ` and $: drawn, exported and read back exactly
local ++test_count
capture noisily {
    global QA_HS_GLB "EXPANDED"
    sysuse auto, clear
    mata: st_varlabel("mpg", "Miles " + char(96) + "q " + char(36) + "QA_HS_GLB")
    label define v170o 0 "x", replace
    mata: st_vlmodify("v170o", 1, "F " + char(96) + "lit" + char(39) + " " + char(36) + "QA_HS_GLB")
    label values foreign v170o
    quietly regress price mpg i.foreign
    capture frame drop v170_ex
    tempfile svg
    eplot ., drop(_cons) export(v170_ex) name(v170_vl, replace)
    quietly graph export `"`svg'.svg"', as(svg) replace
    mata: st_global("V170_NEEDLE", "Miles " + char(96) + "q " + char(36) + "QA_HS_GLB")
    _v170_count `"`svg'.svg"'
    assert r(n) == 1
    mata: st_global("V170_NEEDLE", "F " + char(96) + "lit" + char(39) + " " + char(36) + "QA_HS_GLB")
    _v170_count `"`svg'.svg"'
    assert r(n) == 1
    frame v170_ex {
        mata: assert(st_sdata(1, "label") == "Miles " + char(96) + "q " + char(36) + "QA_HS_GLB")
        mata: assert(st_sdata(2, "label") == "F " + char(96) + "lit" + char(39) + " " + char(36) + "QA_HS_GLB")
    }
    * frame() reads the exported text back and draws it the same way.
    eplot, frame(v170_ex) name(v170_fr, replace)
    quietly graph export `"`svg'_b.svg"', as(svg) replace
    _v170_count `"`svg'_b.svg"'
    assert r(n) == 1
    frame drop v170_ex
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

capture graph drop _all
macro drop V170_NEEDLE V170_CAPN
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v170, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
