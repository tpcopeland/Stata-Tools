/*******************************************************************************
* validation_cci_se_v121.do
* Validation suite for cci_se v1.2.1 fixes
*
* Validates:
*   V1. Liver hierarchy date logic (min→max fix)
*   V2. Direct-match vs hierarchical date competition
*   V3. generate() collision check
*   V4. Historical Python block disabled; dedicated cross-validation owns it
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

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

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

* V3.2: a shared textual prefix is harmless without an exact collision
clear
input long lopnr str10 diagnos long datum
31 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(ch_score) components prefix(ch_)
local t = (_rc == 0)
run_val "V3.2: generate(ch_score) + prefix(ch_) + components succeeds" `t'

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

* V3.5: generate() may equal the textual prefix when no output equals it
clear
input long lopnr str10 diagnos long datum
34 "I21" 20200101
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
    dateformat(yyyymmdd) generate(cci_) components
local t = (_rc == 0)
run_val "V3.5: generate name equals prefix text but remains distinct" `t'

**# V4. AUTHORITATIVE PYTHON CROSS-VALIDATION

* Executed separately by crossval_cci_se_python.do from pinned local vectors.

**# Summary

display ""
display as text "Tests:    " as result scalar(gs_ntest)
display as text "Passed:   " as result scalar(gs_npass)
display as text "Failed:   " as result scalar(gs_nfail)

if scalar(gs_nfail) > 0 {
    display "RESULT: validation_cci_se_v121 tests=" scalar(gs_ntest) ///
        " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    display as error "SOME TESTS FAILED"
    display as error "Failures: ${gs_failures}"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    display "RESULT: validation_cci_se_v121 tests=" scalar(gs_ntest) ///
        " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
}

do "`qa_dir'/_setools_qa_common.do" teardown
