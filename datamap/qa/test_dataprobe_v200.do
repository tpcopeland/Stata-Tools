*! test_dataprobe_v200.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 4 acceptance cross-check for dataprobe: brief (U1),
*! the keyset() preflight (W1), makespec(file.do) (I1) and diff() (F6), on
*! fixtures of their own, with oracles that do not share the suites'
*! (test_dataprobe_v200_diff.do, test_datamap_v200_safe.do) fixtures
*! Author: Timothy P Copeland, Karolinska Institutet
*
* The plan's Phase 4 acceptance rows, one test each, on a fresh fixture:
*
*   P1  U1: line count <= variables + fixed overhead on a 46-variable
*       fixture; no level of count 1 printed (a labelled categorical holds a
*       level of 1, a string holds values of 1); the listed levels equal the
*       counts of an independent -count-; flagged variables before the rest;
*       no empty section headers; r() identical to the full profile under
*       six option sets
*   P2  W1: m:m (duplicates and missing keys on both sides) numeric (long
*       against double) and string (str5 against str12) keys: every printed
*       row count and key count equals an actual -merge m:m-; a type
*       conflict in either direction is a failed entry with no count
*   P3  I1: the generated do-file passes on the source data and exits 9 for
*       each of nine one-rule perturbations; every one is the rule that was
*       broken (r(failed_checks)), and the .dta spec agrees
*   P4  F6: six single edits each print exactly one variable line, the
*       edited variable's, and r(diff_*) names it
*   P5  r(masked) is the same after quietly dataprobe as after the printing
*       call (frequency-cell suppression, by() byfreq, brief)
* P3 also checks (2026-11-10) that a spec run on data missing a gated
* variable exits 9 with the failure "require", and a typo without require()
* stays rc 111.
* Logs are read through Mata (_v2p_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_dataprobe_v200.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200pwork"
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
macro drop DATAMAP_DQ

capture mata: mata drop _v2p_slurp()
capture mata: mata drop _v2p_in()
capture mata: mata drop _v2p_line()
capture mata: mata drop _v2p_block()
capture mata: mata drop _v2p_lines()
capture mata: mata drop _v2p_rsnap()
mata:
void _v2p_slurp(string scalar path, string scalar dst)
{
	real scalar fh
	string scalar s, l
	fh = fopen(path, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	st_local(dst, s)
}
// local t holds needle when want is 1, does not when 0
void _v2p_in(string scalar needle, real scalar want)
{
	if ((strpos(st_local("t"), needle) > 0) != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
// local t has a whole line equal to needle
void _v2p_line(string scalar needle)
{
	if (!strpos(char(10) + st_local("t"), char(10) + needle + char(10))) {
		errprintf("line not found: %s\n", needle)
		exit(9)
	}
}
// split local t on line feeds into a column (tokens() would trim blanks)
string colvector _v2p_split()
{
	string colvector L
	string scalar r
	real scalar p
	L = J(0, 1, "")
	r = st_local("t")
	while ((p = strpos(r, char(10))) > 0) {
		L = L \ substr(r, 1, p - 1)
		r = substr(r, p + 1, .)
	}
	if (r != "") L = L \ r
	return(L)
}
// the line equal to head and the indented lines after it, joined by "|"
void _v2p_block(string scalar head, string scalar dst)
{
	string colvector L
	real scalar i, j
	string scalar out
	L = _v2p_split()
	out = ""
	for (i = 1; i <= rows(L); i++) {
		if (L[i] == head) {
			for (j = i; j <= rows(L); j++) {
				if (j > i & substr(L[j], 1, 2) != "  ") break
				out = out + (out != "" ? "|" : "") + L[j]
			}
			break
		}
	}
	st_local(dst, out)
}
// lines of local t from the first one starting with head, less log noise,
// into local nlines; the variable lines of the brief table (between the
// column header and the first blank line) into local vlines, "|"-joined
void _v2p_lines(string scalar head)
{
	string colvector L
	real scalar i, k, on, tab
	string scalar v
	L = _v2p_split()
	k = 0
	on = 0
	tab = 0
	v = ""
	for (i = 1; i <= rows(L); i++) {
		if (!on & substr(L[i], 1, strlen(head)) == head) on = 1
		if (on & substr(L[i], 1, 1) != "." & substr(strtrim(L[i]), 1, 5) != "name:" &
			substr(strtrim(L[i]), 1, 4) != "log:" & substr(strtrim(L[i]), 1, 9) != "log type:" &
			substr(strtrim(L[i]), 1, 10) != "closed on:" & substr(L[i], 1, 5) != "-----") k++
		if (on & tab == 1) {
			if (strtrim(L[i]) == "") tab = 2
			else v = v + (v != "" ? "|" : "") + L[i]
		}
		if (on & tab == 0 & substr(strtrim(L[i]), 1, 8) == "Variable") tab = 1
	}
	st_local("nlines", strofreal(k))
	st_local("vlines", v)
}
// every r() scalar and macro as one text, into local dst
void _v2p_rsnap(string scalar dst)
{
	string colvector s
	string scalar out
	real scalar i
	out = ""
	s = sort(st_dir("r()", "numscalar", "*"), 1)
	for (i = 1; i <= rows(s); i++) out = out + "|" + s[i] + "=" + strofreal(st_numscalar("r(" + s[i] + ")"), "%21x")
	s = sort(st_dir("r()", "macro", "*"), 1)
	for (i = 1; i <= rows(s); i++) out = out + "|" + s[i] + "=" + st_global("r(" + s[i] + ")")
	st_local(dst, out)
}
end

**# P1 U1: dataprobe, brief
* the fixture: id; c1 a 9-level labelled categorical (600 500 400 300 100 50 3
* 1 46 rows); c2 a labelled categorical of 1,997 / 2 / 1; x with 40 missing;
* s an all-distinct str5 (every value a count of 1); g a str3 with two values
* (count 1,997 and 3); 40 more doubles z1-z40 so the line bound is tested on
* a wide table
quietly cd "`work'/run"
clear
set seed 20261110
quietly set obs 2000
generate long id = _n
generate byte c1 = 1
quietly replace c1 = 2 in 601/1100
quietly replace c1 = 3 in 1101/1500
quietly replace c1 = 4 in 1501/1800
quietly replace c1 = 5 in 1801/1900
quietly replace c1 = 6 in 1901/1950
quietly replace c1 = 7 in 1951/1953
quietly replace c1 = 8 in 1954
quietly replace c1 = 9 in 1955/2000
label define c1l 1 "L1" 2 "L2" 3 "L3" 4 "L4" 5 "L5" 6 "L6" 7 "L7" 8 "ONLYONE" 9 "L9"
label values c1 c1l
generate byte c2 = 1
quietly replace c2 = 2 in 1/2
quietly replace c2 = 3 in 3
label define c2l 1 "Big" 2 "Two" 3 "SINGLETON"
label values c2 c2l
generate double x = rnormal()
quietly replace x = . in 1/40
generate str5 s = "S" + string(1000 + _n)
generate str3 g = "aa"
quietly replace g = "RAR" in 1/3
forvalues i = 1/40 {
    generate double z`i' = rnormal()
}
quietly save brieffx, replace
quietly cd "`cwd0'"
capture noisily {
    quietly cd "`work'/run"
    use brieffx, clear
    local nv = c(k)
    assert `nv' == 46
    * the oracle for the levels: independent counts
    quietly count if c1 == 1
    local n1 = r(N)
    quietly count if c1 == 5
    local n5 = r(N)
    quietly count if c2 == 1
    local b1 = r(N)
    quietly count if c2 == 2
    local b2 = r(N)
    quietly count if c2 == 3
    assert r(N) == 1 & `n1' == 600 & `n5' == 100 & `b1' == 1997 & `b2' == 2
    foreach m in "" "maskrare" "onlyflagged" "maskrare mincell(2)" "id(id) isid(id)" "expectn(1 5000)" {
        * the full profile prints (a quietly call skips the display region and
        * leaves r(masked) 0, so it is not the comparison); its output goes to
        * a log of its own
        quietly log off main
        capture log close p1f
        log using p1f.log, replace text name(p1f)
        dataprobe, `m'
        mata: _v2p_rsnap("full")
        log close p1f
        quietly log on main
        capture log close p1
        log using p1.log, replace text name(p1)
        dataprobe, brief `m'
        mata: _v2p_rsnap("brf")
        log close p1
        if `"`full'"' != `"`brf'"' {
            display as error "r() differs under [`m']"
            display `"full: `full'"'
            display `"brief: `brf'"'
            exit 9
        }
        mata: _v2p_slurp("p1.log", "t")
        mata: _v2p_lines("dataprobe:")
        display "[`m']: `nlines' lines for `nv' variables"
        assert `nlines' <= `nv' + 8
        * no empty section header, no level of count 1 or of a string
        foreach h in CATEGORICAL CONTINUOUS STRING DATE "QUICK REFERENCE" PATTERNS {
            mata: _v2p_in(char(10) + "`h'", 0)
        }
        mata: _v2p_in("ONLYONE", 0)
        mata: _v2p_in("SINGLETON", 0)
        mata: _v2p_in("S1001", 0)
        mata: _v2p_in("RAR", 0)
    }
    * the levels, unmasked: top five with their counts; the count-2 level
    * is listed, the count-1 level is not
    capture log close p1
    log using p1.log, replace text name(p1)
    dataprobe, brief
    local fl "`r(flagged_vars)'"
    log close p1
    mata: _v2p_slurp("p1.log", "t")
    mata: _v2p_in("1 L1 `n1'; 2 L2 500; 3 L3 400; 4 L4 300; 5 L5 `n5'; +4 more", 1)
    mata: _v2p_in("1 Big `=strtrim(string(`b1', "%9.0fc"))'; 2 Two `b2'; +1 more", 1)
    mata: _v2p_in("all distinct, maxlen 5", 1)
    * flagged variables come first: every variable line before the first
    * unflagged one names a flagged variable, and every flagged variable
    * is among those lines
    mata: _v2p_lines("dataprobe:")
    display "flagged: `fl'"
    assert "`fl'" != ""
    local seenunf 0
    local nfl 0
    local rest "`vlines'"
    while `"`rest'"' != "" {
        local pos = strpos(`"`rest'"', "|")
        if `pos' {
            local ln = substr(`"`rest'"', 1, `pos' - 1)
            local rest = substr(`"`rest'"', `pos' + 1, .)
        }
        else {
            local ln `"`rest'"'
            local rest ""
        }
        gettoken vn : ln
        local isf = strpos(" `fl' ", " `vn' ") > 0
        if `isf' {
            assert !`seenunf'
            local ++nfl
        }
        else local seenunf 1
    }
    assert `nfl' == `: word count `fl''
    assert `seenunf'
    * maskrare: the rare level and what would give it back are withheld; the
    * count-1 level is never printed
    quietly count if c2 == 3
    log using p1.log, replace text name(p1)
    dataprobe c2, brief maskrare
    log close p1
    mata: _v2p_slurp("p1.log", "t")
    mata: _v2p_in("SINGLETON", 0)
    mata: _v2p_in("1 Big", 0)
}
local rc = _rc
capture log close p1
capture log close p1f
capture log on main
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: P1 U1 brief: line bound, no count-1 level, r() unchanged (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: P1 U1 brief: line bound, no count-1 level, r() unchanged"
}

**# P2 W1: the keyset() preflight against an actual merge m:m
quietly cd "`work'/run"
clear
quietly set obs 120
generate long k = 1 + floor((_n - 1) / (1 + mod(ceil(_n / 7), 3)))
quietly replace k = . in 1/4
generate double v = _n
generate str3 shared = "a"
generate str5 s = "x" + string(k)
quietly replace s = "" if missing(k)
quietly save mma, replace
clear
quietly set obs 90
generate double k = 20 + floor((_n - 1) / (1 + mod(ceil(_n / 5), 2)))
quietly replace k = . in 1/2
generate double w = _n
generate str3 shared = "b"
generate str12 s = "x" + string(k)
quietly replace s = "" if missing(k)
quietly save mmb, replace
quietly cd "`cwd0'"
capture noisily {
    quietly cd "`work'/run"
    foreach key in k s {
        use mma, clear
        capture log close p2
        log using p2.log, replace text name(p2)
        capture noisily dataprobe, gatesonly keyset(`key' using mmb, subset) warn
        local rmt "`r(keyset_merge)'"
        local rm = r(keyset_matched)
        local rmo = r(keyset_only_master)
        local ru = r(keyset_only_using)
        log close p2
        assert "`rmt'" == "m:m"
        * the oracle: an actual merge, rows and distinct keys
        quietly merge m:m `key' using mmb
        quietly count if _merge == 3
        local m3 = r(N)
        quietly count if _merge == 1
        local m1 = r(N)
        quietly count if _merge == 2
        local m2 = r(N)
        tempvar t1
        quietly bysort `key': generate byte `t1' = _n == 1
        quietly count if `t1' & _merge == 3
        local k3 = r(N)
        quietly count if `t1' & _merge == 1
        local k1 = r(N)
        quietly count if `t1' & _merge == 2
        local k2 = r(N)
        assert `m3' == 67 & `m1' == 68 & `m2' == 36
        assert `rm' == `k3' & `rmo' == `k1' & `ru' == `k2'
        mata: _v2p_slurp("p2.log", "t")
        mata: _v2p_line("  unique: memory no, mmb no; merge m:m")
        mata: _v2p_line("  keys: `k3' matched, `k1' memory only, `k2' mmb only")
        mata: _v2p_line("  merge m:m would report: `m3' matched, `m1' master only, `m2' using only")
        if "`key'" == "k" mata: _v2p_line("  shared non-key variables: shared s")
        else mata: _v2p_line("  shared non-key variables: k shared")
    }
    * a type conflict in either direction: a failed entry, no count
    clear
    quietly set obs 10
    generate str4 id = string(_n)
    quietly save conf_s, replace
    clear
    quietly set obs 10
    generate byte id = _n
    quietly save conf_n, replace
    foreach pair in "conf_s conf_n" "conf_n conf_s" {
        gettoken mem fil : pair
        use `mem', clear
        capture log close p2
        log using p2.log, replace text name(p2)
        capture noisily dataprobe, gatesonly keyset(id using `fil')
        local krc = _rc
        local rmt "`r(keyset_merge)'"
        local rmm = r(keyset_matched)
        log close p2
        assert `krc' == 9
        assert "`rmt'" == "conflict" & missing(`rmm')
        mata: _v2p_slurp("p2.log", "t")
        mata: _v2p_in("type conflict", 1)
        mata: _v2p_in("  keys: ", 0)
        mata: _v2p_in("would report", 0)
        * the same conflict makes merge itself stop
        capture merge 1:1 id using `fil'
        assert _rc == 106
    }
    * compatible types are not a conflict: long against double, str5 against str12
    use mma, clear
    quietly dataprobe, gatesonly keyset(k using mmb, subset) warn
    assert "`r(keyset_merge)'" != "conflict" & !missing(r(keyset_matched))
}
local rc = _rc
capture log close p2
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: P2 W1 keyset() preflight counts equal an actual merge (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: P2 W1 keyset() preflight counts equal an actual merge"
}

**# P3 I1: the generated do-file against one-rule perturbations
quietly cd "`work'/run"
clear
quietly set obs 2000
generate long id = _n
generate byte arm = 1 + mod(_n, 3)
label define arml 1 "ctl" 2 "act" 3 "plc"
label values arm arml
generate str3 reg = word("N S E", 1 + mod(_n, 3))
generate double age = 30 + mod(_n, 50)
generate double bmi = 20 + mod(_n, 15)
quietly replace bmi = . in 1/20
generate double adm = mdy(1, 1, 2020) + mod(_n, 300)
format adm %td
generate str8 txt = "t" + string(100000 + _n)
quietly save p3src, replace
quietly cd "`cwd0'"
capture noisily {
    quietly cd "`work'/run"
    use p3src, clear
    quietly dataprobe, makespec(p3spec.do, replace) gatesonly
    quietly dataprobe, makespec(p3spec.dta, replace) gatesonly
    mata: _v2p_slurp("p3spec.do", "t")
    mata: _v2p_line("dataprobe, gatesonly ///")
    mata: _v2p_in("expectn(2000 2000)", 1)
    mata: _v2p_in("isid(id)", 1)
    * the source passes, as a do-file and as a spec
    capture noisily do p3spec.do
    assert _rc == 0
    capture noisily dataprobe, checks(p3spec.dta) gatesonly
    assert _rc == 0 & r(n_failed) == 0
    * the perturbations: (name; commands; the gate that must be the failure)
    local i 0
    foreach p in "expectn|drop in 1|expectn" "isid|replace id = 1 in 2|isid" ///
        "require|drop txt|require" "range_id|replace id = 5000 in 1|inrange" ///
        "range_age|replace age = 200 in 5|inrange" "range_date|replace adm = adm + 1000 in 5|inrange" ///
        "allowed_arm|replace arm = 4 in 5|allowed" "allowed_reg|replace reg = char(88) in 5|allowed" ///
        "allowed_bmi|replace bmi = 35 in 30|allowed" {
        gettoken pn rest : p, parse("|")
        gettoken bar rest : rest, parse("|")
        gettoken cmd rest : rest, parse("|")
        gettoken bar want : rest, parse("|")
        local ++i
        use p3src, clear
        quietly `cmd'
        capture log close p3
        log using p3_`i'.log, replace text name(p3)
        capture noisily do p3spec.do
        local rc_do = _rc
        local fc_do "`r(failed_checks)'"
        log close p3
        capture noisily dataprobe, checks(p3spec.dta) gatesonly
        local rc_dta = _rc
        local fc_dta "`r(failed_checks)'"
        display "`pn': do rc `rc_do' (`fc_do'), dta rc `rc_dta' (`fc_dta')"
        assert `rc_do' == 9 & `rc_dta' == 9
        assert "`fc_do'" == "`want'" & "`fc_dta'" == "`want'"
    }
    * a variable that a range, level or key gate names is gone.  2026-11-10
    * (2.0.0 Phase 4 repair round 1): this pinned only "not rc 0" because the
    * gate on the missing variable stopped rc 111.  A gate entry on a variable
    * that require() names and the data lacks is now not run, and require()
    * fails, so the do-file and the .dta spec exit 9 with the failure
    * "require" (reg: allowed; age, adm: inrange; id: isid and inrange; arm,
    * bmi: allowed).
    foreach dv in reg age adm id arm bmi {
        use p3src, clear
        drop `dv'
        capture noisily do p3spec.do
        local rc_do = _rc
        local fc_do "`r(failed_checks)'"
        capture noisily dataprobe, checks(p3spec.dta) gatesonly
        local rc_dta = _rc
        local fc_dta "`r(failed_checks)'"
        display "drop `dv': do rc `rc_do' (`fc_do'), dta rc `rc_dta' (`fc_dta')"
        assert `rc_do' == 9 & `rc_dta' == 9
        assert "`fc_do'" == "require" & "`fc_dta'" == "require"
    }
    * without require() a gate naming a variable the data lacks stays an error
    use p3src, clear
    capture dataprobe, gatesonly inrange(nosuchvar 0 1)
    assert _rc == 111
    capture dataprobe, gatesonly allowed(nosuchvar 1 2)
    assert _rc == 111
    capture dataprobe, gatesonly isid(nosuchvar)
    assert _rc == 111
    * a perturbation the spec does not forbid passes (no false alarm):
    * missing values in a ranged variable, and a level inside the list
    use p3src, clear
    quietly replace age = . in 5
    quietly replace arm = 2 in 7
    capture noisily do p3spec.do
    assert _rc == 0
}
local rc = _rc
capture log close p3
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: P3 I1 do-file passes on source, exits 9 on each perturbation (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: P3 I1 do-file passes on source, exits 9 on each perturbation"
}

**# P4 F6: a single edit prints a single variable line
quietly cd "`work'/run"
clear
set seed 4242
quietly set obs 500
generate double a = rnormal() * 5 + 50
generate double b = rnormal()
quietly replace b = . in 1/10
generate byte d = 1 + mod(_n, 5)
generate double e = _n
generate str4 f = "ab"
generate long h = _n * 3
quietly save p4src, replace
quietly cd "`cwd0'"
capture noisily {
    quietly cd "`work'/run"
    use p4src, clear
    capture frame drop p4base
    quietly dataprobe, snapshot(p4base) gatesonly
    local vars "a b d e f h"
    local i 0
    foreach ed in "replace a = a + 5|a|stat" "replace b = . in 11/20|b|missing" ///
        "recast double d|d|type" "replace d = 6 in 1|d|stat" "drop e|e|dropped" ///
        "generate byte newvar = 1|newvar|added" {
        gettoken cmd rest : ed, parse("|")
        gettoken bar rest : rest, parse("|")
        gettoken ev rest : rest, parse("|")
        gettoken bar kind : rest, parse("|")
        local ++i
        use p4src, clear
        quietly summarize a
        local ma0 = strtrim(string(r(mean), "%12.6g"))
        quietly `cmd'
        capture quietly summarize a
        local ma1 = strtrim(string(r(mean), "%12.6g"))
        capture log close p4
        log using p4_`i'.log, replace text name(p4)
        dataprobe, diff(p4base) gatesonly
        local dch = r(diff_changed)
        local dvs "`r(diff_changed_vars)'"
        local dnd = r(diff_n_delta)
        log close p4
        assert `dch' == 1 & "`dvs'" == "`ev'" & `dnd' == 0
        mata: _v2p_slurp("p4_`i'.log", "t")
        mata: _v2p_block("DIFF", "got")
        * header, baseline, N and key lines, then exactly one variable line
        display "`ed': `got'"
        local nvl 0
        local rest `"`got'"'
        while `"`rest'"' != "" {
            local pos = strpos(`"`rest'"', "|")
            if `pos' {
                local ln = substr(`"`rest'"', 1, `pos' - 1)
                local rest = substr(`"`rest'"', `pos' + 1, .)
            }
            else {
                local ln `"`rest'"'
                local rest ""
            }
            if `"`ln'"' == "DIFF" | substr(`"`ln'"', 1, 12) == "  baseline: " continue
            if substr(`"`ln'"', 1, 5) == "  N: " | substr(`"`ln'"', 1, 6) == "  key " continue
            local ++nvl
        }
        assert `nvl' == 1
        local t `"`got'"'
        mata: _v2p_in("|  `ev': ", 1)
        foreach o of local vars {
            if "`o'" != "`ev'" mata: _v2p_in("|  `o': ", 0)
        }
        mata: _v2p_in("no changes", 0)
        if "`kind'" == "dropped" mata: _v2p_in("|  `ev': dropped (", 1)
        if "`kind'" == "added" mata: _v2p_in("|  `ev': added (", 1)
        if "`kind'" == "type" mata: _v2p_in("|  `ev': type byte -> double", 1)
        if "`kind'" == "missing" mata: _v2p_in("|  `ev': missing 10 -> 20 (+10)", 1)
        * the oracles are the design: b has 490 distinct values (10 missing),
        * d has 5 levels; the mean of a is an independent -summarize-
        if "`ev'" == "b" mata: _v2p_in("|  b: missing 10 -> 20 (+10); distinct 490 -> 480 (-10); mean ", 1)
        if "`cmd'" == "replace d = 6 in 1" mata: _v2p_in("|  d: distinct 5 -> 6 (+1); mean ", 1)
        if "`ev'" == "a" mata: _v2p_in("|  a: mean `ma0' -> `ma1'; range ", 1)
    }
    * the unedited data: no variable line at all
    use p4src, clear
    quietly dataprobe, diff(p4base) gatesonly
    assert r(diff_changed) == 0
    capture frame drop p4base
}
local rc = _rc
capture log close p4
capture frame drop p4base
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: P4 F6 a single edit prints a single variable line (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: P4 F6 a single edit prints a single variable line"
}

**# P5 r(masked) does not depend on quietly
* 2026-11-10 (2.0.0 Phase 4 repair round 1): 1.x skipped the frequency
* tables under quietly, so a call whose only masked cell was a suppressed
* frequency-table cell returned r(masked) 0 quietly and 1 printing.  The
* fixture: a labelled categorical with levels of 1997, 1 and 2 rows (the 1 is
* suppressed under maskrare); also with by() byfreq, brief, and a control
* without maskrare (0 both ways).
quietly cd "`work'/run"
capture noisily {
    clear
    quietly set obs 2000
    generate byte c2 = 1
    quietly replace c2 = 2 in 1
    quietly replace c2 = 3 in 2/3
    label define p5l 1 "big" 2 "one" 3 "two"
    label values c2 p5l
    generate byte g = 1 + (_n > 1000)
    foreach opts in "maskrare" "maskrare by(g) byfreq" "brief maskrare" "nomaskrare" {
        quietly dataprobe c2, `opts'
        local mq = r(masked)
        capture log close p5
        log using p5.log, replace text name(p5)
        dataprobe c2, `opts'
        local mp = r(masked)
        log close p5
        display "`opts': quietly `mq', printing `mp'"
        assert `mq' == `mp'
        if "`opts'" == "nomaskrare" assert `mp' == 0
        else assert `mp' == 1
    }
}
local rc = _rc
capture log close p5
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: P5 r(masked) is the same quietly and printing (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: P5 r(masked) is the same quietly and printing"
}

macro drop DATAMAP_DQ
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_dataprobe_v200 tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
