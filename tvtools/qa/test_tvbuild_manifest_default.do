*! test_tvbuild_manifest_default.do
*! tvbuild builds a provenance manifest by default; nomanifest opts out.
*!
*! The contract under test is an ownership rule, not a feature:
*!
*!   replace authorises replacing a destination the USER NAMED. It does not
*!   authorise clobbering a frame whose name the command INVENTED.
*!
*! So a derived <frameout>_manifest that is already taken is an error on BOTH
*! sides of replace, and a frameout() too long to carry the suffix is an error
*! rather than a truncation. Those two are the tests most likely to be got
*! wrong, because the obvious implementation -- resolve a default, then reuse
*! the existing destination checks -- gets both of them backwards.
*!
*! Three false greens this suite is written against:
*!
*!   1. "The manifest is built by default." A frame that merely EXISTS at the
*!      derived name proves nothing: it could be empty, or left over from an
*!      earlier call. M1 asserts stage rows in execution order and non-missing
*!      counts, and every negative test asserts the frame does NOT exist rather
*!      than only that rc was nonzero.
*!
*!   2. "nomanifest reproduces the old behaviour." Asserting that no manifest
*!      frame appears says nothing about whether the OUTPUT changed. N2 holds
*!      the committed frame under nomanifest against the committed frame under
*!      an explicit manifestframe() and against the default, byte for byte with
*!      cf _all -- three routes, one output.
*!
*!   3. "The error fired for the reason I think." Every refusal here is r(198)
*!      and several are reachable from more than one guard, so a test that only
*!      checked the code could pass off the wrong guard. Each negative test
*!      also asserts what SURVIVED: the pre-existing frame keeps its rows, the
*!      caller's frame keeps its data, and no destination was created.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvbuild_manifest_default.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVM_PASS = 0
global TVM_FAIL = 0
global TVM_FAILED ""

display as result "tvtools QA: tvbuild manifest default -- $S_DATE $S_TIME"

capture program drop _tvm_check
program define _tvm_check
    args ok label detail
    if `ok' {
        global TVM_PASS = $TVM_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVM_FAIL = $TVM_FAIL + 1
        global TVM_FAILED "$TVM_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Does a frame exist? Returns 0/1 in r(yes) without disturbing the caller.
capture program drop _tvm_hasframe
program define _tvm_hasframe, rclass
    version 16.0
    args fr
    capture confirm frame `fr'
    local _yes = (_rc == 0)
    return scalar yes = `_yes'
end

* Drop every frame this suite creates, whatever state the last test left.
capture program drop _tvm_reset
program define _tvm_reset
    version 16.0
    args extra
    foreach fr in mout mout_manifest expl mysrc ///
        twentythreecharsxxxxxxx twentythreecharsxxxxxxx_manifest ///
        twentyfourcharssxxxxxxxx alias alias_manifest `extra' {
        capture frame drop `fr'
    }
end


**# ---------------------------------------------------------------------
**# Fixtures
**# ---------------------------------------------------------------------
* Written into the private run workspace, never the shared qa/ tree.
local work "$TVTOOLS_QA_RUN_DIR"

clear
input long pid double study_entry double study_exit byte sex
    1 100 500 1
    2 120 480 0
    3  90 500 1
end
quietly save "`work'/tmb_master.dta", replace

clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 250 299 2
    2 130 200 1
    3 100 400 2
end
quietly save "`work'/tmb_source.dta", replace

* Rebuild the caller's master in the default frame before every call.
capture program drop _tvm_master
program define _tvm_master
    version 16.0
    args workdir
    quietly use "`workdir'/tmb_master.dta", clear
end

local INLINE start(a_start) stop(a_stop) exposure(drug) reference(0) ///
    generate(tv_drug)


**# ===== M: the default =====

