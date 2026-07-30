* baseline_tvevent_surface.do
* Behavioural baseline capture and differential replay for tvevent.
*
* Implements Section 7.3 of the tvtools single-pass plan for the tvevent scope:
* for every case, the complete output dataset, observation and variable order,
* storage types, formats, labels, characteristics, public r() surface,
* negative-path return codes, and caller state after success and error.
*
* Case coverage is driven by Section 10.3's required boundary list: events
* before entry and after exit, at start, strictly inside, at stop, one-day
* intervals, multiple internal dates in one interval, same-day duplicate
* rejection, primary/competing same-day handling, earliest event independent of
* event-row order, recurring events with enum()/total-time/gap-time clocks,
* duplicate interval coordinates with distinct payloads, an ambiguous first
* event in two distinct overlapping intervals, empty/all-missing event data,
* rate()/total()/cumulative()/deprecated continuous(), and string payloads with
* value labels, formats, and characteristics.
*
* Manually invoked. Deliberately NOT in any correctness lane and NOT in
* qa/_tvtools_qa_manifest.do: it emits a BASELINE: line, never a RESULT: line,
* because its verdict depends on a capture directory produced by a different
* build of the package.
*
* Usage (from the package's qa/ directory):
*   stata-mp -b do baseline_tvevent_surface.do capture <dir>
*   stata-mp -b do baseline_tvevent_surface.do compare <dir>
*
* capture  runs every case and writes <dir>/<tag>.dta, <dir>/<tag>.meta, and
*          <dir>/<tag>.ret. Run this against the frozen implementation.
* compare  re-runs every case against the current implementation and diffs it
*          against <dir>. Any difference in values, variable list or order,
*          sortedby, storage type, format, variable label, value label name or
*          definition, characteristic, return code, or r() surface is a
*          failure. Exact comparison throughout -- no tolerance.
*
* A legacy-vs-new comparison alone can preserve an old bug, so this harness is
* the surface-drift half of the evidence only. The independent-oracle half
* lives in validation_tvevent.do, validation_audit_tvevent.do, and
* crossval_tvevent_recurring.do.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local mode "`1'"
local dir  "`2'"
if !inlist("`mode'", "capture", "compare") {
    display as error "usage: baseline_tvevent_surface.do {capture|compare} <dir>"
    exit 198
}
if "`dir'" == "" {
    display as error "a capture directory is required"
    exit 198
}
capture mkdir "`dir'"

local qadir "`c(pwd)'"
adopath ++ "`qadir'/.."

global TVB_PASS = 0
global TVB_FAIL = 0
global TVB_FAILED ""
global TVB_MODE  "`mode'"
global TVB_DIR   "`dir'"

display as result "tvtools baseline (tvevent surface): `mode' -- $S_DATE $S_TIME"

**# ---------------------------------------------------------------------
**# Recorder
**# ---------------------------------------------------------------------
* _tvb_record must run IMMEDIATELY after the command under test: every
* describe, confirm, count, or file command below replaces r().

capture program drop _tvb_record
program define _tvb_record
    version 16.0
    args tag therc skipr

    * Snapshot r() before anything here can touch it.
    local rs : r(scalars)
    local rm : r(macros)
    local rt : r(matrices)
    * skipr: the caller has just run `frame change', so r() belongs to that
    * command, not to the case under test. Record data and metadata only.
    if "`skipr'" == "nor" {
        local rs ""
        local rm ""
        local rt ""
    }
    local rsvals ""
    foreach nm of local rs {
        local v = r(`nm')
        local rsvals `"`rsvals' `nm'="`v'""'
    }
    local rmvals ""
    foreach nm of local rm {
        local v `"`r(`nm')'"'
        * Absolute paths are not part of the behavioural contract: the capture
        * directory differs between runs, and a `frame()' input is currently
        * materialised to a per-process Stata tempfile whose name changes every
        * time. Normalise both so a real contract change is not buried under
        * noise -- and so the tempfile paths themselves are visible as
        * <tempfile> when they should have disappeared entirely.
        local v : subinstr local v "$TVB_DIR" "<dir>", all
        local v : subinstr local v "`c(tmpdir)'" "<tmp>", all
        local vnorm ""
        foreach tok of local v {
            if regexm("`tok'", "St[0-9]+\.[0-9]+") local tok "<tempfile>"
            local vnorm "`vnorm' `tok'"
        }
        local vnorm = trim("`vnorm'")
        local rmvals `"`rmvals' `nm'="`vnorm'""'
    }
    * r(flow) is a matrix in tvevent; record its cells, not just its name, so a
    * flow-accounting change cannot pass as a matching matrix list.
    local rmxvals ""
    foreach nm of local rt {
        tempname _M
        matrix `_M' = r(`nm')
        local _r = rowsof(`_M')
        local _c = colsof(`_M')
        local _cells ""
        forvalues i = 1/`_r' {
            forvalues j = 1/`_c' {
                local _cells "`_cells',`=`_M'[`i',`j']'"
            }
        }
        local _rn : rownames `_M'
        local _cn : colnames `_M'
        local rmxvals `"`rmxvals' `nm'=`_r'x`_c'[`_rn'][`_cn']`_cells'"'
    }

    local dir "$TVB_DIR"
    local mode "$TVB_MODE"

    * Structural and metadata description of the current data.
    local nobs = _N
    local nvar = c(k)
    local sortby : sortedby
    local dtalab : data label
    quietly describe, varlist
    local vlist `r(varlist)'

    local meta "N=`nobs'|K=`nvar'|SORT=`sortby'|DTALAB=`dtalab'"
    foreach v of local vlist {
        local t  : type `v'
        local f  : format `v'
        local l  : variable label `v'
        local vl : value label `v'
        local c1 : char `v'[tvtools_quantity]
        local c2 : char `v'[tvtools_history_point]
        local c3 : char `v'[tvtools_quantity_unit]
        * Value-label DEFINITIONS, not just the assigned name: two datasets can
        * carry the same label name with different contents.
        local vldef ""
        if "`vl'" != "" {
            quietly levelsof `v', local(_lv) missing
            foreach x of local _lv {
                local d : label `vl' `x', strict
                local vldef "`vldef',`x'=`d'"
            }
        }
        local meta `"`meta'|`v';`t';`f';`l';`vl';`c1';`c2';`c3';`vldef'"'
    }

    tempname fh
    if "`mode'" == "capture" {
        file open `fh' using "`dir'/`tag'.meta", write replace text
        file write `fh' `"`meta'"' _n
        file close `fh'
        file open `fh' using "`dir'/`tag'.ret", write replace text
        file write `fh' "rc=`therc'" _n
        file write `fh' `"scalars:`rsvals'"' _n
        file write `fh' `"macros:`rmvals'"' _n
        file write `fh' `"matrices:`rmxvals'"' _n
        file close `fh'
        quietly save "`dir'/`tag'.dta", replace emptyok
        display as text "  captured `tag' (rc=`therc', N=`nobs', k=`nvar')"
        exit
    }

    * compare
    local ok = 1
    local detail ""

    capture confirm file "`dir'/`tag'.meta"
    if _rc {
        local ok = 0
        local detail "no baseline captured for `tag'"
    }
    else {
        tempname fh2
        file open `fh2' using "`dir'/`tag'.meta", read text
        file read `fh2' line
        local basemeta `"`line'"'
        file close `fh2'
        if `"`basemeta'"' != `"`meta'"' {
            local ok = 0
            local detail "metadata/schema drift"
            display as error `"    baseline: `basemeta'"'
            display as error `"    current : `meta'"'
        }

        file open `fh2' using "`dir'/`tag'.ret", read text
        file read `fh2' line
        local baserc `"`line'"'
        file read `fh2' line
        local basesc `"`line'"'
        file read `fh2' line
        local basemc `"`line'"'
        file read `fh2' line
        local basemx `"`line'"'
        file close `fh2'
        if `"`baserc'"' != "rc=`therc'" {
            local ok = 0
            local detail "`detail' return code (baseline `baserc', now rc=`therc')"
        }
        if `"`basesc'"' != `"scalars:`rsvals'"' {
            local ok = 0
            local detail "`detail' r() scalars"
            display as error `"    baseline: `basesc'"'
            display as error `"    current : scalars:`rsvals'"'
        }
        if `"`basemc'"' != `"macros:`rmvals'"' {
            local ok = 0
            local detail "`detail' r() macros"
            display as error `"    baseline: `basemc'"'
            display as error `"    current : macros:`rmvals'"'
        }
        if `"`basemx'"' != `"matrices:`rmxvals'"' {
            local ok = 0
            local detail "`detail' r() matrices"
            display as error `"    baseline: `basemx'"'
            display as error `"    current : matrices:`rmxvals'"'
        }

        * cf compares values variable by variable and errors on any mismatch,
        * including a differing variable list or observation count.
        capture cf _all using "`dir'/`tag'.dta", verbose
        if _rc {
            local ok = 0
            local detail "`detail' data values (cf rc=`=_rc')"
        }
    }

    if `ok' {
        global TVB_PASS = $TVB_PASS + 1
        display as result "  MATCH `tag'"
    }
    else {
        global TVB_FAIL = $TVB_FAIL + 1
        global TVB_FAILED "$TVB_FAILED `tag'"
        display as error "  DRIFT `tag': `detail'"
    }
