clear all
version 16.0
set varabbrev off

* test_iivw_coverage_gate.do - structural tests for the SOL-04 coverage gate
*
* WHY THIS EXISTS
* ---------------
* validation_iivw_inference.do is the SOL-04 release gate: 1000 simulated
* datasets x 999 bootstrap draws x 3 families. It is far too expensive to run
* in a lane, so its ACCEPTANCE arithmetic is exercised by the release run
* itself -- but its AGGREGATION machinery is not, and that machinery is where
* a wrong coverage number gets manufactured at rc=0.
*
* Three defects have been found in it, all of the same class: combine produced
* a confident verdict over rows that were not the study it claimed.
*
*   1. combine re-ran the entire 1..SIMS simulation and then DISCARDED every
*      row in favour of rowsin() -- correct number, at the cost of a second
*      full study (~a day). Fixed 2026-07-21 by guarding the loop.
*   2. A missing INTERIOR block was accepted. The tiling proof was a min/max
*      check on sim, so absent replications looked exactly like failed draws:
*      deleting block 376-500 of 8 left min=1, max=1000 and produced a verdict
*      over 875 replications reported as sims=1000. Fixed 2026-07-21 by
*      proving coverage from the block RANGES.
*   3. The verdict's reps=/sims=/seed labels were free text copied from the
*      command arguments and never checked against the rows. Measured: one
*      fabricated pool combined to "gate=PASS sims=1000 reps=999" and
*      "gate=PASS sims=1000 reps=10" with byte-identical coverage. This was
*      reachable rather than hypothetical -- run_coverage_gate.sh skips a
*      block whose .dta is already in the pool, and the pool filename encodes
*      only family and range, so the REPS=10 plumbing pilot the runbook
*      describes leaves 20 files named exactly what the REPS=999 run wants.
*      The real run would skip all of them and certify pilot rows as the
*      release gate. Fixed 2026-07-22 by stamping (reps, sims, seed) into
*      every block row and verifying them in combine.
*
* Defects 1 and 2 were verified interactively only; the runbook recorded that
* as an open item. This file is that coverage.
*
* HOW IT TESTS
* ------------
* Every arm FABRICATES a block pool rather than simulating one. That is the
* point: the aggregation contract is about which rows are present and what
* they claim about themselves, not about their numeric values, so fabricated
* rows exercise it exactly and cost seconds instead of days. Each arm shells
* out to a real `stata-mp -b do validation_iivw_inference.do combine_iiw ...`
* in an isolated tree and reads the log, because that is how the gate is
* actually invoked -- an in-process `do` would be terminated by the do-file's
* own exit codes.
*
* NOTE ON THE PASS ARM (G3). It asserts that a verdict is PRODUCED, not that
* it is PASS-on-real-data. The coverage values are fabricated, so the verdict
* is a statement about the machinery reaching its acceptance rule, nothing
* more. Only the real release run says anything about the estimator.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_coverage_gate.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_coverage_gate.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* ---------------------------------------------------------------------------
* Fabricate one stamped block file covering sims FROM..TO.
* reps/sims/seed are what the block CLAIMS it was produced under; the arms
* vary them independently of what combine is later invoked with.
* ---------------------------------------------------------------------------
capture program drop _cg_block
program define _cg_block
    version 16.0
    syntax , dir(string) from(integer) to(integer) ///
        reps(integer) sims(integer) seed(integer) [STAMPED(integer 1)]
    quietly {
        clear
        local n = `to' - `from' + 1
        set obs `n'
        gen int sim = `from' + _n - 1
        gen int arm = 1
        if `stamped' {
            gen long blk_reps = `reps'
            gen long blk_sims = `sims'
            gen long blk_seed = `seed'
        }
        * Values are placeholders. Coverage is set to a fixed 0.94 pattern so
        * the arithmetic is deterministic and no arm depends on a random draw.
        gen double b_refit   = 0.5
        gen double se_refit  = 0.05
        gen byte   cov_refit = mod(_n, 100) > 6
        gen double b_fix   = 0.5
        gen double se_fix  = 0.0515
        gen byte   cov_fix = mod(_n, 100) > 5
        gen double b_fwb   = 0.5
        gen double se_fwb  = 0.052
        gen byte   cov_fwb = mod(_n, 100) > 5
        gen byte   cov_naive = mod(_n, 100) > 9
        gen int nrow = 1000
        gen int nsub = 250
        local tag = string(`from', "%05.0f") + "_" + string(`to', "%05.0f")
        save "`dir'/iiw_`tag'.dta", replace
    }
