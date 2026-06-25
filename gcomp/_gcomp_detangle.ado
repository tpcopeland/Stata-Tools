*! _gcomp_detangle Version 1.3.2  2026/06/25
*! Parsing helper for gcomp option groups
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_detangle
program define _gcomp_detangle
version 16.0
local _orig_varabbrev = c(varabbrev)
set varabbrev off
capture noisily {
args target tname rhs separator
if "`separator'"=="" {
	local separator ","
}
unab rhs:`rhs'
local nx: word count `rhs'
forvalues j=1/`nx' {
	local n`j': word `j' of `rhs'
}
tokenize "`target'", parse("`separator'")
local ncl 0
while "`1'"!="" {
	if "`1'"=="`separator'" {
		mac shift
	}
	local ncl=`ncl'+1
	local clust`ncl' "`1'"
	mac shift
}
if "`clust`ncl''"=="" {
	local --ncl
}
if `ncl'>`nx' {
	noi di as err "too many `tname'() values specified"
	exit 198
}
forvalues i=1/`ncl' {
	tokenize "`clust`i''", parse(":")
	if "`2'"!=":" {
		if `i'>1 {
			noi di as err "invalid `clust`i'' in `tname'() (syntax error)"
			exit 198
		}
		local 2 ":"
		local 3 `1'
		local 1
		forvalues j=1/`nx' {
			local 1 `1' `n`j''
		}
	}
	local arg3 `3'
	unab arg1:`1'
	tokenize `arg1'
	while "`1'"!="" {
		* Inlined chkin logic
		local _gc_k: list posof "`1'" in rhs
		if `_gc_k' == 0 {
			noi di as err "`1' is not a valid covariate"
			exit 198
		}
		local v`_gc_k' `arg3'
		mac shift
	}
}
forvalues j=1/`nx' {
	if "`v`j''"!="" {
		global S_`j' `v`j''
	}
	else global S_`j'
}
}
local rc = _rc
set varabbrev `_orig_varabbrev'
if `rc' exit `rc'
end
