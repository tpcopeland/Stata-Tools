*! _tvpipe_load_source Version 1.10.2  2026/07/31
*! Copy one tvpipe source into a scratch frame under fixed internal names
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Copy one source's structural columns into a scratch work frame under fixed
* internal names, attach the master window through the crosswalk, and report
* the three counts that describe the source before restriction.
*
* The copy is what keeps a user's source frame read-only. It also fixes the
* column names, so every check that follows reads _tvp_start / _tvp_stop /
* _tvp_p# regardless of what the source called them -- a check written against
* a user-supplied name is one macro-expansion mistake away from testing the
* wrong column.
*
* Both the preflight and the Phase 4B construction stage load sources through
* this program, which is why it has its own file: a program that lives inside
* _tvpipe_preflight.ado is in memory only after that file has been run, so the
* second caller would depend on the first having been invoked. It is listed in
* tvtools.pkg and resolves by filename like every other helper.
*
* Returns:
*   r(N_input)          source rows before any restriction
*   r(N_persons)        distinct source persons before any restriction
*   r(N_unmatched_ids)  distinct source persons absent from the master

capture program drop _tvpipe_load_source
program define _tvpipe_load_source, rclass
    version 16.0
    syntax , SRCframe(name) WORKframe(name) XWALKframe(name) WHERE(string) ///
        ID(name) ENTry(name) EXIt(name) ///
        STARTVar(name) STOPVar(name) PAYload(string) ///
        IDISstr(integer) MASTERIDtype(string)

    local _here "`c(frame)'"
    frame change `srcframe'

    foreach v in `id' `startvar' `stopvar' `payload' {
        capture confirm variable `v', exact
        if _rc {
            frame change `_here'
            noisily display as error "`where': variable '`v'' not found in the source"
            exit 111
        }
    }

    local _t : type `id'
    if "`_t'" == "strL" {
        frame change `_here'
        noisily display as error ///
            "`where': the source id is strL; tvtools requires a numeric or fixed-width string identifier"
        exit 109
    }
    local _src_is_str = (substr("`_t'", 1, 3) == "str")
    if `_src_is_str' != `idisstr' {
        frame change `_here'
        noisily display as error ///
            "`where': the source id is `_t' but the master id is `masteridtype'"
        noisily display as error ///
            "tvpipe never converts an identifier; make the two agree before calling"
        exit 106
    }

    local _n_input = _N

    capture frame drop `workframe'
    frame put `id' `startvar' `stopvar' `payload', into(`workframe')
    frame change `workframe'

    quietly rename `startvar' _tvp_start
    quietly rename `stopvar'  _tvp_stop
    local _p = 0
    foreach v of local payload {
        local ++_p
        quietly rename `v' _tvp_p`_p'
    }

    * frlink/frget rather than a merge: the crosswalk stays untouched and the
    * fetch is explicit. Every frget here uses the `new = old' form -- the bare
    * varlist form silently skips any source name beginning with __ and still
    * returns rc=0, so the next line fails on a variable that never existed.
    quietly frlink m:1 `id', frame(`xwalkframe')
    quietly frget _tvp_gid = _tvp_gid, from(`xwalkframe')
    quietly frget _tvp_entry = `entry', from(`xwalkframe')
    quietly frget _tvp_exit = `exit', from(`xwalkframe')
    quietly generate byte _tvp_matched = !missing(_tvp_gid)
    * The link variable is named after the target frame. It is a tempname, but
    * leaving it behind would put a stray column into every normalised source.
    capture drop `xwalkframe'

    * Distinct-person counts by tag rather than by levelsof: levelsof builds a
    * macro with one token per value, which a large cohort overruns.
    tempvar _tag
    quietly egen byte `_tag' = tag(`id')
    quietly count if `_tag'
    local _n_srcpers = r(N)
    quietly count if `_tag' & _tvp_matched == 0
    local _n_unmatched = r(N)
    drop `_tag'

    frame change `_here'
    return scalar N_unmatched_ids = `_n_unmatched'
    return scalar N_persons = `_n_srcpers'
    return scalar N_input = `_n_input'
end
