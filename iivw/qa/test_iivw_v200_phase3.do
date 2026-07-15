* test_iivw_v200_phase3.do
* Phase 3: output, export, and contract hardening.
*
*   P1  H11  missing cvcut()/balcut()/essratiocut() rejected, not inverted
*   P2  H11  missing true() rejected by iivw_diagnose
*   P3  H12  export-only options without xlsx() error instead of silently no-op
*   P4  H12  iivw_exogtest replace WITHOUT xlsx() is still legal (dual purpose)
*   P5  H9   a failed export keeps the analytical r() surface (all 3 commands)
*   P6  H9   a failed exogtest export does NOT roll back the generated lag vars
*   P7  H10  Excel sheet lookup is case-insensitive, like Excel itself
*   P8  H16  edited/dropped/permuted weighted data is refused; a re-sort is not
*   P9  H18  a time-varying treat_cov() is refused; a baseline one is accepted
*   P10 H15  weighted model(mixed) requires experimentalmixed
*   P11 C10  the README Quick Start runs verbatim
*
* Every one of these was rc 0 and wrong before Phase 3. The H11 cases are the
* sharpest: `cvcut(.)' classified a CV of 0.64 as "low" and `balcut(.)' called
* any imbalance "good", because every finite number is less than missing.

clear all
set varabbrev off
version 16.0

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v200_phase3.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
* local Stata license header, and the release hygiene gate had been taught to
* whitelist exactly these files. The batch invocation
* (`stata-mp -b do <suite>.do') already produces a readable log in the cwd, and
* run_all.log captures everything when the suite runs under the runner, so the
* named log was pure redundancy.
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local pkg_dir "`c(pwd)'/.."
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

**# Helpers

capture program drop _p3_data
program define _p3_data
    syntax , [n(integer 300) seed(integer 90210)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double z = rnormal()
    gen byte trt = runiform() < invlogit(0.4 * z)
    gen double cens = 5 + 5 * runiform()
    expand 30
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / (0.6 * exp(0.5 * z))
    bysort id (j): gen double time = sum(gap)
    keep if time < cens
    drop gap j
    gen double y = 1 + 0.5 * z + 0.3 * trt + rnormal()
    * A genuinely time-varying covariate, for the treat_cov() contract.
    gen double tvz = z + 0.1 * time
end

capture program drop _p3_weighted
program define _p3_weighted
    syntax , [n(integer 300) seed(integer 90210)]
    _p3_data, n(`n') seed(`seed')
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
end

**# P1  H11: a missing threshold must be rejected, not silently inverted

local ++test_count
local p1_ok = 1
_p3_weighted
foreach spec in "cvcut(.)" "cvcut(.a)" "balcut(.)" "balcut(.z)" ///
    "essratiocut(.)" "essratiocut(.a)" {
    capture iivw_balance, `spec'
    if _rc != 198 {
        local p1_ok = 0
        display "  P1: iivw_balance, `spec' gave rc " _rc ", expected 198"
    }
}
* And the finite thresholds must still work.
capture iivw_balance, cvcut(0.10) balcut(0.10) essratiocut(0.95)
if _rc != 0 {
    local p1_ok = 0
    display "  P1: finite thresholds rejected, rc " _rc
}
if `p1_ok' {
    local ++pass_count
    display "PASS P1: missing thresholds rejected; finite thresholds still accepted"
}
else {
    local ++fail_count
    display "FAIL P1: a missing threshold was accepted (it would invert every comparison)"
}

**# P2  H11: iivw_diagnose true() may not be missing

local ++test_count
_p3_weighted
quietly regress y z
estimates store p2_unw
quietly regress y z [pw=_iivw_iw]
estimates store p2_wtd
quietly regress y z cens
estimates store p2_adj

local p2_ok = 1
foreach v in "." ".a" {
    capture iivw_diagnose z, unweighted(p2_unw) weighted(p2_wtd) ///
        adjusted(p2_adj) force true(`v')
    if _rc != 198 {
        local p2_ok = 0
        display "  P2: true(`v') gave rc " _rc ", expected 198"
    }
}
capture iivw_diagnose z, unweighted(p2_unw) weighted(p2_wtd) ///
    adjusted(p2_adj) force true(0.5)
if _rc != 0 {
    local p2_ok = 0
    display "  P2: a finite true() was rejected, rc " _rc
}
if `p2_ok' {
    local ++pass_count
    display "PASS P2: iivw_diagnose rejects a missing true()"
}
else {
    local ++fail_count
    display "FAIL P2: a missing true() propagates into every reported bias as ."
}

**# P3  H12: export-only options without xlsx() must error, not no-op

local ++test_count
local p3_ok = 1
_p3_weighted
foreach spec in "sheet(X)" "open" "replace" "title(T)" "footnote(F)" ///
    "decimals(2)" "zebra" "headershade" "theme(blue)" {
    capture iivw_balance, `spec'
    if _rc != 198 {
        local p3_ok = 0
        display "  P3: iivw_balance, `spec' gave rc " _rc ", expected 198"
    }
}
foreach spec in "sheet(X)" "zebra" "decimals(2)" "replace" {
    capture iivw_diagnose z, unweighted(p2_unw) weighted(p2_wtd) ///
        adjusted(p2_adj) force `spec'
    if _rc != 198 {
        local p3_ok = 0
        display "  P3: iivw_diagnose, `spec' gave rc " _rc ", expected 198"
    }
}
foreach spec in "sheet(X)" "zebra" "title(T)" {
    capture iivw_exogtest z, id(id) time(time) censor(cens) `spec'
    if _rc != 198 {
        local p3_ok = 0
        display "  P3: iivw_exogtest, `spec' gave rc " _rc ", expected 198"
    }
}
if `p3_ok' {
    local ++pass_count
    display "PASS P3: export-only options require xlsx()"
}
else {
    local ++fail_count
    display "FAIL P3: an export-only option was accepted and silently ignored"
}

**# P4  H12: exogtest replace is dual-purpose and IS legal without xlsx()

local ++test_count
_p3_weighted
capture drop _iivw_exog_*
quietly iivw_exogtest z, id(id) time(time) censor(cens)
capture iivw_exogtest z, id(id) time(time) censor(cens) replace
local p4_rc = _rc
if `p4_rc' == 0 {
    local ++pass_count
    display "PASS P4: iivw_exogtest replace without xlsx() overwrites the lag variables"
}
else {
    local ++fail_count
    display "FAIL P4: replace without xlsx() rejected (rc `p4_rc'); it also means"
    display "  'overwrite the generated lag variables' and must stay legal"
}

