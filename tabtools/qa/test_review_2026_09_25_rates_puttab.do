* test_review_2026_09_25_rates_puttab.do - regressions for the 2026-09-25
* review of hrcomptab/comptab rate composition, stratetab, and puttab.
*
* Every assertion compares a written cell (frame, xlsx, or CSV read back) with
* an oracle computed by a different route: stcox exp(_b[]) for hazard ratios,
* the strate output file itself for rates and person-years, and the Stata
* display format of the source variable for dates.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv0925
log using "test_review_2026_09_25_rates_puttab.log", replace text name(_rv0925)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
* A directory that is never created: writes below it must fail.
local nodir "`output_dir'/_rv0925_no_such_dir"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Cell of the output frame whose trimmed first-column label equals `label'.
capture program drop _rv_cell
program define _rv_cell, rclass
    version 17.0
    args fr label col
    local out ""
    local hits = 0
    frame `fr' {
        forvalues i = 4/`=_N' {
            if strtrim(c1[`i']) == `"`label'"' {
                local out = `col'[`i']
                local ++hits
            }
        }
    }
    return scalar hits = `hits'
    return local cell `"`out'"'
end

* Does a text log contain a line with `pattern'?
capture program drop _rv_log_has
program define _rv_log_has, rclass
    version 17.0
    args logfile pattern
    tempname fh
    local found = 0
    file open `fh' using `"`logfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`pattern'"') > 0 local found = 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

* Write a synthetic strate-shaped file (per(1) layout).
capture program drop _rv_strate_file
program define _rv_strate_file
    version 17.0
    syntax, path(string) [nogroup]
    label variable _D "Number of failures"
    label variable _Y "Person-time observation"
    label variable _Rate "Rate estimate"
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    quietly save `"`path'.dta"', replace
end

**# Fixtures: cancer data, grouped rate scaffold, Cox model frames
tempfile cancerfx
* strate output() files live in output_dir under fixed names; strate and
* stratetab both append .dta, which a bare tempfile name does not survive.
local sgrp "`output_dir'/_rv0925_sgrp"
local ssex "`output_dir'/_rv0925_ssex"
local sall "`output_dir'/_rv0925_sall"
sysuse cancer, clear
gen byte grp = cond(age < 55, 1, cond(age < 60, 2, 3))
label define _rv_grpl 1 "Low" 2 "Mid" 3 "High"
label values grp _rv_grpl
gen byte male = mod(_n, 2)
label define _rv_sexl 0 "Female" 1 "Male"
label values male _rv_sexl
* the same grouping without value labels: model rows read "1", "2", "3"
gen byte grpn = grp
stset studytime, failure(died)
quietly save "`cancerfx'", replace
strate grp, output("`sgrp'", replace)
strate male, output("`ssex'", replace)
strate, output("`sall'", replace)

capture frame drop _rv_rates
stratetab, using("`sgrp'" "`ssex'") outcomes(1) outlabels("Death") ///
    explabels("Group" \ "Sex") frame(_rv_rates, replace)

use "`cancerfx'", clear
quietly stcox i.grp, nolog
local hr_mid = strtrim(string(exp(_b[2.grp]), "%9.2f"))
local hr_high = strtrim(string(exp(_b[3.grp]), "%9.2f"))
collect clear
collect: stcox i.grp, nolog
capture frame drop _rv_mg
capture frame drop _rv_mg_ep
regtab, models("Death") frame(_rv_mg, replace) eplotframe(_rv_mg_ep, replace) coef(HR) noint

quietly stcox i.male, nolog
local hr_male = strtrim(string(exp(_b[1.male]), "%9.2f"))
collect clear
collect: stcox i.male, nolog
capture frame drop _rv_ms
capture frame drop _rv_ms_ep
regtab, models("Death") frame(_rv_ms, replace) eplotframe(_rv_ms_ep, replace) coef(HR) noint

