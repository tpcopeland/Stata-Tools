*! _dataprobe_sccells
*! smallcells() on microdata: cell counts in rows and distinct ids, and the margins audit
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// Called by _dataprobe_smallcells for an entry with id(), by() or margins.
//
//   _dataprobe_sccells group varlist, gen(newvar)
//       newvar (long) gets the stratum number 1..G of every row: the
//       distinct value combinations of varlist in sorted order, a missing
//       value (".", ".a", "") a value of its own, the numbering egen
//       group(varlist), missing gives.  It is built in Mata, so a strL works
//       and the rows are not re-sorted.  r(G).
//
//   _dataprobe_sccells count, group(gvar) hits(varlist) scope(var)
//       mcell(#) [idvar(varname) margins(strata|conditions|both) mask(#)]
//       gvar holds the strata 1..G; each hit is 0/1 (a cell's rows) and
//       scope is 0/1 (the entry's rows).  Cell (g, j) is the rows of
//       stratum g whose hit j is 1, and with idvar() also the distinct
//       idvar values among them (a missing id is one value).  The row
//       counts of all G strata come from one _dataprobe_byhits count pass
//       per hit; a distinct-id count is the row count of a tag, 1 on the
//       first row of each (stratum, id) among the hit rows, built by one
//       sort in Mata, so the data are never re-sorted and no stratum is
//       rescanned.
//
//       The floor: a cell fails when its rows, or its ids, are 1 to m-1
//       (m = mcell).  r(nbad) cells fail, r(nrs) of them in rows and r(nis)
//       in ids; the first 8 are r(f#_g) (stratum), r(f#_j) (hit) and
//       r(f#_u) ("rows", "ids" or "rows, ids"), r(nf) of them.
//
//       The margins audit (margins()): a relation is a set of cells whose
//       total is published.  strata: the cells of one stratum (its hits);
//       conditions: the cells of one hit (its strata); both: both kinds.
//       A relation of one cell is the cell itself, which the floor checks.
//       In a relation, the small cells S (rows or ids 1 to m-1) are the
//       cells a primary suppression would hide, and each count is taken as
//       adding up to the margin (as a table of persons in exclusive
//       categories does).  A relation is exposed, first match:
//         1 single      S is one cell: the margin minus the shown cells
//                       gives it back (Hundepool et al. 2026, sec. 4.1
//                       Ex. 1a, 4.2.2)
//         2 singletons  S is two cells, each a single unit (one id with
//                       idvar(), else one row): each unit can subtract
//                       itself from the margin (sec. 4.3.2, PS2)
//         3 smallsum    S sums to 1 to m-1 in rows or ids: the hidden
//                       group's total, recoverable from the margin, is
//                       itself a small count (datamap's own rule)
//         4 pinned      every cell of S is small in a unit (rows or ids)
//                       and their sum there is |S| or |S| x (m-1): with
//                       each hidden count known to lie in 1 to m-1 (as
//                       <m prints it), every one is fixed (datamap's own
//                       rule: the feasibility interval of sec. 4.2.2
//                       closed)
//         5 narrowed    every cell of S is small in a unit and their sum
//                       Ru there leaves each cell a range narrower than 1
//                       to m-1: [max(1, Ru-(|S|-1)(m-1)), min(m-1,
//                       Ru-(|S|-1))] (datamap's own rule: the feasibility
//                       interval of sec. 4.2.2, with every hidden cell in
//                       1 to m-1, tighter than <m says)
//       r(nx) relations are exposed; the first 8 are r(x#_t) (1 stratum,
//       2 hit), r(x#_i) (its number), r(x#_p) (the pattern) and r(x#_c)
//       (the small cells: hits of a stratum, strata of a hit), r(nxl).
//
//       mask(#) > 0: r(wh) lists the strata whose rows or ids in scope are
//       1 to #-1 (withheld: named by number, not values); only strata
//       named in the lists above are tested.

capture mata: mata drop _dpsc_codes()
capture mata: mata drop _dpsc_group()
capture mata: mata drop _dpsc_tag()
capture mata: mata drop _dpsc_eval()
capture mata: mata drop _dpsc_rel()
mata:
// codes 1..K of one variable's values in sorted order (string, strL or
// numeric); each missing value is one value
real colvector _dpsc_codes(string scalar v)
{
	real colvector c, p, x
	string colvector s
	real scalar n, i, k
	n = st_nobs()
	c = J(n, 1, .)
	if (n == 0) return(c)
	if (st_isstrvar(v)) {
		s = st_sdata(., v)
		p = order(s, 1)
		k = 1
		c[p[1]] = 1
		for (i = 2; i <= n; i++) {
			if (s[p[i]] != s[p[i - 1]]) k++
			c[p[i]] = k
		}
	}
	else {
		x = st_data(., v)
		p = order(x, 1)
		k = 1
		c[p[1]] = 1
		for (i = 2; i <= n; i++) {
			if (x[p[i]] != x[p[i - 1]]) k++
			c[p[i]] = k
		}
	}
	return(c)
}

