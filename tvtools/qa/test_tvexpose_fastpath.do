*! test_tvexpose_fastpath.do
*! Contract pins for tvexpose's narrow categorical fast path (1.9.1).
*!
*! Until 1.9.1 the default categorical construction reached its finished
*! tiling by writing and re-reading the working dataset roughly sixteen times
*! after clipping -- gap discovery, the earliest-episode extraction, a
*! baseline file, a post-exposure file, the append, and two m:1 re-merges of
*! the master windows. When a call is narrow enough to qualify, the same
*! tiling is now built in one in-memory pass by _tvexpose_fast_build.
*!
*! Axes probed, and why each one is here:
*!   F1-F14   the eligibility predicate as its OWN pure decision surface.
*!            _tvexpose_eligible reads options and nothing else, so each row
*!            states an expected eligible/ineligible verdict and its reason.
*!            F13 is the one that matters most: an unrecognised option name in
*!            flags() is an ERROR, so a typo in tvexpose.ado cannot silently
*!            make an excluded call look eligible. F14 pins that a caller that
*!            forgets hasstop() fails CLOSED.
*!   F15      the option-coverage contract. Every option tvexpose declares is
*!            either in the small allowed set or in the helper's blocking
*!            vocabulary. This is the drift guard: adding an option to
*!            tvexpose without classifying it fails HERE rather than by
*!            silently widening the fast path years later.
*!   F16-F29  the kernel called directly on minimal data, including every
*!            geometry where an off-by-one would otherwise hide -- an episode
*!            flush against entry, against exit, against both, a one-day
*!            window, a one-day gap, abutting same and different categories,
*!            and a person with no episode at all.
*!   F30-F33  the kernel's precondition failures. A structural violation must
*!            error, never emit a tiling it cannot justify.
*!   F34-F37  DISPATCH. A public parity test can pass while the fast path is
*!            never selected, so a deliberately broken kernel is placed ahead
*!            of the real one on the adopath: an eligible call must then FAIL,
*!            and its nearest ineligible neighbours must still succeed. F37 is
*!            the no-runtime-fallback contract -- the eligible call propagates
*!            the kernel's return code instead of quietly retrying on the
*!            legacy engine, which would mask a real defect.
*!   F38-F39  rollback. With the broken kernel installed, a failed eligible
*!            call leaves the caller's data and an existing frameout() target
*!            exactly as they were.
*!   F40-F44  an INDEPENDENT oracle. The expected tiling is recomputed day by
*!            day -- one observation per person-day, categorised from the raw
*!            episodes, then run-length encoded -- and compared to what
*!            tvexpose returns. This shares no code and no algorithm with
*!            either engine, so it cannot preserve a defect common to both,
*!            which a frozen-surface baseline alone can.
*!
*! NOT covered, stated so it is not mistaken for coverage: this suite does not
*! re-test the released behaviour of the excluded option families. That is the
*! job of the 40-case X series in baseline_tvexpose_surface.do, which replays
*! them against the frozen pre-1.9.1 surface.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvexpose_fastpath.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TXF_PASS = 0
global TXF_FAIL = 0
global TXF_FAILED ""

display as result "tvtools QA: tvexpose categorical fast path -- $S_DATE $S_TIME"

capture program drop _txf_check
program define _txf_check
    args ok label detail
    if `ok' {
        global TXF_PASS = $TXF_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TXF_FAIL = $TXF_FAIL + 1
        global TXF_FAILED "$TXF_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Assert an eligibility verdict from the pure decision surface.
capture program drop _txf_elig
program define _txf_elig
    args label want opts
    capture noisily _tvexpose_eligible, `opts'
    local rc = _rc
    local got = cond(`rc', -1, r(eligible))
    local why `"`r(reason)'"'
    _txf_check `=(`got' == `want')' `label' "wanted `want', got `got' (rc=`rc', reason=`why')"
end

local qadir "`c(pwd)'"
local pkgdir "`c(pwd)'/.."

**# ---------------------------------------------------------------------
**# F1-F14  Eligibility predicate as a pure decision surface
**# ---------------------------------------------------------------------
* Every row states its expected verdict and the reason for it. Nothing here
* loads data: that is the point of splitting the predicate in two.

local base "exptype(timevarying) hasstop(1) reference(0)"

_txf_elig F01_bare_eligible          1 "`base'"
_txf_elig F02_negative_reference     1 "exptype(timevarying) hasstop(1) reference(-5)"
_txf_elig F03_no_reference_given     1 "exptype(timevarying) hasstop(1)"
_txf_elig F04_no_stop                0 "exptype(timevarying) hasstop(0) reference(0)"
_txf_elig F05_evertreated_mode       0 "exptype(evertreated) hasstop(1) reference(0)"
_txf_elig F06_continuous_mode        0 "exptype(continuous) hasstop(1) reference(0)"
_txf_elig F07_merge_nonzero          1 "`base' mergedays(30)"
_txf_elig F08_lag_nonzero            1 "`base' lagdays(10)"
_txf_elig F09_washout_nonzero        1 "`base' washoutdays(10)"
_txf_elig F10_fillgaps_nonzero       1 "`base' fillgapdays(10)"
_txf_elig F11_carryforward_nonzero   0 "`base' carryforwarddays(10)"
_txf_elig F12_grace_on               0 "`base' graceon(1)"
_txf_elig F12b_noninteger_reference  0 "exptype(timevarying) hasstop(1) reference(0.5)"