* M1: omit manifestframe() -> the derived frame exists, is a real manifest, and
* r(manifestframe) names it. "Exists" alone is not the claim: the frame must
* carry one row per executed stage, in execution order, with counts filled in.
_tvm_reset
_tvm_master "`work'"
* Every local read by the _tvm_check expression below is initialised HERE,
* before the captured block. A regression that aborts the block part-way leaves
* the rest unset, and an unset macro turns the check expression into a syntax
* error that ends the whole do-file -- so the suite would report fewer failures
* than it found. Sentinel values are chosen to fail the check, never to pass it.
local m_ret ""
local m_rows = -1
local m_ordered = 0
local m_counted = 0
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    local m_ret "`r(manifestframe)'"
    local m_rows = 0
    local m_ordered = 1
    local m_counted = 1
    local _here "`c(frame)'"
    frame change mout_manifest
    local m_rows = _N
    quietly count if missing(n_input) | missing(n_output)
    if r(N) > 0 local m_counted = 0
    * stage_order, if the manifest carries one, must be 1..N in row order.
    capture confirm variable stage_order
    if _rc == 0 {
        quietly count if stage_order != _n
        if r(N) > 0 local m_ordered = 0
    }
    frame change `_here'
}
local rc = _rc
_tvm_hasframe mout_manifest
local m_exists = r(yes)
_tvm_check `=(`rc' == 0 & `m_exists' & "`m_ret'" == "mout_manifest" & ///
    `m_rows' > 0 & `m_ordered' & `m_counted')' ///
    "M1 default builds <frameout>_manifest" ///
    "rc=`rc' exists=`m_exists' ret=`m_ret' rows=`m_rows' ordered=`m_ordered' counted=`m_counted'"

* M2: the default manifest describes the same run the output frame holds --
* its final stage row's output count equals r(N_periods).
_tvm_reset
_tvm_master "`work'"
* Sentinels initialised before the block; see the note at M1.
local m_periods = -1
local m_out_rows = -2
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    local m_periods = r(N_periods)
    local _here "`c(frame)'"
    frame change mout
    local m_out_rows = _N
    frame change `_here'
}
local rc = _rc
_tvm_check `=(`rc' == 0 & `m_periods' == `m_out_rows' & `m_out_rows' > 0)' ///
    "M2 default manifest run matches the committed frame" ///
    "rc=`rc' periods=`m_periods' rows=`m_out_rows'"


**# ===== N: nomanifest =====

* N1: nomanifest -> no derived frame, r(manifestframe) empty.
_tvm_reset
_tvm_master "`work'"
* Sentinels initialised before the block; see the note at M1.
local n_ret "unset"
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout) nomanifest
    local n_ret "`r(manifestframe)'"
}
local rc = _rc
_tvm_hasframe mout_manifest
local n_exists = r(yes)
_tvm_check `=(`rc' == 0 & !`n_exists' & "`n_ret'" == "")' ///
    "N1 nomanifest creates no manifest and returns none" ///
    "rc=`rc' exists=`n_exists' ret=|`n_ret'|"

* N2: the opt-out is a true no-op for the OUTPUT. Three routes -- default,
* explicit manifestframe(), and nomanifest -- must commit byte-identical
* frames. Asserting only that nomanifest built no manifest would not notice a
* manifest branch that had also changed what was committed.
_tvm_reset
capture erase "`work'/tm_def.dta"
capture erase "`work'/tm_expl.dta"
capture erase "`work'/tm_none.dta"
* Sentinels initialised before the block; see the note at M1.
local sig_def "A"
local sig_expl "B"
local sig_none "C"
local d1 = -1
local d2 = -1
capture noisily {
    local _here "`c(frame)'"

    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    local sig_def "`r(datasignature)'"
    frame change mout
    quietly save "`work'/tm_def.dta", replace
    frame change `_here'
    _tvm_reset

    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
        manifestframe(expl)
    local sig_expl "`r(datasignature)'"
    frame change mout
    quietly save "`work'/tm_expl.dta", replace
    frame change `_here'
    _tvm_reset

    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout) nomanifest
    local sig_none "`r(datasignature)'"
    frame change mout
    quietly save "`work'/tm_none.dta", replace
    frame change `_here'

    * cf, not datasignature: the signature folds storage type into its checksum
    * and would call two identical value sets different. Both are checked.
    quietly use "`work'/tm_none.dta", clear
    quietly cf _all using "`work'/tm_def.dta", verbose
    local d1 = r(Nsum)
    quietly use "`work'/tm_none.dta", clear
    quietly cf _all using "`work'/tm_expl.dta", verbose
    local d2 = r(Nsum)
}
local rc = _rc
_tvm_check `=(`rc' == 0 & `d1' == 0 & `d2' == 0 & ///
    "`sig_def'" == "`sig_none'" & "`sig_expl'" == "`sig_none'")' ///
    "N2 nomanifest commits a byte-identical output frame" ///
    "rc=`rc' cf_vs_default=`d1' cf_vs_explicit=`d2' sigs=`sig_def'/`sig_expl'/`sig_none'"

