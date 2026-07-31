*! test_tvbuild_regressions_1_10_2.do
*! Pins for the four tvbuild defects fixed at 1.10.2, plus the cleanup contract
*! the varabbrev change touches.
*!
*! Measured against a pristine 1.10.1 tree before the fixes landed:
*! 18 tests, 12 pass, 6 FAIL. The six that fail are the defect pins --
*!
*!   V1  expected 198, got 111   the characteristic was read as a variable
*!   E1  expected 0,   got 109   ev_note was nominated by the glob
*!   Q1  manifest [rate( tv_dose)] vs r(rate_vars) [tv_dose]
*!   Q2  expected [rate(tv_dose)], got [rate( tv_dose)]
*!   N1  expected 198, got 103   it reached the internal startvar() option
*!   N2  expected 198, got 103
*!
*! -- and the other twelve are guards, which is a different job: they hold the
*! paths a fix could plausibly break on its way past the defect. Do not read
*! the whole file as regression pins.
*!
*! Two of the guards were expected to fail on 1.10.1 and did not, which is
*! worth recording because it changes what the E block means. E3 (a stub with
*! a hole) and E4 (a non-canonical ev02) both exited correctly on 1.10.1 --
*! not because the preflight caught them, but because the greedy glob let them
*! through to tvevent, whose own resolution then rejected them. So 1.10.1's
*! preflight was BOTH over-rejecting (E1) and under-checking (E3, E4), and the
*! observable rc only exposed the first. The fix makes the preflight agree with
*! the engine on all three; E3/E4 now pin that agreement rather than tvevent's
*! backstop. V2 likewise already exited 198 on 1.10.1, from a malformed `if'
*! expression rather than from the version guard -- same rc, different reason,
*! which is why V1 and not V2 is the pin for that defect.
*!
*! What each block is written against, and the false green it exists to deny:
*!
*!   V1-V5  specification-version characteristic. The 1.10.1 guard read
*!          `if _rc == 0 & `_v' == 1', and Stata's `&' does not short-circuit,
*!          so a non-numeric characteristic was resolved as a VARIABLE NAME.
*!          The false green: testing only with numeric versions (2, 99) never
*!          reaches the broken branch -- every such value confirms cleanly and
*!          the comparison is legal. The input that breaks it is non-numeric,
*!          so V1/V2 supply exactly that, and V3-V5 hold the numeric path.
*!
*!   E1-E5  recurring event stub. 1.10.1 resolved it with a bare
*!          `ds `eventdate'*', which nominates every variable sharing the
*!          prefix. The false green: a fixture whose master holds ONLY the
*!          stub members passes on both versions, because the glob and the
*!          correct rule agree when nothing else shares the prefix. E1 puts a
*!          companion column in the master, which is the only shape that
*!          separates them.
*!
*!   Q1-Q2  provenance/return agreement. r(rate_vars) was trimmed at the
*!          return surface AFTER the manifest was built from the untrimmed
*!          local, so the two disagreed by one space. The false green:
*!          asserting either copy alone passes on 1.10.1. Q1 asserts they are
*!          EQUAL to each other and Q2 pins the literal.
*!
*!   N1-N2  start_var/stop_var arity, reported at the specification row.
*!
*!   S1-S3  varabbrev is restored to the CALLER's entry value on the success
*!          path, the failure path, and when the caller had it on. The bare
*!          restore replaced a `capture'd one; if it ever fails to run, these
*!          are what notice.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvbuild_regressions_1_10_2.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVR_PASS = 0
global TVR_FAIL = 0
global TVR_FAILED ""
local test_count = 0

display as result "tvtools QA: tvbuild 1.10.2 regressions -- $S_DATE $S_TIME"

capture program drop _tvr_check
program define _tvr_check
    args ok label detail
    if `ok' {
        global TVR_PASS = $TVR_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVR_FAIL = $TVR_FAIL + 1
        global TVR_FAILED "$TVR_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

**# ---------------------------------------------------------------------
**# Fixtures. Built at top level: an `input' block inside `program define'
**# would end the program at its own `end'.
**# ---------------------------------------------------------------------
clear
input long pid double study_entry double study_exit
    1 100 500
    2 120 480
    3  90 500
