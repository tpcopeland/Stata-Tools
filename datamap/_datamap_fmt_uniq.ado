*! _datamap_fmt_uniq Version 1.6.0  2026/07/14
*! Format a unique-value count for display, honouring a censored count
*! Author: Timothy P Copeland, Karolinska Institutet

// _datamap_classify censors unique counts above its cap() so that
// high-cardinality variables need not be sorted (see _datamap_nuniq.ado).
// When it censors, it reports n = cap+1 and sets unique_capped=1.  Printing
// that bare number would assert a precise cardinality the engine never
// computed -- a 6-million-row ID variable would read as exactly "1001"
// distinct.  A censored count therefore renders as ">cap" instead.
//
//   n=20,   capped=0  ->  "20"
//   n=1001, capped=1  ->  ">1000"
//   n=.               ->  "."

capture program drop _datamap_fmt_uniq
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_fmt_uniq, rclass
	version 16.0
	args n capped
	// A missing `capped' must read as "not censored".  Guard explicitly:
	// -if `capped'- with capped==. is TRUE in Stata (. is nonzero), which
	// would render every exact count as ">n-1".
	if "`capped'" == "" local capped = 0
	if missing(`capped') local capped = 0
	if missing(`n') {
		return local s "."
		exit
	}
	if `capped' {
		return local s = ">" + strtrim(string(`n' - 1, "%18.0f"))
	}
	else {
		return local s = strtrim(string(`n', "%18.0f"))
	}
end
