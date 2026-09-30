*! validation_datamap_fixture_primitives.do -- exact metadata/code/text and full caller contracts
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_datamap_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# names JSON exact schema/values
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempfile output
    qa_state_snapshot, tag(dm_primitive)
    quietly datamap, output(`"`output'"') format(json) mincell(0) maxcat(100) maxfreq(100)
    assert r(nfiles)==1 & r(nobs)==20 & r(nvars)==4
    qa_state_compare, tag(dm_primitive)
    python: _dm_ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _dm_vars={v["name"]:v for v in _dm_ds["variable_metadata"]}; assert _dm_ds["observations"]==20 and set(_dm_vars)==set("y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b".split())
    python: assert {z["value"]:z["count"] for z in _dm_vars["y"]["frequencies"]}=={"0":10,"2":10} and {z["value"]:z["count"] for z in _dm_vars["Y"]["frequencies"]}=={"-9":10,"11":10}; assert {z["value"]:z["count"] for z in _dm_vars["abcdefghijklmnopqrstuvwxyz_1234a"]["frequencies"]}=={str(i):1 for i in range(1,21)} and {z["value"]:z["count"] for z in _dm_vars["abcdefghijklmnopqrstuvwxyz_1234b"]["frequencies"]}=={str(-i):1 for i in range(1,21)}

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: names JSON exact schema/values rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names JSON exact schema/values"
}

**# names Dictionary exact row identities
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempfile output metadata
    qa_state_snapshot, tag(dd_primitive)
    quietly datadict, output(`"`output'"') saving(`"`metadata'"', replace) stats mincell(0) maxcat(100) maxfreq(100) uniqcap(0)
    assert r(nfiles)==1 & r(nobs_total)==20 & r(nvars_total)==4
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
    display as error "FAIL: names Dictionary exact row identities rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names Dictionary exact row identities"
}

**# names QC exact schema gates
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    qa_state_snapshot, tag(dc_primitive)
    quietly datacheck, gatesonly expectn(20) require(y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b)
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
    quietly datacheck, gatesonly expectn(20) ledger(`"`ledger'"', run(primitive)) name(actual) maskrare mincell(5)
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

**# codes JSON exact schema/values
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    tempfile output
    qa_state_snapshot, tag(dm_primitive)
    quietly datamap, output(`"`output'"') format(json) mincell(0) maxcat(100) maxfreq(100)
    assert r(nfiles)==1 & r(nobs)==15 & r(nvars)==2
    qa_state_compare, tag(dm_primitive)
    python: _dm_ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _dm_vars={v["name"]:v for v in _dm_ds["variable_metadata"]}; assert _dm_ds["observations"]==15 and set(_dm_vars)==set("code y".split())
    python: assert {z["value"]:z["count"] for z in _dm_vars["code"]["frequencies"]}=={"3000000000":3,"3000000001":3,"-7":3,"2":3,"20":3}

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: codes JSON exact schema/values rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes JSON exact schema/values"
}

**# codes Dictionary exact row identities
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    tempfile output metadata
    qa_state_snapshot, tag(dd_primitive)
    quietly datadict, output(`"`output'"') saving(`"`metadata'"', replace) stats mincell(0) maxcat(100) maxfreq(100) uniqcap(0)
    assert r(nfiles)==1 & r(nobs_total)==15 & r(nvars_total)==2
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
    display as error "FAIL: codes Dictionary exact row identities rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes Dictionary exact row identities"
}

**# codes QC exact schema gates
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    qa_state_snapshot, tag(dc_primitive)
    quietly datacheck, gatesonly expectn(15) require(code y)
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
    quietly datacheck, gatesonly expectn(15) ledger(`"`ledger'"', run(primitive)) name(actual) maskrare mincell(5)
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

**# strings JSON exact schema/values
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
    quietly datamap, output(`"`output'"') format(json) mincell(0) maxcat(100) maxfreq(100) categorical(caption)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==11
    qa_state_compare, tag(dm_primitive)
    python: _dm_ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _dm_vars={v["name"]:v for v in _dm_ds["variable_metadata"]}; assert _dm_ds["observations"]==40 and set(_dm_vars)==set("id group shared y x text date all_missing onelevel extended caption".split())
    python: _dm_freq={z["value"]:z["count"] for z in _dm_vars["caption"]["frequencies"]}; assert all(_dm_freq[v]==1 for v in _dm_corpus) and _dm_vars["caption"]["missing_n"]==31 and "EXPANDED" not in _dm_freq

}
local outcome=_rc
capture restore
capture dataqa set clear
if `outcome' {
    local ++fail
    display as error "FAIL: strings JSON exact schema/values rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings JSON exact schema/values"
}

**# strings Dictionary exact row identities
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
    quietly datadict, output(`"`output'"') saving(`"`metadata'"', replace) stats mincell(0) maxcat(100) maxfreq(100) uniqcap(0)
    assert r(nfiles)==1 & r(nobs_total)==40 & r(nvars_total)==11
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
    display as error "FAIL: strings Dictionary exact row identities rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings Dictionary exact row identities"
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
    quietly datacheck, gatesonly expectn(40) require(id group shared y x text date all_missing onelevel extended caption)
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
    quietly datacheck, gatesonly expectn(40) ledger(`"`ledger'"', run(primitive)) name(actual) maskrare mincell(5)
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
