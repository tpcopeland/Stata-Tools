* baseline_tvmerge_surface.do
* Behavioural baseline capture and differential replay for tvmerge.
*
* Implements Section 7.3 of the tvtools single-pass plan: for every case, the
* complete output dataset, observation and variable order, storage types,
* formats, labels, characteristics, public r() surface, negative-path return
* codes, and caller state after success and error.
*
* Manually invoked. Deliberately NOT in any correctness lane and NOT in
* qa/_tvtools_qa_manifest.do: it emits a BASELINE: line, never a RESULT: line,
* because its verdict depends on a capture directory produced by a different
* build of the package.
*
* Usage (from the package's qa/ directory):
*   stata-mp -b do baseline_tvmerge_surface.do capture <dir>
*   stata-mp -b do baseline_tvmerge_surface.do compare <dir>
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
* lives in the validation_* and crossval_* suites.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local mode "`1'"
local dir  "`2'"
if !inlist("`mode'", "capture", "compare") {
    display as error "usage: baseline_tvmerge_surface.do {capture|compare} <dir>"
    exit 198
}
if "`dir'" == "" {
    display as error "a capture directory is required"
    exit 198
}
capture mkdir "`dir'"

local qadir "`c(pwd)'"
capture ado uninstall tvtools
while !_rc {
    capture ado uninstall tvtools
}
adopath ++ "`qadir'/.."

global TVB_PASS = 0
global TVB_FAIL = 0
global TVB_FAILED ""
global TVB_MODE  "`mode'"
global TVB_DIR   "`dir'"

display as result "tvtools baseline (tvmerge surface): `mode' -- $S_DATE $S_TIME"

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
        * directory differs between runs, and a `frames()' input is currently
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
        * Value-label DEFINITIONS, not just the assigned name: two frames can
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
        file write `fh' "matrices:`rt'" _n
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
        if `"`basemx'"' != "matrices:`rt'" {
            local ok = 0
            local detail "`detail' r() matrices"
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

    * --- A: master exposure episodes, numeric id ---------------------------
    clear
    quietly set obs 12
    quietly generate long pid = ceil(_n / 3)
    quietly bysort pid: generate int seq = _n
    quietly generate int a_start = mdy(1, 1, 2020) + (seq - 1) * 40
    quietly generate int a_stop  = a_start + 29
    quietly generate byte drugA = mod(pid + seq, 3)
    quietly generate double doseA = 10 * seq
    quietly generate double rateA = 0.5 * seq
    quietly generate double cumA  = 100 * seq
    quietly generate str6 siteA = cond(mod(pid, 2), "north", "south")
    label define _lblA 0 "none" 1 "low" 2 "high"
    label values drugA _lblA
    label variable drugA "Drug A level"
    format a_start a_stop %tdCCYY/NN/DD
    char doseA[tvtools_quantity] "total"
    char rateA[tvtools_quantity] "rate"
    char cumA[tvtools_quantity] "cumulative"
    char cumA[tvtools_history_point] "start"
    quietly drop seq
    quietly save "`dir'/src_a.dta", replace

    * --- B: second source, overlapping, moderate density -------------------
    clear
    quietly set obs 16
    quietly generate long pid = ceil(_n / 4)
    quietly bysort pid: generate int seq = _n
    quietly generate int b_start = mdy(1, 15, 2020) + (seq - 1) * 30
    quietly generate int b_stop  = b_start + 24
    quietly generate byte drugB = mod(pid * seq, 2)
    quietly generate double doseB = 5 * seq
    quietly generate str4 armB = cond(mod(seq, 2), "act", "ctl")
    label define _lblB 0 "off" 1 "on"
    label values drugB _lblB
    format b_start b_stop %tdCCYY/NN/DD
    char doseB[tvtools_quantity] "total"
    quietly drop seq
    quietly save "`dir'/src_b.dta", replace

    * --- C: third source, sparse --------------------------------------------
    clear
    quietly set obs 8
    quietly generate long pid = ceil(_n / 2)
    quietly bysort pid: generate int seq = _n
    quietly generate int c_start = mdy(2, 1, 2020) + (seq - 1) * 70
    quietly generate int c_stop  = c_start + 19
    quietly generate byte drugC = seq
    format c_start c_stop %tdCCYY/NN/DD
    quietly drop seq
    quietly save "`dir'/src_c.dta", replace

    * --- D: disjoint calendar window, produces ZERO overlapping pairs -------
    clear
    quietly set obs 4
    quietly generate long pid = _n
    quietly generate int d_start = mdy(1, 1, 2030)
    quietly generate int d_stop  = mdy(12, 31, 2030)
    quietly generate byte drugD = 1
    format d_start d_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_d.dta", replace

    * --- E/F: one-day and shared-boundary intervals -------------------------
    clear
    quietly input long pid int e_start int e_stop byte drugE
        1 21915 21915 1
        1 21916 21920 2
        2 21915 21925 1
    end
    format e_start e_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_e.dta", replace

    clear
    quietly input long pid int f_start int f_stop byte drugF
        1 21915 21916 7
        1 21920 21920 8
        2 21920 21930 9
    end
    format f_start f_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_f.dta", replace

    * --- G: nested and many-to-many overlaps --------------------------------
    clear
    quietly input long pid int g_start int g_stop byte drugG
        1 21915 21975 1
        1 21930 21940 2
        1 21935 21990 3
        2 21915 21930 4
    end
    format g_start g_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_g.dta", replace

    * --- H: string ID -------------------------------------------------------
    use "`dir'/src_a.dta", clear
    quietly generate str8 sid = "P" + string(pid, "%04.0f")
    quietly drop pid
    quietly save "`dir'/src_a_str.dta", replace
    use "`dir'/src_b.dta", clear
    quietly generate str8 sid = "P" + string(pid, "%04.0f")
    quietly drop pid
    quietly save "`dir'/src_b_str.dta", replace

    * --- I: ID mismatch, for force -----------------------------------------
    use "`dir'/src_b.dta", clear
    quietly replace pid = 99 if pid == 4
    quietly save "`dir'/src_b_idmix.dta", replace

    * --- J: malformed rows, for dropinvalid ---------------------------------
    use "`dir'/src_b.dta", clear
    quietly replace b_stop = . in 1
    quietly replace b_start = b_stop + 5 in 2
    quietly save "`dir'/src_b_bad.dta", replace

    * --- K: within-source overlap, categorical (warning) and total (r459) ---
    clear
    quietly input long pid int k_start int k_stop byte drugK double totK
        1 21915 21945 1 10
        1 21930 21960 2 20
        2 21915 21945 1 30
    end
    format k_start k_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_k_overlap.dta", replace

    * --- M: exact within-source duplicate rows ------------------------------
    * Drives the full-row `duplicates drop' at the end of the merge. Without a
    * source like this every case reports n_duplicates_dropped=0 and that step
    * is unexercised -- verified by fault injection, which the earlier fixture
    * set could not detect.
    * Every id in src_a must appear here, or the ID-set preflight raises r(459)
    * before the merge ever reaches the dedup step.
    clear
    quietly input long pid int m_start int m_stop byte drugM
        1 21915 21945 1
        1 21915 21945 1
        2 21915 21945 2
        3 21915 21945 1
        4 21915 21945 2
    end
    format m_start m_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_m_dup.dta", replace

    * --- N: same interval, DIFFERENT payload --------------------------------
    * The mirror case. These rows must survive: dedup keys on the whole row,
    * never on (id,start,stop) alone.
    clear
    quietly input long pid int n_start int n_stop byte drugN str3 payN
        1 21915 21945 1 "xx"
        1 21915 21945 1 "yy"
        2 21915 21945 2 "zz"
        3 21915 21945 1 "pp"
        4 21915 21945 2 "qq"
    end
    format n_start n_stop %tdCCYY/NN/DD
    quietly save "`dir'/src_n_paydup.dta", replace

    * --- L: payload for keep() ---------------------------------------------
    use "`dir'/src_b.dta", clear
    quietly generate str5 clinic = "C" + string(pid, "%04.0f")
    quietly generate double weightkg = 60 + pid
    label variable weightkg "Body weight (kg)"
    format weightkg %9.2f
    char weightkg[myown] "payload"
    quietly save "`dir'/src_b_payload.dta", replace

**# ---------------------------------------------------------------------
**# Cases
**# ---------------------------------------------------------------------

* B01 two sources, default categorical, file inputs
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B01_two_file `=_rc'

* B02 the same merge from frames(), built from byte-identical data
capture frame drop fa
capture frame drop fb
frame create fa
frame fa: use "`dir'/src_a.dta", clear
frame create fb
frame fb: use "`dir'/src_b.dta", clear
clear
capture noisily tvmerge, frames(fa fb) ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B02_two_frames `=_rc'
capture frame drop fa
capture frame drop fb

* B03 three sources
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta" "`dir'/src_c.dta", ///
    id(pid) start(a_start b_start c_start) stop(a_stop b_stop c_stop) ///
    exposure(drugA drugB drugC)
_tvb_record B03_three_file `=_rc'

* B04 zero overlapping pairs: the documented empty schema
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_d.dta", ///
    id(pid) start(a_start d_start) stop(a_stop d_stop) exposure(drugA drugD)
_tvb_record B04_zero_pairs `=_rc'

* B05 one-day and shared-boundary intervals
use "`dir'/src_e.dta", clear
capture noisily tvmerge "`dir'/src_e.dta" "`dir'/src_f.dta", ///
    id(pid) start(e_start f_start) stop(e_stop f_stop) exposure(drugE drugF)
_tvb_record B05_boundary `=_rc'

* B06 nested and many-to-many overlaps
use "`dir'/src_g.dta", clear
capture noisily tvmerge "`dir'/src_g.dta" "`dir'/src_b.dta", ///
    id(pid) start(g_start b_start) stop(g_stop b_stop) exposure(drugG drugB)
_tvb_record B06_nested `=_rc'

* B07 string ID
use "`dir'/src_a_str.dta", clear
capture noisily tvmerge "`dir'/src_a_str.dta" "`dir'/src_b_str.dta", ///
    id(sid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B07_string_id `=_rc'

* B08 quantity algebra: rate, total, cumulative together
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(doseA doseB) rate(rateA) total(doseA doseB) cumulative(cumA)
_tvb_record B08_quantities `=_rc'

* B09 keep(): string payload, value labels, formats, characteristics
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b_payload.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) keep(clinic weightkg)
_tvb_record B09_keep_payload `=_rc'

* B10 generate()
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) generate(expA expB)
_tvb_record B10_generate `=_rc'

* B11 prefix()
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) prefix(x_)
_tvb_record B11_prefix `=_rc'

* B12 startname/stopname/dateformat
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB) ///
    startname(t0) stopname(t1) dateformat(%tdDD/NN/CCYY)
_tvb_record B12_names `=_rc'

* B13 force with mismatched IDs
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b_idmix.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) force
_tvb_record B13_force `=_rc'

* B14 the same mismatch WITHOUT force: released r(459), caller intact
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 4242
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b_idmix.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B14_idmismatch_err `=_rc'

