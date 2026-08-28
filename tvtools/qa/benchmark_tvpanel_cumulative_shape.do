*! benchmark_tvpanel_cumulative_shape.do
*! Scaling gate for cumulative panel evaluation (fixed total episodes/windows)
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
set varabbrev off
set processors 1
set seed 20260828
set sortseed 20260828
capture log close _all

local total = cond("`1'" == "", 20000, real("`1'"))
local qadir "`c(pwd)'"
adopath ++ "`qadir'/.."
capture findfile tvpanel.ado
if _rc exit 111

tempfile master episodes
local _tmin = .
local _tmax = 0
local _bad = 0

foreach per in 10 50 200 {
    local nids = floor(`total' / `per')
    local ne = `nids' * `per'
    clear
    quietly set obs `nids'
    quietly generate long id = _n
    quietly generate double entry = 21915
    quietly generate double exit = 21915 + 2 * `per' + 1
    quietly save "`master'", replace

    clear
    quietly set obs `ne'
    quietly generate long id = 1 + floor((_n - 1) / `per')
    quietly generate long seq = 1 + mod(_n - 1, `per')
    quietly generate double start = 21915 + 2 * (seq - 1)
    quietly generate double stop = start
    quietly generate byte eclass = 1 + mod(seq, 2)
    quietly drop seq
    quietly save "`episodes'", replace

    quietly use "`master'", clear
    capture quietly tvpanel using "`episodes'", id(id) entry(entry) exit(exit) ///
        exposure(eclass) reference(0) width(1) cumulative(days)
    quietly use "`master'", clear
    timer clear 82
    timer on 82
    capture noisily tvpanel using "`episodes'", id(id) entry(entry) exit(exit) ///
        exposure(eclass) reference(0) width(1) cumulative(days)
    local rc = _rc
    timer off 82
    quietly timer list 82
    local secs = r(t82)
    local _tmin = min(`_tmin', `secs')
    local _tmax = max(`_tmax', `secs')
    if `rc' local _bad = 1
    display "BENCH: case=tvpanel_cumulative_shape Eper=`per' persons=`nids' " ///
        "E=`ne' Nout=`=_N' rc=`rc' seconds=`secs'"
}

local ratio = `_tmax' / `_tmin'
display "BENCH: case=tvpanel_cumulative_shape fixed_E=`total' max_min_ratio=`ratio'"
if `_bad' | `ratio' > 5 {
    display as error "BENCHBAD: cumulative-panel fixed-row shape ratio `ratio' (>5)"
    exit 459
}
display as text "BENCHDONE"
