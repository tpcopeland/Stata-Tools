* baseline_tvexpose_surface.do
* Behavioural baseline capture and differential replay for tvexpose.
*
* Implements Section 7.3 of the tvtools single-pass plan for the tvexpose
* scope: for every case, the complete output dataset, observation and variable
* order, sortedby, dataset label, storage types, formats, variable labels,
* value-label names AND definitions, the three tvtools_* characteristics, the
* public r() surface, negative-path return codes, and caller state after
* success and error.
*
* Case coverage is driven by Section 11.4's required fast-path matrix. The
* E-series are the calls that Section 11.1 declares eligible for the Phase 3
* categorical fast path; the X-series are their nearest ineligible neighbours,
* one per excluded option family plus every overlap geometry; the S-series are
* state and negative paths that must keep their released behaviour whichever
* engine runs.
*
* Manually invoked. Deliberately NOT in any correctness lane and NOT in
* qa/_tvtools_qa_manifest.do: it emits a BASELINE: line, never a RESULT: line,
* because its verdict depends on a capture directory produced by a different
* build of the package.
*
* Usage (from the package's qa/ directory):
*   stata-mp -b do baseline_tvexpose_surface.do capture <dir>
*   stata-mp -b do baseline_tvexpose_surface.do compare <dir>
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
* lives in validation_tvexpose.do, validation_audit_tvexpose.do, and
* crossval_tvexpose_expand.do.
*
* Every fixture this harness writes carries a tvxb_ prefix AND a stem that no
* tracked fixture uses. Two of the obvious names collided with canonical
* fixtures in data/, and tools/fixture_manifest.py --check reported a
* producer/consumer mismatch for them -- which is how the collision was found.
* Prefixing alone was not enough: the manifest scanner matches a filename
* anywhere in the text, so a name that merely CONTAINS a tracked one still
* registers as a consumer of it. Keep both the prefix and a distinct stem on
* anything added here, and do not spell a tracked fixture name out even in a
* comment.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local mode "`1'"
local dir  "`2'"
if !inlist("`mode'", "capture", "compare") {
    display as error "usage: baseline_tvexpose_surface.do {capture|compare} <dir>"
    exit 198
}
if "`dir'" == "" {
    display as error "a capture directory is required"
    exit 198
}
capture mkdir "`dir'"

local qadir "`c(pwd)'"
adopath ++ "`qadir'/.."

* Provenance. A capture taken against the installed package and replayed
* against the working tree would compare a build with itself and report zero
* drift for any change whatsoever. Print the resolved path so the log records
* which tvexpose.ado produced the numbers.
capture findfile tvexpose.ado
if _rc {
    display as error "BASELINEBAD: tvexpose.ado not found on the adopath"
    exit 111
}
display as text "BASELINEADO: `r(fn)'"

global TVX_PASS = 0
global TVX_FAIL = 0
global TVX_FAILED ""
global TVX_MODE  "`mode'"
global TVX_DIR   "`dir'"

display as result "tvtools baseline (tvexpose surface): `mode' -- $S_DATE $S_TIME"

**# ---------------------------------------------------------------------
**# Recorder
**# ---------------------------------------------------------------------
* _tvx_record must run IMMEDIATELY after the command under test: every
* describe, confirm, count, or file command below replaces r().

capture program drop _tvx_record
program define _tvx_record
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
        * directory differs between runs and every internal tempfile name
        * changes per process. Normalise both so a real contract change is not
        * buried under noise -- and so a leaked tempfile path is still visible
        * as <tempfile> when it should have disappeared entirely.
        * r(combine_map) legitimately contains double quotes (101="1+2").
        * Embedding one unescaped inside the record line ends the string early
        * and the whole harness dies at r(132) two cases later, so neutralise
        * the quote character itself while keeping the value comparable.
        local _dq `"""'
        local v : subinstr local v `"`_dq'"' "<q>", all
        local v : subinstr local v "$TVX_DIR" "<dir>", all
        local v : subinstr local v "`c(tmpdir)'" "<tmp>", all
        local vnorm ""
        foreach tok of local v {
            if regexm("`tok'", "St[0-9]+\.[0-9]+") local tok "<tempfile>"
            local vnorm "`vnorm' `tok'"
        }
        local vnorm = trim("`vnorm'")
        local rmvals `"`rmvals' `nm'="`vnorm'""'
    }
    * r(flow) is a matrix in tvexpose; record its cells, not just its name, so
    * a flow-accounting change cannot pass as a matching matrix list.
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

    local dir "$TVX_DIR"
    local mode "$TVX_MODE"

    * Structural and metadata description of the current data.
    local nobs = _N
    local nvar = c(k)
    local sortby : sortedby
    local dtalab : data label
    * tvexpose stamps the using path as the dataset label, so the label is
    * capture-directory dependent by construction.
    local dtalab : subinstr local dtalab "`dir'" "<dir>", all
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
            local _dq `"""'
            foreach x of local _lv {
                local d : label `vl' `x', strict
                local d : subinstr local d `"`_dq'"' "<q>", all
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
        global TVX_PASS = $TVX_PASS + 1
        display as result "  MATCH `tag'"
    }
    else {
        global TVX_FAIL = $TVX_FAIL + 1
        global TVX_FAILED "$TVX_FAILED `tag'"
        display as error "  DRIFT `tag': `detail'"
    }