* Every blocking option family gets its own row: a family that silently
* stopped blocking is exactly the defect this suite exists to catch.
local _fams "pointtime evertreated currentformer duration dose dosecuts"
local _fams "`_fams' continuousunit expandunit bytype recency recencyunit"
local _fams "`_fams' grace switching switchingdetail statetime"
local _fams "`_fams' priority split layer combine keepvars"
local _fams "`_fams' flow dropinvalid"
local _famfail = 0
local _famnames ""
foreach f of local _fams {
    capture _tvexpose_eligible, `base' flags("`f'")
    if _rc | r(eligible) != 0 {
        local _famfail = `_famfail' + 1
        local _famnames "`_famnames' `f'"
    }
}
_txf_check `=(`_famfail' == 0)' F13_every_family_blocks ///
    "`_famfail' family/families did not block:`_famnames'"

* An unrecognised name must be an ERROR. If it were merely ignored, a typo in
* tvexpose.ado would hand an excluded call to the fast engine.
capture _tvexpose_eligible, `base' flags("nosuchoption")
_txf_check `=(_rc == 198)' F14_unknown_flag_errors "rc=`=_rc', wanted 198"

* Omitting hasstop() must fail closed, onto the legacy path.
capture _tvexpose_eligible, exptype(timevarying) reference(0)
local _hs = cond(_rc, -1, r(eligible))
_txf_check `=(`_hs' == 0)' F15_missing_hasstop_fails_closed "got `_hs'"

**# ---------------------------------------------------------------------
**# F16  Option-coverage contract
**# ---------------------------------------------------------------------
* Read tvexpose's own syntax declaration and the helper's blocking list, and
* require that every declared option is classified by one or the other. This
* is what makes the fast path safe to leave in place while tvexpose keeps
* growing: a new option that nobody classified fails here.
local _allowed "using id start exposure entry exit stop reference"
local _allowed "`_allowed' generate frameout replace keepdates"
local _allowed "`_allowed' referencelabel label"
local _allowed "`_allowed' window check gaps overlaps summarize validate verbose saveas"
local _allowed "`_allowed' nofastpath"

* The declaration is bounded by its own continuation marker: it starts at the
* syntax line and ends at the first line that does not carry a trailing
* continuation. Keying the end to a specific option name instead let the scan
* run on into the body, where a display-as-error string carrying a quote
* mangled the token accumulator and killed the suite at r(198).
*
* Note for anyone editing the comments here: a continuation marker written as
* literal text inside a comment is still a continuation. Spelling one out on
* the line above cost an hour, because Stata joined the comment to the code
* that followed it and the failure surfaced 500 lines away.
* Two traps this scan walked into, both worth stating because neither
* announces itself and both surface hundreds of lines from the edit:
*
* 1. The continuation marker is BUILT, never written literally. A literal one
*    inside a string is still stripped by the preprocessor along with the rest
*    of the line, so a subinstr naming it silently truncates mid-command.
* 2. Every source line is read through its MACRO NAME, never re-quoted into an
*    expression. `local l = trim(`"<line>"')' looks safe and is not: a source
*    line that ENDS in a double quote makes the compound quote close one
*    character early, and the leftover text is then parsed as a command. That
*    is what produced `invalid name' on a line the scan had no business
*    reaching -- the scan had already stopped; the failure was in the read.
local _sl = "/"
local _cont "`_sl'`_sl'`_sl'"
tempname fh
local _declared ""
local _insyntax = 0
file open `fh' using "`pkgdir'/tvexpose.ado", read text
file read `fh' line
while r(eof) == 0 {
    * Search source text by extended-macro substitution, which does not
    * reparse embedded quotes. Once the declaration ends, stop reading: later
    * display strings and format tokens are intentionally irrelevant here.
    if !`_insyntax' {
        local _junk : subinstr local line "syntax using/" "", all count(local _ns)
        if `_ns' > 0 local _insyntax = 1
    }
    if `_insyntax' {
        local _junk : subinstr local line "`_cont'" "", all count(local _ncont)
        local clean : subinstr local line "`_cont'" " ", all
        local clean : subinstr local clean "," " ", all
        local clean : subinstr local clean "[" " ", all
        local clean : subinstr local clean "]" " ", all
        * Option tokens look like NAMEname( or a bare NAME flag. Strip the
        * argument spec and lower-case what is left.
        foreach tok of local clean {
            local p = strpos("`tok'", "(")
            if `p' > 0 local tok = substr("`tok'", 1, `p' - 1)
            local tok = lower(subinstr("`tok'", "`_sl'", "", .))
            if "`tok'" != "" & regexm("`tok'", "^[a-z]+$") ///
                local _declared "`_declared' `tok'"
        }
        if `_ncont' == 0 continue, break
    }
    file read `fh' line
}
file close `fh'
local _declared : list uniq _declared
local _declared : list _declared - _allowed

local _blocking "pointtime evertreated currentformer duration dose dosecuts"
local _blocking "`_blocking' continuousunit expandunit bytype"
local _blocking "`_blocking' recency recencyunit grace"
local _blocking "`_blocking' switching switchingdetail statetime"
local _blocking "`_blocking' priority split layer combine keepvars"
local _blocking "`_blocking' flow dropinvalid"
* Three buckets, not two. The five numeric knobs are not blocking FLAGS --
* they are checked by VALUE, because merge(0) is eligible and merge(30) is
* not -- so they are classified in their own list rather than quietly
* absorbed into either of the other two. `syntax' is the command word the
* scanner necessarily picks up along with the options.
local _numeric "merge lag washout fillgaps carryforward"
local _noise "syntax"
local _unclassified : list _declared - _blocking
local _unclassified : list _unclassified - _numeric
local _unclassified : list _unclassified - _noise
local _nsyn : word count `_declared'

