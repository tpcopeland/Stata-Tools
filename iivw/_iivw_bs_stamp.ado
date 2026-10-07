*! _iivw_bs_stamp Version 4.3.5  2026/10/06
*! Stamp iivw shard identity onto a bootstrap replicate file
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass (adds e(iivw_bs_lineage/asig/dsig/dsig_vars) only)

/*
Basic syntax:
  _iivw_bs_stamp , file(spec) [spec(string) resolved]

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
  bootstrap suboptions. Only the filename is used. spec() is the caller's
  estimator-affecting option list (iivw_fit passes its parsed outcome options);
  it enters the outcome-analysis identity.

  Identity stamped (audit F04/F05, 2026-09-27):
    _iivw_shard_asig     outcome-analysis identity: a fingerprint of the
                         estimation-sample data (outcome, covariate columns,
                         weight, id, time, cluster) plus the model spec
    _iivw_shard_lineage  the component draw sets this file holds. A single
                         shard is one component, named from the RNG state its
                         bootstrap consumed; a saved pool carries the union of
                         its inputs', so it cannot be re-pooled with a part of
                         itself
  The same values are added to e() so the anchor can be matched by identity.

See help iivw_bspool for the pooling contract these characteristics support.
*/

capture program drop _iivw_bs_stamp
program define _iivw_bs_stamp, eclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _frame_open = 0
    tempname shardfr
    capture noisily {

    syntax , File(string) [SPEC(string asis) RESOLVED]

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
    * macval(): the name is user text; expanding it again would write one
    * file and stamp another (or execute an unbalanced backtick).
    * resolved: file() is already one literal file name (iivw_bspool resolves
    * its own saving() first), so it is not split at a comma and may hold
    * any character the file system allows, quotes included.
    if "`resolved'" != "" {
        local _fname `"`macval(file)'"'
    }
    else {
        local _spec `"`macval(file)'"'
        gettoken _fname _rest : _spec, parse(",")
        local _fname `macval(_fname)'
    }
    if `"`macval(_fname)'"' == "" {
        display as error "_iivw_bs_stamp: empty filename in saving() spec"
        error 198
    }

    * Resolve EXACTLY as bootstrap's saving() does: .dta is appended only when
    * the filename carries no suffix at all. Probing `name.dta' first stamped
    * the wrong file whenever both x.dta and x.dta.dta existed: saving(x.dta)
    * wrote x.dta and this rewrote x.dta.dta (audit F06). A file that is not
    * at the one resolved path is a bootstrap that did not write what it was
    * told to, which must not pass silently.
    mata: st_local("_sfx", pathsuffix(st_local("_fname")))
    if `"`_sfx'"' == "" {
        local _target `"`macval(_fname)'.dta"'
    }
    else {
        local _target `"`macval(_fname)'"'
    }
    capture confirm file `"`macval(_target)'"'
    if _rc {
        display as error "_iivw_bs_stamp: no replicate file at `macval(_fname)'"
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
    * Outcome-analysis identity (audit F04)
    * -------------------------------------------------------------------
    * A pooled result re-stamping its saved file already carries the identity
    * it was pooled under (checked equal across every input); it may have no
    * data in memory at all. A fresh fit computes it from the estimation sample.
    local _pooled = ("`e(iivw_bs_pooled)'" == "1")
    if `_pooled' {
        local _asig    "`e(iivw_bs_asig)'"
        local _lineage "`e(iivw_bs_lineage)'"
        if "`_asig'" == "" | "`_lineage'" == "" {
            display as error "_iivw_bs_stamp: pooled result carries no analysis identity or lineage"
            error 459
        }
    }
    else {
        local _id   "`e(iivw_id)'"
        local _time "`e(iivw_time)'"
        if "`_id'" == "" {
            display as error "_iivw_bs_stamp: e(iivw_id) is empty; cannot key the analysis identity"
            error 459
        }
        * The bound columns: outcome, every coefficient column that is a
        * variable (generated time/interaction/dummy columns included), the
        * weight, the key and the cluster. Recorded in e() so the pooler
        * re-verifies exactly this list against the live data.
        local _cols : colnames e(b)
        local _dvars "`e(depvar)'"
        foreach _c of local _cols {
            capture confirm numeric variable `_c', exact
            if !_rc local _dvars "`_dvars' `_c'"
        }
        local _dvars "`_dvars' `e(iivw_weight_var)' `_id' `_time' `e(iivw_cluster)'"

        * The engine can consume model inputs that have no coefficient stripe.
        * Read the observed fit's own resolved roles instead of reparsing
        * user option abbreviations.
        if "`e(iivw_model)'" == "gee" {
            local _offset "`e(offset)'"
            * glm records exposure(expo) as e(offset) = ln(expo)
            if substr("`_offset'", 1, 3) == "ln(" & ///
                substr("`_offset'", -1, 1) == ")" {
                local _offset = substr("`_offset'", 4, strlen("`_offset'") - 4)
            }
            if "`_offset'" != "" {
                confirm numeric variable `_offset', exact
                local _dvars "`_dvars' `_offset'"
            }
            local _trials "`e(m)'"
            if "`_trials'" != "" {
                capture confirm number `_trials'
                if _rc {
                    confirm numeric variable `_trials', exact
                    local _dvars "`_dvars' `_trials'"
                }
            }
        }
        else if "`e(iivw_model)'" == "mixed" {
            local _auxvars "`e(rbyvar)' `e(timevar)' `e(spcoordvars)'"
            foreach _v of local _auxvars {
                confirm variable `_v', exact
                local _dvars "`_dvars' `_v'"
            }
        }
        local _dvars : list uniq _dvars
        local _dvars : list retokenize _dvars
        tempvar _es
        quietly gen byte `_es' = e(sample)
        quietly count if `_es'
        if r(N) == 0 {
            display as error "_iivw_bs_stamp: e(sample) is empty; cannot fingerprint the analysis"
            error 459
        }
        quietly _iivw_weight_signature, analysis(`_dvars') key(`_id') ///
            timevar(`_time') touse(`_es')
        local _draw "`r(signature)'"
        _iivw_bs_stamp_hash, text(`"`_draw'"')
        local _dsig "`r(hash)'"

        local _bfull : colfullnames e(b)
        local _N = e(N)
        local _aparts `"`_dsig'|b=`_bfull'|N=`_N'|model=`e(iivw_model)'|ucmd=`e(iivw_underlying_cmd)'|vf=`e(varfunct)'|lk=`e(linkt)'|wt=`e(iivw_weighttype)'|refit=`e(iivw_refitweights)'|unw=`e(iivw_unweighted)'|ts=`e(iivw_timespec)'|cl=`e(iivw_cluster)'|wv=`e(iivw_weight_var)'|tiv=`e(iivw_treat_in_visit)'|wsig=`e(iivw_wsig)'|spec=`spec'"'
        _iivw_bs_stamp_hash, text(`"`_aparts'"')
        local _asig "a2:`r(hash)'"
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
        use `"`macval(_target)'"', clear

        * Lineage of a single shard: the exact RNG state its bootstrap
        * consumed, which bootstrap itself records. Same state means same
        * draws, so the name is shared exactly by the files that duplicate
        * each other and by nothing else.
        if !`_pooled' {
            local _rngst : char _dta[seed]
            if `"`_rngst'"' == "" {
                display as error "_iivw_bs_stamp: `macval(_target)' records no RNG state"
                error 459
            }
            _iivw_bs_stamp_hash, text(`"`_rngst'"')
            local _lineage "s:`r(hash)'"
        }

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
        char _dta[_iivw_shard_asig]            "`_asig'"
        char _dta[_iivw_shard_lineage]         "`_lineage'"
        char _dta[_iivw_shard_pooled]          "`_pooled'"
        if `_pooled' {
            char _dta[_iivw_shard_rngstream]   "`e(iivw_bs_streams)'"
            char _dta[_iivw_shard_seed]        "`e(iivw_bs_seeds)'"
        }
        else {
            char _dta[_iivw_shard_rngstream]   "`e(iivw_rngstream)'"
            char _dta[_iivw_shard_seed]        "`e(iivw_vce_seed)'"
        }

        quietly save `"`macval(_target)'"', replace
    }

    * The anchor side of the same identity. Nothing else in e() is touched.
    if !`_pooled' {
        ereturn local iivw_bs_asig      "`_asig'"
        ereturn local iivw_bs_dsig      "`_dsig'"
        ereturn local iivw_bs_dsig_vars "`_dvars'"
        ereturn local iivw_bs_lineage   "`_lineage'"
    }

    }
    local rc = _rc
    if `_frame_open' capture frame drop `shardfr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* ---------------------------------------------------------------------------
* Compact fingerprint of a string: two independent Jenkins hashes (forward and
* reversed text) plus the length. Used for identities that must fit in a _dta
* characteristic and compare as exact strings. Like the weight signature, this
* detects accident, not an adversary. iivw_bspool repeats the same three-part
* expression inline rather than call this bundled program, which an installed
* copy only defines once _iivw_bs_stamp.ado has been loaded.
* ---------------------------------------------------------------------------
capture program drop _iivw_bs_stamp_hash
program define _iivw_bs_stamp_hash, rclass
    version 16.0
    syntax , TEXT(string asis)
    local text `text'
    mata: st_local("_h", ///
        strofreal(hash1(st_local("text")), "%12.0f") + "." + ///
        strofreal(hash1(strreverse(st_local("text"))), "%12.0f") + "." + ///
        strofreal(strlen(st_local("text"))))
    return local hash "`_h'"
end
