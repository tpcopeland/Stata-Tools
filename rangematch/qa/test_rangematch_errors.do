* test_rangematch_errors.do
* Error-path contracts for rangematch
* Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.1
set varabbrev off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _rm_errors_using
program define _rm_errors_using
    clear
    set obs 1
    generate double key = 5
    generate double x = 42
end

* T1: parser-level enum validation rejects an invalid closure without mutation.
local ++test_count
capture noisily {
    _rm_errors_using
    tempfile using_data
    save "`using_data'"
    clear
    input double key low high marker
    5 0 10 77
    end
    capture noisily rangematch key low high using "`using_data'", closed(middle)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 1
    assert key == 5 & low == 0 & high == 10 & marker == 77
    rangematch key low high using "`using_data'", closed(both) keepusing(x)
    assert _N == 1
    assert x == 42
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T2: missing(error) is a mid-pipeline safety contract, not an rc=0 no-op.
local ++test_count
capture noisily {
    _rm_errors_using
    tempfile using_data
    save "`using_data'"
    clear
    input double key low high marker
    5 . 10 88
    6 0 10 89
    7 0 10 90
    end
    quietly regress high key
    capture noisily rangematch key low high using "`using_data'", missing(error)
    local call_rc = _rc
    assert `call_rc' == 459
    assert _N == 3
    assert missing(low[1]) & high[1] == 10 & marker[1] == 88
    assert "`e(cmd)'" == "regress"
    rangematch key low high using "`using_data'", missing(drop) unmatched(master)
    assert _N == 2
    assert r(N_master) == 2
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T3: overlap-only and nearest-only controls must not be silently combined.
local ++test_count
capture noisily {
    clear
    input double ulo uhi x
    0 10 42
    end
    tempfile using_data
    save "`using_data'"
    clear
    input double low high marker
    2 8 99
    end
    capture noisily rangematch low high using "`using_data'", overlap(ulo uhi) nearest(before)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 1
    assert low == 2 & high == 8 & marker == 99
    rangematch low high using "`using_data'", overlap(ulo uhi) keepusing(x)
    assert _N == 1
    assert x == 42
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T4: a late destination collision must keep the source frame intact.
local ++test_count
capture noisily {
    _rm_errors_using
    tempfile using_data
    save "`using_data'"
    clear
    input double key low high marker
    5 0 10 66
    end
    frame create rm_errors_destination
    frame rm_errors_destination: clear
    frame rm_errors_destination: set obs 1
    frame rm_errors_destination: gen byte sentinel = 1
    capture noisily rangematch key low high using "`using_data'", frame(rm_errors_destination)
    local call_rc = _rc
    assert `call_rc' == 110
    assert _N == 1
    assert marker == 66
    frame rm_errors_destination: assert _N == 1
    frame rm_errors_destination: assert sentinel == 1
    rangematch key low high using "`using_data'", frame(rm_errors_destination) replace keepusing(x)
    frame rm_errors_destination: assert _N == 1
    frame rm_errors_destination: assert x == 42
    frame drop rm_errors_destination
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T5: invalid nearest() values fail before creating frame/file output.
local ++test_count
capture noisily {
    _rm_errors_using
    tempfile using_data bad_output before
    save "`using_data'"
    clear
    input double key low high marker
    5 0 10 55
    end
    save "`before'", replace

    capture noisily rangematch key low high using "`using_data'", ///
        nearest(bad) frame(rm_errors_bad_nearest)
    local frame_rc = _rc
    capture frame rm_errors_bad_nearest: describe
    local frame_exists = (_rc == 0)
    capture frame drop rm_errors_bad_nearest
    cf _all using "`before'"

    capture noisily rangematch key low high using "`using_data'", ///
        nearest(bad) saving("`bad_output'")
    local saving_rc = _rc
    capture confirm file "`bad_output'"
    local file_exists = (_rc == 0)
    capture erase "`bad_output'"
    cf _all using "`before'"

    assert `frame_rc' == 198
    assert `saving_rc' == 198
    assert !`frame_exists'
    assert !`file_exists'
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T6: invalid closed() values fail before creating frame/file output.
local ++test_count
capture noisily {
    _rm_errors_using
    tempfile using_data bad_output before
    save "`using_data'"
    clear
    input double key low high marker
    5 0 10 44
    end
    save "`before'", replace

    capture noisily rangematch key low high using "`using_data'", ///
        closed(bad) frame(rm_errors_bad_closed)
    local frame_rc = _rc
    capture frame rm_errors_bad_closed: describe
    local frame_exists = (_rc == 0)
    capture frame drop rm_errors_bad_closed
    cf _all using "`before'"

    capture noisily rangematch key low high using "`using_data'", ///
        closed(bad) saving("`bad_output'")
    local saving_rc = _rc
    capture confirm file "`bad_output'"
    local file_exists = (_rc == 0)
    capture erase "`bad_output'"
    cf _all using "`before'"

    assert `frame_rc' == 198
    assert `saving_rc' == 198
    assert !`frame_exists'
    assert !`file_exists'
}
if _rc == 0 local ++pass_count
else local ++fail_count

capture program drop _rm_errors_using

if `fail_count' > 0 {
    display as error "RESULT: test_rangematch_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
