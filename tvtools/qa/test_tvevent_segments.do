*! test_tvevent_segments.do
*! Contract pins for tvevent's direct segment builder (1.9.1).
*!
*! Until 1.9.1 tvevent discovered split points with the Mata point engine, then
*! THREW AWAY the engine's interval index and rebuilt the interval-to-date
*! association with joinby(id) + reshape wide + expand + merge, round-tripping
*! through four tempfiles. Segments are now built straight from the pair index:
*! one row per (bound row, segment number), mapped back onto payload rows by
*! coordinate.
*!
*! Axes probed, and why each one is here:
*!   S1-S4   segments exactly PARTITION the interval they came from -- full
*!           coverage, no gap, no overlap, count == splits + 1. This is an
*!           independent oracle, computed from the input geometry, not a
*!           restatement of what the builder does. The pre-1.9.1 suite asserted
*!           event counts and row counts, which a builder that mis-set one
*!           boundary would still satisfy.
*!   S5-S6   the Section 5.1 boundary rules: an event at start yields
*!           [start,start] and [start+1,stop]; an event at stop is flagged
*!           WITHOUT a split.
*!   S7      many split points in a single interval. The released builder
*!           needed one `date'# variable per split rank; the new one needs
*!           none, so the split count is no longer bounded by a variable
*!           budget or by reshape's cost.
*!   S8-S9   the bound-row/payload-row distinction. Duplicate coordinates with
*!           different payloads each receive the full segment set, and split
*!           dates deduplicate WITHIN a bound row, never across a person.
*!   S10-S12 the three new scratch frames do not leak -- on success, on the
*!           ambiguity refusal, and on a malformed-input refusal. This is state
*!           the refactor introduced; nothing in the pre-1.9.1 suite could see
*!           a leaked frame, and a leak is silent until a name collides.
*!   S13     a user column whose name begins with __ survives as id(). This is
*!           not hypothetical: `frget varlist' SILENTLY SKIPS such a source and
*!           still returns rc=0, which is exactly how the first draft of the
*!           builder failed -- the next line errored on a variable that was
*!           never created. Every frget in the builder now names both sides.
*!   S14-S15 the Section 5.2 quantity algebra across segments: total()
*!           apportions and sums back to the original, rate() and cumulative()
*!           are carried unchanged.
*!   S16     the caller's data survives a failure inside the builder.
*!   S17     repeated identical runs produce byte-identical output, so no
*!           result depends on frame or sort nondeterminism.
*!   S18-S19 frames built for a call that turns out to need no split are still
*!           released, and a frame() input is left intact.
*!   S20     nested intervals index independently. The builder numbers
*!           coordinates once in split discovery and regenerates that numbering
*!           for payload rows; nested intervals are the only geometry where
*!           (id, start, stop) and (id, stop, start) disagree, so nothing else
*!           can see the two sides drift apart.
*!
*! NOT covered, stated so it is not mistaken for coverage: the three
*! `capture frame drop' lines in tvevent's error-cleanup zone are defensive.
*! Deleting them changes no check here, because every reachable refusal fires
*! either before the frames exist or after the success-path drops have already
*! run. They guard an unexpected failure inside frlink/expand/Mata, which no
*! fixture can induce from outside the command.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvevent_segments.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TES_PASS = 0
global TES_FAIL = 0
global TES_FAILED ""
local test_count = 0

display as result "tvtools QA: tvevent segment builder -- $S_DATE $S_TIME"

capture program drop _tes_check
program define _tes_check
    args ok label detail
    if `ok' {
        global TES_PASS = $TES_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TES_FAIL = $TES_FAIL + 1
        global TES_FAILED "$TES_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Count frames other than the ones this suite owns. A scratch frame left behind
* by tvevent shows up here and nowhere else.
capture program drop _tes_nframes
program define _tes_nframes, rclass
    version 16.0
    quietly frames dir
    local all `r(frames)'
    local mine "default fivl keepme"
    local extra : list all - mine
    return local extra "`extra'"
    return scalar n = `: word count `extra''
end

tempfile fIVL fEV fOUT fDUP fOVL fMANY fEVMANY fQTY

**# ---------------------------------------------------------------------
**# Fixtures
**# ---------------------------------------------------------------------
* 21915 = 01jan2020. Person 1 owns two abutting 30-day intervals, person 2 one,
* person 3 a single-day interval.
clear
quietly input long pid int i_start int i_stop byte trt
    1 21915 21944 1
    1 21945 21974 2
    2 21915 21944 1
    3 21930 21930 0
