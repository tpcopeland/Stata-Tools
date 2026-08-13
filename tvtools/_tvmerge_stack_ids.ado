*! _tvmerge_stack_ids Version 1.16.0  2026/08/13
*! Stack one ID column across source frames into a destination frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (wrapper)

/*
tvmerge needs the union of person IDs across its source datasets twice: for
flow accounting (persons in) and for the shared integer group key the
interval sweep matches on.

Stata 16 and 17 have no command that appends one frame onto another, so the
released code obtained that union by re-reading every source file from disk and
appending through a tempfile. This kernel does the same concatenation in
memory, which is what lets tvmerge read each input exactly once.

Scope: it concatenates a single column. It does not deduplicate, sort, or
assign group numbers -- the caller does that in Stata, where numeric and string
IDs are handled natively and the crosswalk stays inspectable.

Contract:
  - every source frame must exist and contain idvar;
  - all sources must agree on numeric-versus-string class (tvmerge's merge-key
    compatibility rule already forbids mixing them, and coercing here would
    silently invent a mapping);
  - the destination frame must exist and be completely empty on entry;
  - the destination receives one variable named id, holding every source row in
    source order, source by source;
  - the entry frame is restored on the normal path. Restoring it on an error
    path is the caller's cleanup zone's job, because a Mata abort leaves Stata
    in whatever frame was current when it failed.

Called internally by tvmerge; not for direct use.
*/

version 16.0

capture mata: mata drop _tvp_stack_ids()

mata:
mata set matastrict on

// ----------------------------------------------------------------------------
// _tvp_stack_ids(): concatenate idvar from each source frame into destframe.
// Two passes: count rows, allocate once, then fill by position. Never grows
// the destination one row at a time.
// ----------------------------------------------------------------------------
void _tvp_stack_ids(
    string rowvector srcframes,
    string scalar    idvar,
    string scalar    destframe,
    string scalar    vartype,
    real scalar      isstr)
{
    string scalar    oldframe
    real scalar      i, nsrc, total, pos, n
    real colvector   counts
    real colvector   rv
    string colvector sv

    oldframe = st_framecurrent()
    nsrc     = cols(srcframes)

    if (nsrc < 1) _error("no source frames supplied")

    counts = J(nsrc, 1, 0)
    for (i = 1; i <= nsrc; i++) {
        st_framecurrent(srcframes[i])
        if (_st_varindex(idvar) == .) {
            st_framecurrent(oldframe)
            _error("id variable not found in a source frame")
        }
        counts[i] = st_nobs()
    }
    total = colsum(counts)

    st_framecurrent(destframe)
    if (st_nvar() != 0 | st_nobs() != 0) {
        st_framecurrent(oldframe)
        _error("destination frame is not empty")
    }
    (void) st_addvar(vartype, "id")
    if (total > 0) st_addobs(total)

    pos = 0
    for (i = 1; i <= nsrc; i++) {
        n = counts[i]
        if (n > 0) {
            st_framecurrent(srcframes[i])
            if (isstr) sv = st_sdata(., idvar)
            else       rv = st_data(., idvar)
            st_framecurrent(destframe)
            if (isstr) st_sstore((pos + 1) :: (pos + n), "id", sv)
            else       st_store( (pos + 1) :: (pos + n), "id", rv)
        }
        pos = pos + n
    }

    if (pos != total) {
        st_framecurrent(oldframe)
        _error("stacked row count does not match the source total")
    }

    st_numscalar("_tvm_stack_n", total)
    st_framecurrent(oldframe)
}

end

// Stack idvar from every named source frame into an empty destination frame.
// Usage: _tvmerge_stack_ids <src1> [<src2> ...], idvar(name) into(framename)
// Returns: r(n_rows)
capture program drop _tvmerge_stack_ids
program define _tvmerge_stack_ids, rclass
    version 16.0
    syntax namelist(min=1), IDVar(name) INTO(name)

    * Storage class is read from the sources rather than assumed. Mixing a
    * numeric ID in one source with a string ID in another has no correct
    * answer, so it is refused instead of coerced.
    local _isstr = -1
    local _maxlen = 1
    local _vartype ""
    foreach fr of local namelist {
        capture confirm frame `fr'
        if _rc {
            display as error "source frame not found: `fr'"
            exit 111
        }
        frame `fr' {
            capture confirm variable `idvar'
            if _rc {
                display as error "id variable `idvar' not found in frame `fr'"
                exit 111
            }
            local _t : type `idvar'
        }
        if substr("`_t'", 1, 4) == "strL" {
            display as error ///
                "id variable `idvar' is strL in frame `fr'; strL cannot be a merge key"
            exit 109
        }
        local _thisstr = (substr("`_t'", 1, 3) == "str")
        if `_isstr' == -1 local _isstr = `_thisstr'
        else if `_isstr' != `_thisstr' {
            display as error ///
                "id variable `idvar' is string in one source frame and numeric in another"
            exit 109
        }
        if `_thisstr' {
            local _len = real(substr("`_t'", 4, .))
            if `_len' > `_maxlen' local _maxlen = `_len'
        }
    }

    * A str# destination must be wide enough for the widest source, or Mata
    * truncates silently and two distinct persons become one.
    if `_isstr' local _vartype "str`_maxlen'"
    else        local _vartype "double"

    capture confirm frame `into'
    if _rc {
        display as error "destination frame not found: `into'"
        exit 111
    }

    mata: _tvp_stack_ids(tokens("`namelist'"), "`idvar'", "`into'", ///
        "`_vartype'", `_isstr')

    return scalar n_rows = _tvm_stack_n
    capture scalar drop _tvm_stack_n
end
