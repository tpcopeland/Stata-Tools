*! _datamap_collect_levels Version 2.0.0  2026/11/10
*! The levels frame of the datamap collector: one row per dataset x variable x value
*! Author: Timothy P Copeland, Karolinska Institutet

// Three modes:
//
//   create  _datamap_collect_levels, create frame(f)
//   post    _datamap_collect_levels varlist, frame(f) dsindex(#)
//               [maxlevels(#) mincell(#)]
//           the levels of each variable of the data in the current frame.
//   profile _datamap_collect_levels, profile frame(f) dsindex(#)
//               varframe(v) vfirst(#) vlast(#) lfirst(#) [mincell(#) datesafe]
//           after post (2026-11-10, F3/F4), with the dataset in the current
//           frame: for rows vfirst..vlast of the variables frame v
//           (_datamap_post_metadata_rows) and the dataset's levels rows from
//           lfirst on (0: none yet), (1) the row margins missing_state and
//           n_state (_datamap_prof_missing: the Missing count and the
//           nonmissing count are the two parts of N, so each is the other's
//           complement; a listed categorical's Missing total also rides on
//           its level mask, see is_missing_code); (2) the per-code missing
//           counts of every numeric, non-excluded variable with missing
//           values: the missing-code rows here (posted now for a variable
//           whose levels are not listed), masked as a table whose total is
//           the Missing count, and missing_codes, the breakdown text saving()
//           writes; (3) the string profile of each string-class variable
//           (_datamap_prof_string): numeric_n, padded_n, date_mask, is_strl
//           and the five most frequent non-numeric values as rows here
//           (is_missing_code 0), masked with the numeric count and the rest,
//           when some but not all nonblank values are numeric text, or when
//           the variable has at most maxcat() distinct values (never for
//           high-cardinality text such as identifiers or free text).  A
//           value held by fewer than mincell() observations is never listed.
//           Under safe (2.0.0, U2) only text with at most maxcat() distinct
//           values lists any value.
//           Under datesafe every listed value of the variable is withheld
//           (tokens_hidden) when the text reads as dates (date_mask) or any
//           listed value holds a digit (2026-11-10: date() masks alone let
//           "2020-01-10 10:30", "2020-01", "1/10/20" and "born 10 jan 1980"
//           through; text without a digit cannot carry a day or a year).
//
// Columns of frame f, one row per dataset x variable x value:
//   ds_index         the dataset's row in the datasets frame
//   variable         variable name
//   level            order within the variable: the nonmissing values
//                    ascending (bytewise for strings), then the missing
//                    values present (. .a-.z; "" for a string variable)
//   value            the value (numeric variables; . for strings)
//   value_str        the value (string variables; "" for numeric)
//   label            the value label's text for the value, "" when it has none
//   count            observations holding the value
//   share            100 * count / N, where N counts EVERY observation,
//                    missing ones included.  This is the percent-denominator
//                    rule of datamap 2.0.0, and this is the one place it is
//                    computed: a writer prints a share from here, never its
//                    own quotient.  With the missing values as rows of their
//                    own, the shares of a variable sum to 100.  (2026-11-10:
//                    the Markdown writer prints the same quotient from count
//                    and the same N, rounded half up in integer arithmetic,
//                    because round(share, 0.1) split decimal ties;
//                    _datamap_md_varrows' _dmv_pctc.)
//   suppressed       1 when the count may not be printed: below mincell(), or
//                    withheld as a complement (the small-cell rule of
//                    datamap and dataprobe's maskrare, applied over
//                    the nonmissing values)
//   complementary    1 when withheld as a complement
//   is_missing_code  1 for a missing-value row.  Post leaves on these rows
//                    the mask state of the variable's Missing TOTAL, the
//                    same on every one of them: levels + Missing = N, so the
//                    total is one more cell of the level mask (a lone
//                    suppressed level, 3 observed in 1,000, was recoverable
//                    as N minus the printed Missing count).  Profile reads
//                    that state into the variables frame (missing_state)
//                    and then writes each row's own state, the per-code mask
//                    (F3, 2026-11-10): the codes are a table whose total is
//                    the Missing count; every code is withheld when that
//                    total is, a lone code equals the total, and otherwise
//                    the level rule applies (_datamap_lvmask).
//   (profile)        a string-class variable's rows are its most frequent
//                    non-numeric values, is_missing_code 0 (F4)
//
// A variable with more than maxlevels() distinct nonmissing values, or a
// dataset with no observations, gets no rows; a variable with no nonmissing
// value gets its missing-value rows only.
//
// Reading the rows back: Mata in an autoloaded .ado is private to that file,
// so the reader lives with its consumer (_datamap_md_varrows.ado reads the
// rows of one dataset).
capture mata: mata drop _datamap_lvmask()
capture mata: mata drop _datamap_lvgrow()
capture mata: mata drop _datamap_lvruns()
capture mata: mata drop _datamap_lvrunlen()
capture mata: mata drop _datamap_levels_post()
capture mata: mata drop _datamap_prof_item()
capture mata: mata drop _datamap_prof_missing()
capture mata: mata drop _datamap_prof_strvars()
capture mata: mata drop _datamap_prof_string()
mata:
// The small-cell mask (0 shown, 1 below m, 2 complement); the same rule as
// _datamap_md_sections' _dms_maskcore and dataprobe's maskrare: a lone
// suppressed cell is recoverable from N and the missing count, so the
// smallest shown cell joins the withheld set until it has at least two
// members and a pooled count of at least m.
real colvector _datamap_lvmask(real colvector c, real scalar m)
{
	if (m <= 0 | rows(c) == 0) return(J(rows(c), 1, 0))
	return(_datamap_lvgrow(c, (c :< m) :& (c :> 0), m))
}

