*! bench_rangematch.do  12may2026
*! Benchmark rangematch against SSC rangejoin on synthetic range joins

version 17.0
clear all
set more off
set varabbrev off
set seed 20260511

local cwd "`c(pwd)'"
capture confirm file "`cwd'/rangematch.ado"
if _rc == 0 {
    adopath ++ "`cwd'"
}
else {
    capture confirm file "`cwd'/rangematch/rangematch.ado"
    if _rc == 0 {
        adopath ++ "`cwd'/rangematch"
    }
}

capture which rangematch
if _rc {
    display as error "rangematch is not installed or on the adopath"
    display as error "Install rangematch, or run this file from the rangematch package directory."
    exit 111
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
    int groups int halfwidth double seconds double pairs int rc str12 status ///
    using "`bench_results'", replace

forvalues i = 1/6 {
    local scenario  "`scenario`i''"
    local nmaster   `nmaster`i''
    local nusing    `nusing`i''
    local groups    `groups`i''
    local halfwidth `halfwidth`i''

    display as text _newline "Scenario: `scenario' " ///
        "(master=`nmaster', using=`nusing', groups=`groups', halfwidth=`halfwidth')"

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
    local rc = _rc
    timer off 1
    quietly timer list 1
    local seconds = r(t1)
    local pairs = .
    local status "error"
    if `rc' == 0 {
        local pairs = _N
        local status "ok"
    }
    post `posth' ("rangematch") ("`scenario'") (`nmaster') (`nusing') ///
        (`groups') (`halfwidth') (`seconds') (`pairs') (`rc') ("`status'")

    if `has_rangejoin' {
        use "`master'", clear
        timer clear 1
        timer on 1
        capture noisily rangejoin key lo hi using "`using'", by(group)
        local rc = _rc
        timer off 1
        quietly timer list 1
        local seconds = r(t1)
        local pairs = .
        local status "error"
        if `rc' == 0 {
            local pairs = _N
            local status "ok"
        }
        post `posth' ("rangejoin") ("`scenario'") (`nmaster') (`nusing') ///
            (`groups') (`halfwidth') (`seconds') (`pairs') (`rc') ("`status'")
    }
    else {
        post `posth' ("rangejoin") ("`scenario'") (`nmaster') (`nusing') ///
            (`groups') (`halfwidth') (.) (.) (111) ("skipped")
    }
}

postclose `posth'

use "`bench_results'", clear
generate double pairs_per_second = pairs / seconds if seconds > 0 & status == "ok"
format seconds %9.3f
format pairs pairs_per_second %12.0fc

display as text _newline "Benchmark results"
list command scenario n_master n_using groups halfwidth status seconds pairs ///
    pairs_per_second rc, noobs abbreviate(16)

display as result _newline "bench_rangematch.do complete"
