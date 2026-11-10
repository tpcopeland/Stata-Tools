*! validation_datamap_fixture_primitives.do -- exact metadata/code/text and full caller contracts
*! Author: Timothy P Copeland, Karolinska Institutet
* 2026-11-10 (datamap 2.0.0): datadict and format(json) are removed.  The three
* "JSON exact schema/values" tests now read datamap's Markdown (same fixtures,
* same expected counts, through _qa_md.do); the three "Dictionary" tests run on
* datamap's saving() table (r(nobs)/r(nvars) became r(nobs)/r(nvars),
* the stats option is gone).  JSON-specific escaping is not asserted any
* more: the writer no longer exists.
version 16.0
clear all
set more off
capture log close _all
log using validation_datamap_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
do _qa_md.do
local tests 0
local pass 0
local fail 0

* strings test oracle (Mata: the corpus strings hold backticks and quotes that
* a macro would mangle).  Finds the caption row, requires each corpus string,
* escaped, as one `"<value>": 1 (2.5%)` entry, exactly nine entries, and the
* Missing cell 31 (77.5%).
mata:
void _qa_prim_check(string scalar f, string scalar names)
{
    string colvector L
    string rowvector nm
    string scalar row, tok, v
    real scalar i, ok, k
    L = cat(f)
    row = ""
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 13) == "| " + char(96) + "caption" + char(96) + " |") row = L[i]
    }
    ok = (row != "")
    nm = tokens(names)
    for (k = 1; k <= cols(nm); k++) {
        v = st_global(nm[k])
        v = subinstr(v, char(92), char(92) + char(92))
        v = subinstr(v, char(36), "&#36;")
        v = subinstr(v, char(96), "&#96;")
        tok = char(34) + v + char(34) + ": 1 (2.5%)"
        ok = ok & strpos(row, tok) > 0
    }
    ok = ok & strpos(row, "| 31 (77.5%) |") > 0
    ok = ok & ((ustrlen(row) - ustrlen(subinstr(row, "<br>", ""))) == 8 * 4)
    st_numscalar("__qa_prim_ok", ok)
}
end

**# names Markdown exact schema/values
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempfile output
    qa_state_snapshot, tag(dm_primitive)
    quietly datamap, output(`"`output'"') mincell(0) maxcat(100) maxfreq(100)
    assert r(nfiles)==1 & r(nobs)==20 & r(nvars)==4
    qa_state_compare, tag(dm_primitive)
    * Markdown oracle: exactly the four variables, each with its two (or twenty)
    * levels and counts as built into the fixture (y 0/2 x10, Y -9/11 x10,
    * the 32-character names 1..20 and -20..-1 once each)
    qa_md_contains using `"`output'"', needle("- Observations: 20") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==4
    qa_md_rows using `"`output'"', var(y) cell("0: 10 (50.0%)<br>2: 10 (50.0%)")
    assert r(n)==1
    qa_md_rows using `"`output'"', var(Y) cell("-9: 10 (50.0%)<br>11: 10 (50.0%)")
    assert r(n)==1
    local cellA ""
    local cellB ""
    forvalues i = 1/20 {
        local sep = cond(`i'==1, "", "<br>")
        local cellA "`cellA'`sep'`i': 1 (5.0%)"
        local j = 21 - `i'
        local cellB "`cellB'`sep'-`j': 1 (5.0%)"
    }
    qa_md_rows using `"`output'"', var(abcdefghijklmnopqrstuvwxyz_1234a) cell("`cellA'")
    assert r(n)==1
    qa_md_rows using `"`output'"', var(abcdefghijklmnopqrstuvwxyz_1234b) cell("`cellB'")
    assert r(n)==1
}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: names Markdown exact schema/values rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names Markdown exact schema/values"
}

**# names saving() exact row identities
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempfile output metadata
    qa_state_snapshot, tag(dd_primitive)
    quietly datamap, output(`"`output'"') saving(`"`metadata'"', replace) mincell(0) maxcat(100) maxfreq(100) uniqcap(0)
    assert r(nfiles)==1 & r(nobs)==20 & r(nvars)==4
    qa_state_compare, tag(dd_primitive)
    preserve
    quietly use `"`metadata'"', clear
    assert _N==4 & N==20 & nvars==4
    python: assert set(__import__("sfi").Data.get(var="variable",missingval=None))==set("y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b".split())
    assert mean==1 & unique==2 if inlist(variable,"y","Y")
    assert mean==10.5 & unique==20 if variable=="abcdefghijklmnopqrstuvwxyz_1234a"
    assert mean==-10.5 & unique==20 if variable=="abcdefghijklmnopqrstuvwxyz_1234b"
    restore

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: names saving() exact row identities rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names saving() exact row identities"
}

**# names QC exact schema gates
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    qa_state_snapshot, tag(dc_primitive)
    quietly dataprobe, gatesonly expectn(20) require(y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b)
    assert r(N)==20 & r(n_checks)==2 & r(n_passed)==2 & r(n_failed)==0
    qa_state_compare, tag(dc_primitive)

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: names QC exact schema gates rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names QC exact schema gates"
}

