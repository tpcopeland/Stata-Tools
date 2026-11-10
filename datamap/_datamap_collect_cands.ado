*! _datamap_collect_cands Version 2.0.0  2026/11/10
*! Placeholder candidates of each variable, for datamap's quality section
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_collect_cands, varframe(v) vfirst(#) vlast(#) dateformat(fmt)
//     [levframe(l) lfirst(#) mincell(#) placeholders(numlist) datesafe]
//
// With the dataset in the current frame (datamap 2.0.0 Phase 3, F5,
// 2026-11-10; run only under quality): for rows vfirst..vlast of the
// variables frame, the values that may stand in for a missing or unknown
// value, as text in column candidates ("" when none).  Candidates only:
// nothing is recoded, and the Flags and statistics are computed as before.
//
// Rules (what a fetched source supports, and nothing more; the 2.0.0
// literature check found no citable source for a built-in numeric rule set
// such as 9/99/999 or -1/-9 at a distribution edge, so there is none):
//   date      a variable of the date class or with a date display format
//             (date_family): the placeholder dates 01jan1900, 01jan1960
//             (Stata's date 0) and 31dec9999, for the families with day
//             resolution (%td, %tc, %tC; any time of that day); and values
//             after the run date (c(current_date)) in every family but %tb
//             and %tg, compared by period (a %tm value after this month),
//             not counting the placeholder dates
//   declared  placeholders(numlist): each listed value, in every numeric
//             variable that is not a date, compared as stored (a float
//             variable against float(value))
// Excluded and string variables get none.  Under datesafe a date variable
// with any candidate reads "candidates withheld (datesafe)": its frequencies
// are withheld there, and a candidate is an exact date with its count
// (2026-11-10: printed "1960/01/01: 12 rows").
//
// Each item reads "<value>: <count> rows".  Masking, so no count in
// 1..mincell()-1 is printed: a count below mincell() reads "suppressed (<m)".
// A variable whose levels the document lists takes the levels' own mask
// (a candidate equal to a level withheld as a complement is withheld too),
// and every count is withheld when the variable's nonmissing N= is
// (n_state), since a candidate can equal it.
//
// The variables frame needs the profile margins (n_state) first:
// _datamap_collect_levels, profile runs before this.

capture mata: mata drop _datamap_cd_run()
capture mata: mata drop _datamap_cd_item()
capture mata: mata drop _datamap_cd_day()
capture mata: mata drop _datamap_cd_period()
mata:
// day number of x in family f (%td %tc %tC); . for the other families
real colvector _datamap_cd_day(real colvector x, string scalar f)
{
	if (f == "%td") return(floor(x))
	if (f == "%tc") return(dofc(x))
	if (f == "%tC") return(dofC(x))
	return(J(rows(x), 1, .))
}
// the period of day d in family f, as the family counts it
real scalar _datamap_cd_period(real scalar d, string scalar f)
{
	if (f == "%td" | f == "%tc" | f == "%tC") return(d)
	if (f == "%tw") return(wofd(d))
	if (f == "%tm") return(mofd(d))
	if (f == "%tq") return(qofd(d))
	if (f == "%th") return(hofd(d))
	if (f == "%ty") return(year(d))
	return(.)
}
// one item; h: 0 shown, 1 below m, 2 withheld as a complement
string scalar _datamap_cd_item(string scalar what, real scalar c, real scalar h,
	real scalar m)
{
	if (h == 1) return(what + ": suppressed (<" + strofreal(m) + ")")
	if (h == 2) return(what + ": suppressed (complementary)")
	return(what + ": " + strofreal(c, "%20.0f") + (c == 1 ? " row" : " rows"))
}
// Runs with the variables frame current; src the dataset's frame, lev the
// levels frame (lf its first row of this dataset, 0: none), codes the
// declared values, fcodes the same as float and ctxt their numlist text.
void _datamap_cd_run(string scalar src, real scalar vf, real scalar vl,
	string scalar lev, real scalar lf, real scalar m, string scalar dfmt,
	real rowvector codes, real rowvector fcodes, string rowvector ctxt, real scalar datesafe)
{
	string matrix S, LS
	real matrix D, LD
	string colvector out
	string scalar cur, v, f, txt, what
	real scalar i, j, k, today, c, h, a1, a2, hn, nl, isfl, per, anyh
	real colvector x, day, pd, lr, b, lday, lper
	real rowvector cd
	real colvector st, len
	transmorphic A

	if (vf < 1 | vl < vf) return
	cur = st_framecurrent()
	S = st_sdata((vf::vl), ("variable", "class", "storage_type", "date_family"))
	D = st_data((vf::vl), ("N", "missing", "n_state"))
	// the placeholder dates: 01jan1900, 01jan1960, 31dec9999
	pd = (mdy(1, 1, 1900) \ 0 \ mdy(12, 31, 9999))
	today = date(c("current_date"), "DMY")

	// this dataset's listed levels (not the missing-code rows), by name
	A = asarray_create()
	asarray_notfound(A, (0, 0))
	nl = 0
	if (lev != "" & lf >= 1) {
		st_framecurrent(lev)
		if (lf <= st_nobs()) {
			LS = st_sdata((lf::st_nobs()), "variable")
			LD = st_data((lf::st_nobs()), ("value", "count", "suppressed",
				"complementary", "is_missing_code"))
			nl = rows(LS)
			st = (nl == 1 ? 1 : selectindex(1 \ (LS[|2 \ nl|] :!= LS[|1 \ nl - 1|])))
			if (rows(st) == 1) len = nl
			else len = (st[|2 \ rows(st)|] \ nl + 1) - st
			for (j = rows(st); j >= 1; j--) asarray(A, LS[st[j]], (st[j], st[j] + len[j] - 1))
		}
		st_framecurrent(cur)
	}

	out = J(rows(S), 1, "")
	for (i = 1; i <= rows(S); i++) {
		v = S[i, 1]
		if (S[i, 2] == "excluded" | substr(S[i, 3], 1, 3) == "str") continue
		if (missing(D[i, 1]) | D[i, 1] - D[i, 2] <= 0) continue
		f = substr(S[i, 4], 1, 3)
		if (f == "" & S[i, 2] == "date") f = "%td"
		if (f == "" & cols(codes) == 0) continue
		if (f == "%tb" | f == "%tg") continue
		hn = (missing(D[i, 3]) ? 0 : D[i, 3])
		// the variable's listed levels, when the document lists them
		lr = J(0, 1, .)
		if (nl) {
			a1 = asarray(A, v)
			a2 = a1[2]
			a1 = a1[1]
			if (a1 > 0) lr = select((a1::a2), LD[|a1, 5 \ a2, 5|] :== 0)
		}
		st_framecurrent(src)
		x = st_data(., v)
		isfl = (st_vartype(v) == "float")
		st_framecurrent(cur)
		x = select(x, x :< .)
		txt = ""
		// k = 1..K: the items; b marks the candidate rows of x, lday the
		// rows of the levels that make the candidate
		if (f != "") {
			day = _datamap_cd_day(x, f)
			if (length(lr)) lday = _datamap_cd_day(LD[lr, 1], f)
			for (k = 1; k <= 3 + 1; k++) {
				if (k <= 3) {
					if (f != "%td" & f != "%tc" & f != "%tC") continue
					b = (day :== pd[k])
					if (length(lr)) lper = (lday :== pd[k])
					what = strtrim(strofreal(pd[k], dfmt))
				}
				else {
					per = _datamap_cd_period(today, f)
					if (missing(per)) continue
					if (f == "%td" | f == "%tc" | f == "%tC") {
						b = (day :> today) :& !(day :== pd[3])
						if (length(lr)) lper = (lday :> today) :& !(lday :== pd[3])
					}
					else {
						b = (floor(x) :> per)
						if (length(lr)) lper = (floor(LD[lr, 1]) :> per)
					}
					what = "after " + strtrim(strofreal(today, dfmt)) + " (run date)"
				}
				c = sum(b)
				if (c == 0) continue
				h = (m > 0 & c < m)
				anyh = 0
				if (length(lr)) anyh = sum(select(LD[lr, 3], lper)) > 0
				if (m > 0 & (anyh | hn)) h = (c < m ? 1 : 2)
				txt = txt + (txt == "" ? "" : "; ") + _datamap_cd_item(what, c, h, m)
			}
			if (datesafe & txt != "") txt = "candidates withheld (datesafe)"
		}
		else {
			for (k = 1; k <= cols(codes); k++) {
				cd = (isfl ? fcodes[k] : codes[k])
				c = sum(x :== cd)
				if (c == 0) continue
				h = (m > 0 & c < m)
				anyh = 0
				if (length(lr)) anyh = sum(select(LD[lr, 3], LD[lr, 1] :== cd)) > 0
				if (m > 0 & (anyh | hn)) h = (c < m ? 1 : 2)
				// the value as the numlist wrote it
				what = ctxt[k]
				txt = txt + (txt == "" ? "" : "; ") + _datamap_cd_item(what, c, h, m)
			}
		}
		out[i] = txt
	}
	st_sstore((vf::vl), "candidates", out)
}
end

program define _datamap_collect_cands, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , VARFrame(name) VFIRST(integer) VLAST(integer) ///
            DATEFormat(string) [LEVFrame(name) LFIRST(integer 0) ///
            MINCell(integer 0) PLACEholders(numlist) DATESafe]
        local _src = c(frame)
        // the declared values, and the same as float for a float variable
        local _codes : list uniq placeholders
        // the dates print in dateformat() when it is a daily format (the
        // document's), else in datamap's default
        local _df `"`dateformat'"'
        local _dfs = subinstr(`"`_df'"', "%-", "%", 1)
        if substr(`"`_dfs'"', 1, 3) != "%td" & substr(`"`_dfs'"', 1, 2) != "%d" ///
            local _df "%tdCCYY/NN/DD"
        tempname _C _F
        local _ncod : word count `_codes'
        if `_ncod' {
            matrix `_C' = J(1, `_ncod', .)
            matrix `_F' = J(1, `_ncod', .)
            forvalues _k = 1/`_ncod' {
                matrix `_C'[1, `_k'] = `: word `_k' of `_codes''
                matrix `_F'[1, `_k'] = float(`: word `_k' of `_codes'')
            }
        }
        frame `varframe': mata: _datamap_cd_run("`_src'", `vfirst', `vlast', ///
            "`levframe'", `lfirst', `mincell', st_local("_df"), ///
            (`_ncod' ? st_matrix("`_C'") : J(1, 0, .)), ///
            (`_ncod' ? st_matrix("`_F'") : J(1, 0, .)), tokens(st_local("_codes")), ///
            ("`datesafe'" != ""))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
