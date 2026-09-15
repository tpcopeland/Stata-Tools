*! _iivw_bs_stamp Version 4.2.0  2026/09/15
*! Stamp iivw shard identity onto a bootstrap replicate file
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: none (reads e(), touches neither r() nor e())

/*
Basic syntax:
  _iivw_bs_stamp , file(spec)

Description:
  Called by iivw_fit immediately after a bootstrap fit that used saving().
  Stata's bootstrap prefix writes the replicate draws with enough metadata to
  recompute a variance (the observed estimates, the column stripes, the
  estimation-sample size, the pre-draw RNG state) but with nothing that says
  WHICH iivw fit produced them. Pooling two files that happen to have the same
  column names but came from different weights, a different weight type, or a
  different outcome specification would average draws from two different
  estimators and report the result as one.

  This writes the missing half of that identity into the file's _dta
  characteristics, so a shard artifact is self-describing and iivw_bspool can
  refuse a set that does not agree. Everything stamped is read back out of
  e(), not passed in, so the stamp cannot drift from what iivw_fit returned.

  file(spec) is the saving() spec as the user typed it -- filename plus any
  bootstrap suboptions. Only the filename is used.

See help iivw_bspool for the pooling contract these characteristics support.
*/

capture program drop _iivw_bs_stamp
program define _iivw_bs_stamp
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _frame_open = 0
    tempname shardfr
    capture noisily {

    syntax , File(string)

    * -------------------------------------------------------------------
    * Resolve the filename out of the saving() spec
    * -------------------------------------------------------------------
    * saving() is Stata's grammar: filename optionally followed by a comma and
    * bootstrap's own suboptions (double, every(#), replace). gettoken honours
    * quoting, so a quoted path containing a comma survives; an unquoted one
    * was already ambiguous to bootstrap itself.
    *
    * file() takes string, not string asis, deliberately. asis keeps the
    * caller's outer quotes, and gettoken then reads the whole quoted spec as
    * one token -- so saving(reps, replace) resolved to a filename literally
    * called "reps, replace" and the stamp errored with file not found.
    local _spec `"`file'"'
    gettoken _fname _rest : _spec, parse(",")
    local _fname `_fname'
    if `"`_fname'"' == "" {
        display as error "_iivw_bs_stamp: empty filename in saving() spec"
        error 198
    }

    * bootstrap appends .dta when the spec carries no suffix. Probe that form
    * first, then the literal one, so both spellings resolve. A file that
    * resolves as neither is a bootstrap that did not write what it was told
    * to, which must not pass silently.
    local _target ""
    capture confirm file `"`_fname'.dta"'
    if !_rc local _target `"`_fname'.dta"'
    else {
        capture confirm file `"`_fname'"'
        if !_rc local _target `"`_fname'"'
    }
    if `"`_target'"' == "" {
        display as error "_iivw_bs_stamp: no replicate file at `_fname'"
        display as error "  the bootstrap prefix was given saving() but wrote no file"
        error 601
    }

    * -------------------------------------------------------------------
    * Build identity
    * -------------------------------------------------------------------
    * Version comes from the installed iivw.ado *! header, the same single
    * source `iivw version' reads, so a bump cannot leave a stale literal
    * behind here. An install whose header cannot be read is a broken install,
    * not a nameless one (IIVW-14b): refuse rather than stamp "unknown" and let
    * the pooler accept a shard of unknown provenance.
    local _pkgversion ""
    capture findfile iivw.ado
    if !_rc {
        local _adopath "`r(fn)'"
        tempname _fh
        capture file open `_fh' using "`_adopath'", read text
        if !_rc {
            file read `_fh' _headerline
            file close `_fh'
            if regexm(`"`_headerline'"', "Version ([0-9.]+)") {
                local _pkgversion = regexs(1)
            }
        }
    }
    if "`_pkgversion'" == "" {
        display as error "_iivw_bs_stamp: cannot read the package version from iivw.ado"
        display as error "  a shard file that cannot name the build that wrote it"
        display as error "  cannot be pooled; reinstall the package"
        error 601
    }

    if "`e(iivw_cmd)'" != "iivw_fit" {
        display as error "_iivw_bs_stamp: no current iivw_fit results to stamp"
        error 301
    }

    * -------------------------------------------------------------------
    * Write the characteristics
    * -------------------------------------------------------------------
    * A frame, not preserve/restore: the caller's analysis data is mid-fit and
    * carries the weight contract characteristics, and nothing here should come
    * near it. Frames also leave e() alone, which matters because iivw_fit has
    * already posted its results by this point.
    frame create `shardfr'
    local _frame_open = 1
    frame `shardfr' {
        use `"`_target'"', clear

        char _dta[_iivw_shard] "1"
        char _dta[_iivw_shard_version]         "`_pkgversion'"
        char _dta[_iivw_shard_cmd]             "`e(iivw_cmd)'"
        char _dta[_iivw_shard_wsig]            "`e(iivw_wsig)'"
        char _dta[_iivw_shard_model]           "`e(iivw_model)'"
        char _dta[_iivw_shard_weighttype]      "`e(iivw_weighttype)'"
        char _dta[_iivw_shard_refitweights]    "`e(iivw_refitweights)'"
        char _dta[_iivw_shard_unweighted]      "`e(iivw_unweighted)'"
        char _dta[_iivw_shard_cluster]         "`e(iivw_cluster)'"
        char _dta[_iivw_shard_timespec]        "`e(iivw_timespec)'"
        char _dta[_iivw_shard_citype]          "`e(iivw_ci_type)'"
        char _dta[_iivw_shard_level]           "`e(level)'"
        char _dta[_iivw_shard_vce]             "`e(iivw_vce)'"
        char _dta[_iivw_shard_depvar]          "`e(depvar)'"
        char _dta[_iivw_shard_reps_requested]  "`e(iivw_bs_reps_requested)'"
        char _dta[_iivw_shard_reps_completed]  "`e(iivw_bs_reps_completed)'"
        char _dta[_iivw_shard_reps_failed]     "`e(iivw_bs_reps_failed)'"
        char _dta[_iivw_shard_status]          "`e(iivw_inference_status)'"
        char _dta[_iivw_shard_rngstream]       "`e(iivw_rngstream)'"
        char _dta[_iivw_shard_seed]            "`e(iivw_vce_seed)'"

        save `"`_target'"', replace
    }

    }
    local rc = _rc
    if `_frame_open' capture frame drop `shardfr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