end

**# ---------------------------------------------------------------------
**# Deterministic fixtures
**# ---------------------------------------------------------------------
* Every generated tie carries an explicit original-row tie-break, so no result
* below depends on the sort seed.
*
* Built at top level, not inside a program: several fixtures use `input',
* whose terminating `end' would close a program definition instead of the
* input block.
*
* Calendar anchor: 21915 = 01jan2020.

**# --- master (caller) datasets ------------------------------------------

* M1 the workhorse master. Five persons with deliberately different window
* shapes: two full-year windows, one late/short window, a ONE-DAY window, and
* a person who owns no exposure episode at all in exp_clean.dta. Carries the
* metadata classes the parity contract names: value label, variable labels,
* display formats, a string payload, and a dataset label.
clear
quietly input long pid int s_entry int s_exit byte sex str6 site
    1 21915 22279 1 "north"
    2 21915 22279 0 "south"
    3 21930 22000 1 "north"
    4 21915 21915 0 "east"
    5 21915 22279 1 "west"
end
label define _sexlbl 0 "female" 1 "male"
label values sex _sexlbl
label variable sex "Sex at birth"
label variable s_entry "Study entry"
label variable s_exit "Study exit"
format s_entry s_exit %tdCCYY/NN/DD
label data "tvexpose baseline master"
quietly save "`dir'/tvxb_mas_base.dta", replace

* M2 the same master keyed by a fixed-width string id.
use "`dir'/tvxb_mas_base.dta", clear
quietly generate str8 sid = "P" + string(pid, "%04.0f")
quietly drop pid
quietly order sid
quietly save "`dir'/tvxb_mas_str.dta", replace

* M3 every window is a single day. Separates one-day-window handling from the
* single one-day person carried by M1.
clear
quietly input long pid int s_entry int s_exit
    1 21915 21915
    2 21920 21920
    3 21930 21930
end
format s_entry s_exit %tdCCYY/NN/DD
quietly save "`dir'/tvxb_mas_oneday.dta", replace

* M4 a master keyed by a strL id. strL keys must keep their released refusal.
use "`dir'/tvxb_mas_base.dta", clear
quietly generate strL lid = "P" + string(pid)
quietly save "`dir'/tvxb_mas_strl.dta", replace

**# --- exposure (using) datasets -----------------------------------------

* X1 the workhorse eligible source: clean, non-overlapping, inside every
* window, no reference-coded row, whole-number codes, a value label on the
* exposure column. Person 5 deliberately owns no row.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21959 1
    1 21990 22019 2
    2 21920 21949 1
    3 21940 21969 2
    4 21915 21915 1
