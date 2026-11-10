*! test_datamap_v200_collector.do Version 1.0.0  2026/11/09
*! datamap 2.0.0 Phase 1: the collector frames (datasets, variables, levels)
*! behind the 1.10.6 writers -- saving() parity with a 1.10.6 fixture, the
*! percent-denominator rule, the frames' contents, and no frame left behind
*! on success or error
*! 2026-11-10 (datamap 2.0.0 Phase 2): datadict and format(json) are removed.  The
*! datadict parity family left the P01-P03 loop (no writer to compare; its
*! fixture is the before-picture); D01/D02 read the one Markdown writer's level
*! cells ("<value> <label>: n (p%)"); F01-F03 run datamap in document mode where
*! they ran datadict, and F01's JSON run is a separate-output run.
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_collector.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
* tempfile names repeat across suites in one runner session: own suffix
local work "`base'_v200cwork"
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

do "`qa_dir'/_qa_collector_parity.do"
do "`qa_dir'/_qa_md.do"

capture mata: mata drop _v200c_cmp()
mata:
// Frame fa against frame fb: the same variables in the same order and the
// same number of rows, then every string cell byte for byte and every number
// exactly (a missing code equals only itself).  Returns the number of
// differing cells (-1: different variables or rows) and prints the first five.
real scalar _v200c_cmp(string scalar fa, string scalar fb)
{
	string scalar cur, v
	string rowvector va, vb
	real scalar k, j, i, na, nb, nbad
	real colvector d
	string colvector sa, sb
	real colvector xa, xb

	cur = st_framecurrent()
	st_framecurrent(fa)
	k = st_nvar()
	na = st_nobs()
	va = J(1, k, "")
	for (j = 1; j <= k; j++) va[j] = st_varname(j)
	st_framecurrent(fb)
	nb = st_nobs()
	vb = J(1, st_nvar(), "")
	for (j = 1; j <= st_nvar(); j++) vb[j] = st_varname(j)
	if (cols(va) != cols(vb) | na != nb) {
		st_framecurrent(cur)
		printf("{err}columns %f vs %f, rows %f vs %f\n", cols(va), cols(vb), na, nb)
		return(-1)
	}
	if (any(va :!= vb)) {
		st_framecurrent(cur)
		printf("{err}variable names or order differ\n")
		return(-1)
	}
	nbad = 0
	for (j = 1; j <= k; j++) {
		v = va[j]
		st_framecurrent(fa)
		if (st_isstrvar(v)) {
			sa = st_sdata(., v)
			st_framecurrent(fb)
			if (!st_isstrvar(v)) d = J(na, 1, 1)
			else {
				sb = st_sdata(., v)
				d = (sa :!= sb)
			}
		}
		else {
			xa = st_data(., v)
			st_framecurrent(fb)
			if (st_isstrvar(v)) d = J(na, 1, 1)
			else {
				xb = st_data(., v)
				d = (xa :!= xb)
			}
		}
		for (i = 1; i <= na; i++) {
			if (d[i]) {
				nbad++
				if (nbad <= 5) printf("{err}differs: row %f, %s\n", i, v)
			}
		}
	}
	st_framecurrent(cur)
	return(nbad)
}
end