end
format i_start i_stop %tdCCYY/NN/DD
quietly save "`fIVL'", replace

* Recurring events: two internal dates for person 1 (one in each interval), one
* internal date for person 2, none for person 3.
clear
quietly input long pid int evdate1 int evdate2
    1 21930 21960
    2 21920 .
end
format evdate1 evdate2 %tdCCYY/NN/DD
quietly save "`fEV'", replace

**# ---------------------------------------------------------------------
**# S1-S4  Segments partition their parent interval
**# ---------------------------------------------------------------------
* Independent oracle: recompute, from the ORIGINAL geometry, what the partition
* of each interval must be, and compare against what tvevent produced. Nothing
* here reads the builder's intermediate state.

quietly use "`fEV'", clear
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
quietly save "`fOUT'", replace

local ++test_count
* Coverage: total person-time out == total person-time in. Splitting an
* interval must neither create nor destroy a single day.
quietly use "`fIVL'", clear
quietly generate double _d = i_stop - i_start + 1
quietly summarize _d, meanonly
local dayin = r(sum)
quietly use "`fOUT'", clear
quietly generate double _d = i_stop - i_start + 1
quietly summarize _d, meanonly
local dayout = r(sum)
local _ok = (`dayin' == `dayout')
_tes_check `_ok' "S1 segments cover exactly the input person-time" ///
    "in=`dayin' out=`dayout'"

local ++test_count
* No overlap and no gap: within a person, consecutive rows must abut exactly
* (next start == previous stop + 1) wherever the previous row came from the
* same original interval. Checking the whole person is stronger and still
* correct here, because the fixture's intervals themselves abut.
quietly use "`fOUT'", clear
sort pid i_start i_stop
quietly by pid: generate double _gap = i_start - i_stop[_n-1] - 1 if _n > 1
quietly count if _gap != 0 & !missing(_gap)
local _ok = (r(N) == 0)
_tes_check `_ok' "S2 consecutive segments abut with no gap or overlap" ///
    "`r(N)' adjacent pairs do not satisfy start == prior stop + 1"

local ++test_count
* Every segment is well formed: start <= stop, both non-missing.
quietly count if missing(i_start) | missing(i_stop) | i_start > i_stop
local _ok = (r(N) == 0)
_tes_check `_ok' "S3 every emitted segment has start <= stop" ///
    "`r(N)' malformed segments"

local ++test_count
* Row count: 4 intervals in, 3 internal split points, so 7 rows out.
quietly count
local _ok = (r(N) == 7)
_tes_check `_ok' "S4 row count equals intervals + split points" ///
    "expected 7, observed `r(N)'"

**# ---------------------------------------------------------------------
**# S5-S6  Section 5.1 boundary rules
**# ---------------------------------------------------------------------

local ++test_count
* Event AT START: [start,start] then [start+1,stop]; the event belongs to the
* first segment.
clear
quietly input long pid int evdate1
    2 21915
end
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
quietly count if pid == 2 & i_start == 21915 & i_stop == 21915
local a = r(N)
quietly count if pid == 2 & i_start == 21916 & i_stop == 21944
local b = r(N)
quietly count if pid == 2 & i_start == 21915 & i_stop == 21915 & _failure > 0
local c = r(N)
local _ok = (`a' == 1 & `b' == 1 & `c' == 1)
_tes_check `_ok' ///
    "S5 event at start splits into [s,s] and [s+1,stop], flagged on the first" ///
    "[s,s]=`a' [s+1,stop]=`b' flagged=`c'"

local ++test_count
* Event AT STOP: flagged, no split. Person 2's single interval must stay whole.
clear
quietly input long pid int evdate1
    2 21944
end
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
quietly count if pid == 2
local n2 = r(N)
quietly count if pid == 2 & i_start == 21915 & i_stop == 21944 & _failure > 0
local f2 = r(N)
local _ok = (`n2' == 1 & `f2' == 1)
_tes_check `_ok' ///
    "S6 event at stop is flagged without splitting the interval" ///
    "rows for pid 2 = `n2' (expected 1), flagged whole interval = `f2'"

**# ---------------------------------------------------------------------
**# S7  Many split points in one interval
**# ---------------------------------------------------------------------
* The released builder reshaped split dates wide, so an interval with j splits
* needed j variables named `date'1 ... `date'j. The direct builder creates none.