end
label define _druglbl 1 "low" 2 "high"
label values drug _druglbl
label variable drug "Drug class"
label variable e_start "Episode start"
format e_start e_stop %tdCCYY/NN/DD
label data "tvexpose baseline episodes"
quietly save "`dir'/tvxb_src_clean.dta", replace

* X1b the same episodes with NO value label on the exposure column. This is
* the branch that builds a fresh _tvlbl_<name> definition instead of
* modifying an inherited one; without it that branch is untested.
use "`dir'/tvxb_src_clean.dta", clear
label values drug
label variable drug ""
quietly save "`dir'/tvxb_src_nolabel.dta", replace

* X2 a NON-EMPTY source whose every row clips out of its person's window.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21000 21100 1
    2 22500 22600 1
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_allclip.dta", replace

* X3 source ids absent from the master, mixed with a matched row.
clear
quietly input long pid int e_start int e_stop byte drug
     1 21930 21959 1
    98 21930 21959 2
    99 21930 21959 1
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_unmatched.dta", replace

* X4 episodes clipped at entry, at exit, at both ends, and wholly outside the
* window in each direction.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21900 21929 1
    1 22270 22300 2
    2 21900 22300 1
    3 21000 21100 1
    5 22500 22600 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_clip.dta", replace

* X5 adjacent same-category, adjacent different-category, and a positive
* uncovered gap. Section 11.2 item 6 forbids collapsing adjacent equal
* categories, and item 7 emits a reference row only for a positive gap, so
* these three geometries separate a correct builder from a plausible one.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21915 21944 1
    1 21945 21974 1
    1 21975 22004 2
    2 21930 21959 1
    2 21990 22019 1
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_adjacent.dta", replace

* X6 negative, zero, and positive whole-number category codes together. Run
* with reference(-5) so that ZERO is an ordinary exposed category rather than
* the reference, which is the only way a zero code is actually exercised.
clear
quietly input long pid int e_start int e_stop int drug
    1 21930 21959 -2
    2 21930 21959  0
    3 21940 21969  7
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_codes.dta", replace

* X7 a reference-coded source episode. Legal on the public surface; Section
* 11.1 keeps it OFF the first fast path.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21959 0
    2 21930 21959 1
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_refcoded.dta", replace

* X8 a non-integer exposure code. label define refuses 1.5 (r198), so the
* existing value-label behaviour is not a safe first fast-path target.
clear
quietly input long pid int e_start int e_stop double drug
    1 21930 21959 1.5
    2 21930 21959 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_noninteger.dta", replace

* X9-X13 the five overlap geometries the eligibility preflight must reject.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21969 1
    1 21950 21989 1
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_ov_same.dta", replace

clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21969 1
    1 21950 21989 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_ov_diff.dta", replace

clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21999 1
    1 21950 21969 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_nested.dta", replace

clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21959 1
    1 21930 21959 1
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_dup.dta", replace

clear
quietly input long pid int e_start int e_stop byte drug
    1 21930 21959 1
    1 21959 21989 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_endpoint.dta", replace

* X14 one-day episodes only, for the one-day-window master.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21915 21915 1
    2 21920 21920 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_oneday.dta", replace

* X15 string-id episodes matching mst_str.dta.
use "`dir'/tvxb_src_clean.dta", clear
quietly generate str8 sid = "P" + string(pid, "%04.0f")
quietly drop pid
quietly order sid
quietly save "`dir'/tvxb_src_clean_str.dta", replace

* X16 an empty using dataset: zero rows, correct schema.
use "`dir'/tvxb_src_clean.dta", clear
quietly drop in 1/`=_N'
quietly save "`dir'/tvxb_src_empty.dta", replace

* X17 malformed source rows: a missing start date and a reversed interval.
clear
quietly input long pid int e_start int e_stop byte drug
    1     . 21959 1
    2 21990 21930 1
    3 21940 21969 2
end
format e_start e_stop %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_malformed.dta", replace

* X18 point-in-time episodes (no stop column at all).
clear
quietly input long pid int e_start byte drug
    1 21930 1
    2 21920 1