end
save "tr_cohort.dta", replace

* Episode source: one non-reference episode per person, inside the window.
clear
input long pid double ep_start double ep_stop byte ep_class
    1 200 300 1
    2 200 300 1
    3 200 300 1
end
save "tr_epi.dta", replace

* Ready interval source carrying a rate quantity, tiling each window exactly.
clear
input long pid double start double stop double dose
    1 100 500 5
    2 120 480 5
    3  90 500 5
end
char dose[tvtools_quantity] rate
save "tr_lab.dta", replace

capture program drop _tvr_spec1
program define _tvr_spec1
    * One episodes row, file locator. Rebuilt per test so a characteristic set
    * by one block cannot leak into the next.
    capture frame drop trspec
    frame create trspec
    frame trspec {
        quietly set obs 1
        quietly generate str32 source_name  = "drug"
        quietly generate str12 source_kind  = "episodes"
        quietly generate str32 source_frame = ""
        quietly generate strL  source_file  = "tr_epi.dta"
        quietly generate str32 start_var    = "ep_start"
        quietly generate str32 stop_var     = "ep_stop"
        quietly generate strL  input_vars   = "ep_class"
        quietly generate strL  output_vars  = "tv_drug"
        quietly generate double reference   = 0
    }
end

local BASE "id(pid) entry(study_entry) exit(study_exit) frameout(trout) replace"

**# ---------------------------------------------------------------------
**# V: specification-version characteristic
**#
**# 1.10.1 observed: V1 exits 111 ("two not found"), V2 exits 198 from a
**# malformed `if' expression rather than from the version guard. Both were
**# supposed to be the r(198) message asserted here.
**# ---------------------------------------------------------------------
capture program drop _tvr_version
program define _tvr_version, rclass
    version 16.0
    args value
    _tvr_spec1
    frame trspec: char _dta[tvbuild_spec_version] `"`value'"'
    quietly use "tr_cohort.dta", clear
    capture tvbuild, specframe(trspec) id(pid) entry(study_entry) ///
        exit(study_exit) frameout(trout) replace
    return scalar rc = _rc
end

