* benchmark_codescan_vs_manual.do
* Head-to-head: codescan vs the "typical" hand-coded gen/replace+regexm() loop
* for the SAME task — row-level binary indicators for K conditions across V wide
* code variables. Both must produce identical columns; we time each and report
* the ratio. NOT a gate, NOT in any lane. Run manually:
*   stata-mp -b do benchmark_codescan_vs_manual.do

clear all
version 16.0
set varabbrev off

capture log close _all
log using "benchmark_codescan_vs_manual.log", text replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace
discard

* 20 prefix patterns (one per condition)
local codes E11 E10 E66 I10 I20 I21 I50 J44 J45 N18 C50 C34 F32 F20 M16 M17 K21 K70 G20 G40

program define _bvm_build
    args nobs nvars
    clear
    quietly set obs `nobs'
    local pool E110 E119 E101 E660 I100 I200 I214 I500 J440 J450 N180 C509 C349 F320 F200 M160 M170 K210 K700 G200 G409 Z000 R69 ""
    local npool : word count `pool'
    forvalues v = 1/`nvars' {
        quietly gen str8 dx`v' = ""
        quietly replace dx`v' = word("`pool'", 1 + mod(_n * `v' + `v', `npool'))
    }
end

* codescan define() spec built once
local def ""
local k = 0
foreach c of local codes {
    local ++k
    if `k' == 1  local def `"c`k' "`c'""'
    else         local def `"`def' | c`k' "`c'""'
}

foreach n in 100000 1000000 {
    _bvm_build `n' 30

    * ── Method A: typical hand-coded loop (compiled, vectorized regexm) ──
    timer clear 1
    timer on 1
    forvalues k = 1/20 {
        local c : word `k' of `codes'
        quietly gen byte hc`k' = 0
    }
    forvalues v = 1/30 {
        local kk = 0
        foreach c of local codes {
            local ++kk
            quietly replace hc`kk' = 1 if regexm(dx`v', "^(`c')")
        }
    }
    timer off 1
    quietly timer list 1
    local t_manual = r(t1)

    * ── Method B: codescan (interpreted Mata, distinct-value memoization) ──
    timer clear 2
    timer on 2
    quietly codescan dx1-dx30, define(`def') mode(regex)
    timer off 2
    quietly timer list 2
    local t_codescan = r(t2)

    * Correctness: identical columns (regexm and ustrregexm agree on ASCII)
    forvalues k = 1/20 {
        quietly count if c`k' != hc`k'
        assert r(N) == 0
    }

    local ratio = `t_manual' / `t_codescan'
    display as result "N=`n'  20 conds x 30 vars:  manual=" %7.2f `t_manual' ///
        "s   codescan=" %7.2f `t_codescan' "s   (manual/codescan = " %4.2f `ratio' "x)"
}

display as result "BENCHMARK COMPLETE"
log close _all
