*! _regtab_fitrec Version 2.5.6  2026/10/07
*! fit-time records of tabtools fitcount, per model column
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_fitrec: string results tabtools fitcount stored with each model
* =============================================================================
* Usage: _regtab_fitrec <result> [<result> ...]   (tt_terms tt_cns tt_levels)
* Each model's records were stored with its own cmdset at fit time; the
* collection itself keeps neither e(sample) nor the b./o. markers of e(b).
* The rows of the rendered (cmdset) layout are every cmdset level in the
* renderer's numeric order, the order of the table's model columns, so row m
* is model m (a cmdset without the result, such as a failed fit, has an empty
* row). Returns in the caller: _fr_present (the results the collection
* holds), _fr_models (the number of cmdset rows), _fr_rc (0, or the error of
* the read), and _fr_<result>_<m> for every result asked for and model m.
* The labels of the result levels are restored exactly as found.
capture program drop _regtab_fitrec
program define _regtab_fitrec, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _want `0'
	c_local _fr_present ""
	c_local _fr_models 0
	c_local _fr_rc 0
	capture noisily {
		_regtab_rlabels `_want'
		local _pres "`_rl_present'"
		local _nm = 0
		local _frc = 0
		if "`_pres'" != "" {
			capture {
				collect layout (cmdset) (result[`_pres'])
			}
			local _frc = _rc
			if !`_frc' {
				preserve
				* stata-dev-ignore: capture-rc — a braced capture stops at its first error; _rc is read on the first line after the closing brace
				capture {
					_tabtools_collect_render, type(meta) rowdim(cmdset) results(`_pres')
					local _nm = _N - 1
					foreach _r of local _pres {
						local _col ""
						foreach _v of varlist _all {
							if strtrim(`_v'[1]) == "`_r'" local _col "`_v'"
						}
						forvalues _m = 1/`_nm' {
							local _val ""
							if "`_col'" != "" mata: st_local("_val", strtrim(st_sdata(`_m' + 1, "`_col'")))
							c_local _fr_`_r'_`_m' `"`_val'"'
						}
					}
				}
				local _frc = _rc
				restore
			}
		}
		forvalues _rli = 1/`_rl_n' {
			local _rlv : word `_rli' of `_rl_present'
			quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
		}
		c_local _fr_present "`_pres'"
		c_local _fr_models `_nm'
		c_local _fr_rc `_frc'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