* Guard the guard: if the parse found nothing, the check would pass vacuously.
_txf_check `=(`_nsyn' >= 25)' F16a_syntax_parsed ///
    "parsed only `_nsyn' non-allowed option tokens from tvexpose.ado"
_txf_check `=("`_unclassified'" == "")' F16b_all_options_classified ///
    "unclassified tvexpose option(s):`_unclassified'"

**# ---------------------------------------------------------------------
**# F17-F30  The kernel, called directly on minimal data
**# ---------------------------------------------------------------------
* 21915 = 01jan2020. Each case builds the episode data in memory, writes the
* per-person window file, calls the builder, and checks the emitted tiling.

tempfile fMST

capture program drop _txf_master
program define _txf_master
    version 16.0
    args path
    quietly save "`path'", replace
end

* Assert the emitted tiling as "start-stop=value" triples in row order.
capture program drop _txf_shape
program define _txf_shape, rclass
    version 16.0
    local out ""
    forvalues i = 1/`=_N' {
        local out "`out' `=id[`i']':`=exp_start[`i']'-`=exp_stop[`i']'=`=exp_value[`i']'"
    }
    return local shape = trim("`out'")
end

* --- F17 one episode strictly inside the window -> baseline, episode, post
clear
quietly input long id double study_entry double study_exit
    1 21915 21945
end
_txf_master "`fMST'"
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21929=1 1:21930-21945=0")' ///
    F17_interior_episode "rc=`rc' shape=`r(shape)'"

* --- F18 episode flush against entry -> no baseline row
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21915 21929 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21929=1 1:21930-21945=0")' ///
    F18_flush_at_entry "rc=`rc' shape=`r(shape)'"

* --- F19 episode flush against exit -> no post row
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21945 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21945=1")' ///
    F19_flush_at_exit "rc=`rc' shape=`r(shape)'"

* --- F20 episode covering the entire window -> exactly one row
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21915 21945 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21945=1")' ///
    F20_covers_window "rc=`rc' shape=`r(shape)'"

* --- F21 no episode at all -> exactly one reference row spanning the window
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
end
quietly drop in 1
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21945=0")' ///
    F21_no_episode "rc=`rc' shape=`r(shape)'"

* --- F22 a ONE-DAY gap must still emit a reference row. This is the boundary
* that separates "emit only when the gap is positive" from ">= 0", and an
* off-by-one here is invisible in any fixture whose gaps are long.
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
    1 21931 21940 2 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21929=1 1:21930-21930=0 1:21931-21940=2 1:21941-21945=0")' ///
    F22_one_day_gap "rc=`rc' shape=`r(shape)'"

* --- F23 abutting DIFFERENT categories: two rows, and no zero-length row
* wedged between them.
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
    1 21930 21940 2 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21929=1 1:21930-21940=2 1:21941-21945=0")' ///
    F23_abutting_different "rc=`rc' shape=`r(shape)'"

* --- F24 abutting SAME category coalesces into one row. This is the released
* layer kernel's behaviour, not an invention: it extends its previous output
* row whenever the next segment abuts and carries the same code.
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
    1 21930 21940 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21940=1 1:21941-21945=0")' ///
    F24_abutting_same_coalesces "rc=`rc' shape=`r(shape)'"

* --- F25 a CHAIN of three abutting same-category episodes coalesces
* transitively, which a single-pass pairwise rule would get wrong.
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
    1 21930 21935 1 21915 21945
    1 21936 21940 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21940=1 1:21941-21945=0")' ///
    F25_abutting_chain "rc=`rc' shape=`r(shape)'"

