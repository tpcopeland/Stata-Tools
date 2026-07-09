*! _datamap_nuniq Version 1.5.2  2026/07/09
*! Distinct-value count for one variable, without sorting the dataset
*! Author: Timothy P Copeland, Karolinska Institutet

// -tabulate- materializes a full frequency table and aborts with r(134) once a
// variable exceeds ~12k levels; -duplicates report- and -egen tag()- both sort
// the whole dataset once per variable.  Counting cardinality that way costs
// more than every statistic datamap actually reports.  uniqrows() on a single
// extracted column returns the same number for a fraction of the cost.
//
// Missing-value contract:
//   numeric  - system (.) and extended (.a-.z) missing are never counted
//   string   - "" is not counted unless -countempty- is specified
// -countempty- reproduces the -duplicates report- semantics that the
// classification pass has always used for string variables.

capture mata: mata drop _datamap_nuniq_num()
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111, 3499) exit `_drop_rc'
capture mata: mata drop _datamap_nuniq_str()
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111, 3499) exit `_drop_rc'

mata:
real scalar _datamap_nuniq_num(string scalar vname)
{
	real colvector x
	x = st_data(., vname)
	x = select(x, x :< .)
	if (rows(x) == 0) return(0)
	return(rows(uniqrows(x)))
}
real scalar _datamap_nuniq_str(string scalar vname, real scalar countempty)
{
	string colvector s
	s = st_sdata(., vname)
	if (!countempty) s = select(s, s :!= "")
	if (rows(s) == 0) return(0)
	return(rows(uniqrows(s)))
}
end

capture program drop _datamap_nuniq
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_nuniq, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax varname [, COUNTEmpty]

		local _empty = ("`countempty'" != "")
		local _vtype : type `varlist'
		if strpos("`_vtype'", "str") == 1 {
			mata: st_local("_n", strofreal( ///
				_datamap_nuniq_str("`varlist'", `_empty'), "%18.0f"))
		}
		else {
			mata: st_local("_n", strofreal( ///
				_datamap_nuniq_num("`varlist'"), "%18.0f"))
		}
		return scalar n = `_n'
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end