* N3: nomanifest + manifestframe() -> r(198), and nothing was built.
_tvm_reset
_tvm_master "`work'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
    manifestframe(expl) nomanifest
local rc = _rc
_tvm_hasframe mout
local x1 = r(yes)
_tvm_hasframe expl
local x2 = r(yes)
_tvm_check `=(`rc' == 198 & !`x1' & !`x2')' ///
    "N3 nomanifest with manifestframe() is r(198)" ///
    "rc=`rc' mout=`x1' expl=`x2'"


**# ===== E: explicit manifestframe() is unchanged =====

* E1: an explicitly named manifest is used, and no derived frame appears
* alongside it.
_tvm_reset
_tvm_master "`work'"
* Sentinels initialised before the block; see the note at M1.
local e_ret ""
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
        manifestframe(expl)
    local e_ret "`r(manifestframe)'"
}
local rc = _rc
_tvm_hasframe expl
local e_expl = r(yes)
_tvm_hasframe mout_manifest
local e_derived = r(yes)
_tvm_check `=(`rc' == 0 & `e_expl' & !`e_derived' & "`e_ret'" == "expl")' ///
    "E1 explicit manifestframe() used, no derived frame created" ///
    "rc=`rc' expl=`e_expl' derived=`e_derived' ret=`e_ret'"

* E2: an explicit manifestframe() keeps 1.11.0 replace semantics -- exists
* without replace is r(110), exists with replace overwrites. This is the other
* half of the asymmetry: the derived name is NOT treated this way.
_tvm_reset
_tvm_master "`work'"
frame create expl
frame expl {
    quietly set obs 5
    quietly generate byte sentinel = 1
}
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
    manifestframe(expl)
local rc_norep = _rc
_tvm_master "`work'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
    manifestframe(expl) replace
local rc_rep = _rc
local e_over = 0
capture noisily {
    local _here "`c(frame)'"
    frame change expl
    capture confirm variable sentinel
    if _rc != 0 local e_over = 1
    frame change `_here'
}
_tvm_check `=(`rc_norep' == 110 & `rc_rep' == 0 & `e_over')' ///
    "E2 explicit manifestframe() still honours replace" ///
    "no_replace_rc=`rc_norep' replace_rc=`rc_rep' overwritten=`e_over'"


**# ===== L: the name-length boundary =====

* L1: frameout() of 24 characters cannot carry the 9-character suffix -> r(198)
* and nothing is created. The refusal is the point: a truncated destination is
* a write to a frame the caller never asked for.
_tvm_reset
_tvm_master "`work'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' ///
    frameout(twentyfourcharssxxxxxxxx)
local rc = _rc
_tvm_hasframe twentyfourcharssxxxxxxxx
local l_out = r(yes)
_tvm_check `=(`rc' == 198 & !`l_out' & ///
    strlen("twentyfourcharssxxxxxxxx") == 24)' ///
    "L1 frameout() of 24 characters is r(198), nothing created" ///
    "rc=`rc' created=`l_out'"

