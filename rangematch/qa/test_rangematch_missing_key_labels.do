* test_rangematch_missing_key_labels.do
* Phase-2 contract suite for the rangematch clarity audit:
*   RM-I06  the missing() policy governs the master key wherever that key is a
*           matching input (scalar offsets, nearest()), reported separately in
*           r(N_master_key_missing)
*   RM-I08  a same-named/different value-label definition preserves both
*           meanings under collision-free names
*   RM-I09  missing counts are posted on successful wildcard/drop runs and are
*           NOT posted under missing(error), which exits before any return
*
* Every test below fails on 1.3.3: missing(error) returned rc=0 on a missing
* matching key, r(N_master_key_missing) did not exist, and a carried using
* variable silently acquired the master's value-label meaning.

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
set varabbrev off

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}


local test_count = 0
local pass_count = 0
local fail_count = 0

**# Shared fixtures
tempfile u_pt m_key u_lab m_lab u_same m_same
clear
set obs 3
gen double k = _n
gen str3 tag = "u" + string(_n)
save "`u_pt'"

clear
set obs 3
gen double k = cond(_n == 1, ., _n)
gen double lo = _n - 0.5
gen double hi = _n + 0.5
save "`m_key'"

**# T1 (I06): scalar offsets + missing(error) rejects a missing master key
local ++test_count
capture noisily {
    use "`m_key'", clear
    capture rangematch k -1 1 using "`u_pt'", missing(error) unmatched(none)
    assert _rc == 459
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T1 offsets missing(error)"
}
else {
    local ++pass_count
    display as text "[ok] T1 offsets missing(error)"
}

**# T2 (I06): nearest() + missing(error) rejects a missing master key
local ++test_count
capture noisily {
    use "`m_key'", clear
    capture rangematch k . . using "`u_pt'", nearest(both) missing(error) ///
        unmatched(none)
    assert _rc == 459
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T2 nearest missing(error)"
}
else {
    local ++pass_count
    display as text "[ok] T2 nearest missing(error)"
}

**# T3 (I06): the policy does NOT apply when the key is only carried
* Variable bounds with no nearest() make the key a carried value, not a
* matching input, so missing(error) must not reject it.
local ++test_count
capture noisily {
    use "`m_key'", clear
    rangematch k lo hi using "`u_pt'", missing(error) unmatched(none)
    local nk = r(N_master_key_missing)
    assert `nk' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T3 carried key is not a matching input"
}
else {
    local ++pass_count
    display as text "[ok] T3 carried key is not a matching input"
}

**# T4 (I06): missing(drop) removes the missing-key row
local ++test_count
capture noisily {
    use "`m_key'", clear
    rangematch k -1 1 using "`u_pt'", missing(drop) unmatched(none)
    local nm = r(N_master)
    local nk = r(N_master_key_missing)
    assert `nm' == 2
    assert `nk' == 1
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T4 missing(drop) removes missing-key rows"
}
else {
    local ++pass_count
    display as text "[ok] T4 missing(drop) removes missing-key rows"
}

**# T5 (I06): wildcard keeps the row, matches nothing, still reports the count
local ++test_count
capture noisily {
    use "`m_key'", clear
    rangematch k -1 1 using "`u_pt'", unmatched(none)
    local nk = r(N_master_key_missing)
    local nm = r(N_master)
    assert `nk' == 1
    assert `nm' == 3
    * keys 2 and 3 each span [1,3] and [2,4] over using keys 1,2,3
    local np = r(N_matched_pairs)
    assert `np' == 5
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T5 wildcard never-match contract preserved"
}
else {
    local ++pass_count
    display as text "[ok] T5 wildcard never-match contract preserved"
}

**# T6 (I06): extended missings are caught, not just sysmiss
local ++test_count
capture noisily {
    use "`m_key'", clear
    quietly replace k = .a in 1
    capture rangematch k -1 1 using "`u_pt'", missing(error) unmatched(none)
    assert _rc == 459
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T6 extended missing key caught"
}
else {
    local ++pass_count
    display as text "[ok] T6 extended missing key caught"
}