quietly stcox ib2.grp, nolog
local hr2_low = strtrim(string(exp(_b[1.grp]), "%9.2f"))
local hr2_high = strtrim(string(exp(_b[3.grp]), "%9.2f"))
local hr2_low_raw = exp(_b[1.grp])
collect clear
collect: stcox ib2.grp, nolog
capture frame drop _rv_mg2
capture frame drop _rv_mg2_ep
regtab, models("Death") frame(_rv_mg2, replace) eplotframe(_rv_mg2_ep, replace) coef(HR) noint

quietly stcox male, nolog
local hr_bin = strtrim(string(exp(_b[male]), "%9.2f"))
collect clear
collect: stcox male, nolog
capture frame drop _rv_mbin
regtab, models("Death") frame(_rv_mbin, replace) coef(HR) noint

collect clear
collect: stcox i.grpn, nolog
capture frame drop _rv_mnum
regtab, models("Death") frame(_rv_mnum, replace) coef(HR) noint

**# C3: hrcomptab maps model rows to the rate scaffold by label

**## C3a selecting the model's reference row into a non-reference slot errors
local ++test_count
capture noisily {
    capture frame drop _rv_o1
    capture noisily hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) ///
        rows(2/3 \ 2) outcomemap("Death") frame(_rv_o1, replace)
    assert _rc == 198
    capture confirm frame _rv_o1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS [C3a]: reference-row selection is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL [C3a]: reference-row selection was not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3a"
}

