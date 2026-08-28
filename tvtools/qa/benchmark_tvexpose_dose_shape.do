*! benchmark_tvexpose_dose_shape.do
*! Scaling gate for dose overlap allocation (fixed total episode rows)
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
capture findfile tvexpose.ado
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
    quietly generate long pid = _n
    quietly generate double entry = 21915
    quietly generate double exit = 21915 + `per' + 30
    quietly save "`master'", replace

    clear
    quietly set obs `ne'
    quietly generate long pid = 1 + floor((_n - 1) / `per')
    quietly generate long seq = 1 + mod(_n - 1, `per')
    quietly generate double start = 21914 + seq
    quietly generate double stop = start + 30
    quietly generate double daily_dose = 1 + mod(seq, 5) / 10
    quietly drop seq
    quietly save "`episodes'", replace

    * Warm cache and compiled Mata before measuring.
    quietly use "`master'", clear
    capture quietly tvexpose using "`episodes'", id(pid) start(start) ///
        stop(stop) exposure(daily_dose) entry(entry) exit(exit) dose
    quietly use "`master'", clear
    timer clear 81
    timer on 81
    capture noisily tvexpose using "`episodes'", id(pid) start(start) ///
        stop(stop) exposure(daily_dose) entry(entry) exit(exit) dose
    local rc = _rc
    timer off 81
    quietly timer list 81
    local secs = r(t81)
    local _tmin = min(`_tmin', `secs')
    local _tmax = max(`_tmax', `secs')
    if `rc' local _bad = 1
    display "BENCH: case=dose_shape Eper=`per' persons=`nids' E=`ne' " ///
        "Nout=`=_N' rc=`rc' seconds=`secs'"
}

local ratio = `_tmax' / `_tmin'
display "BENCH: case=dose_shape fixed_E=`total' max_min_ratio=`ratio'"
if `_bad' | `ratio' > 5 {
    display as error "BENCHBAD: dose fixed-row shape ratio `ratio' (>5)"
    exit 459
}
display as text "BENCHDONE"
