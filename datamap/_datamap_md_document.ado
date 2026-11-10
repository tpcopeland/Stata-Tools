*! _datamap_md_document Version 2.0.0  2026/11/10
*! datamap's Markdown document, rendered from the collector frames
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_md_document using file, dsframe(f) varframe(f) levframe(f)
//     dslist(numlist) columns(list) mincell(#) maxfreq(#) dateformat(fmt)
//     [append toc docmode separate title() subtitle() version() author()
//     docdate() notes() changelog() nofreq nostats nolabels datesafe quality
//     linkage]
//
// Writes the datasets in dslist (rows of the datasets frame) to `file' as
// one Markdown document; `file' is datamap's stage, copied over the output
// by the caller.  It reads the three collector frames and nothing else: the
// data are not in memory here (several datasets are rendered after all were
// collected).
//
// Layout:
//   docmode   # title (": <dataset>" under separate), subtitle, Version
//   toc       ## Contents: one link per dataset (_datamap_md_anchor), then
//             Notes and Change Log when given (docmode)
//   each dataset
//             ## <i>. <name>, then bullets: source (and, for the data in
//             memory, its file and whether it changed since), label,
//             observations, variables, sort order, the declared state
//             (xtset/tsset, stset, svyset, mi set, dataset notes; F2,
//             _dmd_state), data signature, disclosure; then
//             ### Variables with the table (_datamap_md_tablehead,
//             _datamap_md_varrows); ### Flags under quality; the fragments
//             collected with the data (_datamap_md_sections) under
//             ### Structure (inferred), ### Missingness, ### Sample rows.
//             Declared settings print as declared, in the header; what
//             detect() finds from names and values is "inferred"
//             (2026-11-10: the heading read "detected")
//             Under quality, ### Flags is followed by ### Candidates (not
//             applied): the placeholder candidates (F5, 2026-11-10)
//   linkage   ## Linkage, after the dataset sections, for two or more
//             datasets (F1, 2026-11-10; _dmd_linkage); a Contents line
//   docmode   ## Notes, ## Change Log (each when given;
//             _datamap_md_textblock), then the footer: Document Version,
//             Author, Last Updated (docdate())
// append: the file is appended to (dataset sections only; the caller refuses
// the document options with append), the section numbers continuing from
// the file's last "## <n>. " heading; otherwise it is truncated first.
// The document options arrive as datamap transports them
// (_datamap_transport_encode) and are decoded and escaped here, in Mata.

