quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local TESTS 0
local PASS 0
local FAIL 0

**# T1: point/sweep output is ordered by original master and using rows
local ++TESTS
capture noisily {
    tempfile using_point
    clear
    input int uid double key
    30 30
    10 10
    20 20
    40 40
    end
    save "`using_point'", replace

    clear
    input int mid double(lo hi)
    2 15 35
    1 5 25
    end
    rangematch key lo hi using "`using_point'", keepusing(uid) ///
        unmatched(both) masterid(mobs) usingid(uobs) frame(v154_point) replace
    frame v154_point {
        gen long observed_order = _n
        sort mobs uobs
        assert observed_order == _n
        assert missing(mobs[_N])
        assert uobs[_N] == 4
    }
}
if _rc {
    local ++FAIL
    display as error "FAIL: point/sweep default output ordering"
}
else {
    local ++PASS
    display as result "PASS: point/sweep default output ordering"
}

**# T2: nearest/binary output is ordered by original master and using rows
local ++TESTS
capture noisily {
    tempfile using_nearest
    clear
    input int uid double key
    30 30
    10 10
    20 20
    end
    save "`using_nearest'", replace

    clear
    input int mid double(key lo hi)
    2 25 0 50
    1 15 0 50
    end
    rangematch key lo hi using "`using_nearest'", nearest(both) ties(all) ///
        keepusing(uid) unmatched(none) masterid(mobs) usingid(uobs) ///
        frame(v154_binary) replace
    frame v154_binary {
        gen long observed_order = _n
        sort mobs uobs
        assert observed_order == _n
    }
}
if _rc {
    local ++FAIL
    display as error "FAIL: nearest/binary default output ordering"
}
else {
    local ++PASS
    display as result "PASS: nearest/binary default output ordering"
}

**# T3: overlap output is ordered by original master and using rows
local ++TESTS
capture noisily {
    tempfile using_overlap
    clear
    input int uid double(ulo uhi)
    30 25 35
    10 5 15
    20 15 25
    end
    save "`using_overlap'", replace

    clear
    input int mid double(mlo mhi)
    2 20 30
    1 10 20
    end
    rangematch mlo mhi using "`using_overlap'", overlap(ulo uhi) ///
        keepusing(uid) unmatched(none) masterid(mobs) usingid(uobs) ///
        frame(v154_overlap) replace
    frame v154_overlap {
        gen long observed_order = _n
        sort mobs uobs
        assert observed_order == _n
    }
}
if _rc {
    local ++FAIL
    display as error "FAIL: overlap default output ordering"
}
else {
    local ++PASS
    display as result "PASS: overlap default output ordering"
}

display "RESULT: test_rangematch_v154 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