**## C3b reversed row order is placed by label, frame and xlsx agree with stcox
local ++test_count
local fc3b "`output_dir'/_rv0925_c3b.xlsx"
capture erase "`fc3b'"
capture noisily {
    capture frame drop _rv_o2
    hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) rows(4 3 \ 3) ///
        outcomemap("Death") frame(_rv_o2, replace) xlsx("`fc3b'")
    _rv_cell _rv_o2 "Mid" c5
    assert r(hits) == 1
    assert strpos(`"`r(cell)'"', "`hr_mid' (") == 1
    _rv_cell _rv_o2 "High" c5
    assert strpos(`"`r(cell)'"', "`hr_high' (") == 1
    _rv_cell _rv_o2 "Low" c5
    assert `"`r(cell)'"' == "Reference"
    _rv_cell _rv_o2 "Male" c5
    assert strpos(`"`r(cell)'"', "`hr_male' (") == 1
    _rv_cell _rv_o2 "Female" c5
    assert `"`r(cell)'"' == "Reference"
    * the same cells read back from the workbook (A=title, B=label, F=effect)
    import excel using "`fc3b'", sheet("Composite") clear allstring
    local hits = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "Mid" {
            assert strpos(F[`i'], "`hr_mid' (") == 1
            local ++hits
        }
        if strtrim(B[`i']) == "High" {
            assert strpos(F[`i'], "`hr_high' (") == 1
            local ++hits
        }
    }
    assert `hits' == 2
}
if _rc == 0 {
    display as result "  PASS [C3b]: reversed rows placed by label"
    local ++pass_count
}
else {
    display as error "  FAIL [C3b]: reversed rows mis-placed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3b"
}
capture frame drop _rv_o2

**## C3c a model fitted with ib2. puts its reference on the Mid row
local ++test_count
capture noisily {
    capture frame drop _rv_o3
    capture frame drop _rv_o3_ep
    hrcomptab _rv_rates, modelframes(_rv_mg2 _rv_ms) rows(2 4 \ 3) ///
        outcomemap("Death") frame(_rv_o3, replace) eplotframe(_rv_o3_ep, replace)
    _rv_cell _rv_o3 "Low" c5
    assert strpos(`"`r(cell)'"', "`hr2_low' (") == 1
    _rv_cell _rv_o3 "Mid" c5
    assert `"`r(cell)'"' == "Reference"
    _rv_cell _rv_o3 "High" c5
    assert strpos(`"`r(cell)'"', "`hr2_high' (") == 1
    _rv_cell _rv_o3 "Male" c5
    assert strpos(`"`r(cell)'"', "`hr_male' (") == 1
    * the eplot companion agrees: Mid is the reference, Low carries the HR
    frame _rv_o3_ep {
        quietly count if strtrim(label) == "Mid" & rowtype == "reference"
        assert r(N) == 1
        quietly count if strtrim(label) == "Low" & rowtype == "reference"
        assert r(N) == 0
        quietly summarize estimate if strtrim(label) == "Low", meanonly
        assert r(N) == 1
        assert !missing(r(mean)) & !missing(`hr2_low_raw')
        assert reldif(r(mean), `hr2_low_raw') < 1e-6
    }
}
if _rc == 0 {
    display as result "  PASS [C3c]: non-first model reference placed correctly"
    local ++pass_count
}
else {
    display as error "  FAIL [C3c]: non-first model reference mis-placed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3c"
}
capture frame drop _rv_o3
capture frame drop _rv_o3_ep

**## C3d selecting an ib2. model's reference row errors
local ++test_count
capture noisily {
    capture noisily hrcomptab _rv_rates, modelframes(_rv_mg2 _rv_ms) ///
        rows(2/3 \ 3) outcomemap("Death")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS [C3d]: ib2 reference-row selection is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL [C3d]: ib2 reference-row selection was not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3d"
}

**## C3e selecting a factor heading row errors
local ++test_count
capture noisily {
    capture noisily hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) ///
        rows(1 3 \ 3) outcomemap("Death")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS [C3e]: heading-row selection is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL [C3e]: heading-row selection was not rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3e"
}

**## C3f factor levels whose labels match no rate category error
local ++test_count
capture noisily {
    capture noisily hrcomptab _rv_rates, modelframes(_rv_mnum _rv_ms) ///
        rows(3/4 \ 3) outcomemap("Death")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS [C3f]: unmatched factor labels are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL [C3f]: unmatched factor labels were placed by position (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3f"
}

**## C3g a plain 0/1 indicator still fills a two-category section
local ++test_count
capture noisily {
    capture frame drop _rv_o4
    hrcomptab _rv_rates, modelframes(_rv_mg _rv_mbin) rows(3/4 \ 1) ///
        outcomemap("Death") frame(_rv_o4, replace)
    _rv_cell _rv_o4 "Male" c5
    assert strpos(`"`r(cell)'"', "`hr_bin' (") == 1
    _rv_cell _rv_o4 "Female" c5
    assert `"`r(cell)'"' == "Reference"
    _rv_cell _rv_o4 "Mid" c5
    assert strpos(`"`r(cell)'"', "`hr_mid' (") == 1
}
if _rc == 0 {
    display as result "  PASS [C3g]: binary indicator fills its section"
    local ++pass_count
}
else {
    display as error "  FAIL [C3g]: binary indicator workflow broke (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3g"
}
capture frame drop _rv_o4

**## C3h rownames() selections are placed by label as well
local ++test_count
capture noisily {
    capture frame drop _rv_o5
    hrcomptab _rv_rates, modelframes(_rv_mg _rv_mbin) ///
        rownames("High Mid" \ "male") outcomemap("Death") frame(_rv_o5, replace)
    _rv_cell _rv_o5 "Mid" c5
    assert strpos(`"`r(cell)'"', "`hr_mid' (") == 1
    _rv_cell _rv_o5 "High" c5
    assert strpos(`"`r(cell)'"', "`hr_high' (") == 1
}
if _rc == 0 {
    display as result "  PASS [C3h]: rownames() placed by label"
    local ++pass_count
}
else {
    display as error "  FAIL [C3h]: rownames() mis-placed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3h"
}
capture frame drop _rv_o5

**# I6: caller data identity survives stratetab and hrcomptab

**## I6a stratetab success and failure leave c(filename)/c(changed)/data intact
local ++test_count
capture noisily {
    tempfile myauto
    sysuse auto, clear
    quietly save "`myauto'", replace
    quietly replace price = 2 in 1
    local fn0 `"`c(filename)'"'
    assert c(changed) == 1
    quietly datasignature
    local sig0 `"`r(datasignature)'"'

    stratetab, using("`sgrp'") outcomes(1)
    assert `"`c(filename)'"' == `"`fn0'"'
    assert c(changed) == 1
    assert price[1] == 2
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'

    capture stratetab, using("`output_dir'/_rv_no_such_strate") outcomes(1)
    assert _rc == 601
    assert `"`c(filename)'"' == `"`fn0'"'
    assert c(changed) == 1
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'

    capture stratetab, using("`sgrp'") outcomes(1) xlsx("`nodir'/x.xlsx")
    assert _rc != 0
    assert `"`c(filename)'"' == `"`fn0'"'
    assert c(changed) == 1
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'

    * unsaved edits must still be protected by Stata's own guard
    capture use "`myauto'"
    assert _rc == 4
}
if _rc == 0 {
    display as result "  PASS [I6a]: stratetab preserves caller data identity"
    local ++pass_count
}
else {
    display as error "  FAIL [I6a]: stratetab changed caller data identity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I6a"
}

**## I6b hrcomptab success and failure leave c(filename)/c(changed)/data intact
local ++test_count
capture noisily {
    tempfile myauto2
    sysuse auto, clear
    quietly save "`myauto2'", replace
    quietly replace mpg = 99 in 3
    local fn0 `"`c(filename)'"'
    quietly datasignature
    local sig0 `"`r(datasignature)'"'

    hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) rows(3/4 \ 3) outcomemap("Death")
    assert `"`c(filename)'"' == `"`fn0'"'
    assert c(changed) == 1
    assert mpg[3] == 99
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'

    capture hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) rows(3/4 \ 3) ///
        outcomemap("Death") xlsx("`nodir'/x.xlsx")
    assert _rc != 0
    assert `"`c(filename)'"' == `"`fn0'"'
    assert c(changed) == 1
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'

    capture hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) rows(3 \ 3) outcomemap("Death")
    assert _rc == 198
    assert `"`c(filename)'"' == `"`fn0'"'
    assert c(changed) == 1

    capture use "`myauto2'"
    assert _rc == 4
}
if _rc == 0 {
    display as result "  PASS [I6b]: hrcomptab preserves caller data identity"
    local ++pass_count
}
else {
    display as error "  FAIL [I6b]: hrcomptab changed caller data identity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I6b"
}

**# I7: puttab if/in are evaluated in the frame() source

**## I7a in and if against a frame whose variables are absent from the current frame
local ++test_count
local f7 "`output_dir'/_rv0925_i7.xlsx"
capture erase "`f7'"
capture noisily {
    capture frame drop _rv_big
    frame create _rv_big
    frame _rv_big {
        quietly set obs 30
        gen int v = _n
    }
    clear
    quietly set obs 2
    gen byte z = 9

    puttab in 5/10 using "`f7'", frame(_rv_big) sheet("In") noheader
    assert r(n_datarows) == 6
    puttab if v > 27 using "`f7'", frame(_rv_big) sheet("If") noheader
    assert r(n_datarows) == 3
    * current frame untouched
    assert _N == 2
    confirm variable z
    capture confirm variable v
    assert _rc != 0

    import excel using "`f7'", sheet("In") cellrange(B2:B7) clear allstring
    assert _N == 6
    assert B[1] == "5"
    assert B[6] == "10"
    import excel using "`f7'", sheet("If") cellrange(B2:B4) clear allstring
    assert _N == 3
    assert B[1] == "28"
    assert B[3] == "30"
}
if _rc == 0 {
    display as result "  PASS [I7a]: if/in evaluated in the source frame"
    local ++pass_count
}
else {
    display as error "  FAIL [I7a]: if/in evaluated in the current frame (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I7a"
}
capture frame drop _rv_big

**# I8: strate per(k) files and the documented ratescale()/pyscale() contract

**## I8a per(1000) output rendered with ratescale(1) pyscale(0.001) matches strate
local ++test_count
capture noisily {
    local sper "`output_dir'/_rv0925_sper"
    use "`cancerfx'", clear
    strate grp, per(1000) output("`sper'", replace)
    use "`sper'.dta", clear
    local want_rate = strtrim(string(round(_Rate[1], .1), "%9.1f"))
    local want_py = strtrim(string(round(_Y[1] * 1000, 1), "%20.0fc"))
    local want_ev = strtrim(string(_D[1], "%20.0fc"))
    capture frame drop _rv_per
    stratetab, using("`sper'") outcomes(1) ratescale(1) pyscale(0.001) ///
        frame(_rv_per, replace)
    frame _rv_per {
        assert strtrim(c1[5]) == "Low"
        assert c2[5] == "`want_ev'"
        assert c3[5] == "`want_py'"
        assert strpos(c4[5], "`want_rate' (") == 1
    }
    * the help file documents the per(k) conversion
    findfile stratetab.sthlp
    _rv_log_has "`r(fn)'" "pyscale(0.001)"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS [I8a]: per(1000) contract documented and exact"
    local ++pass_count
}
else {
    display as error "  FAIL [I8a]: per(1000) contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I8a"
}

**# I9a: puttab honours date/time display formats; no negative zero

**## I9a %td and %tc columns export as dates, -0.001 at 2 digits as 0.00
local ++test_count
local f9 "`output_dir'/_rv0925_i9a.xlsx"
local c9 "`output_dir'/_rv0925_i9a.csv"
capture erase "`f9'"
capture erase "`c9'"
capture noisily {
    clear
    quietly set obs 2
    gen d = mdy(1, 1, 2020) + _n - 1
    format d %td
    gen double x = cond(_n == 1, -0.001, 1.234)
    gen double tc = clock("01jan2020 13:45:00", "DMYhms") + (_n - 1) * 1000
    format tc %tc
    local want_d1 = strtrim(string(d[1], "%td"))
    local want_tc1 = strtrim(string(tc[1], "%tc"))
    assert "`want_d1'" == "01jan2020"
    puttab d x tc using "`f9'", sheet("D") noheader csv("`c9'") digits(2)
    import excel using "`f9'", sheet("D") cellrange(B2:D3) clear allstring
    assert B[1] == "`want_d1'"
    assert B[2] == "02jan2020"
    assert C[1] == "0.00"
    assert C[2] == "1.23"
    assert D[1] == "`want_tc1'"
    import delimited using "`c9'", varnames(nonames) stringcols(_all) clear
    assert v1[1] == "`want_d1'"
    assert v2[1] == "0.00"

    matrix _rvM = (-0.001, 2.5)
    puttab using "`f9'", sheet("M") matrix(_rvM) noheader digits(2)
    import excel using "`f9'", sheet("M") cellrange(C2:D2) clear allstring
    assert C[1] == "0.00"
    assert D[1] == "2.50"
}
if _rc == 0 {
    display as result "  PASS [I9a]: date formats honoured, no negative zero"
    local ++pass_count
}
else {
    display as error "  FAIL [I9a]: date formats / negative zero (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I9a"
}

**# I9b: stratetab commits frame() only after every export succeeds

**## I9b a failed xlsx write neither creates nor replaces the frame
local ++test_count
capture noisily {
    capture frame drop _rv_frf
    capture stratetab, using("`sgrp'") outcomes(1) xlsx("`nodir'/out.xlsx") ///
        frame(_rv_frf, replace)
    assert _rc != 0
    capture confirm frame _rv_frf
    assert _rc != 0

    frame create _rv_frf
    frame _rv_frf {
        quietly set obs 1
        gen keepme = 42
    }
    capture stratetab, using("`sgrp'") outcomes(1) xlsx("`nodir'/out.xlsx") ///
        frame(_rv_frf, replace)
    assert _rc != 0
    frame _rv_frf {
        assert _N == 1
        assert keepme[1] == 42
    }
    * success still commits
    stratetab, using("`sgrp'") outcomes(1) frame(_rv_frf, replace)
    frame _rv_frf: assert strtrim(c1[5]) == "Low"
}
if _rc == 0 {
    display as result "  PASS [I9b]: frame() staged until exports succeed"
    local ++pass_count
}
else {
    display as error "  FAIL [I9b]: frame() committed before a failed export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I9b"
}
capture frame drop _rv_frf

**# Minor findings

**## M1 stratetab export message names the sheet actually written
local ++test_count
local fm1 "`output_dir'/_rv0925_m1.xlsx"
capture erase "`fm1'"
capture noisily {
    tempfile m1log
    * Capture unwrapped: a long output path must not split the message.
    local _rv_ls = c(linesize)
    set linesize 255
    log using "`m1log'", text replace name(_rvm1)
    stratetab, using("`sgrp'") outcomes(1) xlsx("`fm1'")
    log close _rvm1
    set linesize `_rv_ls'
    _rv_log_has "`m1log'" ", sheet Results"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS [M1]: stratetab message names the sheet"
    local ++pass_count
}
else {
    display as error "  FAIL [M1]: stratetab message has an empty sheet (rc=`=_rc')"
    capture log close _rvm1
    capture set linesize `_rv_ls'
    local ++fail_count
    local failed_tests "`failed_tests' M1"
}

**## M2 unlabeled category codes >= 1e7 keep full precision
local ++test_count
capture noisily {
    local sbig "`output_dir'/_rv0925_sbig"
    clear
    quietly set obs 2
    gen long grp = cond(_n == 1, 10000000, 20000001)
    gen double _D = 5
    gen double _Y = 1000
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.5
    gen double _Upper = _Rate * 2
    _rv_strate_file, path("`sbig'")
    capture frame drop _rv_m2
    stratetab, using("`sbig'") outcomes(1) frame(_rv_m2, replace)
    frame _rv_m2 {
        assert strtrim(c1[5]) == "10000000"
        assert strtrim(c1[6]) == "20000001"
    }
}
if _rc == 0 {
    display as result "  PASS [M2]: large category codes exact"
    local ++pass_count
}
else {
    display as error "  FAIL [M2]: large category codes lost precision (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M2"
}
capture frame drop _rv_m2

**## M3 events and person-years >= 1e9 keep thousands separators
local ++test_count
capture noisily {
    local shuge "`output_dir'/_rv0925_shuge"
    clear
    quietly set obs 1
    gen byte grp = 1
    gen double _D = 1234567890
    gen double _Y = 123456789012
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.99
    gen double _Upper = _Rate * 1.01
    _rv_strate_file, path("`shuge'")
    capture frame drop _rv_m3
    stratetab, using("`shuge'") outcomes(1) frame(_rv_m3, replace)
    frame _rv_m3 {
        assert c2[5] == "1,234,567,890"
        assert c3[5] == "123,456,789,012"
    }
}
if _rc == 0 {
    display as result "  PASS [M3]: large counts keep separators"
    local ++pass_count
}
else {
    display as error "  FAIL [M3]: large counts lost separators (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M3"
}
capture frame drop _rv_m3

**## M4 a strate file with no grouping variable gives one overall row
local ++test_count
capture noisily {
    use "`sall'.dta", clear
    local want_ev = strtrim(string(_D[1], "%20.0fc"))
    local want_py = strtrim(string(round(_Y[1], 1), "%20.0fc"))
    local want_rate = strtrim(string(round(_Rate[1] * 1000, .1), "%9.1f"))
    capture frame drop _rv_m4
    stratetab, using("`sall'") outcomes(1) explabels("All patients") ///
        frame(_rv_m4, replace)
    assert r(N_rows) == 5
    frame _rv_m4 {
        assert c1[4] == "All patients"
        assert strtrim(c1[5]) == "Overall"
        assert c2[5] == "`want_ev'"
        assert c3[5] == "`want_py'"
        assert strpos(c4[5], "`want_rate' (") == 1
    }
}
if _rc == 0 {
    display as result "  PASS [M4]: ungrouped strate file supported"
    local ++pass_count
}
else {
    display as error "  FAIL [M4]: ungrouped strate file (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M4"
}
capture frame drop _rv_m4

**## M5 stratetab errors print only the custom message
local ++test_count
capture noisily {
    tempfile m5log
    * Capture unwrapped: a long output path must not split the message.
    local _rv_ls = c(linesize)
    set linesize 255
    log using "`m5log'", text replace name(_rvm5)
    capture noisily stratetab, using("`sgrp'" "`ssex'" "`sall'") outcomes(2)
    local m5rc = _rc
    log close _rvm5
    set linesize `_rv_ls'
    assert `m5rc' == 198
    _rv_log_has "`m5log'" "divisible"
    assert r(found) == 1
    _rv_log_has "`m5log'" "invalid syntax"
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS [M5]: no generic message after the custom one"
    local ++pass_count
}
else {
    display as error "  FAIL [M5]: generic error text repeated (rc=`=_rc')"
    capture log close _rvm5
    capture set linesize `_rv_ls'
    local ++fail_count
    local failed_tests "`failed_tests' M5"
}

**## M6 a Markdown write failure gives a Markdown hint, not the xlsx hint
local ++test_count
capture noisily {
    tempfile m6log
    clear
    quietly set obs 2
    gen x = _n
    * Capture unwrapped: a long output path must not split the message.
    local _rv_ls = c(linesize)
    set linesize 255
    log using "`m6log'", text replace name(_rvm6)
    capture noisily puttab x, markdown("`nodir'/t.md")
    local m6rc = _rc
    log close _rvm6
    set linesize `_rv_ls'
    assert `m6rc' != 0
    _rv_log_has "`m6log'" "xlsx file is not open"
    assert r(found) == 0
    _rv_log_has "`m6log'" "Hint: check that the Markdown file"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS [M6]: sink-specific failure hint"
    local ++pass_count
}
else {
    display as error "  FAIL [M6]: wrong failure hint (rc=`=_rc')"
    capture log close _rvm6
    capture set linesize `_rv_ls'
    local ++fail_count
    local failed_tests "`failed_tests' M6"
}

**## M7 an existing sheet matched case-insensitively reports its real name
local ++test_count
local fm7 "`output_dir'/_rv0925_m7.xlsx"
capture erase "`fm7'"
capture noisily {
    clear
    quietly set obs 2
    gen x = _n
    puttab x using "`fm7'", sheet("Table")
    tempfile m7log
    * Capture unwrapped: a long output path must not split the message.
    local _rv_ls = c(linesize)
    set linesize 255
    log using "`m7log'", text replace name(_rvm7)
    puttab x using "`fm7'", sheet("TABLE")
    local m7sheet `"`r(sheet)'"'
    log close _rvm7
    set linesize `_rv_ls'
    assert `"`m7sheet'"' == "Table"
    _rv_log_has "`m7log'" "to sheet Table in"
    assert r(found) == 1
    stratetab, using("`sgrp'") outcomes(1) xlsx("`fm7'") sheet("table")
    assert `"`r(sheet)'"' == "Table"
    hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) rows(3/4 \ 3) ///
        outcomemap("Death") xlsx("`fm7'") sheet("TaBlE")
    assert `"`r(sheet)'"' == "Table"
    import excel using "`fm7'", describe
    assert r(N_worksheet) == 1
}
if _rc == 0 {
    display as result "  PASS [M7]: canonical sheet name reported"
    local ++pass_count
}
else {
    display as error "  FAIL [M7]: user-case sheet name reported (rc=`=_rc')"
    capture log close _rvm7
    capture set linesize `_rv_ls'
    local ++fail_count
    local failed_tests "`failed_tests' M7"
}