// The complement loop of _datamap_lvmask from a given state h0 (0 shown,
// 1 below m, 2 complement): adds the smallest shown cell until the withheld
// set has two members and a pooled count of at least m, or nothing is left.
real colvector _datamap_lvgrow(real colvector c, real colvector h0, real scalar m)
{
	real colvector h
	real scalar k, best, j

	k = rows(c)
	h = h0
	while (sum(h :!= 0) > 0) {
		if (sum(h :!= 0) >= 2 & sum(select(c, h :!= 0)) >= m) break
		best = 0
		for (j = 1; j <= k; j++) {
			if (h[j] != 0) continue
			if (best == 0) best = j
			else if (c[j] < c[best]) best = j
		}
		if (best == 0) break
		h[best] = 2
	}
	return(h)
}

// Start of each run of equal values in sorted column s (rows(s) >= 1)
real colvector _datamap_lvruns(transmorphic colvector s)
{
	real scalar n
	n = rows(s)
	if (n == 1) return(1)
	return(selectindex(1 \ (s[|2 \ n|] :!= s[|1 \ n - 1|])))
}

// Length of each run, from the run starts idx of a column of n rows
real colvector _datamap_lvrunlen(real colvector idx, real scalar n)
{
	if (rows(idx) == 1) return(n)
	return((idx[|2 \ rows(idx)|] \ n + 1) - idx)
}