**# P5  H9: a failed export must not discard the analytical payload

local ++test_count
local p5_ok = 1
local badpath "/nonexistent_dir_xyz/out.xlsx"

* FALSE-GREEN GUARD. r() persists across commands: if the failing call posted
* nothing at all, r() would still hold whatever the LAST rclass command left --
* and _p3_weighted runs iivw_weight, which sets r(N). Flushing r() with a
* neutral rclass command first means every value asserted below can only have
* come from the command under test.
_p3_weighted
quietly summarize y
capture iivw_balance, xlsx("`badpath'")
local p5_brc = _rc
local p5_bflag "`r(balance_flag)'"
local p5_btsmd = r(balance_max_tsmd)
local p5_bN = r(N)
if `p5_brc' == 0 {
    local p5_ok = 0
    display "  P5: iivw_balance export to a bad path returned rc 0"
}
if missing(`p5_btsmd') | missing(`p5_bN') | "`p5_bflag'" == "" {
    local p5_ok = 0
    display "  P5: iivw_balance r() was discarded by the failed export"
}

quietly summarize y
capture iivw_diagnose z, unweighted(p2_unw) weighted(p2_wtd) adjusted(p2_adj) ///
    force xlsx("`badpath'")
local p5_drc = _rc
local p5_dconc "`r(conclusion)'"
capture confirm matrix r(decomp)
local p5_ddec = _rc
if `p5_drc' == 0 | "`p5_dconc'" == "" | `p5_ddec' != 0 {
    local p5_ok = 0
    display "  P5: iivw_diagnose lost r() on a failed export (rc `p5_drc')"
}

capture drop _iivw_exog_*
quietly summarize y
capture iivw_exogtest z, id(id) time(time) censor(cens) xlsx("`badpath'")
local p5_erc = _rc
local p5_entests = r(n_tests)
if `p5_erc' == 0 | missing(`p5_entests') {
    local p5_ok = 0
    display "  P5: iivw_exogtest lost r() on a failed export (rc `p5_erc')"
}

if `p5_ok' {
    local ++pass_count
    display "PASS P5: all three commands raise the export rc AND keep r()"
}
else {
    local ++fail_count
    display "FAIL P5: a failed optional export discarded results that were already computed"
}

**# P6  H9: a failed exogtest export must NOT roll back the lag variables

local ++test_count
_p3_weighted
capture drop _iivw_exog_*
capture iivw_exogtest z, id(id) time(time) censor(cens) xlsx("`badpath'")
local p6_lags "`r(lagvars)'"
local p6_ok = 1
if "`p6_lags'" == "" local p6_ok = 0
foreach v of local p6_lags {
    capture confirm variable `v'
    if _rc {
        local p6_ok = 0
        display "  P6: lag variable `v' was deleted by the failed export"
    }
}
if `p6_ok' {
    local ++pass_count
    display "PASS P6: the generated lag variables survive a failed export"
}
else {
    local ++fail_count
    display "FAIL P6: a bad xlsx() path drove the name-transaction rollback and"
    display "  deleted lag variables the command had successfully created"
}

**# P7  H10: Excel sheet names are case-insensitive

local ++test_count
_p3_weighted
tempfile p7f
local p7x "`p7f'.xlsx"
local p7_ok = 1