end
format e_start %tdCCYY/NN/DD
quietly save "`dir'/tvxb_src_point.dta", replace

* X19 episodes carrying a payload column for keepvars-style calls.
use "`dir'/tvxb_src_clean.dta", clear
quietly save "`dir'/tvxb_src_payload.dta", replace

**# ---------------------------------------------------------------------
**# E-series: calls Section 11.1 declares ELIGIBLE
**# ---------------------------------------------------------------------

* E01 the bare eligible call, default generated name.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E01_default `=_rc'

* E02 explicit generate().
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) generate(myexp)
_tvx_record E02_generate `=_rc'

* E03 keepdates: the study bounds survive into the output, ordered last, with
* their master labels and formats restored.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) keepdates
_tvx_record E03_keepdates `=_rc'

* E04 referencelabel() and label() together: the reference category label and
* the output variable label are both observable contract.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) referencelabel("No drug") label("Drug exposure")
_tvx_record E04_labels `=_rc'

* E05 a source with NO value label on the exposure column. Exercises the
* branch that defines _tvlbl_<name> from scratch rather than modifying an
* inherited definition.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_nolabel.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E05_no_source_label `=_rc'

* E06 fixed-width string ids.
use "`dir'/tvxb_mas_str.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean_str.dta", ///
    id(sid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E06_string_id `=_rc'

* E07 a non-empty source whose every row clips out: all person-time becomes
* reference, and the command must still emit one row per person.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_allclip.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E07_all_clip_out `=_rc'

* E08 source ids absent from the master.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_unmatched.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E08_unmatched_ids `=_rc'

* E09 episodes clipped at entry, at exit, at both, and wholly outside.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clip.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E09_clipped `=_rc'

* E10 adjacent same-category, adjacent different-category, and a positive
* uncovered gap in one call.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_adjacent.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E10_adjacent_and_gap `=_rc'

* E11 negative, zero, and positive whole-number codes with a negative
* reference.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_codes.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(-5) ///
    entry(s_entry) exit(s_exit)
_tvx_record E11_signed_codes `=_rc'

* E12 one-day study windows with one-day episodes.
use "`dir'/tvxb_mas_oneday.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_oneday.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E12_oneday `=_rc'

* E13 frameout() creating a new frame. Two records: the caller frame (which
* must be byte-identical to the input master) with the r() surface, then the
* created frame's contents.
use "`dir'/tvxb_mas_base.dta", clear
capture frame drop tvxout
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) frameout(tvxout)
_tvx_record E13_frameout_new_caller `=_rc'
capture frame change tvxout
_tvx_record E13_frameout_new_frame 0 nor
capture frame change default
capture frame drop tvxout

* E14 frameout() replacing an existing frame.
use "`dir'/tvxb_mas_base.dta", clear
capture frame drop tvxout
frame create tvxout
frame tvxout: quietly set obs 3
frame tvxout: quietly generate byte junk = _n
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) frameout(tvxout) replace
_tvx_record E14_frameout_replace_caller `=_rc'
capture frame change tvxout
_tvx_record E14_frameout_replace_frame 0 nor
capture frame change default
capture frame drop tvxout

* E15 frameout() naming an existing frame WITHOUT replace: released r(110)
* before any mutation, and the target frame must be untouched.
use "`dir'/tvxb_mas_base.dta", clear
capture frame drop tvxout
frame create tvxout
frame tvxout: quietly set obs 3
frame tvxout: quietly generate byte junk = _n
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) frameout(tvxout)
_tvx_record E15_frameout_norepl_caller `=_rc'
capture frame change tvxout
_tvx_record E15_frameout_norepl_frame 0 nor
capture frame change default
capture frame drop tvxout

* E16 the same call issued twice in one session. Pins that no engine leaves
* state behind that changes the second answer.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E16_repeated_call `=_rc'

* E17 a fresh call after discard, which drops every program from memory and
* forces the helper loader to resolve again.
discard
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record E17_after_discard `=_rc'

* E18 an id/start/stop name set that differs from the reserved internal
* working names in every position, so the closing rename gate is exercised.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) generate(tvdrug) referencelabel("Off drug")
_tvx_record E18_renamed_bounds `=_rc'

