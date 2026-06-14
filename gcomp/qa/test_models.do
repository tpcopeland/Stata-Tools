* test_models.do - Component-model capture/display/export (gcomp savemodels/
* showmodels + gcomptab models mode). v1.3.0 feature.
* Runtime: ~2 minutes (small bootstrap)

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap install ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'/") replace
discard

local testdir "`c(tmpdir)'"

* clean residue
foreach f in _tm_models.xlsx _tm_models.md _tm_models.csv {
    capture erase "`testdir'/`f'"
}

* === Synthetic mediation data ===
set seed 24680
set obs 1000
gen double c = rnormal()
gen double x = rbinomial(1, invlogit(-0.5 + 0.4*c))
gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
tempfile medbin
save `medbin'

* ============================================================
* 1. savemodels populates the e() manifest
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    assert e(N_models) == 2
    assert "`e(model_names)'"   == "_gcomp_m_1 _gcomp_m_2"
    assert "`e(model_cmds)'"    == "logit logit"
    assert "`e(model_depvars)'" == "m y"
    assert "`e(model_eq_1)'" == "x c"
    assert "`e(model_eq_2)'" == "m x c"
}
if _rc == 0 {
    display as result "  PASS: savemodels populates e() manifest"
    local ++pass_count
}
else {
    display as error "  FAIL: savemodels manifest (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 2. Stored estimates are faithful to a direct refit
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    logit m x c
    tempname ref
    matrix `ref' = e(b)
    estimates restore _gcomp_m_1
    tempname got
    matrix `got' = e(b)
    assert mreldif(`ref', `got') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: stored component model is faithful (exact refit)"
    local ++pass_count
}
else {
    display as error "  FAIL: faithfulness (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 3. showmodels (compact + native) run clean across families
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) showmodels
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) showmodels modelstyle(native)
}
if _rc == 0 {
    display as result "  PASS: showmodels compact + native run clean"
    local ++pass_count
}
else {
    display as error "  FAIL: showmodels (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 4. modelstyle() validation
* ============================================================
local ++test_count
capture {
    use `medbin', clear
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) showmodels modelstyle(bogus)
}
if _rc == 198 {
    display as result "  PASS: modelstyle(bogus) rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: modelstyle validation (rc=`=_rc', expected 198)"
    local ++fail_count
}

* ============================================================
* 5. gcomptab, models writes markdown/csv/display + returns
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    gcomptab, models markdown("`testdir'/_tm_models.md") csv("`testdir'/_tm_models.csv") display
    assert r(N_models) == 2
    assert r(N_rows) == 4
    assert "`r(coef_label)'" == "OR"
    confirm file "`testdir'/_tm_models.md"
    confirm file "`testdir'/_tm_models.csv"
    tempname tab
    matrix `tab' = r(table)
    assert rowsof(`tab') == 4 & colsof(`tab') == 2
}
if _rc == 0 {
    display as result "  PASS: gcomptab models markdown/csv/display + returns"
    local ++pass_count
}
else {
    display as error "  FAIL: gcomptab models md/csv/display (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 6. gcomptab, models xlsx (compact + stats + stars)
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    gcomptab, models xlsx("`testdir'/_tm_models.xlsx") sheet(Models) ///
        stats(n) compact stars modellabels("Mediator \ Outcome")
    confirm file "`testdir'/_tm_models.xlsx"
    assert "`r(xlsx)'" != ""
}
if _rc == 0 {
    display as result "  PASS: gcomptab models xlsx (compact/stats/stars)"
    local ++pass_count
}
else {
    display as error "  FAIL: gcomptab models xlsx (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 7. Guard: models with no captured models errors cleanly
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1)
    * no savemodels; clobber active e() with a foreign estimator
    logit m x c
}
capture noisily gcomptab, models display
local _grc = _rc
if `_grc' == 198 {
    display as result "  PASS: models guard errors without savemodels (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: models guard (rc=`_grc', expected 198)"
    local ++fail_count
}