capture iivw_balance, xlsx("`p7x'") sheet("Balance")
if _rc != 0 {
    local p7_ok = 0
    display "  P7: first write failed, rc " _rc
}
* "balance" and "Balance" are the SAME sheet to Excel. Without replace this must
* take the soft rc-602 path (warn, keep r()), never try to add a duplicate.
capture iivw_balance, xlsx("`p7x'") sheet("balance")
if _rc != 0 {
    local p7_ok = 0
    display "  P7: case-only re-write without replace gave rc " _rc ", expected the 602 warning path (rc 0)"
}
capture iivw_balance, xlsx("`p7x'") sheet("balance") replace
if _rc != 0 {
    local p7_ok = 0
    display "  P7: case-only re-write WITH replace gave rc " _rc ", expected 0"
}
if `p7_ok' {
    local ++pass_count
    display "PASS P7: a case-only sheet difference resolves to the same worksheet"
}
else {
    local ++fail_count
    display "FAIL P7: exact-case sheet lookup; writing Balance then balance died rc 16114"
}

**# P8  H16: the weights must still describe the data

local ++test_count
local p8_ok = 1

* A harmless re-sort must NOT trip the guard.
_p3_weighted
gsort -time
capture iivw_fit y z, vce(fixed) model(gee)
if _rc != 0 {
    local p8_ok = 0
    display "  P8: a re-sort was rejected, rc " _rc " -- the signature is not sort-invariant"
}

* Each of these is a real change and must be refused with 459.
_p3_weighted
drop in 1/50
capture iivw_fit y z, vce(fixed) model(gee)
if _rc != 459 {
    local p8_ok = 0
    display "  P8: dropped rows accepted, rc " _rc
}

_p3_weighted
quietly replace _iivw_weight = _iivw_weight * 2 in 7
capture iivw_fit y z, vce(fixed) model(gee)
if _rc != 459 {
    local p8_ok = 0
    display "  P8: an edited weight accepted, rc " _rc
}

_p3_weighted
quietly replace z = z + 1 in 11
capture iivw_fit y z, vce(fixed) model(gee)
if _rc != 459 {
    local p8_ok = 0
    display "  P8: an edited visit covariate accepted, rc " _rc
}

* Reversing the weight column preserves sum(w) and sum(w^2). Only the cross
* terms sum(w*t)/sum(w*k) catch it -- this is why they are in the signature.
_p3_weighted
quietly replace _iivw_weight = _iivw_weight[_N - _n + 1]
capture iivw_fit y z, vce(fixed) model(gee)
if _rc != 459 {
    local p8_ok = 0
    display "  P8: a PERMUTED weight column accepted, rc " _rc
}

* iivw_balance must be guarded too, not just iivw_fit.
_p3_weighted
quietly replace _iivw_weight = 1 in 5
capture iivw_balance
if _rc != 459 {
    local p8_ok = 0
    display "  P8: iivw_balance accepted stale weights, rc " _rc
}

if `p8_ok' {
    local ++pass_count
    display "PASS P8: stale/edited weighted data refused; a re-sort still passes"
}
else {
    local ++fail_count
    display "FAIL P8: the stored weights no longer describe the data and nothing noticed"
}

**# P9  H18: treat_cov() must be a baseline characteristic

local ++test_count
local p9_ok = 1

_p3_data
capture iivw_weight, id(id) time(time) visit(z) censor(cens) ///
    wtype(fiptiw) treat(trt) treat_cov(tvz)
if _rc != 459 {
    local p9_ok = 0
    display "  P9: a time-varying treat_cov() was accepted, rc " _rc
}

_p3_data
capture iivw_weight, id(id) time(time) visit(z) censor(cens) ///
    wtype(fiptiw) treat(trt) treat_cov(z)
if _rc != 0 {
    local p9_ok = 0
    display "  P9: a subject-constant treat_cov() was rejected, rc " _rc
}

* An explicitly constructed baseline value must be accepted.
_p3_data
bysort id (time): gen double base_tvz = tvz[1]
capture iivw_weight, id(id) time(time) visit(z) censor(cens) ///
    wtype(fiptiw) treat(trt) treat_cov(base_tvz)
if _rc != 0 {
    local p9_ok = 0
    display "  P9: an explicit baseline covariate was rejected, rc " _rc
}