// Runs with the levels frame current; reads variable v of frame src.  mats:
// "" to count in Mata (string variables, and numeric ones -tabulate- would
// not take), or the names of four Stata matrices from -tabulate, matrow()
// matcell()-: the nonmissing values and their counts, then the missing
// values and theirs ("." "." when there are none).
void _datamap_levels_post(string scalar src, string scalar v,
	real scalar dsx, real scalar maxlev, real scalar m, string scalar mats)
{
	string scalar tgt, lab
	string rowvector mt
	real scalar N, isstr, n, k, km, nmr, nr, r0, hm, tm
	real colvector x, mx, idx, cnt, mcnt, h, u, mu
	string colvector sx, su, labs, mlabs
	real matrix D
	string matrix S

	tgt = st_framecurrent()
	st_framecurrent(src)
	N = st_nobs()
	isstr = st_isstrvar(v)
	k = 0
	km = 0
	mt = tokens(mats)
	if (!isstr & cols(mt) == 4) {
		u = st_matrix(mt[1])[., 1]
		cnt = st_matrix(mt[2])[., 1]
		k = rows(u)
		nmr = 0
		if (mt[3] != ".") {
			mu = st_matrix(mt[3])[., 1]
			mcnt = st_matrix(mt[4])[., 1]
			nmr = rows(mu)
		}
		lab = st_varvaluelabel(v)
		if (lab != "") {
			if (!st_vlexists(lab)) lab = ""
		}
		if (k > 0) {
			if (lab != "") labs = st_vlmap(lab, u)
			else labs = J(k, 1, "")
		}
		if (nmr > 0) {
			if (lab != "") mlabs = st_vlmap(lab, mu)
			else mlabs = J(nmr, 1, "")
		}
	}
	else if (isstr) {
		sx = st_sdata(., v)
		km = sum(sx :== "")
		sx = select(sx, sx :!= "")
		n = rows(sx)
		if (n > 0) {
			sx = sort(sx, 1)
			idx = _datamap_lvruns(sx)
			su = sx[idx]
			cnt = _datamap_lvrunlen(idx, n)
			k = rows(su)
		}
		// a string variable's one missing value, "", as one row
		nmr = (km > 0)
		if (nmr) mcnt = km
	}
	else {
		x = st_data(., v)
		mx = select(x, x :>= .)
		x = select(x, x :< .)
		n = rows(x)
		if (n > 0) {
			x = sort(x, 1)
			idx = _datamap_lvruns(x)
			u = x[idx]
			cnt = _datamap_lvrunlen(idx, n)
			k = rows(u)
		}
		km = rows(mx)
		nmr = 0
		if (km > 0) {
			mx = sort(mx, 1)
			idx = _datamap_lvruns(mx)
			mu = mx[idx]
			mcnt = _datamap_lvrunlen(idx, km)
			nmr = rows(mu)
		}
		lab = st_varvaluelabel(v)
		if (lab != "") {
			if (!st_vlexists(lab)) lab = ""
		}
		if (k > 0) {
			if (lab != "") labs = st_vlmap(lab, u)
			else labs = J(k, 1, "")
		}
		if (nmr > 0) {
			if (lab != "") mlabs = st_vlmap(lab, mu)
			else mlabs = J(nmr, 1, "")
		}
	}
	st_framecurrent(tgt)

	// no observations, or too many values to list: no rows
	if (N == 0 | k > maxlev) return
	nr = k + nmr
	if (nr == 0) return

	D = J(nr, 8, 0)
	S = J(nr, 3, "")
	D[., 1] = J(nr, 1, dsx)
	D[., 2] = (1::nr)
	hm = 0
	if (k > 0) {
		h = _datamap_lvmask(cnt, m)
		// the Missing total joins the mask as one more cell (header note);
		// the levels' own state is kept and only grown from
		if (m > 0 & nmr > 0) {
			tm = sum(mcnt)
			h = _datamap_lvgrow(cnt \ tm, h \ (tm < m), m)
			hm = h[k + 1]
			h = h[|1 \ k|]
		}
		D[|1, 4 \ k, 4|] = cnt
		D[|1, 5 \ k, 5|] = 100 :* cnt :/ N
		D[|1, 6 \ k, 6|] = (h :!= 0)
		D[|1, 7 \ k, 7|] = (h :== 2)
		if (isstr) {
			D[|1, 3 \ k, 3|] = J(k, 1, .)
			S[|1, 2 \ k, 2|] = su
		}
		else {
			D[|1, 3 \ k, 3|] = u
			S[|1, 3 \ k, 3|] = labs
		}
	}
	if (nmr > 0) {
		D[|k + 1, 4 \ nr, 4|] = mcnt
		D[|k + 1, 5 \ nr, 5|] = 100 :* mcnt :/ N
		D[|k + 1, 6 \ nr, 6|] = J(nmr, 1, (hm != 0))
		D[|k + 1, 7 \ nr, 7|] = J(nmr, 1, (hm == 2))
		D[|k + 1, 8 \ nr, 8|] = J(nmr, 1, 1)
		if (isstr) D[|k + 1, 3 \ nr, 3|] = J(nmr, 1, .)
		else {
			D[|k + 1, 3 \ nr, 3|] = mu
			S[|k + 1, 3 \ nr, 3|] = mlabs
		}
	}
	S[., 1] = J(nr, 1, v)

	r0 = st_nobs()
	st_addobs(nr)
	st_store((r0 + 1 :: r0 + nr), ("ds_index", "level", "value", "count",
		"share", "suppressed", "complementary", "is_missing_code"), D)
	st_sstore((r0 + 1 :: r0 + nr), ("variable", "value_str", "label"), S)
}