**# names Missingness exact complete rows
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    qa_state_snapshot, tag(dmv_primitive)
    quietly datamvp y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b, nodrop
    assert r(N)==20 & r(N_complete)==20 & r(N_incomplete)==0
    assert r(N_mv_total)==0 & r(max_miss)==0 & r(mean_miss)==0
    qa_state_compare, tag(dmv_primitive)

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: names Missingness exact complete rows rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names Missingness exact complete rows"
}

**# names Ledger actual assertion and release
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempfile ledger release
    quietly dataprobe, gatesonly expectn(20) ledger(`"`ledger'"', run(primitive)) name(actual) maskrare mincell(5)
    assert r(n_checks)==1 & r(n_passed)==1
    qa_state_snapshot, tag(dqa_primitive)
    quietly dataqa assert using `"`ledger'"', run(primitive) expect(actual)
    assert r(N)==1 & r(n_failed)==0
    qa_state_compare, tag(dqa_primitive)
    qa_state_snapshot, tag(dqa_primitive)
    quietly dataqa export using `"`ledger'"', run(primitive) saving(`"`release'"') threshold(5)
    local published `"`r(saving)'"'
    assert r(N)==1 & r(n_scope_dropped)==0
    qa_state_compare, tag(dqa_primitive)
    preserve
    quietly use `"`published'"', clear
    assert _N==1 & family=="expectn" & status=="pass" & observed_num==20 & n_scope==20
    restore
    erase `"`published'"'

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: names Ledger actual assertion and release rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names Ledger actual assertion and release"
}

**# codes Markdown exact schema/values
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    tempfile output
    qa_state_snapshot, tag(dm_primitive)
    quietly datamap, output(`"`output'"') mincell(0) maxcat(100) maxfreq(100)
    assert r(nfiles)==1 & r(nobs)==15 & r(nvars)==2
    qa_state_compare, tag(dm_primitive)
    * Markdown oracle: 3,000,000,000 and 3,000,000,001 stay two levels (a lossy
    * display format would print both alike), three rows each; y is 1..15
    qa_md_contains using `"`output'"', needle("- Observations: 15") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==2
    qa_md_rows using `"`output'"', var(code) ///
        cell("-7: 3 (20.0%)<br>2: 3 (20.0%)<br>20: 3 (20.0%)<br>3000000000: 3 (20.0%)<br>3000000001: 3 (20.0%)")
    assert r(n)==1
    local cellY ""
    forvalues i = 1/15 {
        local sep = cond(`i'==1, "", "<br>")
        local cellY "`cellY'`sep'`i': 1 (6.7%)"
    }
    qa_md_rows using `"`output'"', var(y) cell("`cellY'")
    assert r(n)==1
}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: codes Markdown exact schema/values rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes Markdown exact schema/values"
}

**# codes saving() exact row identities
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    tempfile output metadata
    qa_state_snapshot, tag(dd_primitive)
    quietly datamap, output(`"`output'"') saving(`"`metadata'"', replace) mincell(0) maxcat(100) maxfreq(100) uniqcap(0)
    assert r(nfiles)==1 & r(nobs)==15 & r(nvars)==2
    qa_state_compare, tag(dd_primitive)
    preserve
    quietly use `"`metadata'"', clear
    assert _N==2 & N==15 & nvars==2
    python: assert set(__import__("sfi").Data.get(var="variable",missingval=None))==set("code y".split())
    assert unique==5 & missing==0 if variable=="code"
    assert mean==8 & unique==15 if variable=="y"
    restore

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: codes saving() exact row identities rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes saving() exact row identities"
}

**# codes QC exact schema gates
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    qa_state_snapshot, tag(dc_primitive)
    quietly dataprobe, gatesonly expectn(15) require(code y)
    assert r(N)==15 & r(n_checks)==2 & r(n_passed)==2 & r(n_failed)==0
    qa_state_compare, tag(dc_primitive)

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: codes QC exact schema gates rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes QC exact schema gates"
}

**# codes Missingness exact complete rows
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    qa_state_snapshot, tag(dmv_primitive)
    quietly datamvp code y, nodrop
    assert r(N)==15 & r(N_complete)==15 & r(N_incomplete)==0
    assert r(N_mv_total)==0 & r(max_miss)==0 & r(mean_miss)==0
    qa_state_compare, tag(dmv_primitive)

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: codes Missingness exact complete rows rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes Missingness exact complete rows"
}

**# codes Ledger actual assertion and release
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    tempfile ledger release
    quietly dataprobe, gatesonly expectn(15) ledger(`"`ledger'"', run(primitive)) name(actual) maskrare mincell(5)
    assert r(n_checks)==1 & r(n_passed)==1
    qa_state_snapshot, tag(dqa_primitive)
    quietly dataqa assert using `"`ledger'"', run(primitive) expect(actual)
    assert r(N)==1 & r(n_failed)==0
    qa_state_compare, tag(dqa_primitive)
    qa_state_snapshot, tag(dqa_primitive)
    quietly dataqa export using `"`ledger'"', run(primitive) saving(`"`release'"') threshold(5)
    local published `"`r(saving)'"'
    assert r(N)==1 & r(n_scope_dropped)==0
    qa_state_compare, tag(dqa_primitive)
    preserve
    quietly use `"`published'"', clear
    assert _N==1 & family=="expectn" & status=="pass" & observed_num==15 & n_scope==15
    restore
    erase `"`published'"'

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: codes Ledger actual assertion and release rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes Ledger actual assertion and release"
}

