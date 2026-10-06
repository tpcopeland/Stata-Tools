*! _regtab_flatten Version 2.5.1  2026/10/06
*! regtab block: flatten coleq#colname rows (multilevel and multi-equation)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_flatten" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_flatten, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* Flatten coleq#colname hierarchical layout for multi-level models
* In coleq#colname layout, the exported structure is:
*   Header rows: coleq values (equation labels: "y", "District", "School", "Residual")
*   Data rows:   colname values (indented: "  x", "  var(_cons)", "  var(e)")
* Goal: merge each data row with its parent header into bracket notation:
*   header="District" + data="  var(_cons)" -> "var(_cons[district])"
*   header="y" + data="  x" -> "x"
if `_is_multilevel' {
    quietly count if _n > 2 ///
        & strpos(A, "[") > 0 & strpos(A, "]") > 0 ///
        & (strpos(A, "var(") > 0 | strpos(A, "cov(") > 0 | strpos(A, "sd(") > 0)
    local _qualified_re_layout = (r(N) > 0)

    if `_qualified_re_layout' {
        * Newer collect exports already encode multi-level RE rows with
        * bracketed group paths (for example var(_cons[district>school])).
        * Normalize nested paths to the terminal grouping variable so the
        * downstream relabel/MOR logic can match them reliably.
        replace A = strtrim(A) if _n > 2
        * Header rows are the renderer's coleq rows, the only rows without a
        * raw colname key. An empty model-1 cell is not a header: it is a row
        * that only a later model estimates.
        gen byte _q_is_header = _n > 2 & strtrim(_raw_colname) == ""
        drop if _q_is_header
        drop _q_is_header
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar `"`re_groupvar_`_lev''"'
            local _gpath `"`re_grouppath_`_lev''"'
            if "`_gpath'" != "`_gvar'" {
                replace A = subinstr(A, "[`_gpath']", "[`_gvar']", .) ///
                    if _n > 2 & (strpos(A, "var(") > 0 | strpos(A, "cov(") > 0 | strpos(A, "sd(") > 0)
            }
        }
    }
    else {
        * Identify header rows by their empty raw key (see above); an empty
        * model-1 cell marks a row only a later model estimates.
        gen byte _is_header = strtrim(_raw_colname) == "" & _n > 2

        * Propagate coleq header label down to each data row
        gen str244 _parent_header = A if _is_header
        replace _parent_header = _parent_header[_n-1] if _parent_header == "" & _n > 2

        * Trim once for reuse: strip coleq indent from A and whitespace from header
        gen str244 _A_trim = strtrim(A) if _n > 2
        replace _parent_header = strtrim(_parent_header) if _n > 2

        * Map coleq labels to variable names using POSITIONAL group IDs
        * (avoids label collisions when two grouping vars share the same label)
        * Each header row starts a new group via running sum of _is_header:
        *   group 1 = FE equation ("y"), group 2 = RE level 1, group 3 = RE level 2, ...
        gen int _hdr_grp = sum(_is_header)
        * The FE equation is always group 1; RE levels follow in order
        local _fe_grp = 1
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar `"`re_groupvar_`_lev''"'
            local _target_grp = `_fe_grp' + `_lev'
            replace _parent_header = `"`_gvar'"' if _hdr_grp == `_target_grp'
        }
        * Residual group is after all RE levels — leave as-is (handled below)
        drop _hdr_grp

        * Check if the DATA row (colname) contains an RE pattern
        gen byte _data_is_re = (strpos(_A_trim, "var(") > 0 | ///
            strpos(_A_trim, "cov(") > 0 | strpos(_A_trim, "sd(") > 0) & !_is_header

        * RE data rows (not Residual): splice header groupvar into bracket notation
        * "  var(_cons)" + header "district" -> "var(_cons[district])"
        replace A = subinstr(_A_trim, ")", "[" + _parent_header + "])", 1) ///
            if _data_is_re & _parent_header != "Residual" & _n > 2

        * Residual data row: just trim indent
        replace A = _A_trim if _data_is_re & _parent_header == "Residual" & _n > 2

        * FE data rows: use data row's own colname (strip coleq indent)
        replace A = _A_trim if !_is_header & !_data_is_re & _n > 2

        * Drop the coleq header rows (no data)
        drop if _is_header
        drop _is_header _parent_header _data_is_re _A_trim
    }

    * The coleq#colname renderer builds no factor parent rows, so a factor
    * lost its header row (Sex above Male/Female) as soon as a model had two
    * grouping levels. Insert the parent the colname layout would have
    * rendered: keyed on the raw colname, once per consecutive run of levels.
    quietly generate str244 _fp_par = ""
    forvalues _fpr = 3/`=_N' {
        local _fp_key = strtrim(_raw_colname[`_fpr'])
        _regtab_fvparent `"`_fp_key'"'
        if `"`_fp_parent'"' == "" continue
        quietly replace _fp_par = `"`_fp_parent'"' in `_fpr'
    }
    quietly count if _n > 2 & _fp_par != ""
    if r(N) > 0 {
        quietly generate long _fp_ord = _n
        quietly generate byte _fp_new = _n > 2 & _fp_par != "" & _fp_par != _fp_par[_n - 1]
        quietly expand 2 if _fp_new, generate(_fp_dup)
        quietly ds A _raw_colname _raw_eq _fp_par _fp_ord _fp_new _fp_dup, not
        foreach _fpv in `r(varlist)' {
            capture confirm string variable `_fpv'
            if _rc == 0 quietly replace `_fpv' = "" if _fp_dup
            else quietly replace `_fpv' = . if _fp_dup
        }
        quietly replace A = _fp_par if _fp_dup
        quietly replace _raw_colname = _fp_par if _fp_dup
        gsort _fp_ord -_fp_dup
        drop _fp_ord _fp_new _fp_dup
    }
    drop _fp_par
}
else if `_is_multieq' {
    gen long _orig_row_order = _n
    * Equation header rows carry no raw colname key. Keying on an empty
    * model-1 cell deleted every row model 1 lacks: a covariate only a later
    * model has, and whole equations (zinb's ancillary rows beside zip, a
    * second outcome's equation) absent from model 1.
    gen byte _is_header = strtrim(_raw_colname) == "" & _n > 2
    gen str244 _parent_header = A if _is_header
    replace _parent_header = _parent_header[_n-1] if _parent_header == "" & _n > 2
    replace _parent_header = strtrim(_parent_header) if _n > 2

    gen str244 _A_trim = strtrim(A) if _n > 2
    gen str244 _eq_label = _parent_header if _n > 2
    if `_coleq_label_n' > 0 {
        forvalues _eqi = 1/`_coleq_label_n' {
            replace _eq_label = `"`macval(_coleq_lab_`_eqi')'"' ///
                if _eq_label == `"`_coleq_key_`_eqi''"' ///
                | _eq_label == `"`macval(_coleq_key2_`_eqi')'"'
        }
    }
    if `"`macval(_dep_label)'"' != "" {
        replace _eq_label = `"`macval(_dep_label)'"' if _eq_label == `"`_depvar'"'
    }
    replace _eq_label = "Inflation equation" if strlower(_eq_label) == "inflate"
    replace _eq_label = "Selection equation" ///
        if inlist(strlower(_eq_label), "selection_ll", "selection_ul", "selection")
    replace _eq_label = "Scale" if strlower(_eq_label) == "lnsigma"
    replace _eq_label = "Ancillary" ///
        if strlower(_eq_label) == "/" | regexm(strlower(_eq_label), "^_diparm")
    replace _eq_label = subinstr(_eq_label, "_", " ", .) if _n > 2
    replace _A_trim = "Intercept" if inlist(strlower(_A_trim), "_cons", "constant", "intercept")

    * Omitted rows from base outcomes add noise and can masquerade as
    * reference-category coefficients for every covariate.
    gen byte _drop_omitted_eq = !_is_header & _n > 2 & ///
        (substr(_A_trim, 1, 2) == "o." | strpos(_A_trim, "o.") == 1)
    drop if _drop_omitted_eq
    drop _drop_omitted_eq

    * The rule above removes the o.-marked rows of a base-outcome equation but
    * not its factor levels, which collect reports without the marker. That
    * left half an equation of constrained cells standing beside the estimated
    * ones. An equation in which no coefficient was estimated at all carries no
    * information, so drop it whole - but only while some other equation does
    * have estimates, so a table is never emptied.
    ds
    local _eqvars `r(varlist)'
    local _eqhelpers "A _raw_colname _raw_eq _orig_row_order _is_header _parent_header _A_trim _eq_label `_role_vars'"
    local _eqvars : list _eqvars - _eqhelpers
    local _eq_ci_vars ""
    local _eqpos = 0
    foreach _eqv of local _eqvars {
        local ++_eqpos
        if mod(`_eqpos', 3) == 2 local _eq_ci_vars `"`_eq_ci_vars' `_eqv'"'
    }
    if `"`_eq_ci_vars'"' != "" {
        gen byte _eq_row_data = 0
        foreach _eqv of local _eq_ci_vars {
            quietly replace _eq_row_data = 1 ///
                if !_is_header & _n > 2 & strtrim(`_eqv') != ""
        }
        quietly count if _eq_row_data
        if r(N) > 0 {
            bysort _eq_label (_eq_row_data): gen byte _eq_any_data = _eq_row_data[_N]
            sort _orig_row_order
            quietly count if _n > 2 & !_is_header & _eq_any_data == 0
            if r(N) > 0 {
                drop if _n > 2 & !_is_header & _eq_any_data == 0
            }
            drop _eq_any_data
        }
        drop _eq_row_data
    }

    * Factor covariates: the single-equation layout's parent row ("Sex")
    * above indented level rows ("  Male", "  Female"), once per consecutive
    * run of levels inside each equation block, keyed on the raw colname.
    quietly generate str244 _fp_par = ""
    forvalues _fpr = 3/`=_N' {
        if _is_header[`_fpr'] continue
        local _fp_key = strtrim(_raw_colname[`_fpr'])
        _regtab_fvparent `"`_fp_key'"'
        if `"`_fp_parent'"' == "" continue
        quietly replace _fp_par = `"`_fp_parent'"' in `_fpr'
        forvalues _fvi = 1/`_fvrow_label_n' {
            if `"`_fvrow_pat_`_fvi''"' == `"`_fp_key'"' {
                quietly replace _A_trim = `"`macval(_fvrow_lab_`_fvi')'"' in `_fpr'
            }
        }
    }
    quietly count if _n > 2 & _fp_par != ""
    if r(N) > 0 {
        quietly generate long _fp_ord = _n
        quietly generate byte _fp_new = _n > 2 & _fp_par != "" & _fp_par != _fp_par[_n - 1]
        quietly expand 2 if _fp_new, generate(_fp_dup)
        quietly ds A _raw_colname _raw_eq _fp_par _fp_ord _fp_new _fp_dup ///
            _is_header _parent_header _eq_label _orig_row_order, not
        foreach _fpv in `r(varlist)' {
            capture confirm string variable `_fpv'
            if _rc == 0 quietly replace `_fpv' = "" if _fp_dup
            else quietly replace `_fpv' = . if _fp_dup
        }
        quietly replace _raw_colname = _fp_par if _fp_dup
        quietly replace _A_trim = _fp_par if _fp_dup
        forvalues _fvp = 1/`_fvrow_parent_n' {
            quietly replace _A_trim = `"`macval(_fvrow_parent_lab_`_fvp')'"' ///
                if _fp_dup & _fp_par == `"`_fvrow_parent_var_`_fvp''"'
        }
        gsort _fp_ord -_fp_dup
        drop _fp_ord _fp_new _fp_dup
    }
    drop _fp_par

    replace A = _eq_label + ": " + _A_trim ///
        if !_is_header & _eq_label != "" & strtrim(_A_trim) != "" & _n > 2
    drop if _is_header
    drop _is_header _parent_header _A_trim _eq_label _orig_row_order
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