capture mata: mata drop _dmd_esc()
capture mata: mata drop _dmd_codespan()
capture mata: mata drop _dmd_unquote()
capture mata: mata drop _dmd_decode()
capture mata: mata drop _dmd_opt()
capture mata: mata drop _dmd_lastsec()
capture mata: mata drop _dmd_put()
capture mata: mata drop _dmd_dsname()
capture mata: mata drop _dmd_title()
capture mata: mata drop _dmd_tocline()
capture mata: mata drop _dmd_dshead()
capture mata: mata drop _dmd_names()
capture mata: mata drop _dmd_namesex()
capture mata: mata drop _dmd_state()
capture mata: mata drop _dmd_dstail()
capture mata: mata drop _dmd_footer()
capture mata: mata drop _dmd_lkpair()
capture mata: mata drop _dmd_linkage()
mata:
string scalar _dmd_esc(string scalar text)
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
// text as a code span, verbatim (a code span decodes no escape); a backtick
// in the text takes a double-backtick fence
string scalar _dmd_codespan(string scalar text)
{
	text = subinstr(subinstr(text, char(10), " "), char(13), " ")
	if (strpos(text, char(96)) == 0) return(char(96) + text + char(96))
	return(char(96) + char(96) + " " + text + " " + char(96) + char(96))
}
string scalar _dmd_unquote(string scalar value)
{
	real scalar n
	n = strlen(value)
	while (n >= 4 & substr(value, 1, 2) == char(96) + char(34) &
		substr(value, n - 1, 2) == char(34) + char(39)) {
		value = substr(value, 3, n - 4)
		n = strlen(value)
	}
	return(value)
}
string scalar _dmd_decode(string scalar text)
{
	string scalar p
	p = "__DATAMAP_68F73A__"
	text = subinstr(text, p + "D", char(36))
	text = subinstr(text, p + "T", char(96))
	text = subinstr(text, p + "N", char(10))
	text = subinstr(text, p + "R", char(13))
	text = subinstr(text, p + "P", p)
	return(text)
}
// a document option, decoded and escaped
string scalar _dmd_opt(string scalar loc)
{
	return(_dmd_esc(_dmd_decode(_dmd_unquote(st_local(loc)))))
}
// The largest dataset-section number already in path ("## <n>. " at the
// start of a line), 0 when there is none or no file.  append continues the
// numbering from it (2026-11-10: it restarted at 1, so an appended section
// repeated the first heading and its anchor).  fget() hands back a line
// longer than its buffer in pieces; a piece after a full-length one is the
// rest of that line, never a heading.
real scalar _dmd_lastsec(string scalar path)
{
	real scalar fh, mx, n, cont
	string scalar ln, d
	mx = 0
	if (!fileexists(path)) return(0)
	fh = _fopen(path, "r")
	if (fh < 0) return(0)
	cont = 0
	while ((ln = fget(fh)) != J(0, 0, "")) {
		if (!cont & substr(ln, 1, 3) == "## ") {
			d = substr(ln, 4, .)
			n = 0
			while (n < strlen(d) & strpos("0123456789", substr(d, n + 1, 1))) n++
			if (n > 0 & n <= 15 & substr(d, n + 1, 2) == ". ") {
				mx = max((mx, strtoreal(substr(d, 1, n))))
			}
		}
		cont = (strlen(ln) >= 32768)
	}
	fclose(fh)
	return(mx)
}
// append lines L to path (mode "a"), or truncate it first (mode "w")
void _dmd_put(string scalar path, string colvector L, string scalar mode)
{
	real scalar fh, i
	fh = _fopen(path, mode)
	if (fh < 0) {
		errprintf("_datamap_md_document: cannot open %s (error %g)\n", path, fh)
		exit(603)
	}
	for (i = 1; i <= rows(L); i++) fput(fh, L[i])
	fclose(fh)
}
// the heading name of datasets-frame row r (current frame), unescaped
string scalar _dmd_dsname(real scalar r)
{
	if (_st_sdata(r, st_varindex("source")) == "memory") return("Data in memory")
	return(_st_sdata(r, st_varindex("dataset")))
}
// title block; sep > 0: the row of the one dataset of a separate file
void _dmd_title(string scalar path, real scalar sep)
{
	string colvector L
	string scalar t
	t = _dmd_opt("title")
	if (t == "") t = "Data Dictionary"
	if (sep > 0) t = t + ": " + _dmd_esc(_dmd_dsname(sep))
	L = ("# " + t) \ ""
	if (_dmd_opt("subtitle") != "") L = L \ _dmd_opt("subtitle") \ ""
	if (_dmd_opt("version") != "") L = L \ ("Version " + _dmd_opt("version")) \ ""
	_dmd_put(path, L, "a")
}
// one Contents line: dataset row r at position i, anchor in local anc
void _dmd_tocline(string scalar path, real scalar r, real scalar i, string scalar anc)
{
	_dmd_put(path, strofreal(i, "%20.0f") + ". [" + _dmd_esc(_dmd_dsname(r)) +
		"](#" + st_local(anc) + ")", "a")
}
// names (space-separated) as code spans joined by ", "
string scalar _dmd_names(string scalar s)
{
	string rowvector t
	t = tokens(s)
	if (cols(t) == 0) return("")
	return(invtokens(char(96) :+ t :+ char(96), ", "))
}
// 1 when text names one of the variables in ex as a whole word: a declared
// setting's values (a failure code, an if() or origin() expression) are
// withheld when they name an excluded variable
real scalar _dmd_namesex(string scalar text, string rowvector ex)
{
	real scalar j
	for (j = 1; j <= cols(ex); j++) {
		if (regexm(text, "(^|[^A-Za-z0-9_])" + ex[j] + "($|[^A-Za-z0-9_])")) return(1)
	}
	return(0)
}
// The declared-state bullets of datasets-frame row r (current frame): the
// settings as declared, read from the characteristics at collection
// (_datamap_collect_dataset).  Variable names print as code spans and
// expressions verbatim as code spans; a value that names an excluded
// variable (ex) is withheld.
string colvector _dmd_state(real scalar r)
{
	string colvector L
	string rowvector ex
	string scalar p, t, ln, fv, x
	real scalar j
	string rowvector nt

	L = J(0, 1, "")
	ex = tokens(_st_sdata(r, st_varindex("excluded_all")))
	p = _st_sdata(r, st_varindex("ts_panel"))
	t = _st_sdata(r, st_varindex("ts_time"))
	if (p != "" | t != "") {
		ln = "- Declared " + (p != "" ? "xtset: panel " + _dmd_names(p) : "tsset:")
		if (t != "") {
			ln = ln + (p != "" ? "; time " : " time ") + _dmd_names(t)
			x = _st_sdata(r, st_varindex("ts_fmt"))
			if (x != "") ln = ln + " (" + _dmd_esc(x) + ")"
			x = _st_sdata(r, st_varindex("ts_delta"))
			if (x != "") ln = ln + "; delta " + _dmd_esc(x)
		}
		else ln = ln + "; no time variable"
		L = L \ ln
	}
	t = _st_sdata(r, st_varindex("st_time"))
	if (t != "") {
		ln = "- Declared stset: time " + _dmd_names(t)
		x = _st_sdata(r, st_varindex("st_t0"))
		if (x != "") ln = ln + "; entry time " + _dmd_names(x)
		x = _st_sdata(r, st_varindex("st_id"))
		if (x != "") ln = ln + "; id " + _dmd_names(x)
		x = _st_sdata(r, st_varindex("st_fail"))
		fv = _st_sdata(r, st_varindex("st_failval"))
		if (x == "") ln = ln + "; failure: none declared (every record ends in failure)"
		else {
			ln = ln + "; failure " + _dmd_names(x)
			if (_dmd_namesex(x, ex)) ln = ln + " (values withheld: excluded)"
			else if (fv != "") ln = ln + " == " + _dmd_esc(fv)
			else ln = ln + " (nonzero, nonmissing)"
		}
		nt = ("st_origin", "st_enter", "st_exit", "st_if")
		for (j = 1; j <= cols(nt); j++) {
			x = _st_sdata(r, st_varindex(nt[j]))
			if (x == "") continue
			ln = ln + "; " + substr(nt[j], 4, .) + " "
			if (_dmd_namesex(x, ex)) ln = ln + "withheld (names an excluded variable)"
			else ln = ln + _dmd_codespan(x)
		}
		x = _st_sdata(r, st_varindex("st_scale"))
		if (x != "" & x != "1") ln = ln + "; scale " + _dmd_esc(x)
		x = _st_sdata(r, st_varindex("st_weight"))
		if (x != "") ln = ln + "; weight " + _dmd_codespan(x)
		L = L \ ln
	}
	x = _st_sdata(r, st_varindex("svy_settings"))
	if (x != "") L = L \ ("- Declared svyset: " + _dmd_codespan(x))
	x = _st_sdata(r, st_varindex("mi_style"))
	if (x != "") {
		ln = "- Declared mi set: style " + _dmd_esc(x)
		x = _st_sdata(r, st_varindex("mi_m"))
		if (x != "") ln = ln + "; M = " + _dmd_esc(x)
		x = _st_sdata(r, st_varindex("mi_ivars"))
		ln = ln + "; imputed " + (x == "" ? "none" : _dmd_names(x))
		x = _st_sdata(r, st_varindex("mi_pvars"))
		if (x != "") ln = ln + "; passive " + _dmd_names(x)
		L = L \ ln
	}
	x = _st_sdata(r, st_varindex("dta_notes"))
	if (x != "") {
		L = L \ "- Dataset notes:"
		nt = tokens(x, char(10))
		for (j = 1; j <= cols(nt); j++) {
			if (nt[j] != char(10)) L = L \ ("  - " + _dmd_esc(nt[j]))
		}
	}
	return(L)
}
// dataset heading and bullets; runs with the datasets frame current
void _dmd_dshead(string scalar path, real scalar r, real scalar i,
	string scalar varframe, real scalar mincell, real scalar datesafe)
{
	string colvector L, ex
	string scalar src, lab, sl, sig, sug, cur, ln, fn
	real scalar N, k, kd, vf, vl, chg
	string rowvector t

	src = _st_sdata(r, st_varindex("source"))
	lab = _st_sdata(r, st_varindex("label"))
	sl = _st_sdata(r, st_varindex("sortlist"))
	sig = _st_sdata(r, st_varindex("datasignature"))
	sug = _st_sdata(r, st_varindex("suggested"))
	N = _st_data(r, st_varindex("N"))
	k = _st_data(r, st_varindex("nvars"))
	kd = _st_data(r, st_varindex("nvars_doc"))
	vf = _st_data(r, st_varindex("vfirst"))
	vl = _st_data(r, st_varindex("vlast"))

	// the excluded variables among the documented rows
	ex = J(0, 1, "")
	if (vf >= 1 & vl >= vf) {
		cur = st_framecurrent()
		st_framecurrent(varframe)
		ex = st_sdata((vf::vl), "variable")
		ex = select(ex, st_sdata((vf::vl), "class") :== "excluded")
		st_framecurrent(cur)
	}

	L = ("## " + strofreal(i, "%20.0f") + ". " + _dmd_esc(_dmd_dsname(r))) \ ""
	if (src == "memory") {
		L = L \ "- Source: data in memory"
		// the data in memory: the file Stata last used or saved for them
		// (c(filename)) and whether they changed since (c(changed))
		fn = _st_sdata(r, st_varindex("filename"))
		chg = _st_data(r, st_varindex("changed"))
		if (fn == "") ln = "- File: none (not used from or saved to a file)"
		else ln = "- File: " + _dmd_codespan(fn) + "; " +
			(chg ? "changed since it was last used or saved" : "unchanged since it was last used or saved")
		L = L \ ln
	}
	else L = L \ ("- Source: " + _dmd_codespan(src))
	if (lab != "" & lab != ".") L = L \ ("- Label: " + _dmd_esc(lab))
	L = L \ ("- Observations: " + strofreal(N, "%20.0f"))
	ln = "- Variables: " + strofreal(k, "%20.0f")
	if (!missing(kd) & kd != k) ln = ln + " (" + strofreal(kd, "%20.0f") + " documented)"
	L = L \ ln
	if (sl != "") {
		t = tokens(sl)
		L = L \ ("- Sort order: " + invtokens(char(96) :+ t :+ char(96), ", "))
	}
	L = L \ _dmd_state(r)
	if (sig != "") L = L \ ("- Data signature: " + _dmd_codespan(sig))
	ln = "- Disclosure: " + strofreal(rows(ex)) + " excluded"
	if (rows(ex)) ln = ln + " (" + invtokens(char(96) :+ ex' :+ char(96), ", ") + ")"
	if (mincell > 0) ln = ln + "; cells below " + strofreal(mincell) + " suppressed"
	else ln = ln + "; small-cell suppression off"
	ln = ln + "; date-safe " + (datesafe ? "on" : "off")
	t = tokens(sug)
	if (cols(t)) ln = ln + "; likely identifiers not excluded: " +
		invtokens(char(96) :+ t :+ char(96), ", ")
	else ln = ln + "; likely identifiers not excluded: none"
	L = L \ ln \ "" \ "### Variables" \ ""
	_dmd_put(path, L, "a")
}
// after the table: flags (quality), then the collected fragments; runs with
// the datasets frame current
void _dmd_dstail(string scalar path, real scalar r, string scalar varframe,
	real scalar quality)
{
	string colvector L, nm, qf
	string scalar cur, s
	real scalar vf, vl, j, q

	L = ""
	vf = _st_data(r, st_varindex("vfirst"))
	vl = _st_data(r, st_varindex("vlast"))
	if (quality) {
		L = L \ "### Flags" \ ""
		j = 0
		if (vf >= 1 & vl >= vf) {
			cur = st_framecurrent()
			st_framecurrent(varframe)
			nm = st_sdata((vf::vl), "variable")
			qf = st_sdata((vf::vl), "quality_flag")
			st_framecurrent(cur)
			for (q = 1; q <= rows(nm); q++) {
				if (qf[q] == "") continue
				L = L \ ("- " + char(96) + nm[q] + char(96) + ": " + _dmd_esc(qf[q]))
				j++
			}
		}
		if (j == 0) L = L \ "No quality flags."
		L = L \ ""
		// F5 (2026-11-10): placeholder candidates, collected under quality
		// (_datamap_collect_cands); listed, never applied
		L = L \ "### Candidates (not applied)" \ ""
		j = 0
		if (vf >= 1 & vl >= vf) {
			cur = st_framecurrent()
			st_framecurrent(varframe)
			qf = st_sdata((vf::vl), "candidates")
			st_framecurrent(cur)
			for (q = 1; q <= rows(nm); q++) {
				if (qf[q] == "") continue
				// generated text (numbers, dates, fixed words): escaped,
				// with the "(<m)" of a withheld count kept as written
				L = L \ ("- " + char(96) + nm[q] + char(96) + ": " +
					subinstr(_dmd_esc(qf[q]), "(&lt;", "(<"))
				j++
			}
		}
		if (j == 0) L = L \ "No placeholder candidates."
		L = L \ ""
	}
	s = _st_sdata(r, st_varindex("structure"))
	if (s != "") L = L \ "### Structure (inferred)" \ "" \ s \ ""
	s = _st_sdata(r, st_varindex("missingness"))
	if (s != "") L = L \ "### Missingness" \ "" \ s \ ""
	s = _st_sdata(r, st_varindex("samples"))
	if (s != "") L = L \ "### Sample rows" \ "" \ s \ ""
	_dmd_put(path, L, "a")
}
// The merge type of a merge of dataset a (master) with b (using) on one
// variable, from its key flag in each (1 unique, 0 not)
string scalar _dmd_lkpair(real scalar ka, real scalar kb)
{
	if (ka == 1 & kb == 1) return("1:1")
	if (ka == 1 & kb == 0) return("1:m")
	if (ka == 0 & kb == 1) return("m:1")
	if (ka == 0 & kb == 0) return("m:m")
	return("not determined")
}
// The linkage block (F1, 2026-11-10) of the datasets in rows R of the
// datasets frame (current): every variable name two or more of them share,
// its storage type and uniqueness (the variables frame's key) in each, the
// merge type a merge on that variable alone implies, and a type conflict
// (numeric in one, string in another; str widths and strL are not); then
// the value labels of the same name defined differently.  No value and no
// count is printed.  A variable excluded in any dataset has its uniqueness
// and merge type withheld (they are statistics of it); its name and types
// are structure, printed in the variable tables too.
void _dmd_linkage(string scalar path, real rowvector R, string scalar varframe,
	real scalar i0)
{
	string colvector L, nm, vlab, NM, TY
	string matrix S
	real colvector DJ, KY, EX, o, st, len, GS, GL, GF, gi
	real scalar n, j, l, i, vf, vl, r, a, k, nn, u, isn, iss, ex, np, q
	string scalar cur, ln, typ, un, mg, fl, dsn
	string rowvector ds, vn, vd, groups, dsn0
	real rowvector kk
	transmorphic B

	n = cols(R)
	// the dataset names; the source path when two share a name; a file
	// listed twice (one path) its section number too.  The clashes are
	// found on the names before any is replaced (2026-11-10: replacing
	// in place left the last of a pair unclashed, and a file listed twice
	// read as "f3.dta" and "f3", two datasets)
	ds = J(1, n, "")
	for (j = 1; j <= n; j++) ds[j] = _dmd_dsname(R[j])
	dsn0 = ds
	for (j = 1; j <= n; j++) {
		if (sum(dsn0 :== dsn0[j]) > 1) ds[j] = _st_sdata(R[j], st_varindex("source"))
	}
	dsn0 = ds
	for (j = 1; j <= n; j++) {
		if (sum(dsn0 :== dsn0[j]) > 1) ds[j] = dsn0[j] + " (section " + strofreal(i0 + j, "%20.0f") + ")"
	}
	for (j = 1; j <= n; j++) ds[j] = _dmd_esc(ds[j])

	// every (dataset, variable) row in one set of columns, in dataset and
	// then table order, grouped by name with one sort (2026-11-10: an
	// asarray of names and a name x dataset matrix slowed every later
	// datamap run in the session by about 10% on 15 x 2,000 variables)
	np = 0
	for (j = 1; j <= n; j++) {
		vf = _st_data(R[j], st_varindex("vfirst"))
		vl = _st_data(R[j], st_varindex("vlast"))
		if (!missing(vf) & !missing(vl) & vf >= 1 & vl >= vf) np = np + vl - vf + 1
	}
	NM = J(np, 1, "")
	TY = J(np, 1, "")
	DJ = J(np, 1, .)
	KY = J(np, 1, .)
	EX = J(np, 1, 0)
	q = 0
	cur = st_framecurrent()
	for (j = 1; j <= n; j++) {
		vf = _st_data(R[j], st_varindex("vfirst"))
		vl = _st_data(R[j], st_varindex("vlast"))
		if (missing(vf) | missing(vl) | vf < 1 | vl < vf) continue
		st_framecurrent(varframe)
		S = st_sdata((vf::vl), ("variable", "storage_type", "class"))
		r = rows(S)
		NM[|q + 1 \ q + r|] = S[., 1]
		TY[|q + 1 \ q + r|] = S[., 2]
		EX[|q + 1 \ q + r|] = (S[., 3] :== "excluded")
		KY[|q + 1 \ q + r|] = st_data((vf::vl), "key")
		DJ[|q + 1 \ q + r|] = J(r, 1, j)
		st_framecurrent(cur)
		q = q + r
	}
	// the names in two or more datasets: runs of the sorted names, each
	// run's rows in table order (row numbers rise with the dataset), the
	// runs in order of first appearance
	GS = J(0, 1, .)
	GL = J(0, 1, .)
	if (np >= 2) {
		o = order(NM, 1)
		st = selectindex(1 \ (NM[o[|2 \ np|]] :!= NM[o[|1 \ np - 1|]]))
		len = (rows(st) == 1 ? np : (st[|2 \ rows(st)|] \ np + 1) - st)
		st = select(st, len :>= 2)
		len = select(len, len :>= 2)
		if (rows(st)) {
			GF = J(rows(st), 1, .)
			for (a = 1; a <= rows(st); a++) GF[a] = min(o[|st[a] \ st[a] + len[a] - 1|])
			gi = order(GF, 1)
			GS = st[gi]
			GL = len[gi]
		}
	}

	L = ("## Linkage" \ "" \ "Variable names in two or more datasets. Unique: the values identify the observations, missing values counted as values, as " + char(96) + "merge" + char(96) + " counts them. Merge: the type a merge on that variable alone implies (master first)." \ "")
	nn = rows(GS)
	if (nn) L = L \ "| Variable | Datasets | Type | Unique | Merge | Flags |" \ "|---|---|---|---|---|---|"
	for (a = 1; a <= nn; a++) {
		gi = sort(o[|GS[a] \ GS[a] + GL[a] - 1|], 1)
		vn = ds[DJ[gi]']
		vd = TY[gi]'
		kk = KY[gi]'
		k = cols(vn)
		ex = (sum(EX[gi]) > 0)
		// numeric vs string: the only type conflict
		iss = sum(substr(vd, 1, 3) :== "str")
		isn = k - iss
		ln = "| " + char(96) + NM[gi[1]] + char(96) + " | "
		ln = ln + (k == n & n > 4 ? "all " + strofreal(n) : invtokens(vn, ", ")) + " | "
		if (sum(vd :== vd[1]) == k) typ = _dmd_esc(vd[1])
		else {
			typ = ""
			for (j = 1; j <= k; j++) typ = typ + (j > 1 ? "; " : "") + vn[j] + " " + _dmd_esc(vd[j])
		}
		ln = ln + typ + " | "
		if (ex) {
			un = "withheld (excluded)"
			mg = "withheld (excluded)"
		}
		else {
			if (sum(kk :== kk[1]) == k) {
				un = (kk[1] == 1 ? "yes" : (kk[1] == 0 ? "no" : "not determined"))
				un = un + (k == 2 ? " in both" : " in all")
			}
			else {
				un = ""
				for (j = 1; j <= k; j++) un = un + (j > 1 ? "; " : "") + vn[j] + " " +
					(kk[j] == 1 ? "yes" : (kk[j] == 0 ? "no" : "not determined"))
			}
			if (iss > 0 & isn > 0 & k == 2) mg = "cannot merge: numeric and string"
			else if (k <= 4) {
				// each pair; a numeric-string pair cannot merge
				mg = ""
				for (j = 1; j <= k; j++) {
					for (l = j + 1; l <= k; l++) {
						mg = mg + (mg == "" ? "" : "; ") + vn[j] + " " +
							((substr(vd[j], 1, 3) == "str") != (substr(vd[l], 1, 3) == "str") ?
							"cannot merge (numeric and string)" : _dmd_lkpair(kk[j], kk[l])) + " " + vn[l]
					}
				}
			}
			else if (iss > 0 & isn > 0) mg = "cannot merge a numeric with a string dataset; see Type"
			else {
				u = sum(kk :== 1)
				if (missing(sum(kk))) mg = "not determined in some datasets"
				else if (u == k) mg = "1:1 between any two"
				else if (u == 0) mg = "m:m between any two (unique in none)"
				// one unique dataset has no 1:1 partner, and one
				// non-unique dataset has no m:m partner (2026-11-10)
				else if (u == 1) mg = "1:m from " + invtokens(select(vn, kk :== 1), ", ") +
					" to any other; m:m among the others"
				else if (k - u == 1) mg = "1:1 among " + invtokens(select(vn, kk :== 1), ", ") +
					"; 1:m from one of them to " + invtokens(select(vn, kk :== 0), ", ")
				else mg = "1:1 among " + invtokens(select(vn, kk :== 1), ", ") +
					"; 1:m from one of them to any other; m:m among the others"
			}
		}
		fl = ""
		if (iss > 0 & isn > 0) {
			fl = "type conflict: numeric in " + invtokens(select(vn, substr(vd, 1, 3) :!= "str"), ", ") +
				"; string in " + invtokens(select(vn, substr(vd, 1, 3) :== "str"), ", ")
		}
		L = L \ (ln + un + " | " + mg + " | " + fl + " |")
	}
	if (nn == 0) L = L \ "No variable name occurs in two or more datasets."
	L = L \ ""

	// value labels: name -> the datasets defining it and their definitions
	B = asarray_create()
	vlab = J(0, 1, "")
	for (j = 1; j <= n; j++) {
		nm = tokens(_st_sdata(R[j], st_varindex("vl_names")))'
		if (rows(nm) == 0) continue
		// one definition per name, split at char(29) (an empty definition
		// is an empty piece)
		groups = J(1, rows(nm), "")
		dsn = _st_sdata(R[j], st_varindex("vl_defs"))
		for (q = 1; q <= cols(groups); q++) {
			i = strpos(dsn, char(29))
			if (i == 0) {
				groups[q] = dsn
				dsn = ""
			}
			else {
				groups[q] = substr(dsn, 1, i - 1)
				dsn = substr(dsn, i + 1, .)
			}
		}
		for (i = 1; i <= rows(nm); i++) {
			if (!asarray_contains(B, nm[i])) {
				vlab = vlab \ nm[i]
				asarray(B, nm[i], J(0, 2, ""))
			}
			asarray(B, nm[i], asarray(B, nm[i]) \ (ds[j], groups[i]))
		}
	}
	np = 0
	for (i = 1; i <= rows(vlab); i++) {
		S = asarray(B, vlab[i])
		// the datasets defining the label (one row each)
		if (sum(S[., 1] :!= "") < 2) continue
		if (sum(S[., 2] :== S[1, 2]) == rows(S)) continue
		if (np == 0) L = L \ "Value labels with the same name and different definitions (" + char(96) + "merge" + char(96) + " keeps the master's):" \ ""
		np++
		// the datasets grouped by definition
		dsn = ""
		vn = J(1, 0, "")
		for (r = 1; r <= rows(S); r++) {
			if (sum(vn :== S[r, 2])) continue
			vn = vn, S[r, 2]
			dsn = dsn + (dsn == "" ? "" : " | ") + invtokens(select(S[., 1], S[., 2] :== S[r, 2])', ", ")
		}
		L = L \ ("- " + char(96) + vlab[i] + char(96) + ": " + strofreal(cols(vn)) +
			" definitions (" + dsn + ")")
	}
	if (np == 0) L = L \ "No value label is defined differently in two datasets."
	L = L \ ""
	_dmd_put(path, L, "a")
}
void _dmd_footer(string scalar path)
{
	string colvector L
	L = J(0, 1, "")
	if (_dmd_opt("version") != "") L = L \ ("**Document Version:** " + _dmd_opt("version")) \ ""
	if (_dmd_opt("author") != "") L = L \ ("**Author:** " + _dmd_opt("author")) \ ""
	L = L \ ("**Last Updated:** " + _dmd_opt("docdate"))
	_dmd_put(path, L, "a")
}
end

program define _datamap_md_document, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , DSFrame(name) VARFrame(name) LEVFrame(name) ///
            DSList(numlist integer >0) COLumns(string) MINCell(integer) ///
            MAXFreq(integer) DATEFormat(string) ///
            [APPend TOC DOCmode SEParate TItle(string asis) ///
            SUBTitle(string asis) VERsion(string asis) AUTHor(string asis) ///
            DOCDate(string asis) NOTEs(string asis) CHANGElog(string asis) ///
            NOFReq NOSTats NOLAbels DATESafe QUALity LINKage SAFE]

        local _ds = ("`datesafe'" != "")
        local _q = ("`quality'" != "")
        local _nds : word count `dslist'

        // a fresh document, or the existing one (append), whose section
        // numbers the appended sections continue
        local _i0 = 0
        if "`append'" == "" mata: _dmd_put(st_local("using"), J(0, 1, ""), "w")
        else mata: st_local("_i0", strofreal(_dmd_lastsec(st_local("using")), "%20.0f"))

        if "`docmode'" != "" {
            local _sep = 0
            if "`separate'" != "" & `_nds' == 1 local _sep = `dslist'
            frame `dsframe': mata: _dmd_title(st_local("using"), `_sep')
        }

        mata: st_local("_hasnotes", strofreal(_dmd_opt("notes") != ""))
        mata: st_local("_haschlog", strofreal(_dmd_opt("changelog") != ""))
        if "`docmode'" == "" {
            local _hasnotes = 0
            local _haschlog = 0
        }

        if "`toc'" != "" {
            mata: _dmd_put(st_local("using"), "## Contents" \ "", "a")
            local i = 0
            foreach dsx of local dslist {
                local ++i
                _datamap_md_anchor, frame(`dsframe') row(`dsx') index(`i')
                local _anc "`r(anchor)'"
                frame `dsframe': mata: _dmd_tocline(st_local("using"), `dsx', `i', "_anc")
            }
            if "`linkage'" != "" & `_nds' >= 2 {
                local ++i
                mata: _dmd_put(st_local("using"), "`i'. [Linkage](#linkage)", "a")
            }
            if `_hasnotes' {
                local ++i
                mata: _dmd_put(st_local("using"), "`i'. [Notes](#notes)", "a")
            }
            if `_haschlog' {
                local ++i
                mata: _dmd_put(st_local("using"), "`i'. [Change Log](#change-log)", "a")
            }
            mata: _dmd_put(st_local("using"), "", "a")
        }

        local _rowopt ""
        foreach _o in nofreq nostats nolabels datesafe safe {
            if "``_o''" != "" local _rowopt "`_rowopt' `_o'"
        }
        local i = `_i0'
        foreach dsx of local dslist {
            local ++i
            frame `dsframe' {
                local _vf = vfirst[`dsx']
                local _vl = vlast[`dsx']
                local _lf = lfirst[`dsx']
                local _ll = llast[`dsx']
                mata: _dmd_dshead(st_local("using"), `dsx', `i', "`varframe'", ///
                    `mincell', `_ds')
            }
            foreach _x in _vf _vl _lf _ll {
                if missing(``_x'') local `_x' = 0
            }
            _datamap_md_tablehead using `"`using'"', columns(`columns')
            _datamap_md_varrows using `"`using'"', varframe(`varframe') ///
                vfirst(`_vf') vlast(`_vl') levframe(`levframe') ///
                lfirst(`_lf') llast(`_ll') columns(`columns') ///
                mincell(`mincell') maxfreq(`maxfreq') ///
                dateformat(`"`dateformat'"') `_rowopt'
            frame `dsframe': mata: _dmd_dstail(st_local("using"), `dsx', ///
                "`varframe'", `_q')
        }

        // F1: the linkage block, after the dataset sections
        if "`linkage'" != "" & `_nds' >= 2 {
            local _dsl : subinstr local dslist " " ",", all
            frame `dsframe': mata: _dmd_linkage(st_local("using"), (`_dsl'), "`varframe'", `_i0')
        }

        if "`docmode'" != "" {
            if `_hasnotes' {
                mata: _dmd_put(st_local("using"), "## Notes" \ "", "a")
                _datamap_md_textblock using `"`using'"', text(`"`macval(notes)'"')
                mata: _dmd_put(st_local("using"), "", "a")
            }
            if `_haschlog' {
                mata: _dmd_put(st_local("using"), "## Change Log" \ "", "a")
                _datamap_md_textblock using `"`using'"', text(`"`macval(changelog)'"')
                mata: _dmd_put(st_local("using"), "", "a")
            }
            mata: _dmd_footer(st_local("using"))
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