* --- F26 one-day window with a one-day episode
clear
quietly input long id double study_entry double study_exit
    1 21915 21915
end
_txf_master "`fMST'"
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21915 21915 1 21915 21915
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21915=1")' ///
    F26_oneday_window "rc=`rc' shape=`r(shape)'"

* --- F27 one-day window, no episode
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21915 21915 1 21915 21915
end
quietly drop in 1
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21915=0")' ///
    F27_oneday_no_episode "rc=`rc' shape=`r(shape)'"

* --- F28 several persons at once, including one with no episode. The person
* set comes from the window file, never from the episodes.
clear
quietly input long id double study_entry double study_exit
    1 21915 21945
    2 21915 21925
    3 21915 21920
end
_txf_master "`fMST'"
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
    3 21915 21920 2 21915 21920
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=0 1:21920-21929=1 1:21930-21945=0 2:21915-21925=0 3:21915-21920=2")' ///
    F28_multi_person "rc=`rc' shape=`r(shape)'"

* --- F29 a negative reference code, with zero as an ordinary category
clear
quietly input long id double study_entry double study_exit
    1 21915 21945
end
_txf_master "`fMST'"
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 0 21915 21945
end
capture noisily _tvexpose_fast_build, reference(-5) masterfile("`fMST'")
local rc = _rc
_txf_shape
_txf_check `=(`rc' == 0 & "`r(shape)'" == "1:21915-21919=-5 1:21920-21929=0 1:21930-21945=-5")' ///
    F29_negative_reference "rc=`rc' shape=`r(shape)'"

* --- F30 the returned counts describe what was actually emitted
clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
end
capture noisily _tvexpose_fast_build, reference(0) masterfile("`fMST'")
local _nr = r(N_rows)
local _np = r(N_persons)
_txf_check `=(`_nr' == _N & `_nr' == 3 & `_np' == 1)' F30_returns ///
    "N_rows=`_nr' N_persons=`_np' _N=`=_N'"

**# ---------------------------------------------------------------------
**# F31-F34  Kernel precondition failures
**# ---------------------------------------------------------------------
* An impossible input errors. It is never padded, guessed, or emitted.

clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21929 21920 1 21915 21945
end
capture _tvexpose_fast_build, reference(0) masterfile("`fMST'")
_txf_check `=(_rc == 498)' F31_reversed_bounds_error "rc=`=_rc', wanted 498"

clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 . 21929 1 21915 21945
end
capture _tvexpose_fast_build, reference(0) masterfile("`fMST'")
_txf_check `=(_rc == 498)' F32_missing_bound_error "rc=`=_rc', wanted 498"

clear
quietly input long id double exp_start double exp_stop double study_entry double study_exit
    1 21920 21929 21915 21945
end
capture _tvexpose_fast_build, reference(0) masterfile("`fMST'")
_txf_check `=(_rc == 111)' F33_missing_column_error "rc=`=_rc', wanted 111"

clear
quietly input long id double exp_start double exp_stop double exp_value double study_entry double study_exit
    1 21920 21929 1 21915 21945
end
capture _tvexpose_fast_build, reference(0) masterfile("`qadir'/no_such_master_file.dta")
_txf_check `=(_rc == 601)' F34_missing_master_error "rc=`=_rc', wanted 601"

**# ---------------------------------------------------------------------
**# F35-F39  Dispatch proof and rollback
**# ---------------------------------------------------------------------
* A public parity test can pass while the fast path is never selected, so the
* engine is proved by BREAKING it. A stub _tvexpose_fast_build.ado is written
* into a scratch directory placed ahead of the package on the adopath; the
* shipped command is not touched and carries no test hook.

local stubdir "`c(tmpdir)'/txf_stub_`c(pid)'"
capture mkdir "`stubdir'"
* file write takes string literals and macros, not expressions, so the quote
* characters the stub needs are interpolated from a macro rather than written
* as char(34) arguments.
local _q = char(34)
tempname sfh
file open `sfh' using "`stubdir'/_tvexpose_fast_build.ado", write replace text
file write `sfh' "program define _tvexpose_fast_build, rclass" _n
file write `sfh' "    version 16.0" _n
file write `sfh' "    syntax , REFerence(string) MASTERfile(string) [NOCOALESCE MIRROR(name)]" _n
file write `sfh' `"    display as error `_q'TXF_STUB_KERNEL`_q'"' _n
file write `sfh' "    exit 9931" _n
file write `sfh' "end" _n
file close `sfh'

* Fixtures for the public calls.
tempfile fPMST fPEXP fPREF
clear
quietly input long pid int s_entry int s_exit
    1 21915 21945
    2 21915 21945
end
quietly save "`fPMST'", replace
clear
quietly input long pid int e_start int e_stop byte drug
    1 21920 21929 1
    2 21925 21935 2