* A baseline covariate recorded ONLY at baseline (missing at later visits) is a
* normal registry layout. An sd()-based guard rejects it; min/max must not.
_p3_data
gen double z_base = z
bysort id (time): replace z_base = . if _n > 1
capture iivw_weight, id(id) time(time) visit(z) censor(cens) ///
    wtype(fiptiw) treat(trt) treat_cov(z_base)
if _rc != 0 {
    local p9_ok = 0
    display "  P9: a baseline-only-recorded covariate was rejected, rc " _rc
}

if `p9_ok' {
    local ++pass_count
    display "PASS P9: time-varying treat_cov() refused; baseline forms accepted"
}
else {
    local ++fail_count
    display "FAIL P9: treat_cov() silently became 'whatever sat on the earliest row'"
}

**# P10  H15: a weighted mixed model requires the acknowledgment

local ++test_count
local p10_ok = 1
_p3_weighted

capture iivw_fit y z, vce(fixed) model(mixed)
if _rc != 198 {
    local p10_ok = 0
    display "  P10: weighted model(mixed) ran without experimentalmixed, rc " _rc
}
capture iivw_fit y z, vce(fixed) model(mixed) experimentalmixed
if _rc != 0 {
    local p10_ok = 0
    display "  P10: experimentalmixed did not permit the fit, rc " _rc
}
* Unweighted mixed carries no such caveat and must not require the option.
capture iivw_fit y z, model(mixed) unweighted
if _rc != 0 {
    local p10_ok = 0
    display "  P10: UNweighted model(mixed) was gated, rc " _rc
}
capture iivw_fit y z, vce(fixed) model(gee)
if _rc != 0 {
    local p10_ok = 0
    display "  P10: model(gee) was gated, rc " _rc
}

if `p10_ok' {
    local ++pass_count
    display "PASS P10: weighted mixed gated behind experimentalmixed; gee/unweighted free"
}
else {
    local ++fail_count
    display "FAIL P10: the weighted-mixed caveat is still only a note"
}

**# P11  C10: the README Quick Start must run exactly as printed

local ++test_count

* Read the Quick Start out of the SHIPPED README and run that. Retyping it here
* would only test this file's copy: the README could say anything -- including
* the removed `nobaseevent', which is what it actually said -- and the test
* would still pass. The oracle has to be the file the user reads.
tempfile p11_do
local p11_lines = 0

* The README must NEVER pass through a Stata macro. A backtick opens a macro
* reference, and markdown is full of them -- both the ``` fences and every
* inline `code` span. `file read' into a local and then substr() on it dies
* r(132) "too few quotes" on README line 5, before it ever reaches the Quick
* Start. Read the file into a VARIABLE and do all the string work there: a
* string variable's contents are data and are never macro-expanded.
*
* char(96) is the backtick. It is written that way here for the same reason.
import delimited using "`pkg_dir'/README.md", delimiter(tab) ///
    varnames(nonames) stringcols(_all) clear

capture confirm variable v2
if _rc == 0 {
    display "  P11: a tab in README.md split a line; extraction is unreliable"
}

quietly count
local p11_total = r(N)
gen long _ord = _n
* Built with char(96) inside the expression. Putting the fence in a macro and
* then expanding it into a quoted literal would re-inject the backticks into
* the source and fail exactly as before.
gen byte _fence = substr(v1, 1, 3) == char(96) + char(96) + char(96)
gen byte _open  = _fence & substr(v1, 4, 5) == "stata"
gen byte _qs    = strpos(v1, "## Quick Start") == 1

quietly summarize _ord if _qs, meanonly
local p11_qs_at = r(min)
quietly summarize _ord if _open & _ord > `p11_qs_at', meanonly
local p11_open_at = r(min)
quietly summarize _ord if _fence & _ord > `p11_open_at', meanonly
local p11_close_at = r(min)

if !missing(`p11_qs_at') & !missing(`p11_open_at') & !missing(`p11_close_at') {
    quietly keep if _ord > `p11_open_at' & _ord < `p11_close_at'
    quietly count
    local p11_lines = r(N)
    export delimited v1 using "`p11_do'", delimiter(tab) novarnames replace
}

clear
capture noisily do "`p11_do'"
local p11_rc = _rc

if `p11_lines' < 5 {
    local ++fail_count
    display "FAIL P11: extracted only `p11_lines' lines from the README Quick Start;"
    display "  the block was not found, so this test proved nothing"
}
else if `p11_rc' == 0 {
    local ++pass_count
    display "PASS P11: the README Quick Start (`p11_lines' lines, read from the file) runs verbatim"
}
else {
    local ++fail_count
    display "FAIL P11: the shipped Quick Start errors (rc `p11_rc') for an installed user"
}

**# Summary

display ""
display "test_iivw_v200_phase3: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_iivw_v200_phase3 tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture log close
if `fail_count' > 0 exit 1
