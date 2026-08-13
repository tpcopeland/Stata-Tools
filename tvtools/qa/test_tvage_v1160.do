*! test_tvage_v1160.do
*! Regression coverage for the tvtools 1.16.0 tvage person-time contract.
*! Author: Timothy P Copeland, Karolinska Institutet
*!
*! Both defects this suite pins were silent at rc=0 under a fully green lane:
*! tvage discarded person-time and said nothing about it on any channel. The
*! checks therefore live on the axes the rest of the tvage QA never probed --
*! conservation of person-days against an independently computed input total,
*! the rendered console text with no noisily option, and the arithmetic
*! relating r(n_persons_in), r(n_persons_dropped), and r(n_persons).

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_tvage_v1160.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global A16_TESTS = 0
global A16_PASS = 0
global A16_FAIL = 0
global A16_FAILED ""

capture program drop _a16_record
program define _a16_record
    args ok code detail
    global A16_TESTS = $A16_TESTS + 1
    if `ok' {
        global A16_PASS = $A16_PASS + 1
        display as result "  PASS: `code'"
    }
    else {
        global A16_FAIL = $A16_FAIL + 1
        global A16_FAILED "$A16_FAILED `code'"
        display as error "  FAIL: `code' (`detail')"
    }
end

* A batch log hard-wraps at c(linesize) and continues the line with "> ", at a
* column that depends on the message text. Searching the raw file for any
* phrase longer than the remaining width therefore fails for a reason that has
* nothing to do with the behaviour under test. Rejoin the continuations first.
capture program drop _a16_readlog
program define _a16_readlog, rclass
    args path
    local raw = fileread("`path'")
    local nl = char(10)
    local cr = char(13)
    local flat = subinstr(`"`raw'"', "`cr'", "", .)
    local flat = subinstr(`"`flat'"', "`nl'> ", "", .)
    return local content `"`flat'"'
end

* Person-days over closed [start, stop] daily intervals. Computed here rather
* than read from any tvtools return, so the oracle cannot inherit the code's
* own interval arithmetic.
capture program drop _a16_persondays
program define _a16_persondays, rclass
    args startvar stopvar
    tempvar pd
    quietly generate double `pd' = `stopvar' - `startvar' + 1
    quietly summarize `pd', meanonly
    return scalar total = r(sum)
end

* A cohort of `n' persons followed for one whole calendar year. `nbad' of them
* receive the dob supplied in `baddob'; the rest are born 01jan1980.
capture program drop _a16_cohort
program define _a16_cohort
    args n nbad baddob
    clear
    quietly set obs `n'
    quietly generate long id = _n
    quietly generate long dob = mdy(1, 1, 1980)
    if `nbad' > 0 quietly replace dob = `baddob' if id <= `nbad'
    quietly generate long entry = mdy(1, 1, 2020)
    quietly generate long exit  = mdy(12, 31, 2020)
    quietly format dob entry exit %tdCCYY/NN/DD
end

display as result "tvtools QA: 1.16.0 tvage person-time contract -- $S_DATE $S_TIME"

**# A. entry() before dob() is refused, not silently truncated

* Pre-1.16.0 this returned rc=0: attained age at entry went negative, the
* minage() clamp raised it to 0, and the effective interval start was moved
* forward to the birth anniversary -- deleting the pre-birth person-days with
* no error, no console text, no change in the row count, and no r() counter.
_a16_cohort 10 3 `=mdy(3, 26, 2020)'
_a16_persondays entry exit
local pd_in = r(total)
local n_in = _N

local prebirth_log "$TVTOOLS_QA_RUN_DIR/a16_prebirth.log"
capture noisily {
    quietly log using "`prebirth_log'", replace text nomsg name(a16pre)
    noisily tvage, id(id) dob(dob) entry(entry) exit(exit) groupwidth(5)
    quietly log close a16pre
}
local prebirth_rc = _rc
capture log close a16pre
_a16_readlog "`prebirth_log'"
local prebirth_content `"`r(content)'"'

local ok = `prebirth_rc' == 498
_a16_record `ok' A1_PREBIRTH_REFUSED "rc=`prebirth_rc' (expected 498)"

* Transactional: the refusal happens before preserve, so the caller's data must
* be untouched and none of the three output variables may exist.
capture confirm variable age_start
local made_start = (_rc == 0)
capture confirm variable age_stop
local made_stop = (_rc == 0)
capture confirm variable age_tv
local made_age = (_rc == 0)
capture confirm variable dob
local kept_dob = (_rc == 0)
local ok = !`made_start' & !`made_stop' & !`made_age' & `kept_dob' & _N == `n_in'
_a16_record `ok' A2_PREBIRTH_TRANSACTIONAL ///
    "outputs=`made_start'`made_stop'`made_age' dob=`kept_dob' N=`=_N' of `n_in'"

* The message must name how many rows are at fault, so the user can find them.
local ok = strpos(`"`prebirth_content'"', "3 row(s) have entry") > 0 & ///
    strpos(`"`prebirth_content'"', "before birth") > 0
