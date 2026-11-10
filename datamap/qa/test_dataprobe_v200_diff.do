*! test_dataprobe_v200_diff.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 4, batch A: dataprobe compare()/saving() targets (U3),
*! snapshot()/diff()/tol() (F6), the keyset() preflight (W1) and
*! makespec(file.do) (I1), each against the acceptance test of the plan
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Fixture: the session's scenario, a 3,000-row "person" file (numeric lopnr,
* extended missings in edu, a 999 placeholder in bmi, a %tc variable, an exit
* date in 2070, a byte death flag, numeric text with NA) and rx files whose
* lopnr is str12 (rx) or long (rx2).
*
*   D1  F6: the scenario (expand 150 rows, blank 26 bmi, drop age, add newv,
*       tostring dead) prints each line of the DIFF block exactly, in order;
*       every count and mean from an independent count/summarize; r(diff_*)
*   D2  F6: identical data prints "no changes"; r(diff_changed) 0; a rolling
*       diff(b) snapshot(b, replace) compares with the previous snapshot
*   D3  U3/F6: compare() prints the same lines as diff() for the same
*       baseline (snapshot frame), for a saving() frame and for a saving()
*       file; the detail block prints under gatesonly; compare() is still the
*       schema gate (rc 9; warn rc 0), diff() never halts
*   D4  U3: one target rule -- saving(b) then compare(b); saving(b.dta) then
*       compare(b.dta) and compare(b) (no frame b: the 1.x file fallback);
*       a missing target, an existing frame or file without replace, a file
*       snapshot() and the current frame each stop before any profile output
*   D5  F6 masking: under maskrare a count from 1 to 4 prints as <5 and its
*       delta as +<5, the count beside it is withheld; a range prints only as
*       changed; the surplus key rows are masked; r() is unmasked
*   D6  F6 tol(): a relative change below 1e-8 prints nothing, tol(0) prints
*       it; the count tolerance hides a change of 26 and keeps one of 150;
*       tol() without diff() or compare() is rc 198
*   D7  F6: a plain dataset as baseline (schema only: types, added, dropped,
*       N); a datamap saving() file (strL columns) as baseline
*   D8  W1: person/rx type conflict is a failed entry with no count (rc 9,
*       no keys line); person/rx2: the printed counts equal an actual merge
*       1:m and the key counts equal -frlink-; shared non-key names; m:1 and
*       1:1; masking of a small count and of the counts that would give
*       it back (matched keys and rows beside a masked one-sided count)
*   D9  I1: makespec(spec.do) writes a dataprobe command that passes on the
*       source data and exits 9 on perturbed data; .dta unchanged; an
*       existing do-file without replace is rc 602 before any output; a
*       string level with a space is left out with a comment
*   D10 note 4: saving() with a note of 2,000 quotes, backticks and dollar
*       signs (1.10.6: r(130)) stores the cell cut to 2045 bytes verbatim
*   D11 F6: an excluded variable (either side) gets its type, class and
*       missing count compared, never its distinct count or statistics
*   D12 F6: a key outside the call's varlist prints "not checked after",
*       not "dropped"; a key dropped from the data still prints "dropped"
*   D13 F6 masking: under safe/maskrare the mean of a categorical or two-
*       or three-valued variable reads "mean changed" (it is a share that
*       gives a suppressed count back); unmasked it prints
*   D14 F6: empty data (keep if 0, or an empty if/in scope) with diff(),
*       compare() or snapshot() skips the profile with a note and reports
*       N 74 -> 0 and each distinct count to 0, no class line; gates still
*       run; brief or a plain call on empty data is still r(2000)
*   D15 U3: diff() and compare() read a quoted baseline path with a space,
*       as saving() writes it; an unquoted name with a space is still r(198)
* Logs are read through Mata (_v2d_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_dataprobe_v200_diff.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200dwork"
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

capture mata: mata drop _v2d_slurp()
capture mata: mata drop _v2d_in()
capture mata: mata drop _v2d_line()
capture mata: mata drop _v2d_block()
mata:
void _v2d_slurp(string scalar path, string scalar dst)
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
void _v2d_in(string scalar needle, real scalar want)
{
	if ((strpos(st_local("t"), needle) > 0) != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
// local t has a whole line equal to needle
void _v2d_line(string scalar needle)
{
	if (!strpos(char(10) + st_local("t"), char(10) + needle + char(10))) {
		errprintf("line not found: %s\n", needle)
		exit(9)
	}
}
// the line of local t equal to head and the indented lines after it,
// joined by "|", into local dst
void _v2d_block(string scalar head, string scalar dst)
{
	string colvector L
	real scalar i, j, p
	string scalar out, r
	// split on line feeds by hand: tokens() trims each line's blanks
	L = J(0, 1, "")
	r = st_local("t")
	while ((p = strpos(r, char(10))) > 0) {
		L = L \ substr(r, 1, p - 1)
		r = substr(r, p + 1, .)
	}
	if (r != "") L = L \ r
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
end

* a pair of numbers as a diff line prints them: the fewest %g digits, 6 to
* 17, that tell them apart
capture program drop _v2d_pair
program define _v2d_pair, rclass
    args a b
    forvalues d = 6/17 {
        local sa = strtrim(string(`a', "%24.`d'g"))
        local sb = strtrim(string(`b', "%24.`d'g"))
        if "`sa'" != "`sb'" continue, break
    }
    return local s "`sa' -> `sb'"
end

* the fixture
quietly cd "`work'/run"
clear
quietly set obs 3000
generate long lopnr = 100000 + _n
generate byte edu = 1 + mod(_n, 3)
quietly replace edu = . in 1/51
quietly replace edu = .a in 52/196
quietly replace edu = .b in 197/276
label define edul 1 "Low" 2 "Mid" 3 "High" .a "Refused" .b "Not asked"
label values edu edul
generate byte sex = 1 + mod(_n, 2)
generate double bmi = 20 + mod(_n, 37) / 3
quietly replace bmi = 999 in 101/126
generate int age = 20 + mod(_n, 70)
generate double admit_tc = clock("2015-03-01 10:00", "YMDhm") + _n * 60000
format admit_tc %tc
generate long exitd = mdy(1, 1, 2020) + mod(_n, 400)
quietly replace exitd = mdy(6, 1, 2070) in 1/12
format exitd %td
generate byte dead = mod(_n, 9) == 0
generate str8 income_s = string(1000 + _n)
quietly replace income_s = "NA" in 1/124
quietly save person.dta, replace
clear
quietly set obs 9000
generate str12 lopnr = string(100000 + ceil(_n / 3))
generate int drug = mod(_n, 7)
generate byte sex = 1 + mod(_n, 2)
quietly save rx.dta, replace
destring lopnr, replace
quietly drop if lopnr > 102990
quietly save rx2.dta, replace
* the perturbation of the session
capture program drop _v2d_perturb
program define _v2d_perturb
    quietly expand 2 in 1/150
    quietly replace bmi = . in 2001/2026
    drop age
    generate float newv = _n / 7
    quietly tostring dead, replace
end
quietly cd "`cwd0'"

**# D1 F6: the session's scenario, line by line
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) gatesonly
    assert "`r(snapshot)'" == "base" & "`r(snapshot_key)'" == "lopnr"
    * the oracle: the baseline's facts, before the perturbation
    quietly summarize lopnr
    local m0_lopnr = r(mean)
    quietly summarize bmi
    local m0_bmi = r(mean)
    quietly count if missing(edu)
    local e0 = r(N)
    quietly count if missing(bmi)
    local b0 = r(N)
    _v2d_perturb
    quietly summarize lopnr
    local m1_lopnr = r(mean)
    quietly summarize bmi
    local m1_bmi = r(mean)
    quietly count if missing(edu)
    local e1 = r(N)
    quietly count if missing(bmi)
    local b1 = r(N)
    local n1 = _N
    tempvar tg
    quietly bysort lopnr: generate byte `tg' = _n == 1
    quietly count if `tg'
    local sur = `n1' - r(N)
    drop `tg'
    assert `e0' == 276 & `e1' == 426 & `b0' == 0 & `b1' == 26 & `n1' == 3150 & `sur' == 150
    _v2d_pair `m0_lopnr' `m1_lopnr'
    local ml "`r(s)'"
    _v2d_pair `m0_bmi' `m1_bmi'
    local mb "`r(s)'"
    local want "DIFF|  baseline: frame base|  N: current `n1', baseline 3000, delta `=`n1' - 3000'"
    local want "`want'|  key lopnr: unique before, not unique after (`sur' surplus rows)"
    local want "`want'|  lopnr: mean `ml'"
    local want "`want'|  edu: missing `e0' -> `e1' (+`=`e1' - `e0'')"
    local want "`want'|  bmi: missing `b0' -> `b1' (+`=`b1' - `b0''); mean `mb'"
    local want "`want'|  age: dropped (int)"
    local want "`want'|  dead: type byte -> str1; class categorical -> string"
    local want "`want'|  newv: added (float, continuous)"
    capture log close d1
    log using d1.log, replace text name(d1)
    dataprobe, diff(base) gatesonly
    assert r(diff_n_delta) == 150 & r(diff_base_N) == 3000
    assert r(diff_key_before) == 1 & r(diff_key_after) == 0 & r(diff_key_surplus) == 150
    assert r(diff_added) == 1 & r(diff_dropped) == 1 & r(diff_type_changed) == 1
    assert r(diff_changed) == 6 & r(diff_n_lines) == 6
    assert "`r(diff_added_vars)'" == "newv" & "`r(diff_dropped_vars)'" == "age"
    assert "`r(diff_type_changed_vars)'" == "dead" & "`r(diff_missing_changed_vars)'" == "edu bmi"
    assert "`r(diff_stat_changed_vars)'" == "lopnr bmi" & "`r(diff_key)'" == "lopnr"
    assert "`r(diff_changed_vars)'" == "lopnr edu bmi age dead newv"
    assert r(diff_tol) == 1e-8 & r(diff_ctol) == 0 & r(N) == 3150
    * 2026-11-10 (Phase 5 QA): r(diff_baseline) was documented and returned but
    * never asserted; it is the text printed after "baseline: " in the DIFF block
    assert `"`r(diff_baseline)'"' == "frame base"
    log close d1
    mata: _v2d_slurp("d1.log", "t")
    mata: _v2d_block("DIFF", "got")
    if `"`got'"' != `"`want'"' {
        display as error `"got:  `got'"'
        display as error `"want: `want'"'
        exit 9
    }
    quietly cd "`cwd0'"
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D1 the session's scenario prints each diff line (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D1 the session's scenario prints each diff line"
}

**# D2 F6: identical data; a rolling snapshot
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) gatesonly
    capture log close d2
    log using d2.log, replace text name(d2)
    dataprobe, diff(base) gatesonly
    assert r(diff_changed) == 0 & r(diff_n_lines) == 0 & r(diff_n_delta) == 0
    log close d2
    mata: _v2d_slurp("d2.log", "t")
    mata: _v2d_block("DIFF", "got")
    assert `"`got'"' == "DIFF|  baseline: frame base|  N: current 3000, baseline 3000, delta 0|  key lopnr: unique before and after|  no changes"
    * rolling: diff against the previous snapshot, then replace it
    _v2d_perturb
    quietly dataprobe, diff(base) snapshot(base, replace) gatesonly
    assert r(diff_changed) == 6
    frame base {
        local c1 : char _dta[dataprobe_N]
        local c2 : char _dta[dataprobe_keyuniq]
    }
    assert "`c1'" == "3150" & "`c2'" == "0"
    quietly dataprobe, diff(base) gatesonly
    assert r(diff_changed) == 0 & r(diff_n_delta) == 0
    * snapshot() without replace on an existing frame stops before output
    capture log close d2b
    log using d2b.log, replace text name(d2b)
    capture noisily dataprobe, snapshot(base)
    local src = _rc
    log close d2b
    assert `src' == 110
    mata: _v2d_slurp("d2b.log", "t")
    mata: _v2d_in("snapshot(): frame base already exists; specify replace", 1)
    mata: _v2d_in("QUICK REFERENCE", 0)
    mata: _v2d_in(" obs, ", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D2 identical data prints no changes; rolling snapshot (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D2 identical data prints no changes; rolling snapshot"
}

**# D3 U3/F6: compare() prints the diff() lines; under gatesonly too
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    capture frame drop fb
    quietly dataprobe, snapshot(base) saving(fb) gatesonly
    quietly dataprobe, saving(pbase.dta, replace) gatesonly
    _v2d_perturb
    capture log close d3
    log using d3.log, replace text name(d3)
    dataprobe, diff(base) gatesonly
    capture noisily dataprobe, compare(base) gatesonly
    local c1 = _rc
    capture noisily dataprobe, compare(fb) gatesonly warn
    local c2 = _rc
    capture noisily dataprobe, compare(pbase.dta) gatesonly warn
    local c3 = _rc
    * compare() stays the schema gate; the block prints under gatesonly
    assert `c1' == 9 & `c2' == 0 & `c3' == 0
    assert r(compare_added) == 1 & r(compare_dropped) == 1 & r(compare_type_changed) == 1
    assert "`r(compare_added_vars)'" == "newv" & "`r(compare_dropped_vars)'" == "age"
    log close d3
    mata: _v2d_slurp("d3.log", "t")
    mata: _v2d_block("DIFF", "gd")
    mata: _v2d_block("SCHEMA COMPARE", "gc")
    * the same lines after the heading
    local gd2 = substr(`"`gd'"', strpos(`"`gd'"', "|"), .)
    local gc2 = substr(`"`gc'"', strpos(`"`gc'"', "|"), .)
    assert `"`gd2'"' == `"`gc2'"' & `"`gd2'"' != ""
    * a saving() frame and a saving() file: the same per-variable lines; the
    * key's uniqueness before is unknown there (3,000 distinct values are
    * above the profile's count cap and saving() carries no key)
    local p0 = strpos(`"`gd2'"', "|  lopnr:")
    local tail = substr(`"`gd2'"', `p0', .)
    foreach b in "frame fb" "pbase.dta" {
        local s0 = strpos(`"`t'"', "  baseline: `b'")
        assert `s0' > 0
        local tt = substr(`"`t'"', `s0', .)
        local tt = subinstr(`"`tt'"', char(10), "|", .)
        assert strpos(`"`tt'"', "  key lopnr: unknown before, not unique after (150 surplus rows)") > 0
        assert strpos(`"|`tt'"', `"`tail'"') > 0
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D3 compare() prints the diff() lines, gatesonly too (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D3 compare() prints the diff() lines, gatesonly too"
}

**# D4 U3: one target rule, validated before profiling
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop b
    quietly dataprobe, saving(b)
    quietly dataprobe, compare(b) warn
    assert r(compare_changed) == 0
    capture erase b2.dta
    quietly dataprobe, saving(b2.dta)
    quietly dataprobe, compare(b2.dta) warn
    assert r(compare_changed) == 0
    * no frame b2: the 1.x reading of compare(b2) as b2.dta still works
    quietly dataprobe, compare(b2) warn
    assert r(compare_changed) == 0
    foreach call in "compare(nosuch)|601|compare(): no frame or file named nosuch" ///
        "diff(nosuch)|601|diff(): no frame or file named nosuch" ///
        "compare(./nosuch.dta)|601|compare() file ./nosuch.dta not found" ///
        "saving(b)|110|saving(): frame b already exists; specify replace" ///
        "saving(b2.dta)|602|saving(): file b2.dta already exists; specify replace" ///
        "snapshot(sn.dta)|198|snapshot() takes a frame name; saving() writes a file" ///
        "saving(default, replace)|198|saving(): default is the current frame and cannot be replaced" ///
        "compare(b b2)|198|compare() accepts one frame name or one Stata dataset filename" ///
        "saving(b, csv)|198|saving(): the only suboption is replace; got csv" ///
        "snapshot(b2f) saving(b2f)|198|saving() and snapshot() name the same frame b2f" {
        gettoken o rest : call, parse("|")
        gettoken bar rest : rest, parse("|")
        gettoken wrc rest : rest, parse("|")
        local msg = substr(`"`rest'"', 2, .)
        capture log close d4
        log using d4.log, replace text name(d4)
        capture noisily dataprobe, `o'
        local crc = _rc
        log close d4
        if `crc' != `wrc' {
            display as error "`o': rc `crc', want `wrc'"
            exit 9
        }
        mata: _v2d_slurp("d4.log", "t")
        mata: _v2d_in(st_local("msg"), 1)
        mata: _v2d_in("QUICK REFERENCE", 0)
        mata: _v2d_in(" obs, ", 0)
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D4 one target rule, checked before any output (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D4 one target rule, checked before any output"
}

**# D5 F6 masking
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) gatesonly
    quietly replace bmi = . in 2001/2003
    quietly replace exitd = mdy(1, 1, 2071) in 3000
    quietly expand 2 in 1/2
    capture log close d5
    log using d5.log, replace text name(d5)
    dataprobe, diff(base) gatesonly maskrare
    * stored results stay unmasked
    assert r(diff_key_surplus) == 2 & r(diff_n_delta) == 2
    log close d5
    mata: _v2d_slurp("d5.log", "t")
    mata: _v2d_line("  N: current 3002, baseline [suppressed], delta <5 (masked)")
    mata: _v2d_line("  key lopnr: unique before, not unique after (<5 surplus rows)")
    mata: _v2d_in("  bmi: missing 0 -> <5 (+<5)", 1)
    * 401 -> 402 distinct dates: the delta is masked, the count beside it
    * withheld; the range only as changed
    mata: _v2d_line("  exitd: distinct [suppressed] -> 402 (+<5); range changed")
    mata: _v2d_line("  edu: missing [suppressed] -> 278 (+<5)")
    mata: _v2d_in("2070", 0)
    mata: _v2d_in("delta 2", 0)
    * without masking: the counts and the range
    capture log close d5
    log using d5b.log, replace text name(d5)
    dataprobe, diff(base) gatesonly
    log close d5
    mata: _v2d_slurp("d5b.log", "t")
    mata: _v2d_in("  bmi: missing 0 -> 3 (+3)", 1)
    mata: _v2d_line("  N: current 3002, baseline 3000, delta 2")
    quietly summarize exitd
    local mx = string(r(max), "%td")
    mata: _v2d_in("; range 01jan2020 to 01jun2070 -> 01jan2020 to `mx'", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D5 diff() masking (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D5 diff() masking"
}

**# D6 F6 tol()
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) gatesonly
    quietly replace bmi = bmi * (1 + 1e-10)
    quietly dataprobe, diff(base) gatesonly
    assert r(diff_changed) == 0
    quietly dataprobe, diff(base) gatesonly tol(0)
    assert "`r(diff_stat_changed_vars)'" == "bmi" & r(diff_tol) == 0
    use person, clear
    _v2d_perturb
    quietly dataprobe, diff(base) gatesonly tol(1e-8 30)
    assert "`r(diff_missing_changed_vars)'" == "edu" & r(diff_ctol) == 30
    capture dataprobe, gatesonly tol(0)
    assert _rc == 198
    capture dataprobe, diff(base) gatesonly tol(-1)
    assert _rc == 125
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D6 tol() (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D6 tol()"
}

**# D7 F6: a plain dataset and a datamap saving() file as baselines
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    _v2d_perturb
    capture log close d7
    log using d7.log, replace text name(d7)
    dataprobe, diff(person.dta) gatesonly
    assert r(diff_schema_only) == 1 & r(diff_changed) == 3
    assert `"`r(diff_baseline)'"' == "person.dta"
    log close d7
    mata: _v2d_slurp("d7.log", "t")
    mata: _v2d_block("DIFF", "got")
    assert `"`got'"' == "DIFF|  baseline: person.dta|  N: current 3150, baseline 3000, delta 150|  key lopnr: unknown before, not unique after (150 surplus rows)|  age: dropped (int)|  dead: type byte -> str1|  newv: added (float, continuous)"
    * a datamap saving() file (strL missing_codes and candidates)
    use person, clear
    quietly datamap, output(dm.md) saving(dm.dta, replace) quality
    use dm.dta, clear
    confirm strL variable missing_codes candidates
    use person, clear
    quietly replace bmi = . in 2001/2026
    quietly dataprobe, diff(dm.dta) gatesonly
    assert "`r(diff_missing_changed_vars)'" == "bmi" & r(diff_schema_only) == 0
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D7 plain dataset and datamap saving() baselines (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D7 plain dataset and datamap saving() baselines"
}

**# D8 W1: keyset() preflight
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture log close d8
    log using d8.log, replace text name(d8)
    capture noisily dataprobe, gatesonly keyset(lopnr using rx)
    local krc = _rc
    assert missing(r(keyset_only_master)) & "`r(keyset_merge)'" == "conflict"
    log close d8
    assert `krc' == 9
    mata: _v2d_slurp("d8.log", "t")
    mata: _v2d_line("KEYSET PREFLIGHT: lopnr using rx")
    mata: _v2d_line("  types: lopnr long in memory, str12 in rx")
    mata: _v2d_in("keyset(lopnr): equal — type conflict: lopnr long in memory, str12 in rx", 1)
    mata: _v2d_in("  keys: ", 0)
    * same types: the printed counts against an actual merge
    capture log close d8
    log using d8b.log, replace text name(d8)
    capture noisily dataprobe, gatesonly keyset(lopnr using rx2, subset) warn
    assert r(keyset_matched) == 2990 & "`r(keyset_merge)'" == "1:m"
    log close d8
    merge 1:m lopnr using rx2
    quietly count if _merge == 3
    local m3 = r(N)
    quietly count if _merge == 1
    local m1 = r(N)
    quietly count if _merge == 2
    local m2 = r(N)
    tempvar t1
    quietly bysort lopnr: generate byte `t1' = _n == 1
    quietly count if `t1' & _merge == 3
    local k3 = r(N)
    quietly count if `t1' & _merge == 1
    local k1 = r(N)
    mata: _v2d_slurp("d8b.log", "t")
    mata: _v2d_line("  types: lopnr long in memory, long in rx2")
    mata: _v2d_line("  unique: memory yes, rx2 no; merge 1:m")
    mata: _v2d_line("  keys: `k3' matched, `k1' memory only, 0 rx2 only")
    mata: _v2d_line("  merge 1:m would report: `m3' matched, `m1' master only, `m2' using only")
    mata: _v2d_line("  shared non-key variables: sex")
    * m:1 and 1:1
    use rx2, clear
    quietly dataprobe, gatesonly keyset(lopnr using person, subset)
    assert "`r(keyset_merge)'" == "m:1"
    use person, clear
    quietly dataprobe, gatesonly keyset(lopnr using person)
    assert "`r(keyset_merge)'" == "1:1" & r(keyset_matched) == 3000
    * masking: 3 keys only in memory print as <5
    use person, clear
    quietly drop if lopnr > 102993
    capture log close d8
    log using d8c.log, replace text name(d8)
    capture noisily dataprobe, gatesonly keyset(lopnr using rx2, subset) maskrare warn
    log close d8
    mata: _v2d_slurp("d8c.log", "t")
    * 2026-11-10 (2.0.0 review fix): the matched key count printed exactly
    * beside a masked memory-only count gave it back by subtraction from the
    * distinct keys (2993 - 2990 = 3), so it is now "all but <5".  The
    * matched row count stays exact: in a 1:m merge it is the file's
    * matched rows, and nothing printed takes it from a small cell.
    mata: _v2d_line("  keys: all but <5 matched, <5 memory only, 0 rx2 only")
    mata: _v2d_line("  merge 1:m would report: 8970 matched, <5 master only, 0 using only")
    mata: _v2d_in("2990 matched", 0)
    * 1:1, 98 of 100 keys in the file: neither matched count prints
    clear
    quietly set obs 100
    generate long id = _n
    quietly save m100, replace
    quietly keep if id <= 98
    quietly save u98, replace
    * the file holds 3 of memory's keys and 50 others
    clear
    quietly set obs 53
    generate long id = cond(_n <= 3, _n, 1000 + _n)
    quietly save u3, replace
    use m100, clear
    capture log close d8
    log using d8d.log, replace text name(d8)
    capture noisily dataprobe, gatesonly keyset(id using u98) maskrare warn
    assert r(keyset_matched) == 98
    capture noisily dataprobe, gatesonly keyset(id using u3) maskrare warn
    assert r(keyset_matched) == 3
    capture noisily dataprobe, keyset(id using u98) safe
    log close d8
    mata: _v2d_slurp("d8d.log", "t")
    mata: _v2d_line("  keys: all but <5 matched, <5 memory only, 0 u98 only")
    mata: _v2d_line("  merge 1:1 would report: all but <5 matched, <5 master only, 0 using only")
    mata: _v2d_line("  keys: <5 matched, all but <5 memory only, all but <5 u3 only")
    mata: _v2d_line("  merge 1:1 would report: <5 matched, all but <5 master only, all but <5 using only")
    mata: _v2d_in("98 matched", 0)
    mata: _v2d_in("97 keys", 0)
    mata: _v2d_in("50 keys", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D8 keyset() preflight (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D8 keyset() preflight"
}

**# D9 I1: makespec(file.do)
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    generate str4 city = cond(mod(_n, 2), "ab", "c d")
    quietly save person_c, replace
    quietly dataprobe lopnr sex bmi city, makespec(spec.do, replace) gatesonly
    quietly dataprobe lopnr sex bmi city, makespec(spec.dta, replace) gatesonly
    mata: _v2d_slurp("spec.do", "t")
    mata: _v2d_line("dataprobe, gatesonly ///")
    mata: _v2d_line("    expectn(3000 3000) ///")
    mata: _v2d_line("    isid(lopnr) ///")
    mata: _v2d_line("    require(lopnr sex bmi city) ///")
    mata: _v2d_in("    allowed(sex 1 2)", 1)
    mata: _v2d_in("* allowed(): city was left out (a level holds a space", 1)
    * the do-file passes on its data; the .dta spec too
    capture noisily do spec.do
    assert _rc == 0
    capture noisily dataprobe, checks(spec.dta) gatesonly
    assert _rc == 0
    * perturbed data: exit 9
    quietly replace bmi = 2000 in 7
    capture noisily do spec.do
    assert _rc == 9
    use person_c, clear
    quietly drop in 1
    capture noisily do spec.do
    assert _rc == 9
    * an existing do-file without replace: rc 602 before any output
    capture log close d9
    log using d9.log, replace text name(d9)
    capture noisily dataprobe, makespec(spec.do)
    local mrc = _rc
    log close d9
    assert `mrc' == 602
    mata: _v2d_slurp("d9.log", "t")
    mata: _v2d_in("QUICK REFERENCE", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D9 makespec(file.do) (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D9 makespec(file.do)"
}

**# D10 saving(): a note of 2,000 quote, backtick and dollar characters
capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 5
    generate x = _n
    mata: st_global("x[note1]", 500 * (char(34) + char(96) + "$" + "a"))
    char x[note0] 1
    capture erase d10.dta
    dataprobe, saving(d10.dta) gatesonly
    use d10, clear
    mata: st_local("ok", strofreal(st_sdata(1, "notes") == substr(500 * (char(34) + char(96) + "$" + "a"), 1, 2045)))
    assert `ok' == 1
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D10 saving() note of 2,000 special characters (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D10 saving() note of 2,000 special characters"
}

**# D11 F6: an excluded variable gets no distinct count or statistic
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) exclude(lopnr) gatesonly
    quietly replace lopnr = 1 in 1
    quietly replace lopnr = . in 2
    quietly dataprobe, diff(base) exclude(lopnr) gatesonly
    * the missing count is structure; the mean and range are not printed
    assert "`r(diff_missing_changed_vars)'" == "lopnr" & "`r(diff_stat_changed_vars)'" == ""
    assert "`r(diff_unique_changed_vars)'" == ""
    * excluded in the baseline only: a class change, still no statistic
    quietly dataprobe, diff(base) gatesonly
    assert "`r(diff_class_changed_vars)'" == "lopnr" & "`r(diff_stat_changed_vars)'" == ""
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D11 an excluded variable gets no statistic in diff() (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D11 an excluded variable gets no statistic in diff()"
}

**# D12 F6: a key outside the varlist is not "dropped"
* 2026-11-10 (Phase 4 review fix): diff() and compare() printed "key lopnr:
* dropped" when lopnr was only outside the call's varlist; the variable
* lines already judged dropped against the data, not the working copy.
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) gatesonly
    capture log close d12
    log using d12.log, replace text name(d12)
    dataprobe edu bmi, diff(base) gatesonly
    assert "`r(diff_key)'" == "lopnr" & r(diff_key_before) == 1 & missing(r(diff_key_after))
    capture noisily dataprobe edu bmi, compare(base) gatesonly
    assert _rc == 0
    log close d12
    mata: _v2d_slurp("d12.log", "t")
    mata: _v2d_line("  key lopnr: unique before, not checked after (not in the varlist)")
    mata: _v2d_line("  no changes")
    mata: _v2d_in("dropped", 0)
    * dropped from the data: still "dropped"
    drop lopnr
    capture log close d12
    log using d12b.log, replace text name(d12)
    dataprobe edu bmi, diff(base) gatesonly
    log close d12
    mata: _v2d_slurp("d12b.log", "t")
    mata: _v2d_line("  key lopnr: dropped")
    mata: _v2d_line("  lopnr: dropped (long)")
}
local rc = _rc
capture log close d12
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D12 a key outside the varlist is not dropped (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D12 a key outside the varlist is not dropped"
}

**# D13 F6 masking: no mean of a categorical or two/three-valued variable
* 2026-11-10 (Phase 5 review fix): under safe and maskrare, diff() and
* compare() printed "flag: mean .025 -> .0375" for a 0/1 flag held by 2 and
* then 3 of 80 rows: the mean is the share, so it gave the suppressed count
* back.  The mean of a categorical variable, or of one with two or three
* distinct values on either side, now reads "mean changed" under the mask
* (datamap's _datamap_sumpolicy cathide/momhide rule); a many-valued mean
* still prints, and without the mask every mean prints.
capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 80
    generate byte flag = _n <= 2
    generate double three = cond(_n <= 2, 1, cond(_n <= 40, 2, 3))
    generate double x = _n
    capture frame drop base
    * maxcat(2): flag is categorical, three is a three-valued continuous
    quietly dataprobe, snapshot(base) gatesonly safe maxcat(2)
    quietly replace flag = 1 in 3
    quietly replace three = 1 in 3
    quietly replace x = x + 1
    capture frame drop fb
    frame copy base fb
    frame fb: quietly save d13base, replace
    capture log close d13
    log using d13.log, replace text name(d13)
    dataprobe, diff(base) gatesonly safe maxcat(2)
    * the stored results still name the changed means
    assert "`r(diff_stat_changed_vars)'" == "flag three x"
    dataprobe, diff(base) gatesonly maskrare maxcat(2)
    capture noisily dataprobe, compare(d13base.dta) gatesonly maskrare maxcat(2)
    assert _rc == 0
    log close d13
    mata: _v2d_slurp("d13.log", "t")
    mata: _v2d_line("  flag: mean changed")
    mata: _v2d_line("  three: mean changed")
    mata: _v2d_line("  x: mean 40.5 -> 41.5; range changed")
    mata: _v2d_in(".025", 0)
    mata: _v2d_in(".0375", 0)
    mata: _v2d_in("2.475", 0)
    * without the mask: the means, from an independent summarize
    quietly summarize flag, meanonly
    local mf1 = strtrim(string(r(mean), "%12.0g"))
    capture log close d13
    log using d13b.log, replace text name(d13)
    dataprobe, diff(base) gatesonly maxcat(2)
    log close d13
    mata: _v2d_slurp("d13b.log", "t")
    mata: _v2d_line("  flag: mean .025 -> `mf1'")
    mata: _v2d_in("  three: mean 2.475 -> ", 1)
}
local rc = _rc
capture log close d13
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D13 masked diff withholds a share-giving mean (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D13 masked diff withholds a share-giving mean"
}

**# D14 F6: empty data is reported, not refused
* 2026-11-10 (Phase 6 review fix): snapshot(), diff() and compare() on data
* emptied by keep if 0 stopped with r(2000) "no observations" -- the case
* diff() exists for.  The profile is skipped (nothing to profile) and the
* diff lines print; an empty variable is not reported as a class change
* (every empty variable classifies as categorical).
capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    capture frame drop base
    quietly dataprobe, snapshot(base) gatesonly
    keep if 0
    capture log close d14
    log using d14.log, replace text name(d14)
    dataprobe, diff(base)
    assert r(N) == 0 & r(diff_base_N) == 74 & r(diff_n_delta) == -74
    assert "`r(diff_class_changed_vars)'" == ""
    assert strpos(" `r(diff_unique_changed_vars)' ", " price ")
    capture noisily dataprobe, compare(base)
    assert _rc == 9
    capture noisily dataprobe, diff(base) expectn(74)
    assert _rc == 9
    dataprobe, diff(base) expectn(0)
    capture frame drop e0
    dataprobe, snapshot(e0)
    frame e0: local e0N : char _dta[dataprobe_N]
    assert "`e0N'" == "0"
    log close d14
    mata: _v2d_slurp("d14.log", "t")
    mata: _v2d_line("note: no observations; the profile is skipped")
    mata: _v2d_line("  N: current 0, baseline 74, delta -74")
    mata: _v2d_line("  price: distinct 74 -> 0 (-74)")
    mata: _v2d_line("  rep78: missing 5 -> 0 (-5); distinct 5 -> 0 (-5)")
    mata: _v2d_in(": class ", 0)
    mata: _v2d_in("; class ", 0)
    mata: _v2d_in("QUICK REFERENCE", 0)
    mata: _v2d_in("gatesonly with no gates declared", 0)
    * nothing to compare against: still r(2000)
    capture noisily dataprobe, brief
    assert _rc == 2000
    capture noisily dataprobe
    assert _rc == 2000
    * an empty if/in scope with diff(): reported; without: r(2000)
    sysuse auto, clear
    capture log close d14
    log using d14b.log, replace text name(d14)
    dataprobe if price < 0, diff(base)
    assert r(diff_n_delta) == -74
    capture noisily dataprobe if price < 0
    assert _rc == 2000
    * from the empty snapshot back to 74 rows: no class change printed
    dataprobe, diff(e0) gatesonly
    assert "`r(diff_class_changed_vars)'" == "" & r(diff_n_delta) == 74
    log close d14
    mata: _v2d_slurp("d14b.log", "t")
    mata: _v2d_line("note: no observations satisfy if/in; the profile is skipped")
    mata: _v2d_line("  N: current 74, baseline 0, delta 74")
    mata: _v2d_line("  price: distinct 0 -> 74 (+74)")
    mata: _v2d_in(": class ", 0)
    mata: _v2d_in("; class ", 0)
}
local rc = _rc
capture log close d14
capture frame drop e0
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D14 empty data is reported by diff/compare/snapshot (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D14 empty data is reported by diff/compare/snapshot"
}

**# D15 U3: a quoted baseline path with a space
* 2026-11-10 (Phase 6 review fix): saving("my dir/p 1.dta") wrote the file
* but compare() and diff() of the same quoted path were r(198): option
* (string) stripped the quotes, so the target looked like two words.
* compare() and diff() now keep the quotes (asis); an unquoted name with a
* space is still r(198) (D4).
capture noisily {
    quietly cd "`work'/run"
    capture mkdir "sp dir"
    sysuse auto, clear
    dataprobe, saving("sp dir/p 1.dta", replace) gatesonly
    capture log close d15
    log using d15.log, replace text name(d15)
    dataprobe, compare("sp dir/p 1.dta") gatesonly
    assert r(compare_changed) == 0
    dataprobe, diff("sp dir/p 1.dta") gatesonly
    assert r(diff_base_N) == 74 & r(diff_n_delta) == 0
    dataprobe, diff(`"sp dir/p 1.dta"') gatesonly
    capture noisily dataprobe, diff(sp dir) gatesonly
    assert _rc == 198
    capture noisily dataprobe, diff("sp dir/nosuch.dta") gatesonly
    assert _rc == 601
    log close d15
    mata: _v2d_slurp("d15.log", "t")
    mata: _v2d_line("  baseline: sp dir/p 1.dta")
    mata: _v2d_line("diff() accepts one frame name or one Stata dataset filename")
}
local rc = _rc
capture log close d15
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D15 a quoted baseline path with a space (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D15 a quoted baseline path with a space"
}

capture frame drop base
capture frame drop fb
capture frame drop b
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_dataprobe_v200_diff tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