end
quietly save "`fPEXP'", replace
clear
quietly input long pid int e_start int e_stop byte drug
    1 21920 21929 1
    1 21925 21935 2
    2 21925 21935 2
end
quietly save "`fPREF'", replace

adopath ++ "`stubdir'"
discard

use "`fPMST'", clear
capture noisily tvexpose using "`fPEXP'", id(pid) start(e_start) stop(e_stop) ///
    exposure(drug) reference(0) entry(s_entry) exit(s_exit)
local _elig_rc = _rc
_txf_check `=(`_elig_rc' == 9931)' F35_eligible_call_uses_fast_kernel ///
    "rc=`_elig_rc', wanted the stub's 9931"

* The caller's data must be exactly what it was before the failed call.
capture confirm variable s_entry
local _ok = (_rc == 0)
if `_ok' {
    capture _tvtools_qa_assert_cf_all_exact using "`fPMST'"
    local _ok = (_rc == 0)
}
_txf_check `=`_ok'' F36_caller_restored_after_kernel_failure ///
    "caller data not restored after the failing eligible call"

* An existing frameout() target must also survive untouched.
capture frame drop txfout
frame create txfout
frame txfout: quietly set obs 4
frame txfout: quietly generate byte keepme = _n
use "`fPMST'", clear
capture noisily tvexpose using "`fPEXP'", id(pid) start(e_start) stop(e_stop) ///
    exposure(drug) reference(0) entry(s_entry) exit(s_exit) ///
    frameout(txfout) replace
local _fo_rc = _rc
local _fo_n = 0
capture frame txfout: local _fo_n = _N
_txf_check `=(`_fo_rc' == 9931 & `_fo_n' == 4)' F37_frameout_target_untouched ///
    "rc=`_fo_rc', frame rows=`_fo_n' (wanted 9931 and 4)"
capture frame drop txfout

* A call initially ineligible because its source overlaps is cleaned by the
* shared legacy stage, then deliberately reaches the second-stage builder.
use "`fPMST'", clear
capture noisily tvexpose using "`fPREF'", id(pid) start(e_start) stop(e_stop) ///
    exposure(drug) reference(0) entry(s_entry) exit(s_exit)
_txf_check `=(_rc == 9931)' F38_postclean_data_uses_fast_kernel ///
    "rc=`=_rc', wanted the stub's 9931"

* So does a call made ineligible by an OPTION.
use "`fPMST'", clear
capture noisily tvexpose using "`fPEXP'", id(pid) start(e_start) stop(e_stop) ///
    exposure(drug) reference(0) entry(s_entry) exit(s_exit) dropinvalid
_txf_check `=(_rc == 0)' F39_option_ineligible_uses_legacy "rc=`=_rc', wanted 0"

* Restore the real kernel.
adopath - "`stubdir'"
capture erase "`stubdir'/_tvexpose_fast_build.ado"
capture rmdir "`stubdir'"
discard

* And prove the restore worked, so nothing below is measuring the stub.
use "`fPMST'", clear
capture noisily tvexpose using "`fPEXP'", id(pid) start(e_start) stop(e_stop) ///
    exposure(drug) reference(0) entry(s_entry) exit(s_exit)
_txf_check `=(_rc == 0)' F40_real_kernel_restored "rc=`=_rc', wanted 0"

**# ---------------------------------------------------------------------
**# F46-F47  Missing-helper guard
**# ---------------------------------------------------------------------
* Both helpers are auto-loaded by filename, so a partial installation shows
* up as "command _tvexpose_fast_build is unrecognized", r(199) -- a message
* that names neither the package nor the fix. tvexpose therefore confirms
* both files resolve up front.
*
* F46 is the positive contract and catches a .pkg omission: the files must be
* findable from wherever the caller is. F47 pins that the guard itself is
* still present for BOTH names, and fails if either is deleted.
*
* The negative path -- actually running tvexpose with a helper absent -- is
* NOT exercised here, and saying so is the honest report: the installed copy
* in PLUS supplies the helper no matter what this suite does to the adopath,
* so hiding it requires a crippled package tree and an adopath stripped of
* PLUS/PERSONAL/SITE. That was verified out of band against a scratch tree
* with _tvexpose_fast_build.ado deleted; it is not automated.
local _hmiss ""
foreach h in _tvexpose_eligible _tvexpose_fast_data _tvexpose_fast_build ///
        _tvexpose_dose_sweep {
    capture findfile `h'.ado
    if _rc local _hmiss "`_hmiss' `h'"
}
_txf_check `=("`_hmiss'" == "")' F46_helpers_resolve "unresolvable helper(s):`_hmiss'"

