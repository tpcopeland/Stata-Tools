* test_fixes_2026_10_10.do - regressions for the tabtools 2.6.2 fixes
*
* R1  survtab median: a confidence limit the survivor function never reaches
*     prints as NR, and a finite lower limit is kept (stci is the oracle)
* R2  survtab: the beyond-follow-up caveat reaches the CSV and Markdown
*     footnote, naming each group's last follow-up (summarize _t oracle)
* R3  effecttab margins, at(): each row is labelled with its scenario as
*     margins posted it in r(at), and carries that scenario's margin
* R4  effecttab margins with at() and a fixed factor; the overall margin is
*     "Overall", a single at() names its scenario; interaction rows use value
*     labels; two margins calls with different at() keep 1._at, 2._at
* R5  regtab interaction rows: parent from variable labels, levels from value
*     labels, the estimate under the right label; a caller's collect label
*     is kept
* R6  puttab and outtab with csv() as the only sink write the CSV
* R7  outtab refuses an exposure that takes one value in the sample
* R8  ratetab and survtab note days-scaled analysis time; no note once
*     stset has scale()
* R9  crosstab and corrtab p-values follow the package rule: "P for trend <
*     0.001" and "p = 0.065", two decimals from 0.10
* R10 review of the 2.6.2 change set: the overall margin of two margins calls
*     with different at() reads "Margin", not one call's scenario; an
*     atmeans scenario names its statistic and value labels; an asbalanced
*     factor is named; a missing crosstab p keeps "p = ."; a user footnote
*     without a full stop is closed before survtab's caveat
*
* Oracles: stci, summarize, margins' own r(at) and r(b), e(b), count, tab,
* pwcorr. No expected value is read back from the code under test. Run from
* tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _f10
log using "test_fixes_2026_10_10.log", replace text name(_f10)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* _fx_csv FILE: load a CSV, every cell a string, into frame _fx (v1, v2, ...)
capture program drop _fx_csv
program define _fx_csv
    version 17.0
    args file
    capture frame drop _fx
    frame create _fx
    frame _fx: quietly import delimited using `"`file'"', varnames(nonames) ///
        stringcols(_all) delimiter(",") bindquote(strict) clear
end