* L2: 23 characters is the last that fits (23 + 9 = 32) and must succeed. The
* boundary is tested from both sides, so an off-by-one in either direction
* fails one of L1/L2.
_tvm_reset
_tvm_master "`work'"
* Sentinels initialised before the block; see the note at M1.
local l_ret ""
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' ///
        frameout(twentythreecharsxxxxxxx)
    local l_ret "`r(manifestframe)'"
}
local rc = _rc
_tvm_hasframe twentythreecharsxxxxxxx_manifest
local l_man = r(yes)
_tvm_check `=(`rc' == 0 & `l_man' & ///
    "`l_ret'" == "twentythreecharsxxxxxxx_manifest" & ///
    strlen("twentythreecharsxxxxxxx") == 23 & ///
    strlen("twentythreecharsxxxxxxx_manifest") == 32)' ///
    "L2 frameout() of 23 characters succeeds at the 32-character limit" ///
    "rc=`rc' manifest=`l_man' ret=`l_ret'"

* L3: nomanifest lifts the length restriction, because no name is derived.
_tvm_reset
_tvm_master "`work'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' ///
    frameout(twentyfourcharssxxxxxxxx) nomanifest
local rc = _rc
_tvm_hasframe twentyfourcharssxxxxxxxx
local l_out = r(yes)
_tvm_check `=(`rc' == 0 & `l_out')' ///
    "L3 nomanifest accepts a frameout() too long to derive from" ///
    "rc=`rc' created=`l_out'"


**# ===== R: the replace asymmetry =====