**# ---------------------------------------------------------------------
**# X-series: nearest INELIGIBLE neighbours
**# ---------------------------------------------------------------------
* Section 11.1 excludes each of these. Every one must keep producing exactly
* the released answer, because the fast path must never claim it.

* --- data predicates ---------------------------------------------------

* X01 a reference-coded source episode.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_refcoded.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X01_reference_coded `=_rc'

* X02 a non-integer exposure code.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_noninteger.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X02_noninteger_code `=_rc'

* X03 a non-integer reference.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0.5) ///
    entry(s_entry) exit(s_exit)
_tvx_record X03_noninteger_reference `=_rc'

* X04 same-class overlap.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_ov_same.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X04_overlap_same_class `=_rc'

* X05 different-class overlap: the released default is layer-style
* resolution, which is exactly why an overlap may not reach the fast path.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_ov_diff.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X05_overlap_diff_class `=_rc'

* X06 nesting.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_nested.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X06_nested `=_rc'

* X07 exact duplicate episodes.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_dup.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X07_exact_duplicate `=_rc'

* X08 a shared endpoint: one day of overlap only.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_endpoint.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record X08_shared_endpoint `=_rc'

* --- excluded option families -----------------------------------------

* X09 pointtime (and therefore no stop()).
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_point.dta", ///
    id(pid) start(e_start) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) pointtime
_tvx_record X09_pointtime `=_rc'

* X10 merge()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_adjacent.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) merge(30)
_tvx_record X10_merge `=_rc'

* X11 lag()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) lag(10)
_tvx_record X11_lag `=_rc'

* X12 washout()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) washout(10)
_tvx_record X12_washout `=_rc'

* X13 fillgaps()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) fillgaps(10)
_tvx_record X13_fillgaps `=_rc'

* X14 carryforward()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_adjacent.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) carryforward(10)
_tvx_record X14_carryforward `=_rc'

* X15 grace()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_adjacent.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) grace(45)
_tvx_record X15_grace `=_rc'

* X16 evertreated
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) evertreated
_tvx_record X16_evertreated `=_rc'

* X17 currentformer
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) currentformer
_tvx_record X17_currentformer `=_rc'

* X18 duration()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) duration(1 5)
_tvx_record X18_duration `=_rc'

* X19 dose
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) ///
    entry(s_entry) exit(s_exit) dose
_tvx_record X19_dose `=_rc'

* X20 continuousunit()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) continuousunit(years)
_tvx_record X20_continuous `=_rc'

* X21 recency()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) recency(30) recencyunit(days)
_tvx_record X21_recency `=_rc'

* X22 bytype
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) evertreated bytype
_tvx_record X22_bytype `=_rc'

* X23 window()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) window(1 7)
_tvx_record X23_window `=_rc'

* X24 switching
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) switching
_tvx_record X24_switching `=_rc'

* X25 switchingdetail
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) switchingdetail
_tvx_record X25_switchingdetail `=_rc'

* X26 statetime
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) statetime
_tvx_record X26_statetime `=_rc'

* X27 priority()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_ov_diff.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) priority(2 1)
_tvx_record X27_priority `=_rc'

* X28 split
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_ov_diff.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) split
_tvx_record X28_split `=_rc'

* X29 layer, named explicitly rather than reached as the default.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_ov_diff.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) layer
_tvx_record X29_layer `=_rc'

* X30 combine()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_ov_diff.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) combine(combo)
_tvx_record X30_combine `=_rc'

* X31 keepvars()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) keepvars(sex site)
_tvx_record X31_keepvars `=_rc'

* X32 check
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) check
_tvx_record X32_check `=_rc'

* X33 gaps
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_adjacent.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) gaps
_tvx_record X33_gaps `=_rc'

* X34 overlaps
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) overlaps
_tvx_record X34_overlaps `=_rc'