**## M8 header-row detection keeps a genuine first data row
local ++test_count
local fm8 "`output_dir'/_rv0925_m8.xlsx"
capture erase "`fm8'"
capture noisily {
    clear
    quietly set obs 3
    generate str12 grp = cond(_n == 1, "Group", "A")
    label variable grp "Group"
    generate n = cond(_n == 1, ., _n)
    label variable n "Count"
    puttab grp n using "`fm8'", sheet("A") varlabels
    assert r(n_datarows) == 3
    import excel using "`fm8'", sheet("A") cellrange(B3:B5) clear allstring
    assert B[1] == "Group"

    * all-string with a blank in a non-label column is data too
    clear
    quietly set obs 3
    generate str12 grp = cond(_n == 1, "Group", "A")
    generate str12 other = cond(_n == 1, "", "B")
    label variable grp "Group"
    label variable other "Other"
    puttab grp other using "`fm8'", sheet("B") varlabels
    assert r(n_datarows) == 3

    * a genuine tabtools header row is still consumed once
    sysuse auto, clear
    desctab mpg, by(foreign) clear
    puttab _all using "`fm8'", sheet("C") varlabels
    assert r(n_datarows) == 2
}
if _rc == 0 {
    display as result "  PASS [M8]: header heuristic only consumes real headers"
    local ++pass_count
}
else {
    display as error "  FAIL [M8]: header heuristic dropped a data row (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M8"
}