**# T7 (I06): overlap mode defines the scalar as 0
local ++test_count
capture noisily {
    tempfile u_ov m_ov
    clear
    set obs 3
    gen double ulo = _n
    gen double uhi = _n + 1
    save "`u_ov'"
    clear
    set obs 3
    gen double lo = _n
    gen double hi = _n + 1
    save "`m_ov'"
    use "`m_ov'", clear
    rangematch lo hi using "`u_ov'", overlap(ulo uhi) unmatched(none)
    local nk = r(N_master_key_missing)
    assert `nk' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T7 overlap posts the scalar as 0"
}
else {
    local ++pass_count
    display as text "[ok] T7 overlap posts the scalar as 0"
}

**# T8 (I06): a row missing BOTH key and bound counts in both diagnostics
local ++test_count
capture noisily {
    use "`m_key'", clear
    quietly replace lo = . in 1
    rangematch k lo hi using "`u_pt'", nearest(both) unmatched(none)
    local nb = r(N_missing_bounds)
    local nk = r(N_master_key_missing)
    assert `nb' == 1
    assert `nk' == 1
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T8 both-missing row counted in both diagnostics"
}
else {
    local ++pass_count
    display as text "[ok] T8 both-missing row counted in both diagnostics"
}

**# T9 (I09): missing(error) posts NO counts -- and no stale ones
* A prior successful run leaves r() populated. The captured error must not let
* callers read those stale values back as if they described the failed call.
local ++test_count
capture noisily {
    use "`m_key'", clear
    rangematch k -1 1 using "`u_pt'", unmatched(none)
    assert r(N_master_key_missing) == 1
    * A successful in-place run replaces the data with the joined output, so
    * reload the master before the call that must fail.
    use "`m_key'", clear
    capture rangematch k -1 1 using "`u_pt'", missing(error) unmatched(none)
    assert _rc == 459
    capture confirm scalar r(N_master_key_missing)
    assert _rc != 0
    capture confirm scalar r(N_missing_bounds)
    assert _rc != 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T9 missing(error) posts no counts"
}
else {
    local ++pass_count
    display as text "[ok] T9 missing(error) posts no counts"
}

**# T10 (I08): conflicting label definitions preserve both meanings
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double k = _n
    gen byte cat = 1
    gen byte cat2 = 1
    label define shared 1 "using-one"
    label values cat shared
    label values cat2 shared
    save "`u_lab'"

    clear
    set obs 3
    gen double k = _n
    gen double lo = _n - 0.5
    gen double hi = _n + 0.5
    gen byte mcat = 1
    label define shared 1 "master-one"
    label values mcat shared
    save "`m_lab'"

    use "`m_lab'", clear
    rangematch k lo hi using "`u_lab'", unmatched(none)
    * master keeps the original name and meaning
    local vm : value label mcat
    assert "`vm'" == "shared"
    local tm : label shared 1
    assert `"`tm'"' == "master-one"
    * the carried using variables decode to their OWN text
    local vu : value label cat
    assert "`vu'" == "shared_U"
    decode cat, gen(_t10a)
    assert _t10a[1] == "using-one"
    * one renamed copy is reused for both carried variables sharing the map
    local vu2 : value label cat2
    assert "`vu2'" == "shared_U"
    capture label list shared_U2
    assert _rc != 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T10 conflicting definitions both survive"
}
else {
    local ++pass_count
    display as text "[ok] T10 conflicting definitions both survive"
}