* One configuration's saving() file against the 1.10.6 fixture: no data
* label, sort order or characteristic; the 1.10.6 column names, order, types,
* formats and labels; the 1.10.6 values, cell for cell.
capture program drop _v200c_check
program define _v200c_check
    args cfg family qadata
    tempname fa fb sa sb
    frame create `fa'
    frame create `fb'
    frame create `sa'
    frame create `sb'
    frame `fa' {
        quietly use "`cfg'.dta", clear
        * 2.0.0: separate files are <name>_map.md (1.10.6: .txt); nothing else may differ
        if "`cfg'" == "dm5" quietly replace output = subinstr(output, "_map.md", "_map.txt", .)
        * 2026-11-10 (2.0.0 Phase 3, F3): datamap's saving() has a 28th column,
        * missing_codes (the per-code missing breakdown; strL since the
        * 2026-11-10 repair, which keeps a long breakdown whole), after the 27
        * of 1.10.6; dataprobe's has none.  The 27 are compared as before.
        * 2026-11-10 (2.0.0 Phase 3, I2): nine more after missing_codes (the
        * new facts; their list and values are pinned in
        * test_datamap_v200_link.do); dropped here with it, the 27 unchanged.
        if "`family'" == "datamap" {
            unab _v28 : _all
            assert word("`_v28'", 28) == "missing_codes" & wordcount("`_v28'") == 37
            confirm strL variable missing_codes
            drop missing_codes position date_family numeric_n numeric_pct padded_n date_mask is_strl key candidates
        }
        assert `"`: data label'"' == ""
        assert "`: sortedby'" == ""
        local _ch : char _dta[]
        assert "`_ch'" == ""
    }
    frame `sa' {
        quietly use "`cfg'.dta", clear
        if "`family'" == "datamap" drop missing_codes position date_family numeric_n numeric_pct padded_n date_mask is_strl key candidates
        quietly describe, replace clear
        keep position name type format vallab varlab
    }
    frame `sb' {
        quietly use "`qadata'/test_saving_v1106_schema.dta", clear
        quietly keep if family == cond("`family'" == "dataprobe", "dataprobe", "saving27")
        keep position name type format vallab varlab
    }
    frame `sa': mata: st_numscalar("__v200c_bad", _v200c_cmp("`sa'", "`sb'"))
    if scalar(__v200c_bad) != 0 {
        display as error "`cfg': saving() columns differ from 1.10.6"
        exit 9
    }
    frame `fb' {
        quietly use "`qadata'/test_saving_v1106_`family'.dta", clear
        quietly keep if cfg == "`cfg'"
        drop cfg
    }
    frame `fa': mata: st_numscalar("__v200c_bad", _v200c_cmp("`fa'", "`fb'"))
    if scalar(__v200c_bad) != 0 {
        display as error "`cfg': " scalar(__v200c_bad) " saving() cells differ from 1.10.6"
        exit 9
    }
    frame `fa': display as text "`cfg': " _N " rows identical to 1.10.6"
end

* The 14 parity runs, once, in their own directory (relative names, so the
* source and output columns match the fixture wherever the suite runs)
local qadata "`qa_dir'/data"
local cwd0 "`c(pwd)'"
quietly cd "`work'/run"
capture noisily _qacp_run
local run_rc = _rc
local c_datamap "`r(datamap)'"
local c_dataprobe "`r(dataprobe)'"

**# P01-P03 saving() identical to 1.10.6, column for column and cell for cell

* Phase 1 moves saving() onto the collector's variables frame
* (_datamap_post_metadata_rows, create/post/save); the 27 columns must be
* what 1.10.6 wrote.  Fixture: _qa_collector_parity.do run by datamap 1.10.6.
foreach fam in datamap dataprobe {
    capture noisily {
        assert `run_rc' == 0
        assert "`c_`fam''" != ""
        foreach c of local c_`fam' {
            _v200c_check `c' `fam' "`qadata'"
        }
    }
    local rc = _rc
    local ++tests
    if `rc' {
        local ++fail
        display as error "FAIL: `fam' saving() identical to the 1.10.6 fixture (`c_`fam'') (rc=`rc')"
    }
    else {
        local ++pass
        display as result "PASS: `fam' saving() identical to the 1.10.6 fixture (`c_`fam'')"
    }
}

**# D01 the percent-denominator rule: N counts every observation