* B15 dropinvalid
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b_bad.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) dropinvalid flow
_tvb_record B15_dropinvalid `=_rc'

* B16 malformed input WITHOUT dropinvalid: released 498, caller intact
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 777
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b_bad.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B16_malformed_err `=_rc'

* B17 within-source categorical overlap: warning, rows preserved
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_k_overlap.dta" "`dir'/src_a.dta", ///
    id(pid) start(k_start a_start) stop(k_stop a_stop) exposure(drugK drugA)
_tvb_record B17_src_overlap_cat `=_rc'

* B18 within-source total() overlap: released r(459)
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 31337
capture noisily tvmerge "`dir'/src_k_overlap.dta" "`dir'/src_a.dta", ///
    id(pid) start(k_start a_start) stop(k_stop a_stop) ///
    exposure(totK doseA) total(totK doseA)
_tvb_record B18_src_overlap_total `=_rc'

* B19 frameout(): result to a frame, caller data left intact
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 555
capture frame drop fout
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) frameout(fout)
_tvb_record B19_frameout_caller `=_rc'
capture frame change fout
_tvb_record B19_frameout_result 0 nor
capture frame change default
capture frame drop fout

* B20 frameout() onto an existing frame without replace: released r(110)
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 556
capture frame drop fout
frame create fout
frame fout: set obs 3
frame fout: generate double preexisting = 9
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) frameout(fout)
_tvb_record B20_frameout_exists_err `=_rc'
capture frame change fout
_tvb_record B20_frameout_target_intact 0 nor
capture frame change default
capture frame drop fout

* B21 saveas()
use "`dir'/src_a.dta", clear
capture erase "`dir'/b21_out.dta"
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) ///
    exposure(drugA drugB) saveas("`dir'/b21_out.dta") replace