local nsplit = 200
clear
quietly set obs 1
quietly generate long pid = 1
quietly generate int i_start = 21915
quietly generate int i_stop  = 21915 + `nsplit' + 5
format i_start i_stop %tdCCYY/NN/DD
quietly save "`fMANY'", replace

clear
quietly set obs 1
quietly generate long pid = 1
forvalues k = 1/`nsplit' {
    quietly generate int evdate`k' = 21915 + `k'
    format evdate`k' %tdCCYY/NN/DD
}
quietly save "`fEVMANY'", replace

local ++test_count
quietly use "`fEVMANY'", clear
capture quietly tvevent using "`fMANY'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
local rc = _rc
local nrows = _N
* j split points inside one interval produce j+1 segments.
quietly generate double _d = i_stop - i_start + 1
quietly summarize _d, meanonly
local cover = r(sum)
local _ok = (`rc' == 0 & `nrows' == `nsplit' + 1 & `cover' == `nsplit' + 6)
_tes_check `_ok' ///
    "S7 `nsplit' split points in one interval yield `=`nsplit'+1' segments covering it exactly" ///
    "rc=`rc' rows=`nrows' (expected `=`nsplit'+1') days=`cover' (expected `=`nsplit'+6')"

**# ---------------------------------------------------------------------
**# S8-S9  Bound rows versus payload rows
**# ---------------------------------------------------------------------

* Two rows sharing (id,start,stop) but carrying different payloads.
clear
quietly input long pid int i_start int i_stop byte trt str3 payl
    1 21915 21944 1 "xx"
    1 21915 21944 1 "yy"
    2 21915 21944 2 "zz"
end
format i_start i_stop %tdCCYY/NN/DD
quietly save "`fDUP'", replace

local ++test_count
clear
quietly input long pid int evdate1
    1 21930
end
quietly tvevent using "`fDUP'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring) keepvars()
quietly count if pid == 1
local n1 = r(N)
quietly count if pid == 1 & payl == "xx"
local nx = r(N)
quietly count if pid == 1 & payl == "yy"
local ny = r(N)
local _ok = (`n1' == 4 & `nx' == 2 & `ny' == 2)
_tes_check `_ok' ///
    "S8 duplicate coordinates with distinct payloads each get the full segment set" ///
    "pid1 rows=`n1' (expected 4), xx=`nx' yy=`ny' (expected 2 each)"

local ++test_count
* Split dates deduplicate WITHIN a bound row. Under type(recurring) tvevent
* refuses two event rows that share a person-day (r459), so the only way a
* coordinate receives the same split date twice is type(single), where same-day
* rows are explicitly "the same event". The dedup is then observable as
* idempotence: two identical event rows must produce exactly the output one
* row produces.
clear
quietly input long pid int evdate
    1 21930
end
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop)
quietly save "`fOUT'", replace
clear
quietly input long pid int evdate
    1 21930
    1 21930
end
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop)
capture cf _all using "`fOUT'", verbose
local cfrc = _rc
local _ok = (`cfrc' == 0)
_tes_check `_ok' ///
    "S9 a repeated same-day event splits the coordinate exactly once" ///
    "cf against the single-event run rc=`cfrc'"

**# ---------------------------------------------------------------------
**# S10-S12  Scratch frames do not leak
**# ---------------------------------------------------------------------

local ++test_count
capture frame drop keepme
frame create keepme
frame keepme: quietly set obs 2
quietly use "`fEV'", clear
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
_tes_nframes
local _ok = (r(n) == 0)
_tes_check `_ok' "S10 no scratch frame survives a successful call" ///
    "left behind: `r(extra)'"

local ++test_count
* The ambiguity refusal fires AFTER the segment builder has run and created its
* frames, which is the interesting error path.
clear
quietly input long pid int i_start int i_stop byte trt
    1 21915 21944 1
    1 21930 21960 2
end
format i_start i_stop %tdCCYY/NN/DD
quietly save "`fOVL'", replace
clear
quietly input long pid int evdate
    1 21935
end
capture tvevent using "`fOVL'", id(pid) date(evdate) start(i_start) stop(i_stop)
local rc = _rc
_tes_nframes
local _ok = (`rc' == 459 & r(n) == 0)
_tes_check `_ok' ///
    "S11 the ambiguity refusal leaves no scratch frame" ///
    "rc=`rc' (expected 459), left behind: `r(extra)'"

local ++test_count
clear
quietly input long pid int evdate
    1 21930
end
capture tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(nosuchvar) stop(i_stop)
local rc = _rc
_tes_nframes
local _ok = (`rc' != 0 & r(n) == 0)
_tes_check `_ok' ///
    "S12 a rejected call leaves no scratch frame" ///
    "rc=`rc', left behind: `r(extra)'"
capture frame drop keepme

**# ---------------------------------------------------------------------
**# S13  A user column named __x
**# ---------------------------------------------------------------------
* `frget varlist' silently skips a source variable whose name starts with __
* and still returns rc=0. The builder uses the explicit new = old form
* everywhere so a user column named like a tempvar cannot vanish.

local ++test_count
quietly use "`fIVL'", clear
quietly rename pid __uid
quietly save "`fOUT'", replace
clear
quietly input long __uid int evdate1
    1 21930
end
capture quietly tvevent using "`fOUT'", id(__uid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
local rc = _rc
local n = _N
quietly count if __uid == 1 & i_start == 21915 & i_stop == 21930
local a = r(N)
quietly count if __uid == 1 & i_start == 21931 & i_stop == 21944
local b = r(N)
local _ok = (`rc' == 0 & `n' == 5 & `a' == 1 & `b' == 1)
_tes_check `_ok' ///
    "S13 an id() column named __uid splits correctly" ///
    "rc=`rc' rows=`n' (expected 5) [21915,21930]=`a' [21931,21944]=`b'"

**# ---------------------------------------------------------------------
**# S14-S15  Quantity algebra across segments
**# ---------------------------------------------------------------------

clear
quietly input long pid int i_start int i_stop double tot double rt double cum
    1 21915 21944 300 2.5 1000
    2 21915 21944 300 2.5 2000
end
format i_start i_stop %tdCCYY/NN/DD
char tot[tvtools_quantity] "total"
char rt[tvtools_quantity] "rate"
char cum[tvtools_quantity] "cumulative"
char cum[tvtools_history_point] "start"
quietly save "`fQTY'", replace

local ++test_count
clear
quietly input long pid int evdate1
    1 21930
end
quietly tvevent using "`fQTY'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring) ///
    total(tot) rate(rt) cumulative(cum)
* Person 1's 30-day interval splits into 16 and 14 days. total() apportions by
* duration and must sum back to the original.
quietly summarize tot if pid == 1, meanonly
local sumtot = r(sum)
quietly count if pid == 1 & i_stop == 21930 & reldif(tot, 300 * 16 / 30) < 1e-12
local seg1 = r(N)
quietly count if pid == 1 & i_start == 21931 & reldif(tot, 300 * 14 / 30) < 1e-12
local seg2 = r(N)
local _ok = (reldif(`sumtot', 300) < 1e-12 & `seg1' == 1 & `seg2' == 1)
_tes_check `_ok' ///
    "S14 total() apportions by duration and sums back to the original" ///
    "sum=`sumtot' (expected 300) seg1=`seg1' seg2=`seg2'"

local ++test_count
quietly count if pid == 1 & rt == 2.5
local nr = r(N)
quietly count if pid == 1 & cum == 1000
local nc = r(N)
local q1 : char rt[tvtools_quantity]
local q2 : char cum[tvtools_quantity]
local q3 : char cum[tvtools_history_point]
local _ok = (`nr' == 2 & `nc' == 2 & "`q1'" == "rate" & "`q2'" == "cumulative" ///
    & "`q3'" == "start")
_tes_check `_ok' ///
    "S15 rate() and cumulative() carry unchanged, with characteristics intact" ///
    "rate rows=`nr' cum rows=`nc' chars=`q1'/`q2'/`q3'"

**# ---------------------------------------------------------------------
**# S16  Caller survives a failure inside the builder
**# ---------------------------------------------------------------------

local ++test_count
clear
quietly input long pid int evdate
    1 21935
end
quietly generate double caller_marker = 4242
capture tvevent using "`fOVL'", id(pid) date(evdate) start(i_start) stop(i_stop)
local rc = _rc
capture confirm variable caller_marker
local haveit = (_rc == 0)
local n = _N
quietly summarize caller_marker, meanonly
local _ok = (`rc' == 459 & `haveit' & `n' == 1 & r(mean) == 4242)
_tes_check `_ok' ///
    "S16 the caller's data survives a refusal inside the builder" ///
    "rc=`rc' marker=`haveit' N=`n'"

**# ---------------------------------------------------------------------
**# S17  Repeated runs are byte-identical
**# ---------------------------------------------------------------------
* Frames, frlink, and the sorts inside the builder must not leave any output
* detail to run-to-run chance. Compared with cf, which errors on any difference
* in values, variable list, or observation count.

local ++test_count
quietly use "`fEV'", clear
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
quietly save "`fOUT'", replace
quietly use "`fEV'", clear
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
capture cf _all using "`fOUT'", verbose
local cfrc = _rc
local s1 : sortedby
local _ok = (`cfrc' == 0)
_tes_check `_ok' ///
    "S17 two identical calls produce byte-identical output" ///
    "cf rc=`cfrc' sortedby=`s1'"

**# ---------------------------------------------------------------------
**# S18-S19  Frames created but never used, and frame() input
**# ---------------------------------------------------------------------

local ++test_count
* n_splits == 0 with events present: the bound, event, and pair frames are all
* built and then must be released even though the split branch never ran. The
* success-path drops sit outside that branch precisely so this case is covered.
capture frame drop keepme
frame create keepme
frame keepme: quietly set obs 2
clear
quietly input long pid int evdate1
    2 21944
end
quietly tvevent using "`fIVL'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
_tes_nframes
local _ok = (r(n) == 0)
_tes_check `_ok' "S18 no frame leaks when events match but nothing splits" ///
    "left behind: `r(extra)'"

local ++test_count
* frame() input: tvevent still materialises the named frame to a tempfile, so
* this pins that the user's frame survives untouched and no scratch frame is
* added on top of it.
capture frame drop fivl
frame create fivl
frame fivl: use "`fIVL'", clear
quietly use "`fEV'", clear
quietly tvevent, frame(fivl) id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
local nout = _N
frame fivl: quietly count
local nsrc = r(N)
_tes_nframes
local _ok = (`nout' == 7 & `nsrc' == 4 & r(n) == 0)
_tes_check `_ok' "S19 frame() input is left intact and adds no scratch frame" ///
    "rows=`nout' (expected 7) source frame rows=`nsrc' (expected 4), left behind: `r(extra)'"
capture frame drop fivl

**# ---------------------------------------------------------------------
**# S20  Nested intervals index independently
**# ---------------------------------------------------------------------
* The builder numbers coordinates in Section 3 and regenerates that numbering
* for payload rows in Section 4. Both must key on (id, start, stop) in the same
* order. Nested intervals are the only geometry where (id, start, stop) and
* (id, stop, start) order coordinates differently -- for abutting or partially
* overlapping intervals the two agree -- so this is the case that can see a
* swapped index. It is here because fault injection showed nothing else did.

local ++test_count
clear
quietly input long pid int i_start int i_stop byte trt
    1 21915 21980 1
    1 21930 21960 2
end
format i_start i_stop %tdCCYY/NN/DD
tempfile fNEST
quietly save "`fNEST'", replace
clear
quietly input long pid int evdate1 int evdate2
    1 21940 21970
end
quietly tvevent using "`fNEST'", id(pid) date(evdate) ///
    start(i_start) stop(i_stop) type(recurring)
* Outer [21915,21980] splits at 21940 and 21970 -> three segments.
* Inner [21930,21960] splits at 21940 only -> two segments.
local outer = 0
foreach seg in "21915 21940" "21941 21970" "21971 21980" {
    local a : word 1 of `seg'
    local b : word 2 of `seg'
    quietly count if i_start == `a' & i_stop == `b'
    local outer = `outer' + (r(N) == 1)
}
local inner = 0
foreach seg in "21930 21940" "21941 21960" {
    local a : word 1 of `seg'
    local b : word 2 of `seg'
    quietly count if i_start == `a' & i_stop == `b'
    local inner = `inner' + (r(N) == 1)
}
quietly count
local ntot = r(N)
local _ok = (`outer' == 3 & `inner' == 2 & `ntot' == 5)
_tes_check `_ok' ///
    "S20 nested intervals each receive their own segments" ///
    "outer segments matched=`outer'/3 inner=`inner'/2 rows=`ntot' (expected 5)"

**# Summary
capture frame drop keepme
local pass_count = $TES_PASS
local fail_count = $TES_FAIL
display "RESULT: test_tvevent_segments tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvevent segment builder failures:$TES_FAILED"
    exit 1
}
