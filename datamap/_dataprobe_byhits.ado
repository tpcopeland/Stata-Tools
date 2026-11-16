*! _dataprobe_byhits Version 2.0.0  2026/11/10
*! One-pass by() group blocks and per-group row counts for dataprobe
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// dataprobe evaluates its gates once per by() group.  Counting a group's
// rows with "count if group == g" reads every row once per group, so G
// groups cost G passes over the data.  These subcommands do the group
// bookkeeping in one pass.
//
//   blocks gvar, order(var) first(newvar) last(newvar)
//       gvar holds the group numbers 1..G (egen group, every row in a
//       group).  Puts the rows in group order unless they already are:
//       order() gets the current row order (_n) unless it exists already,
//       and the data are sorted by gvar order(), so each group keeps its
//       rows' relative order (a caller can put the rows back with
//       "sort order()"; dataprobe does not need to).  first() and last()
//       get, at observation k, the first and last row of group k, so a
//       command restricted to group k can read "in first[k]/last[k]".
//       r(sorted) is 1 when the rows were sorted (order() exists), r(G) is
//       the number of groups.  sorted: the caller knows the rows are in
//       group order, so they are not scanned for it (a wrong claim is
//       still caught: the groups would not be the blocks 1..G).
//
//   count gvar hitvar, into(var)
//       into() (an existing numeric variable) gets, at observation k, the
//       number of rows of group k whose hitvar is nonzero and nonmissing.
//       Rows with a missing gvar are in no group.  r(G) is the largest
//       group number.
//
//   mark gvar [if], groups(numlist) replace(var)
//       Sets var to 1 on the rows (satisfying if) whose group is one of
//       groups(); other rows are unchanged.  The same rows as one
//       "replace var = 1 if group == g" per listed group, in one pass.
//
//   distinct varname, touse(var) range(a/b)
//       r(n) is the number of distinct values of varname over the rows a..b
//       whose touse is 1 (touse 0/1 on those rows), the count
//       "egen tag()" gives, without sorting every row of the data.

capture mata: mata drop _dataprobe_byhits_sorted()
capture mata: mata drop _dataprobe_byhits_blocks()
capture mata: mata drop _dataprobe_byhits_count()
capture mata: mata drop _dataprobe_byhits_mark()
capture mata: mata drop _dataprobe_byhits_distinct()
mata:
// 1 when gvar is nondecreasing down the rows
real scalar _dataprobe_byhits_sorted(string scalar gv)
{
	real colvector g
	real scalar n
	g = st_data(., gv)
	n = rows(g)
	if (n < 2) return(1)
	return(all(g[|2 \ n|] :>= g[|1 \ n - 1|]))
}

// first and last row of each group, the data sorted by gvar: the groups
// must be exactly 1..G, one block each, or the blocks do not address them
real scalar _dataprobe_byhits_blocks(string scalar gv, string scalar fv, string scalar lv)
{
	real colvector g
	real matrix info
	real scalar G
	g = st_data(., gv)
	if (rows(g) == 0) return(0)
	if (hasmissing(g)) {
		errprintf("_dataprobe_byhits: the group variable has missing values\n")
		exit(459)
	}
	info = panelsetup(g, 1)
	G = rows(info)
	if (G != max(g) | any(g[info[., 1]] :!= (1::G))) {
		errprintf("_dataprobe_byhits: the groups are not the blocks 1..G\n")
		exit(459)
	}
	st_store((1::G), fv, info[., 1])
	st_store((1::G), lv, info[., 2])
	return(G)
}

// rows per group whose hit is nonzero and nonmissing
real scalar _dataprobe_byhits_count(string scalar gv, string scalar hv, string scalar cv)
{
	real colvector g, h, c
	real scalar i, n, G, k
	g = st_data(., gv)
	h = st_data(., hv)
	n = rows(g)
	G = max(g)
	if (n == 0 | G >= .) return(0)
	if (G > n) {
		errprintf("_dataprobe_byhits: group numbers exceed the rows\n")
		exit(459)
	}
	c = J(G, 1, 0)
	for (i = 1; i <= n; i++) {
		k = g[i]
		if (k < . & h[i] != 0 & h[i] < .) c[k] = c[k] + 1
	}
	st_store((1::G), cv, c)
	return(G)
}

