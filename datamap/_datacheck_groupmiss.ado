*! _datacheck_groupmiss Version 1.9.1  2026/10/04
*! Group sizes, complete-case counts, and missing counts by group, one pass
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Syntax: _datacheck_groupmiss [varlist], group(varname) complete(varname)
//             frame(name)
//
// datacheck by() printed its GROUPWISE tables from one -count if- per group
// and per (group, variable) pair: G x P full-data passes, repeated in three
// blocks (measured: 7.1 of 13.7 s for 20 groups x 36 variables on 500k rows).
// This sorts the group id once and accumulates every count with panelsum(),
// so the cost is one sort plus one vectorized pass per variable, and no
// indicator variables are added to the data.
//
// Creates frame `frame' with one row per group value 1..max(group): n (rows
// in the group), c (rows with complete == 1), and m1 ... mP (rows missing
// the j-th variable of varlist; none when varlist is empty, as when every
// profiled variable is excluded).  A group value with no rows has zeros.
// Rows whose group is missing are not counted, as -count if group == g-
// never counted them.  Missing means missing() for numerics (. and .a-.z)
// and "" for strings.  The data and their sort order are not changed.
//
// Returns r(G) (rows of the frame) and r(missvars), the variables of varlist
// missing in at least one counted row.

capture mata: mata drop _datacheck_groupmiss_engine()
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111, 3499) exit `_drop_rc'

mata:
void _datacheck_groupmiss_engine(string scalar gname, string scalar ccname,
	string scalar vars, string scalar fr)
{
	string rowvector v, names
	real colvector g, o, R, keep, m
	real rowvector mm
	real matrix info, out
	string scalar cur
	real scalar G, N, P, j, lo, hi, chunk

	v = tokens(vars)
	P = cols(v)
	N = st_nobs()

	// Copies, not views: order() and permutation subscripts on a view were
	// 6x slower (0.60 vs 0.09 s for one 500k-row sort).  One numeric column
	// at a time keeps the transient cost at 8 bytes per row.
	g = st_data(., gname)
	o = order(g, 1)
	g = g[o]
	info = panelsetup(g, 1)
	R = g[info[., 1]]
	keep = (R :< .)
	G = (any(keep) ? max(select(R, keep)) : 0)
	out = J(G, P + 2, 0)

	if (G > 0) {
		info = select(info, keep)
		R = select(R, keep)
		out[R, 1] = info[., 2] - info[., 1] :+ 1
		m = (st_data(., ccname) :== 1)
		out[R, 2] = panelsum(m[o], info)
		chunk = 1000000
		for (j = 1; j <= P; j++) {
			if (st_isstrvar(v[j])) {
				// strings are read in row chunks, so a wide str# or strL
				// column is never copied whole
				m = J(N, 1, 0)
				for (lo = 1; lo <= N; lo = lo + chunk) {
					hi = min((lo + chunk - 1, N))
					m[|lo \ hi|] = (st_sdata((lo, hi), v[j]) :== "")
				}
			}
			else m = (st_data(., v[j]) :>= .)
			out[R, j + 2] = panelsum(m[o], info)
		}
	}

	names = ("n", "c")
	if (P > 0) names = names, ("m" :+ strofreal(1..P))
	cur = st_framecurrent()
	st_framecreate(fr)
	st_local("_frame_made", "1")
	st_framecurrent(fr)
	if (G > 0) st_addobs(G)
	(void) st_addvar("double", names)
	if (G > 0) st_store(., names, out)
	st_framecurrent(cur)

	st_local("G", strofreal(G))
	if (P > 0 & G > 0) {
		// no variable missing: select() of a 1x1 v returns 0x0, which
		// invtokens() rejects (r(3202)), so test the mask first
		mm = (colsum(out[., 3..P + 2]) :> 0)
		st_local("missvars", (any(mm) ? invtokens(select(v, mm)) : ""))
	}
	else st_local("missvars", "")
}
end

capture program drop _datacheck_groupmiss
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datacheck_groupmiss, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	local _orig_frame = c(frame)
	local _frame_made = 0
	set varabbrev off
	capture noisily {
		syntax [varlist(default=none)], GROUP(varname numeric) COMPlete(varname numeric) FRAME(name)
		local G = 0
		local missvars ""
		mata: _datacheck_groupmiss_engine("`group'", "`complete'", ///
			"`varlist'", "`frame'")
		return scalar G = `G'
		return local missvars "`missvars'"
	}
	local rc = _rc
	// a failure after the engine created the frame must not leave it behind,
	// or leave the caller in it
	if `rc' {
		if "`c(frame)'" != "`_orig_frame'" capture frame change `_orig_frame'
		if `_frame_made' capture frame drop `frame'
	}
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end
