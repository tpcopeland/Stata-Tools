*! test_datamap_v200_content_qa.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 3 QA, part 1: F2, F3, U4 and F4, each against the plan's
*! acceptance test with oracles that do not share the implementation's route
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Companion of test_datamap_v200_content.do (the developers' suite) and part 2,
* test_datamap_v200_link_qa.do (U5, F5, F1, I2, privacy, helper pins).  Where
* the developers' suite pins one case, this file adds the cases it leaves out.
*
*   Q1  F2: every Declared line is present only for its own kind (xtset,
*       tsset, stset, svyset, mi set, each alone, two at once, and each
*       cleared again); no Dataset notes line without notes; no Structure
*       section without detect()/autodetect, "inferred" with it
*   Q2  F3 fuzz: 10 random datasets (codes . .a .b .c .z, labelled or not,
*       counts 0-25) at mincell 0, 1, 3, 5 and 1000.  Every printed count equals a
*       Mata count of the column, at mincell(0) every code is listed, no count
*       in 1..mincell-1 is printed, a single withheld cell is never
*       derivable from the printed total, no breakdown when only . occurs,
*       saving() missing_codes equals the document's list and the numeric
*       missing column keeps the exact count
*   Q3  F3 by hand: an unlabelled code, a label that needs escaping, and the
*       counts against -count-
*   Q4  U4: the family helper over every date format the classifier knows, and
*       the Type cell for every storage type, a date format on every numeric
*       storage type, and formats that are not dates
*   Q5  F4 date masks: the 95% rule at its exact boundary for 1..100
*       nonblank values (integer arithmetic), YMD/DMY/MDY and pairs
*   Q6  F4 tokens: the top five, ties by value, the rest; numeric-text count
*       and share against real(); blank-only and padded values
*   Q7  F4 strL and exclusion: strL flag in Type and saving(); an excluded
*       variable gets no profile in the document or in saving()
* Documents are read through Mata (_vq_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_content_qa.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200qwork"
capture mkdir "`work'"
capture mkdir "`work'/plus"
capture mkdir "`work'/personal"
capture mkdir "`work'/run"
mata: assert(direxists(st_local("work") + "/plus") & direxists(st_local("work") + "/run"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
local tests = 0
local pass = 0
local fail = 0
local cwd0 "`c(pwd)'"

capture mata: mata drop _vq_slurp()
capture mata: mata drop _vq_in()
capture mata: mata drop _vq_line()
capture mata: mata drop _vq_count()
capture mata: mata drop _vq_cell()
capture mata: mata drop _vq_f3()
capture mata: mata drop _vq_die()
capture mata: mata drop _vq_split()
capture mata: mata drop _vq_occ()
mata:
void _vq_die(string scalar msg)
{
	errprintf("%s", msg)
	exit(9)
}
// s cut at every sep
string rowvector _vq_split(string scalar s, string scalar sep)
{
	string rowvector r
	real scalar j
	r = J(1, 0, "")
	while ((j = strpos(s, sep)) > 0) {
		r = r, substr(s, 1, j - 1)
		s = substr(s, j + strlen(sep), .)
	}
	return(r, s)
}
// how many times needle occurs in local t
real scalar _vq_occ(string scalar needle)
{
	string scalar t
	real scalar n, j
	t = st_local("t")
	n = 0
	while ((j = strpos(t, needle)) > 0) {
		n++
		t = substr(t, j + strlen(needle), .)
	}
	return(n)
}
void _vq_slurp(string scalar path, string scalar dst)
{
	real scalar fh
	string scalar s, l
	fh = fopen(path, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	st_local(dst, s)
}
// local t holds needle ({bq} = a backtick) when want is 1, does not when 0
void _vq_in(string scalar needle, real scalar want)
{
	real scalar has
	has = (strpos(st_local("t"), subinstr(needle, "{bq}", char(96))) > 0)
	if (has != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
// local t has a whole line equal to needle ({bq} = a backtick)
void _vq_line(string scalar needle)
{
	if (!strpos(char(10) + st_local("t"), char(10) + subinstr(needle, "{bq}", char(96)) + char(10))) {
		errprintf("line not found: %s\n", needle)
		exit(9)
	}
}
// lines of local t that start with prefix
real scalar _vq_count(string scalar prefix)
{
	string scalar t
	real scalar n, j
	t = st_local("t")
	n = 0
	while ((j = strpos(t, char(10))) > 0) {
		n = n + (substr(t, 1, strlen(prefix)) == prefix)
		t = substr(t, j + 1, .)
	}
	return(n)
}
// the Missing cell (4th) of variable v's row in local t, "" when no row
string scalar _vq_cell(string scalar v)
{
	string scalar t, ln, key
	real scalar j, k
	t = st_local("t")
	key = "| " + char(96) + v + char(96) + " | "
	while ((j = strpos(t, char(10))) > 0) {
		ln = substr(t, 1, j - 1)
		t = substr(t, j + 1, .)
		if (substr(ln, 1, strlen(key)) == key) {
			ln = substr(ln, 3, .)
			for (k = 1; k <= 3; k++) ln = substr(ln, strpos(ln, " | ") + 3, .)
			return(substr(ln, 1, strpos(ln, " | ") - 1))
		}
	}
	return("")
}
// F3 check of variable v (numeric, in memory) against its Missing cell in
// local t, at mincell m.  sv is the frame holding the saving() table.
void _vq_f3(string scalar v, real scalar m, string scalar sv)
{
	string scalar cell, rest, it, w, cur, svc
	string rowvector items, codes, seen
	real colvector x
	real rowvector cc
	real scalar tmiss, tot, hastot, i, j, np, nhid, sump, c, k, svm, pos
	real matrix S

	x = st_data(., v)
	codes = (".", ".a", ".b", ".c", ".z")
	cc = (sum(x :== .), sum(x :== .a), sum(x :== .b), sum(x :== .c), sum(x :== .z))
	tmiss = sum(cc)
	cell = _vq_cell(v)
	if (cell == "") _vq_die(sprintf("%s: no row\n", v))
	// the saving() row
	cur = st_framecurrent()
	st_framecurrent(sv)
	k = st_varindex("variable")
	svc = ""
	svm = .
	for (i = 1; i <= st_nobs(); i++) {
		if (st_sdata(i, k) == v) {
			svc = st_sdata(i, st_varindex("missing_codes"))
			svm = _st_data(i, st_varindex("missing"))
		}
	}
	st_framecurrent(cur)
	if (svm != tmiss) _vq_die(sprintf("%s: saving() missing %g, true %g\n", v, svm, tmiss))
	np = sum(cc :> 0)
	if (tmiss == 0) {
		if (substr(cell, 1, 3) != "0 (" | strpos(cell, ":") | svc != "") {
			_vq_die(sprintf("%s: no missing values but cell [%s] saving [%s]\n", v, cell, svc))
		}
		return
	}
	// the total
	hastot = (substr(cell, 1, 1) >= "0" & substr(cell, 1, 1) <= "9")
	tot = .
	if (hastot) tot = strtoreal(substr(cell, 1, strpos(cell, " ") - 1))
	if (m <= 1 & !hastot) _vq_die(sprintf("%s: total withheld at mincell(%g): %s\n", v, m, cell))
	if (hastot & tot != tmiss) _vq_die(sprintf("%s: printed total %g, true %g\n", v, tot, tmiss))
	// (a variable missing in every row prints the dataset's N, which the header
	// prints as well)
	if (hastot & tot < m & tot != st_nobs()) _vq_die(sprintf("%s: printed total %g below mincell %g\n", v, tot, m))
	if (!hastot & substr(cell, 1, 10) != "suppressed") _vq_die(sprintf("%s: odd cell [%s]\n", v, cell))
	// the breakdown: only . occurring means none
	pos = strpos(cell, "): ")
	rest = (pos ? substr(cell, pos + 3, .) : "")
	if (np == 1 & cc[1] > 0) {
		if (rest != "" | svc != "") _vq_die(sprintf("%s: only . occurs but breakdown [%s] saving [%s]\n", v, cell, svc))
		return
	}
	if (rest == "") _vq_die(sprintf("%s: no breakdown in [%s]\n", v, cell))
	if (svc != rest) _vq_die(sprintf("%s: saving() [%s] differs from the cell's [%s]\n", v, svc, rest))
	items = _vq_split(rest, ", ")
	nhid = 0
	sump = 0
	seen = J(1, 0, "")
	for (i = 1; i <= cols(items); i++) {
		it = items[i]
		w = substr(it, 1, strpos(it + " ", " ") - 1)
		c = selectindex(codes :== w)
		if (!length(c)) _vq_die(sprintf("%s: unknown code [%s] in [%s]\n", v, w, cell))
		seen = seen, w
		if (strpos(it, "suppressed (")) {
			nhid++
			if (m <= 1) _vq_die(sprintf("%s: a code withheld at mincell(%g): %s\n", v, m, cell))
			continue
		}
		j = strtoreal(substr(it, strlen(it) - strpos(strreverse(it), " ") + 2, .))
		if (j != cc[c]) _vq_die(sprintf("%s: code %s printed %g, true %g\n", v, w, j, cc[c]))
		if (j < m) _vq_die(sprintf("%s: code %s count %g below mincell %g\n", v, w, j, m))
		sump = sump + j
	}
	// every code that occurs is listed (a count or withheld), none invented
	for (i = 1; i <= 5; i++) {
		if (cc[i] > 0 & !sum(seen :== codes[i])) _vq_die(sprintf("%s: code %s missing from [%s]\n", v, codes[i], cell))
		if (cc[i] == 0 & sum(seen :== codes[i])) _vq_die(sprintf("%s: code %s invented in [%s]\n", v, codes[i], cell))
	}
	// one withheld cell beside a printed total is derivable: it must not be small
	if (hastot & nhid == 1 & m > 0) {
		if (tot - sump > 0 & tot - sump < m) {
			errprintf("%s: the one withheld cell is derivable as %g (< %g) from [%s]\n", v, tot - sump, m, cell)
			exit(9)
		}
	}
}
end

**# Q1 F2: each Declared line only for its own kind

capture noisily {
    quietly cd "`work'/run"
    * none
    clear
    quietly set obs 20
    generate x = _n
    quietly datamap, output(q1a.md)
    mata: _vq_slurp("q1a.md", "t")
    mata: assert(_vq_count("- Declared ") == 0)
    mata: _vq_in("- Dataset notes:", 0)
    mata: _vq_in("Structure", 0)
    * xtset alone
    generate int firm = ceil(_n / 5)
    generate int year = 2000 + mod(_n - 1, 5)
    xtset firm year
    quietly datamap, output(q1b.md)
    mata: _vq_slurp("q1b.md", "t")
    mata: assert(_vq_count("- Declared ") == 1 & _vq_count("- Declared xtset: ") == 1)
    * cleared again: absent
    xtset, clear
    quietly datamap, output(q1b2.md)
    mata: _vq_slurp("q1b2.md", "t")
    mata: assert(_vq_count("- Declared ") == 0)
    * tsset alone, quarterly
    clear
    quietly set obs 12
    generate q = tq(2020q1) + _n - 1
    format q %tq
    generate y = _n
    tsset q
    quietly datamap, output(q1c.md)
    mata: _vq_slurp("q1c.md", "t")
    mata: assert(_vq_count("- Declared ") == 1 & _vq_count("- Declared tsset: ") == 1)
    mata: _vq_in("- Declared tsset: time {bq}q{bq} (%tq quarterly); delta 1", 1)
    tsset, clear
    quietly datamap, output(q1c2.md)
    mata: _vq_slurp("q1c2.md", "t")
    mata: assert(_vq_count("- Declared ") == 0)
    * stset alone
    clear
    quietly set obs 30
    generate double t1 = 5 + _n
    generate byte d = mod(_n, 2)
    stset t1, failure(d)
    quietly datamap, output(q1d.md)
    mata: _vq_slurp("q1d.md", "t")
    mata: assert(_vq_count("- Declared ") == 1 & _vq_count("- Declared stset: ") == 1)
    stset, clear
    quietly datamap, output(q1d2.md)
    mata: _vq_slurp("q1d2.md", "t")
    mata: assert(_vq_count("- Declared ") == 0)
    * svyset alone
    clear
    quietly set obs 40
    generate int psu = ceil(_n / 4)
    generate double w = 1 + mod(_n, 3)
    svyset psu [pweight = w]
    quietly datamap, output(q1e.md)
    mata: _vq_slurp("q1e.md", "t")
    mata: assert(_vq_count("- Declared ") == 1 & _vq_count("- Declared svyset: ") == 1)
    svyset, clear
    quietly datamap, output(q1e2.md)
    mata: _vq_slurp("q1e2.md", "t")
    mata: assert(_vq_count("- Declared ") == 0)
    * mi set alone
    clear
    set seed 4411
    quietly set obs 60
    generate double a = rnormal()
    generate double b = a + rnormal()
    quietly replace b = . in 1/6
    quietly mi set wide
    quietly mi register imputed b
    quietly mi impute regress b a, add(2) rseed(2)
    quietly datamap, output(q1f.md)
    mata: _vq_slurp("q1f.md", "t")
    mata: assert(_vq_count("- Declared ") == 1 & _vq_count("- Declared mi set: ") == 1)
    mata: _vq_in("- Declared mi set: style wide; M = 2; imputed {bq}b{bq}", 1)
    quietly mi unset
    quietly datamap, output(q1f2.md)
    mata: _vq_slurp("q1f2.md", "t")
    mata: assert(_vq_count("- Declared ") == 0)
    * xtset and stset together, with a note: exactly those two lines
    clear
    quietly set obs 40
    generate int id = ceil(_n / 4)
    generate int wave = 1 + mod(_n - 1, 4)
    generate double t1 = wave * 10
    generate byte d = (wave == 4)
    notes: a note on the dataset
    xtset id wave
    stset t1, id(id) failure(d)
    quietly datamap, output(q1g.md)
    mata: _vq_slurp("q1g.md", "t")
    mata: assert(_vq_count("- Declared ") == 2)
    mata: assert(_vq_count("- Declared xtset: ") == 1 & _vq_count("- Declared stset: ") == 1)
    mata: assert(_vq_count("- Declared tsset: ") == 0 & _vq_count("- Declared svyset: ") == 0 & _vq_count("- Declared mi set: ") == 0)
    mata: _vq_in("- Dataset notes:", 1)
    * detect(): no Structure section unless asked, and inferred when asked
    mata: _vq_in("Structure", 0)
    quietly datamap, output(q1h.md) detect(panel) panelid(id)
    mata: _vq_slurp("q1h.md", "t")
    mata: _vq_line("### Structure (inferred)")
    mata: _vq_in("(detected)", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q1 Declared lines only for their own kind (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q1 Declared lines only for their own kind"'
}

**# Q2 F3 fuzz: printed counts against Mata counts, no small count printed

capture noisily {
    quietly cd "`work'/run"
    local nruns = 0
    forvalues d = 1/10 {
        set seed `=7000 + `d''
        clear
        quietly set obs `=150 + 50 * mod(`d', 4)'
        local vars ""
        forvalues vi = 1/6 {
            quietly generate byte v`vi' = 1 + mod(_n + `vi', 3)
            local r0 = 0
            foreach code in . .a .b .c .z {
                local cnt = cond(runiform() < .4, 0, ceil(runiform() * cond(runiform() < .5, 8, 25)))
                if `cnt' > 0 quietly replace v`vi' = `code' in `=`r0' + 1'/`=`r0' + `cnt''
                local r0 = `r0' + `cnt'
            }
            if mod(`vi' + `d', 2) == 0 {
                label define l`vi' 1 "One" 2 "Two" 3 "Three" .a "Refused" .z "Zzz label"
                label values v`vi' l`vi'
            }
            local vars `vars' v`vi'
        }
        * a continuous variable (no levels listed) with codes, and one that is
        * missing in every row (all .a and .b)
        quietly generate double v7 = rnormal() * 10
        local r0 = 0
        foreach code in . .a .b .c .z {
            local cnt = cond(runiform() < .4, 0, ceil(runiform() * cond(runiform() < .5, 8, 25)))
            if `cnt' > 0 quietly replace v7 = `code' in `=`r0' + 1'/`=`r0' + `cnt''
            local r0 = `r0' + `cnt'
        }
        quietly generate double v8 = .a
        quietly replace v8 = .b in `=floor(_N / 3)'/l
        local vars `vars' v7 v8
        foreach m in 0 1 3 5 1000 {
            capture frame drop sv
            quietly datamap, output(q2.md) mincell(`m') saving(q2s, replace)
            frame create sv
            frame sv: quietly use q2s, clear
            mata: _vq_slurp("q2.md", "t")
            foreach v of local vars {
                mata: _vq_f3("`v'", `m', "sv")
                local ++nruns
            }
            frame drop sv
        }
    }
    display as text "Q2: " `nruns' " variable-runs checked"
    assert `nruns' == 400
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q2 F3 fuzz (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q2 F3 fuzz"'
}

**# Q3 F3 by hand: unlabelled code, escaping, counts against -count-

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 400
    generate byte v = 1 + mod(_n, 4)
    quietly replace v = .c in 1/7
    quietly replace v = .d in 8/29
    quietly replace v = . in 30/60
    label define vl 1 "a" 2 "b" 3 "c" 4 "d" .d `"Don't know | n/a <x>"'
    label values v vl
    foreach c in . .c .d {
        quietly count if v == `c'
        local n`=subinstr("`c'", ".", "d", 1)' = r(N)
    }
    assert `nd' == 31 & `ndc' == 7 & `ndd' == 22
    * the default mincell: every count is at least 5, so all three print
    quietly datamap, output(q3b.md)
    mata: _vq_slurp("q3b.md", "t")
    mata: _vq_in("| 60 (15.0%): . `nd', .c `ndc', .d Don't know \| n/a &lt;x&gt; `ndd' |", 1)
    quietly datamap, output(q3.md) mincell(0) saving(q3s, replace)
    mata: _vq_slurp("q3.md", "t")
    * the label is escaped in the document; .c has none and prints bare
    mata: _vq_in("60 (15.0%): . `nd', .c `ndc', .d Don't know \| n/a &lt;x&gt; `ndd' |", 1)
    use q3s, clear
    * saving() keeps the label raw
    assert missing_codes == `". 31, .c 7, .d Don't know | n/a <x> 22"' if variable == "v"
    assert missing == 60 if variable == "v"
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q3 F3 by hand (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q3 F3 by hand"'
}

**# Q4 U4: every date family, every storage type, formats that are not dates

capture noisily {
    quietly cd "`work'/run"
    * the helper over every date format the classifier knows
    local k = 0
    foreach pair in "%td|%td daily" "%-td|%td daily" "%tdCCYY-NN-DD|%td daily" ///
        "%d|%td daily" "%dDlY|%td daily" "%tc|%tc datetime" "%tcHH:MM|%tc datetime" ///
        "%-tc|%tc datetime" "%tC|%tC datetime (leap seconds)" ///
        "%tCDDmon|%tC datetime (leap seconds)" "%tw|%tw weekly" "%tm|%tm monthly" ///
        "%tq|%tq quarterly" "%th|%th half-yearly" "%ty|%ty yearly" ///
        "%tb|%tb business daily" "%tbmycal|%tb business daily" "%tg|%tg generic" ///
        "%9.2f|" "%9s|" "%-12s|" "%9.0g|" "%12.0fc|" "%s|" {
        local f = substr("`pair'", 1, strpos("`pair'", "|") - 1)
        local want = substr("`pair'", strpos("`pair'", "|") + 1, .)
        _datamap_datefamily, format(`f')
        assert `"`r(family)'"' == `"`want'"'
        local ++k
    }
    assert `k' == 24
    * the Type cell
    clear
    quietly set obs 6
    generate byte t_byte = 1
    generate int t_int = 1
    generate long t_long = 1
    generate float t_float = 1
    generate double t_double = 1
    generate str1 t_s1 = "a"
    generate str244 t_s244 = "a"
    generate str2045 t_s2045 = "a"
    generate strL t_strl = "a"
    generate float t_ftd = 1
    format t_ftd %td
    generate int t_imo = 1
    format t_imo %tm
    generate byte t_bq = 1
    format t_bq %tq
    generate long t_lw = 1
    format t_lw %tw
    generate double t_dg = 1
    format t_dg %tg
    generate double t_dtc = 1
    format t_dtc %tcHH:MM
    generate double t_f92 = 1.25
    format t_f92 %9.2f
    generate double t_fc = 1000
    format t_fc %12.0fc
    quietly datamap, output(q4.md) columns(variable type format)
    mata: _vq_slurp("q4.md", "t")
    mata: _vq_in("| {bq}t_byte{bq} | byte |", 1)
    mata: _vq_in("| {bq}t_int{bq} | int |", 1)
    mata: _vq_in("| {bq}t_long{bq} | long |", 1)
    mata: _vq_in("| {bq}t_float{bq} | float |", 1)
    mata: _vq_in("| {bq}t_double{bq} | double |", 1)
    mata: _vq_in("| {bq}t_s1{bq} | str1 |", 1)
    mata: _vq_in("| {bq}t_s244{bq} | str244 |", 1)
    mata: _vq_in("| {bq}t_s2045{bq} | str2045 |", 1)
    mata: _vq_in("| {bq}t_strl{bq} | strL |", 1)
    mata: _vq_in("| {bq}t_ftd{bq} | float %td daily | %td |", 1)
    mata: _vq_in("| {bq}t_imo{bq} | int %tm monthly | %tm |", 1)
    mata: _vq_in("| {bq}t_bq{bq} | byte %tq quarterly | %tq |", 1)
    mata: _vq_in("| {bq}t_lw{bq} | long %tw weekly | %tw |", 1)
    mata: _vq_in("| {bq}t_dg{bq} | double %tg generic | %tg |", 1)
    mata: _vq_in("| {bq}t_dtc{bq} | double %tc datetime | %tcHH:MM |", 1)
    * a numeric display format that is not a date adds nothing to the type
    mata: _vq_in("| {bq}t_f92{bq} | double | %9.2f |", 1)
    mata: _vq_in("| {bq}t_fc{bq} | double | %12.0fc |", 1)
    * the same with the default columns: the family still names the date
    quietly datamap, output(q4b.md)
    mata: _vq_slurp("q4b.md", "t")
    mata: _vq_in("| {bq}t_dtc{bq} |  | double %tc datetime | ", 1)
    mata: _vq_in("| {bq}t_f92{bq} |  | double | ", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q4 U4 type column (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q4 U4 type column"'
}

**# Q5 F4 date masks: the 95% boundary for 1..100 nonblank values

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 120
    * nv nonblank values; the "p" variable parses ceil(0.95 nv) of them (the
    * smallest count that reads), the "f" variable one fewer.  ceil(0.95 nv)
    * by integer arithmetic: floor((95 nv + 99) / 100)
    forvalues nv = 1/100 {
        local ok = floor((95 * `nv' + 99) / 100)
        foreach kind in p f {
            local k = `ok' - ("`kind'" == "f")
            quietly generate str10 m`kind'`nv' = ""
            if `k' > 0 quietly replace m`kind'`nv' = "2020-01-" + string(1 + mod(_n, 28), "%02.0f") in 1/`k'
            if `nv' > `k' quietly replace m`kind'`nv' = "bad" in `=`k' + 1'/`nv'
        }
    }
    * the oracle's own check of the fixture: parse counts straight from date()
    quietly count if !missing(date(mp37, "YMD"))
    assert r(N) == floor((95 * 37 + 99) / 100)
    quietly datamap, output(q5.md) saving(q5s, replace)
    mata: _vq_slurp("q5.md", "t")
    use q5s, clear
    local bad = 0
    forvalues nv = 1/100 {
        quietly count if variable == "mp`nv'" & date_mask == "YMD"
        if r(N) != 1 {
            local ++bad
            display as error "nv=`nv': mp parses " floor((95 * `nv' + 99) / 100) " of `nv' but date_mask is not YMD"
        }
        quietly count if variable == "mf`nv'" & date_mask == ""
        if r(N) != 1 {
            local ++bad
            display as error "nv=`nv': mf one short but date_mask is set"
        }
    }
    assert `bad' == 0
    * the document says the same for a sample of the variables
    mata: _vq_line("| {bq}mp20{bq} |  | str10 | 100 (83.3%) | N=20; 20 distinct; max length 10; date-like text (YMD) |")
    * exactly the 100 "p" variables read as dates, none of the 100 "f" ones
    mata: assert(_vq_occ("date-like text (YMD)") == 100)
    mata: assert(_vq_occ("date-like text") == 100)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q5 date mask 95% boundary (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q5 date mask 95% boundary"'
}

**# Q6 F4 tokens, numeric text and the masks YMD/DMY/MDY

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 300
    * 140 numeric-looking values of several forms, the rest tokens
    generate str12 s = string(1000 + _n)
    quietly replace s = "1e3" in 1/5
    quietly replace s = "+5" in 6/10
    quietly replace s = ".5" in 11/15
    quietly replace s = "5." in 16/20
    quietly replace s = "-7" in 21/25
    quietly replace s = "NA" in 141/170
    quietly replace s = "na" in 171/190
    quietly replace s = "N/A" in 191/202
    quietly replace s = "-" in 203/211
    quietly replace s = "." in 212/218
    quietly replace s = ".a" in 219/224
    quietly replace s = "?" in 225/230
    quietly replace s = "1,000" in 231/233
    quietly replace s = "" in 249/254
    quietly replace s = " 12" in 238/241
    quietly replace s = "13 " in 242/245
    quietly replace s = "0x10" in 246/248
    * oracles
    quietly count if s != "" & !missing(real(s))
    local nnum = r(N)
    local share = strtrim(string(100 * `nnum' / 300, "%9.1f"))
    quietly count if s != "" & ustrregexm(s, "^ | $")
    local npad = r(N)
    quietly count if s == "NA"
    local cNA = r(N)
    quietly count if s == "na"
    local cna = r(N)
    quietly count if s == "N/A"
    local cNslashA = r(N)
    quietly count if s == "-"
    local cdash = r(N)
    quietly count if s == "."
    local cdot = r(N)
    assert `cNA' == 30 & `cna' == 20 & `cNslashA' == 12 & `cdash' == 9 & `cdot' == 7
    quietly datamap, output(q6a.md) mincell(0)
    mata: _vq_slurp("q6a.md", "t")
    local want `"numeric text `nnum' (`share'%); non-numeric "NA" `cNA', "na" `cna', "N/A" `cNslashA', "-" `cdash', "." `cdot', others; leading or trailing spaces `npad' |"'
    mata: _vq_in(st_local("want"), 1)
    * the number the document gives for numeric text is the one real() gives
    mata: _vq_in("numeric text `nnum' (", 1)
    * the ties (6 and 6) beyond the top five stay in "others": no ".a", no "?"
    mata: _vq_in(char(34) + ".a" + char(34), 0)
    mata: _vq_in(char(34) + "?" + char(34), 0)
    * default mincell does not change a table whose every cell is >= 5 except
    * the 3-row "1,000" and 3-row "0x10", which are never listed
    quietly datamap, output(q6b.md)
    mata: _vq_slurp("q6b.md", "t")
    mata: _vq_in("numeric text `nnum' (`share'%); non-numeric " + char(34) + "NA" + char(34) + " `cNA', ", 1)
    mata: _vq_in("0x10", 0)
    mata: _vq_in("1,000", 0)
    * blank-only values are tokens and padded
    clear
    quietly set obs 60
    generate str6 w = string(_n)
    quietly replace w = " " in 1/6
    quietly replace w = "  " in 7/12
    quietly replace w = "1 " in 13/20
    quietly count if w != "" & ustrregexm(w, "^ | $")
    local npad2 = r(N)
    assert `npad2' == 20
    quietly datamap, output(q6c.md) mincell(0) saving(q6c, replace)
    mata: _vq_slurp("q6c.md", "t")
    mata: _vq_in("leading or trailing spaces `npad2' |", 1)
    mata: _vq_in("non-numeric " + char(34) + " " + char(34) + " 6", 1)
    use q6c, clear
    assert padded_n == `npad2' if variable == "w"
    * date masks: YMD, DMY, MDY, a pair; oracle: date() on each mask
    clear
    quietly set obs 60
    generate str10 d_ymd = "2020-02-" + string(13 + mod(_n, 10))
    generate str10 d_dmy = string(13 + mod(_n, 10)) + "/02/2020"
    generate str10 d_mdy = "02/" + string(13 + mod(_n, 10)) + "/2020"
    generate str10 d_amb = "0" + string(1 + mod(_n, 9)) + "/0" + string(1 + mod(_n, 3)) + "/2020"
    generate str10 d_no = "abc" + string(_n)
    foreach v in d_ymd d_dmy d_mdy d_amb d_no {
        foreach mk in YMD DMY MDY {
            quietly count if !missing(date(`v', "`mk'"))
            local pr_`v'_`mk' = (r(N) >= 0.95 * 60)
        }
        local want_`v' ""
        foreach mk in YMD DMY MDY {
            if `pr_`v'_`mk'' local want_`v' = "`want_`v''" + cond("`want_`v''" == "", "", " or ") + "`mk'"
        }
    }
    assert "`want_d_ymd'" == "YMD" & "`want_d_dmy'" == "DMY" & "`want_d_mdy'" == "MDY"
    assert "`want_d_amb'" == "DMY or MDY" & "`want_d_no'" == ""
    quietly datamap, output(q6d.md) saving(q6d, replace)
    use q6d, clear
    foreach v in d_ymd d_dmy d_mdy d_amb d_no {
        assert date_mask == "`want_`v''" if variable == "`v'"
    }
    mata: _vq_slurp("q6d.md", "t")
    mata: _vq_in("max length 10; values", 1)
    mata: _vq_in("date-like text (DMY or MDY) |", 1)
    mata: _vq_in("date-like text (YMD) |", 1)
    mata: _vq_in("date-like text (DMY) |", 1)
    mata: _vq_in("date-like text (MDY) |", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q6 F4 tokens and masks (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q6 F4 tokens and masks"'
}

**# Q7 F4 strL flag; excluded variables get no profile

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 30
    generate strL big = "x" * 3000 in 1
    quietly replace big = "short" in 2/30
    generate strL small_l = "ab" + string(_n)
    generate str2045 wide = "ab" + string(_n)
    generate str8 ids = "ID" + string(10000 + _n)
    generate str8 income_s = string(_n)
    quietly replace income_s = "NA" in 1/9
    generate str10 dstr = "2020-03-" + string(10 + mod(_n, 15))
    quietly save q7f, replace
    quietly datamap, output(q7.md) saving(q7s, replace) exclude(income_s dstr ids)
    mata: _vq_slurp("q7.md", "t")
    mata: _vq_in("| {bq}big{bq} |  | strL | ", 1)
    mata: _vq_in("| {bq}small_l{bq} |  | strL | ", 1)
    mata: _vq_in("| {bq}wide{bq} |  | str2045 | ", 1)
    use q7s, clear
    assert is_strl == 1 if inlist(variable, "big", "small_l")
    assert is_strl == 0 if variable == "wide"
    assert is_strl != 1 if inlist(variable, "ids", "income_s", "dstr")
    * excluded: no profile in saving() and none in the document
    assert missing(numeric_n) & missing(padded_n) & missing(numeric_pct) & date_mask == "" ///
        if inlist(variable, "income_s", "dstr", "ids")
    mata: _vq_line("| {bq}income_s{bq} |  | str8 | 0 (0.0%) | excluded (structure only) |")
    mata: _vq_line("| {bq}dstr{bq} |  | str10 | 0 (0.0%) | excluded (structure only) |")
    mata: _vq_in("numeric text", 0)
    mata: _vq_in("date-like", 0)
    mata: _vq_in("non-numeric", 0)
    mata: _vq_in("ID10", 0)
    mata: _vq_in("2020-03", 0)
    * not excluded: the same variables are profiled
    quietly use q7f, clear
    quietly datamap, output(q7b.md) saving(q7b, replace) mincell(0)
    mata: _vq_slurp("q7b.md", "t")
    mata: _vq_in("numeric text 21 (70.0%)", 1)
    use q7b, clear
    assert numeric_n == 21 if variable == "income_s"
    assert date_mask == "YMD" if variable == "dstr"
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q7 strL and exclusion (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q7 strL and exclusion"'
}

**# Q8 the data in memory is left as it was, after every new option and an error

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 300
    generate int id = ceil(_n / 3)
    generate int wave = 1 + mod(_n - 1, 3)
    generate double y = mod(_n * 7, 101)
    generate str8 s = string(1000 + _n)
    quietly replace s = "NA" in 1/9
    generate byte q = 1 + mod(_n, 3)
    quietly replace q = .a in 1/11
    label define ql .a "Refused"
    label values q ql
    generate long lopnr = 8800000 + _n
    notes y: a note
    char y[tag] "xyz"
    xtset id wave
    sort y
    quietly save q8f, replace
    quietly use q8f, clear
    quietly datasignature
    local sig0 `"`r(datasignature)'"'
    local ch0 = c(changed)
    local so0 : sortedby
    local k0 = c(k)
    local n0 = _N
    local tag0 : char y[tag]
    frame create q8user
    quietly frame dir
    local fr0 `"`r(frames)'"'
    quietly datamap, output(q8.md) exclude(auto) quality placeholders(999) missing(pattern) ///
        samples(2) saving(q8s, replace csv) detect(panel) panelid(id) mincell(0)
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'
    assert c(changed) == `ch0' & "`: sortedby'" == "`so0'" & c(k) == `k0' & _N == `n0'
    local tag1 : char y[tag]
    assert "`tag1'" == "`tag0'"
    quietly frame dir
    assert `"`r(frames)'"' == `"`fr0'"'
    * (the xtset declaration is a pair of characteristics; -xtset- itself
    * would re-sort the data, so it is not called here)
    local pv : char _dta[_TSpanel]
    local tv : char _dta[_TStvar]
    assert "`pv'" == "id" & "`tv'" == "wave"
    * an error leaves the same state and no frame behind
    capture datamap, output(q8e.md) placeholders(999)
    assert _rc == 198
    capture datamap nosuchvar, output(q8e.md)
    assert _rc != 0
    capture datamap, output(q8e.md) saving(q8s, csv)
    assert _rc == 602
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`sig0'"'
    assert c(changed) == `ch0' & "`: sortedby'" == "`so0'"
    quietly frame dir
    assert `"`r(frames)'"' == `"`fr0'"'
    capture frame drop q8user
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q8 state untouched (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q8 state untouched"'
}

**# Q9 missing_codes in saving(): whole, as the document prints it
* 2026-11-10 (2.0.0 Phase 3 repair): this pinned a cut at 2045 bytes on a
* character boundary (str2045, no mark, rc 0) while the document printed the
* breakdown whole.  missing_codes is strL now: the file and the saving() table
* must carry the same text, in the .dta and in saving(, csv).

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 200
    generate byte v = 1 + mod(_n, 4)
    quietly replace v = .a in 1/20
    quietly replace v = .b in 21/50
    * labels of 1,500 two-byte characters: the list is 3,000+ bytes
    local L1 = "é" * 1500
    label define vl .a "`L1'" .b "`L1'"
    label values v vl
    quietly datamap, output(q9.md) saving(q9s, replace)
    * the document is not cut
    mata: _vq_slurp("q9.md", "t")
    mata: assert(_vq_occ(st_local("L1")) == 2)
    use q9s, clear
    * the column holds the whole breakdown: both labels and both counts
    confirm strL variable missing_codes
    assert missing_codes == ".a `L1' 20, .b `L1' 30" if variable == "v"
    assert strlen(missing_codes) > 6000 if variable == "v"
    * the csv copy carries the same text
    quietly datamap, output(q9c.md) saving(q9c, replace csv)
    quietly import delimited using q9c.csv, clear varnames(1) case(preserve) bindquotes(strict) stringcols(_all) encoding("utf-8")
    assert missing_codes == ".a `L1' 20, .b `L1' 30" if variable == "v"
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: Q9 missing_codes whole (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: Q9 missing_codes whole"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_content_qa tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
