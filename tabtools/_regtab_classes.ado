*! _regtab_classes Version 2.5.3  2026/10/06
*! regtab block: constraint classes collect could not record, per model
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_classes" from inside its quietly block and the body is
* quietly again, so only the block's own noisily lines print.
*
* It works on the rendered table: per model m, _omit_type<m> holds collect's
* class of each row (base, omit, empty, or blank), and a row is constrained
* in that model when its cell has an estimate with neither interval nor
* p-value. The block sets the class of such rows where collect could not:
* - The fit's own notes decide whenever they are known: the record tabtools
*   fitcount stored with the model (tt_cns), or the active e(b) when the
*   active fit is the model (_regtab_activeb proves it). They are the notes
*   Stata's own table prints - (base), (empty), (omitted), for main effects
*   and interaction cells alike - and "constrained" for a coefficient a
*   constraint fixes (class cns: its estimate is shown with cnslabel()).
* - Otherwise, in a model whose only recorded class is "empty" or that
*   records none (nbreg, zinb, intreg, streg, stintreg in Stata 17), the
*   model's specification decides a factor main effect's base
*   (_regtab_fvbase): its b. level is the reference and every other
*   constrained level of the factor omitted; a base that only fvset names
*   (it may postdate the fit) decides nothing when the factor has two or more
*   constrained levels: none of them is called the reference, all are not
*   estimable, and a note says so; with one constrained level, that level is
*   the base. An interaction cell is a base cell when one of its factor
*   levels is the base this model holds for that factor's main effect, and
*   is otherwise empty or omitted: not estimable. A cell whose factors have
*   no decided base here cannot be told: not estimable, and a note says so.
* - Only a cell holding the constrained value itself (0, or 1 where collect
*   holds a ratio) can be a base, omitted, or empty coefficient; any other
*   value is an estimate (fixed by a constraint, or estimated with a zero
*   variance) and is never called the reference.
* - Elsewhere collect's "empty" on the b. level stands when another level of
*   the factor is constrained too; when it is the factor's only constrained
*   level the base has observations (the stamp nbreg gives a base beside an
*   omitted continuous term): the reference.
* - At most one reference per factor in a model collect could not classify.
program define _regtab_classes, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* column m is the m-th cmdset in column order (_regtab_cmdsets)
_regtab_cmdsets
local _ab_levels `"`_cs_levels'"'
forvalues _m = 1/`n_models' {
	if `_m' > `_sm_n' continue
	local _unc = inlist(`"`_ocls_`_m''"', "", "empty") & `"`_ocls_0'"' == ""
	local _cm = 3 * `_m' - 2
	local _cc `"_n > 2 & strtrim(c`_cm') != "" & strtrim(c`=`_cm' + 1') == "" & strtrim(c`=`_cm' + 2') == """'
	quietly count if `_cc'
	if r(N) == 0 continue
	* the constrained value on the scale collect holds
	local _cv `"real(subinstr(strtrim(c`_cm'), ",", "", .))"'
	local _ccv `"`_cc' & inlist(`_cv', 0, 1)"'
	if `_m' <= `_meta_models' {
		local _bv = cond(`model_eform_`_m'', 0, `model_null_`_m'')
		local _ccv `"`_cc' & `_cv' == `_bv'"'
	}
	* The fit's own notes: fitcount's record, else the active fit. A classed
	* model asks the active fit only for a cell collect left without class
	* (a coefficient a constraint fixes).
	local _bn `"`_fcn_`_m''"'
	if `"`_bn'"' == "" & `_m' <= `_meta_models' {
		quietly count if `_cc' & _omit_type`_m' == ""
		if `_unc' | r(N) > 0 {
			_regtab_activeb `: word `_m' of `_ab_levels'' `"`model_cmdline_`_m''"'
			if `_ab_ok' local _bn `"`_ab_notes'"'
		}
	}
	if `"`_bn'"' != "" {
		if `"`_bn'"' != "-" {
			foreach _t of local _bn {
				local _eq = strrpos(`"`_t'"', "=")
				local _k = substr(`"`_t'"', 1, `_eq' - 1)
				local _c = substr(`"`_t'"', `_eq' + 1, .)
				local _cls = cond("`_c'" == "b", "base", cond("`_c'" == "o", "omit", ///
					cond("`_c'" == "e", "empty", "cns")))
				if "`_cls'" == "cns" {
					quietly replace _omit_type`_m' = "cns" if `_cc' & strtrim(_raw_A) == `"`_k'"'
				}
				else {
					quietly replace _omit_type`_m' = "`_cls'" if `_ccv' & strtrim(_raw_A) == `"`_k'"'
				}
			}
		}
		* the notes are the fit's whole record: a constrained factor level of
		* an unclassed model they do not mark was estimated (zero variance)
		if `_unc' {
			quietly replace _omit_type`_m' = "empty" if `_cc' & _omit_type`_m' == "" ///
				& regexm(strtrim(_raw_A), "(^|#)[0-9]+\.")
		}
		continue
	}
	foreach _fv of local _fvbv_`_m' {
		local _bk ""
		foreach _k of local _fvb_`_m' {
			if ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") local _bk `"`_k'"'
		}
		local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
		if `"`_bk'"' != "" {
			quietly count if `_ccv' & strtrim(_raw_A) == `"`_bk'"'
			if r(N) == 0 continue
		}
		quietly count if `_ccv' & `_fvrow'
		local _ncon = r(N)
		local _soft : list _fv in _fvbs_`_m'
		if `_unc' {
			if `_soft' & `_ncon' > 1 {
				quietly replace _omit_type`_m' = "empty" if `_ccv' & `_fvrow' & inlist(_omit_type`_m', "", "empty")
				noisily display as text "(regtab: model `_m': the base level of `_fv' cannot be told from its" ///
					" omitted levels, as fvset may have changed since the fit; they are shown as not estimable." ///
					" Fit with ib#.`_fv', run tabtools fitcount after the fit, or tabulate while the fit is active)"
				continue
			}
			quietly replace _omit_type`_m' = "omit" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			if `_soft' & `_ncon' == 1 {
				quietly replace _omit_type`_m' = "base" if `_ccv' & `_fvrow'
				continue
			}
		}
		if `"`_bk'"' == "" continue
		if `_unc' {
			quietly replace _omit_type`_m' = "base" if _n > 2 ///
				& strtrim(_raw_A) == `"`_bk'"' & inlist(_omit_type`_m', "empty", "omit")
		}
		else if `_ncon' == 1 {
			quietly replace _omit_type`_m' = "base" if _n > 2 ///
				& strtrim(_raw_A) == `"`_bk'"' & _omit_type`_m' == "empty"
		}
	}
	* The model's main-effect factors, and the bases its command line names
	* outright (ib#.x): those hold without the data in memory.
	local _ivs ""
	foreach _k of local _sm_fvk_`_m' {
		if ustrregexm(`"`_k'"', "^[0-9]+\.([A-Za-z_][A-Za-z0-9_]*)$") {
			local _iv = ustrregexs(1)
			local _ivs : list _ivs | _iv
		}
	}
	local _ibx ""
	if `_m' <= `_meta_models' {
		local _clp = subinstr(subinstr(subinstr(`"`model_cmdline_`_m''"', "#", " ", .), "(", " ", .), ")", " ", .)
		foreach _p of local _clp {
			if ustrregexm(`"`_p'"', "^ib([0-9]+)\.([A-Za-z_][A-Za-z0-9_]*)$") {
				local _ibx "`_ibx' `=ustrregexs(1)'.`=ustrregexs(2)'"
			}
		}
	}
	* A model collect could classify: a constrained level it left without a
	* class (a coefficient a constraint fixes at the constrained value; Stata
	* prints it "(omitted)") is the reference only when it is the factor's
	* base - the base the specification resolves (_regtab_fvbase), or an
	* ib#. of the command line, or, with neither, the factor's only
	* constrained level. Any other is omitted when the factor's base is
	* known, and not estimable, with a note, when it is not.
	if !`_unc' {
		foreach _fv of local _ivs {
			local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
			quietly count if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			if r(N) == 0 continue
			local _bk ""
			foreach _k of local _fvb_`_m' {
				if ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") local _bk `"`_k'"'
			}
			local _infv : list _fv in _fvbv_`_m'
			if !`_infv' {
				foreach _k of local _ibx {
					if ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") local _bk `"`_k'"'
				}
			}
			* a base the model estimated means the data no longer describe
			* the fit: it decides nothing
			if `"`_bk'"' != "" {
				quietly count if `_cc' & strtrim(_raw_A) == `"`_bk'"'
				if r(N) == 0 local _bk ""
			}
			quietly count if _n > 2 & `_fvrow' & _omit_type`_m' == "base"
			local _nb = r(N)
			if `"`_bk'"' != "" | `_nb' > 0 {
				if `"`_bk'"' != "" {
					quietly replace _omit_type`_m' = "base" if `_ccv' & strtrim(_raw_A) == `"`_bk'"' & _omit_type`_m' == ""
				}
				quietly replace _omit_type`_m' = "omit" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
				continue
			}
			quietly count if `_cc' & `_fvrow'
			if r(N) < 2 continue
			quietly replace _omit_type`_m' = "empty" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			noisily display as text "(regtab: model `_m': which level of `_fv' is the base cannot be told" ///
				" (its specification is not in memory); its constrained levels without a class are shown as" ///
				" not estimable. Fit with ib#.`_fv', run tabtools fitcount after the fit, or tabulate while the fit is active)"
		}
		* collect classes every constrained interaction cell of such a model:
		* one it left without a class is fixed by a constraint, never a base
		quietly replace _omit_type`_m' = "omit" if `_ccv' & _omit_type`_m' == "" ///
			& strpos(_raw_A, "#") & regexm(strtrim(_raw_A), "(^|#)[0-9]+\.")
		continue
	}
	* At most one reference per factor. A constrained main-effect level still
	* without a class goes to the value rule, which calls it the reference.
	* Two or more of them in one factor (the base unverifiable: the data in
	* memory no longer hold the fit's levels), or one beside a decided base,
	* are not estimable instead. An ib#. of the command line decides first.
	foreach _fv of local _ivs {
		local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
		local _infv : list _fv in _fvbv_`_m'
		if !`_infv' {
			foreach _k of local _ibx {
				if !ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") continue
				quietly count if `_ccv' & strtrim(_raw_A) == `"`_k'"' & _omit_type`_m' == ""
				if r(N) == 0 continue
				quietly replace _omit_type`_m' = "base" if `_ccv' & strtrim(_raw_A) == `"`_k'"' & _omit_type`_m' == ""
				quietly replace _omit_type`_m' = "omit" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			}
		}
		quietly count if _n > 2 & `_fvrow' & _omit_type`_m' == "base"
		local _nb = r(N)
		quietly count if `_ccv' & `_fvrow' & _omit_type`_m' == ""
		local _nf = r(N)
		if (`_nb' == 0 & `_nf' < 2) | `_nf' == 0 continue
		quietly replace _omit_type`_m' = "empty" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
		if `_nb' == 0 {
			noisily display as text "(regtab: model `_m': the base level of `_fv' cannot be told from its" ///
				" omitted levels; they are shown as not estimable. Fit with ib#.`_fv', run tabtools" ///
				" fitcount after the fit, or tabulate while the fit is active)"
		}
	}
	* Interaction cells: a base cell has a factor level that is the base this
	* model holds for that factor's main effect (one decided above, or a lone
	* constrained main-effect level, which the value rule calls the base).
	quietly count if `_ccv' & _omit_type`_m' == "" & strpos(_raw_A, "#") ///
		& regexm(strtrim(_raw_A), "(^|#)[0-9]+\.")
	if r(N) == 0 continue
	local _mbase ""
	local _mvars ""
	foreach _fv of local _ivs {
		local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
		quietly levelsof _raw_A if _n > 2 & `_fvrow' & _omit_type`_m' == "base", local(_bl) clean
		if `: word count `_bl'' != 1 {
			quietly levelsof _raw_A if `_ccv' & `_fvrow' & _omit_type`_m' == "", local(_bl) clean
		}
		if `: word count `_bl'' != 1 continue
		local _mbase "`_mbase' `_bl'"
		local _mvars "`_mvars' `_fv'"
	}
	quietly levelsof _raw_A if `_ccv' & _omit_type`_m' == "" & strpos(_raw_A, "#") ///
		& regexm(strtrim(_raw_A), "(^|#)[0-9]+\."), local(_ikeys) clean
	local _iund ""
	foreach _k of local _ikeys {
		local _anyb = 0
		local _und = 0
		foreach _p in `=subinstr(`"`_k'"', "#", " ", .)' {
			if !ustrregexm(`"`_p'"', "^[0-9]+\.([A-Za-z_][A-Za-z0-9_]*)$") continue
			local _pv = ustrregexs(1)
			local _in : list _pv in _mvars
			local _isb : list _p in _mbase
			if !`_in' local _und = 1
			else if `_isb' local _anyb = 1
		}
		local _cls = cond(`_anyb', "base", "empty")
		quietly replace _omit_type`_m' = "`_cls'" if `_ccv' & strtrim(_raw_A) == `"`_k'"' & _omit_type`_m' == ""
		if !`_anyb' & `_und' local _iund "`_iund' `_k'"
	}
	if "`_iund'" != "" {
		noisily display as text "(regtab: model `_m': the base cells of`_iund' cannot be told from" ///
			" empty cells, as the model holds no decided base for one of their factors; they are shown" ///
			" as not estimable. Run tabtools fitcount after the fit, or tabulate while the fit is active)"
	}
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