* The guard names its helper through a loop macro, so the message text in the
* source reads "`_tvx_helper'.ado not found" and NOT the resolved name --
* searching for the resolved name finds nothing and the check fails on correct
* code, which is how this check's own first draft behaved. Look instead for
* the loop line that carries both helper names, plus the message itself.
local _sawloop = 0
local _sawmsg  = 0
tempname gh
file open `gh' using "`pkgdir'/tvexpose.ado", read text
file read `gh' line
while r(eof) == 0 {
    local _j : subinstr local line "foreach" "", all count(local _nf)
    local _j : subinstr local line "_tvexpose_eligible" "", all count(local _n1)
    local _j : subinstr local line "_tvexpose_fast_data" "", all count(local _n2)
    local _j : subinstr local line "_tvexpose_fast_build" "", all count(local _n3)
    local _j : subinstr local line "_tvexpose_dose_sweep" "", all count(local _n4)
    if `_nf' > 0 & `_n1' > 0 & `_n2' > 0 & `_n3' > 0 & `_n4' > 0 ///
        local _sawloop = 1
    local _j : subinstr local line "not found; reinstall tvtools" "", all count(local _nm)
    if `_nm' > 0 local _sawmsg = 1
    file read `gh' line
}
file close `gh'
_txf_check `=(`_sawloop' & `_sawmsg')' F47_helper_guard_present ///
    "tvexpose.ado missing-helper guard: loop=`_sawloop' message=`_sawmsg'"

**# ---------------------------------------------------------------------
**# F41-F45  Independent day-by-day oracle
**# ---------------------------------------------------------------------
* The frozen-surface baseline proves the two engines agree; it cannot prove
* they are both right. This oracle shares no code with either: it expands the
* study window to one observation per person-day, categorises each day
* directly from the raw episodes, run-length encodes the result, and compares.

capture program drop _txf_oracle
program define _txf_oracle, rclass
    version 16.0
    args mstfile expfile ref
    * One row per person-day.
    quietly use "`mstfile'", clear
    quietly generate long __ndays = s_exit - s_entry + 1
    quietly expand __ndays
    quietly bysort pid (s_entry): generate long __k = _n
    quietly generate double __day = s_entry + __k - 1
    keep pid __day
    quietly generate double __val = `ref'

    * Categorise each day from the raw episodes. Later source rows win, which
    * is the released layer precedence; under the fast path's predicate there
    * are no overlaps, so the order cannot matter -- applying it anyway means
    * the oracle does not quietly assume the predicate held.
    preserve
    quietly use "`expfile'", clear
    local _ne = _N
    local _pid ""
    local _s ""
    local _e ""
    local _v ""
    forvalues i = 1/`_ne' {
        local _pid "`_pid' `=pid[`i']'"
        local _s   "`_s' `=e_start[`i']'"
        local _e   "`_e' `=e_stop[`i']'"
        local _v   "`_v' `=drug[`i']'"
    }
    restore
    forvalues i = 1/`_ne' {
        local p : word `i' of `_pid'
        local a : word `i' of `_s'
        local b : word `i' of `_e'
        local v : word `i' of `_v'
        quietly replace __val = `v' if pid == `p' & __day >= `a' & __day <= `b'
    }

    * Run-length encode back into intervals.
    sort pid __day
    quietly by pid: generate byte __new = (_n == 1) | (__val != __val[_n-1])
    quietly by pid: generate long __run = sum(__new)
    sort pid __run __day
    quietly by pid __run: generate double __st = __day[1]
    quietly by pid __run: generate double __sp = __day[_N]
    quietly by pid __run: keep if _n == 1
    keep pid __st __sp __val
    sort pid __st

    local out ""
    forvalues i = 1/`=_N' {
        local out "`out' `=pid[`i']':`=__st[`i']'-`=__sp[`i']'=`=__val[`i']'"
    }
    return local shape = trim("`out'")
end

* Read back whatever tvexpose committed, in its own row order.
capture program drop _txf_actual
program define _txf_actual, rclass
    version 16.0
    local out ""
    forvalues i = 1/`=_N' {
        local out "`out' `=pid[`i']':`=e_start[`i']'-`=e_stop[`i']'=`=tv_drug[`i']'"
    }
    return local shape = trim("`out'")
end

capture program drop _txf_oracle_case
program define _txf_oracle_case
    version 16.0
    args label mstfile expfile ref
    _txf_oracle "`mstfile'" "`expfile'" `ref'
    local want "`r(shape)'"
    quietly use "`mstfile'", clear
    capture noisily tvexpose using "`expfile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(`ref') entry(s_entry) exit(s_exit)
    local rc = _rc
    _txf_actual
    local got "`r(shape)'"
    _txf_check `=(`rc' == 0 & "`got'" == "`want'")' `label' ///
        "rc=`rc'; oracle=`want'; actual=`got'"
end

tempfile fOM fO1 fO2 fO3 fO4 fO5
clear
quietly input long pid int s_entry int s_exit
    1 21915 21960
    2 21915 21930
    3 21920 21920
    4 21915 21960
