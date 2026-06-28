*! _gcomp_diag_capture Version 1.4.0  2026/06/28
*! Diagnostic capture helper for gcomp model fits
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_diag_capture
program define _gcomp_diag_capture
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	syntax, varname(string) command(string) [visit(string) show]
	local _n = e(N)
	local _converged = .
	local _ll = .
	local _r2 = .
	local _rmse = .
	if inlist("`command'", "logit", "mlogit", "ologit") {
		local _converged = e(converged)
		local _ll = e(ll)
		local _r2 = e(r2_p)
	}
	if "`command'" == "regress" {
		local _r2 = e(r2)
		local _rmse = e(rmse)
	}
	local _cleanvar = subinstr("`varname'", "_", "", .)
	if "`_cleanvar'" == "" local _cleanvar "v"
	if "`visit'" != "" {
		local _rowname "`_cleanvar't`visit'"
	}
	else {
		local _rowname "`_cleanvar'"
	}
	tempname _newrow
	matrix `_newrow' = (`_n', `_converged', `_ll', `_r2', `_rmse')
	matrix colnames `_newrow' = N converged ll r2 rmse
	matrix rownames `_newrow' = `_rowname'
	capture confirm matrix _gc_diag_result
	if _rc {
		matrix _gc_diag_result = `_newrow'
	}
	else {
		matrix _gc_diag_result = _gc_diag_result \ `_newrow'
	}
	if "`show'" != "" {
		if "`visit'" != "" {
			local _vlabel " (t=`visit')"
		}
		else {
			local _vlabel ""
		}
		if "`command'" == "regress" {
			noi di as text "   Diagnostics: `varname'`_vlabel'" ///
				_col(40) "N=" as result %7.0f `_n' ///
				as text "  R" _char(178) "=" as result %6.4f `_r2' ///
				as text "  RMSE=" as result %8.4f `_rmse'
		}
		else {
			local _conv_label "yes"
			if `_converged' == 0 {
				local _conv_label "{err}NO{text}"
			}
			noi di as text "   Diagnostics: `varname'`_vlabel'" ///
				_col(40) "N=" as result %7.0f `_n' ///
				as text "  pseudo-R" _char(178) "=" as result %6.4f `_r2' ///
				as text "  converged=`_conv_label'"
		}
		if `_converged' == 0 {
			noi di as err "   >>> WARNING: `command' model for `varname'`_vlabel' did not converge."
			noi di as err "       Estimates may be unreliable. Check equation specification."
		}
		if `_n' < 20 {
			noi di as err "   >>> WARNING: `command' model for `varname'`_vlabel' fit on only `_n' observations."
		}
		if "`command'" == "regress" & `_r2' < 0.01 {
			noi di as text "   >>> Note: very low R" _char(178) " for `varname'`_vlabel'. Model explains <1% of variance."
		}
		if inlist("`command'", "logit", "mlogit", "ologit") & `_r2' != . & `_r2' < 0.001 {
			noi di as text "   >>> Note: very low pseudo-R" _char(178) " for `varname'`_vlabel'. Model may have poor discrimination."
		}
	}
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end