_a16_record `ok' A3_PREBIRTH_ROW_COUNT "rc=`prebirth_rc'"

* The contract in its general form: tvage may refuse this input, or it may
* accept it and conserve person-days, but it may never accept it and lose
* person-days. Pre-1.16.0 it did exactly the third thing (3650 -> 3395).
local pd_out = .
if `prebirth_rc' == 0 _a16_persondays age_start age_stop
if `prebirth_rc' == 0 local pd_out = r(total)
local ok = (`prebirth_rc' != 0) | (`pd_out' == `pd_in')
_a16_record `ok' A4_PREBIRTH_NO_SILENT_LOSS ///
    "rc=`prebirth_rc' in=`pd_in' out=`pd_out'"

**# B. Age-window drops are reported unconditionally and counted in r()

* Three of ten persons carry a dob typo putting them past the default
* maxage(120). Pre-1.16.0: rc=0, an empty console, and r(n_persons)=7 as the
* only trace -- with no input-side counterpart to compare it against.
_a16_cohort 10 3 `=mdy(1, 1, 1000)'
local n_in = _N

local drop_log "$TVTOOLS_QA_RUN_DIR/a16_drop.log"
local d_persons = .
local d_persons_in = .
local d_dropped = .
capture noisily {
    quietly log using "`drop_log'", replace text nomsg name(a16drop)
    noisily tvage, id(id) dob(dob) entry(entry) exit(exit) groupwidth(5)
    * r() must be read before log close; a log-management command clears it.
    local d_persons = r(n_persons)
    local d_persons_in = r(n_persons_in)
    local d_dropped = r(n_persons_dropped)
    quietly log close a16drop
}
local drop_rc = _rc
capture log close a16drop
_a16_readlog "`drop_log'"
local drop_content `"`r(content)'"'

local ok = `drop_rc' == 0 & `d_persons' == 7 & `d_persons_in' == 10 & ///
    `d_dropped' == 3
_a16_record `ok' B1_DROP_SUBSET_RETURNS ///
    "rc=`drop_rc' persons=`d_persons' in=`d_persons_in' dropped=`d_dropped'"

* An absent r() scalar reads back as system missing, and `. == . + .' is TRUE
* in Stata -- so this reconciliation passes vacuously against a build that
* returns neither counter unless non-missingness is asserted explicitly.
local ok = `drop_rc' == 0 & !missing(`d_persons_in') & ///
    !missing(`d_persons') & !missing(`d_dropped') & ///
    `d_persons_in' == `d_persons' + `d_dropped'
_a16_record `ok' B2_DROP_RECONCILES ///
    "`d_persons_in' vs `d_persons'+`d_dropped'"

* The discriminator. tvage was invoked WITHOUT its noisily option, which is
* where the old build printed nothing at all.
local ok = strpos(`"`drop_content'"', "person(s) contributed no rows") > 0 & ///
    strpos(`"`drop_content'"', "minage(0)/maxage(120)") > 0
_a16_record `ok' B3_DROP_REPORTED_BY_DEFAULT "rc=`drop_rc'"

* A notice that always fires is no more informative than one that never fires.
_a16_cohort 10 0 0
local clean_log "$TVTOOLS_QA_RUN_DIR/a16_clean.log"
local c_dropped = .
local c_persons = .
capture noisily {
    quietly log using "`clean_log'", replace text nomsg name(a16clean)
    noisily tvage, id(id) dob(dob) entry(entry) exit(exit) groupwidth(5)
    local c_dropped = r(n_persons_dropped)
    local c_persons = r(n_persons)
    quietly log close a16clean
}
local clean_rc = _rc
capture log close a16clean
_a16_readlog "`clean_log'"
local clean_content `"`r(content)'"'
local ok = `clean_rc' == 0 & `c_dropped' == 0 & `c_persons' == 10 & ///
    strpos(`"`clean_content'"', "contributed no rows") == 0
_a16_record `ok' B4_NO_DROP_NO_NOTICE ///
    "rc=`clean_rc' dropped=`c_dropped' persons=`c_persons'"

* An explicitly requested window drops a subset the same way, and reports it.
clear
quietly set obs 10
quietly generate long id = _n
quietly generate long dob = mdy(1, 1, 1960)
quietly replace dob = mdy(1, 1, 1980) if id > 6
quietly generate long entry = mdy(1, 1, 2020)
quietly generate long exit  = mdy(12, 31, 2020)
local w_persons = .
local w_persons_in = .
local w_dropped = .
capture noisily tvage, id(id) dob(dob) entry(entry) exit(exit) ///
    groupwidth(1) minage(50) maxage(70)
local window_rc = _rc
if `window_rc' == 0 {
    local w_persons = r(n_persons)
    local w_persons_in = r(n_persons_in)
    local w_dropped = r(n_persons_dropped)
}
local ok = `window_rc' == 0 & `w_persons_in' == 10 & `w_persons' == 6 & ///
    `w_dropped' == 4
_a16_record `ok' B5_EXPLICIT_WINDOW_SUBSET ///
    "rc=`window_rc' in=`w_persons_in' out=`w_persons' dropped=`w_dropped'"