end
quietly save "`fOM'", replace

* O1 the ordinary mix: interior episodes, an episode flush at entry, and a
* person with none.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21920 21929 1
    1 21940 21949 2
    2 21915 21922 1
    3 21920 21920 3
end
quietly save "`fO1'", replace
_txf_oracle_case F41_oracle_mixed "`fOM'" "`fO1'" 0

* O2 abutting same category, which the released engine coalesces. The oracle
* run-length encodes days, so it reaches the same single row by a completely
* different route.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21920 21929 1
    1 21930 21939 1
    2 21920 21925 2
end
quietly save "`fO2'", replace
_txf_oracle_case F42_oracle_abutting "`fOM'" "`fO2'" 0

* O3 one-day gaps and one-day episodes together.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21920 21920 1
    1 21922 21922 2
    1 21924 21924 1
    2 21930 21930 1
end
quietly save "`fO3'", replace
_txf_oracle_case F43_oracle_oneday "`fOM'" "`fO3'" 0

* O4 episodes clipped at entry, at exit, and at both.
clear
quietly input long pid int e_start int e_stop byte drug
    1 21900 21919 1
    1 21955 22000 2
    2 21800 22000 1
    4 21916 21959 3
end
quietly save "`fO4'", replace
_txf_oracle_case F44_oracle_clipped "`fOM'" "`fO4'" 0

* O5 a negative reference with zero as an ordinary category.
clear
quietly input long pid int e_start int e_stop int drug
    1 21920 21929 0
    2 21920 21925 7
    4 21930 21939 -2
end
quietly save "`fO5'", replace
_txf_oracle_case F45_oracle_negative_reference "`fOM'" "`fO5'" -5

**# ---------------------------------------------------------------------
**# F48-F50  Same-build differential, at scale, and the console axis
**# ---------------------------------------------------------------------
* Three axes nothing above probes.
*
* The first is SCALE. Every correctness fixture in this file holds at most a
* handful of persons, and the registered benchmark asserts only the output row
* count, never a value. A storage-type or allocation defect that needs tens of
* thousands of rows to appear would pass everything written so far.
*
* The second is a dispatch proof that does not depend on manipulating the
* adopath. `verbose' is data-neutral -- it changes what is displayed and
* nothing else -- but it is on the blocking list, so the SAME data run twice,
* once plain and once with `verbose', goes through the fast engine and then
* the legacy engine in ONE build of the package. Any disagreement is an engine
* disagreement. This is the differential the frozen baseline provides across
* builds, available here across engines.
*
* The third is the CONSOLE. The baseline records data, r(), and return codes;
* it does not record displayed text. The fast branch re-emits the released
* "no valid exposure periods" note, and deleting that note would be invisible
* to every other check in this suite and in the baseline.

capture program drop _txf_engine_diff
program define _txf_engine_diff
    version 16.0
    args label mstfile expfile opts
    tempfile fastout
    quietly use "`mstfile'", clear
    capture noisily tvexpose using "`expfile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit) `opts'
    local rc1 = _rc
    local np1 = .
    local nr1 = .
    local tt1 = .
    local et1 = .
    local ut1 = .
    local gx1 ""
    local cm1 ""
    local by1 ""
    if `rc1' == 0 {
        local np1 = r(N_persons)
        local nr1 = r(N_periods)
        local tt1 = r(total_time)
        local et1 = r(exposed_time)
        local ut1 = r(unexposed_time)
        local gx1 `"`r(genvar)'"'
        local cm1 `"`r(combine_map)'"'
        local by1 `"`r(bytype_map)'"'
    }
    local n1 = _N
    local sort1 : sortedby
    quietly describe, varlist
    local vl1 `r(varlist)'
    quietly save "`fastout'", replace

    * nofastpath is an internal QA switch: it forces the frozen constructor
    * while leaving every public option and the byte-identical input intact.
    quietly use "`mstfile'", clear
    capture noisily tvexpose using "`expfile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit) ///
        `opts' nofastpath
    local rc2 = _rc
    local np2 = .
    local nr2 = .
    local tt2 = .
    local et2 = .
    local ut2 = .
    local gx2 ""
    local cm2 ""
    local by2 ""
    if `rc2' == 0 {
        local np2 = r(N_persons)
        local nr2 = r(N_periods)
        local tt2 = r(total_time)
        local et2 = r(exposed_time)
        local ut2 = r(unexposed_time)
        local gx2 `"`r(genvar)'"'
        local cm2 `"`r(combine_map)'"'
        local by2 `"`r(bytype_map)'"'
    }
    local n2 = _N
    local sort2 : sortedby
    quietly describe, varlist
    local vl2 `r(varlist)'

    local ok = (`rc1' == 0 & `rc2' == 0 & `n1' == `n2')
    local ok = `ok' & ("`sort1'" == "`sort2'") & ("`vl1'" == "`vl2'")
    local ok = `ok' & (`np1' == `np2') & (`nr1' == `nr2')
    local ok = `ok' & (`tt1' == `tt2') & (`et1' == `et2') & (`ut1' == `ut2')
    local ok = `ok' & (`"`gx1'"' == `"`gx2'"') & (`"`cm1'"' == `"`cm2'"')
    local ok = `ok' & (`"`by1'"' == `"`by2'"')
    if `ok' {
        capture _tvtools_qa_assert_cf_all_exact using "`fastout'", verbose
        local ok = (_rc == 0)
    }
    _txf_check `ok' `label' ///
        "rc=`rc1'/`rc2' N=`n1'/`n2' sort=`sort1'|`sort2' vars=`vl1'|`vl2'"