// One item of a breakdown as saving() writes it: the code or value text,
// its label, then the count or why it is withheld (h: 0 shown, 1 below m,
// 2 complement).  The Markdown renderer builds the same item, escaped
// (_datamap_md_varrows, _dmv_item).
string scalar _datamap_prof_item(string scalar v, string scalar lab,
	real scalar c, real scalar h, real scalar m)
{
	string scalar s
	s = v + (lab != "" ? " " + lab : "")
	if (h == 1) return(s + " suppressed (<" + strofreal(m) + ")")
	if (h == 2) return(s + " suppressed (complementary)")
	return(s + " " + strofreal(c, "%20.0f"))
}

// Profile step (1) and (2) (see the header).  Runs with the levels frame
// current; vframe is the variables frame, src the dataset's frame.
void _datamap_prof_missing(string scalar vframe, real scalar vf, real scalar vl,
	string scalar src, real scalar dsx, real scalar lf, real scalar m)
{
	string scalar cur, v, lab, txt
	string matrix SV, LS, S
	real matrix DV, LD, D
	real colvector st, len, rr, c, h, x, mx, idx, mu, mc, mrow
	real matrix ms
	real scalar n, i, ii, j, nl, N, nm, nv, hm, hn, k, a1, a2, r0, nr, hasl
	real matrix wi
	string colvector labs, mtxt
	transmorphic A

	if (vl < vf | vf < 1) return
	cur = st_framecurrent()
	n = vl - vf + 1
	st_framecurrent(vframe)
	SV = st_sdata((vf::vl), ("variable", "class", "storage_type"))
	DV = st_data((vf::vl), ("N", "missing"))
	st_framecurrent(cur)

	// this dataset's levels rows, indexed by variable name (one run each)
	A = asarray_create()
	asarray_notfound(A, (0, 0))
	nl = 0
	if (lf >= 1 & lf <= st_nobs()) {
		LS = st_sdata((lf::st_nobs()), ("variable", "value_str", "label"))
		LD = st_data((lf::st_nobs()), ("value", "count", "suppressed",
			"complementary", "is_missing_code", "level"))
		nl = rows(LS)
		st = (nl == 1 ? 1 : selectindex(1 \ (LS[|2, 1 \ nl, 1|] :!= LS[|1, 1 \ nl - 1, 1|])))
		if (rows(st) == 1) len = nl
		else len = (st[|2 \ rows(st)|] \ nl + 1) - st
		for (j = rows(st); j >= 1; j--) asarray(A, LS[st[j], 1], (st[j], st[j] + len[j] - 1))
	}

	ms = J(n, 2, 0)
	mtxt = J(n, 1, "")
	D = J(0, 10, .)
	S = J(0, 3, "")
	// only a variable with missing values has a margin or a code to show
	// (both margins 0 otherwise): wide data skip the loop body
	wi = selectindex((DV[., 2] :> 0) :& (DV[., 2] :< .) :& (DV[., 1] :> 0) :& (DV[., 1] :< .))
	for (ii = 1; ii <= length(wi); ii++) {
		i = wi[ii]
		v = SV[i, 1]
		N = DV[i, 1]
		nm = DV[i, 2]
		if (missing(N) | N <= 0 | missing(nm)) continue
		nv = N - nm
		// the margins (as _datamap_md_varrows printed them in 2.0.0's
		// Phase 2; one place since 2026-11-10)
		hm = 0
		hn = 0
		if (m > 0 & nm > 0 & nv > 0) {
			hm = (nm < m ? 1 : (nv < m ? 2 : 0))
			hn = (nv < m ? 1 : (nm < m ? 2 : 0))
		}
		a1 = 0
		a2 = 0
		if (nl > 0) {
			rr = asarray(A, v)
			a1 = rr[1]
			a2 = rr[2]
		}
		mrow = J(0, 1, .)
		if (a1 > 0) {
			mrow = select((a1::a2), LD[|a1, 5 \ a2, 5|] :== 1)
			// the listed level mask's state of the Missing total
			if (m > 0 & hm == 0 & length(mrow)) {
				if (max(LD[mrow, 4])) hm = 2
				else if (max(LD[mrow, 3])) hm = 1
			}
		}
		ms[i, .] = (hm, hn)

		// per-code counts: numeric, not excluded, with missing values
		if (SV[i, 2] == "excluded" | substr(SV[i, 3], 1, 3) == "str" | nm <= 0) continue
		hasl = length(mrow)
		if (hasl) {
			mu = LD[mrow, 1]
			mc = LD[mrow, 2]
			labs = LS[mrow, 3]
		}
		else {
			st_framecurrent(src)
			x = st_data(., v)
			lab = st_varvaluelabel(v)
			if (lab != "") {
				if (!st_vlexists(lab)) lab = ""
			}
			st_framecurrent(cur)
			mx = select(x, x :>= .)
			if (rows(mx) == 0) continue
			mx = sort(mx, 1)
			idx = (rows(mx) == 1 ? 1 : selectindex(1 \ (mx[|2 \ rows(mx)|] :!= mx[|1 \ rows(mx) - 1|])))
			mu = mx[idx]
			mc = (rows(idx) == 1 ? rows(mx) : (idx[|2 \ rows(idx)|] \ rows(mx) + 1) - idx)
			if (lab != "") {
				st_framecurrent(src)
				labs = st_vlmap(lab, mu)
				st_framecurrent(cur)
			}
			else labs = J(rows(mu), 1, "")
		}
		k = rows(mu)
		// the mask: all withheld with the total; a lone code is the total
		if (m <= 0) h = J(k, 1, 0)
		else if (hm != 0) h = 2 :- ((mc :< m) :& (mc :> 0))
		else if (k == 1) h = 0
		else h = _datamap_lvmask(mc, m)
		if (hasl) {
			st_store(mrow :+ (lf - 1), ("suppressed", "complementary"), ((h :!= 0), (h :== 2)))
		}
		else {
			nr = rows(D)
			D = D \ (J(k, 1, dsx), (1::k), mu, mc, 100 :* mc :/ N, (h :!= 0),
				(h :== 2), J(k, 1, 1), J(k, 1, .), J(k, 1, .))
			S = S \ (J(k, 1, v), J(k, 1, ""), labs)
		}
		// the breakdown, only when a code other than . occurs
		if (sum(mu :> .)) {
			txt = ""
			for (j = 1; j <= k; j++) {
				txt = txt + (j > 1 ? ", " : "") +
					_datamap_prof_item(strofreal(mu[j]), labs[j], mc[j], h[j], m)
			}
			mtxt[i] = txt
		}
	}
	if (rows(D)) {
		r0 = st_nobs()
		nr = rows(D)
		st_addobs(nr)
		st_store((r0 + 1 :: r0 + nr), ("ds_index", "level", "value", "count",
			"share", "suppressed", "complementary", "is_missing_code"), D[., (1..8)])
		st_sstore((r0 + 1 :: r0 + nr), ("variable", "value_str", "label"), S)
	}
	st_framecurrent(vframe)
	st_store((vf::vl), ("missing_state", "n_state"), ms)
	st_sstore((vf::vl), "missing_codes", mtxt)
	st_framecurrent(cur)
}