**# strings Markdown exact schema/values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    python: _dm_corpus=[__import__("sfi").Macro.getGlobal(g) for g in __import__("sfi").Macro.getLocal("corpus").split()]

    tempfile output
    qa_state_snapshot, tag(dm_primitive)
    quietly datamap, output(`"`output'"') mincell(0) maxcat(100) maxfreq(100) categorical(caption)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==11
    qa_state_compare, tag(dm_primitive)
    * Markdown oracle: eleven variable rows; caption (strL, forced categorical)
    * lists the nine corpus strings once each, 31 missing, and the bait global
    * ($QA_HS_GLB = "EXPANDED") appears nowhere in the file.  Expected cells
    * are built from the corpus by the Markdown escapes the writer documents:
    * a dollar sign is &#36;, a backtick &#96;, a backslash is doubled.
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==11
    qa_md_contains using `"`output'"', needle("EXPANDED")
    assert r(n)==0
    mata: _qa_prim_check(st_local("output"), st_local("corpus"))
    assert scalar(__qa_prim_ok)==1
    scalar drop __qa_prim_ok
}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: strings Markdown exact schema/values rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings Markdown exact schema/values"
}

**# strings saving() exact row identities
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    python: _dm_corpus=[__import__("sfi").Macro.getGlobal(g) for g in __import__("sfi").Macro.getLocal("corpus").split()]

    tempfile output metadata
    qa_state_snapshot, tag(dd_primitive)
    quietly datamap, output(`"`output'"') saving(`"`metadata'"', replace) mincell(0) maxcat(100) maxfreq(100) uniqcap(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==11
    qa_state_compare, tag(dd_primitive)
    preserve
    quietly use `"`metadata'"', clear
    assert _N==11 & N==40 & nvars==11
    python: assert set(__import__("sfi").Data.get(var="variable",missingval=None))==set("id group shared y x text date all_missing onelevel extended caption".split())
    assert unique==9 & missing==31 if variable=="caption"
    restore

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: strings saving() exact row identities rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings saving() exact row identities"
}

**# strings QC exact schema gates
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    python: _dm_corpus=[__import__("sfi").Macro.getGlobal(g) for g in __import__("sfi").Macro.getLocal("corpus").split()]

    qa_state_snapshot, tag(dc_primitive)
    quietly dataprobe, gatesonly expectn(40) require(id group shared y x text date all_missing onelevel extended caption)
    assert r(N)==40 & r(n_checks)==2 & r(n_passed)==2 & r(n_failed)==0
    qa_state_compare, tag(dc_primitive)

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: strings QC exact schema gates rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings QC exact schema gates"
}

**# strings Missingness exact complete rows
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    python: _dm_corpus=[__import__("sfi").Macro.getGlobal(g) for g in __import__("sfi").Macro.getLocal("corpus").split()]

    qa_state_snapshot, tag(dmv_primitive)
    quietly datamvp id x y, nodrop
    assert r(N)==40 & r(N_complete)==40 & r(N_incomplete)==0
    assert r(N_mv_total)==0 & r(max_miss)==0 & r(mean_miss)==0
    qa_state_compare, tag(dmv_primitive)

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: strings Missingness exact complete rows rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings Missingness exact complete rows"
}

**# strings Ledger actual assertion and release
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    python: _dm_corpus=[__import__("sfi").Macro.getGlobal(g) for g in __import__("sfi").Macro.getLocal("corpus").split()]

    tempfile ledger release
    quietly dataprobe, gatesonly expectn(40) ledger(`"`ledger'"', run(primitive)) name(actual) maskrare mincell(5)
    assert r(n_checks)==1 & r(n_passed)==1
    qa_state_snapshot, tag(dqa_primitive)
    quietly dataqa assert using `"`ledger'"', run(primitive) expect(actual)
    assert r(N)==1 & r(n_failed)==0
    qa_state_compare, tag(dqa_primitive)
    qa_state_snapshot, tag(dqa_primitive)
    quietly dataqa export using `"`ledger'"', run(primitive) saving(`"`release'"') threshold(5)
    local published `"`r(saving)'"'
    assert r(N)==1 & r(n_scope_dropped)==0
    qa_state_compare, tag(dqa_primitive)
    preserve
    quietly use `"`published'"', clear
    assert _N==1 & family=="expectn" & status=="pass" & observed_num==40 & n_scope==40
    restore
    erase `"`published'"'

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: strings Ledger actual assertion and release rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings Ledger actual assertion and release"
}

display "RESULT: validation_datamap_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
