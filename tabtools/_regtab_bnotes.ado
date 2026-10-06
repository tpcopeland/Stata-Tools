*! _regtab_bnotes Version 2.5.4  2026/10/06
*! the fit's own constraint notes for every coefficient of the active e(b)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_bnotes: base, empty, omitted, and constrained coefficients of e(b)
* =============================================================================
* Usage: _regtab_bnotes
* Reads the active estimation results. Stata keeps, in the column stripe of
* e(b), what each coefficient is: _ms_element_info returns "(base)",
* "(empty)", or "(omitted)", the notes the estimator's own table prints, for
* main effects and interaction cells alike. A coefficient that the stripe does
* not mark, whose variance is zero, and that a row of e(Cns) fixes on its own
* (constraint define, then constraints()) is constrained: Stata prints its
* value with "(constrained)". Returns, in the caller, _bn_notes: one
* key=code token per such coefficient, separated by spaces, code b (base), e
* (empty), o (omitted), or c (constrained); the key is the coefficient name as
* the collection keys it (1b.x -> 1.x, 1b.g#co.z -> 1.g#z). A key that two
* equations mark differently (or one marks and another does not) is left
* out. "-" when nothing is marked, and ""
* when there is no e(b).
* tabtools fitcount stores the string with each model (tt_cns), so regtab can
* read the fit's own notes for a model that is no longer the active fit;
* regtab computes it directly (via _regtab_activeb) when the model is.
capture program drop _regtab_bnotes
program define _regtab_bnotes, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		local _out ""
		capture confirm matrix e(b)
		local _hasb = !_rc
		if `_hasb' {
			tempname _V _C
			capture matrix `_V' = e(V)
			local _hasV = !_rc
			capture matrix `_C' = e(Cns)
			local _hasC = !_rc
			local _names : colnames e(b)
			local _ncb : word count `_names'
			quietly _ms_eq_info, matrix(e(b))
			local _keq = r(k_eq)
			forvalues _e = 1/`_keq' {
				local _ke_`_e' = r(k`_e')
			}
			local _keys ""
			local _bad ""
			local _j = 0
			forvalues _e = 1/`_keq' {
				forvalues _i = 1/`_ke_`_e'' {
					local ++_j
					quietly _ms_element_info, element(`_i') equation(#`_e') matrix(e(b))
					local _note `"`r(note)'"'
					local _code ""
					if `"`_note'"' == "(base)" local _code "b"
					else if `"`_note'"' == "(empty)" local _code "e"
					else if `"`_note'"' == "(omitted)" local _code "o"
					else if `_hasV' & `_hasC' {
						* fixed by a constraint of its own: zero variance and a
						* row of e(Cns) with this coefficient alone
						if `_V'[`_j', `_j'] == 0 {
							forvalues _r = 1/`=rowsof(`_C')' {
								if `_C'[`_r', `_j'] == 0 continue
								local _alone = 1
								forvalues _q = 1/`_ncb' {
									if `_q' != `_j' & `_C'[`_r', `_q'] != 0 local _alone = 0
								}
								if `_alone' local _code "c"
							}
						}
					}
					* every coefficient is recorded, marked or not, so a key one
					* equation marks and another estimates is ambiguous too
					local _nm : word `_j' of `_names'
					local _key = ustrregexra(ustrregexra(`"`_nm'"', ///
						"(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)co?\.", "$1")
					local _pos : list posof `"`_key'"' in _keys
					if `_pos' > 0 {
						if "`_code'" != "`_code_`_pos''" local _bad : list _bad | _key
						continue
					}
					local _keys `"`_keys' `_key'"'
					local _pos : word count `_keys'
					local _code_`_pos' "`_code'"
				}
			}
			local _n : word count `_keys'
			forvalues _p = 1/`_n' {
				local _key : word `_p' of `_keys'
				local _isbad : list _key in _bad
				if !`_isbad' & "`_code_`_p''" != "" local _out `"`_out' `_key'=`_code_`_p''"'
			}
			local _out = strtrim(`"`_out'"')
			if `"`_out'"' == "" local _out "-"
		}
		c_local _bn_notes `"`_out'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