// 1 on the rows whose group is listed, else 0
void _dataprobe_byhits_mark(string scalar gv, string scalar gl, string scalar mv)
{
	real colvector g, sel, m, ix
	real rowvector L
	real scalar G
	g = st_data(., gv)
	L = strtoreal(tokens(gl))
	m = J(rows(g), 1, 0)
	G = max((max(g), max(L), 0))
	if (G >= . | G < 1 | cols(L) == 0) {
		st_store(., mv, m)
		return
	}
	L = select(L, L :>= 1 :& L :<= G :& L :== floor(L))
	sel = J(G, 1, 0)
	if (cols(L)) sel[L'] = J(cols(L), 1, 1)
	ix = selectindex(g :< . :& g :>= 1 :& g :== floor(g))
	if (rows(ix)) m[ix] = sel[g[ix]]
	st_store(., mv, m)
}

// distinct values over rows a..b where touse is 1
real scalar _dataprobe_byhits_distinct(string scalar v, string scalar tv, real scalar a, real scalar b)
{
	real colvector t, ix
	if (b < a) return(0)
	t = st_data((a, b), tv)
	ix = selectindex(t :== 1)
	if (rows(ix) == 0) return(0)
	ix = ix :+ (a - 1)
	if (st_isstrvar(v)) return(rows(uniqrows(st_sdata(ix, v))))
	return(rows(uniqrows(st_data(ix, v))))
}
end

program define _dataprobe_byhits, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0
        if "`sub'" == "blocks" {
            syntax varname, ORDer(name) FIRST(name) LAST(name) [SORTED]
            local _claim "`sorted'"
            local sorted = 0
            if "`_claim'" != "" local _inorder = 1
            else mata: st_local("_inorder", strofreal(_dataprobe_byhits_sorted(st_local("varlist"))))
            if !`_inorder' {
                capture confirm variable `order', exact
                if _rc quietly generate long `order' = _n
                sort `varlist' `order'
                local sorted = 1
            }
            quietly generate long `first' = .
            quietly generate long `last' = .
            mata: st_local("_G", strofreal(_dataprobe_byhits_blocks(st_local("varlist"), ///
                st_local("first"), st_local("last")), "%20.0f"))
            return scalar sorted = `sorted'
            return scalar G = `_G'
        }
        else if "`sub'" == "count" {
            syntax varlist(min=2 max=2 numeric), INTO(varname numeric)
            gettoken gv hv : varlist
            local hv = strtrim("`hv'")
            mata: st_local("_G", strofreal(_dataprobe_byhits_count(st_local("gv"), ///
                st_local("hv"), st_local("into")), "%20.0f"))
            return scalar G = `_G'
        }
        else if "`sub'" == "mark" {
            syntax varname(numeric) [if], GROUPS(string) REPLACE(varname numeric)
            marksample touse, novarlist
            tempvar m
            quietly generate byte `m' = 0
            mata: _dataprobe_byhits_mark(st_local("varlist"), st_local("groups"), st_local("m"))
            quietly replace `replace' = 1 if `m' == 1 & `touse'
        }
        else if "`sub'" == "distinct" {
            syntax varname, TOUSE(varname numeric) RANGE(string)
            local _a : word 1 of `=subinstr("`range'", "/", " ", 1)'
            local _b : word 2 of `=subinstr("`range'", "/", " ", 1)'
            confirm integer number `_a'
            confirm integer number `_b'
            mata: st_local("_n", strofreal(_dataprobe_byhits_distinct(st_local("varlist"), ///
                st_local("touse"), `_a', `_b'), "%20.0f"))
            return scalar n = `_n'
        }
        else {
            display as error "_dataprobe_byhits: unknown subcommand `sub'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