**## M9 hrcomptab accepts an upper-case .XLSX extension
local ++test_count
local fm9 "`output_dir'/_rv0925_m9.XLSX"
capture erase "`fm9'"
capture noisily {
    hrcomptab _rv_rates, modelframes(_rv_mg _rv_ms) rows(3/4 \ 3) ///
        outcomemap("Death") xlsx("`fm9'")
    confirm file "`fm9'"
    assert `"`r(xlsx)'"' == "`fm9'"
}
if _rc == 0 {
    display as result "  PASS [M9]: .XLSX accepted"
    local ++pass_count
}
else {
    display as error "  FAIL [M9]: .XLSX rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M9"
}

**## M10 puttab matrix() accepts r(table) and e(b) directly
local ++test_count
local fm10 "`output_dir'/_rv0925_m10.xlsx"
capture erase "`fm10'"
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    matrix _rvRT = r(table)
    local want_b = strtrim(string(_rvRT[1, 1], "%32.3f"))
    local want_se = strtrim(string(_rvRT[2, 1], "%32.3f"))
    local want_eb = strtrim(string(_b[mpg], "%32.2f"))
    puttab using "`fm10'", matrix(r(table)) sheet("RT") digits(3)
    assert r(n_datarows) == rowsof(_rvRT)
    puttab using "`fm10'", matrix(e(b)) sheet("EB")
    assert r(n_datarows) == 1
    import excel using "`fm10'", sheet("RT") cellrange(B3:C4) clear allstring
    assert B[1] == "b"
    assert C[1] == "`want_b'"
    assert C[2] == "`want_se'"
    import excel using "`fm10'", sheet("EB") cellrange(C3:C3) clear allstring
    assert C[1] == "`want_eb'"
    capture puttab using "`fm10'", matrix(r(nosuchmatrix)) sheet("X")
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS [M10]: r(table)/e(b) matrix sources"
    local ++pass_count
}
else {
    display as error "  FAIL [M10]: r(table)/e(b) matrix sources (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M10"
}

