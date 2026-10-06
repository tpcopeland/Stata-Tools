*! _regtab_addrow Version 2.5.4  2026/10/06
*! regtab block: addrow() rows, appended or placed inside a factor block
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_addrow" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_addrow, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* =========================================================================
* ADD CUSTOM ROWS (addrow option)
* =========================================================================
* addrow("label" val1 val2 ... [, after(term)] [\ ...]): one row per
* specification, its values in the models' estimate columns in order. A
* row without after() is appended below the table body (and any stats()
* rows). after(term) places it inside the body instead, right after the
* coefficient row whose raw name is term (exact and case-sensitive, as
* keep() matches: after(1.drug), after(age)), or, when term is a factor
* variable, after the last level of that factor's block (after(drug)).
* Several rows after one anchor keep their order. An inserted row takes the
* indentation of the row it follows. A term that matches no row, several
* rows, or several blocks of one factor is an error (r(198)).
local addrow_rows = ""
local _ar_in_rows = ""
if `"`macval(addrow)'"' != "" {
    * Split on backslash to get individual rows
    local _ar_rest : copy local addrow
    * A specification wrapped whole in one more layer of quotes (addrow(`"`spec'"')
    * from a program) is unwrapped: it used to become one row labelled with
    * the whole specification.
    _regtab_unwrap `"`macval(_ar_rest)'"'
    local _ar_rest : copy local _uw_spec
    * The coefficient rows an after() can name, and each row's factor block.
    local _ar_end = _N
    if `stats_start_row' > 0 local _ar_end = `stats_start_row' - 1
    quietly generate double _ar_ord = _n
    quietly generate str244 _ar_par = ""
    * raw names in keep()'s form: c. and the b/o/n markers of a level dropped,
    * so after(1.foreign#c.mpg) and after(1b.rep78) name the row keep() would
    quietly generate str244 _ar_nk = ustrregexra(ustrregexra(strtrim(_raw_A), ///
        "(^|#)c\.", "$1"), "(^|#)([0-9]+)[a-z]+\.", "$1$2.")
    forvalues _rr = 3/`_ar_end' {
        local _rt_key = strtrim(_raw_A[`_rr'])
        if `"`_rt_key'"' == "" continue
        _regtab_fvparent `"`_rt_key'"'
        if `"`_fp_parent'"' != "" quietly replace _ar_par = `"`_fp_parent'"' in `_rr'
    }
    local _ar_ins = 0
    local _ar_spec = 0
    while `"`macval(_ar_rest)'"' != "" {
        * Split on backslash using string position (gettoken + parse
        * breaks quoted strings — it returns "P trend" as a separate
        * token from "0.032 0.041" instead of keeping them together)
        local _bs_pos = strpos(`"`macval(_ar_rest)'"', "\")
        if `_bs_pos' > 0 {
            local _ar_chunk = substr(`"`macval(_ar_rest)'"', 1, `_bs_pos' - 1)
            local _ar_rest = substr(`"`macval(_ar_rest)'"', `_bs_pos' + 1, .)
        }
        else {
            local _ar_chunk : copy local _ar_rest
            local _ar_rest ""
        }
        local _ar_chunk = strtrim(`"`macval(_ar_chunk)'"')
        if `"`macval(_ar_chunk)'"' == "" continue

        * Parse the chunk: first token is the label (quoted OK), rest are values
        gettoken _ar_label _ar_vals : _ar_chunk
        * Remove one balanced outer quote layer; embedded quotation marks are data.
        mata: st_local("_ar_label", _tt_strip_outer_quotes(st_local("_ar_label")))
        * placement: a trailing ", after(term)" after the values
        local _ar_after ""
        local _ar_hasafter = ustrregexm(`"`macval(_ar_vals)'"', "^(.*),[ ]*after\(([^()]*)\)[ ]*$")
        if `_ar_hasafter' {
            local _ar_after = strtrim(ustrregexs(2))
            local _ar_vals = ustrregexs(1)
            local _ar_nkey = ustrregexra(ustrregexra(`"`_ar_after'"', ///
                "(^|#)c\.", "$1"), "(^|#)([0-9]+)[a-z]+\.", "$1$2.")
            if `"`_ar_after'"' == "" {
                noisily display as error "addrow(): after() requires a coefficient or factor name"
                exit 198
            }
        }
        local _ar_anchor = .
        local _ar_indent ""
        if `_ar_hasafter' {
            * a factor variable: the end of its block of levels
            quietly count if _n >= 3 & _n <= `_ar_end' & _ar_par == `"`_ar_after'"'
            if r(N) > 0 {
                quietly count if _n >= 3 & _n <= `_ar_end' & _ar_par == `"`_ar_after'"' ///
                    & _ar_par[_n - 1] != `"`_ar_after'"'
                if r(N) > 1 {
                    noisily display as error `"addrow(): after(`_ar_after') matches `r(N)' blocks of levels; name the level to follow, such as after(1.`_ar_after')"'
                    exit 198
                }
                quietly summarize _ar_ord if _n >= 3 & _n <= `_ar_end' & _ar_par == `"`_ar_after'"', meanonly
                local _ar_anchor = r(max)
            }
            else {
                quietly count if _n >= 3 & _n <= `_ar_end' & _ar_nk == `"`_ar_nkey'"'
                if r(N) != 1 {
                    noisily display as error `"addrow(): after(`_ar_after') matches `r(N)' coefficient rows; it must match exactly one (raw names such as 1.drug or age, or a factor variable)"'
                    if r(N) > 1 noisily display as error "  a multi-equation table lists a term once per equation, so after() cannot place a row there"
                    exit 198
                }
                quietly summarize _ar_ord if _n >= 3 & _n <= `_ar_end' & _ar_nk == `"`_ar_nkey'"', meanonly
                local _ar_anchor = r(min)
            }
            mata: st_local("_ar_indent", ustrregexra(st_sdata(`_ar_anchor', "A"), "^( *).*$", "$1"))
        }

        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`_ar_indent'`macval(_ar_label)'"' in `=`curr_n'+1'
        * frame(, flat keys): the row's key is its position in addrow()
        local ++_ar_spec
        capture confirm variable _kty
        if !_rc {
            quietly replace _kty = "addrow" in `=`curr_n'+1'
            quietly replace _ktm = "addrow:`_ar_spec'" in `=`curr_n'+1'
        }

        * Positionally assign values to model estimate columns
        local _ar_m = 0
        local _ar_vals = strtrim(`"`macval(_ar_vals)'"')
        while `"`macval(_ar_vals)'"' != "" {
            gettoken _ar_v _ar_vals : _ar_vals
            local _ar_m = `_ar_m' + 1
            local col = (`_ar_m' - 1) * 3 + 1
            if `col' <= `n' {
                replace c`col' = `"`macval(_ar_v)'"' in `=`curr_n'+1'
            }
        }
        if `_ar_hasafter' {
            * right after the anchor and after the rows already placed there
            if "`_ar_k_`_ar_anchor''" == "" local _ar_k_`_ar_anchor' = 0
            local _ar_k_`_ar_anchor' = `_ar_k_`_ar_anchor'' + 1
            quietly replace _ar_ord = `_ar_anchor' + `_ar_k_`_ar_anchor'' / 1000 in `=`curr_n'+1'
            local _ar_in_rows "`_ar_in_rows' `=`curr_n'+1'"
            local ++_ar_ins
        }
        else {
            quietly replace _ar_ord = `curr_n' + 1 in `=`curr_n'+1'
            local addrow_rows = "`addrow_rows' `=`curr_n'+1'"
        }
    }
    if `_ar_ins' > 0 {
        * Move the inserted rows into place and carry every row position
        * already taken (header and constraint rows, stats() rows, appended
        * addrow() rows, the eplotframe() source rows) to the new order.
        quietly generate long _ar_old = _n
        sort _ar_ord, stable
        quietly generate long _ar_new = _n
        foreach _arl in first_re_row stats_rows addrow_rows _ar_in_rows stats_start_row {
            local _ar_map ""
            foreach _r of local `_arl' {
                if `_r' <= 0 {
                    local _ar_map "`_ar_map' `_r'"
                    continue
                }
                quietly summarize _ar_new if _ar_old == `_r', meanonly
                * stata-dev-ignore: double-macro-transport — row numbers are integers; their decimal expansion is exact
                local _ar_map "`_ar_map' `=cond(r(N), r(min), `_r')'"
            }
            local `_arl' = strtrim("`_ar_map'")
        }
        forvalues _m = 1/`n_models' {
            local _ar_map ""
            foreach _r of local _constraint_rows_`_m' {
                quietly summarize _ar_new if _ar_old == `_r' - 1, meanonly
                * stata-dev-ignore: double-macro-transport — row numbers are integers; their decimal expansion is exact
                local _ar_map "`_ar_map' `=r(min) + 1'"
            }
            local _constraint_rows_`_m' = strtrim("`_ar_map'")
        }
        if `"`_eplotframe_name'"' != "" {
            mata: _regtab_arM = st_data(., ("_ar_old", "_ar_new"))
            frame `_eplotframe_name' {
                mata: _regtab_arS = st_data(., "source_row")
                mata: for (_regtab_arI = 1; _regtab_arI <= rows(_regtab_arS); _regtab_arI++) _regtab_arS[_regtab_arI] = select(_regtab_arM[., 2], _regtab_arM[., 1] :== _regtab_arS[_regtab_arI] + 2) - 2
                mata: st_store(., "source_row", _regtab_arS)
            }
            capture mata: mata drop _regtab_arM _regtab_arS _regtab_arI
        }
        drop _ar_old _ar_new
    }
    drop _ar_ord _ar_par _ar_nk
    local addrow_rows = strtrim("`addrow_rows'")
    local _ar_in_rows = strtrim("`_ar_in_rows'")
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