end

**# ---------------------------------------------------------------------
**# Deterministic fixtures
**# ---------------------------------------------------------------------
* Every generated tie carries an explicit original-row tie-break, so no result
* below depends on the sort seed.
*
* Built at top level, not inside a program: several fixtures use `input', whose
* terminating `end' would close a program definition instead of the input block.
*
* Calendar anchor: 21915 = 01jan2020.

    * --- interval (using) datasets -----------------------------------------

    * I1 base intervals: two-segment person, single-segment person, a one-day
    * interval, and a long interval. Carries the metadata classes the parity
    * contract names that survive a default call: value label, variable label,
    * display formats, a string payload, and a dataset label.
    *
    * The tvtools_quantity characteristics deliberately live in ivl_qty.dta
    * instead. tvevent refuses (r498, "Quantity variable totq requires explicit
    * total()") whenever a marked column arrives without its option, so putting
    * the chars here would freeze that refusal as the baseline for every default
    * case and leave the segment builder itself uncovered.
    clear
    quietly input long pid int i_start int i_stop byte trt double totq double rateq double cumq str6 site
        1 21915 21944 1 30 0.5 100 "north"
        1 21945 21974 2 30 1.5 130 "north"
        2 21915 21944 1 30 0.5 200 "south"
        3 21915 21915 0  1 0.25 10 "north"
        4 21915 21974 2 60 2.0 400 "south"
    end
    label define _trtlbl 0 "none" 1 "low" 2 "high"
    label values trt _trtlbl
    label variable trt "Treatment level"
    label variable totq "Interval total"
    format i_start i_stop %tdCCYY/NN/DD
    format totq %9.2f
    label data "tvevent baseline intervals"
    quietly save "`dir'/ivl_base.dta", replace

    * I1b the same intervals carrying all three tvtools_* characteristics. Used
    * only by the cases that pass the matching rate()/total()/cumulative()
    * options, which is the only way a marked column reaches the engine.
    char totq[tvtools_quantity] "total"
    char rateq[tvtools_quantity] "rate"
    char cumq[tvtools_quantity] "cumulative"
    char cumq[tvtools_history_point] "start"
    quietly save "`dir'/ivl_qty.dta", replace

    * I2 duplicate interval coordinates with DISTINCT payloads. These rows must
    * survive: the final dedup keys on the whole row, never on (id,start,stop).
    clear
    quietly input long pid int i_start int i_stop byte trt str3 payl
        1 21915 21944 1 "xx"
        1 21915 21944 1 "yy"
        2 21915 21944 2 "zz"
    end
    format i_start i_stop %tdCCYY/NN/DD
    quietly save "`dir'/ivl_paydup.dta", replace

    * I3 two DISTINCT overlapping intervals containing the same date. Section
    * 10.2 item 12 keeps these ambiguous.
    clear
    quietly input long pid int i_start int i_stop byte trt
        1 21915 21944 1
        1 21930 21960 2
        2 21915 21944 1
    end
    format i_start i_stop %tdCCYY/NN/DD
    quietly save "`dir'/ivl_overlap.dta", replace

    * I4 string ID
    use "`dir'/ivl_base.dta", clear
    quietly generate str8 sid = "P" + string(pid, "%04.0f")
    quietly drop pid
    quietly save "`dir'/ivl_base_str.dta", replace

    * I5 intervals carrying a strL id
    use "`dir'/ivl_base.dta", clear
    quietly generate strL lid = "P" + string(pid)
    quietly save "`dir'/ivl_base_strl.dta", replace

    * I6 intervals already containing an output name, for the replace policy
    use "`dir'/ivl_base.dta", clear
    quietly generate byte _failure = 7
    quietly save "`dir'/ivl_hasfail.dta", replace

    * I7 intervals containing a date-stub collision (evdate1)
    use "`dir'/ivl_base.dta", clear
    quietly generate int evdate1 = 21920
    quietly save "`dir'/ivl_stub.dta", replace

    * I8 malformed intervals: a missing stop and a reversed pair
    use "`dir'/ivl_base.dta", clear
    quietly replace i_stop = . in 2
    quietly replace i_start = i_stop + 5 in 3
    quietly save "`dir'/ivl_bad.dta", replace

    * --- event (master) datasets --------------------------------------------

    * E1 one event strictly inside the first interval of pid 1
    clear
    quietly input long pid int evdate
        1 21930
    end
    format evdate %tdCCYY/NN/DD
    label variable evdate "Event date"
    quietly save "`dir'/ev_inside.dta", replace

    * E2 event exactly at start: yields [start,start] and [start+1,stop]
    clear
    quietly input long pid int evdate
        1 21915
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_at_start.dta", replace

    * E3 event exactly at stop: flagged, no split
    clear
    quietly input long pid int evdate
        1 21944
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_at_stop.dta", replace

    * E4 events before entry and after exit for two different people
    clear
    quietly input long pid int evdate
        1 21000
        2 22999
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_outside.dta", replace

    * E5 event on the one-day interval of pid 3
    clear
    quietly input long pid int evdate
        3 21915
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_oneday.dta", replace

    * E6 several internal dates inside one interval of pid 4, deliberately NOT
    * in ascending row order, so segment construction cannot depend on the
    * order events happen to arrive in.
    clear
    quietly input long pid int evdate1 int evdate2 int evdate3
        4 21950 21920 21935
    end
    format evdate1 evdate2 evdate3 %tdCCYY/NN/DD
    quietly save "`dir'/ev_multi_wide.dta", replace

    * E7 the same three dates in ascending order. Under type(recurring) the
    * output must be identical to E6.
    clear
    quietly input long pid int evdate1 int evdate2 int evdate3
        4 21920 21935 21950
    end
    format evdate1 evdate2 evdate3 %tdCCYY/NN/DD
    quietly save "`dir'/ev_multi_wide_sorted.dta", replace

    * E8 recurring events for several people
    clear
    quietly input long pid int evdate1 int evdate2
        1 21930 21955
        2 21920 .
        4 21925 21960
    end
    format evdate1 evdate2 %tdCCYY/NN/DD
    quietly save "`dir'/ev_recur.dta", replace

    * E9 same-day duplicate events for one person
    clear
    quietly input long pid int evdate
        1 21930
        1 21930
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_samedate_dup.dta", replace

    * E10 primary and competing event on the same day
    clear
    quietly input long pid int evdate byte compev
        1 21930 1
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_compete_sameday.dta", replace

    * E11 competing event on a different day
    clear
    quietly input long pid int evdate byte compev
        1 21930 0
        2 21925 1
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_compete.dta", replace

    * E12 all-missing event dates
    clear
    quietly input long pid int evdate
        1 .
        2 .
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_allmiss.dta", replace

    * E13 empty event dataset
    clear
    quietly input long pid int evdate
        1 21930
    end
    quietly drop in 1
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_empty.dta", replace

    * E14 event with keepvars payload: string, value label, format, char
    clear
    quietly input long pid int evdate byte cause double sev str5 clinic
        1 21930 1 3.5 "CL001"
        2 21925 2 1.25 "CL002"
    end
    label define _causelbl 1 "relapse" 2 "death"
    label values cause _causelbl
    label variable cause "Event cause"
    format evdate %tdCCYY/NN/DD
    format sev %9.3f
    char sev[myown] "payload"
    quietly save "`dir'/ev_keep.dta", replace

    * E15 string ID events
    use "`dir'/ev_inside.dta", clear
    quietly generate str8 sid = "P" + string(pid, "%04.0f")
    quietly drop pid
    quietly save "`dir'/ev_inside_str.dta", replace

    * E16 strL ID events
    use "`dir'/ev_inside.dta", clear
    quietly generate strL lid = "P" + string(pid)
    quietly save "`dir'/ev_inside_strl.dta", replace

    * E17 an event inside BOTH of two distinct overlapping intervals
    clear
    quietly input long pid int evdate
        1 21935
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_ambig.dta", replace

    * E18 events for every person, several splitting internally. This is the
    * general case that exercises split and no-split intervals side by side in
    * a single call.
    clear
    quietly input long pid int evdate
        1 21930
        2 21920
        3 21915
        4 21950
    end
    format evdate %tdCCYY/NN/DD
    label variable evdate "Event date"
    quietly save "`dir'/ev_mixed.dta", replace

    * E19 out-of-bounds events for two people alongside an internal event for a
    * third. Section 10.3 requires the outside cases; on their own they leave
    * zero observations (r2000, case V05), so this fixture also carries a
    * surviving splitter.
    clear
    quietly input long pid int evdate
        1 21000
        2 22999
        4 21950
    end
    format evdate %tdCCYY/NN/DD
    quietly save "`dir'/ev_mixed_outside.dta", replace

    * E20 recurring events on the OVERLAPPING intervals, one landing exactly on
    * the stop of one interval while strictly inside another. This is the only
    * configuration that reaches the released `_valid_split' re-filter: the
    * point engine already restricts split discovery to start <= date < stop, so
    * a date can only arrive at an interval it does not split by having been
    * joined across a person's other interval. Fault injection confirmed the
    * earlier fixture set could NOT detect a `<' -> `<=' change to that filter.
    clear
    quietly input long pid int evdate1 int evdate2
        1 21944 21950
    end
    format evdate1 evdate2 %tdCCYY/NN/DD
    quietly save "`dir'/ev_stop_and_inside.dta", replace

    * I9 NESTED intervals for one person, with different split dates each.
    * This is the only geometry in which the coordinate key (id, start, stop)
    * and the key (id, stop, start) order the coordinates differently: for
    * abutting or partially overlapping intervals the two orders agree, so no
    * earlier fixture could detect a builder that indexed coordinates one way
    * and payload rows the other. Fault injection confirmed exactly that.
    clear
    quietly input long pid int i_start int i_stop byte trt
        1 21915 21980 1
        1 21930 21960 2
        2 21915 21944 1
    end
    format i_start i_stop %tdCCYY/NN/DD
    quietly save "`dir'/ivl_nested.dta", replace

    * E21 one date inside both nested intervals, one inside only the outer.
    * The two coordinates must therefore end with DIFFERENT segment counts;
    * with equal counts a swapped index would still produce matching output.
    clear
    quietly input long pid int evdate1 int evdate2
        1 21940 21970
    end
    format evdate1 evdate2 %tdCCYY/NN/DD
    quietly save "`dir'/ev_nested.dta", replace

**# ---------------------------------------------------------------------
**# Cases
**# ---------------------------------------------------------------------

* V01 event strictly inside an interval: the core split
use "`dir'/ev_inside.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V01_inside `=_rc'

* V02 the identical call from frame(), built from byte-identical intervals
capture frame drop fivl
frame create fivl
frame fivl: use "`dir'/ivl_base.dta", clear
use "`dir'/ev_inside.dta", clear
capture noisily tvevent, frame(fivl) ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V02_inside_frame `=_rc'
capture frame drop fivl

* V03 event exactly at start
use "`dir'/ev_at_start.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V03_at_start `=_rc'

* V04 event exactly at stop: flagged without a split
use "`dir'/ev_at_stop.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V04_at_stop `=_rc'

* V05 events before entry and after exit
use "`dir'/ev_outside.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) validate
_tvb_record V05_outside `=_rc'

* V06 event on a one-day interval
use "`dir'/ev_oneday.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V06_oneday `=_rc'

* V07 several internal dates in one interval, event rows unsorted
use "`dir'/ev_multi_wide.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring)
_tvb_record V07_multi_internal `=_rc'

* V08 the same three dates already sorted: output must be identical to V07
use "`dir'/ev_multi_wide_sorted.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring)
_tvb_record V08_multi_internal_sorted `=_rc'

* V09 recurring events across several people
use "`dir'/ev_recur.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring)
_tvb_record V09_recurring `=_rc'

* V10 recurring with enum() and the gap-time clock
use "`dir'/ev_recur.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring) ///
    enum(evnum) gaptime
_tvb_record V10_recur_enum_gap `=_rc'

* V11 recurring with a total-time clock via timegen()
use "`dir'/ev_recur.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring) ///
    timegen(tt) timeunit(days)
_tvb_record V11_recur_totaltime `=_rc'

* V12 same-day duplicate events
use "`dir'/ev_samedate_dup.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) validate
_tvb_record V12_samedate_dup `=_rc'

* V13 primary and competing event on the same day
use "`dir'/ev_compete_sameday.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) compete(compev) validate
_tvb_record V13_compete_sameday `=_rc'

* V14 competing events on different days
use "`dir'/ev_compete.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) compete(compev)
_tvb_record V14_compete `=_rc'

* V15 duplicate interval coordinates with distinct payloads
use "`dir'/ev_inside.dta", clear
capture noisily tvevent using "`dir'/ivl_paydup.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V15_paydup `=_rc'

* V16 an event inside two distinct overlapping intervals
use "`dir'/ev_ambig.dta", clear
capture noisily tvevent using "`dir'/ivl_overlap.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V16_ambiguous `=_rc'

* V17 all-missing event dates
use "`dir'/ev_allmiss.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V17_allmissing `=_rc'

* V18 empty event dataset
use "`dir'/ev_empty.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V18_empty_events `=_rc'

* V19 quantity algebra: rate, total, cumulative together
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_qty.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) ///
    rate(rateq) total(totq) cumulative(cumq)
