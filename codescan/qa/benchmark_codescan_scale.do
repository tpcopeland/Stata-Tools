* benchmark_codescan_scale.do
* Registry-scale wall-time guardrail for the codescan mata core. NOT a gate and
* NOT in any run_all.do lane — run manually:  stata-mp -b do benchmark_codescan_scale.do
* Records timings for prefix and regex (ICU) modes at 100k and 1M rows x 30 code
* variables x 20 conditions, so a future regression in the hot loop is visible.
*
* Measured 2026-06-30 (16-core stata-mp), 30 vars x 20 conds:
*                  prefix      regex(ICU)
*     100k rows    12.2s        12.8s
*       1M rows   127.5s       127.3s
*
* v2.0.4 introduced distinct-value memoization (classify each unique code once,
* then look it up). That removed pattern matching as the bottleneck — regex(ICU)
* at 100k dropped from ~100s (v2.0.3, per-cell) to ~13s (~8x), and prefix and
* regex now cost the same because neither re-runs the matcher per cell. The
* residual cost is the per-cell pass itself (transform + asarray lookup + the
* indicator OR-in over O(N x nvars) cells), which scales ~linearly in rows.
* A future single-pass variant (lazy classify-on-first-encounter) could roughly
* halve the residual by avoiding the second cell sweep; deferred as it trades a
* clean two-pass structure for per-cell vector copies. Cost still grows with the
* cell:distinct-code ratio, so prefer prefix mode when the rule set allows it.

clear all
version 16.0
set varabbrev off

capture log close _all
log using "benchmark_codescan_scale.log", text replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
discard

* 20 ICD-10-ish prefixes spread across chapters
local codes E11 E10 E66 I10 I20 I21 I50 J44 J45 N18 C50 C34 F32 F20 M16 M17 K21 K70 G20 G40

program define _bench_build
    args nobs nvars
    clear
    quietly set obs `nobs'
    local pool E110 E119 E101 E660 I100 I200 I214 I500 J440 J450 N180 C509 C349 F320 F200 M160 M170 K210 K700 G200 G409 Z000 R69 ""
    local npool : word count `pool'
    forvalues v = 1/`nvars' {
        quietly gen str8 dx`v' = ""
        * Deterministic spread: each var draws from the pool by a hash of _n.
        quietly replace dx`v' = word("`pool'", 1 + mod(_n * `v' + `v', `npool'))
    }
end

* Build the 20-condition define() spec once.
local def ""
local k = 0
foreach c of local codes {
    local ++k
    if `k' == 1  local def `"c`k' "`c'""'
    else         local def `"`def' | c`k' "`c'""'
}

foreach n in 100000 1000000 {
    * Fresh data for each timed scan so the two modes' output vars never collide.
    _bench_build `n' 30
    timer clear 1
    timer on 1
    quietly codescan dx1-dx30, define(`def') mode(prefix)
    timer off 1
    quietly timer list 1
    local t_prefix = r(t1)

    _bench_build `n' 30
    timer clear 2
    timer on 2
    quietly codescan dx1-dx30, define(`def') mode(regex)
    timer off 2
    quietly timer list 2
    local t_regex = r(t2)

    display as result "N=`n'  30 vars x 20 conds:  prefix=" %7.2f `t_prefix' "s   regex(ICU)=" %7.2f `t_regex' "s"
}

display as result "BENCHMARK COMPLETE"
log close _all
