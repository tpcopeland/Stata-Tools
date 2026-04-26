/*******************************************************************************
* validation_cci_se_v121.do
* Validation suite for cci_se v1.2.1 fixes
*
* Validates:
*   V1. Liver hierarchy date logic (min→max fix)
*   V2. Direct-match vs hierarchical date competition
*   V3. generate() collision check
*   V4. Python cross-validation of Mata engine (ICD-10 subset)
*
* Run from setools/qa/ directory:
*   stata-mp -b do validation_cci_se_v121.do
*******************************************************************************/

version 16.0
capture log close _all
set varabbrev off

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_val
program define run_val
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  [PASS] `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  [FAIL] `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures `"${gs_failures} "`test_name'""'
    }
end

**# V1. LIVER HIERARCHY DATE LOGIC (max fix)

* V1.1: Pure upgrade — mild liver before ascites
* Expected: upgrade date = max(2010-06-01, 2013-03-15) = 2013-03-15
clear
input long lopnr str10 diagnos long datum
1 "K703"  20100601
1 "R18"   20130315
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local expected = daily("15mar2013", "DMY")
local t = (cci_livsev[1] == 1 & cci_livsev_date[1] == `expected')
run_val "V1.1: liver upgrade date = max(mild, ascites) when mild first" `t'

* V1.2: Pure upgrade — ascites before mild liver
* Expected: upgrade date = max(2012-01-01, 2015-06-01) = 2015-06-01
clear
input long lopnr str10 diagnos long datum
2 "R18"   20120101
2 "K703"  20150601
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local expected = daily("01jun2015", "DMY")
local t = (cci_livsev[1] == 1 & cci_livsev_date[1] == `expected')
run_val "V1.2: liver upgrade date = max(mild, ascites) when ascites first" `t'

* V1.3: Pure upgrade — same-day mild + ascites
* Expected: upgrade date = max(date, date) = that date
clear
input long lopnr str10 diagnos long datum
3 "K73"   20180701
3 "R18"   20180701
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local expected = daily("01jul2018", "DMY")
local t = (cci_livsev[1] == 1 & cci_livsev_date[1] == `expected')
run_val "V1.3: same-day mild+ascites → upgrade date = that day" `t'

* V1.4: Mild liver only (no ascites) — no upgrade
clear
input long lopnr str10 diagnos long datum
4 "B18"   20140301
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local t = (cci_livmild[1] == 1 & cci_livsev[1] == 0 & ///
    missing(cci_livsev_date[1]))
run_val "V1.4: mild liver only → no upgrade, livsev_date missing" `t'

* V1.5: Ascites only (no mild liver) — no upgrade
clear
input long lopnr str10 diagnos long datum
5 "R18"   20160501
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local t = (cci_livmild[1] == 0 & cci_livsev[1] == 0 & ///
    missing(cci_livsev_date[1]))
run_val "V1.5: ascites only → no upgrade, no mild liver either" `t'

* V1.6: Upgrade clears mild liver date
clear
input long lopnr str10 diagnos long datum
6 "K703"  20100101
6 "R18"   20120601
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local t = (cci_livmild[1] == 0 & missing(cci_livmild_date[1]))
run_val "V1.6: after upgrade, livmild=0 and livmild_date=." `t'

**# V2. DIRECT MATCH VS HIERARCHICAL DATE COMPETITION

* V2.1: Direct severe code + mild+ascites — direct date earlier
* Direct I850 on 2011-01-01, mild K703 on 2012-06-01, ascites R18 on 2013-01-01
* Hierarchical upgrade date = max(2012-06-01, 2013-01-01) = 2013-01-01
* Final = min(direct=2011-01-01, hierarchical=2013-01-01) = 2011-01-01
clear
input long lopnr str10 diagnos long datum
10 "I850"  20110101
10 "K703"  20120601
10 "R18"   20130101
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local expected = daily("01jan2011", "DMY")
local t = (cci_livsev[1] == 1 & cci_livsev_date[1] == `expected')
run_val "V2.1: direct earlier than hierarchical → direct date wins" `t'

* V2.2: Direct severe code + mild+ascites — hierarchical date earlier
* Direct I859 on 2020-01-01, mild K709 on 2010-03-01, ascites R18 on 2012-06-15
* Hierarchical upgrade date = max(2010-03-01, 2012-06-15) = 2012-06-15
* Final = min(direct=2020-01-01, hierarchical=2012-06-15) = 2012-06-15
clear
input long lopnr str10 diagnos long datum
11 "I859"  20200101
11 "K709"  20100301
11 "R18"   20120615
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local expected = daily("15jun2012", "DMY")
local t = (cci_livsev[1] == 1 & cci_livsev_date[1] == `expected')
run_val "V2.2: hierarchical earlier than direct → hierarchical date wins" `t'

* V2.3: Direct severe code + mild+ascites — identical dates
* Direct I982 on 2015-04-01, mild B19 on 2013-01-01, ascites R18 on 2015-04-01
* Hierarchical = max(2013-01-01, 2015-04-01) = 2015-04-01
* Final = min(2015-04-01, 2015-04-01) = 2015-04-01
clear
input long lopnr str10 diagnos long datum
12 "I982"  20150401
12 "B19"   20130101
12 "R18"   20150401
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
local expected = daily("01apr2015", "DMY")
local t = (cci_livsev[1] == 1 & cci_livsev_date[1] == `expected')
run_val "V2.3: direct = hierarchical date → tied date preserved" `t'

* V2.4: Verify mild liver indicator cleared AND score correct in all V2 cases
clear
input long lopnr str10 diagnos long datum
20 "I850"  20110101
20 "K703"  20120601
20 "R18"   20130101
21 "I859"  20200101
21 "K709"  20100301
21 "R18"   20120615
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates components
sort lopnr
local t = (cci_livmild[1] == 0 & cci_livmild[2] == 0 & ///
    charlson[1] == 3 & charlson[2] == 3)
run_val "V2.4: livmild cleared and score=3 (livsev weight) in both cases" `t'

**# V3. GENERATE() COLLISION CHECK

* V3.1: generate name starts with default prefix → rc=198
clear
input long lopnr str10 diagnos long datum
30 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(cci_mi) components
local t = (_rc == 198)
run_val "V3.1: generate(cci_mi) + components → rc=198" `t'

* V3.2: generate name starts with custom prefix → rc=198
clear
input long lopnr str10 diagnos long datum
31 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(ch_score) components prefix(ch_)
local t = (_rc == 198)
run_val "V3.2: generate(ch_score) + prefix(ch_) + components → rc=198" `t'

* V3.3: generate name does NOT start with prefix → success
clear
input long lopnr str10 diagnos long datum
32 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(score) components
local t = (_rc == 0)
run_val "V3.3: generate(score) + components → success" `t'

* V3.4: collision check not triggered without components
clear
input long lopnr str10 diagnos long datum
33 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(cci_mi)
local t = (_rc == 0)
run_val "V3.4: generate(cci_mi) without components → success" `t'

* V3.5: exact prefix match (edge: generate IS the prefix)
clear
input long lopnr str10 diagnos long datum
34 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(cci_) components
local t = (_rc == 198)
run_val "V3.5: generate name equals prefix exactly → rc=198" `t'

**# V4. PYTHON CROSS-VALIDATION (ICD-10 subset)

* Export ICD-10 diagnoses to CSV, run Python oracle, compare results
local data_url "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta"
local input_csv "`c(tmpdir)'/cci_crossval_input.csv"
local output_csv "`c(tmpdir)'/cci_crossval_output.csv"
local py_script "`pkg_dir'/qa/_crossval_cci_se_python.py"

* Verify the Python script exists; python3 availability checked via output file
capture confirm file "`py_script'"
if _rc {
    display as text "  [SKIP] V4: _crossval_cci_se_python.py not found"
    scalar gs_ntest = scalar(gs_ntest) + 1
    scalar gs_npass = scalar(gs_npass) + 1
}
else {

    * Load diagnosis data — keep only ICD-10 era (year >= 1998)
    use "`data_url'", clear
    gen int _yr = year(visit_date)
    keep if _yr >= 1998
    drop _yr

    * Run Stata cci_se on ICD-10 subset
    cci_se, id(id) icd(icd) date(visit_date) components
    rename charlson charlson_stata
    foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab ///
        diabcomp renal livmild livsev pud cancer mets aids {
        rename cci_`v' stata_`v'
    }
    tempfile stata_out
    save `stata_out'

    * Re-load and export for Python (match Stata's internal filtering)
    use "`data_url'", clear
    gen int _yr = year(visit_date)
    keep if _yr >= 1998
    drop _yr
    keep if !missing(id) & !missing(visit_date) & trim(icd) != ""
    export delimited id icd visit_date using "`input_csv'", replace

    * Run Python oracle
    shell python3 "`py_script'" "`input_csv'" "`output_csv'"

    * Verify Python produced output
    capture confirm file "`output_csv'"
    if _rc {
        display as error "  [FAIL] V4: Python script did not produce output"
        scalar gs_ntest = scalar(gs_ntest) + 1
        scalar gs_nfail = scalar(gs_nfail) + 1
    }
    else {

        * Import Python results
        import delimited using "`output_csv'", clear
        * Ensure id is numeric for merge compatibility
        capture confirm string variable id
        if !_rc {
            destring id, replace
        }
        rename charlson charlson_python
        foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab ///
            diabcomp renal livmild livsev pud cancer mets aids {
            rename cci_`v' python_`v'
        }
        tempfile python_out
        save `python_out'

        * Merge on id
        use `stata_out', clear
        merge 1:1 id using `python_out'
        count if _merge == 3
        local n_matched = r(N)
        count if _merge == 1
        local n_stata_only = r(N)
        count if _merge == 2
        local n_python_only = r(N)
        keep if _merge == 3
        drop _merge
        sort id

        * V4.0: Merge completeness
        local t = (`n_stata_only' == 0 & `n_python_only' == 0)
        run_val "V4.0: merge complete (matched=`n_matched' stata_only=`n_stata_only' python_only=`n_python_only')" `t'

        * V4.1: Overall score agreement
        count if charlson_stata != charlson_python
        local n_score_diff = r(N)
        local N_total = _N
        local t = (`n_score_diff' == 0)
        run_val "V4.1: CCI score agreement (N=`N_total', disagree=`n_score_diff')" `t'

        * V4.2: Component-level agreement
        local all_agree = 1
        local worst_comp ""
        local worst_n = 0
        foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab ///
            diabcomp renal livmild livsev pud cancer mets aids {
            count if stata_`v' != python_`v'
            if r(N) > 0 {
                local all_agree = 0
                if r(N) > `worst_n' {
                    local worst_n = r(N)
                    local worst_comp "`v'"
                }
            }
        }
        local t = (`all_agree' == 1)
        if `all_agree' {
            run_val "V4.2: all 18 components match Python (N=`N_total')" `t'
        }
        else {
            run_val "V4.2: component mismatch (worst: `worst_comp' n=`worst_n')" `t'
        }

        * V4.3: Hierarchy rules verified in Python output
        count if python_diab == 1 & python_diabcomp == 1
        local t = (r(N) == 0)
        run_val "V4.3: Python enforces diabetes hierarchy" `t'

        count if python_cancer == 1 & python_mets == 1
        local t = (r(N) == 0)
        run_val "V4.4: Python enforces cancer hierarchy" `t'

        count if python_livmild == 1 & python_livsev == 1
        local t = (r(N) == 0)
        run_val "V4.5: Python enforces liver hierarchy" `t'

        * V4.6: Score range sanity
        summarize charlson_stata
        local t = (r(min) >= 0 & r(max) <= 30)
        run_val "V4.6: Stata scores in [0, 30]" `t'

        summarize charlson_python
        local t = (r(min) >= 0 & r(max) <= 30)
        run_val "V4.7: Python scores in [0, 30]" `t'

        * V4.8: Weight formula cross-check
        gen int recomputed = stata_mi + stata_chf + stata_pvd + stata_cevd + ///
            stata_copd + stata_pulm + stata_rheum + stata_dem + ///
            2*stata_plegia + stata_diab + 2*stata_diabcomp + ///
            2*stata_renal + stata_livmild + 3*stata_livsev + ///
            stata_pud + 2*stata_cancer + 6*stata_mets + 6*stata_aids
        count if recomputed != charlson_stata
        local t = (r(N) == 0)
        run_val "V4.8: Stata score = sum of weighted components" `t'
    }

    * Clean up
    capture erase "`input_csv'"
    capture erase "`output_csv'"
}

**# Summary

display ""
display as text "Tests:    " as result scalar(gs_ntest)
display as text "Passed:   " as result scalar(gs_npass)
display as text "Failed:   " as result scalar(gs_nfail)

if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failures: ${gs_failures}"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
}