* R1: a frame already sitting at the derived name, WITH replace -> r(198).
* This is the rule, and it is the test most likely to be got wrong: the
* obvious implementation reuses the frameout() replace path and overwrites.
_tvm_reset
_tvm_master "`work'"
frame create mout_manifest
frame mout_manifest {
    quietly set obs 7
    quietly generate long caller_sentinel = _n * 3
}
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) replace
local rc = _rc
* What survived matters as much as the rc: the caller's frame keeps its rows.
local r_intact = 0
capture noisily {
    local _here "`c(frame)'"
    frame change mout_manifest
    quietly count if caller_sentinel == _n * 3
    if r(N) == 7 & _N == 7 local r_intact = 1
    frame change `_here'
}
_tvm_hasframe mout
local r_out = r(yes)
_tvm_check `=(`rc' == 198 & `r_intact' & !`r_out')' ///
    "R1 derived name is not overwritten even under replace" ///
    "rc=`rc' intact=`r_intact' frameout_created=`r_out'"

* R2: the same collision without replace -> also r(198), not r(110). The two
* sides must agree, or the error a user sees depends on a flag that is
* documented not to govern this case.
_tvm_reset
_tvm_master "`work'"
frame create mout_manifest
frame mout_manifest {
    quietly set obs 7
    quietly generate long caller_sentinel = _n * 3
}
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
local rc = _rc
local r_intact = 0
capture noisily {
    local _here "`c(frame)'"
    frame change mout_manifest
    quietly count if caller_sentinel == _n * 3
    if r(N) == 7 & _N == 7 local r_intact = 1
    frame change `_here'
}
_tvm_check `=(`rc' == 198 & `r_intact')' ///
    "R2 derived-name collision without replace is r(198), frame intact" ///
    "rc=`rc' intact=`r_intact'"

* R3: nomanifest is one of the two documented ways out, and it works on the
* very collision R1 refused. An error naming an escape that does not work is
* worse than no escape.
_tvm_reset
_tvm_master "`work'"
frame create mout_manifest
frame mout_manifest {
    quietly set obs 7
    quietly generate long caller_sentinel = _n * 3
}
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) nomanifest
local rc = _rc
local r_intact = 0
capture noisily {
    local _here "`c(frame)'"
    frame change mout_manifest
    quietly count if caller_sentinel == _n * 3
    if r(N) == 7 & _N == 7 local r_intact = 1
    frame change `_here'
}
_tvm_check `=(`rc' == 0 & `r_intact')' ///
    "R3 nomanifest clears the derived-name collision, frame untouched" ///
    "rc=`rc' intact=`r_intact'"

* R4: manifestframe() with a different name is the other documented way out.
_tvm_reset
_tvm_master "`work'"
frame create mout_manifest
frame mout_manifest {
    quietly set obs 7
    quietly generate long caller_sentinel = _n * 3
}
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
    manifestframe(expl)
local rc = _rc
_tvm_hasframe expl
local r_expl = r(yes)
local r_intact = 0
capture noisily {
    local _here "`c(frame)'"
    frame change mout_manifest
    quietly count if caller_sentinel == _n * 3
    if r(N) == 7 & _N == 7 local r_intact = 1
    frame change `_here'
}
_tvm_check `=(`rc' == 0 & `r_expl' & `r_intact')' ///
    "R4 manifestframe() clears the derived-name collision, frame untouched" ///
    "rc=`rc' expl=`r_expl' intact=`r_intact'"


* R5: tvbuild's OWN manifest at the derived name is replaceable. A repeated
* identical call is the ordinary case, and the first run leaves a manifest at a
* name the second run derives again. Refusing that -- which the first cut of
* this change did -- makes every default call fail the second time it is run.
_tvm_reset
capture noisily {
    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    local r5_sig1 "`r(datasignature)'"
    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout) replace
    local r5_sig2 "`r(datasignature)'"
}
local rc = _rc
_tvm_hasframe mout_manifest
local r5_man = r(yes)
_tvm_check `=(`rc' == 0 & `r5_man' & "`r5_sig1'" == "`r5_sig2'" & ///
    "`r5_sig1'" != "")' ///
    "R5 a repeated default run replaces tvbuild's own manifest" ///
    "rc=`rc' manifest=`r5_man' sig=`r5_sig1'/`r5_sig2'"

* R6: an ORPHANED manifest -- the state left behind when a user drops the
* output frame alone -- must not make the frameout() name unusable. No replace
* here: the user never named the manifest, so there is nothing for replace to
* authorise, and frameout() itself is free.
_tvm_reset
capture noisily {
    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    frame drop mout
    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
}
local rc = _rc
_tvm_hasframe mout
local r6_out = r(yes)
_tvm_check `=(`rc' == 0 & `r6_out')' ///
    "R6 an orphaned manifest does not strand the frameout() name" ///
    "rc=`rc' frameout=`r6_out'"

* R7: the exemption is keyed to tvbuild's provenance mark, not to the manifest
* SCHEMA. A user frame carrying the same columns -- a saved copy, a hand-built
* table -- is still a user frame and is still refused on both sides of replace.
* Without this test R5/R6 could be satisfied by a check that looked at the
* column names, which would silently overwrite exactly the frame rule 3 exists
* to protect.
_tvm_reset
capture noisily {
    _tvm_master "`work'"
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    * A schema-identical copy with the provenance mark stripped.
    frame copy mout_manifest expl
    frame drop mout_manifest
    frame drop mout
    frame expl: char _dta[tvtools_manifest]
    frame rename expl mout_manifest
}
local setup_rc = _rc
_tvm_master "`work'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) replace
local rc = _rc
local r7_rows = -1
capture noisily {
    local _here "`c(frame)'"
    frame change mout_manifest
    local r7_rows = _N
    frame change `_here'
}
_tvm_hasframe mout
local r7_out = r(yes)
_tvm_check `=(`setup_rc' == 0 & `rc' == 198 & !`r7_out' & `r7_rows' > 0)' ///
    "R7 an unmarked frame with the manifest schema is still refused" ///
    "setup_rc=`setup_rc' rc=`rc' frameout=`r7_out' rows=`r7_rows'"

* R8: the committed manifest actually carries the provenance mark. R5/R6 depend
* on it, so a commit that dropped it would make them pass for the wrong reason
* only until the mark stopped being written at all.
_tvm_reset
_tvm_master "`work'"
local r8_char "unset"
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    local _here "`c(frame)'"
    frame change mout_manifest
    local r8_char : char _dta[tvtools_manifest]
    frame change `_here'
}
local rc = _rc
_tvm_check `=(`rc' == 0 & "`r8_char'" == "tvbuild")' ///
    "R8 the committed manifest carries the tvtools_manifest mark" ///
    "rc=`rc' char=|`r8_char'|"


**# ===== A: the derived name aliases an input =====

* A1: the derived name is the CALLER's frame. Writing it would mean writing the
* master while the command is still reading it.
_tvm_reset
capture frame drop alias_manifest
frame create alias_manifest
* Initialised before the block: if it errors before reaching the assignments,
* the check below must read a defined failure, not an empty macro.
local a_rc = 999
local a_n = -1
local a_hasid = 0
capture noisily {
    local _here "`c(frame)'"
    frame change alias_manifest
    quietly use "`work'/tmb_master.dta", clear
    capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(alias)
    local a_rc = _rc
    local a_n = _N
    local a_hasid = 0
    capture confirm variable pid
    if _rc == 0 local a_hasid = 1
    frame change `_here'
}
_tvm_hasframe alias
local a_out = r(yes)
_tvm_check `=(`a_rc' == 198 & !`a_out' & `a_n' == 3 & `a_hasid')' ///
    "A1 derived name aliasing the caller frame is r(198)" ///
    "rc=`a_rc' frameout_created=`a_out' caller_rows=`a_n' caller_id=`a_hasid'"

* A2: the derived name is a SOURCE frame named in the plan.
_tvm_reset
capture frame drop alias_manifest
frame create alias_manifest
frame alias_manifest {
    quietly use "`work'/tmb_source.dta", clear
}
_tvm_master "`work'"
capture noisily tvbuild, sourceframe(alias_manifest) id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(alias)
local rc = _rc
_tvm_hasframe alias
local a_out = r(yes)
local a_src = 0
capture noisily {
    local _here "`c(frame)'"
    frame change alias_manifest
    if _N == 4 local a_src = 1
    frame change `_here'
}
_tvm_check `=(`rc' == 198 & !`a_out' & `a_src')' ///
    "A2 derived name aliasing a source frame is r(198)" ///
    "rc=`rc' frameout_created=`a_out' source_intact=`a_src'"


**# ===== D: dryrun =====

* D1: a dry run reports the derived name and creates neither destination.
_tvm_reset
_tvm_master "`work'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) dryrun
local rc = _rc
_tvm_hasframe mout
local d_out = r(yes)
_tvm_hasframe mout_manifest
local d_man = r(yes)
_tvm_check `=(`rc' == 0 & !`d_out' & !`d_man')' ///
    "D1 dryrun creates neither the output nor the derived manifest" ///
    "rc=`rc' frameout=`d_out' manifest=`d_man'"

* D2: the dry-run plan display names the frame the committed run would build.
* Read back from a capture log: a plan that reported a name the real run does
* not use is a dry run that describes a different command.
_tvm_reset
_tvm_master "`work'"
local plancap "$TVTOOLS_QA_RUN_DIR/tm_plan.txt"
capture log close tvman
quietly log using "`plancap'", replace text name(tvman) nomsg
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) dryrun
local rc = _rc
quietly log close tvman
local d_named = 0
capture noisily {
    tempname fh
    file open `fh' using "`plancap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "manifestframe()") > 0 & ///
           strpos(`"`macval(line)'"', "mout_manifest") > 0 local d_named = 1
        file read `fh' line
    }
    file close `fh'
}
_tvm_check `=(`rc' == 0 & `d_named')' ///
    "D2 dryrun plan display names the derived manifest frame" ///
    "rc=`rc' named=`d_named'"

* D3: a dry run refuses the derived-name collision exactly as the real run
* does. A dry run that passed a plan the committed run would reject is worse
* than no dry run.
_tvm_reset
_tvm_master "`work'"
frame create mout_manifest
frame mout_manifest {
    quietly set obs 2
    quietly generate byte sentinel = 1
}
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) dryrun replace
local rc = _rc
_tvm_check `=(`rc' == 198)' ///
    "D3 dryrun refuses the derived-name collision the real run refuses" ///
    "rc=`rc'"


**# ===== S: the rest of the return surface is unchanged =====

* S1: turning the manifest on by default must not have altered any other
* returned value. Every shared macro and scalar is compared between the
* default run and a nomanifest run.
_tvm_reset
_tvm_master "`work'"
* Sentinels initialised before the block; see the note at M1.
local s_np_d = -1
local s_ng_d = -1
local s_uc_d = -1
local s_ev_d "A"
local s_fo_d "A"
local s_cv_d "A"
local s_np_n = -2
local s_ng_n = -2
local s_uc_n = -2
local s_ev_n "B"
local s_fo_n "B"
local s_cv_n "B"
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout)
    local s_np_d = r(N_periods)
    local s_ng_d = r(n_gap_ids)
    local s_uc_d = r(uncovered_days)
    local s_ev_d "`r(exposure_vars)'"
    local s_fo_d "`r(frameout)'"
    local s_cv_d "`r(coverage)'"
}
local rc1 = _rc
_tvm_reset
_tvm_master "`work'"
capture noisily {
    tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
        entry(study_entry) exit(study_exit) `INLINE' frameout(mout) nomanifest
    local s_np_n = r(N_periods)
    local s_ng_n = r(n_gap_ids)
    local s_uc_n = r(uncovered_days)
    local s_ev_n "`r(exposure_vars)'"
    local s_fo_n "`r(frameout)'"
    local s_cv_n "`r(coverage)'"
}
local rc2 = _rc
_tvm_check `=(`rc1' == 0 & `rc2' == 0 & `s_np_d' == `s_np_n' & ///
    `s_ng_d' == `s_ng_n' & `s_uc_d' == `s_uc_n' & ///
    "`s_ev_d'" == "`s_ev_n'" & "`s_fo_d'" == "`s_fo_n'" & ///
    "`s_cv_d'" == "`s_cv_n'")' ///
    "S1 the rest of the return surface is identical with and without the manifest" ///
    "rc=`rc1'/`rc2' periods=`s_np_d'/`s_np_n' expo=|`s_ev_d'|/|`s_ev_n'|"

* S2: c(varabbrev) survives the new refusals. Every early exit added in this
* change leaves the captured block, and the restore is outside it.
_tvm_reset
_tvm_master "`work'"
set varabbrev on
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' frameout(mout) ///
    manifestframe(expl) nomanifest
local s_va1 "`c(varabbrev)'"
capture noisily tvbuild, sourceusing("`work'/tmb_source.dta") id(pid) ///
    entry(study_entry) exit(study_exit) `INLINE' ///
    frameout(twentyfourcharssxxxxxxxx)
local s_va2 "`c(varabbrev)'"
set varabbrev off
_tvm_check `=("`s_va1'" == "on" & "`s_va2'" == "on")' ///
    "S2 varabbrev restored after both new refusals" ///
    "after_mutual_exclusion=`s_va1' after_length=`s_va2'"


**# ===== Cleanup and summary =====
_tvm_reset
capture erase "`work'/tm_def.dta"
capture erase "`work'/tm_expl.dta"
capture erase "`work'/tm_none.dta"
capture erase "`work'/tmb_master.dta"
capture erase "`work'/tmb_source.dta"

local pass_count = $TVM_PASS
local fail_count = $TVM_FAIL
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvbuild manifest default Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvbuild_manifest_default tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: $TVM_FAILED"
    exit 1
}
display as result "ALL TESTS PASSED"