_tvb_record B21_saveas `=_rc'

* B22 diagnostics: check, validatecoverage, validateoverlap, summarize, flow
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB) ///
    check validatecoverage validateoverlap summarize flow
_tvb_record B22_diagnostics `=_rc'

* B23 a source file that does not exist: released r(601), caller intact
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 601
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_absent.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B23_missing_file_err `=_rc'

* B24 a source that is not a Stata dataset: released r(610), caller intact
tempname fh3
file open `fh3' using "`dir'/not_a_dataset.dta", write replace text
file write `fh3' "this is not a Stata dataset" _n
file close `fh3'
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 610
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/not_a_dataset.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B24_unreadable_err `=_rc'

* B25 strL ID rejection
use "`dir'/src_a.dta", clear
quietly generate strL lid = "P" + string(pid)
quietly save "`dir'/src_a_strl.dta", replace
use "`dir'/src_a.dta", clear
quietly generate double caller_marker = 109
capture noisily tvmerge "`dir'/src_a_strl.dta" "`dir'/src_b.dta", ///
    id(lid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B25_strl_id_err `=_rc'

* B26 zero-variable caller with observations: restorable state is just _N
clear
quietly set obs 7
capture noisily tvmerge "`dir'/src_a.dta" "`dir'/src_b.dta", ///
    id(pid) start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
_tvb_record B26_zerovar_caller `=_rc'

* B27 full-row duplicates are dropped (exercises n_duplicates_dropped)
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_m_dup.dta" "`dir'/src_a.dta", ///
    id(pid) start(m_start a_start) stop(m_stop a_stop) exposure(drugM drugA)
_tvb_record B27_full_row_dupes `=_rc'

* B28 rows sharing (id,start,stop) but differing in payload must NOT be dropped
use "`dir'/src_a.dta", clear
capture noisily tvmerge "`dir'/src_n_paydup.dta" "`dir'/src_a.dta", ///
    id(pid) start(n_start a_start) stop(n_stop a_stop) ///
    exposure(drugN drugA) keep(payN)
_tvb_record B28_payload_dupes_kept `=_rc'

**# ---------------------------------------------------------------------
**# Summary
**# ---------------------------------------------------------------------
if "`mode'" == "capture" {
    display "BASELINE: capture complete -> `dir'"
}
else {
    local p = $TVB_PASS
    local f = $TVB_FAIL
    display "BASELINE: tvmerge_surface cases=`=`p'+`f'' match=`p' drift=`f'"
    if `f' > 0 {
        display as error "baseline drift in:$TVB_FAILED"
        exit 9
    }
}
