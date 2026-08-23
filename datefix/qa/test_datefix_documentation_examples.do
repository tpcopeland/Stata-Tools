*! Exact executable examples from datefix.sthlp
*! Date: 2026-08-23

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_datefix_documentation_examples.log", replace text nomsg
do "_datefix_qa_common.do"
quietly _datefix_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Current help setup and first four executable examples, copied verbatim.
local ++test_count
capture noisily {
    clear
    input str10 dob str10 dod str10 visit_date str8 city_founded str10 admission_date str12 invalid_date
      "2020-01-15" "2024-03-01" "03/14/2020" "07/04/76" "15/06/2024" "2020/00/15"
      "1990-12-31" "2024-07-04" "11/03/2023" "11/12/84" "01/01/2025" "not-a-date"
      end
    datefix dob dod, order(YMD)
    assert dob[1] == date("2020-01-15", "YMD") & dod[2] == date("2024-07-04", "YMD")
    datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY)
    assert vdate[1] == date("03/14/2020", "MDY")
    local vformat : format vdate
    assert "`vformat'" == "%tdMonth_DD,_CCYY"
    datefix city_founded, order(MDY) topyear(1900)
    assert city_founded[1] == date("07/04/1876", "MDY") & city_founded[2] == date("11/12/1884", "MDY")
    datefix admission_date, newvar(admit_dt) drop order(DMY) df(%tdDD/NN/CCYY)
    confirm variable admit_dt
    capture confirm variable admission_date
    assert _rc == 111
    assert admit_dt[1] == date("15/06/2024", "DMY")
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Current help diagnose example, including its intentionally invalid strings.
local ++test_count
capture noisily {
    capture noisily {
        datefix invalid_date, order(YMD) diagnose
    }
    local call_rc = _rc
    assert `call_rc' == 198
    local invalid_type : type invalid_date
    assert "`invalid_type'" == "str12"
    assert invalid_date[1] == "2020/00/15" & invalid_date[2] == "not-a-date"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_datefix_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
log close _all