end

* --- F48 small, but through the full public surface both ways
_txf_engine_diff F48_engine_diff_small "`fOM'" "`fO1'"

* --- F49 the same comparison at 2,000 persons and 6,000 episodes
tempfile fBM fBE
clear
quietly set obs 2000
quietly generate long pid = _n
quietly generate int s_entry = 21915
quietly generate int s_exit  = 22120
quietly save "`fBM'", replace
clear
quietly set obs 6000
quietly generate long pid = 1 + floor((_n - 1) / 3)
quietly generate long seq = 1 + mod(_n - 1, 3)
quietly generate int e_start = 21920 + (seq - 1) * 40
quietly generate int e_stop  = e_start + 29
quietly generate byte drug = 1 + mod(seq, 2)
quietly drop seq
quietly save "`fBE'", replace
_txf_engine_diff F49_engine_diff_at_scale "`fBM'" "`fBE'"

* --- F50-F64 newly admitted construction and transformation surfaces
_txf_engine_diff F50_lag              "`fOM'" "`fO1'" "lag(2)"
_txf_engine_diff F51_washout          "`fOM'" "`fO1'" "washout(3)"
_txf_engine_diff F52_fillgaps         "`fOM'" "`fO1'" "fillgaps(3)"
_txf_engine_diff F53_window           "`fOM'" "`fO1'" "window(0 100)"
_txf_engine_diff F54_merge            "`fOM'" "`fO1'" "merge(15)"
_txf_engine_diff F55_grace            "`fOM'" "`fO1'" "grace(15)"
_txf_engine_diff F56_carryforward     "`fOM'" "`fO1'" "carryforward(5)"
_txf_engine_diff F57_priority         "`fOM'" "`fO1'" "priority(2 1)"
_txf_engine_diff F58_layer            "`fOM'" "`fO1'" "layer"
_txf_engine_diff F59_combine          "`fOM'" "`fO1'" "combine(combo)"
_txf_engine_diff F60_evertreated      "`fOM'" "`fO1'" "evertreated"
_txf_engine_diff F61_currentformer    "`fOM'" "`fO1'" "currentformer"
_txf_engine_diff F62_continuous       "`fOM'" "`fO1'" "continuousunit(years)"
_txf_engine_diff F63_duration         "`fOM'" "`fO1'" "duration(1 3) continuousunit(years)"
_txf_engine_diff F64_recency          "`fOM'" "`fO1'" "recency(10 30) recencyunit(days)"

* --- F50 the fast path still emits the released no-episodes note
tempfile fNM fNE
clear
quietly input long pid int s_entry int s_exit
    1 21915 21945
    2 21915 21945
end
quietly save "`fNM'", replace
clear
quietly input long pid int e_start int e_stop byte drug
    1 21000 21100 1
    2 21000 21100 1
end
quietly save "`fNE'", replace

local notelog "`c(tmpdir)'/txf_note_`c(pid)'.log"
capture erase "`notelog'"
quietly log using "`notelog'", replace text name(txfnote)
use "`fNM'", clear
capture noisily tvexpose using "`fNE'", id(pid) start(e_start) stop(e_stop) ///
    exposure(drug) reference(0) entry(s_entry) exit(s_exit)
local _noterc = _rc
capture log close txfnote

local _sawnote = 0
tempname nh
capture file open `nh' using "`notelog'", read text
if _rc == 0 {
    file read `nh' line
    while r(eof) == 0 {
        local _j : subinstr local line "No valid exposure periods found" "", all count(local _nn)
        if `_nn' > 0 local _sawnote = 1
        file read `nh' line
    }
    file close `nh'
}
capture erase "`notelog'"
_txf_check `=(`_noterc' == 0 & `_sawnote' == 1)' F65_no_episode_note ///
    "rc=`_noterc', note seen=`_sawnote'"

**# ---------------------------------------------------------------------
**# Summary
**# ---------------------------------------------------------------------
local pass = $TXF_PASS
local fail = $TXF_FAIL
local total = `pass' + `fail'
if `fail' > 0 display as error "Failed:$TXF_FAILED"
display "RESULT: test_tvexpose_fastpath tests=`total' pass=`pass' fail=`fail'"
capture log close