_tvb_record V19_quantities `=_rc'

* V20 the deprecated continuous() alias
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) continuous(totq)
_tvb_record V20_continuous_alias `=_rc'

* V21 keepvars(): string payload, value labels, formats, characteristics
use "`dir'/ev_keep.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) keepvars(cause sev clinic)
_tvb_record V21_keepvars `=_rc'

* V22 generate() and eventlabel(). eventlabel() takes `value "Label"' pairs,
* not a bare string; a bare string is r(198), which V22b pins.
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) ///
    generate(relapse) eventlabel(0 "Alive" 1 "Relapse")
_tvb_record V22_generate_label `=_rc'

* V22b a malformed eventlabel() argument
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 1982
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) ///
    generate(relapse) eventlabel("Relapse event")
_tvb_record V22b_bad_eventlabel_err `=_rc'

* V23 flow accounting
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) flow
_tvb_record V23_flow `=_rc'

* V24 string ID
use "`dir'/ev_inside_str.dta", clear
capture noisily tvevent using "`dir'/ivl_base_str.dta", ///
    id(sid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V24_string_id `=_rc'

* V25 the general mixed case: split and no-split intervals in one call
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) verbose
_tvb_record V25_mixed `=_rc'

* V26 legacy startvar()/stopvar() spellings
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) startvar(i_start) stopvar(i_stop)
_tvb_record V26_legacy_names `=_rc'

* V27 dropinvalid on malformed intervals
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_bad.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) dropinvalid flow
_tvb_record V27_dropinvalid `=_rc'

