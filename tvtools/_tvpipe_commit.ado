*! _tvpipe_commit Version 1.10.1  2026/07/30
*! Commit tvpipe's result and optional manifest as one transaction
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Two destinations, one transaction. A run that commits the result and then
* fails on the manifest must leave the user exactly as it found them, because
* the alternative -- a committed result whose provenance frame is missing or
* stale -- is worse than no result at all.
*
* The rule that makes this work is that a destination which existed on entry is
* copied to a tempnamed backup BEFORE anything is written to it, and a
* destination that did not exist is dropped rather than restored. Both halves
* are needed: restoring a backup that was never taken would fail, and dropping
* a frame the user already had would destroy data this command never owned.
*
* Post-commit verification re-reads what was actually committed and compares
* its row count, its schema, and its Stata data signature against the scratch
* result. `frame copy' into the current session is expected to be faithful --
* the point is that "expected to be" is not evidence, and this is the last
* moment at which a failure can still be undone.
*
* Returns:
*   r(N_committed)   rows verified in the committed output frame
*   r(datasignature) signature recomputed on the committed output
*   r(rolled_back)   1 when a failure triggered a rollback

capture program drop _tvpipe_commit
program define _tvpipe_commit, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    * Initialised before the captured block: a failure between taking a backup
    * and recording that fact would otherwise leave the rollback zone unable to
    * tell a backup that exists from one that does not.
    local _fo_backed = 0
    local _mf_backed = 0
    local _fo_written = 0
    local _mf_written = 0
    local _rolled = 0
    tempname _bkfo _bkmf

    capture noisily {

    syntax , RESframe(name) FRAMEOut(name) SCHEMA(string) ///
        NROWS(integer) SIGnature(string) ///
        [MANframe(name) MANIFESTframe(name) ///
         FRAMEOUTExists(integer 0) MANIFESTExists(integer 0)]

    local _do_manifest = ("`manifestframe'" != "")

    **# 1. Back up whatever exists
    if `frameoutexists' {
        frame copy `frameout' `_bkfo'
        local _fo_backed = 1
    }
    if `_do_manifest' & `manifestexists' {
        frame copy `manifestframe' `_bkmf'
        local _mf_backed = 1
    }

    **# 2. Commit
    * quietly, not capture: `frame copy ..., replace' prints a note when the
    * destination does not exist yet, and a note in the middle of a commit
    * reads like a warning about the data. Errors still raise their code.
    quietly frame copy `resframe' `frameout', replace
    local _fo_written = 1
    if `_do_manifest' {
        quietly frame copy `manframe' `manifestframe', replace
        local _mf_written = 1
    }

    **# 3. Verify what was actually committed
    frame change `frameout'
    local _n_committed = _N
    quietly ds
    local _present "`r(varlist)'"
    quietly datasignature
    local _sig2 "`r(datasignature)'"
    local _pipechar : char _dta[tvtools_pipeline]
    frame change `_caller_frame'

    local _extra : list _present - schema
    local _missing : list schema - _present
    if `_n_committed' != `nrows' | "`_extra'`_missing'" != "" | ///
       "`_sig2'" != "`signature'" | "`_pipechar'" != "tvpipe" {
        noisily display as error ///
            "tvpipe: the committed frame `frameout' does not match the verified result"
        if `_n_committed' != `nrows' ///
            noisily display as error ///
                "  rows: `_n_committed' committed, `nrows' expected"
        if "`_missing'" != "" ///
            noisily display as error "  missing variable(s):`_missing'"
        if "`_extra'" != "" ///
            noisily display as error "  unexpected variable(s):`_extra'"
        if "`_sig2'" != "`signature'" ///
            noisily display as error "  data signature differs from the verified result"
        exit 459
    }

    if `_do_manifest' {
        frame change `manifestframe'
        local _n_man = _N
        frame change `_caller_frame'
        if `_n_man' == 0 {
            noisily display as error ///
                "tvpipe: the committed manifest frame `manifestframe' is empty"
            exit 459
        }
    }

    return local datasignature "`_sig2'"
    return scalar N_committed = `_n_committed'

    }
    local rc = _rc

    * Rollback zone. It runs on the failure path only, and it runs before the
    * frame/varabbrev restore so that a rollback failure can still be reported
    * as an additional critical diagnostic without displacing the original
    * analytical error.
    if `rc' {
        capture frame change `_caller_frame'
        local _rbrc = 0
        if `_fo_written' {
            if `_fo_backed' {
                capture quietly frame copy `_bkfo' `frameout', replace
                if _rc & !`_rbrc' local _rbrc = _rc
            }
            else {
                capture frame drop `frameout'
                if _rc & !`_rbrc' local _rbrc = _rc
            }
            local _rolled = 1
        }
        if `_mf_written' {
            if `_mf_backed' {
                capture quietly frame copy `_bkmf' `manifestframe', replace
                if _rc & !`_rbrc' local _rbrc = _rc
            }
            else {
                capture frame drop `manifestframe'
                if _rc & !`_rbrc' local _rbrc = _rc
            }
            local _rolled = 1
        }
        if `_rbrc' {
            display as error ///
                "tvpipe: CRITICAL -- rollback after the failure above did not complete (rc=`_rbrc')"
            display as error ///
                "inspect frameout()/manifestframe() before using them"
        }
    }

    capture frame change `_caller_frame'
    local _crc = _rc
    * Backups are dropped last, on both paths: on success they are no longer
    * needed, and on failure they have already been copied back.
    capture frame drop `_bkfo'
    capture frame drop `_bkmf'
    capture set varabbrev `_orig_varabbrev'
    if !`_crc' local _crc = _rc
    if !`rc' & `_crc' local rc = `_crc'

    return scalar rolled_back = `_rolled'
    if `rc' exit `rc'
end
