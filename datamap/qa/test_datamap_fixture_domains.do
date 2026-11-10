*! test_datamap_fixture_domains.do -- actual declared numeric preflight endpoints
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datamap_fixture_domains.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do _qa_fx_a7.do
do _qa_metamorphic.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
* 2026-11-10 (datamap 2.0.0): format(json), format(text) and datadict are
* removed.  _dm_domain_json (a JSON parse in Python) is now _dm_domain_md,
* the same facts read from the Markdown document (40 observations, ten
* variable rows, all_missing and extended 100% missing, x complete), and the
* three datadict tests run on datamap's saving() table (_dd_domain_metadata
* keeps its name and asserts).  Each declared-domain cell (inside / outside
* values of maxcat, maxfreq, uniqcap, samples) is unchanged.
do _qa_md.do
capture program drop _dm_domain_md
program define _dm_domain_md
    args output
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) miss("40 (100.0%)")
    assert r(n)==1
    * 2026-11-10 (2.0.0 Phase 3, F3): the Missing cell lists extended's codes;
    * the fixture holds .a-.z in rows 1-26 and . in the other 14 rows, and at
    * the default mincell(5) each one-row code is withheld (the pin read
    * miss("40 (100.0%)") before)
    local _ext "40 (100.0%): . 14"
    foreach _l in a b c d e f g h i j k l m n o p q r s t u v w x y z {
        local _ext "`_ext', .`_l' suppressed (<5)"
    }
    qa_md_rows using `"`output'"', var(extended) miss("`_ext'")
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) miss("0 (0.0%)")
    assert r(n)==1
end
capture program drop _dd_domain_metadata
program define _dd_domain_metadata
    args metadata
    preserve
    quietly use `"`metadata'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 & unique==0 if variable=="all_missing"
    restore
end

**# datamap maxcat lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') maxcat(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dm_domain_md `"`output'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap maxcat rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap maxcat"
}

**# datamap maxfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') maxfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dm_domain_md `"`output'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap maxfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap maxfreq"
}

**# datamap samples lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') samples(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(nobs)==40 & r(nvars)==10 & r(nfiles)==1)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap samples rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap samples"
}

**# datamap uniqcap lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') uniqcap(@v@)) inside(0 1 100) outside(-1 . 1.5) check(_dm_domain_md `"`output'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap uniqcap rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap uniqcap"
}

**# datamap saving() maxcat lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') saving(`"`metadata'"', replace) maxcat(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dd_domain_metadata `"`metadata'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap saving() maxcat rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap saving() maxcat"
}

**# datamap saving() maxfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') saving(`"`metadata'"', replace) maxfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dd_domain_metadata `"`metadata'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap saving() maxfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap saving() maxfreq"
}

**# datamap saving() uniqcap lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') saving(`"`metadata'"', replace) uniqcap(@v@)) inside(0 1 100) outside(-1 . 1.5) check(_dd_domain_metadata `"`metadata'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap saving() uniqcap rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap saving() uniqcap"
}

**# dataprobe maxcat lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(dataprobe, gatesonly expectn(40) maxcat(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: dataprobe maxcat rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe maxcat"
}

**# dataprobe maxfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(dataprobe, gatesonly expectn(40) maxfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: dataprobe maxfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe maxfreq"
}

**# dataprobe rare lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(dataprobe, gatesonly expectn(40) rare(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: dataprobe rare rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe rare"
}

**# dataprobe outliers lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(dataprobe, gatesonly expectn(40) outliers(@v@)) inside(0 1 100) outside(-1 .) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==5 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: dataprobe outliers rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe outliers"
}

**# dataprobe mincell lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(dataprobe, gatesonly expectn(40) mincell(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: dataprobe mincell rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe mincell"
}

**# datamvp minfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop minfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp minfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp minfreq"
}

**# datamvp top lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop top(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp top rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp top"
}

**# datamvp groupgap lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop groupgap(@v@) graph(bar) over(group) gname(dm_domain) nodraw) inside(0 1 100) outside(-1 . .a) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp groupgap rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp groupgap"
}

**# datamvp mincell lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop mincell(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp mincell rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp mincell"
}

display "RESULT: test_datamap_fixture_domains tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