* ============================================================
* 8. e(model_names) survives a chained gcomptab call (hold/unhold)
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    local _before "`e(model_names)'"
    quietly gcomptab, models display
    local _after "`e(model_names)'"
    assert "`_before'" == "`_after'"
    assert "`_after'" == "_gcomp_m_1 _gcomp_m_2"
    * a second chained call must still work
    gcomptab, models display se nopvalue keep(x c)
    assert r(N_rows) == 2
}
if _rc == 0 {
    display as result "  PASS: e(model_names) survives chained gcomptab (hold/unhold)"
    local ++pass_count
}
else {
    display as error "  FAIL: chained-call e() survival (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 9. Multi-equation (mlogit) + mixed scale + base-eq omitted dropped
* ============================================================
local ++test_count
capture noisily {
    clear
    set seed 13579
    set obs 1500
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.5*c))
    gen double mlin = 0.8*x + 0.5*c + rnormal()
    egen m = cut(mlin), group(3)
    gen double y = 0.5*m + 0.4*x + 0.3*c + rnormal()
    quietly gcomp y m x c, outcome(y) mediation linexp exposure(x) mediator(m) base_confs(c) ///
        commands(m: mlogit, y: regress) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(2) savemodels
    gcomptab, models markdown("`testdir'/_tm_models.md") modellabels("Mediator \ Outcome")
    assert "`r(coef_label)'" == "mixed"
    assert r(N_models) == 2
    * mlogit: 2 non-base eqs x {x,c,_cons} = 6 rows (eq-prefixed, distinct keys);
    * regress adds {m,x,c,_cons} = 4 more -> 10 body rows
    assert r(N_rows) == 10
}
if _rc == 0 {
    display as result "  PASS: mlogit multi-eq + mixed scale + base-eq dropped"
    local ++pass_count
}
else {
    display as error "  FAIL: mlogit multi-eq (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 10. usemodels() selects a subset
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    gcomptab, models usemodels(_gcomp_m_2) display
    assert r(N_models) == 1
    assert r(N_rows) == 4
}
if _rc == 0 {
    display as result "  PASS: usemodels() selects subset"
    local ++pass_count
}
else {
    display as error "  FAIL: usemodels() (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 11. Mutual exclusivity: models + doseresponse rejected
* ============================================================
local ++test_count
capture {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    gcomptab, models doseresponse display
}
if _rc == 198 {
    display as result "  PASS: models + doseresponse rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: mutual exclusivity (rc=`=_rc', expected 198)"
    local ++fail_count
}

* ============================================================
* 12. Existing mediation mode still works (no regression)
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1)
    gcomptab, xlsx("`testdir'/_tm_models.xlsx") sheet("Mediation")
    confirm file "`testdir'/_tm_models.xlsx"
}
if _rc == 0 {
    display as result "  PASS: existing mediation export unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: mediation regression (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* 13. models xlsx into an existing workbook preserves peer sheets
* ============================================================
local ++test_count
capture noisily {
    use `medbin', clear
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        sim(50) samples(3) seed(1) savemodels
    * write a mediation sheet first, then a models sheet into the SAME file
    gcomptab, xlsx("`testdir'/_tm_models.xlsx") sheet("Mediation")
    gcomptab, models xlsx("`testdir'/_tm_models.xlsx") sheet("Models") stats(n)
    * both sheets must survive
    import excel using "`testdir'/_tm_models.xlsx", describe
    local _nsheets = r(N_worksheet)
    local _names ""
    forvalues s = 1/`_nsheets' {
        local _names "`_names' `r(worksheet_`s')'"
    }
    assert strpos("`_names'", "Mediation") > 0
    assert strpos("`_names'", "Models") > 0
}
if _rc == 0 {
    display as result "  PASS: models xlsx preserves peer sheets (no sheet-nuking replace)"
    local ++pass_count
}
else {
    display as error "  FAIL: peer-sheet preservation (rc=`=_rc')"
    local ++fail_count
}

* === cleanup ===
foreach f in _tm_models.xlsx _tm_models.md _tm_models.csv {
    capture erase "`testdir'/`f'"
}

* ============================================================
* Summary
* ============================================================
display as text _n "{hline 60}"
display as text "test_models.do: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "{hline 60}"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"
