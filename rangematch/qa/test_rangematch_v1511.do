*! test_rangematch_v1511.do
*! Regression gates for 1.5.11: the Mata backend compiles silently.
*!
*!   T1  the first rangematch call after `clear all' (backend not in memory)
*!       writes no Mata source into an open text log, under both a plain call
*!       and a `noisily' call; the log holds only the command's own output.
*!   T2  that first call loads the current backend and returns the expected
*!       match count (the silent load is not a skipped load).

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
set varabbrev off

local TESTS 0
local PASS 0
local FAIL 0

capture program drop _v1511_data
program define _v1511_data
    syntax , USING(string)
    clear
    quietly set obs 3
    quietly gen long uid = _n
    quietly gen double key = _n
    quietly save `"`using'"', replace
    clear
    quietly set obs 2
    quietly gen double lo = 0
    quietly gen double hi = 5
end

* Counts the lines of a text file and how many of them contain `needle'.
capture mata: mata drop _v1511_scan()
mata:
void _v1511_scan(string scalar path, string scalar needle)
{
    string colvector lines
    lines = cat(path)
    st_local("n_hits", strofreal(sum(strpos(lines, needle) :> 0)))
    st_local("n_lines", strofreal(rows(lines)))
}
end

**# T1 plain and noisily first calls write no Mata source to the log
foreach prefix in "" "noisily" {
    local ++TESTS
    capture noisily {
        tempfile u lg
        _v1511_data, using(`"`u'"')
        * Drop the backend so this call must compile it.
        capture mata: mata drop _rm_mata_version()
        capture mata: st_local("still", _rm_mata_version())
        assert _rc != 0
        log using `"`lg'"', text replace name(v1511) nomsg
        `prefix' rangematch key lo hi using `"`u'"'
        log close v1511
        mata: _v1511_scan(st_local("lg"), "mata (type end to exit)")
        display as text "prefix=[`prefix'] mata banners=`n_hits' log lines=`n_lines'"
        assert `n_hits' == 0
        mata: _v1511_scan(st_local("lg"), "_rm_mata_version()")
        assert `n_hits' == 0
        * The command's own output is a few dozen lines, not the backend source.
        assert `n_lines' < 80
    }
    if _rc {
        capture log close v1511
        local ++FAIL
        display as error "FAIL: T1 [`prefix'] first call echoes no Mata source"
    }
    else {
        local ++PASS
        display as result "PASS: T1 [`prefix'] first call echoes no Mata source"
    }
}

**# T2 the silent first call still loads the current backend and matches
local ++TESTS
capture noisily {
    tempfile u
    _v1511_data, using(`"`u'"')
    capture mata: mata drop _rm_mata_version()
    quietly rangematch key lo hi using `"`u'"'
    assert r(N_matched_pairs) == 6
    assert _N == 6
    local got ""
    mata: st_local("got", _rm_mata_version())
    assert "`got'" == "1.5.12"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T2 silent load installs the current backend and matches"
}
else {
    local ++PASS
    display as result "PASS: T2 silent load installs the current backend and matches"
}

display "RESULT: test_rangematch_v1511 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