* V28 the same malformed intervals WITHOUT dropinvalid: caller must survive
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 4242
capture noisily tvevent using "`dir'/ivl_bad.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V28_malformed_err `=_rc'

* V29 replace policy: an output name already present in the interval data
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 110
capture noisily tvevent using "`dir'/ivl_hasfail.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V29_exists_err `=_rc'

* V30 the same call WITH replace
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_hasfail.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) replace
_tvb_record V30_replace `=_rc'

* V31 date-stub collision in the interval data
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 1101
capture noisily tvevent using "`dir'/ivl_stub.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V31_stub_collision_err `=_rc'

* V32 strL id in the master (event) dataset
use "`dir'/ev_inside_strl.dta", clear
quietly generate double caller_marker = 109
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(lid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V32_strl_master_err `=_rc'

* V33 strL id in the using (interval) dataset
use "`dir'/ev_inside.dta", clear
quietly generate strL lid = "P" + string(pid)
quietly generate double caller_marker = 1091
capture noisily tvevent using "`dir'/ivl_base_strl.dta", ///
    id(lid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V33_strl_using_err `=_rc'

* V34 a using file that does not exist
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 601
capture noisily tvevent using "`dir'/ivl_absent.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V34_missing_file_err `=_rc'

* V35 a missing interval variable
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 111
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(nosuchvar) stop(i_stop)
_tvb_record V35_missing_var_err `=_rc'

* V36 neither using nor frame()
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 198
capture noisily tvevent, id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V36_no_source_err `=_rc'

* V37 both using and frame()
capture frame drop fivl
frame create fivl
frame fivl: use "`dir'/ivl_base.dta", clear
use "`dir'/ev_mixed.dta", clear
quietly generate double caller_marker = 1981
capture noisily tvevent using "`dir'/ivl_base.dta", frame(fivl) ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V37_both_sources_err `=_rc'
capture frame drop fivl

* V38 zero-variable caller with observations: restorable state is just _N
clear
quietly set obs 7
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop)
_tvb_record V38_zerovar_caller `=_rc'

* V39 the mixed case with every diagnostic switch on at once
use "`dir'/ev_mixed.dta", clear
capture noisily tvevent using "`dir'/ivl_qty.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) ///
    validate flow verbose rate(rateq) total(totq) cumulative(cumq)
_tvb_record V39_all_diagnostics `=_rc'

* V40 recurring events with total() apportionment across split segments
use "`dir'/ev_recur.dta", clear
capture noisily tvevent using "`dir'/ivl_qty.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring) ///
    total(totq) rate(rateq) cumulative(cumq)
_tvb_record V40_recur_quantities `=_rc'

* V41 outside-bounds and internal events in the SAME call: the dropped rows
* must not disturb the segments built for the surviving ones.
use "`dir'/ev_mixed_outside.dta", clear
capture noisily tvevent using "`dir'/ivl_base.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) validate flow
_tvb_record V41_outside_and_inside `=_rc'

* V42 an event at one interval's stop that is strictly inside another interval
* of the same person. The first interval must be flagged without a split; the
* second must split. Reaches the cross-interval `_valid_split' re-filter.
use "`dir'/ev_stop_and_inside.dta", clear
capture noisily tvevent using "`dir'/ivl_overlap.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring)
_tvb_record V42_stop_and_inside `=_rc'

* V43 nested intervals with different split counts. Pins that each coordinate
* receives its own segments: the outer interval three, the inner two.
use "`dir'/ev_nested.dta", clear
capture noisily tvevent using "`dir'/ivl_nested.dta", ///
    id(pid) date(evdate) start(i_start) stop(i_stop) type(recurring)
_tvb_record V43_nested_intervals `=_rc'

**# ---------------------------------------------------------------------
**# Summary
**# ---------------------------------------------------------------------
if "`mode'" == "capture" {
    display "BASELINE: capture complete -> `dir'"
}
else {
    local p = $TVB_PASS
    local f = $TVB_FAIL
    display "BASELINE: tvevent_surface cases=`=`p'+`f'' match=`p' drift=`f'"
    if `f' > 0 {
        display as error "baseline drift in:$TVB_FAILED"
        exit 9
    }
}