* 2026-11-09, datamap 2.0.0: datadict printed a level's share of the
* nonmissing rows (grp 9 of 36 = 25.0%); every writer now prints the levels
* frame's share of all rows (9 of 40 = 22.5%), as datamap's text map always
* did.  Separate and combined files: the second file's own counts (5 and 6 of
* 25) show the levels are read per dataset, not from the first file's rows.
* 2026-11-10: the datadict files (dd2, dd3, dd5, par_in*_dictionary) are the
* datamap documents (dm1, dm3, dm4, dm5's par_in*_map.md) and the cells are
* "<value> <label>: n (p%)".
* 2026-11-10 (Phase 2 repair round 2): grp's Missing total (. 1 + .a 3 = 4)
* is below mincell(5), so the Missing cell is withheld and the smallest
* level, 1 Alpha (first of the tied 9s), is its complement.  The 22.5%
* needle moved to 3 Gamma; the share-of-N intent is unchanged.
capture noisily {
    assert `run_rc' == 0
    tempname fh
    foreach pair in "dm1.txt|3 Gamma: 9 (22.5%)" "dm4.txt|9 (22.5%)" "dm4.txt|5 (20.0%)" ///
        "dm4.txt|6 (24.0%)" "par_in_map.md|3 Gamma: 9 (22.5%)" ///
        "par_in2_map.md|5 (20.0%)" "par_in2_map.md|6 (24.0%)" ///
        `"dm3.txt|"z&#36;x": 23 (57.5%)"' {
        gettoken f needle : pair, parse("|")
        local needle = substr(`"`needle'"', 2, .)
        qa_md_contains using "`f'", needle(`"`needle'"')
        if r(n) == 0 display as error `"`f' lacks `needle'"'
        assert !missing(r(n))
        assert r(n) >= 1
    }
    * and the 1.10.6 nonmissing-denominator shares are gone
    foreach pair in "dm3.txt|9 (25.0%)" "par_in2_map.md|5 (23.8%)" ///
        "dm3.txt|23 (59.0%)" {
        gettoken f needle : pair, parse("|")
        local needle = substr(`"`needle'"', 2, .)
        qa_md_contains using "`f'", needle(`"`needle'"')
        assert r(n) == 0
    }
}
local rc = _rc
capture file close `fh'
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: every document prints the share of N with missing rows (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: every document prints the share of N with missing rows"'
}
quietly cd "`cwd0'"

* Does file f hold needle on some line?  r(hit) 1/0
capture program drop _v200c_has
program define _v200c_has, rclass
    args f needle
    qa_md_contains using `"`f'"', needle(`"`needle'"')
    return scalar hit = r(found)
end

**# D02 denominator against count-if oracles, with extended missing codes