// strata 1..G of a varlist: the value combinations in sorted order
real colvector _dpsc_group(string scalar vl)
{
	string rowvector vars
	real matrix C
	real colvector g, p
	real scalar n, i, j, k, same
	vars = tokens(vl)
	n = st_nobs()
	g = J(n, 1, .)
	if (n == 0) return(g)
	C = J(n, cols(vars), .)
	for (j = 1; j <= cols(vars); j++) C[., j] = _dpsc_codes(vars[j])
	p = order(C, 1..cols(vars))
	k = 1
	g[p[1]] = 1
	for (i = 2; i <= n; i++) {
		same = 1
		for (j = 1; j <= cols(vars); j++) {
			if (C[p[i], j] != C[p[i - 1], j]) same = 0
		}
		if (!same) k++
		g[p[i]] = k
	}
	return(g)
}

// 1 on the first row (in data order) of each (stratum, id) among the rows
// whose hit is 1, else 0
real colvector _dpsc_tag(real colvector g, real colvector c, real colvector h)
{
	real colvector t, ix, p
	real matrix K
	real scalar i
	t = J(rows(h), 1, 0)
	ix = selectindex(h :== 1)
	// length(): a 1x1 input gives a 1x0 result, whose rows() is 1
	if (length(ix) == 0) return(t)
	ix = vec(ix)
	K = (g[ix], c[ix], ix)
	p = order(K, (1, 2, 3))
	t[ix[p[1]]] = 1
	for (i = 2; i <= rows(p); i++) {
		if (K[p[i], 1] != K[p[i - 1], 1] | K[p[i], 2] != K[p[i - 1], 2]) t[ix[p[i]]] = 1
	}
	return(t)
}

// one relation's cells r (rows) and d (ids; empty without idvar()): its
// pattern (0 when not exposed) and its small cells S
real scalar _dpsc_rel(real colvector r, real colvector d, real scalar m, ///
	real scalar hasid, real colvector S)
{
	real colvector sm, x
	real scalar k, u, Ru, pat
	sm = (r :>= 1 :& r :< m)
	if (hasid) sm = sm :| (d :>= 1 :& d :< m)
	S = vec(selectindex(sm))
	k = length(S)
	if (k == 0) return(0)
	if (k == 1) return(1)
	if (k == 2) {
		if (hasid) {
			if (all(d[S] :== 1)) return(2)
		}
		else if (all(r[S] :== 1)) return(2)
	}
	if (sum(r[S]) < m) return(3)
	if (hasid) {
		if (sum(d[S]) < m) return(3)
	}
	// the feasibility interval of each hidden cell given their sum Ru and
	// that each lies in 1..m-1: a point (pinned), or narrower (narrowed)
	pat = 0
	for (u = 1; u <= 1 + hasid; u++) {
		x = (u == 1 ? r[S] : d[S])
		if (all(x :>= 1 :& x :< m)) {
			Ru = sum(x)
			if (Ru <= k | Ru >= k * (m - 1)) pat = 4
			else if (pat == 0 & (Ru - (k - 1) * (m - 1) > 1 | Ru - (k - 1) < m - 1)) pat = 5
		}
	}
	return(pat)
}

