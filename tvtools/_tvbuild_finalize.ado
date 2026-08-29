*! _tvbuild_finalize Version 1.17.1  2026/08/30
*! Attach master payload and impose tvbuild's committed schema on the result
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Everything between the last engine and the commit: the master's own columns
* are attached once, the committed variable order of Section 12.4 is imposed,
* every metadata category is re-asserted rather than assumed, the provenance
* characteristics are written, and the result is checked against the schema
* that was planned before any source was opened.
*
* Master payload is attached ONCE, here, rather than carried through every
* intermediate stage. A person-level column copied into each source before the
* merge would be duplicated per source, renamed by the merge engine's
* collision rules, and apportioned by nothing -- and it would make the
* intermediate frames wider for no analytical reason.
*
* The schema check is the part that earns its place. It compares the variables
* actually present against the set resolved before source acquisition, in BOTH
* directions. A missing name is an obvious failure; an EXTRA name is the one
* that matters, because that is what a leaked event date, a surviving frame
* link, or an internal staging column looks like, and none of those changes a
* single value in the columns a value-only comparison would check.
*
* Returns:
*   r(N_periods)     rows in the finalised result
*   r(N_persons)     distinct persons in the finalised result
*   r(datasignature) Stata data signature of the finalised result

capture program drop _tvbuild_finalize
program define _tvbuild_finalize, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , RESframe(name) XWALKframe(name) MASTERframe(name) ///
        ID(name) ENTry(name) EXIt(name) ///
        STARTName(name) STOPName(name) DATEFormat(string) ///
        MASTERIDtype(string) SCHEMA(string) COVerage(string) ///
        [KEEPvars(string) DROPdates(integer 0) ///
         DROPVars(string) EVENTVar(name) TIMEVar(name) ENUMVar(name) ///
         GAPSTARTVar(name) GAPSTOPVar(name)]

    frame change `resframe'

    **# Event input roles never become committed payload
    * The event engine carries its own date and competing-risk columns into
    * its result. They described the input, not the constructed exposure, and
    * Section 12.7 keeps them out of the committed schema.
    foreach v of local dropvars {
        capture drop `v'
    }

    **# Master columns, attached once through the crosswalk
    local _fetch ""
    if !`dropdates' local _fetch "`entry' `exit'"
    local _fetch "`_fetch' `keepvars'"
    local _fetch : list uniq _fetch
    if "`_fetch'" != "" {
        quietly frlink m:1 `id', frame(`xwalkframe')
        foreach v of local _fetch {
            quietly frget `v' = `v', from(`xwalkframe')
        }
        capture drop `xwalkframe'
        * Only the study bounds are checked for a failed match. A keepvar may
        * legitimately be missing in the master; a missing entry/exit means the
        * link itself did not resolve, which no later check would notice.
        if !`dropdates' {
            quietly count if missing(`entry') | missing(`exit')
            if r(N) > 0 {
                frame change `_caller_frame'
                noisily display as error ///
                    "tvbuild: `r(N)' result row(s) could not be matched back to a master window"
                exit 459
            }
        }
        _tvbuild_carry_meta, srcframe(`xwalkframe') dstframe(`resframe') ///
            vars(`_fetch')
        frame change `resframe'
    }

    **# Bounds
    quietly recast double `startname'
    quietly recast double `stopname'
    format `startname' `dateformat'
    format `stopname'  `dateformat'
    label variable `startname' "Interval start"
    label variable `stopname'  "Interval stop"

    **# The identifier carries the master's type, format, and labels
    local _cur : type `id'
    if "`_cur'" != "`masteridtype'" quietly recast `masteridtype' `id'
    frame change `_caller_frame'
    _tvbuild_carry_meta, srcframe(`xwalkframe') dstframe(`resframe') vars(`id')

    frame change `resframe'

    **# Committed variable order
    order `schema'

    **# Schema check, both directions
    quietly ds
    local _present "`r(varlist)'"
    local _extra : list _present - schema
    local _missing : list schema - _present
    if "`_missing'" != "" {
        frame change `_caller_frame'
        noisily display as error ///
            "tvbuild: the result is missing planned variable(s):`_missing'"
        exit 498
    }
    if "`_extra'" != "" {
        frame change `_caller_frame'
        noisily display as error ///
            "tvbuild: the result carries variable(s) that are not part of the committed schema:`_extra'"
        noisily display as error ///
            "this is an internal error; no destination frame was created or changed"
        exit 498
    }

    **# Structural invariants
    quietly count if missing(`startname') | missing(`stopname')
    if r(N) > 0 {
        frame change `_caller_frame'
        noisily display as error "tvbuild: `r(N)' result row(s) have a missing bound"
        exit 498
    }
    quietly count if `startname' > `stopname'
    if r(N) > 0 {
        frame change `_caller_frame'
        noisily display as error "tvbuild: `r(N)' result row(s) have start after stop"
        exit 498
    }

    local _n_out = _N
    tempvar _tag
    quietly egen byte `_tag' = tag(`id')
    quietly count if `_tag'
    local _n_pers = r(N)
    drop `_tag'

    * Every master person must survive to the committed result. A person lost
    * during merge or event work is an error, not a silently smaller cohort.
    frame change `masterframe'
    local _n_master = _N
    frame change `resframe'
    if `_n_pers' != `_n_master' {
        local _lost = `_n_master' - `_n_pers'
        frame change `_caller_frame'
        noisily display as error ///
            "tvbuild: `_lost' master person(s) have no row in the result; nothing was committed"
        exit 2000
    }

    **# Dataset label and provenance characteristics
    frame change `masterframe'
    local _dtalab : data label
    frame change `resframe'
    if `"`_dtalab'"' != "" label data `"`_dtalab'"'

    char _dta[tvtools_tvbuild]           "tvbuild"
    char _dta[tvtools_tvbuild_schema]    "1"
    char _dta[tvtools_tvbuild_coverage]  "`coverage'"
    char _dta[tvtools_tvbuild_start]     "`startname'"
    char _dta[tvtools_tvbuild_stop]      "`stopname'"
    char _dta[tvtools_tvbuild_event]     "`eventvar'"
    char _dta[tvtools_tvbuild_committed] "1"

    sort `id' `startname' `stopname'

    * datasignature is a reproducible data identity. It says nothing about
    * formats, labels, characteristics, or value-label definitions, which is
    * why the schema and metadata assertions above are not replaced by it.
    quietly datasignature
    local _sig "`r(datasignature)'"

    frame change `_caller_frame'

    return local datasignature "`_sig'"
    return scalar N_persons = `_n_pers'
    return scalar N_periods = `_n_out'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end