end

* ---------------------------------------------------------------------------
* Build an isolated tree, fill _inf_blocks per the caller's recipe, run
* combine_iiw, and return the log path.  Returns r(logfile).
* ---------------------------------------------------------------------------
capture program drop _cg_combine
program define _cg_combine, rclass
    version 16.0
    syntax , pkgdir(string) root(string) combreps(integer) combsims(integer) ///
        combseed(integer)
    quietly {
        * Clean ONLY the package copy. `root'/blocks holds the fabricated pool
        * the caller just wrote; wiping `root' wholesale destroys it, every
        * combine then exits 601 "no block files", and the arms that assert the
        * ABSENCE of a verdict pass vacuously. That false green was observed.
        shell rm -rf "`root'/iivw"
        shell mkdir -p "`root'"
        shell cp -a "`pkgdir'" "`root'/iivw"
        shell rm -rf "`root'/iivw/qa/_inf_blocks"
        * NB: a closing double quote immediately followed by slash-star opens a
        * Stata BLOCK COMMENT. Writing the qa path in quotes and then appending
        * a slash-star glob outside them silently swallows the rest of the file;
        * the run dies at r(612) far from the offending line. Keep every glob's
        * slash INSIDE the quotes. (This comment cannot show the sequence
        * literally -- it would trigger the same bug here.)
        shell find "`root'/iivw/qa" -maxdepth 1 -name '*.log' -delete
    }
    * caller has already written blocks into `root'/blocks
    quietly shell mkdir -p "`root'/iivw/qa/_inf_blocks"
    quietly shell cp -f "`root'/blocks/"*.dta "`root'/iivw/qa/_inf_blocks/"
    * HARD TIMEOUT. Without it, a regression that lets combine re-run the
    * simulation makes this suite HANG for days rather than fail -- a hanging
    * test is worse than a missing one, because a lane that never returns gets
    * killed and read as infrastructure trouble. timeout turns that regression
    * into a missing RESULT line, which every arm below already treats as a
    * failure. 180s is ~1600x the measured aggregation cost (0.07-0.11s).
    quietly shell cd "`root'/iivw/qa" && timeout 180 stata-mp -b do validation_iivw_inference.do ///
        combine_iiw `combsims' `combreps' `combseed' > /dev/null 2>&1
    return local logfile "`root'/iivw/qa/validation_iivw_inference.log"
end

* ---------------------------------------------------------------------------
* Grep a log for a literal string. Returns r(found) = 1/0.
* ---------------------------------------------------------------------------
capture program drop _cg_grep
program define _cg_grep, rclass
    version 16.0
    syntax , logfile(string) pattern(string)
    tempfile out
    quietly shell grep -a -c -F "`pattern'" "`logfile'" > "`out'" 2>/dev/null
    tempname fh
    file open `fh' using "`out'", read text
    file read `fh' line
    file close `fh'
    local n = real(trim("`line'"))
    if missing(`n') local n = 0
    return scalar found = (`n' > 0)
end

tempfile dummy
local root "`c(tmpdir)'/iivw_cg_`=int(runiform()*1e9)'"

* ===========================================================================
* G1 - a missing INTERIOR block must refuse, not be read as failed draws
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        * omit 351-400 entirely
        if `f' != 351 {
            _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
                reps(999) sims(1000) seed(20260715)
        }
    }
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("replication(s) covered by NO block")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("first gap at sim 351")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS G1: a missing interior block refuses and yields no verdict"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G1"
    display "FAIL G1: a missing interior block did not refuse"
}

* ===========================================================================
* G2 - overlapping blocks must refuse
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(999) sims(1000) seed(20260715)
    }
    * an extra block re-covering 101-200
    _cg_block, dir("`root'/blocks") from(101) to(200) ///
        reps(999) sims(1000) seed(20260715)
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS G2: overlapping blocks refuse and yield no verdict"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G2"
    display "FAIL G2: overlapping blocks did not refuse"
}

