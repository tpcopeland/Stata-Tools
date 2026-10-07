*! _regtab_addcol Version 2.5.5  2026/10/07
*! addcol() columns of a transposed table
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_addcol: addcol() columns of a transposed table
* =============================================================================
* Usage: _regtab_addcol <n> <models> `"<spec>"' `"<keys>"'
* addcol("label" val1 val2 ... [, after(term)] [\ ...]): addrow()'s
* specification for a transposed table, one column per specification after
* column c<n>, the label as its header (row 1) and the values given to the
* models (rows 3 on) in order. after(term) places the column after the last
* column of coefficient term (its raw name, as keep() takes it), after any
* column already placed there; <keys> holds each column's raw name ("." for
* a statistic). Returns the new column count in _ac_n in the caller.
* Labels and values are data: copied with macval() and copy local, written
* to the dataset through Mata, never re-expanded ($name, a backquote).
capture program drop _regtab_addcol
program define _regtab_addcol, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken n 0 : 0
	gettoken n_models 0 : 0
	gettoken _ac_rest 0 : 0
	gettoken _ac_keys 0 : 0
	capture noisily {
		_regtab_unwrap `"`macval(_ac_rest)'"'
		local _ac_rest : copy local _uw_spec
		while `"`macval(_ac_rest)'"' != "" {
			mata: st_local("_bs_pos", strofreal(strpos(st_local("_ac_rest"), char(92))))
			if `_bs_pos' > 0 {
				mata: st_local("_ac_chunk", substr(st_local("_ac_rest"), 1, `_bs_pos' - 1))
				mata: st_local("_ac_rest", substr(st_local("_ac_rest"), `_bs_pos' + 1, .))
			}
			else {
				local _ac_chunk : copy local _ac_rest
				local _ac_rest ""
			}
			mata: st_local("_ac_chunk", strtrim(st_local("_ac_chunk")))
			if `"`macval(_ac_chunk)'"' == "" continue
			gettoken _ac_label _ac_vals : _ac_chunk
			mata: st_local("_ac_label", _tt_strip_outer_quotes(st_local("_ac_label")))
			* placement: a trailing ", after(term)", as in addrow()
			local _ac_after ""
			local _ac_pos = 0
			mata: st_local("_ac_hasaf", strofreal(ustrregexm(st_local("_ac_vals"), "^(.*),[ ]*after\(([^()]*)\)[ ]*$")))
			if `_ac_hasaf' {
				mata: st_local("_ac_after", strtrim(ustrregexs(2))); st_local("_ac_vals", ustrregexs(1))
				* keep()'s form: c. and level markers (1b.) do not matter
				local _ac_after = ustrregexra(ustrregexra(`"`_ac_after'"', "(^|#)c\.", "$1"), ///
					"(^|#)([0-9]+)[a-z]+\.", "$1$2.")
				local _ac_j = 0
				foreach _ac_k of local _ac_keys {
					local ++_ac_j
					local _ac_kn = ustrregexra(ustrregexra(`"`_ac_k'"', "(^|#)c\.", "$1"), ///
						"(^|#)([0-9]+)[a-z]+\.", "$1$2.")
					if `"`_ac_kn'"' == `"`_ac_after'"' | `"`_ac_k'"' == `"+`_ac_after'"' local _ac_pos = `_ac_j'
				}
				if `_ac_pos' == 0 {
					display as error `"addcol(): after(`_ac_after') matches no column of the transposed table (give a raw coefficient name, as keep() takes it)"'
					exit 198
				}
			}
			local ++n
			quietly generate str244 c`n' = ""
			quietly replace c`n' = `"`macval(_ac_label)'"' in 1
			if `_ac_pos' > 0 {
				* move the new column right after column c<pos>
				rename c`n' _ac_new
				forvalues _j = `=`n' - 1'(-1)`=`_ac_pos' + 1' {
					rename c`_j' c`=`_j' + 1'
				}
				rename _ac_new c`=`_ac_pos' + 1'
				order c*, sequential after(A)
				local _ac_k2 ""
				local _ac_j = 0
				foreach _ac_k of local _ac_keys {
					local ++_ac_j
					local _ac_k2 `"`_ac_k2' `_ac_k'"'
					if `_ac_j' == `_ac_pos' local _ac_k2 `"`_ac_k2' +`_ac_after'"'
				}
				local _ac_keys `"`_ac_k2'"'
				local _ac_col = `_ac_pos' + 1
			}
			else {
				local _ac_keys `"`_ac_keys' ."'
				local _ac_col = `n'
			}
			local _ac_m = 0
			mata: st_local("_ac_vals", strtrim(st_local("_ac_vals")))
			while `"`macval(_ac_vals)'"' != "" {
				gettoken _ac_v _ac_vals : _ac_vals
				local ++_ac_m
				if `_ac_m' > `n_models' {
					display as error `"addcol(): ""' as result `"`macval(_ac_label)'"' ///
						as error `"" has more values than the `n_models' models"'
					exit 198
				}
				quietly replace c`_ac_col' = `"`macval(_ac_v)'"' in `=2 + `_ac_m''
			}
		}
		c_local _ac_n `n'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
