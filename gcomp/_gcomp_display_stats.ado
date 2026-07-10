*! _gcomp_display_stats Version 1.4.4  2026/07/10
*! Display helper for gcomp result rows
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_display_stats
program define _gcomp_display_stats
version 16.0
local _orig_varabbrev = c(varabbrev)
set varabbrev off
capture noisily {
* Display a single results row: estimate, SE, z, p-value, CI
* Caller writes the row label with _cont, then calls this program
syntax, est(real) se(real) ci_lo(real) ci_hi(real) ///
	[est_col(integer 19) se_col(integer 33) p_col(integer 54) CONTinue]
* Derived column positions from p_col
local z_neg = `p_col' - 7
local z_pos = `p_col' - 6
local ci_col = `p_col' + 9
local ci2_col = `p_col' + 21
* Estimate and SE
noi di as result %9.0g _col(`est_col') `est' _cont
noi di as result _col(`se_col') %9.0g `se' _cont
* z-score and p-value
if `se' > 0 {
	local z = round(`est'/`se', 0.01)
	if `est' < 0 {
		local w = `z_neg' - max(ceil(log10(abs(`z'))), 0)
	}
	else {
		local w = `z_pos' - max(ceil(log10(abs(`z'))), 0)
	}
	noi di as result _col(`w') `z' _cont
	local p = round(2*(1-normal(abs(`est'/`se'))), 0.001)
	if `p' >= . {
		noi di as result _col(`p_col') "    ." _cont
	}
	else if `p' >= 1 {
		noi di as result _col(`p_col') "1.000" _cont
	}
	else if `p' > 0 {
		noi di as result _col(`p_col') "0" _col(`=`p_col'+1') `p' _cont
		if `p' == round(`p', 0.1) {
			noi di _col(`=`p_col'+3') "00" _cont
		}
		else {
			if `p' == round(`p', 0.01) {
				noi di _col(`=`p_col'+4') "0" _cont
			}
		}
	}
	else {
		noi di as result _col(`p_col') "0.000" _cont
	}
}
else {
	noi di as result _col(`z_pos') "." _cont
	noi di as result _col(`p_col') "    ." _cont
}
* CI
if "`continue'" != "" {
	noi di as result _col(`ci_col') %9.0g `ci_lo' _cont
	noi di as result _col(`ci2_col') %9.0g `ci_hi' _cont
}
else {
	noi di as result _col(`ci_col') %9.0g `ci_lo' _cont
	noi di as result _col(`ci2_col') %9.0g `ci_hi'
}
}
local rc = _rc
set varabbrev `_orig_varabbrev'
if `rc' exit `rc'
end
