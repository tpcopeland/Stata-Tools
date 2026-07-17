/*  demo_rangematch.do - Demo output for rangematch

    Produces:
      1. Console output (exposure-window workflow) -> .log -> .md via logdoc
      2. Console output (rangematch/rangejoin benchmarks) -> .log -> .md via logdoc
*/

version 16.1
clear all
set more off
set varabbrev off
set linesize 120
set seed 20260226

**# Paths
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 15, 16) == "/rangematch/demo" {
    local demo_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 5)
    local repo_root = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - 11)
}
else if substr("`cwd'", `cwd_len' - 10, 11) == "/rangematch" {
    local pkg_dir "`cwd'"
    local demo_dir "`pkg_dir'/demo"
    local repo_root = substr("`cwd'", 1, `cwd_len' - 11)
}
else {
    local repo_root "`cwd'"
    local pkg_dir "`repo_root'/rangematch"
    local demo_dir "`pkg_dir'/demo"
}

capture confirm file "`pkg_dir'/rangematch.ado"
if _rc {
    display as error "rangematch.ado was not found from current directory `cwd'"
    exit 601
}

capture mkdir "`demo_dir'"

**# Sandbox the ado path
* PERSONAL precedes PLUS on the adopath, so redirecting PLUS alone leaves a stale
* PERSONAL copy able to shadow the package under test -- the demo would then
* benchmark the wrong code and report it as the local install. Both directories
* move, both originals are saved, and both are restored on every exit path below.
* The directories are process-unique so concurrent runs cannot share state.
tempfile _uniq_probe
mata: st_local("_uniq_tok", pathbasename(st_local("_uniq_probe")))
local old_plus "`c(sysdir_plus)'"
local old_personal "`c(sysdir_personal)'"
local demo_plus "`c(tmpdir)'/rm_demo_plus_`_uniq_tok'"
local demo_personal "`c(tmpdir)'/rm_demo_personal_`_uniq_tok'"
local plus_changed = 0
local personal_changed = 0

* Everything that can fail runs inside this block so that a mid-demo error still
* reaches the cleanup zone. `local rc = _rc' is the first line after it.
capture noisily {

mkdir "`demo_plus'"
mkdir "`demo_personal'"
local plus_changed = 1
sysdir set PLUS "`demo_plus'"
local personal_changed = 1
sysdir set PERSONAL "`demo_personal'"

**# Install package from local source
capture ado uninstall rangematch
quietly net install rangematch, from("`pkg_dir'") replace
discard

* Prove the demo runs the copy just installed. Without this the local-install
* claim rests on the sysdir edits above rather than on observed resolution.
capture findfile rangematch.ado
if _rc {
    display as error "rangematch.ado does not resolve after the demo install"
    exit 601
}
if strpos("`r(fn)'", "`demo_plus'") != 1 {
    display as error "rangematch resolved to `r(fn)', not the demo install under `demo_plus'"
    exit 459
}

**# Install comparison packages in temporary PLUS
capture ado uninstall rangestat
capture ado uninstall rangejoin
capture quietly ssc install rangestat, replace
local rangestat_rc = _rc
capture quietly ssc install rangejoin, replace
local rangejoin_rc = _rc
local has_rangejoin = (`rangestat_rc' == 0 & `rangejoin_rc' == 0)
if !`has_rangejoin' {
    display as text "rangejoin or rangestat could not be installed from SSC; comparison rows will be skipped."
}

**# Exposure-window workflow
capture log close _all
log using "`demo_dir'/workflow.log", replace text name(workflow) nomsg

* # Exposure-window matching

quietly {
    clear
    input double patient_id str10 start_string double exposure_days str9 drug
    101 "2020-01-15" 30 "drug_a"
    101 "2020-03-01" 14 "drug_b"
    102 "2020-02-10" 21 "drug_a"
    103 "2020-02-20" 10 "drug_c"
    end

    generate double exposure_start = daily(start_string, "YMD")
    generate double exposure_end = exposure_start + exposure_days
    format exposure_start exposure_end %td
    drop start_string exposure_days
    tempfile exposures adverse_events
    save "`exposures'"

    clear
    input double patient_id double event_id str10 event_string str18 event_type double severity
    101 1001 "2020-01-20" "rash"      2
    101 1002 "2020-02-20" "headache"  1
    101 1003 "2020-03-10" "nausea"    2
    102 1004 "2020-02-15" "dizziness" 3
    102 1005 "2020-03-20" "fatigue"   1
    103 1006 "2020-02-25" "rash"      1
    104 1007 "2020-02-28" "cough"     1
    end

    generate double event_date = daily(event_string, "YMD")
    format event_date %td
    drop event_string
    save "`adverse_events'"
}

use "`exposures'", clear
noisily rangematch event_date exposure_start exposure_end using "`adverse_events'", ///
    by(patient_id) keepusing(event_id event_date event_type severity) ///
    generate(match_status) masterid(exposure_row) usingid(event_row) ///
    frame(exposure_events) replace stats

noisily frame exposure_events: list patient_id drug exposure_start exposure_end ///
    event_id event_date event_type severity match_status, sepby(patient_id) noobs

log close workflow

**# Synthetic benchmarks
capture log close _all
log using "`demo_dir'/benchmark.log", replace text name(benchmark) nomsg

* # Benchmark: rangematch versus rangejoin

display as text "Shared syntax benchmark: key lo hi using file, by(group)."
display as text "rangematch uses unmatched(none) and nosort so both commands emit matched pairs without a final order guarantee."
display as text "Times include pair generation and output materialization."

quietly {
    local scenario1  "sparse_10k"
    local nmaster1   10000
    local nusing1    10000
    local groups1    20
    local halfwidth1 0

    local scenario2  "dense_10k"
    local nmaster2   10000
    local nusing2    10000
    local groups2    20
    local halfwidth2 10

    local scenario3  "sparse_100k"
    local nmaster3   100000
    local nusing3    100000
    local groups3    50
    local halfwidth3 0

    local scenario4  "dense_100k"
    local nmaster4   100000
    local nusing4    100000
    local groups4    50
    local halfwidth4 5

    local scenario5  "sparse_1m"
    local nmaster5   1000000
    local nusing5    1000000
    local groups5    100
    local halfwidth5 0

    local scenario6  "dense_1m"
    local nmaster6   1000000
    local nusing6    1000000
    local groups6    100
    local halfwidth6 1

    tempfile bench_results
    tempname posth
    postfile `posth' str16 scenario double n_master double n_using ///
        double groups double halfwidth double pairs double rangematch_sec ///
        double rangejoin_sec double rj_over_rm double rangematch_pps ///
        double rangejoin_pps int rangejoin_rc str12 status ///
        using "`bench_results'", replace

    forvalues i = 1/6 {
        local scenario  "`scenario`i''"
        local nmaster   `nmaster`i''
        local nusing    `nusing`i''
        local groups    `groups`i''
        local halfwidth `halfwidth`i''

        noisily display as text "Running `scenario'..."

        tempfile master using

        clear
        set obs `nusing'
        generate double group = mod(_n - 1, `groups') + 1
        bysort group: generate double key = _n
        generate double uid = _n
        save "`using'", replace

        clear
        set obs `nmaster'
        generate double id = _n
        generate double group = mod(_n - 1, `groups') + 1
        bysort group: generate double center = _n
        generate double lo = max(1, center - `halfwidth')
        generate double hi = center + `halfwidth'
        save "`master'", replace

        use "`master'", clear
        timer clear 1
        timer on 1
        rangematch key lo hi using "`using'", ///
            by(group) keepusing(uid key) unmatched(none) nosort
        timer off 1
        timer list 1
        local rm_seconds = r(t1)
        local rm_pairs = _N
        local rm_pps = `rm_pairs' / `rm_seconds'

        local rj_seconds = .
        local rj_pairs = .
        local rj_pps = .
        local rj_over_rm = .
        local rj_rc = 111
        local status "skipped"

        if `has_rangejoin' {
            use "`master'", clear
            timer clear 2
            timer on 2
            capture rangejoin key lo hi using "`using'", by(group)
            local rj_rc = _rc
            timer off 2
            timer list 2
            local rj_seconds = r(t2)
            local status "error"

            if `rj_rc' == 0 {
                local rj_pairs = _N
                local rj_pps = `rj_pairs' / `rj_seconds'
                local rj_over_rm = `rj_seconds' / `rm_seconds'
                local status "ok"
                if `rj_pairs' != `rm_pairs' {
                    local status "mismatch"
                }
            }
        }

        post `posth' ("`scenario'") (`nmaster') (`nusing') ///
            (`groups') (`halfwidth') (`rm_pairs') (`rm_seconds') ///
            (`rj_seconds') (`rj_over_rm') (`rm_pps') (`rj_pps') ///
            (`rj_rc') ("`status'")
    }

    postclose `posth'

    use "`bench_results'", clear
    format n_master n_using pairs rangematch_pps rangejoin_pps %12.0fc
    format rangematch_sec rangejoin_sec rj_over_rm %9.3f
}

list scenario pairs rangematch_sec rangejoin_sec rj_over_rm status, ///
    noobs abbreviate(16)

log close benchmark

**# Convert console logs to markdown via logdoc
local tools_root "`repo_root'"
capture confirm file "`tools_root'/logdoc/logdoc.ado"
if _rc {
    display as error "logdoc was not found at `tools_root'/logdoc"
    exit 601
}

capture ado uninstall logdoc
quietly net install logdoc, from("`tools_root'/logdoc") replace

logdoc using "`demo_dir'/workflow.log", ///
    output("`demo_dir'/workflow.md") ///
    format(md) replace quiet

logdoc using "`demo_dir'/benchmark.log", ///
    output("`demo_dir'/benchmark.md") ///
    format(md) replace quiet

}

**# Cleanup
* Runs on the success path and on every error path above. `local rc = _rc' must
* stay the first line: log close and sysdir set each consume a capture
* internally and would otherwise overwrite the original error with 0.
local rc = _rc
local cleanup_rc = 0
capture log close _all
* Do not uninstall in the cleanup zone: once PLUS is restored, an uninstall
* would remove the caller's real installation. The temporary trees are throwaway.
if `personal_changed' {
    capture sysdir set PERSONAL "`old_personal'"
    if _rc & !`cleanup_rc' local cleanup_rc = _rc
}
if `plus_changed' {
    capture sysdir set PLUS "`old_plus'"
    if _rc & !`cleanup_rc' local cleanup_rc = _rc
}
clear
if !`rc' & `cleanup_rc' local rc = `cleanup_rc'
if `rc' {
    display as error "demo_rangematch.do failed with rc=`rc'"
    exit `rc'
}