// the floor and the margins audit over the G x J cells, into locals
void _dpsc_eval(string scalar cl, string scalar el, string scalar csv, ///
	string scalar esv, real scalar G, real scalar m, real scalar mask, ///
	real scalar wst, real scalar wcd)
{
	real matrix R, D
	real colvector SR, SD, S, r, d, named
	real scalar nc, hasid, g, j, rs, is, nbad, nrs, nis, nf, nx, nxl, pat, i
	string scalar sfx, wh
	hasid = (el != "")
	R = st_data((1, G), tokens(cl))
	SR = st_data((1, G), csv)
	if (hasid) {
		D = st_data((1, G), tokens(el))
		SD = st_data((1, G), esv)
	}
	nc = cols(R)
	named = J(G, 1, 0)
	nbad = nrs = nis = nf = 0
	for (g = 1; g <= G; g++) {
		for (j = 1; j <= nc; j++) {
			rs = (R[g, j] >= 1 & R[g, j] < m)
			is = 0
			if (hasid) is = (D[g, j] >= 1 & D[g, j] < m)
			if (!rs & !is) continue
			nbad++
			nrs = nrs + rs
			nis = nis + is
			if (nf < 8) {
				nf++
				sfx = "_f" + strofreal(nf)
				st_local(sfx + "_g", strofreal(g, "%12.0f"))
				st_local(sfx + "_j", strofreal(j, "%12.0f"))
				st_local(sfx + "_u", (rs & is ? "rows, ids" : (rs ? "rows" : "ids")))
				named[g] = 1
			}
		}
	}
	nx = nxl = 0
	for (i = 1; i <= 2; i++) {
		if (i == 1 & !(wst & nc >= 2)) continue
		if (i == 2 & !(wcd & G >= 2)) continue
		for (g = 1; g <= (i == 1 ? G : nc); g++) {
			if (i == 1) {
				r = R[g, .]'
				d = (hasid ? D[g, .]' : J(0, 1, .))
			}
			else {
				r = R[., g]
				d = (hasid ? D[., g] : J(0, 1, .))
			}
			S = J(0, 1, .)
			pat = _dpsc_rel(r, d, m, hasid, S)
			if (pat == 0) continue
			nx++
			if (nxl < 8) {
				nxl++
				sfx = "_x" + strofreal(nxl)
				st_local(sfx + "_t", strofreal(i))
				st_local(sfx + "_i", strofreal(g, "%12.0f"))
				st_local(sfx + "_p", strofreal(pat))
				st_local(sfx + "_c", invtokens(strofreal(S', "%12.0f")))
				if (i == 1) named[g] = 1
				else named[S] = J(length(S), 1, 1)
			}
		}
	}
	wh = ""
	if (mask > 0) {
		for (g = 1; g <= G; g++) {
			if (!named[g]) continue
			if ((SR[g] >= 1 & SR[g] < mask) | (hasid ? (SD[g] >= 1 & SD[g] < mask) : 0)) {
				wh = wh + " " + strofreal(g, "%12.0f")
			}
		}
	}
	st_local("_nbad", strofreal(nbad, "%12.0f"))
	st_local("_nrs", strofreal(nrs, "%12.0f"))
	st_local("_nis", strofreal(nis, "%12.0f"))
	st_local("_nf", strofreal(nf))
	st_local("_nx", strofreal(nx, "%12.0f"))
	st_local("_nxl", strofreal(nxl))
	st_local("_wh", strtrim(wh))
}
end

program define _dataprobe_sccells, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _nf = 0
    local _nxl = 0
    capture noisily {
        gettoken sub 0 : 0, parse(" ,")
        if "`sub'" == "group" {
            syntax varlist, GEN(name)
            quietly generate long `gen' = .
            mata: st_store(., "`gen'", _dpsc_group("`varlist'"))
            quietly summarize `gen', meanonly
            local _G = cond(r(N) == 0, 0, r(max))
        }
        else if "`sub'" == "count" {
            syntax , GROUP(varname numeric) HITS(varlist numeric) SCOPE(varname numeric) ///
                MCELL(integer) [IDVAR(varname) MARGINS(string) MASK(integer 0)]
            quietly summarize `group', meanonly
            local _G = r(max)
            if r(N) == 0 local _G = 0
            local _hasid = ("`idvar'" != "")
            if `_hasid' {
                tempvar idc tag
                quietly generate long `idc' = .
                mata: st_store(., "`idc'", _dpsc_codes("`idvar'"))
                quietly generate byte `tag' = 0
            }
            // the cells (one per hit), then the scope (each stratum's rows
            // and ids in the entry's scope), each in one pass
            local nh : word count `hits'
            local cl ""
            local el ""
            local j = 0
            foreach h in `hits' `scope' {
                local ++j
                tempvar c`j'
                quietly generate double `c`j'' = .
                if `_G' > 0 _dataprobe_byhits count `group' `h', into(`c`j'')
                if `_hasid' {
                    tempvar e`j'
                    quietly generate double `e`j'' = .
                    if `_G' > 0 {
                        mata: st_store(., "`tag'", _dpsc_tag(st_data(., "`group'"), ///
                            st_data(., "`idc'"), st_data(., "`h'")))
                        _dataprobe_byhits count `group' `tag', into(`e`j'')
                    }
                }
                if `j' <= `nh' {
                    local cl "`cl' `c`j''"
                    if `_hasid' local el "`el' `e`j''"
                }
            }
            local csv "`c`j''"
            local esv ""
            if `_hasid' local esv "`e`j''"
            local wst = inlist("`margins'", "strata", "both")
            local wcd = inlist("`margins'", "conditions", "both")
            local _nbad = 0
            local _nrs = 0
            local _nis = 0
            local _nx = 0
            local _wh ""
            if `_G' > 0 {
                mata: _dpsc_eval("`cl'", "`el'", "`csv'", "`esv'", `_G', `mcell', ///
                    `mask', `wst', `wcd')
            }
        }
        else {
            display as error "_dataprobe_sccells: unknown subcommand `sub'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar G = `_G'
    if "`sub'" == "count" {
        return scalar nbad = `_nbad'
        return scalar nrs = `_nrs'
        return scalar nis = `_nis'
        return scalar nf = `_nf'
        return scalar nx = `_nx'
        return scalar nxl = `_nxl'
        return local wh "`_wh'"
        forvalues k = 1/`_nf' {
            return local f`k'_g "`_f`k'_g'"
            return local f`k'_j "`_f`k'_j'"
            return local f`k'_u "`_f`k'_u'"
        }
        forvalues k = 1/`_nxl' {
            return local x`k'_t "`_x`k'_t'"
            return local x`k'_i "`_x`k'_i'"
            return local x`k'_p "`_x`k'_p'"
            return local x`k'_c "`_x`k'_c'"
        }
    }
end