* 2026-11-10 (Phase 1 QA).  Every expected count is a `count if` on the data
* and every expected share is 100 * that count / _N, where _N includes the
* rows holding . and .a-.z; nothing is read from the package.  Three
* variables: a labelled byte with .a, .b, .c and . (and 3 unlabelled); a
* double with .d and .; a string with blanks.  The levels frame must hold one
* row per listed level with exactly that count and share, the missing-code
* rows included, and the shares of each variable must sum to 100.  datadict's
* document cells must print the same shares (2.0.0: one writer),
* and never the 1.10.6 share of the nonmissing rows.
capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 60
    gen byte ext = 1 + mod(_n, 3)
    quietly replace ext = .a in 1/5
    quietly replace ext = .b in 6/9
    quietly replace ext = .c in 10
    quietly replace ext = . in 11/13
    label define d02L 1 "One" 2 "Two" .a "Refused" .b "NotAsked"
    label values ext d02L
    gen double dbl = mod(_n, 4) * 0.5
    quietly replace dbl = .d in 1/2
    quietly replace dbl = . in 3
    gen str6 st = cond(mod(_n, 2), "x", "y")
    quietly replace st = "" in 1/6
    local N = _N
    tempname L
    _datamap_collect_levels, create frame(`L')
    _datamap_collect_levels ext dbl st, frame(`L') dsindex(1) maxlevels(25) mincell(0)
    local lev_ext "1 2 3 .a .b .c ."
    local lev_dbl "0 .5 1 1.5 .d ."
    foreach v in ext dbl {
        local sumshare = 0
        local sumcount = 0
        foreach lv of local lev_`v' {
            quietly count if `v' == `lv'
            local want_n = r(N)
            assert `want_n' > 0
            local want_sh = 100 * `want_n' / `N'
            frame `L' {
                quietly count if variable == "`v'" & value == `lv'
                assert r(N) == 1
                quietly summarize count if variable == "`v'" & value == `lv'
                assert r(sum) == `want_n'
                quietly summarize share if variable == "`v'" & value == `lv'
                assert !missing(r(sum), `want_sh')
                assert reldif(r(sum), `want_sh') < 1e-12
                quietly summarize is_missing_code if variable == "`v'" & value == `lv'
                assert r(sum) == (`lv' >= .)
            }
            local sumshare = `sumshare' + `want_sh'
            local sumcount = `sumcount' + `want_n'
        }
        assert `sumcount' == `N'
        assert !missing(`sumshare')
        assert reldif(`sumshare', 100) < 1e-12
        local nl : word count `lev_`v''
        frame `L' {
            quietly count if variable == "`v'"
            assert r(N) == `nl'
        }
    }
    foreach lv in x y "" {
        quietly count if st == "`lv'"
        local want_n = r(N)
        frame `L' {
            quietly count if variable == "st" & value_str == "`lv'"
            assert r(N) == 1
            quietly summarize count if variable == "st" & value_str == "`lv'"
            assert r(sum) == `want_n'
            quietly summarize share if variable == "st" & value_str == "`lv'"
            assert !missing(r(sum), 100 * `want_n' / `N')
            assert reldif(r(sum), 100 * `want_n' / `N') < 1e-12
        }
    }
    frame `L' {
        quietly count if variable == "st"
        assert r(N) == 3
    }
    * the document cell: n of _N, not of the nonmissing rows
    quietly datamap, output(d02.md) mincell(0) categorical(dbl st)
    foreach lv in 1 2 3 {
        quietly count if ext == `lv'
        local n = r(N)
        local sh = trim(string(100 * `n' / `N', "%9.1f"))
        local nm = 100 * `n' / (`N' - 13)
        assert abs(`nm' - 100 * `n' / `N') > 1
        local nmsh = trim(string(`nm', "%9.1f"))
        local lab = cond(`lv' == 1, " One", cond(`lv' == 2, " Two", ""))
        local cell_`lv' "`lv'`lab': `n' (`sh'%)"
        local bad_`lv' ": `n' (`nmsh'%)"
    }
    foreach lv in 0 .5 1 1.5 {
        quietly count if dbl == `lv'
        local n = r(N)
        local k = subinstr("`lv'", ".", "p", 1)
        local dcell_`k' "<br>`lv': `n' (`=trim(string(100 * `n' / `N', "%9.1f"))'%)"
        local dbad_`k' ": `n' (`=trim(string(100 * `n' / (`N' - 3), "%9.1f"))'%)"
    }
    foreach lv in x y {
        quietly count if st == "`lv'"
        local n = r(N)
        local scell_`lv' `""`lv'": `n' (`=trim(string(100 * `n' / `N', "%9.1f"))'%)"'
        local sbad_`lv' ": `n' (`=trim(string(100 * `n' / (`N' - 6), "%9.1f"))'%)"
    }
    foreach lv in 1 2 3 {
        _v200c_has d02.md "`cell_`lv''"
        assert r(hit) == 1
        _v200c_has d02.md "`bad_`lv''"
        assert r(hit) == 0
    }
    foreach lv in 0 p5 1 1p5 {
        * the first level of dbl starts the cell ("| 0: ..."), the others follow a <br>
        local dc "`dcell_`lv''"
        if "`lv'" == "0" local dc = subinstr("`dc'", "<br>", "| ", 1)
        _v200c_has d02.md "`dc'"
        assert r(hit) == 1
        _v200c_has d02.md "`dbad_`lv''"
        assert r(hit) == 0
    }
    foreach lv in x y {
        _v200c_has d02.md `"`scell_`lv''"'
        assert r(hit) == 1
        _v200c_has d02.md "`sbad_`lv''"
        assert r(hit) == 0
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: shares equal count-if over N with extended missing rows, in the frame and the document (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: shares equal count-if over N with extended missing rows, in the frame and the document"'
}

**# L01 levels frame: values, labels, counts, shares, masks, missing rows

* Hand counts on _qacp_data (40 rows): grp levels 1-4 nine each, . once,
* .a three times; sc "a`b" 8, say "hi" 8, z$x 23, "" once; rare 0 37 and 1 3
* (3 < 5 suppressed, 37 withheld as its complement); id 40 values (over
* maxlevels(25): no rows); allm all missing (its one missing row only).
capture noisily {
    _qacp_data
    gen byte allm = .
    tempname L
    _datamap_collect_levels, create frame(`L')
    _datamap_collect_levels grp sc rare id allm fx, frame(`L') dsindex(7) ///
        maxlevels(25) mincell(5)
    assert c(frame) == "default"
    frame `L' {
        assert ds_index == 7
        quietly count if variable == "id"
        assert r(N) == 0
        * grp: four levels then . and .a
        preserve
        quietly keep if variable == "grp"
        assert _N == 6
        assert level == _n
        assert value[1] == 1 & value[4] == 4 & value[5] == . & value[6] == .a
        assert count == 9 in 1/4
        assert count[5] == 1 & count[6] == 3
        assert share == 100 * count / 40
        assert is_missing_code == (_n >= 5)
        * 2026-11-10 (Phase 2 repair round 2): the Missing total (1 + 3 = 4)
        * is a cell of the level mask: below mincell(5), so the missing-code
        * rows carry suppressed 1, and level 1 (smallest, first of the tied
        * 9s) is withheld as its complement.  Was: no row flagged.
        assert suppressed == (_n == 1 | _n >= 5)
        assert complementary == (_n == 1)
        quietly summarize share
        assert !missing(r(sum))
        assert reldif(r(sum), 100) < 1e-12
        assert label[1] == "Alpha" & label[6] == "Refused" & label[5] == ""
        mata: assert(st_sdata(2, "label") == "Beta " + char(34) + "q" + char(34) + " " + char(96) + "t" + char(39) + " " + char(36) + "x")
        restore
    }
    frame `L' {
        preserve
        quietly keep if variable == "sc"
        assert _N == 4
        mata: assert(st_sdata(., "value_str") == ("a" + char(96) + "b" \ "say " + char(34) + "hi" + char(34) \ "z" + char(36) + "x" \ ""))
        assert count[1] == 8 & count[2] == 8 & count[3] == 23 & count[4] == 1
        assert missing(value)
        assert is_missing_code == (_n == 4)
        assert share == 100 * count / 40
        restore
    }
    frame `L' {
        preserve
        quietly keep if variable == "rare"
        assert _N == 2
        assert value[1] == 0 & count[1] == 37 & suppressed[1] == 1 & complementary[1] == 1
        assert value[2] == 1 & count[2] == 3 & suppressed[2] == 1 & complementary[2] == 0
        restore
    }
    frame `L' {
        preserve
        quietly keep if variable == "allm"
        assert _N == 1
        assert is_missing_code == 1 & count == 40 & share == 100
        restore
    }
    frame `L' {
        preserve
        quietly keep if variable == "fx"
        assert _N == 3
        assert value[2] == float(.1) & value[3] == float(.2)
        assert count[1] == 13 & count[2] == 14 & count[3] == 13
        restore
    }
    * no observations: no rows
    tempname L0
    _datamap_collect_levels, create frame(`L0')
    preserve
    quietly drop in 1/l
    _datamap_collect_levels grp sc, frame(`L0') dsindex(1)
    restore
    frame `L0': assert _N == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: levels frame rows against hand counts (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: levels frame rows against hand counts"'
}

**# L02 datasets frame row; variables frame keys; the saving() writer

capture noisily {
    _qacp_data
    quietly datasignature
    local want_sig "`r(datasignature)'"
    local want_chg = c(changed)
    tempname D V
    _datamap_collect_dataset, create frame(`D')
    _datamap_collect_dataset, frame(`D') sourcecommand("datamap") source("memory") ///
        dsname("memory") output("x.txt") signature(soft)
    assert r(ds_index) == 1
    _datamap_collect_dataset, frame(`D') sourcecommand("datamap") source("memory") ///
        dsname("memory") output("x.txt")
    assert r(ds_index) == 2
    frame `D' {
        assert _N == 2 & ds_index == _n
        assert N == 40 & nvars == 11
        assert datasignature[1] == "`want_sig'" & datasignature[2] == ""
        assert changed == `want_chg'
        assert sortlist == ""
        mata: assert(st_sdata(1, "label") == "Fixture " + char(34) + "data" + char(34) + " label")
    }
    * variables frame: one row per variable, keyed by dataset and position
    tempfile cls
    _datamap_classify using "memory", loaded saving("`cls'") maxcat(25)
    _datamap_post_metadata_rows, create frame(`V')
    _datamap_post_metadata_rows, frame(`V') dsindex(2) classifications("`cls'") ///
        sourcecommand("datamap") source("memory") dsname("memory") nvars(11)
    frame `V' {
        assert _N == 11
        assert ds_index == 2 & position == _n
        assert variable[1] == "id" & variable[11] == "pnr"
        assert class[2] == "categorical"
    }
    _datamap_post_metadata_rows, frame(`V') savefile("`work'/v_save.dta") replace
    frame `V': assert _N == 11
    preserve
    quietly use "`work'/v_save.dta", clear
    quietly describe
    * 2026-11-10 (2.0.0 Phase 3, F3): 27 columns of 1.10.6 plus missing_codes
    * 2026-11-10 (2.0.0 Phase 3, I2): and the nine new-fact columns after it
    assert r(k) == 37 & r(N) == 11
    unab _vs : _all
    assert word("`_vs'", 28) == "missing_codes"
    assert word("`_vs'", 37) == "candidates"
    capture confirm variable ds_index
    assert _rc == 111
    restore
    * the modes refuse a missing target
    capture _datamap_post_metadata_rows, create
    assert _rc == 198
    capture _datamap_post_metadata_rows, frame(`V') postname(x) classifications("`cls'") ///
        sourcecommand("datamap") nvars(11)
    assert _rc == 198
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: datasets frame row, variables frame keys, saving() writer (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: datasets frame row, variables frame keys, saving() writer"'
}

**# F01 no frame left behind, current frame kept, on success

* Run from a user frame that is not the default, with another user frame
* present: afterwards the same frames exist and the same frame is current.
capture noisily {
    capture frame drop v200c_user
    capture frame drop v200c_other
    frame create v200c_other
    frame create v200c_user
    frame change v200c_user
    _qacp_data
    quietly datasignature
    local sig0 "`r(datasignature)'"
    quietly frames dir
    local fr0 "`r(frames)'"
    quietly datamap, output("`work'/f01.txt") saving("`work'/f01m", replace)
    quietly datamap, output("`work'/f01d.md") title("T") notes("n") saving("`work'/f01d", replace)
    quietly datamap, output("`work'/f01s.md") separate saving("`work'/f01j", replace)
    quietly frames dir
    assert "`r(frames)'" == "`fr0'"
    assert c(frame) == "v200c_user"
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    frame change default
    frame drop v200c_user
    frame drop v200c_other
}
local rc = _rc
capture frame change default
capture frame drop v200c_user
capture frame drop v200c_other
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: collector frames dropped, current frame kept, on success (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: collector frames dropped, current frame kept, on success"'
}

**# F02 no frame left behind, current frame kept, on error

* The second file of a filelist() is not a dataset: the first is documented
* (its rows posted to all three frames), then the run fails.  The frames go,
* the user's frame stays current, the user's data are untouched, and no
* saving() file is written.
capture noisily {
    quietly cd "`work'/run"
    tempname fh
    file open `fh' using "notdta.dta", write text replace
    file write `fh' "this is not a Stata dataset" _n
    file close `fh'
    capture frame drop v200c_user
    frame create v200c_user
    frame change v200c_user
    sysuse auto, clear
    quietly datasignature
    local sig0 "`r(datasignature)'"
    quietly frames dir
    local fr0 "`r(frames)'"
    capture erase "f02m.dta"
    capture erase "f02d.dta"
    capture noisily datamap, filelist(par_in notdta) output(f02.txt) saving(f02m, replace)
    assert _rc != 0
    quietly frames dir
    assert "`r(frames)'" == "`fr0'"
    assert c(frame) == "v200c_user"
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    capture confirm file "f02m.dta"
    assert _rc == 601
    capture noisily datamap, filelist(par_in notdta) output(f02.md) title("T") saving(f02d, replace)
    assert _rc != 0
    quietly frames dir
    assert "`r(frames)'" == "`fr0'"
    assert c(frame) == "v200c_user"
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    capture confirm file "f02d.dta"
    assert _rc == 601
    * an error inside a collector: the current frame comes back
    capture noisily _datamap_collect_levels nosuchvar, frame(nosuchframe) dsindex(1)
    assert _rc == 111
    assert c(frame) == "v200c_user"
    frame change default
    frame drop v200c_user
}
local rc = _rc
capture file close `fh'
capture frame change default
capture frame drop v200c_user
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: collector frames dropped, current frame kept, data unchanged, on error (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: collector frames dropped, current frame kept, data unchanged, on error"'
}

**# F03 more error exits: no frame left, current frame kept, no saving() file

* 2026-11-10 (Phase 1 QA).  The failures land at different points: a bad
* option and a missing single() file before any collection, an existing
* saving() file without replace after the data are collected.
capture noisily {
    quietly cd "`work'/run"
    capture frame drop v200c_user
    frame create v200c_user
    frame change v200c_user
    _qacp_data
    quietly datasignature
    local sig0 "`r(datasignature)'"
    quietly frames dir
    local fr0 "`r(frames)'"
    quietly datamap, output(f03a.txt) saving(f03keep, replace)
    quietly datamap, output(f03a.md) title("T") saving(f03keepd, replace)
    local nerr = 0
    foreach call in ///
        "datamap, nosuchoption" ///
        "datamap, title(T) nosuchoption" ///
        "datamap, single(no_such_file_here) output(f03b.txt)" ///
        "datamap, single(no_such_file_here) output(f03b.md) title(T)" ///
        "datamap, output(f03c.txt) saving(f03keep)" ///
        "datamap, output(f03c.md) title(T) saving(f03keepd)" {
        capture `call'
        assert _rc != 0
        local ++nerr
        quietly frames dir
        assert "`r(frames)'" == "`fr0'"
        assert c(frame) == "v200c_user"
        quietly datasignature
        assert "`r(datasignature)'" == "`sig0'"
    }
    assert `nerr' == 6
    * the existing saving() files were not touched
    preserve
    quietly use f03keep.dta, clear
    assert _N == 11
    quietly use f03keepd.dta, clear
    assert _N == 11
    restore
    frame change default
    frame drop v200c_user
}
local rc = _rc
capture frame change default
capture frame drop v200c_user
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: six error exits leave no frame, keep the current frame and the data (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: six error exits leave no frame, keep the current frame and the data"'
}

**# I01 the new helpers install with the package

capture noisily {
    foreach h in _datamap_collect_dataset _datamap_collect_levels _datamap_post_metadata_rows {
        quietly findfile `h'.ado
        assert strpos(`"`r(fn)'"', "`work'/plus") == 1
    }
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: collector helpers resolve from the installed package (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: collector helpers resolve from the installed package"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_collector tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
