* test_rangematch_labels.do
* v1.3.1 regression suite: label preservation on every output route,
* compound-quoted saving(), and the strL by() guard.
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}


local test_count = 0

* Shared labeled using dataset. gradelbl includes an extended-missing
* mapping to pin the st_vlload/st_vlmodify round-trip for .a codes.
clear
set obs 6
gen double key = _n * 10
gen byte grade = mod(_n, 3) + 1
label define gradelbl 1 "low" 2 "mid" 3 "high" .a "not assessed"
label values grade gradelbl
label variable grade "Using grade label"
tempfile labeled_using
save "`labeled_using'"

capture program drop _rml_mk_master
program define _rml_mk_master
    clear
    set obs 4
    gen long id = _n
    gen double lo = _n * 10 - 5
    gen double hi = _n * 10 + 5
    gen byte sex = mod(_n, 2)
    label define sexlbl 0 "female" 1 "male"
    label values sex sexlbl
    label variable sex "Master sex label"
    label variable id "Master id label"
    label data "Master data label"
end

capture program drop _rml_assert_labels
program define _rml_assert_labels
    local l : variable label id
    assert `"`l'"' == "Master id label"
    local l : variable label sex
    assert `"`l'"' == "Master sex label"
    local v : value label sex
    assert "`v'" == "sexlbl"
    local m : label sexlbl 0
    assert `"`m'"' == "female"
    local l : variable label grade
    assert `"`l'"' == "Using grade label"
    local v : value label grade
    assert "`v'" == "gradelbl"
    local m : label gradelbl 3
    assert `"`m'"' == "high"
    local m : label gradelbl .a
    assert `"`m'"' == "not assessed"
    local d : data label
    assert `"`d'"' == "Master data label"
end

**# T1: labels preserved on the default in-place route (default frame)
local ++test_count
_rml_mk_master
rangematch key lo hi using "`labeled_using'", generate(mrg)
_rml_assert_labels
local v : value label mrg
assert "`v'" != ""
local m : label `v' 3
assert `"`m'"' == "matched"

**# T2: labels preserved when the caller is a named frame
local ++test_count
capture frame drop rml_work
frame create rml_work
frame change rml_work
_rml_mk_master
rangematch key lo hi using "`labeled_using'"
_rml_assert_labels
frame change default
frame drop rml_work

**# T3: labels preserved on the frame() route
local ++test_count
_rml_mk_master
capture frame drop rml_out
rangematch key lo hi using "`labeled_using'", frame(rml_out)
frame rml_out {
    _rml_assert_labels
}
frame drop rml_out

**# T4: compound-quoted saving() writes the file (v1.3.1 regression) and
**# preserves labels; the data in memory must remain the master data
local ++test_count
_rml_mk_master
tempfile rml_sv
rangematch key lo hi using "`labeled_using'", saving(`"`rml_sv'"')
assert `"`r(saving)'"' == `"`rml_sv'"'
capture confirm file `"`rml_sv'"'
assert _rc == 0
* master data untouched in memory
assert _N == 4
capture confirm variable grade
assert _rc != 0
use `"`rml_sv'"', clear
_rml_assert_labels

**# T5: compound-quoted saving() with replace suboption
local ++test_count
_rml_mk_master
rangematch key lo hi using "`labeled_using'", saving(`"`rml_sv'"', replace)
use `"`rml_sv'"', clear
_rml_assert_labels

**# T6: labels preserved when the using data is a frame
local ++test_count
capture frame drop rml_usrc
frame create rml_usrc
frame rml_usrc: use "`labeled_using'", clear
_rml_mk_master
rangematch key lo hi using rml_usrc
_rml_assert_labels
frame drop rml_usrc

**# T7: keepusing() subset keeps the carried variable's labels
local ++test_count
_rml_mk_master
rangematch key lo hi using "`labeled_using'", keepusing(grade)
local l : variable label grade
assert `"`l'"' == "Using grade label"
local v : value label grade
assert "`v'" == "gradelbl"
local m : label gradelbl 2
assert `"`m'"' == "mid"

**# T8: value-label name collision -- both definitions survive (RM-I08)
* Before 1.3.3 the master definition won and the carried using variable kept
* its code but acquired the master's meaning: decode returned the wrong text at
* rc=0. The using definition is now copied under a collision-free name.
local ++test_count
clear
set obs 3
gen double key = _n * 10
gen byte flag = 1
label define dupl 1 "using-one"
label values flag dupl
tempfile rml_dup
save "`rml_dup'"
clear
set obs 3
gen long id = _n
gen double lo = _n * 10 - 5
gen double hi = _n * 10 + 5
gen byte mflag = 1
label define dupl 1 "master-one"
label values mflag dupl
rangematch key lo hi using "`rml_dup'"
* The master keeps the original name and its own meaning.
local m : label dupl 1
assert `"`m'"' == "master-one"
local vm : value label mflag
assert "`vm'" == "dupl"
* The carried using variable is attached to a renamed copy of its own map, so
* it decodes to the using data's text rather than the master's.
local v : value label flag
assert "`v'" == "dupl_U"
local u : label dupl_U 1
assert `"`u'"' == "using-one"
decode flag, gen(_t8_txt)
assert _t8_txt[1] == "using-one"
drop _t8_txt

**# T9: strL by() variable in the master data errors upfront with r(109)
local ++test_count
clear
set obs 3
gen double key = _n
gen str4 grp = "a"
tempfile rml_strl_u
save "`rml_strl_u'"
clear
set obs 3
gen double lo = _n - .5
gen double hi = _n + .5
gen strL grp = "a"
capture rangematch key lo hi using "`rml_strl_u'", by(grp)
assert _rc == 109

**# T10: strL by() variable in the using data errors with r(109)
local ++test_count
clear
set obs 3
gen double key = _n
gen strL grp = "a"
tempfile rml_strl_u2
save "`rml_strl_u2'"
clear
set obs 3
gen double lo = _n - .5
gen double hi = _n + .5
gen str4 grp = "a"
capture rangematch key lo hi using "`rml_strl_u2'", by(grp)
assert _rc == 109

**# T11: dangling value-label attachment (no definition) survives without error
local ++test_count
clear
set obs 3
gen double key = _n * 10
tempfile rml_plain
save "`rml_plain'"
clear
set obs 3
gen long id = _n
gen double lo = _n * 10 - 5
gen double hi = _n * 10 + 5
gen byte code = 1
label values code phantomlbl
rangematch key lo hi using "`rml_plain'"
local v : value label code
assert "`v'" == "phantomlbl"

display as result "ALL RANGEMATCH LABEL/SAVING/STRL TESTS PASSED"
display "RESULT: test_rangematch_labels tests=`test_count' pass=`test_count' fail=0"