local ++test_count
_tvr_version "two"
local rc = r(rc)
local ok = (`rc' == 198)
_tvr_check `ok' "V1 a non-numeric spec version is refused by the version guard" ///
    "expected 198, got `rc' (111 = the characteristic was read as a variable name)"

local ++test_count
_tvr_version "1 2"
local rc = r(rc)
local ok = (`rc' == 198)
_tvr_check `ok' "V2 a two-token spec version is refused by the version guard" ///
    "expected 198, got `rc'"

local ++test_count
_tvr_version "2"
local rc = r(rc)
local ok = (`rc' == 198)
_tvr_check `ok' "V3 an unsupported numeric spec version is still refused" "rc=`rc'"

local ++test_count
_tvr_version "1"
local rc = r(rc)
local ok = (`rc' == 0)
_tvr_check `ok' "V4 spec version 1 is accepted" "rc=`rc'"

* An absent characteristic means version 1. Asserted separately because V4
* sets it explicitly and would pass even if the absent case had regressed.
local ++test_count
_tvr_spec1
quietly use "tr_cohort.dta", clear
capture tvbuild, specframe(trspec) `BASE'
local rc = _rc
local ok = (`rc' == 0 & r(spec_version) == 1)
_tvr_check `ok' "V5 an absent spec-version characteristic means version 1" ///
    "rc=`rc' spec_version=`=r(spec_version)'"

**# ---------------------------------------------------------------------
**# E: recurring event stub resolution
**#
**# 1.10.1 observed: E1 exits 109 naming ev_note -- a variable the caller
**# never nominated -- because `ds ev*' matched it. tvevent, the engine this
**# stage delegates to, has always resolved the stub correctly; the preflight
**# was rejecting calls the engine would have accepted.
**# ---------------------------------------------------------------------
capture program drop _tvr_recurring
program define _tvr_recurring, rclass
    version 16.0
    args extra
    _tvr_spec1
    quietly use "tr_cohort.dta", clear
    quietly generate double ev1 = 250
    quietly generate double ev2 = 400
    if "`extra'" == "note"    quietly generate str8  ev_note = "x"
    if "`extra'" == "hole"    quietly rename ev2 ev3
    if "`extra'" == "pad"     quietly rename ev2 ev02
    if "`extra'" == "none"    quietly drop ev1 ev2
    capture tvbuild, specframe(trspec) id(pid) entry(study_entry) ///
        exit(study_exit) eventdate(ev) eventtype(recurring) ///
        eventgenerate(failed) frameout(trout) replace
    return scalar rc = _rc
end

local ++test_count
_tvr_recurring "note"
local rc = r(rc)
local ok = (`rc' == 0)
_tvr_check `ok' "E1 a companion column sharing the stub prefix is not an event date" ///
    "expected 0, got `rc' (109 = ev_note was nominated by the glob)"

local ++test_count
_tvr_recurring ""
local rc = r(rc)
local ok = (`rc' == 0)
_tvr_check `ok' "E2 a clean ev1/ev2 stub still resolves" "rc=`rc'"

local ++test_count
_tvr_recurring "hole"
local rc = r(rc)
local ok = (`rc' == 111)
_tvr_check `ok' "E3 a stub with a hole (ev1, ev3) is refused" "expected 111, got `rc'"

local ++test_count
_tvr_recurring "pad"
local rc = r(rc)
local ok = (`rc' == 198)
_tvr_check `ok' "E4 a non-canonical member (ev02) is refused, not guessed" ///
    "expected 198, got `rc'"

local ++test_count
_tvr_recurring "none"
local rc = r(rc)
local ok = (`rc' == 111)
_tvr_check `ok' "E5 no stub at all is refused" "expected 111, got `rc'"

**# ---------------------------------------------------------------------
**# Q: the provenance record and the return surface describe one list
**#
**# 1.10.1 observed: quantity_map == "rate( tv_dose)" while r(rate_vars) ==
**# "tv_dose". Q1 compares the two copies; Q2 pins the literal so a future
**# change that corrupts BOTH identically cannot pass Q1 alone.
**# ---------------------------------------------------------------------
capture frame drop trspec
frame create trspec
frame trspec {
    quietly set obs 2
    quietly generate str32 source_name  = ""
    quietly generate str12 source_kind  = ""
    quietly generate str32 source_frame = ""
    quietly generate strL  source_file  = ""
    quietly generate str32 start_var    = ""
    quietly generate str32 stop_var     = ""
    quietly generate strL  input_vars   = ""
    quietly generate strL  output_vars  = ""
    quietly generate double reference   = .
    quietly generate strL  rate_vars    = ""
    quietly replace source_name = "drug"      in 1
    quietly replace source_kind = "episodes"  in 1
    quietly replace source_file = "tr_epi.dta" in 1
    quietly replace start_var   = "ep_start"  in 1
    quietly replace stop_var    = "ep_stop"   in 1
    quietly replace input_vars  = "ep_class"  in 1
    quietly replace output_vars = "tv_drug"   in 1
    quietly replace reference   = 0           in 1
    quietly replace source_name = "lab"       in 2
    quietly replace source_kind = "intervals" in 2
    quietly replace source_file = "tr_lab.dta" in 2
    quietly replace start_var   = "start"     in 2
    quietly replace stop_var    = "stop"      in 2
    quietly replace input_vars  = "dose"      in 2
    quietly replace output_vars = "tv_dose"   in 2
    quietly replace rate_vars   = "dose"      in 2
}

quietly use "tr_cohort.dta", clear
capture noisily tvbuild, specframe(trspec) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(trout) manifestframe(trman) replace
local qrc = _rc
local r_rate "`r(rate_vars)'"
local r_payload "`r(payload_vars)'"
local r_names "`r(source_names)'"

local mmap ""
if `qrc' == 0 {
    frame trman {
        quietly levelsof quantity_map if stage == "merge", local(_m) clean
        local mmap `"`_m'"'
    }
}

local ++test_count
local ok = (`qrc' == 0 & `"`mmap'"' == `"rate(`r_rate')"')
_tvr_check `ok' "Q1 the manifest quantity_map and r(rate_vars) describe one list" ///
    `"rc=`qrc' manifest=[`mmap'] built from r(rate_vars)=[`r_rate']"'

local ++test_count
local ok = (`qrc' == 0 & `"`mmap'"' == "rate(tv_dose)")
_tvr_check `ok' "Q2 the manifest quantity_map carries no stray whitespace" ///
    `"expected [rate(tv_dose)], got [`mmap']"'

* The same accumulation bug affected every public name list, so the other
* three are pinned too rather than trusting that rate_vars was the only one.
local ++test_count
local ok = (`qrc' == 0 & "`r_payload'" == "tv_drug tv_dose" & "`r_names'" == "drug lab")
_tvr_check `ok' "Q3 r(payload_vars) and r(source_names) carry no leading space" ///
    "payload=[`r_payload'] names=[`r_names']"

**# ---------------------------------------------------------------------
**# N: interval bounds are single columns, reported at the specification row
**#
**# 1.10.1 observed: r(103) "option startvar(): too many names specified",
**# raised inside _tvbuild_load_source, naming neither the row nor the column.
**# ---------------------------------------------------------------------
capture program drop _tvr_arity
program define _tvr_arity, rclass
    version 16.0
    args col value
    _tvr_spec1
    frame trspec: quietly replace `col' = "`value'"
    quietly use "tr_cohort.dta", clear
    capture tvbuild, specframe(trspec) id(pid) entry(study_entry) ///
        exit(study_exit) frameout(trout) replace
    return scalar rc = _rc
end

local ++test_count
_tvr_arity start_var "ep_start pid"
local rc = r(rc)
local ok = (`rc' == 198)
_tvr_check `ok' "N1 a two-token start_var is refused at the specification row" ///
    "expected 198, got `rc' (103 = it reached the internal startvar() option)"

local ++test_count
_tvr_arity stop_var "ep_stop pid"
local rc = r(rc)
local ok = (`rc' == 198)
_tvr_check `ok' "N2 a two-token stop_var is refused at the specification row" ///
    "expected 198, got `rc'"

**# ---------------------------------------------------------------------
**# S: the caller's varabbrev survives, on both paths
**#
**# The restore stopped being `capture'd at 1.10.2. It cannot fail when the
**# value came from c(varabbrev), but that is an argument, not a test.
**# ---------------------------------------------------------------------
local ++test_count
set varabbrev off
_tvr_spec1
quietly use "tr_cohort.dta", clear
capture tvbuild, specframe(trspec) `BASE'
local rc = _rc
local ok = (`rc' == 0 & "`c(varabbrev)'" == "off")
_tvr_check `ok' "S1 varabbrev off is restored after a successful run" ///
    "rc=`rc' varabbrev=`c(varabbrev)'"

local ++test_count
set varabbrev on
_tvr_spec1
quietly use "tr_cohort.dta", clear
capture tvbuild, specframe(trspec) `BASE'
local rc = _rc
local ok = (`rc' == 0 & "`c(varabbrev)'" == "on")
_tvr_check `ok' "S2 varabbrev on is restored after a successful run" ///
    "rc=`rc' varabbrev=`c(varabbrev)'"

local ++test_count
set varabbrev on
_tvr_spec1
quietly use "tr_cohort.dta", clear
capture tvbuild, specframe(trspec) id(pid) entry(study_entry) ///
    exit(no_such_variable) frameout(trout) replace
local rc = _rc
local ok = (`rc' != 0 & "`c(varabbrev)'" == "on")
_tvr_check `ok' "S3 varabbrev on is restored after a failed run" ///
    "rc=`rc' varabbrev=`c(varabbrev)'"
set varabbrev off

**# Cleanup
capture frame drop trspec
capture frame drop trout
capture frame drop trman
foreach f in tr_cohort tr_epi tr_lab {
    capture erase "`f'.dta"
}

**# Summary
local pass_count = $TVR_PASS
local fail_count = $TVR_FAIL
if `fail_count' > 0 display as error "Failed:$TVR_FAILED"
display "RESULT: test_tvbuild_regressions_1_10_2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