* ===========================================================================
* G3 - a complete, consistently stamped pool REACHES the acceptance rule
*      (positive control: without it, G1/G2/G4-G6 would all pass on a combine
*       that refuses everything unconditionally)
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(999) sims(1000) seed(20260715)
    }
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("combine(iiw): 20 block(s), 1000 of 1000 replications")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 1
}
if _rc == 0 {
    local ++pass_count
    display "PASS G3: a complete consistent pool reaches the acceptance rule"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G3"
    display "FAIL G3: a complete consistent pool did not reach a verdict"
}

* ===========================================================================
* G4 - blocks predating the provenance stamp must refuse, not be assumed
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(999) sims(1000) seed(20260715) stamped(0)
    }
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("block rows carry no blk_reps stamp")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS G4: unstamped blocks refuse and yield no verdict"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G4"
    display "FAIL G4: unstamped blocks did not refuse"
}

* ===========================================================================
* G5 - THE PILOT-POOL DEFECT. Blocks produced at reps=10 must not be
*      certified by a combine invoked at reps=999.
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(10) sims(1000) seed(20260715)
    }
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("blocks were produced at blk_reps=10")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS G5: a reps=10 pilot pool cannot be certified as reps=999"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G5"
    display "FAIL G5: a pilot pool was certified under the wrong reps label"
}

* ===========================================================================
* G6 - blocks that disagree AMONG THEMSELVES must refuse. This is the
*      resumed-run case: half the pool from one configuration, half another.
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        local r = cond(`f' <= 500, 10, 999)
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(`r') sims(1000) seed(20260715)
    }
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("blocks disagree on blk_reps")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS G6: a pool mixing two configurations refuses"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G6"
    display "FAIL G6: a pool mixing two configurations did not refuse"
}

* ===========================================================================
* G7 - a mismatched master SEED must refuse. Same defect class as G5, and the
*      one an operator is most likely to hit by editing the launch line.
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(999) sims(1000) seed(20260715)
    }
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(19990101)
    local lg "`r(logfile)'"
    _cg_grep, logfile("`lg'") pattern("blocks were produced at blk_seed=20260715")
    assert r(found) == 1
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS G7: a mismatched master seed refuses"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G7"
    display "FAIL G7: a mismatched master seed did not refuse"
}

* ===========================================================================
* G8 - combine must NOT re-run the simulation.
*
* This is defect 1. It is a runtime assertion, which is normally a bad idea --
* but the pre-fix and post-fix behaviours differ by three orders of magnitude
* (a second full 1000x999 study versus pure aggregation), so the ceiling below
* is nowhere near either the true cost or a plausible slow-box excursion.
* Measured post-fix on this fixture: a few seconds, dominated by Stata startup
* and the tree copy. G3 already ran the same combine; this arm times it.
* ===========================================================================
local ++test_count
capture noisily {
    quietly shell rm -rf "`root'/blocks"
    quietly shell mkdir -p "`root'/blocks"
    forvalues f = 1(50)1000 {
        local t = `f' + 49
        _cg_block, dir("`root'/blocks") from(`f') to(`t') ///
            reps(999) sims(1000) seed(20260715)
    }
    timer clear 1
    timer on 1
    _cg_combine, pkgdir("`pkg_dir'") root("`root'") ///
        combreps(999) combsims(1000) combseed(20260715)
    timer off 1
    local lg "`r(logfile)'"
    quietly timer list 1
    local elapsed = r(t1)
    display as text "  combine elapsed: `elapsed' s (ceiling 180)"
    _cg_grep, logfile("`lg'") pattern("RESULT: validation_iivw_inference iiw gate=")
    assert r(found) == 1
    assert `elapsed' < 180
}
if _rc == 0 {
    local ++pass_count
    display "PASS G8: combine aggregates without re-running the study"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' G8"
    display "FAIL G8: combine appears to have re-run the simulation"
}

quietly shell rm -rf "`root'"

**# SUMMARY

iivw_qa_summary, name(test_iivw_coverage_gate) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
