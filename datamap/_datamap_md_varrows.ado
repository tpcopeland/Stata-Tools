*! _datamap_md_varrows Version 2.0.0  2026/11/10
*! The Markdown variable-table rows of one dataset, read from the collector frames
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_md_varrows using file, varframe(f) vfirst(#) vlast(#)
//     columns(list) mincell(#) maxfreq(#) dateformat(fmt)
//     [levframe(f) lfirst(#) llast(#) nofreq nostats nolabels datesafe]
//
// Appends one table row to `file' for each row vfirst..vlast of the variables
// frame (_datamap_post_metadata_rows), in that order, with the cells named in
// columns() (_datamap_md_columns).  Every number and every share printed here
// is read from the frames: counts, shares and small-cell codes of a level
// from the levels frame (_datamap_collect_levels, rows lfirst..llast), the
// summaries from the variables frame.  Nothing is counted or summarized here,
// and the data are never read.
//
// One percent rule for the whole document: the share (100 * count / N, N
// counting every row) rounded half up to 0.1, printed with one decimal
// (_dmv_pctc).  datamap's text map printed round(share, 0.1) with %5.1f and
// datadict printed %9.1f of the share, which split a binary tie such as
// 22.25 (22.3 against 22.2).  2026-11-10: round(share, 0.1) split decimal
// ties too (3/2000 printed 0.1%, 5/2000 0.3%, 19/2000 0.9%), so the share is
// rounded from the frame's count and N in integer arithmetic, where a tie is
// exact.  The levels frame's share column stays the stored value.
//
// A numeric level prints in its display format only when that format reads
// back as the level itself (_dmv_levfmt): a lossy user format printed
// distinct levels alike (1234567890 and 1234567891 at %8.0g, 0.2 and 0.4 at
// %9.0f).  Date formats print in dateformat(), as before.
//
// Small cells reach the row's margins too (2026-11-10): under mincell() the
// Missing cell and the N= term are withheld when either part of N is below
// m, and the Missing total is one more cell of a listed variable's level
// mask.  Since Phase 3 (2026-11-10) the collector decides both states once
// (_datamap_collect_levels, profile: missing_state, n_state), and saving()'s
// missing_codes follows the same decision; this file only prints them.
//
// Phase 3 (2026-11-10):
//   Type (U4)     storage type, then the date family of a date display
//                 format: "double %td daily", "double %tc datetime"
//                 (date_family, _datamap_datefamily)
//   Missing (F3)  "276 (9.2%): . 51, .a Refused 145, .b Not asked 80": the
//                 per-code counts from the levels frame's missing-code rows,
//                 each masked (suppressed (<m) / (complementary)), printed
//                 only when a code other than . occurs (_dmv_codes), and
//                 not under nofreq
//   string (F4)   numeric text and its share, the most frequent non-numeric
//                 values, values with a leading or trailing space, the
//                 date() mask the text reads as (_dmv_strprof); no count
//                 when the N= term is withheld
//
// An exact zero in a statistics cell prints with the cell's decimals
// (_dmv_celldec, 2026-11-10): "median=0" stood bare beside "mean=0.050".
//
// The notes and characteristics readers (_dmv_brcell) are here, beside their
// only consumer: Mata in an autoloaded .ado is private to its file.

capture mata: mata drop _dmv_esc()
capture mata: mata drop _dmv_pctc()
capture mata: mata drop _dmv_num()
capture mata: mata drop _dmv_numparse()
capture mata: mata drop _dmv_fltdec()
capture mata: mata drop _dmv_levfmt()
capture mata: mata drop _dmv_ndec()
capture mata: mata drop _dmv_pair()
capture mata: mata drop _dmv_celldec()
capture mata: mata drop _dmv_isdatefmt()
capture mata: mata drop _dmv_datefmt()
capture mata: mata drop _dmv_spanunit()
capture mata: mata drop _dmv_uniq()
capture mata: mata drop _dmv_brcell()
capture mata: mata drop _dmv_runstarts()
capture mata: mata drop _dmv_hidden()
capture mata: mata drop _dmv_item()
capture mata: mata drop _dmv_codes()
capture mata: mata drop _dmv_strprof()
capture mata: mata drop _dmv_values()
capture mata: mata drop _dmv_rows()
mata:
// Text for a Markdown table cell (datadict's escape): a backslash first, so
// a\|b keeps its backslash once the pipe is escaped; $ and ` as entities, so
// no renderer reads math or a code span into a label; < and > as entities, so
// a label is never raw HTML; line breaks as spaces, so a cell stays one line.
// 2026-11-10: every other control byte (1-31, 127: tab, CHR(1) ...) is a
// space too; they reached the cell verbatim.  The same body in all four
// copies (_dms_esc, _dmd_esc, _dmtb_esc).
string scalar _dmv_esc(string scalar text)
{
	real scalar i
	text = subinstr(text, char(92), char(92) + char(92))
	text = subinstr(text, "|", char(92) + "|")
	text = subinstr(text, char(36), "&#36;")
	text = subinstr(text, char(96), "&#96;")
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

// The one percent rule (see the header): 100 * c / n rounded half up to 0.1,
// k = floor((2000c + n) / 2n) tenths.  Numerator and denominator are exact
// integers and one division is taken, so the quotient is an integer exactly
// when it should be and otherwise lies at least 1/(2n) from one; floor() is
// exact.  (Mata evaluated 1000 * 201 / 400 as 502.4999..., so the shape
// matters.)  The digits are printed from the integer k, never from k/10.
string scalar _dmv_pctc(real scalar c, real scalar n)
{
	real scalar k, a, b
	if (missing(c) | missing(n) | n <= 0) return(".")
	a = 2000 * c + n
	b = 2 * n
	k = floor(a / b)
	return(strofreal(floor(k / 10), "%20.0f") + "." + strofreal(mod(k, 10), "%1.0f"))
}

// A summary statistic by magnitude (datadict's FormatStatNumber): every digit
// from 100 up (to 1e15, where a double stops holding every integer digit),
// two decimals from 1, three below 1, scientific below 0.001.
// 2026-11-10: an exact zero has no magnitude of its own, so it prints with
// dz decimals, the cell's (_dmv_celldec): "mean=0.050; SD=0.220; median=0"
// printed the zero bare beside three-decimal statistics.  dz < 0 or not
// given: a bare 0.
string scalar _dmv_num(real scalar x, | real scalar dz)
{
	real scalar a
	string scalar s
	if (missing(x)) return(".")
	a = abs(x)
	if (a == 0) {
		if (args() < 2 | missing(dz) | dz < 0) return("0")
		return(strtrim(strofreal(0, "%32." + strofreal(dz) + "f")))
	}
	if (a < 0.001) return(strtrim(strofreal(x, "%9.2e")))
	if (a >= 1e15) return(strtrim(strofreal(x, "%21.0g")))
	if (a >= 100) return(strtrim(strofreal(x, "%32.0fc")))
	// 2026-11-10: the class is the printed magnitude, so a number that
	// rounds up into the next class prints by that class's rule (0.9996
	// printed "1.000", 99.996 "100.00")
	if (a >= 1) {
		s = strtrim(strofreal(x, "%9.2f"))
		if (abs(strtoreal(s)) >= 100) return(strtrim(strofreal(x, "%32.0fc")))
		return(s)
	}
	s = strtrim(strofreal(x, "%9.3f"))
	if (abs(strtoreal(s)) >= 1) return(strtrim(strofreal(x, "%9.2f")))
	return(s)
}

// The decimals of a number printed by _dmv_num: -2 for a bare zero, -1 for
// a form that has no fixed decimals (scientific, %g from 1e15, missing)
real scalar _dmv_ndec(string scalar s, real scalar x)
{
	real scalar p
	if (s == "0") return(-2)
	if (abs(x) >= 1e15) return(-1)
	if (s == "." | strpos(s, "e") | strpos(s, "E")) return(-1)
	p = strpos(s, ".")
	if (p == 0) return(0)
	return(strlen(s) - p)
}

// The decimals of one statistics cell (2026-11-10): the finest fixed-decimal
// count among its nonzero statistics x as _dmv_num prints them; -1 when none
// has fixed decimals (all zero, scientific or missing).  Exact zeros in the
// cell print with it.
real scalar _dmv_celldec(real rowvector x)
{
	real scalar i, d, k
	d = -1
	for (i = 1; i <= cols(x); i++) {
		if (missing(x[i]) | x[i] == 0) continue
		k = _dmv_ndec(_dmv_num(x[i]), x[i])
		if (k > d) d = k
	}
	return(d)
}

// Both ends of an IQR or range (datadict's FormatPair): two different ends
// that print alike get eight significant digits; a minus sign anywhere makes
// the separator " to " (IQR=-250--83.50 read wrongly).
// 2026-11-10: both ends print with ONE number of decimals, the finer of the
// two (a zero end takes the other's): the magnitude classes split a pair
// ("range=0-1.00", "range=1.00-100", "IQR=-224 to -73.50").  An end in
// scientific notation keeps its own form.  dz: the cell's decimals for an
// exact-zero end (_dmv_num).
string scalar _dmv_pair(real scalar lo, real scalar hi, | real scalar dz)
{
	string scalar a, b
	real scalar da, db, d
	if (args() < 3) dz = -1
	a = _dmv_num(lo, dz)
	b = _dmv_num(hi, dz)
	da = _dmv_ndec(a, lo)
	db = _dmv_ndec(b, hi)
	if (da != -1 & db != -1 & da != db) {
		d = max((da, db))
		if (d >= 0) {
			a = strtrim(strofreal(lo, "%32." + strofreal(d) + "fc"))
			b = strtrim(strofreal(hi, "%32." + strofreal(d) + "fc"))
		}
	}
	if (a == b & !missing(lo) & !missing(hi) & lo != hi) {
		a = strtrim(strofreal(lo, "%20.8g"))
		b = strtrim(strofreal(hi, "%20.8g"))
		// %g drops trailing zeros (100.004-100.24): pad the shorter end,
		// which is exact
		da = _dmv_ndec(a, lo)
		db = _dmv_ndec(b, hi)
		if (da >= 0 & db >= 0 & da != db) {
			if (da < db) a = a + (da == 0 ? "." : "") + (db - da) * "0"
			else b = b + (db == 0 ? "." : "") + (da - db) * "0"
		}
	}
	if (substr(a, 1, 1) == "-" | substr(b, 1, 1) == "-" | strpos(a + b, "e-")) {
		return(a + " to " + b)
	}
	return(a + "-" + b)
}

// 1 when a display format is a date format (%t..., %d...; %-td too)
real scalar _dmv_isdatefmt(string scalar f)
{
	f = subinstr(f, "%-", "%", 1)
	return(substr(f, 1, 2) == "%t" | substr(f, 1, 2) == "%d")
}

// The format a date prints in: dateformat() for a daily variable, the daily
// body of dateformat() on the variable's own clock for %tc/%tC, else its own
// format (datamap's and datadict's DateDisplayFormat).
string scalar _dmv_datefmt(string scalar vfmt, string scalar dfmt)
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

// The unit of a date variable's span
string scalar _dmv_spanunit(string scalar vfmt)
{
	string scalar f
	f = subinstr(vfmt, "%-", "%", 1)
	if (strpos(f, "%tc") | strpos(f, "%tC")) return("milliseconds")
	if (strpos(f, "%tw")) return("weeks")
	if (strpos(f, "%tm")) return("months")
	if (strpos(f, "%tq")) return("quarters")
	if (strpos(f, "%th")) return("half-years")
	if (strpos(f, "%ty")) return("years")
	return("days")
}

// A distinct count, censored counts as >cap (_datamap_fmt_uniq)
string scalar _dmv_uniq(real scalar n, real scalar capped)
{
	if (missing(n)) return(".")
	if (!missing(capped) & capped != 0) return(">" + strtrim(strofreal(n - 1, "%18.0f")))
	return(strtrim(strofreal(n, "%18.0f")))
}

// The notes and characteristics readers: the frame holds a variable's notes
// (or its name=value characteristics) joined by <br>, raw; each piece is
// escaped and the pieces are joined by <br> again.
string scalar _dmv_brcell(string scalar raw)
{
	string rowvector p
	string scalar out
	real scalar i, j, k
	if (raw == "") return("")
	out = ""
	i = 1
	while (1) {
		j = strpos(substr(raw, i, .), "<br>")
		if (j == 0) {
			out = out + (out == "" ? "" : "<br>") + _dmv_esc(substr(raw, i, .))
			break
		}
		out = out + (out == "" ? "" : "<br>") + _dmv_esc(substr(raw, i, j - 1))
		i = i + j + 3
	}
	return(out)
}

// The number a printed level reads back as (a %fc format's thousands
// separators removed; Mata's strofreal() ignores -set dp-)
real scalar _dmv_numparse(string scalar s)
{
	return(strtoreal(subinstr(strtrim(s), ",", "")))
}

// The shortest decimal (2 to 9 significant digits) that a float variable
// stores as the float x: the number a float level is.  y rounds to x when it
// lies within half of x's float spacing u, a tie going to the even float.
// P holds 2^-160 ... 2^160 built by doubling: Mata's 2^k is not exact (2^-123
// and some positive powers came back off by an ulp).  Subnormal floats use
// the subnormal spacing 2^-149.
real scalar _dmv_fltdec(real scalar x, real colvector P)
{
	real scalar a, e, u, p, y, d
	if (missing(x) | x == 0) return(x)
	a = abs(x)
	e = floor(ln(a) / ln(2))
	if (e > 159) e = 159
	if (e < -159) e = -159
	while (e > -159 & P[e + 161] > a) e--
	while (e < 159 & P[e + 162] <= a) e++
	if (e < -126) e = -126
	u = P[e - 23 + 161]
	// %32.pe: p decimals, p + 1 significant digits (%32.0e is every digit,
	// not one; a one-digit decimal comes out of p = 1 as d.0e)
	for (p = 1; p <= 8; p++) {
		y = strtoreal(strofreal(x, "%32." + strofreal(p) + "e"))
		d = abs(y - x)
		if (d < u / 2 | (d == u / 2 & mod(a / u, 2) == 0)) return(y)
	}
	return(x)
}

// The levels x of one variable as printed (see the header).  Returns the
// format and leaves in y the numbers to print in it: x, or for a float each
// level's shortest decimal (_dmv_fltdec).  A date format prints in its
// dateformat() form; otherwise the display format when every level reads
// back from it exactly; else the first of %9.0g ... %24.0g that does; else
// %21x, which is exact.  One format per variable, so its levels print alike.
string scalar _dmv_levfmt(real colvector x, string scalar vfmt,
	string scalar dfmt, real scalar isflt, real colvector y)
{
	string rowvector cand
	real colvector P
	real scalar c, i, ok, w
	y = x
	if (_dmv_isdatefmt(vfmt)) return(_dmv_datefmt(vfmt, dfmt))
	if (isflt) {
		P = J(321, 1, 1)
		for (i = 1; i <= 160; i++) {
			P[161 + i] = P[160 + i] * 2
			P[161 - i] = P[162 - i] / 2
		}
		for (i = 1; i <= rows(x); i++) y[i] = _dmv_fltdec(x[i], P)
	}
	cand = (vfmt != "" ? vfmt : "%12.0g")
	for (w = 9; w <= 24; w++) cand = cand, "%" + strofreal(w) + ".0g"
	for (c = 1; c <= cols(cand); c++) {
		ok = 1
		for (i = 1; i <= rows(y); i++) {
			if (_dmv_numparse(strofreal(y[i], cand[c])) != y[i]) {
				ok = 0
				break
			}
		}
		if (ok) return(cand[c])
	}
	return("%21x")
}

// start of each run of equal names in nm (rows(nm) >= 1)
real colvector _dmv_runstarts(string colvector nm)
{
	real scalar n
	n = rows(nm)
	if (n == 1) return(1)
	return(selectindex(1 \ (nm[|2 \ n|] :!= nm[|1 \ n - 1|])))
}

// A withheld margin's cell text
string scalar _dmv_hidden(real scalar h, real scalar m)
{
	if (h == 1) return("suppressed (<" + strofreal(m) + ")")
	return("suppressed (complementary)")
}

// One breakdown item: text v (already escaped), then the count or why it is
// withheld (h: 0 shown, 1 below m, 2 complement).  The same item as
// saving()'s missing_codes (_datamap_collect_levels, _datamap_prof_item).
string scalar _dmv_item(string scalar v, real scalar c, real scalar h, real scalar m)
{
	if (h) return(v + " " + _dmv_hidden(h, m))
	return(v + " " + strofreal(c, "%20.0f"))
}

// The per-code missing breakdown of one variable from its levels rows
// (LS: value_str, label; LD: value, count, share, suppressed,
// complementary, is_missing_code): "" unless a code other than . occurs.
string scalar _dmv_codes(string matrix LS, real matrix LD, real scalar m,
	real scalar nolabels)
{
	real matrix mr
	real scalar j, h
	string scalar out, t
	if (rows(LD) == 0) return("")
	mr = selectindex(LD[., 6] :== 1)
	if (length(mr) == 0) return("")
	// selectindex() of a 1x1 is a row: mr is a matrix, read by length()
	if (sum(LD[mr, 1] :> .) == 0) return("")
	out = ""
	for (j = 1; j <= length(mr); j++) {
		t = strofreal(LD[mr[j], 1])
		if (!nolabels & LS[mr[j], 2] != "") t = t + " " + _dmv_esc(LS[mr[j], 2])
		h = (LD[mr[j], 5] ? 2 : LD[mr[j], 4])
		out = out + (j > 1 ? ", " : "") + _dmv_item(t, LD[mr[j], 2], h, m)
	}
	return(out)
}

// The string profile of a string-class variable (F4), appended to its
// Values cell.  The listed values (rows of LD) are the non-numeric ones of
// numeric text, or the values of a text variable with few distinct values
// (the collector decides; _datamap_collect_levels, profile).  dv: the variables-frame row (numeric_n 18, numeric_state 19,
// padded_n 20, padded_state 21, tokens_hidden 23); dmask: date_mask; LS/LD
// its levels rows, here the listed non-numeric values (is_missing_code 0);
// hn: the N= term's state -- when it is withheld no count is printed.
// nofreq: no value is listed.
string scalar _dmv_strprof(real rowvector dv, string scalar dmask,
	string matrix LS, real matrix LD, real scalar m, real scalar hn,
	real scalar nofreq)
{
	string scalar out, its
	real scalar N, nv, nnum, j, sh, h
	real matrix tr
	N = dv[1]
	nv = N - dv[2]
	nnum = dv[18]
	out = ""
	if (missing(nnum)) return("")
	if (nnum > 0 & nnum == nv) out = out + "; all numeric text"
	else if (nnum > 0 & hn) out = out + "; numeric text mixed with non-numeric values"
	else if (!hn) {
		if (nnum > 0) out = out + "; numeric text " + (dv[19] ? _dmv_hidden(dv[19], m) :
			strofreal(nnum, "%20.0f") + " (" + _dmv_pctc(nnum, N) + "%)")
		if (nofreq) {
			// nofreq: no value is listed
		}
		else if (dv[23]) out = out + "; " + (nnum > 0 ? "non-numeric " : "") + "values withheld (datesafe)"
		else {
			tr = (rows(LD) ? selectindex(LD[., 6] :== 0) : J(0, 1, .))
			if (length(tr)) {
				its = ""
				sh = 0
				for (j = 1; j <= length(tr); j++) {
					h = (LD[tr[j], 5] ? 2 : LD[tr[j], 4])
					its = its + (j > 1 ? ", " : "") +
						_dmv_item(char(34) + _dmv_esc(LS[tr[j], 1]) + char(34), LD[tr[j], 2], h, m)
					sh = sh + LD[tr[j], 2]
				}
				if (nv - nnum > sh) its = its + ", others"
				out = out + "; " + (nnum > 0 ? "non-numeric " : "values ") + its
			}
		}
	}
	if (dv[20] > 0 & !missing(dv[20])) {
		if (hn) out = out + "; values with leading or trailing spaces"
		else out = out + "; leading or trailing spaces " + (dv[21] ? _dmv_hidden(dv[21], m) :
			strofreal(dv[20], "%20.0f"))
	}
	if (dmask != "") out = out + "; date-like text (" + dmask + ")"
	return(out)
}

// The Values/Statistics cell of one variable.  sv: the variables-frame text
// row of _dmv_rows (name, storage type, display format, class, ...,
// date_mask 10); dv: its number row (N, missing, unique, unique_capped,
// mean, sd, p50, p25, p75, min, max, maxlen, span, ...; see _dmv_rows).
// LS/LD: the variable's levels rows (value_str, label / value, count, share,
// suppressed, complementary, is_missing_code), or J(0, .) when it has none.
// hn: the N= term's state (n_state).
string scalar _dmv_values(string rowvector sv, real rowvector dv,
	string matrix LS, real matrix LD, real scalar mincell,
	real scalar maxfreq, string scalar dfmt, real scalar nofreq,
	real scalar nostats, real scalar nolabels, real scalar datesafe,
	real scalar hn, | real scalar safe)
{
	string scalar cls, out, ln, lab, df, lvf
	real scalar N, nvalid, isstr, isdf, i, k, h, dz, nr
	real matrix nm
	real colvector lvy

	if (args() < 13) safe = 0
	cls = sv[4]
	N = dv[1]
	nvalid = N - dv[2]
	isstr = (substr(sv[2], 1, 3) == "str")
	isdf = (!isstr & _dmv_isdatefmt(sv[3]))
	if (cls == "excluded") return("excluded (structure only)")
	if (N == 0) return("No observations")
	if (nvalid <= 0) return("All missing")

	if (cls == "categorical") {
		if (datesafe & isdf) return("frequencies withheld (datesafe)")
		if (nofreq) return(_dmv_uniq(dv[3], dv[4]) + " distinct")
		// length(), not rows(): with one levels row (a lone missing-code
		// row) selectindex() returns 1 x 0, whose rows() is 1
		nm = (rows(LD) ? selectindex(LD[., 6] :== 0) : J(0, 1, .))
		k = length(nm)
		if (k) nm = vec(nm)
		if (k == 0) {
			// no level rows: more distinct values than maxfreq()
			return(_dmv_uniq(dv[3], dv[4]) + " distinct; frequencies not listed (more than maxfreq(" +
				strofreal(maxfreq) + "))")
		}
		out = ""
		nr = 0
		if (!isstr) lvf = _dmv_levfmt(LD[nm, 1], sv[3], dfmt, sv[2] == "float", lvy)
		for (i = 1; i <= k; i++) {
			// safe (maskrare, U2): a level below mincell() is not named --
			// its value can identify, as dataprobe's [suppressed]
			if (safe & !LD[nm[i], 5] & LD[nm[i], 4] == 1) {
				nr++
				continue
			}
			if (isstr) ln = char(34) + _dmv_esc(LS[nm[i], 1]) + char(34)
			else {
				ln = strtrim(strofreal(lvy[i], lvf))
				lab = LS[nm[i], 2]
				if (!nolabels & lab != "") ln = ln + " " + _dmv_esc(lab)
			}
			h = (LD[nm[i], 5] ? 2 : LD[nm[i], 4])
			if (h == 1) ln = ln + ": suppressed (<" + strofreal(mincell) + ")"
			else if (h == 2) ln = ln + ": suppressed (complementary)"
			else ln = ln + ": " + strofreal(LD[nm[i], 2], "%20.0f") + " (" + _dmv_pctc(LD[nm[i], 2], N) + "%)"
			out = out + (out != "" ? "<br>" : "") + ln
		}
		if (nr) out = out + (out != "" ? "<br>other values" : "all values") +
			": suppressed (<" + strofreal(mincell) + " each)"
		return(out)
	}
	if (cls == "continuous") {
		out = (hn ? "N=" + _dmv_hidden(hn, mincell) : "N=" + strofreal(nvalid, "%20.0f"))
		if (datesafe & isdf) return(out + "; summary withheld (datesafe)")
		if (nostats | missing(dv[7])) return(out)
		// exact zeros take the cell's decimals (a withheld mean/SD is
		// missing here, so it does not count)
		dz = _dmv_celldec(dv[(5..11)])
		if (missing(dv[5])) out = out + "; mean and SD withheld (mincell; two or three values)"
		else out = out + "; mean=" + _dmv_num(dv[5], dz) + "; SD=" + _dmv_num(dv[6], dz)
		out = out + "; median=" + _dmv_num(dv[7], dz) + "; IQR=" + _dmv_pair(dv[8], dv[9], dz) +
			"; range=" + _dmv_pair(dv[10], dv[11], dz)
		return(out)
	}
	if (cls == "date") {
		out = (hn ? "N=" + _dmv_hidden(hn, mincell) : "N=" + strofreal(nvalid, "%20.0f"))
		if (datesafe) {
			if (missing(dv[13])) return(out + "; exact dates withheld (datesafe)")
			return(out + "; span " + strtrim(strofreal(dv[13], "%20.0g")) + " " +
				_dmv_spanunit(sv[3]) + " (exact dates withheld)")
		}
		if (missing(dv[10]) | missing(dv[11])) return(out)
		df = _dmv_datefmt(sv[3], dfmt)
		return(out + "; range " + _dmv_esc(strtrim(strofreal(dv[10], df))) + " to " +
			_dmv_esc(strtrim(strofreal(dv[11], df))))
	}
	if (cls == "string") {
		out = (hn ? "N=" + _dmv_hidden(hn, mincell) : "N=" + strofreal(nvalid, "%20.0f"))
		if (!missing(dv[3])) out = out + "; " + _dmv_uniq(dv[3], dv[4]) + " distinct"
		if (!missing(dv[12])) out = out + "; max length " + strofreal(dv[12], "%20.0f")
		return(out + _dmv_strprof(dv, sv[10], LS, LD, mincell, hn, nofreq))
	}
	return("")
}

// Appends the table rows to path; see the header.  Runs with the variables
// frame current.
void _dmv_rows(string scalar path, real scalar vf, real scalar vl,
	string scalar levframe, real scalar lf, real scalar ll,
	string scalar cols, real scalar mincell, real scalar maxfreq,
	string scalar dfmt, real scalar nofreq, real scalar nostats,
	real scalar nolabels, real scalar datesafe, | real scalar safe)
{
	string rowvector cl
	string matrix S, LS, LSv
	real matrix D, LD, LDv
	real colvector r, st, len
	real scalar n, i, j, fh, hasvals, li, a, b, nl
	real rowvector mg
	string scalar cur, row, cell, typ, bd
	string colvector out
	transmorphic A

	if (args() < 15) safe = 0
	cl = tokens(cols)
	if (vl < vf) return
	r = (vf::vl)
	n = rows(r)
	S = st_sdata(r, ("variable", "storage_type", "display_format", "class",
		"variable_label", "value_label", "notes", "characteristics",
		"date_family", "date_mask"))
	D = st_data(r, ("N", "missing", "unique", "unique_capped", "mean", "sd",
		"p50", "p25", "p75", "min", "max", "maxlen", "span", "missing_pct",
		"position", "missing_state", "n_state", "numeric_n", "numeric_state",
		"padded_n", "padded_state", "is_strl", "tokens_hidden"))

	// the levels block of this dataset, indexed by variable name: the
	// values cell lists levels, the Missing cell its missing codes
	hasvals = (sum(cl :== "values") > 0) | (sum(cl :== "missing") > 0)
	A = asarray_create()
	asarray_notfound(A, (0, 0))
	nl = 0
	if (hasvals & levframe != "" & lf >= 1 & ll >= lf) {
		cur = st_framecurrent()
		st_framecurrent(levframe)
		LSv = st_sdata((lf::ll), ("variable", "value_str", "label"))
		LDv = st_data((lf::ll), ("value", "count", "share", "suppressed",
			"complementary", "is_missing_code"))
		st_framecurrent(cur)
		nl = rows(LSv)
		st = _dmv_runstarts(LSv[., 1])
		if (rows(st) == 1) len = nl
		else len = (st[|2 \ rows(st)|] \ nl + 1) - st
		// a name has one run per dataset; the first run wins
		for (j = rows(st); j >= 1; j--) asarray(A, LSv[st[j], 1], (st[j], st[j] + len[j] - 1))
	}

	out = J(n, 1, "")
	for (i = 1; i <= n; i++) {
		// this variable's levels rows, then its margins
		LS = J(0, 2, "")
		LD = J(0, 6, .)
		if (nl > 0) {
			a = asarray(A, S[i, 1])
			if (a[1] > 0) {
				LS = LSv[|a[1], 2 \ a[2], 3|]
				LD = LDv[|a[1], 1 \ a[2], 6|]
			}
		}
		// the margins as the collector decided them; an excluded row's
		// Missing count obeys mincell() too (2026-11-10: it printed 1-4)
		mg = ((missing(D[i, 16]) ? 0 : D[i, 16]), (missing(D[i, 17]) ? 0 : D[i, 17]))
		row = "|"
		for (j = 1; j <= cols(cl); j++) {
			cell = ""
			if (cl[j] == "variable") {
				cell = char(96) + S[i, 1] + char(96)
			}
			else if (cl[j] == "label") cell = _dmv_esc(S[i, 5])
			else if (cl[j] == "type") {
				// U4: "double %td daily" (2026-11-10: "double %td",
				// the display format, not its family)
				typ = S[i, 2]
				if (S[i, 9] != "") typ = typ + " " + S[i, 9]
				else if (substr(typ, 1, 3) != "str" & _dmv_isdatefmt(S[i, 3])) typ = typ + " " + S[i, 3]
				cell = _dmv_esc(typ)
			}
			else if (cl[j] == "class") cell = S[i, 4]
			else if (cl[j] == "format") cell = _dmv_esc(S[i, 3])
			else if (cl[j] == "vallabel") cell = _dmv_esc(S[i, 6])
			else if (cl[j] == "missing") {
				// no observations: no share to print (2026-11-10: was "0 (.%)")
				if (D[i, 1] == 0) cell = "0"
				// a part of N below mincell(), or its complement (2026-11-10)
				else if (mg[1]) cell = _dmv_hidden(mg[1], mincell)
				else cell = strofreal(D[i, 2], "%20.0f") + " (" + _dmv_pctc(D[i, 2], D[i, 1]) + "%)"
				// F3: the per-code breakdown, a frequency table of the
				// missing codes: none under nofreq (2026-11-10: printed
				// ".a Refused 55, .b Not asked 35" beside "3 distinct")
				if (D[i, 1] > 0 & !nofreq) {
					bd = _dmv_codes(LS, LD, mincell, nolabels)
					if (bd != "") cell = cell + ": " + bd
				}
			}
			else if (cl[j] == "values") {
				cell = _dmv_values(S[i, .], D[i, .], LS, LD,
					mincell, maxfreq, dfmt, nofreq, nostats, nolabels, datesafe, mg[2], safe)
			}
			else if (cl[j] == "notes") cell = _dmv_brcell(S[i, 7])
			else if (cl[j] == "chars") cell = _dmv_brcell(S[i, 8])
			else if (cl[j] == "unique") cell = _dmv_uniq(D[i, 3], D[i, 4])
			else if (cl[j] == "position") cell = (missing(D[i, 15]) ? "." : strofreal(D[i, 15], "%20.0f"))
			row = row + " " + cell + " |"
		}
		out[i] = row
	}

	fh = _fopen(path, "a")
	if (fh < 0) {
		errprintf("_datamap_md_varrows: cannot open %s (error %g)\n", path, fh)
		exit(603)
	}
	for (i = 1; i <= n; i++) fput(fh, out[i])
	fclose(fh)
}
end

program define _datamap_md_varrows, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , VARFrame(name) VFIRST(integer) VLAST(integer) ///
            COLumns(string) MINCell(integer) MAXFreq(integer) DATEFormat(string) ///
            [LEVFrame(name) LFIRST(integer 0) LLAST(integer 0) ///
            NOFReq NOSTats NOLAbels DATESafe SAFE]
        local _nf = ("`nofreq'" != "")
        local _sf = ("`safe'" != "")
        local _ns = ("`nostats'" != "")
        local _nl = ("`nolabels'" != "")
        local _ds = ("`datesafe'" != "")
        frame `varframe': mata: _dmv_rows(st_local("using"), `vfirst', `vlast', ///
            "`levframe'", `lfirst', `llast', "`columns'", `mincell', `maxfreq', ///
            st_local("dateformat"), `_nf', `_ns', `_nl', `_ds', `_sf')
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
