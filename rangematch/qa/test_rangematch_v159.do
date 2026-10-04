*! test_rangematch_v159.do
*! Regression gates for the 1.5.9 fixes.
*!
*!   T1  sweep backend under nosort: using rows with tied keys were emitted in
*!       an order Mata's unstable sort() chose afresh on every call. On 3
*!       masters x 3,000 tied using rows, ~1,490 rows per run were out of
*!       original-row order and 2,997 of 3,000 rows moved between two identical
*!       runs. The binary and overlap backends already broke ties on the
*!       original using row; the sweep backend did not.
*!   T2  the same call twice gives an identical nosort order (sweep backend).
*!   T3  a master value-label definition attached to no variable was dropped
*!       from the output on the memory and frame() routes. The definition must
*!       exist IN MEMORY: Stata's own `save' writes only attached definitions,
*!       so a master reloaded from disk never carries one (T6 pins that, so
*!       the fixtures below cannot silently start testing an empty premise).
*!   T4  an unattached master definition still owns its name: a carried using
*!       variable attached to the same name with a DIFFERENT mapping gets the
*!       collision-free copy, and the master definition keeps its meaning.
*!   T5  guard: an identical using mapping under the same name is shared, not
*!       copied.
*!   T6  premise guard: saving() goes through Stata's `save', which drops an
*!       unattached definition exactly as saving the master itself would.

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local TESTS 0
local PASS 0
local FAIL 0

**# Fixtures: tied-key using data and a pre-sorted master
clear
set obs 3000
gen double k = mod(_n, 3)
tempfile tied
save `tied'
clear
set obs 3
gen double lo = _n - 1
gen double hi = lo
gen double k = lo
tempfile sortedm
save `sortedm'

**# T1: sweep + nosort emits tied using rows in original-row order
local ++TESTS
capture noisily {
    use `sortedm', clear
    rangematch k lo hi using `tied', nosort usingid(uid) masterid(mid) ///
        unmatched(none)
    assert "`r(backend)'" == "sweep"
    assert _N == 3000
    * nosort: the output order is the emission order, so read it as stored
    gen long seq = _n
    * masters are emitted in their pre-sorted order, each block contiguous
    assert mid >= mid[_n-1] if _n > 1
    * within one master, tied using rows follow the original using row
    * (no `by': nosort output carries no sort flag, which is the point)
    assert uid > uid[_n-1] if _n > 1 & mid == mid[_n-1]
}
if _rc {
    local ++FAIL
    display as error "FAIL: T1 sweep nosort tied-key order follows original using row"
}
else {
    local ++PASS
    display as result "PASS: T1 sweep nosort tied-key order follows original using row"
}

**# T2: the same sweep nosort call twice gives an identical order
local ++TESTS
capture noisily {
    forvalues r = 1/2 {
        use `sortedm', clear
        rangematch k lo hi using `tied', nosort usingid(uid) masterid(mid) ///
            unmatched(none)
        assert "`r(backend)'" == "sweep"
        gen long seq = _n
        keep seq mid uid
        rename (mid uid) (mid`r' uid`r')
        tempfile run`r'
        save `run`r''
    }
    use `run1', clear
    merge 1:1 seq using `run2', assert(match) nogenerate
    assert mid1 == mid2 & uid1 == uid2
}
if _rc {
    local ++FAIL
    display as error "FAIL: T2 sweep nosort order reproducible across runs"
}
else {
    local ++PASS
    display as result "PASS: T2 sweep nosort order reproducible across runs"
}

**# Fixtures: a master whose unattached value-label definition is in memory
* `_v159_orphan_master' rebuilds it each time; it cannot come from a saved file.
capture program drop _v159_orphan_master
program define _v159_orphan_master
    clear
    set obs 1
    gen double k = 1
    gen double lo = 0
    gen double hi = 2
    label define orphan 1 "one" 2 "two"
end
clear
input double k byte u
1 1
end
tempfile plainu
save `plainu'

**# T3: the unattached master definition survives the memory and frame() routes
local ++TESTS
capture noisily {
    * in-memory route
    _v159_orphan_master
    rangematch k lo hi using `plainu'
    label list orphan
    assert `"`: label orphan 1'"' == "one"
    assert `"`: label orphan 2'"' == "two"
    * frame() route
    _v159_orphan_master
    rangematch k lo hi using `plainu', frame(v159f) replace
    frame v159f {
        label list orphan
        assert `"`: label orphan 1'"' == "one"
        assert `"`: label orphan 2'"' == "two"
    }
    frame drop v159f
    * the caller's own definition is untouched by a frame() run
    label list orphan
    assert `"`: label orphan 1'"' == "one"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T3 unattached master value-label definition is carried"
}
else {
    local ++PASS
    display as result "PASS: T3 unattached master value-label definition is carried"
}

**# T4: a conflicting using mapping under the master's unattached name is renamed
local ++TESTS
capture noisily {
    clear
    input double k byte u
    1 1
    end
    label define orphan 1 "uno"
    label values u orphan
    tempfile conflictu
    save `conflictu'
    _v159_orphan_master
    rangematch k lo hi using `conflictu'
    * the master definition keeps its name and its meaning
    assert `"`: label orphan 1'"' == "one"
    * the carried variable keeps the using meaning under a free name
    local lbl : value label u
    assert "`lbl'" == "orphan_U"
    assert `"`: label (u) 1'"' == "uno"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T4 conflicting using mapping does not hijack the master definition"
}
else {
    local ++PASS
    display as result "PASS: T4 conflicting using mapping does not hijack the master definition"
}

**# T5: an identical using mapping under the same name is shared
local ++TESTS
capture noisily {
    clear
    input double k byte u
    1 2
    end
    label define orphan 1 "one" 2 "two"
    label values u orphan
    tempfile sameu
    save `sameu'
    _v159_orphan_master
    rangematch k lo hi using `sameu'
    local lbl : value label u
    assert "`lbl'" == "orphan"
    assert `"`: label (u) 2'"' == "two"
    capture label list orphan_U
    assert _rc != 0
}
if _rc {
    local ++FAIL
    display as error "FAIL: T5 identical mapping is shared, not copied"
}
else {
    local ++PASS
    display as result "PASS: T5 identical mapping is shared, not copied"
}

**# T6: saving() matches what Stata's own save does with an unattached definition
local ++TESTS
capture noisily {
    * premise: a plain save drops it
    _v159_orphan_master
    tempfile plainsave
    save `plainsave'
    use `plainsave', clear
    capture label list orphan
    local plain_rc = _rc
    * saving() writes through the same save, so it drops it too
    _v159_orphan_master
    tempfile joined
    rangematch k lo hi using `plainu', saving(`"`joined'"', replace)
    use `"`joined'"', clear
    capture label list orphan
    assert _rc == `plain_rc'
    assert `plain_rc' != 0
}
if _rc {
    local ++FAIL
    display as error "FAIL: T6 saving() follows Stata save for unattached definitions"
}
else {
    local ++PASS
    display as result "PASS: T6 saving() follows Stata save for unattached definitions"
}

display "RESULT: test_rangematch_v159 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