* X35 summarize
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) summarize
_tvx_record X35_summarize `=_rc'

* X36 validate. The validation dataset is written to tv_validation.dta in the
* working directory and, without replace, the SECOND run of this harness in
* the same directory fails at r(602) -- which is how the capture/compare
* self-check found it. replace makes the case repeatable; the artifact is
* erased so no run leaves one behind.
capture erase "tv_validation.dta"
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) validate replace
_tvx_record X36_validate `=_rc'
capture erase "tv_validation.dta"

* X37 flow
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) flow
_tvx_record X37_flow `=_rc'

* X38 dropinvalid, on data that actually has invalid rows.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_malformed.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) dropinvalid
_tvx_record X38_dropinvalid `=_rc'

* X39 verbose
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) verbose
_tvx_record X39_verbose `=_rc'

* X40 saveas()
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) saveas("`dir'/tvxb_x40_out.dta") replace
_tvx_record X40_saveas `=_rc'

**# ---------------------------------------------------------------------
**# S-series: state and negative paths
**# ---------------------------------------------------------------------

* S01 an empty using dataset: released error, caller untouched.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_empty.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S01_empty_using `=_rc'

* S02 malformed source rows WITHOUT dropinvalid: released r(498), caller
* untouched. Neither engine may be reached.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_malformed.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S02_malformed_strict `=_rc'

* S03 a using file that does not exist.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_no_such_file.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S03_missing_using `=_rc'

* S04 a strL id in the master.
use "`dir'/tvxb_mas_strl.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(lid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S04_strl_id `=_rc'

* S05 an output-name collision resolved by the namespace preflight, before
* any data are touched.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) generate(pid)
_tvx_record S05_name_collision `=_rc'

* S06 reference() omitted.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) ///
    entry(s_entry) exit(s_exit)
_tvx_record S06_no_reference `=_rc'

* S07 neither stop() nor pointtime.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S07_no_stop_no_pointtime `=_rc'

* S08 a zero-observation master.
use "`dir'/tvxb_mas_base.dta", clear
quietly drop in 1/`=_N'
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S08_empty_master `=_rc'

* S09 a master with a reversed study window and no dropinvalid.
use "`dir'/tvxb_mas_base.dta", clear
quietly replace s_exit = s_entry - 10 in 2
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S09_reversed_window `=_rc'

* S10 a late failure on an otherwise successful eligible-shaped call: the
* saveas() target directory does not exist. Everything analytical has already
* succeeded, so this is the shared caller-restore contract, not an eligibility
* refusal. saveas() is itself outside the fast-path predicate, which is why
* the case is recorded here rather than in the E series.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit) saveas("`dir'/no_such_dir/out.dta")
_tvx_record S10_late_saveas_failure `=_rc'

* S11 an `if' qualifier. tvexpose's syntax declares `using/' with no [if],
* so the released command refuses this with r(101); the marksample call
* inside it therefore always marks the whole caller dataset. Recorded as the
* released contract, not as a supported restriction.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta" if sex == 1, ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S11_if_refused `=_rc'

* S12 the same for `in'.
use "`dir'/tvxb_mas_base.dta", clear
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta" in 1/3, ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S12_in_refused `=_rc'

* S13 a zero-variable caller holding only observations. The restorable state
* is just _N, and the command must refuse rather than construct anything.
clear
quietly set obs 7
capture noisily tvexpose using "`dir'/tvxb_src_clean.dta", ///
    id(pid) start(e_start) stop(e_stop) exposure(drug) reference(0) ///
    entry(s_entry) exit(s_exit)
_tvx_record S13_zerovar_caller `=_rc'

**# ---------------------------------------------------------------------
**# Summary
**# ---------------------------------------------------------------------
if "`mode'" == "capture" {
    display "BASELINE: capture complete -> `dir'"
}
else {
    local p = $TVX_PASS
    local f = $TVX_FAIL
    display "BASELINE: tvexpose_surface cases=`=`p'+`f'' match=`p' drift=`f'"
    if `f' > 0 {
        display as error "baseline drift in:$TVX_FAILED"
        exit 9
    }
}