**# T11 (I08): identical definitions are shared, NOT renamed
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double k = _n
    gen byte cat = 1
    label define same 1 "one"
    label values cat same
    save "`u_same'"

    clear
    set obs 3
    gen double k = _n
    gen double lo = _n - 0.5
    gen double hi = _n + 0.5
    gen byte mcat = 1
    label define same 1 "one"
    label values mcat same
    save "`m_same'"

    use "`m_same'", clear
    rangematch k lo hi using "`u_same'", unmatched(none)
    local vu : value label cat
    assert "`vu'" == "same"
    capture label list same_U
    assert _rc != 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T11 identical definitions are shared"
}
else {
    local ++pass_count
    display as text "[ok] T11 identical definitions are shared"
}

**# T12 (I08): the rename survives the frame() route
local ++test_count
capture noisily {
    use "`m_lab'", clear
    capture frame drop rm_i08
    rangematch k lo hi using "`u_lab'", unmatched(none) frame(rm_i08)
    frame rm_i08 {
        local vu : value label cat
        assert "`vu'" == "shared_U"
        decode cat, gen(_t12)
        assert _t12[1] == "using-one"
        local tm : label shared 1
        assert `"`tm'"' == "master-one"
    }
    capture frame drop rm_i08
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T12 rename survives frame() route"
}
else {
    local ++pass_count
    display as text "[ok] T12 rename survives frame() route"
}

**# T13 (I08): a 32-character label name still resolves within Stata's cap
local ++test_count
capture noisily {
    tempfile u_long m_long
    local nm32 "abcdefghijabcdefghijabcdefghij12"
    clear
    set obs 3
    gen double k = _n
    gen byte cat = 1
    label define `nm32' 1 "using-one"
    label values cat `nm32'
    save "`u_long'"
    clear
    set obs 3
    gen double k = _n
    gen double lo = _n - 0.5
    gen double hi = _n + 0.5
    gen byte mcat = 1
    label define `nm32' 1 "master-one"
    label values mcat `nm32'
    save "`m_long'"
    use "`m_long'", clear
    rangematch k lo hi using "`u_long'", unmatched(none)
    local vu : value label cat
    assert strlen("`vu'") <= 32
    assert "`vu'" != "`nm32'"
    decode cat, gen(_t13)
    assert _t13[1] == "using-one"
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T13 32-char label name resolves"
}
else {
    local ++pass_count
    display as text "[ok] T13 32-char label name resolves"
}

**# T14 (I06): offsets AND nearest() together explain BOTH reasons
* Each mode makes the key a matching input for its own reason. An if/else here
* reported the offsets and stayed silent about the distance, so a user with
* both got a diagnostic that explained half of why their call was rejected.
* The needles are error-message text that appears nowhere in the command line,
* so a log echo cannot fake this green.
local ++test_count
capture noisily {
    tempfile t14_log
    use "`m_key'", clear
    capture log close _rm_t14_log
    quietly log using "`t14_log'", replace text name(_rm_t14_log)
    * `noisily' is load-bearing: a bare `capture' swallows the display output
    * this test exists to read, so the needles would never reach the log and
    * the assertions below would fail on correct code.
    capture noisily rangematch k -1 1 using "`u_pt'", nearest(both) ///
        missing(error) unmatched(none)
    local t14_rc = _rc
    quietly log close _rm_t14_log
    assert `t14_rc' == 459

    tempname fh14
    local saw_interval = 0
    local saw_distance = 0
    file open `fh14' using "`t14_log'", read text
    file read `fh14' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "so the match interval is undefined") > 0 {
            local saw_interval = 1
        }
        if strpos(`"`line'"', "so the match distance is undefined") > 0 {
            local saw_distance = 1
        }
        file read `fh14' line
    }
    file close `fh14'
    assert `saw_interval' == 1
    assert `saw_distance' == 1
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T14 offsets+nearest explain both reasons"
}
else {
    local ++pass_count
    display as text "[ok] T14 offsets+nearest explain both reasons"
}

**# Summary
display as text _newline "test_rangematch_missing_key_labels"
display as text "Tests:  `test_count'"
display as text "Passed: `pass_count'"
display as text "Failed: `fail_count'"
display "RESULT: test_rangematch_missing_key_labels tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 exit 9