// The string-class rows of the variables frame (current), vf..vl, with a
// nonmissing value: locals _sv_n, _sv_v<k> (name), _sv_r<k> (row)
void _datamap_prof_strvars(real scalar vf, real scalar vl)
{
	real colvector r, b
	string colvector nm
	real scalar k
	st_local("_sv_n", "0")
	if (vl < vf | vf < 1) return
	r = (vf::vl)
	nm = st_sdata(r, "variable")
	b = (st_sdata(r, "class") :== "string") :&
		(substr(st_sdata(r, "storage_type"), 1, 3) :== "str") :&
		(st_data(r, "N") :- st_data(r, "missing") :> 0)
	b = selectindex(b)
	st_local("_sv_n", strofreal(length(b)))
	for (k = 1; k <= length(b); k++) {
		st_local("_sv_v" + strofreal(k), nm[b[k]])
		st_local("_sv_r" + strofreal(k), strofreal(r[b[k]]))
	}
}

// Profile step (3) for string variable v (row vr of the variables frame
// vframe): the counts the caller took (locals _pf_nv _pf_nnon _pf_pad
// _pf_ymd _pf_dmy _pf_mdy) and, from the observations where nnvar is 1
// (nonblank, real() missing), the non-numeric values.  Runs with the levels
// frame current; src is the dataset's frame.
void _datamap_prof_string(string scalar src, string scalar v, string scalar nnvar,
	string scalar vframe, real scalar vr, real scalar dsx, real scalar m,
	real scalar datesafe, real scalar maxcat, | real scalar safe)
{
	string scalar cur, dm
	string colvector sx, su, rest
	real colvector idx, cnt, o, c, h, pre, pm, b
	real matrix kp
	real scalar nv, nnon, nnum, pad, top, oth, isl, hide, j, r0, few, nc, vec
	real rowvector dc
	string rowvector mk

	if (args() < 10) safe = 0
	cur = st_framecurrent()
	nv = strtoreal(st_local("_pf_nv"))
	nnon = strtoreal(st_local("_pf_nnon"))
	pad = strtoreal(st_local("_pf_pad"))
	nnum = nv - nnon
	// masks read in 95% or more of the nonblank values
	mk = ("YMD", "DMY", "MDY")
	dc = (strtoreal(st_local("_pf_ymd")), strtoreal(st_local("_pf_dmy")),
		strtoreal(st_local("_pf_mdy")))
	dm = ""
	for (j = 1; j <= 3; j++) {
		if (nv > 0 & dc[j] >= 0.95 * nv) dm = dm + (dm == "" ? "" : " or ") + mk[j]
	}
	// few distinct values: an exact count no larger than maxcat()
	st_framecurrent(vframe)
	few = (_st_data(vr, st_varindex("unique")) <= maxcat &
		_st_data(vr, st_varindex("unique_capped")) == 0)
	// counted by matching only up to 24 distinct values: one vector pass per
	// value costs about what one sort does at 30-40 values (1,000,000 rows:
	// 20 values 0.47 s, 40 values 0.91 s, sort 0.87 s; probes/p3fix/vt), and
	// grows with values x rows, so more values are sorted (2026-11-10: an
	// 800-value text at maxcat(1000) took 11 s on 600,000 rows)
	vec = (few & _st_data(vr, st_varindex("unique")) <= 24)
	st_framecurrent(src)
	isl = (st_vartype(v) == "strL")
	sx = J(0, 1, "")
	// safe (2.0.0, U2): no value of text above maxcat() distinct values is
	// listed, the non-numeric values of part-numeric text included
	if (nnon > 0 & (few | (nnum > 0 & !safe))) sx = st_sdata(., v, nnvar)
	st_framecurrent(cur)

	hide = 0
	top = 0
	// the numeric count prints only when the text is part numeric
	nc = (nnum > 0 & nnon > 0)
	if (rows(sx)) {
		su = J(0, 1, "")
		cnt = J(0, 1, .)
		if (vec) {
			// at most 24 distinct values: count each by matching, one
			// vector pass per value, instead of sorting every row (a Mata
			// string sort of 1,000,000 rows took 0.7 s)
			rest = sx
			while (rows(rest) & rows(su) <= maxcat) {
				b = (rest :== rest[1])
				su = su \ rest[1]
				cnt = cnt \ sum(b)
				rest = select(rest, !b)
			}
			if (rows(rest)) {
				su = J(0, 1, "")
				cnt = J(0, 1, .)
			}
			else {
				o = order(su, 1)
				su = su[o]
				cnt = cnt[o]
			}
		}
		if (rows(su) == 0) {
			sx = sort(sx, 1)
			idx = _datamap_lvruns(sx)
			su = sx[idx]
			cnt = _datamap_lvrunlen(idx, rows(sx))
		}
		// a value held by fewer than mincell() observations is never
		// listed (a rare text value can be a name or an identifier): it
		// stays in the rest
		kp = selectindex(cnt :>= max((m, 1)))
		if (length(kp)) {
			su = su[kp]
			cnt = cnt[kp]
			// the five most frequent, ties by value
			o = order((-cnt, (1::rows(cnt))), (1, 2))
			top = min((5, rows(o)))
			o = o[|1 \ top|]
			su = su[o]
			cnt = cnt[o]
		}
	}
	if (nc | top > 0) {
		// datesafe: listed values that read as dates are exact dates
		if (datesafe & top > 0) {
			// date text takes more forms than date() masks read (ISO
			// datetimes, year-month, two-digit years, dates inside other
			// text): any listed value holding a digit (ASCII or any Unicode
			// decimal digit) withholds them all (2026-11-10)
			if (dm != "") hide = 1
			for (j = 1; j <= top; j++) {
				if (regexm(su[j], "[0-9]") | ustrregexm(su[j], "\p{Nd}")) hide = 1
			}
		}
		// the numeric count, the listed values and the rest (never printed,
		// so it pools with the withheld cells) are one table over N=, which
		// the row prints: a cell below m, the rest included, is withheld
		// with complements (_datamap_lvgrow)
		c = J(0, 1, .)
		if (nc) c = nnum
		if (top > 0) c = c \ cnt
		pre = J(rows(c), 1, 0)
		// values withheld under datesafe are not printed: they pool
		if (hide) pre[|nc + 1 \ nc + top|] = J(top, 1, 1)
		oth = nnon - (top > 0 ? sum(cnt) : 0)
		if (oth > 0) {
			c = c \ oth
			pre = pre \ 1
		}
		h = J(rows(c), 1, 0)
		if (m > 0) {
			pm = (c :< m) :& (c :> 0)
			if (sum(pm)) h = _datamap_lvgrow(c, pm :| pre, m)
		}
		st_framecurrent(vframe)
		st_store(vr, "numeric_state", (nc ? h[1] : 0))
		st_framecurrent(cur)
		if (top > 0 & !hide) {
			r0 = st_nobs()
			st_addobs(top)
			st_store((r0 + 1 :: r0 + top), ("ds_index", "level", "value", "count",
				"share", "suppressed", "complementary", "is_missing_code"),
				(J(top, 1, dsx), (1::top), J(top, 1, .), cnt,
				100 :* cnt :/ strtoreal(st_local("_pf_N")),
				(h[|nc + 1 \ nc + top|] :!= 0), (h[|nc + 1 \ nc + top|] :== 2), J(top, 1, 0)))
			st_sstore((r0 + 1 :: r0 + top), ("variable", "value_str", "label"),
				(J(top, 1, v), su, J(top, 1, "")))
		}
	}
	else {
		// all numeric text, or nothing listed: no numeric count is printed
		st_framecurrent(vframe)
		st_store(vr, "numeric_state", 0)
		st_framecurrent(cur)
	}
	st_framecurrent(vframe)
	st_store(vr, ("numeric_n", "padded_n", "padded_state", "is_strl", "tokens_hidden"),
		(nnum, pad, (m > 0 & pad > 0 & pad < m), isl, hide))
	st_sstore(vr, "date_mask", dm)
	st_framecurrent(cur)
}