**# C. Person-time conservation oracle

* No age-window truncation is in play here, so tvage is a pure splitting
* operation and must conserve person-days exactly. The suite had no such
* oracle: every earlier tvage check asserted row counts, boundary dates, or
* age labels, none of which move when person-time leaks.
capture program drop _a16_conserve
program define _a16_conserve
    args label gw
    clear
    set seed 20260813
    quietly set obs 40
    quietly generate long id = _n
    quietly generate long dob = mdy(1, 1, 1955) + floor(runiform() * 3650)
    quietly generate long entry = mdy(1, 1, 2000) + floor(runiform() * 365)
    quietly generate long exit  = mdy(1, 1, 2019) + floor(runiform() * 365)
    tempvar pd
    quietly generate double `pd' = exit - entry + 1
    quietly summarize `pd', meanonly
    local pd_in = r(sum)
    quietly drop `pd'
    local n_in = _N
    capture noisily tvage, id(id) dob(dob) entry(entry) exit(exit) ///
        groupwidth(`gw')
    local rc = _rc
    local pd_out = .
    local n_out = .
    if `rc' == 0 {
        tempvar idtag
        quietly egen byte `idtag' = tag(id)
        quietly count if `idtag'
        local n_out = r(N)
        quietly generate double `pd' = age_stop - age_start + 1
        quietly summarize `pd', meanonly
        local pd_out = r(sum)
    }
    * The person-count guard keeps the conservation assertion from going
    * vacuous if the fixture ever starts triggering the age window. It is
    * computed from the data rather than read from r(n_persons_dropped), so
    * this check tests conservation on every build rather than doubling as a
    * second test of the 1.16.0 return surface.
    local ok = `rc' == 0 & `n_out' == `n_in' & `pd_out' == `pd_in'
    _a16_record `ok' `label' "rc=`rc' in=`pd_in' out=`pd_out' persons=`n_out' of `n_in'"
end

_a16_conserve C1_CONSERVATION_GW1 1
_a16_conserve C2_CONSERVATION_GW5 5

* Conservation alone does not prove the intervals tile the follow-up: a gap
* paired with an equal overlap conserves the total. Check contiguity too.
clear
set seed 20260813
quietly set obs 40
quietly generate long id = _n
quietly generate long dob = mdy(1, 1, 1955) + floor(runiform() * 3650)
quietly generate long entry = mdy(1, 1, 2000) + floor(runiform() * 365)
quietly generate long exit  = mdy(1, 1, 2019) + floor(runiform() * 365)
capture noisily tvage, id(id) dob(dob) entry(entry) exit(exit) groupwidth(1)
local tile_rc = _rc
local n_break = .
local n_reversed = .
if `tile_rc' == 0 {
    quietly bysort id (age_start): generate byte _brk = ///
        (_n > 1) & (age_start != age_stop[_n-1] + 1)
    quietly count if _brk
    local n_break = r(N)
    quietly count if age_stop < age_start
    local n_reversed = r(N)
}
local ok = `tile_rc' == 0 & `n_break' == 0 & `n_reversed' == 0
_a16_record `ok' C3_CONTIGUOUS_TILING ///
    "rc=`tile_rc' breaks=`n_break' reversed=`n_reversed'"

display as result "tvtools 1.16.0 tvage contract: $A16_PASS/$A16_TESTS passed"
display "RESULT: test_tvage_v1160 tests=$A16_TESTS pass=$A16_PASS fail=$A16_FAIL"
if $A16_FAIL > 0 {
    display as error "Failed tests:$A16_FAILED"
    capture log close _all
    exit 1
}
capture log close _all
