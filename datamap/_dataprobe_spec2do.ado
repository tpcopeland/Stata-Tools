*! _dataprobe_spec2do Version 2.0.0  2026/11/10
*! dataprobe makespec(file.do): the starter spec as one dataprobe command
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// 2.0.0 (I1).  The rows makespec() builds (frame `frame': gate, var, arg1,
// arg2, values) written as the equivalent command, so the gates live in
// code that can be read, edited and diffed:
//
//   dataprobe, gatesonly ///
//       expectn(3000 3000) ///
//       isid(lopnr) ///
//       require(lopnr edu sex) ///
//       inrange(bmi 20 999 \ ///
//           age 20 99) ///
//       allowed(sex 1 2)
//
// Run on the data it was made from, it passes; a gate that fails exits 9.
// The entries are the ones checks() reads from the .dta spec: numbers at
// full precision, string levels in double quotes (makespec() gives no
// allowed() row to a level holding a double quote, a backtick, a dollar sign
// or a backslash).  A row whose text holds a line break, or any character
// a do-file would expand, is left out with a comment saying so, and so is
// the allowed() entry of a string variable with a level holding a space
// (a typed allowed() value list loses its quotes, so the level would split).  The
// dataset name is written into the header comment with every character
// other than letters, digits, space and ._-() removed.
program define _dataprobe_spec2do, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FRame(name) FILE(string) [REPLACE DATAset(string) SCOPED(integer 0)]
        _datamap_version dataprobe
        local _ver "`r(version)'"
        mata: _dp_spec2do("`frame'", st_local("file"), "`replace'" != "", ///
            st_local("dataset"), "`_ver'", `scoped')
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _dp_spec2do()
capture mata: mata drop _dp_s2d_safe()
mata:
// 1 when s can be written into a do-file line as is: no line break, no
// backtick, no dollar sign, no comment opener
real scalar _dp_s2d_safe(string scalar s)
{
	return(!(strpos(s, char(10)) | strpos(s, char(13)) | strpos(s, char(96)) |
		strpos(s, "$") | strpos(s, "/*") | strpos(s, "*/") | strpos(s, "//")))
}
void _dp_spec2do(string scalar fr, string scalar fn, real scalar rep,
	string scalar ds, string scalar ver, real scalar scoped)
{
	string colvector G, V, A1, A2, VA
	string rowvector L, req, inr, alw
	string scalar cur, e, nm, line
	real scalar i, fh, j, nskip
	cur = st_framecurrent()
	st_framecurrent(fr)
	G = st_sdata(., "gate")
	V = st_sdata(., "var")
	A1 = st_sdata(., "arg1")
	A2 = st_sdata(., "arg2")
	VA = st_sdata(., "values")
	st_framecurrent(cur)

	nm = ""
	for (i = 1; i <= strlen(ds); i++) {
		e = substr(ds, i, 1)
		if (regexm(e, "^[A-Za-z0-9 ._()-]$")) nm = nm + e
	}
	L = J(1, 0, "")
	L = L, "* dataprobe makespec() (datamap " + ver + "), " +
		strofreal(date(c("current_date"), "DMY"), "%tdCCYY-NN-DD") +
		(nm != "" ? ": the gates observed on " + nm : ": the gates observed on the data")
	L = L, "* Run on the data in memory: it passes on that data and exits 9 when a gate fails."
	if (scoped) L = L, "* Made on an if/in subsample: run it on the same rows."
	line = "dataprobe, gatesonly"
	req = inr = alw = J(1, 0, "")
	nskip = 0
	for (i = 1; i <= rows(G); i++) {
		if (G[i] == "expectn") e = "expectn(" + strtrim(A1[i] + " " + A2[i]) + ")"
		else if (G[i] == "isid") e = "isid(" + VA[i] + ")"
		else if (G[i] == "require") e = ""
		else if (G[i] == "inrange") e = V[i] + " " + A1[i] + " " + A2[i]
		else if (G[i] == "allowed") e = V[i] + " " + VA[i]
		else continue
		if (!_dp_s2d_safe(e + (G[i] == "require" ? VA[i] : ""))) {
			nskip++
			L = L, "* " + G[i] + "(): an entry for " + (V[i] != "" ? V[i] : "the variables") +
				" was left out (its text cannot be written into a do-file)"
			continue
		}
		// a string level holding a space: allowed() typed on a command
		// line reads its value list without the quotes (syntax, string),
		// so "de f" would be two levels; the .dta spec carries it
		if (G[i] == "allowed" & substr(VA[i], 1, 1) == char(34)) {
			if (strpos(subinstr(VA[i], char(34) + " " + char(34), char(1)), " ")) {
				nskip++
				L = L, "* allowed(): " + V[i] + " was left out (a level holds a space, which a typed value list cannot carry; makespec() to a .dta keeps it)"
				continue
			}
		}
		if (G[i] == "require") req = req, tokens(VA[i])
		else if (G[i] == "inrange") inr = inr, e
		else if (G[i] == "allowed") alw = alw, e
		else line = line + " ///" + char(10) + "    " + e
	}
	if (cols(req)) {
		line = line + " ///" + char(10) + "    require("
		for (j = 1; j <= cols(req); j++) {
			if (j > 1 & mod(j - 1, 8) == 0) line = line + " ///" + char(10) + "        "
			else if (j > 1) line = line + " "
			line = line + req[j]
		}
		line = line + ")"
	}
	if (cols(inr)) {
		line = line + " ///" + char(10) + "    inrange("
		for (j = 1; j <= cols(inr); j++) {
			line = line + (j > 1 ? " \ ///" + char(10) + "        " : "") + inr[j]
		}
		line = line + ")"
	}
	if (cols(alw)) {
		line = line + " ///" + char(10) + "    allowed("
		for (j = 1; j <= cols(alw); j++) {
			line = line + (j > 1 ? " \ ///" + char(10) + "        " : "") + alw[j]
		}
		line = line + ")"
	}
	L = L, line
	if (rep & fileexists(fn)) unlink(fn)
	fh = fopen(fn, "w")
	for (j = 1; j <= cols(L); j++) fput(fh, L[j])
	fclose(fh)
}
end