**## M11 stratetab returns r(csv) and its help matches the rendered header
local ++test_count
local cm11 "`output_dir'/_rv0925_m11.csv"
capture erase "`cm11'"
capture noisily {
    stratetab, using("`sgrp'") outcomes(1) csv("`cm11'")
    assert `"`r(csv)'"' == "`cm11'"
    confirm file "`cm11'"
    capture frame drop _rv_m11
    stratetab, using("`sgrp'") outcomes(1) frame(_rv_m11, replace)
    frame _rv_m11: local hdr = c4[3]
    assert `"`hdr'"' == "Per 1,000 PY (95% CI)"
    findfile stratetab.sthlp
    local sth "`r(fn)'"
    _rv_log_has "`sth'" `"Rate (95% CI)"'
    assert r(found) == 0
    _rv_log_has "`sth'" "Per 1,000 PY (95% CI)"
    assert r(found) == 1
    _rv_log_has "`sth'" "using(namelist)"
    assert r(found) == 0
    _rv_log_has "`sth'" "{cmd:r(csv)}"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS [M11]: r(csv) and help header/using() drift"
    local ++pass_count
}
else {
    display as error "  FAIL [M11]: r(csv) or help drift (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' M11"
}
capture frame drop _rv_m11

**# Summary
foreach _f in sgrp ssex sall sper sbig shuge {
    capture erase "`output_dir'/_rv0925_`_f'.dta"
}
foreach _fr in _rv_rates _rv_mg _rv_mg_ep _rv_ms _rv_ms_ep _rv_mg2 _rv_mg2_ep _rv_mbin _rv_mnum {
    capture frame drop `_fr'
}
display as result "review 2026-09-25 QA summary: `pass_count' passed, `fail_count' failed"
if "`failed_tests'" != "" display as error "Failed:`failed_tests'"
display "RESULT: test_review_2026_09_25_rates_puttab tests=`test_count' pass=`pass_count' fail=`fail_count'"
quietly tabtools set clear
log close _rv0925
if `fail_count' > 0 exit 1