* _fx_row LABEL [START]: r(row) = first row of _fx at or after START whose
* first cell, trimmed, is LABEL (0 when none)
capture program drop _fx_row
program define _fx_row, rclass
    version 17.0
    args label start
    if "`start'" == "" local start 1
    local hit 0
    frame _fx {
        forvalues i = `start'/`=_N' {
            if `hit' continue
            if strtrim(v1[`i']) == strtrim(`"`label'"') local hit `i'
        }
    }
    return scalar row = `hit'
end

* _fx_log FILE NEEDLE: r(n) = lines of FILE containing NEEDLE
capture program drop _fx_log
program define _fx_log, rclass
    version 17.0
    args file needle
    mata: st_numscalar("_fx_n", sum(strpos(cat(st_local("file")), st_local("needle")) :> 0))
    return scalar n = scalar(_fx_n)
    scalar drop _fx_n
end

**# R1: survtab median CI keeps a finite lower limit when the upper is NR
local ++test_count
capture noisily {
    webuse drugtr, clear
    * oracle: stci for the drug group, whose upper limit is not reached
    quietly stci if drug == 1
    local lb = r(lb)
    local ub = r(ub)
    assert !missing(`lb') & missing(`ub')
    local want = "(" + strtrim(string(`lb', "%21.1f")) + ", NR)"
    quietly stci if drug == 0
    local want0 = "(" + strtrim(string(r(lb), "%21.1f")) + ", " + strtrim(string(r(ub), "%21.1f")) + ")"
    tempfile f
    survtab, times(10) median by(drug) csv("`f'.csv")
    _fx_csv "`f'.csv"
    _fx_row "(95% CI)"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert strtrim(v3[`r']) == "`want'"
    frame _fx: assert strtrim(v2[`r']) == "`want0'"
}
if _rc == 0 {
    display as result "  PASS: R1 survtab median CI prints NR for an unreached limit"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 survtab median NR (rc=`=_rc')"
    local ++fail_count
}

**# R2: survtab beyond-support caveat reaches the exported footnote
local ++test_count
capture noisily {
    webuse drugtr, clear
    quietly summarize _t if drug == 0 & _st, meanonly
    local last0 = strtrim(string(r(max), "%12.0g"))
    * 40 is past drug 0's last follow-up
    assert 40 > `last0'
    tempfile f
    survtab, times(10 40) by(drug) csv("`f'.csv") markdown("`f'.md") ///
        footnote("Source: drugtr.")
    local beyond `"`r(beyond_support)'"'
    assert strpos(`"`beyond'"', "last follow-up `last0'") > 0
    _fx_csv "`f'.csv"
    frame _fx: local lastcell = v1[_N]
    assert strpos(`"`lastcell'"', "Source: drugtr.") == 1
    assert strpos(`"`lastcell'"', "not supported by the data") > 0
    assert strpos(`"`lastcell'"', "last follow-up `last0'") > 0
    _fx_log "`f'.md" "last follow-up `last0'"
    assert r(n) == 1
    * no caveat when every time is supported
    survtab, times(10) by(drug) csv("`f'2.csv")
    _fx_csv "`f'2.csv"
    frame _fx: quietly count if strpos(v1, "not supported") > 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: R2 survtab beyond-support caveat in CSV/Markdown footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 survtab beyond-support footnote (rc=`=_rc')"
    local ++fail_count
}

**# R3: effecttab margins at() rows carry their scenario and its margin
local ++test_count
capture noisily {
    webuse nhanes2, clear
    quietly logit highbp c.age i.female
    collect clear
    quietly collect: margins, at(age=(40 50 60 70))
    * oracle: margins' own scenario matrix and margins, read before effecttab
    matrix AT = r(at)
    matrix B = r(b)
    local agecol = colnumb(AT, "age")
    local alab : variable label age
    tempfile f
    effecttab, csv("`f'.csv") digits(4)
    _fx_csv "`f'.csv"
    forvalues j = 1/4 {
        local a = AT[`j', `agecol']
        _fx_row "`alab' = `a'"
        local r = r(row)
        assert `r' > 0 & `r' < .
        frame _fx: local est = real(v2[`r'])
        assert abs(`est' - B[1, `j']) < 0.00005
    }
    * no raw scenario number is left
    frame _fx: quietly count if regexm(v1, "_at")
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: R3 effecttab at() rows named by scenario, values aligned"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 effecttab at() labels (rc=`=_rc')"
    local ++fail_count
}

**# R4: at() with a factor, overall margin, interactions, conflicting at()
local ++test_count
capture noisily {
    webuse nhanes2, clear
    quietly logit highbp c.age i.female
    local alab : variable label age
    local m : label (female) 0
    local w : label (female) 1
    tempfile f
    * a scenario fixing age and a factor level reads "Age (years) = 40, Male"
    collect clear
    quietly collect: margins, at(age=(40 60) female=(0 1))
    matrix B = r(b)
    effecttab, csv("`f'a.csv") digits(4)
    _fx_csv "`f'a.csv"
    _fx_row "`alab' = 60, `w'"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert abs(real(v2[`r']) - B[1, 4]) < 0.00005
    _fx_row "`alab' = 40, `m'"
    assert r(row) > 0 & !missing(r(row))
    * the overall margin is not an intercept
    collect clear
    quietly collect: margins
    matrix B = r(b)
    effecttab, csv("`f'b.csv") digits(4)
    _fx_csv "`f'b.csv"
    _fx_row "Overall"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert abs(real(v2[`r']) - B[1, 1]) < 0.00005
    _fx_row "Intercept"
    assert r(row) == 0
    * a single at() names its scenario
    collect clear
    quietly collect: margins, at(age=50)
    effecttab, csv("`f'c.csv")
    _fx_csv "`f'c.csv"
    _fx_row "`alab' = 50"
    assert r(row) > 0 & !missing(r(row))
    * interaction rows of margins use the value labels
    quietly logit highbp i.female##i.race c.age
    collect clear
    quietly collect: margins female#race
    matrix B = r(b)
    local k = colnumb(B, "1.female#2.race")
    local blk : label (race) 2
    effecttab, csv("`f'd.csv") digits(4)
    _fx_csv "`f'd.csv"
    _fx_row "`w' # `blk'"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert abs(real(v2[`r']) - B[1, `k']) < 0.00005
    * two margins calls with different at(): one row number would name two
    * scenarios, so the rows keep their numbers
    quietly logit highbp c.age i.female
    collect clear
    quietly collect: margins, at(age=(40 60))
    quietly collect: margins, at(age=(30 50))
    effecttab, csv("`f'e.csv")
    _fx_csv "`f'e.csv"
    _fx_row "1._at"
    assert r(row) > 0 & !missing(r(row))
    _fx_row "`alab' = 40"
    assert r(row) == 0
}
if _rc == 0 {
    display as result "  PASS: R4 effecttab factor scenario, Overall, interactions, conflicting at()"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 effecttab margins labels (rc=`=_rc')"
    local ++fail_count
}

**# R5: regtab interaction rows use variable and value labels
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.foreign##c.weight c.mpg#c.weight
    local bfw = _b[1.foreign#c.weight]
    local bmw = _b[c.mpg#c.weight]
    local flab : variable label foreign
    local wlab : variable label weight
    local mlab : variable label mpg
    local f1 : label (foreign) 1
    tempfile f
    regtab, csv("`f'.csv") digits(4)
    _fx_csv "`f'.csv"
    _fx_row "`flab' # `wlab'"
    local p = r(row)
    assert `p' > 0
    * the level under the interaction parent names both components, so it
    * cannot be confused with the main-effect level "Foreign"
    _fx_row "`f1' # `wlab'" `=`p' + 1'
    local r = r(row)
    assert `r' > `p' & `r' <= `p' + 2
    frame _fx: assert abs(real(v2[`r']) - `bfw') < 0.00005
    * the main-effect level keeps the only bare "Foreign" row
    frame _fx: quietly count if strtrim(v1) == "`f1'"
    assert r(N) == 1
    _fx_row "`mlab' # `wlab'"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert abs(real(v2[`r']) - `bmw') < 0.00005
    * no raw interaction key is left
    frame _fx: quietly count if strpos(v1, "#") & regexm(v1, "[0-9]\.")
    assert r(N) == 0
    * a label the caller set on the collection is kept
    collect label levels colname 1.foreign#c.weight "MY LABEL", modify
    regtab, csv("`f'2.csv") digits(4)
    _fx_csv "`f'2.csv"
    _fx_row "MY LABEL"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert abs(real(v2[`r']) - `bfw') < 0.00005
}
if _rc == 0 {
    display as result "  PASS: R5 regtab interaction rows labelled, estimates aligned"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 regtab interaction labels (rc=`=_rc')"
    local ++fail_count
}

**# R6: csv() alone is a sink for puttab and outtab
local ++test_count
capture noisily {
    webuse nhanes2, clear
    quietly count if female == 1
    local n1 = strtrim(string(r(N), "%12.0fc"))
    quietly count if female == 1 & highbp == 1
    local e1 = strtrim(string(r(N), "%12.0fc"))
    tempfile f
    outtab highbp, exposure(female) csv("`f'.csv")
    confirm file "`f'.csv"
    _fx_csv "`f'.csv"
    frame _fx: assert strpos(v2[2], "`e1'/`n1'") == 1
    sysuse auto, clear
    local mk1 = make[1]
    local pr3 = price[3]
    puttab make price in 1/3, csv("`f'p.csv")
    assert r(csv) == "`f'p.csv"
    _fx_csv "`f'p.csv"
    frame _fx: assert strtrim(v1[2]) == "`mk1'" & real(v2[4]) == `pr3'
    * no sink at all is still refused
    capture puttab make price in 1/3
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R6 csv() as the only sink (puttab, outtab)"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 csv-only sink (rc=`=_rc')"
    local ++fail_count
}

**# R7: outtab refuses a single-valued exposure (degenerate exposure)
local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte ev = price > 6000
    generate byte one = 1
    capture outtab ev, exposure(one)
    assert _rc == 2000
    * a subsample in which only one group remains is refused the same way
    capture outtab ev if foreign == 1, exposure(foreign)
    assert _rc == 2000
    * both values present: runs
    outtab ev, exposure(foreign)
}
if _rc == 0 {
    display as result "  PASS: R7 outtab refuses an exposure with one value"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 outtab single-valued exposure (rc=`=_rc')"
    local ++fail_count
}

**# R8: day-scaled analysis time is noted by ratetab and survtab
local ++test_count
capture noisily {
    webuse diet, clear
    quietly stset dox, failure(fail) origin(time doe) id(id)
    tempfile lg
    log using "`lg'.log", text replace name(_f10b)
    ratetab hienergy
    survtab, times(1000)
    log close _f10b
    _fx_log "`lg'.log" "Note: analysis time is in days"
    assert r(n) == 2
    _fx_log "`lg'.log" "pyscale(365.25)"
    assert r(n) == 1
    * scale() turns days into years: no note
    quietly stset dox, failure(fail) origin(time doe) id(id) scale(365.25)
    log using "`lg'2.log", text replace name(_f10b)
    ratetab hienergy
    survtab, times(5)
    ratetab hienergy, pyscale(1)
    log close _f10b
    _fx_log "`lg'2.log" "Note: analysis time is in"
    assert r(n) == 0
    * a given pyscale() or timeunit() is the caller's statement: no note
    quietly stset dox, failure(fail) origin(time doe) id(id)
    log using "`lg'3.log", text replace name(_f10b)
    ratetab hienergy, pyscale(365.25)
    ratetab hienergy, pyscale(1)
    survtab, times(1000) timeunit(days)
    log close _f10b
    _fx_log "`lg'3.log" "Note: analysis time is in"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: R8 ratetab/survtab note days-scaled time only when unstated"
    local ++pass_count
}
else {
    local r8rc = _rc
    capture log close _f10b
    display as error "  FAIL: R8 time-unit note (rc=`r8rc')"
    local ++fail_count
}

**# R9: crosstab and corrtab p-values follow the package rule
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile f
    crosstab rep78 foreign, trend csv("`f'a.csv")
    local pt = r(p_trend)
    assert `pt' < 0.001
    _fx_csv "`f'a.csv"
    frame _fx: quietly count if strtrim(v1) == "P for trend < 0.001"
    assert r(N) == 1
    frame _fx: quietly count if strpos(v1, "= <")
    assert r(N) == 0
    crosstab rep78 trunk, trend csv("`f'b.csv")
    local pt = r(p_trend)
    * oracle text: three decimals below 0.10
    assert `pt' >= 0.001 & `pt' < 0.10
    local want = "P for trend = " + strtrim(string(`pt', "%5.3f"))
    _fx_csv "`f'b.csv"
    frame _fx: quietly count if strtrim(v1) == "`want'"
    assert r(N) == 1
    * corrtab: a p-value from 0.10 prints two decimals (pwcorr oracle)
    quietly pwcorr price headroom, sig
    matrix S = r(sig)
    local p = S[2, 1]
    assert `p' >= 0.10 & `p' <= 0.99
    corrtab price headroom, pvalues csv("`f'c.csv")
    _fx_csv "`f'c.csv"
    frame _fx: quietly count if strpos(v2, "(" + strtrim(string(`p', "%5.2f")) + ")") > 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: R9 crosstab/corrtab p-value text by the package rule"
    local ++pass_count
}
else {
    display as error "  FAIL: R9 p-value text (rc=`=_rc')"
    local ++fail_count
}

**# R10: review findings on the 2.6.2 change set
local ++test_count
capture noisily {
    webuse nhanes2, clear
    quietly logit highbp c.age i.female
    local alab : variable label age
    tempfile f
    * two calls, one overall and one at(age=50): the shared _cons row holds
    * a different scenario in each column
    collect clear
    quietly collect: margins
    local b1 = r(b)[1, 1]
    quietly collect: margins, at(age=50)
    local b2 = r(b)[1, 1]
    effecttab, csv("`f'a.csv") digits(4)
    _fx_csv "`f'a.csv"
    _fx_row "Margin"
    local r = r(row)
    assert `r' > 0 & `r' < .
    frame _fx: assert abs(real(v2[`r']) - `b1') < 0.00005
    frame _fx: assert abs(real(v5[`r']) - `b2') < 0.00005
    _fx_row "`alab' = 50"
    assert r(row) == 0
    _fx_row "Intercept"
    assert r(row) == 0
    * both calls at the same single scenario: the row is that scenario
    collect clear
    quietly collect: margins, at(age=50)
    quietly collect: margins, at(age=50) predict(xb)
    effecttab, csv("`f'b.csv")
    _fx_csv "`f'b.csv"
    _fx_row "`alab' = 50"
    assert r(row) > 0 & !missing(r(row))
    * atmeans: the factor's proportions under its value labels, and the
    * statistic named, from margins' own r(at) and r(atstats1)
    collect clear
    quietly collect: margins, atmeans at(age=(40 50))
    matrix AT = r(at)
    local st = word("`r(atstats1)'", 2)
    assert "`st'" == "mean"
    local m : label (female) 0
    local w : label (female) 1
    local p0 = strtrim(string(AT[1, 2], "%9.0g"))
    local p1 = strtrim(string(AT[1, 3], "%9.0g"))
    if substr("`p0'", 1, 1) == "." local p0 "0`p0'"
    if substr("`p1'", 1, 1) == "." local p1 "0`p1'"
    effecttab, csv("`f'c.csv")
    _fx_csv "`f'c.csv"
    local flab : variable label female
    _fx_row "`alab' = 40, `flab' (mean): `m' = `p0', `w' = `p1'"
    assert r(row) > 0 & !missing(r(row))
    * asbalanced names the balanced factor instead of dropping it
    collect clear
    quietly collect: margins, asbalanced at(age=50)
    effecttab, csv("`f'd.csv")
    _fx_csv "`f'd.csv"
    local flab : variable label female
    frame _fx: quietly count if strpos(v1, "`flab' (asbalanced)") > 0
    assert r(N) == 1
    * crosstab with a constant row variable: no test p, and the sentence
    * still reads "p = ." with no dangling separator
    sysuse auto, clear
    generate byte one = 1
    crosstab one foreign, csv("`f'e.csv")
    assert missing(r(p))
    _fx_csv "`f'e.csv"
    frame _fx: quietly count if regexm(v1, "test: .*p = \.$")
    assert r(N) == 1
    frame _fx: quietly count if regexm(v1, ", *$")
    assert r(N) == 0
    * a user footnote without a full stop is closed before the caveat
    webuse drugtr, clear
    survtab, times(40) by(drug) csv("`f'f.csv") footnote("User note")
    _fx_csv "`f'f.csv"
    frame _fx: local lastcell = v1[_N]
    assert strpos(`"`lastcell'"', "User note. Times beyond") == 1
}
if _rc == 0 {
    display as result "  PASS: R10 multi-call Margin, atmeans/asbalanced labels, p = ., footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: R10 review findings (rc=`=_rc')"
    local ++fail_count
}

capture frame drop _fx

**# Summary
display as result "RESULT: test_fixes_2026_10_10 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _f10
if `fail_count' > 0 exit 1