end

program define _datamap_collect_levels, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [varlist(default=none)] , FRame(name) [CREATE DSINDEX(integer 0) ///
            MAXLevels(integer 25) MINCell(integer 0) PROFile VARFrame(name) ///
            VFIRST(integer 0) VLAST(integer 0) LFIRST(integer 0) DATESafe ///
            MAXCat(integer 25) SAFE]

        if "`create'" != "" {
            if "`varlist'" != "" {
                noisily display as error "_datamap_collect_levels: create takes no varlist"
                exit 198
            }
            frame create `frame' long ds_index str32 variable long level ///
                double value strL value_str strL label double count ///
                double share byte suppressed byte complementary ///
                byte is_missing_code
        }
        else if "`profile'" != "" {
            if `dsindex' < 1 | "`varframe'" == "" {
                noisily display as error "_datamap_collect_levels: profile requires dsindex() and varframe()"
                exit 198
            }
            local _src = c(frame)
            local _dsf = ("`datesafe'" != "")
            // (1) and (2): margins and per-code missing counts
            frame `frame': mata: _datamap_prof_missing("`varframe'", `vfirst', ///
                `vlast', "`_src'", `dsindex', `lfirst', `mincell')
            // (3) the string profile: counts in Stata (real() and date() as
            // the user's own code reads them), the values in Mata
            frame `varframe': mata: _datamap_prof_strvars(`vfirst', `vlast')
            local _pf_N = c(N)
            forvalues _k = 1/`_sv_n' {
                local _v "`_sv_v`_k''"
                tempvar _nn
                quietly generate byte `_nn' = (`_v' != "") & missing(real(`_v'))
                quietly count if `_v' != ""
                local _pf_nv = r(N)
                quietly count if `_nn'
                local _pf_nnon = r(N)
                quietly count if `_v' != "" & (substr(`_v', 1, 1) == " " | substr(`_v', -1, 1) == " ")
                local _pf_pad = r(N)
                // a mask counts only when it reads 95% or more of the
                // nonblank values: more than 5% failing in the first
                // rows already rules it out (exact; the full count is
                // then not taken and the mask's count is left at 0)
                local _K = min(c(N), floor(0.05 * `_pf_nv') + 1 + c(N) - `_pf_nv')
                foreach _mk in YMD DMY MDY {
                    local _pf_`=lower("`_mk'")' = 0
                    quietly count if `_v' != "" & missing(date(`_v', "`_mk'")) in 1/`_K'
                    if r(N) <= 0.05 * `_pf_nv' {
                        quietly count if `_v' != "" & !missing(date(`_v', "`_mk'"))
                        local _pf_`=lower("`_mk'")' = r(N)
                    }
                }
                frame `frame': mata: _datamap_prof_string("`_src'", "`_v'", "`_nn'", ///
                    "`varframe'", `_sv_r`_k'', `dsindex', `mincell', `_dsf', `maxcat', ///
                    "`safe'" != "")
                quietly drop `_nn'
            }
        }
        else {
            if `dsindex' < 1 {
                noisily display as error "_datamap_collect_levels: dsindex() must be a datasets-frame row"
                exit 198
            }
            local _src = c(frame)
            tempname _R _F _MR _MC
            foreach _v of local varlist {
                // A numeric variable is counted by -tabulate- (one pass in
                // C; a Mata sort of the column cost more than the writers'
                // own tables).  When it refuses -- no observations, nothing
                // nonmissing, more rows than it can tabulate -- Mata counts.
                local _mats ""
                capture confirm numeric variable `_v'
                if _rc == 0 {
                    capture quietly tabulate `_v', matrow(`_R') matcell(`_F')
                    local _trc = _rc
                    if `_trc' == 1 exit 1
                    // nothing nonmissing (or no observations): rc 0, r(r) 0
                    // and no matrices -- Mata counts the missing values
                    if `_trc' == 0 & r(r) == 0 local _trc = 2000
                    if `_trc' == 0 {
                        // too many values to list: no rows
                        if r(r) > `maxlevels' continue
                        quietly count if missing(`_v')
                        if r(N) > 0 {
                            quietly tabulate `_v' if missing(`_v'), missing ///
                                matrow(`_MR') matcell(`_MC')
                            local _mats "`_R' `_F' `_MR' `_MC'"
                        }
                        else local _mats "`_R' `_F' . ."
                    }
                }
                frame `frame': mata: _datamap_levels_post("`_src'", "`_v'", ///
                    `dsindex', `maxlevels', `mincell', "`_mats'")
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
