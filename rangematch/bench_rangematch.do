*! bench_rangematch.do  12may2026
*! Benchmark rangematch against SSC rangejoin on synthetic range joins

version 16.1
clear all

local orig_more "`c(more)'"
local orig_varabbrev "`c(varabbrev)'"
local orig_rngstate = c(rngstate)
set more off
set varabbrev off
set seed 20260511

local source_path ""
local path_added = 0
local post_open = 0

* The benchmark changes session settings and may add a source directory to the
* adopath. Keep the entire operation inside one failure boundary so every exit
* reaches the cleanup zone and the original rc survives cleanup commands.
capture noisily {
    local cwd "`c(pwd)'"
    capture confirm file "`cwd'/rangematch.ado"
    if _rc == 0 local source_path "`cwd'"
    else {
        capture confirm file "`cwd'/rangematch/rangematch.ado"
        if _rc == 0 local source_path "`cwd'/rangematch"
    }
    if "`source_path'" != "" {
        adopath ++ "`source_path'"
        local path_added = 1
    }

    capture which rangematch
    if _rc {
        display as error "rangematch is not installed or on the adopath"
        display as error "Install rangematch, or run this file from the rangematch package directory."
        error 111
    }

    capture which rangejoin
    local has_rangejoin = (_rc == 0)
    if !`has_rangejoin' {
        display as text "rangejoin is not installed; rangejoin benchmark rows will be marked skipped."
    }

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
    postfile `posth' str12 command str16 scenario long n_master long n_using ///
        int groups int halfwidth double expected_pairs double seconds ///
        double pairs int rc str12 status using "`bench_results'", replace
    local post_open = 1

    forvalues i = 1/6 {
        local scenario  "`scenario`i''"
        local nmaster   `nmaster`i''
        local nusing    `nusing`i''
        local groups    `groups`i''
        local halfwidth `halfwidth`i''

        * Each group contains points 1..n and one master interval centered at
        * each point. The untruncated total n*(2h+1) loses h(h+1)/2 pairs at
        * each boundary, hence n*(2h+1)-h(h+1) per group. This is an analytic
        * oracle independent of either matching implementation.
        if mod(`nmaster', `groups') | mod(`nusing', `groups') {
            display as error "scenario `scenario' is not divisible into equal groups"
            error 459
        }
        local n_per_master = `nmaster' / `groups'
        local n_per_using = `nusing' / `groups'
        if `n_per_master' != `n_per_using' | `halfwidth' >= `n_per_using' {
            display as error "scenario `scenario' violates the benchmark oracle assumptions"
            error 459
        }
        local expected = `groups' * ///
            (`n_per_using' * (2 * `halfwidth' + 1) - `halfwidth' * (`halfwidth' + 1))

        display as text _newline "Scenario: `scenario' " ///
            "(master=`nmaster', using=`nusing', groups=`groups', halfwidth=`halfwidth', expected=`expected')"

        tempfile master using

        clear
        quietly set obs `nusing'
        generate int group = mod(_n - 1, `groups') + 1
        bysort group: generate long key = _n
        generate long uid = _n
        quietly save "`using'", replace

        clear
        quietly set obs `nmaster'
        generate long id = _n
        generate int group = mod(_n - 1, `groups') + 1
        bysort group: generate long center = _n
        generate long lo = max(1, center - `halfwidth')
        generate long hi = center + `halfwidth'
        quietly save "`master'", replace

        use "`master'", clear
        timer clear 1
        timer on 1
        capture noisily rangematch key lo hi using "`using'", ///
            by(group) keepusing(uid key) unmatched(none) nosort
        local rm_rc = _rc
        timer off 1
        quietly timer list 1
        local rm_seconds = r(t1)
        local rm_pairs = .
        local rm_status "error"
        if `rm_rc' == 0 {
            local rm_pairs = _N
            local rm_status "ok"
            if `rm_pairs' != `expected' local rm_status "wrong_count"
        }
        post `posth' ("rangematch") ("`scenario'") (`nmaster') (`nusing') ///
            (`groups') (`halfwidth') (`expected') (`rm_seconds') (`rm_pairs') ///
            (`rm_rc') ("`rm_status'")

        if `has_rangejoin' {
            use "`master'", clear
            timer clear 1
            timer on 1
            capture noisily rangejoin key lo hi using "`using'", by(group)
            local rj_rc = _rc
            timer off 1
            quietly timer list 1
            local rj_seconds = r(t1)
            local rj_pairs = .
            local rj_status "error"
            if `rj_rc' == 0 {
                local rj_pairs = _N
                local rj_status "ok"
                if `rj_pairs' != `expected' | `rj_pairs' != `rm_pairs' {
                    local rj_status "wrong_count"
                }
            }
            post `posth' ("rangejoin") ("`scenario'") (`nmaster') (`nusing') ///
                (`groups') (`halfwidth') (`expected') (`rj_seconds') (`rj_pairs') ///
                (`rj_rc') ("`rj_status'")
        }
        else {
            post `posth' ("rangejoin") ("`scenario'") (`nmaster') (`nusing') ///
                (`groups') (`halfwidth') (`expected') (.) (.) (111) ("skipped")
        }
    }

    postclose `posth'
    local post_open = 0

    use "`bench_results'", clear
    generate double pairs_per_second = pairs / seconds if seconds > 0 & status == "ok"
    format seconds %9.3f
    format expected_pairs pairs pairs_per_second %12.0fc

    display as text _newline "Benchmark results"
    list command scenario n_master n_using groups halfwidth expected_pairs ///
        status seconds pairs pairs_per_second rc, noobs abbreviate(16)

    quietly count if command == "rangematch"
    local n_rm = r(N)
    quietly count if command == "rangematch" & status == "error"
    local n_error = r(N)
    quietly count if command == "rangematch" & status == "wrong_count"
    local n_mismatch = r(N)
    quietly count if command == "rangejoin" & inlist(status, "error", "wrong_count")
    local n_bad_comparator = r(N)
    local n_bad = `n_error' + `n_mismatch'
    local n_ok = `n_rm' - `n_bad'

    if `n_rm' != 6 {
        display as error "bench_rangematch.do: expected 6 rangematch scenarios; found `n_rm'"
        error 9
    }

    display "RESULT: bench_rangematch scenarios=`n_rm' ok=`n_ok' error=`n_error' mismatch=`n_mismatch' comparator_error=`n_bad_comparator'"

    if `n_bad' > 0 | `n_bad_comparator' > 0 {
        display as error "bench_rangematch.do: invalid benchmark rows (rangematch=`n_bad', comparator=`n_bad_comparator')"
        display as error "every successful row must equal the analytic pair count; installed comparators must also agree"
        error 9
    }

    display as result _newline "bench_rangematch.do complete"
}
local rc = _rc

local cleanup_rc = 0
if `post_open' {
    capture postclose `posth'
    if _rc & !`cleanup_rc' local cleanup_rc = _rc
}
if `path_added' {
    capture adopath - "`source_path'"
    if _rc & !`cleanup_rc' local cleanup_rc = _rc
}
capture set more `orig_more'
if _rc & !`cleanup_rc' local cleanup_rc = _rc
capture set varabbrev `orig_varabbrev'
if _rc & !`cleanup_rc' local cleanup_rc = _rc
capture set rngstate `orig_rngstate'
if _rc & !`cleanup_rc' local cleanup_rc = _rc

if !`rc' & `cleanup_rc' local rc = `cleanup_rc'
if `rc' exit `rc'
