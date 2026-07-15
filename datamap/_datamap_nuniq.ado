*! _datamap_nuniq Version 1.6.1  2026/07/15
*! Distinct-value count for one variable, without sorting the dataset
*! Author: Timothy P Copeland, Karolinska Institutet

// -tabulate- materializes a full frequency table and aborts with r(134) once a
// variable exceeds ~12k levels; -duplicates report- and -egen tag()- both sort
// the whole dataset once per variable.  Counting cardinality that way costs
// more than every statistic datamap actually reports.
//
// Reading the whole column at once (st_data + select + uniqrows) allocated
// THREE full-length copies per variable -- st_data promotes to double (8
// bytes/obs whatever the storage type), select copies again, and uniqrows
// sorts into a third.  Peak memory ran ~3.5x the dataset, which on a
// multi-GB file pushed Stata into swap and made it appear to hang.
//
// Instead: walk the column in chunks that start small and grow, keeping only
// the running set of distinct values.  A variable whose cardinality exceeds
// `cap' bails on the first small chunk -- continuous and ID variables, the
// ones that were most expensive, are now the cheapest (measured: a 20M-row
// double column went 27.0s / 866MB peak RSS -> 0.16s / 398MB).  Below the cap
// the count is exact and peak memory is bounded by the chunk; above it the
// caller is told the count is censored (r(capped)=1) and r(n) is a lower
// bound (cap+1), so a report can honestly print ">cap".
//
// Memory is bounded ONLY because the walk stops at the cap.  With cap(0) the
// caller is asking for an exact count at any cardinality, the distinct set
// grows to the full cardinality regardless, and chunking just adds re-merges
// (measured 40% SLOWER than one sort).  cap(0) therefore takes a direct path,
// reading the column through a view (st_view/st_sview) so uniqrows sorts
// straight from the data and the initial full-length copy is never allocated.
//
// The cap MUST be >= any threshold the caller compares the count against
// (maxcat, maxfreq).  Otherwise a censored count could silently flip a
// variable's classification.  _datamap_classify enforces this.
//
// Missing-value contract (unchanged):
//   numeric  - system (.) and extended (.a-.z) missing are never counted
//   string   - "" is not counted unless -countempty- is specified

capture mata: mata drop _datamap_nuniq_num()
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111, 3499) exit `_drop_rc'
capture mata: mata drop _datamap_nuniq_str()
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111, 3499) exit `_drop_rc'

mata:
// Returns (count, capped).  When capped, count is a lower bound of cap+1.
//
// Missing values ride along in the running distinct set `d' rather than being
// filtered per chunk (that filter was a second full copy).  At most 27 of d's
// rows can therefore be missing (. and .a-.z), so `slack' rows of headroom
// keep the early exit from firing on missings alone.  The post-loop cap check
// is not redundant: a variable landing between cap+1 and cap+slack distinct
// never trips the in-loop test, and would otherwise report an exact-looking
// count that is actually over the cap.
real rowvector _datamap_nuniq_num(string scalar vname, real scalar cap)
{
	real scalar N, lo, hi, chunk, maxchunk, slack, n
	real colvector d, V

	N = st_nobs()
	if (N == 0) return((0, 0))

	// cap<=0 means the caller needs an EXACT count at any cardinality (panel
	// unit counts on high-cardinality IDs -- the very columns where a copy
	// hurts most).  Chunking cannot help there: the running distinct set
	// grows to the full cardinality anyway, and re-merging it once per chunk
	// is ~40% slower than one sort.  Take the direct path instead -- read the
	// column through a VIEW so uniqrows sorts straight from it and the initial
	// full-length st_data copy is never allocated, and filter missings AFTER
	// uniqrows so select() copies only the (small) distinct set.  uniqrows on
	// a view returns a fresh sorted matrix and leaves the data untouched.
	if (cap <= 0) {
		st_view(V, ., vname)
		d = uniqrows(V)
		d = select(d, d :< .)
		return((rows(d), 0))
	}

	chunk    = 50000
	maxchunk = 4000000
	slack    = 27
	d = J(0, 1, .)

	for (lo = 1; lo <= N; lo = lo + chunk) {
		hi = min((lo + chunk - 1, N))
		d = uniqrows(d \ st_data((lo, hi), vname))
		if (rows(d) > cap + slack) return((cap + 1, 1))
		chunk = min((chunk * 4, maxchunk))
	}

	d = select(d, d :< .)
	n = rows(d)
	if (n > cap) return((cap + 1, 1))
	return((n, 0))
}

real rowvector _datamap_nuniq_str(string scalar vname, real scalar countempty,
	real scalar cap)
{
	real scalar N, lo, hi, chunk, maxchunk, slack, n
	string colvector d, V

	N = st_nobs()
	if (N == 0) return((0, 0))

	// See _datamap_nuniq_num: cap<=0 wants an exact count, which chunking
	// cannot make cheaper once the distinct set is large.  Read through a
	// string view so the initial full-length st_sdata copy is never made.
	if (cap <= 0) {
		st_sview(V, ., vname)
		d = uniqrows(V)
		if (!countempty) d = select(d, d :!= "")
		return((rows(d), 0))
	}

	chunk    = 50000
	maxchunk = 4000000
	slack    = (countempty ? 0 : 1)
	d = J(0, 1, "")

	for (lo = 1; lo <= N; lo = lo + chunk) {
		hi = min((lo + chunk - 1, N))
		d = uniqrows(d \ st_sdata((lo, hi), vname))
		if (rows(d) > cap + slack) return((cap + 1, 1))
		chunk = min((chunk * 4, maxchunk))
	}

	if (!countempty) d = select(d, d :!= "")
	n = rows(d)
	if (n > cap) return((cap + 1, 1))
	return((n, 0))
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
		syntax varname [, COUNTEmpty CAP(integer 1000)]

		if `cap' < 0 {
			noisily display as error "cap() must be non-negative"
			exit 198
		}

		local _empty = ("`countempty'" != "")
		local _vtype : type `varlist'
		tempname R
		if strpos("`_vtype'", "str") == 1 {
			mata: st_matrix("`R'", ///
				_datamap_nuniq_str("`varlist'", `_empty', `cap'))
		}
		else {
			mata: st_matrix("`R'", _datamap_nuniq_num("`varlist'", `cap'))
		}
		return scalar n      = `R'[1, 1]
		return scalar capped = `R'[1, 2]
		return scalar cap    = `cap'
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end
