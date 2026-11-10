*! _datamap_md_sections Version 2.0.0  2026/11/10
*! datamap's Markdown fragments that need the data: structure, missingness, sample rows
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_md_sections, dsframe(f) dsindex(#) varframe(f) vfirst(#) vlast(#)
//     docvars(names) [excluded(names) datevars(names) catvars(names)
//     detect_panel(#) detect_binary(#) detect_survival(#) detect_survey(#)
//     detect_common(#) panelid(name) survivalvars(names) missing_detail(#)
//     missing_pattern(#) samples(#) mincell(#) datesafe dateformat(fmt)]
//
// Runs during collection, with the dataset loaded, and stores three Markdown
// fragments -- bullet lines or a table, no heading -- in row dsindex of the
// datasets frame (_datamap_collect_dataset): structure (what detect(),
// autodetect, panelid() and survivalvars() found), missingness (missing())
// and samples (samples()).  The renderer (_datamap_md_document) prints each
// under its own heading and never reads the data.  Each per-variable count
// here is read from the variables frame (rows vfirst..vlast); what is counted
// here is cross-variable (complete rows, missing-value patterns) or what a
// detector derives (panel units, an event rate, survey weights).
//
// docvars: the documented variables; every detector, the missingness summary
// and the sample rows read only these.  excluded: every excluded variable of
// the dataset (a variable named in panelid() or survivalvars() is checked
// against it too); no value, range, rate or cardinality of one is written.
// Percentages follow the document's one rule: 100 * count / n rounded half
// up to 0.1 in integer arithmetic, one decimal (_dms_pctc, the copy of
// _datamap_md_varrows' _dmv_pctc; 2026-11-10: round(x, 0.1) split decimal
// ties on binary noise).

capture mata: mata drop _dms_add()
capture mata: mata drop _dms_codes()
capture mata: mata drop _dms_pct()
capture mata: mata drop _dms_pctc()
capture mata: mata drop _dms_store()
capture mata: mata drop _dms_vinfo()
capture mata: mata drop _dms_esc()
capture mata: mata drop _dms_isdatefmt()
capture mata: mata drop _dms_datefmt()
capture mata: mata drop _dms_maskcore()
capture mata: mata drop _dms_pinned()
capture mata: mata drop _dms_patviol()
capture mata: mata drop _dms_patmargin()
capture mata: mata drop _dms_patmask()
capture mata: mata drop _dms_samples()
capture mata: mata drop _dms_rangestr()
mata:
// local acc += newline + local ln (no newline before the first line).  A
// line is built in a Stata local, where a backtick is macro syntax, so it
// marks a code span with {bq}; here, in Mata, that becomes the backtick.
// Lines carry variable names, numbers and fixed text only (a name cannot
// hold a brace).  The accumulated local is only ever read by Mata.
void _dms_add(string scalar acc, string scalar ln)
{
	string scalar a
	a = st_local(acc)
	st_local(acc, a + (a == "" ? "" : char(10)) + subinstr(st_local(ln), "{bq}", char(96)))
}
// names in local src as {bq}a{bq}, {bq}b{bq}, ... in local dst (see _dms_add)
void _dms_codes(string scalar src, string scalar dst)
{
	string rowvector t
	t = tokens(st_local(src))
	if (cols(t) == 0) st_local(dst, "")
	else st_local(dst, invtokens("{bq}" :+ t :+ "{bq}", ", "))
}
// 100 * c / n, rounded half up to 0.1, from the integer k (exact; see
// _dmv_pctc in _datamap_md_varrows)
string scalar _dms_pctc(real scalar c, real scalar n)
{
	real scalar k, a, b
	if (missing(c) | missing(n) | n <= 0) return(".")
	a = 2000 * c + n
	b = 2 * n
	k = floor(a / b)
	return(strofreal(floor(k / 10), "%20.0f") + "." + strofreal(mod(k, 10), "%1.0f"))
}
// cell (r, col) of the current frame (the datasets frame) <- local loc
void _dms_store(real scalar r, string scalar col, string scalar loc)
{
	st_sstore(r, col, st_local(loc))
}
// From the variables frame (current), rows vf..vl: the binary variables
// (numeric, two distinct values, count not censored, no date format, not
// excluded) in _bin; variables over 50% missing in _m50 and their number in
// _n50; the number over 10% in _n10
void _dms_vinfo(real scalar vf, real scalar vl)
{
	string matrix S
	real matrix D
	real colvector r, pm, b
	st_local("_bin", "")
	st_local("_m50", "")
	st_local("_n50", "0")
	st_local("_n10", "0")
	if (vl < vf | vf < 1) return
	r = (vf::vl)
	S = st_sdata(r, ("variable", "class", "storage_type", "display_format"))
	D = st_data(r, ("N", "missing", "unique", "unique_capped"))
	b = (substr(S[., 3], 1, 3) :!= "str") :& (S[., 2] :!= "excluded") :&
		(D[., 3] :== 2) :& (D[., 4] :== 0)
	b = b :& !((substr(subinstr(S[., 4], "%-", "%"), 1, 2) :== "%t") :|
		(substr(subinstr(S[., 4], "%-", "%"), 1, 2) :== "%d"))
	if (sum(b)) st_local("_bin", invtokens(select(S[., 1], b)'))
	pm = J(rows(r), 1, 0)
	pm = (D[., 1] :> 0) :* (100 :* D[., 2] :/ (D[., 1] + (D[., 1] :== 0)))
	if (sum(pm :> 50)) st_local("_m50", invtokens(select(S[., 1], pm :> 50)'))
	st_local("_n50", strofreal(sum(pm :> 50)))
	st_local("_n10", strofreal(sum(pm :> 10)))
}
string scalar _dms_esc(string scalar text)
{
	real scalar i
	text = subinstr(text, char(92), char(92) + char(92))
	text = subinstr(text, "|", char(92) + "|")
	text = subinstr(text, char(36), "&#36;")
	text = subinstr(text, char(96), "&#96;")
	// 2026-11-10: the "' rule of the other copies was missing here, so a
	// sample value a"'b reached the file raw (a Stata line reader: rc 198)
	text = subinstr(text, char(34) + char(39), char(34) + "&#39;")
	text = subinstr(text, char(13) + char(10), " ")
	text = subinstr(text, char(10), " ")
	text = subinstr(text, char(13), " ")
	for (i = 1; i <= 31; i++) text = subinstr(text, char(i), " ")
	text = subinstr(text, char(127), " ")
	text = subinstr(text, "<", "&lt;")
	text = subinstr(text, ">", "&gt;")
	return(text)
}
real scalar _dms_isdatefmt(string scalar f)
{
	f = subinstr(f, "%-", "%", 1)
	return(substr(f, 1, 2) == "%t" | substr(f, 1, 2) == "%d")
}
string scalar _dms_datefmt(string scalar vfmt, string scalar dfmt)
{
	string scalar f, d, clk
	f = subinstr(vfmt, "%-", "%", 1)
	if (strpos(f, "%td") | strpos(f, "%d")) return(dfmt)
	if (strpos(f, "%tc") | strpos(f, "%tC")) {
		clk = (strpos(f, "%tC") ? "%tC" : "%tc")
		d = subinstr(dfmt, "%-", "%", 1)
		if (substr(d, 1, 3) == "%td") return(clk + substr(d, 4, .))
		if (substr(d, 1, 2) == "%d") return(clk + substr(d, 3, .))
	}
	return(vfmt)
}
// "lo to hi" of variable v in local dst: dates (isdate) in their display
// format, other values rounded to 0.1
void _dms_rangestr(string scalar v, real scalar lo, real scalar hi,
	real scalar isdate, string scalar dfmt, string scalar dst)
{
	string scalar f
	if (isdate) {
		f = _dms_datefmt(st_varformat(v), dfmt)
		st_local(dst, strtrim(strofreal(lo, f)) + " to " + strtrim(strofreal(hi, f)))
	}
	else st_local(dst, strtrim(strofreal(round(lo, 0.1), "%14.0g")) + " to " +
		strtrim(strofreal(round(hi, 0.1), "%14.0g")))
}
// The small-cell mask with complementary suppression (datamap's cell rule;
// _datamap_collect_levels applies the same one to frequency cells).  Codes:
// 0 shown, 1 below m, 2 withheld as a complement; cells flagged in pre are
// withheld for another reason, pool with the rest and come back 0.
real colvector _dms_maskcore(real colvector c, real scalar m, real colvector pre)
{
	real colvector h
	real scalar k, best, j
	k = rows(c)
	h = J(k, 1, 0)
	if (m <= 0 | k == 0) return(h)
	h = (c :< m) :& (c :> 0)
	h = h :| (pre :!= 0)
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
	return(h :* (pre :== 0))
}
// The pattern cells against the margins the same document prints
// (2026-11-10).  _dms_maskcore pools the withheld cells against the total
// only, but the Missing column prints every variable's missing count, and a
// variable's count is the sum of the patterns with "." in its place: in g2,
// age's 10 minus the shown `..+` 6 gave the suppressed `.++` 4.  A of the
// cells: row 1 the total, row 1 + j variable j's margin.  A suppressed
// (below-m) cell is protected when no published margin pins it: its column
// of A restricted to the unknown cells (withheld or not shown) is not in the
// span of the others, and no margin leaves the unknown cells in it a pooled
// count of 1 to m - 1 that the margins do not already fix on their own.  Shown cells (the complete-rows cell among them) are
// withheld as complements until that holds: the smallest cell that clears
// every check, else the one leaving the fewest, then each added cell that a
// later pick made redundant is shown again, largest first (up to 60 cells);
// with more
// cells, the margin checks only (a lone unknown in a margin, a small pooled
// count) and the smallest cell sharing a margin with a failing one.  A check
// that fails with every cell withheld is pinned by the margins themselves
// (one variable with missing values: complete rows = N - its count); no
// complement helps there and none is added for it.  Not run when A would
// pass 4e6 entries.
// 1 when the pooled count w'x is fixed by the margins alone (w in the row
// space of A): withholding more cells cannot hide it.  Full mode: rank test
// (rkA = rank of A); otherwise w equal to a margin row.
real scalar _dms_pinned(real matrix A, real rowvector w, real scalar rkA,
	real scalar full)
{
	real scalar r
	if (full) return(rank(uniqrows(A \ w)) == rkA)
	for (r = 1; r <= rows(A); r++) {
		if (A[r, .] == w) return(1)
	}
	return(0)
}
real scalar _dms_patviol(real matrix A, real colvector c, real colvector U,
	real colvector prim, real colvector rowok, real scalar m, real scalar full,
	real scalar rkA)
{
	real scalar nv, r, s, rk, j, k
	real rowvector keep
	real matrix B, u
	nv = 0
	// length(), not cols(): with one pattern (K == 1) selectindex() of a
	// 1 x 1 false is 1 x 0, and its transpose has one column
	u = selectindex(U)
	if (length(u) == 0) return(0)
	u = vec(u)'
	for (r = 1; r <= rows(A); r++) {
		if (!rowok[r]) continue
		s = A[r, u] * c[u']
		if (s > 0 & s < m) {
			if (!_dms_pinned(A, A[r, .] :* U', rkA, full)) nv++
		}
	}
	if (full) {
		B = uniqrows(A[., u])
		rk = rank(B)
		for (j = 1; j <= cols(u); j++) {
			if (!prim[u[j]]) continue
			if (cols(u) == 1) {
				nv++
				continue
			}
			keep = select((1..cols(u)), (1..cols(u)) :!= j)
			if (rank(B[., keep]) < rk) nv++
		}
	}
	else {
		for (j = 1; j <= cols(u); j++) {
			k = u[j]
			if (!prim[k]) continue
			for (r = 1; r <= rows(A); r++) {
				if (A[r, k] == 1 & sum(A[r, u]) == 1) {
					nv++
					break
				}
			}
		}
	}
	return(nv)
}
real colvector _dms_patmargin(real colvector c, string colvector P,
	real scalar m, real colvector pre, real colvector h)
{
	real scalar K, v, k, full, best, bv, nv, i, r, rkA
	real matrix A
	real matrix cand
	real colvector U, prim, rowok, ord, primok, Ua, shared, added
	K = rows(c)
	v = strlen(P[1])
	if ((v + 1) * K > 4e6) return(h)
	A = J(v + 1, K, 0)
	A[1, .] = J(1, K, 1)
	for (k = 1; k <= K; k++) A[|2, k \ v + 1, k|] = (ascii(P[k]) :== 46)'
	full = (K <= 60)
	rkA = (full ? rank(uniqrows(A)) : .)
	added = J(0, 1, .)
	// the checks that fail with every cell withheld are left out
	Ua = J(K, 1, 1)
	rowok = ((A * c) :>= m) :| ((A * c) :== 0)
	prim = (h :== 1)
	primok = J(K, 1, 0)
	for (k = 1; k <= K; k++) {
		if (!prim[k]) continue
		primok[k] = (_dms_patviol(A, c, Ua, e(k, K)', J(rows(A), 1, 0), m, full, rkA) == 0)
	}
	prim = prim :* primok
	U = (h :!= 0) :| (pre :!= 0)
	while ((nv = _dms_patviol(A, c, U, prim, rowok, m, full, rkA)) > 0) {
		cand = selectindex((U :== 0))
		// length(), not rows(): with one pattern (K == 1) selectindex() of
		// a 1 x 1 false is 1 x 0
		if (length(cand) == 0) break
		cand = vec(cand)
		// ascending count, then position
		ord = order((c[cand], cand), (1, 2))
		cand = cand[ord]
		best = 0
		if (full) {
			bv = nv
			for (i = 1; i <= rows(cand); i++) {
				U[cand[i]] = 1
				r = _dms_patviol(A, c, U, prim, rowok, m, full, rkA)
				U[cand[i]] = 0
				if (r < bv) {
					best = cand[i]
					bv = r
					if (r == 0) break
				}
			}
		}
		else {
			// the smallest cell sharing a margin with a withheld cell
			shared = (colsum(A[|2, 1 \ v + 1, K|] :* (rowsum(A[|2, 1 \ v + 1, K|] :* (U :* prim)') :> 0)) :> 0)'
			for (i = 1; i <= rows(cand); i++) {
				if (shared[cand[i]]) {
					best = cand[i]
					break
				}
			}
		}
		if (best == 0) best = cand[1]
		U[best] = 1
		h[best] = 2
		added = added \ best
	}
	// a greedy pick can be made redundant by a later one: each added cell,
	// largest first, is shown again when every check still holds without it
	// none added: skip (c[J(0, 1, .)] of a 1 x 1 c is 1 x 0, not 0 x 1)
	if (full & nv == 0 & rows(added) > 0) {
		added = added[order((-c[added], added), (1, 2))]
		for (i = 1; i <= rows(added); i++) {
			U[added[i]] = 0
			if (_dms_patviol(A, c, U, prim, rowok, m, full, rkA) == 0) h[added[i]] = 0
			else U[added[i]] = 1
		}
	}
	return(h)
}
// Missing-value patterns: counts in variable cvar of the current frame,
// most frequent first; rows past nshow are not printed and pool as withheld.
// The all-observed pattern (local ccloc, matched in string variable pvar) is
// printed as the complete-rows count, so it never joins the pool; its code is
// _phcc.  Codes of the printed rows: _ph1 ... _ph<nshow>.
void _dms_patmask(string scalar cvar, real scalar m, real scalar nshow,
	string scalar pvar, string scalar ccloc)
{
	real colvector c, pre, h, cc
	real scalar k
	c = st_data(., cvar)
	pre = (1::rows(c)) :> nshow
	cc = (st_sdata(., pvar) :== st_local(ccloc))
	pre = pre :* (cc :== 0)
	h = _dms_maskcore(c, m, pre)
	if (m > 0 & sum(h :== 1) > 0) h = _dms_patmargin(c, st_sdata(., pvar), m, pre, h)
	for (k = 1; k <= min((nshow, rows(c))); k++) {
		st_local("_ph" + strofreal(k), strofreal(h[k]))
	}
	st_local("_phcc", "0")
	if (sum(cc) > 0) st_local("_phcc", strofreal(max(select(h, cc))))
}
// The sample-rows table of the first n observations of the variables in
// vlist, in local _smp.  Excluded variables print [MASKED]; under datesafe
// a date-class or date-formatted variable prints [DATE SUPPRESSED]; a
// string is cut to 20 characters (17 and ...), never mid-character.
void _dms_samples(string scalar vlist, string scalar excl, string scalar dates,
	real scalar n, real scalar datesafe, string scalar dfmt)
{
	string rowvector v, ex, dt
	string scalar out, cell, s, f
	real scalar i, j, k, x, isex, isdt, nr
	v = tokens(vlist)
	ex = tokens(excl)
	dt = tokens(dates)
	k = cols(v)
	if (k == 0) {
		st_local("_smp", "")
		return
	}
	nr = min((n, st_nobs()))
	out = "|"
	for (j = 1; j <= k; j++) out = out + " " + v[j] + " |"
	out = out + char(10) + "|"
	for (j = 1; j <= k; j++) out = out + "---|"
	for (i = 1; i <= nr; i++) {
		out = out + char(10) + "|"
		for (j = 1; j <= k; j++) {
			isex = (cols(ex) ? sum(ex :== v[j]) > 0 : 0)
			isdt = (cols(dt) ? sum(dt :== v[j]) > 0 : 0)
			f = st_varformat(v[j])
			if (isex) cell = "[MASKED]"
			else if (datesafe & (isdt | (!st_isstrvar(v[j]) & _dms_isdatefmt(f)))) {
				cell = "[DATE SUPPRESSED]"
			}
			else if (st_isstrvar(v[j])) {
				s = _st_sdata(i, st_varindex(v[j]))
				if (ustrlen(s) > 20) s = usubstr(s, 1, 17) + "..."
				cell = _dms_esc(s)
			}
			else {
				x = _st_data(i, st_varindex(v[j]))
				if (missing(x)) cell = "."
				else if (isdt) cell = strtrim(strofreal(x, _dms_datefmt(f, dfmt)))
				else cell = strtrim(strofreal(x, "%14.0g"))
			}
			out = out + " " + cell + " |"
		}
	}
	st_local("_smp", out)
}
end

program define _datamap_md_sections, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, DSFrame(name) DSINDEX(integer) VARFrame(name) ///
            VFIRST(integer) VLAST(integer) DOCvars(string) ///
            [EXCluded(string) DATEVars(string) CATVars(string) ///
            detect_panel(integer 0) detect_binary(integer 0) ///
            detect_survival(integer 0) detect_survey(integer 0) ///
            detect_common(integer 0) PANELid(string) SURVIVALvars(string) ///
            missing_detail(integer 0) missing_pattern(integer 0) ///
            SAMples(integer 0) MINCell(integer 0) DATESafe DATEFormat(string)]
        if `"`dateformat'"' == "" local dateformat "%tdCCYY/NN/DD"
        local _ds = ("`datesafe'" != "")

        // per-variable facts from the variables frame
        frame `varframe': mata: _dms_vinfo(`vfirst', `vlast')

        **# structure
        local _st ""
        if `detect_binary' & "`_bin'" != "" {
            mata: _dms_codes("_bin", "_c")
            local _ln "- Binary (two distinct values): `_c'"
            mata: _dms_add("_st", "_ln")
        }

        // panel: panelid() whether or not detect(panel) is on, else the
        // first documented, non-excluded variable whose name reads as an ID
        if `detect_panel' | "`panelid'" != "" {
            local id_var ""
            if "`panelid'" != "" {
                capture confirm variable `panelid', exact
                if _rc {
                    local _ln "- Panel: identifier `panelid' not found"
                    mata: _dms_add("_st", "_ln")
                }
                else local id_var "`panelid'"
            }
            else {
                foreach vn of local docvars {
                    if `: list vn in excluded' continue
                    if regexm(lower("`vn'"), "id$|_id$|^id_|patient|subject|person") {
                        local id_var "`vn'"
                        continue, break
                    }
                }
            }
            if "`id_var'" != "" {
                if `: list id_var in excluded' {
                    local _ln "- Panel: identifier {bq}`id_var'{bq} is excluded; unit counts withheld"
                    mata: _dms_add("_st", "_ln")
                }
                else {
                    // exact count: a censored count is not a number of units
                    _datamap_nuniq `id_var', cap(0)
                    local n_units = r(n)
                    quietly count if !missing(`id_var')
                    local n_idobs = r(N)
                    local n_noid = _N - `n_idobs'
                    // a panel when some unit has more than one row
                    if `n_units' > 0 & `n_units' < `n_idobs' {
                        local _avg = strtrim(string(`n_idobs' / `n_units', "%9.1f"))
                        local _ln "- Panel: identifier {bq}`id_var'{bq}; `n_units' units; `=_N' rows"
                        if `n_noid' > 0 local _ln "`_ln' (`n_noid' with a missing identifier)"
                        local _ln "`_ln'; `_avg' rows per unit"
                        mata: _dms_add("_st", "_ln")
                    }
                }
            }
        }

        // survival: survivalvars() names the candidates, else every
        // documented variable is matched by name
        if `detect_survival' | `"`survivalvars'"' != "" {
            local candidates "`docvars'"
            local user_named = 0
            if `"`survivalvars'"' != "" {
                local candidates ""
                foreach sv of local survivalvars {
                    capture unab _svx : `sv'
                    if _rc continue
                    local candidates : list candidates | _svx
                }
                local user_named = 1
            }
            local time_vars ""
            local event_vars ""
            foreach vn of local candidates {
                local vn_lower = lower("`vn'")
                local is_time = regexm("`vn_lower'", "time|duration|followup|follow_up|survtime|_t$|^t_")
                local is_event = regexm("`vn_lower'", "event|failure|death|died|status|censor|_d$|^d_")
                // a user-named variable that matches neither name pattern is
                // an event indicator with at most two values, else a time
                if `user_named' & !`is_time' & !`is_event' {
                    capture confirm numeric variable `vn'
                    if _rc == 0 & !`: list vn in excluded' {
                        _datamap_nuniq `vn', cap(0)
                        if r(n) <= 2 local is_event = 1
                        else local is_time = 1
                    }
                    else local is_time = 1
                }
                if `is_time' local time_vars "`time_vars' `vn'"
                if `is_event' local event_vars "`event_vars' `vn'"
            }
            if "`time_vars'" != "" {
                mata: _dms_codes("time_vars", "_c")
                local _ln "- Survival time variables: `_c'"
                mata: _dms_add("_st", "_ln")
                // the range of the first numeric, non-excluded one; a date
                // in its display format, and none under datesafe
                local first_time ""
                foreach tv of local time_vars {
                    if `: list tv in excluded' continue
                    if `_ds' & `: list tv in datevars' continue
                    capture confirm numeric variable `tv'
                    if _rc continue
                    local first_time "`tv'"
                    continue, break
                }
                if "`first_time'" != "" {
                    quietly summarize `first_time'
                    if r(N) > 0 {
                        local _isd : list first_time in datevars
                        mata: _dms_rangestr("`first_time'", `r(min)', `r(max)', `_isd', ///
                            st_local("dateformat"), "_rng")
                        local _ln "  - {bq}`first_time'{bq} range: `_rng'"
                        mata: _dms_add("_st", "_ln")
                    }
                }
            }
            if "`event_vars'" != "" {
                mata: _dms_codes("event_vars", "_c")
                local _ln "- Survival event indicators: `_c'"
                mata: _dms_add("_st", "_ln")
                // the rate of the first numeric, non-excluded 0/1 indicator;
                // the rate times N is the event count, so it obeys mincell()
                foreach ev of local event_vars {
                    if `: list ev in excluded' continue
                    capture confirm numeric variable `ev'
                    if _rc continue
                    _datamap_nuniq `ev', cap(0)
                    if r(n) != 2 continue
                    quietly summarize `ev'
                    if r(min) != 0 | r(max) != 1 continue
                    local _nev = r(sum)
                    local _nnon = r(N) - r(sum)
                    if `mincell' > 0 & (`_nev' < `mincell' | `_nnon' < `mincell') {
                        local _ln "  - {bq}`ev'{bq} rate: suppressed (<`mincell' in a cell)"
                    }
                    else {
                        // the rate's denominator is the indicator's
                        // nonmissing values, not N: said so in the line
                        // (2026-11-10; the document's shares are of N)
                        mata: st_local("_rate", _dms_pctc(`_nev', `_nev' + `_nnon'))
                        local _ln "  - {bq}`ev'{bq} rate: `_rate'% of nonmissing values"
                    }
                    mata: _dms_add("_st", "_ln")
                    continue, break
                }
            }
        }

        // survey design elements, by name; excluded ones are named only
        if `detect_survey' {
            foreach vn of local docvars {
                local vn_lower = lower("`vn'")
                if regexm("`vn_lower'", "weight|wgt|_wt$|^wt_|pweight|fweight") {
                    if `: list vn in excluded' {
                        local _ln "- Survey weight {bq}`vn'{bq}: excluded; statistics withheld"
                        mata: _dms_add("_st", "_ln")
                    }
                    else {
                        capture confirm numeric variable `vn'
                        if _rc == 0 {
                            quietly summarize `vn'
                            local w_min = strtrim(string(round(r(min), 0.1), "%14.0g"))
                            local w_max = strtrim(string(round(r(max), 0.1), "%14.0g"))
                            local w_mean = strtrim(string(round(r(mean), 0.1), "%14.0g"))
                            // a categorical weight's mean, or a two- or
                            // three-valued one's, gives suppressed cells back
                            local _wcls = cond(`: list vn in catvars', "categorical", "continuous")
                            local _wnu = -1
                            if "`_wcls'" == "continuous" & `mincell' > 0 {
                                _datamap_nuniq `vn', cap(0)
                                local _wnu = r(n)
                            }
                            _datamap_sumpolicy, class(`_wcls') mincell(`mincell') nuniq(`_wnu')
                            if r(cathide) | r(momhide) local w_mean "withheld (mincell)"
                            local _ln "- Survey weight {bq}`vn'{bq}: range `w_min' to `w_max'; mean `w_mean'"
                            mata: _dms_add("_st", "_ln")
                        }
                    }
                }
                if regexm("`vn_lower'", "strat") {
                    if `: list vn in excluded' local _ln "- Survey strata {bq}`vn'{bq}: excluded; count withheld"
                    else {
                        _datamap_nuniq `vn', cap(0)
                        local _ln "- Survey strata {bq}`vn'{bq}: `r(n)' strata"
                    }
                    mata: _dms_add("_st", "_ln")
                }
                if regexm("`vn_lower'", "cluster|psu") {
                    if `: list vn in excluded' local _ln "- Survey clusters {bq}`vn'{bq}: excluded; count withheld"
                    else {
                        _datamap_nuniq `vn', cap(0)
                        local _ln "- Survey clusters {bq}`vn'{bq}: `r(n)' primary sampling units"
                    }
                    mata: _dms_add("_st", "_ln")
                }
            }
        }

        // name patterns (names only: nothing here reads a value)
        if `detect_common' {
            foreach _g in ids dates outcomes exposures demos {
                local _p_`_g' ""
            }
            foreach vn of local docvars {
                local vn_lower = lower("`vn'")
                if regexm("`vn_lower'", "id$|_id$|^id_|patient|subject") local _p_ids "`_p_ids' `vn'"
                else if regexm("`vn_lower'", "date|_dt$|^dt_|dob|death") local _p_dates "`_p_dates' `vn'"
                else if regexm("`vn_lower'", "outcome|death|event|died") local _p_outcomes "`_p_outcomes' `vn'"
                else if regexm("`vn_lower'", "exposure|treatment|drug|rx") local _p_exposures "`_p_exposures' `vn'"
                else if regexm("`vn_lower'", "^age$|^sex$|gender|race|ethnicity|ethnic") local _p_demos "`_p_demos' `vn'"
            }
            local _parts ""
            foreach _g in ids dates outcomes exposures demos {
                if "`_p_`_g''" == "" continue
                mata: _dms_codes("_p_`_g'", "_c")
                local _gl = cond("`_g'" == "ids", "IDs", cond("`_g'" == "demos", "demographics", "`_g'"))
                if "`_parts'" == "" local _parts "`_gl' `_c'"
                else local _parts "`_parts'; `_gl' `_c'"
            }
            if "`_parts'" != "" {
                local _ln "- Name patterns: `_parts'"
                mata: _dms_add("_st", "_ln")
            }
        }

        **# missingness
        local _mi ""
        if `missing_detail' | `missing_pattern' {
            local obs = _N
            if `_n50' > 0 {
                mata: _dms_codes("_m50", "_c")
                local _ln "- Variables more than 50% missing: `_n50' (`_c')"
            }
            else local _ln "- Variables more than 50% missing: 0"
            mata: _dms_add("_mi", "_ln")
            local _ln "- Variables more than 10% missing: `_n10'"
            mata: _dms_add("_mi", "_ln")

            // complete rows over the documented variables
            tempvar complete
            quietly gen byte `complete' = 1
            local anymiss_vars ""
            foreach vn of local docvars {
                quietly count if missing(`vn')
                if r(N) > 0 {
                    quietly replace `complete' = 0 if missing(`vn')
                    local anymiss_vars "`anymiss_vars' `vn'"
                }
            }
            quietly count if `complete' == 1
            local n_complete = r(N)
            quietly drop `complete'

            // missing(pattern): a pattern is a cross-variable cell, masked
            // like any frequency cell before the complete-rows line, which
            // is the all-observed pattern's cell
            local _cc_hide = 0
            local npv : word count `anymiss_vars'
            local npat = 0
            local nshow = 0
            if `missing_pattern' & `npv' > 0 & `npv' <= 2045 {
                tempvar pat
                quietly gen str`npv' `pat' = ""
                foreach vn of local anymiss_vars {
                    quietly replace `pat' = `pat' + cond(missing(`vn'), ".", "+")
                }
                tempname pfr
                frame put `pat', into(`pfr')
                quietly drop `pat'
                frame `pfr' {
                    rename `pat' pattern
                    quietly contract pattern, freq(n)
                    gsort -n pattern
                    local npat = _N
                    local nshow = min(`npat', 10)
                    forvalues k = 1/`nshow' {
                        local pat`k' = pattern[`k']
                        local n`k' = n[`k']
                    }
                    local _allobs = `npv' * "+"
                    mata: _dms_patmask("n", `mincell', `nshow', "pattern", "_allobs")
                }
                frame drop `pfr'
                if `_phcc' != 0 local _cc_hide = 1
            }

            local _n_incomplete = `obs' - `n_complete'
            if `mincell' > 0 & ((`n_complete' > 0 & `n_complete' < `mincell') | ///
                (`_n_incomplete' > 0 & `_n_incomplete' < `mincell')) {
                local _ln "- Complete rows: suppressed (<`mincell' in a cell)"
            }
            else if `_cc_hide' local _ln "- Complete rows: suppressed (complementary)"
            else if `obs' == 0 local _ln "- Complete rows: 0 (no observations)"
            else {
                mata: st_local("_pc", _dms_pctc(`n_complete', `obs'))
                local _ln "- Complete rows: `n_complete' (`_pc'%)"
            }
            mata: _dms_add("_mi", "_ln")

            if `missing_pattern' {
                if `npv' == 0 local _ln "- Missing-value patterns: none (no missing values)"
                else if `npv' > 2045 local _ln "- Missing-value patterns: `npv' variables have missing values; too many to list"
                else {
                    mata: _dms_codes("anymiss_vars", "_c")
                    local _ln "- Missing-value patterns (+ observed, . missing) over `_c': `npat' distinct"
                }
                mata: _dms_add("_mi", "_ln")
                forvalues k = 1/`nshow' {
                    if `_ph`k'' == 1 local _ln "  - {bq}`pat`k''{bq}: suppressed (<`mincell')"
                    else if `_ph`k'' == 2 local _ln "  - {bq}`pat`k''{bq}: suppressed (complementary)"
                    else {
                        mata: st_local("_pp", _dms_pctc(`n`k'', `obs'))
                        local _ln "  - {bq}`pat`k''{bq}: `n`k'' (`_pp'%)"
                    }
                    mata: _dms_add("_mi", "_ln")
                }
                if `npat' > 10 {
                    local _ln "  - `=`npat' - 10' more pattern(s) not shown"
                    mata: _dms_add("_mi", "_ln")
                }
            }
        }

        **# sample rows
        local _smp ""
        if `samples' > 0 & _N == 0 local _smp "No rows: the dataset has no observations."
        else if `samples' > 0 {
            mata: _dms_samples(st_local("docvars"), st_local("excluded"), ///
                st_local("datevars"), `samples', `_ds', st_local("dateformat"))
            local _sh "First `=min(`samples', _N)' rows (excluded variables masked"
            if `_ds' local _sh "`_sh'; dates suppressed"
            local _sh "`_sh'):"
            mata: st_local("_smp", st_local("_sh") + char(10) + char(10) + st_local("_smp"))
        }

        frame `dsframe' {
            mata: _dms_store(`dsindex', "structure", "_st")
            mata: _dms_store(`dsindex', "missingness", "_mi")
            mata: _dms_store(`dsindex', "samples", "_smp")
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
