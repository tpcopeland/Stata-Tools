* test_iivw_surfaces.do
* Surface parity, hostile inputs and hostile strings for the iivw commands
* (DOTHIS 2026-09-28 Part 3.1 and 3.3, step 7).
* budget: 60
*
* Cells (each can fail; the audit finding each would have caught is named):
*   parity   one published value per command, identical in r()/e(), the
*            workbook and the console, against an independent oracle where
*            one exists:
*            iivw           the command count = the public help files
*            iivw_weight    mean weight and ESS = summarize/(sum w)^2/sum w^2
*            iivw_balance   weighted mean = summarize [aw=_iivw_iw]
*            iivw_exogtest  HR = exp(b) of its own table (sink agreement)
*            iivw_fit       b = glm [pw=_iivw_weight], vce(cluster id)
*            iivw_bspool    pooled draw count and percentile limit = the
*                           appended draw files (F08)
*            iivw_diagnose  the stored percentile interval (F10); shares
*                           withheld in every sink when endogenous (F11)
*   hostile  qa_hostile_times as visit times: the visit-intensity Cox model
*            depends on time only through its order, so an order-preserving
*            map to 1..5 must leave weights, balance, the exogeneity test and
*            a timespec(none) fit unchanged
*   strings  the qa_hostile_strings corpus through title() of iivw_balance,
*            iivw_exogtest and iivw_diagnose (read back from workbook A1) and
*            saving() of iivw_fit and iivw_bspool (refuse-or-exact)
* Open ledger: iivw r(n_commands) (new finding, below).
*
* Run from iivw/qa:  stata-mp -b do test_iivw_surfaces.do

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
do "`qa_dir'/_qa_parity.do"
do "`qa_dir'/_qa_hostile.do"

if `"`1'"' != "" {
    display as error "test_iivw_surfaces takes no selector"
    exit 198
}

local test_count = 0
local pass_count = 0
local failed ""
tempfile _stub
global IVS_W "`_stub'_ivs"
capture mkdir "$IVS_W"

capture program drop _ivs_result
program define _ivs_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

* The pinned FIPTIW panel (test_iivw_codexaudit_2026_09_27_a/b).
capture program drop _ivs_panel
program define _ivs_panel
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    quietly set obs 150
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    quietly drop if runiform() > keeppr & j > 1
    sort id t
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(7) scores nolog
end

* Lines of a text file matching an ICU regex.
capture mata: mata drop _ivs_count()
mata:
real scalar _ivs_count(string scalar file, string scalar re)
{
    string colvector L
    real scalar i, n
    L = cat(file)
    n = 0
    for (i = 1; i <= rows(L); i++) n = n + ustrregexm(L[i], re)
    return(n)
}
end

* Log a command's console output to a closed text log; r() survives via a
* copy into the scalars/matrices the caller names afterwards.
capture program drop _ivs_log
program define _ivs_log
    version 16.0
    args onoff file
    if "`onoff'" == "on" log using `"`file'"', text replace name(_ivsl)
    else log close _ivsl
end

**# Surface parity

**## SP-iivw the command count
* OPEN LEDGER, emptied in 4.3.2: r(n_commands) was hard-coded 5 while
* r(commands) and the console list six commands (iivw_bspool); iivw.sthlp
* documents it as the number of available commands. The oracle is the
* package's public help files other than iivw.sthlp. With the ledger empty,
* r(n_commands) must equal that count (red on 4.3.1).
local nc_open ""
local ++test_count
capture noisily {
    local helps : dir "`pkg_dir'" files "iivw_*.sthlp"
    local want : word count `helps'
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw
    local cmds "`r(commands)'"
    scalar ivs_nc = r(n_commands)
    _ivs_log off
    qa_surface_parity, expect(`want') name(commands listed) result(wordcount("`cmds'"))
    * the console lists one line per command
    mata: st_numscalar("ivs_ncon", _ivs_count(st_local("lg"), "^  iivw_[a-z]+ +- "))
    qa_assert_equal scalar(ivs_ncon) `want', property(console lists every command)
    display as text "SP-iivw r(n_commands) = " scalar(ivs_nc) " vs `want' commands; recorded open: [`nc_open']"
    if "`nc_open'" == "" qa_surface_parity, expect(`want') name(r(n_commands)) result(scalar(ivs_nc))
    else assert scalar(ivs_nc) == `nc_open' & `nc_open' != `want'
}
_ivs_result `=_rc' "SP-iivw command list agrees across r(commands) and console; r(n_commands) open as recorded"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-iivw"

**## SP-weight mean weight and ESS: r(), console = summarize and (sum w)^2/sum w^2
local ++test_count
capture noisily {
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    quietly set obs 150
    gen long id = _n
    gen double z1 = rnormal()
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    sort id t
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw_weight, id(id) time(t) visit_cov(z1) maxfu(7) nolog
    scalar ivs_mw = r(mean_weight)
    scalar ivs_ess = r(ess)
    _ivs_log off
    quietly summarize _iivw_weight
    scalar ivs_m0 = r(mean)
    tempvar w2
    gen double `w2' = _iivw_weight^2
    quietly summarize `w2', meanonly
    scalar ivs_e0 = (ivs_m0*r(N))^2 / r(sum)
    qa_surface_parity, expect(scalar(ivs_m0)) name(mean weight) result(scalar(ivs_mw)) ///
        log(`"`lg'"') logregex("Mean: +([0-9.]+)")
    qa_surface_parity, expect(scalar(ivs_e0)) name(ESS) result(scalar(ivs_ess)) tol(1e-9) ///
        log(`"`lg'"') logregex("Effective sample size: +([0-9.]+)")
}
_ivs_result `=_rc' "SP-weight mean weight and ESS agree with the weights in r() and console"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-weight"

**## SP-balance weighted covariate mean: r(balance), workbook, console = summarize [aw]
local ++test_count
capture noisily {
    _ivs_panel
    quietly summarize z1 [aw=_iivw_iw]
    scalar ivs_want = r(mean)
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw_balance k1 z1, xlsx("$IVS_W/bal.xlsx") replace
    matrix ivs_B = r(balance)
    _ivs_log off
    local r = rownumb(ivs_B, "z1")
    local c = colnumb(ivs_B, "weighted_mean")
    qa_surface_parity, expect(scalar(ivs_want)) name(weighted mean z1) ///
        result(el(ivs_B,`r',`c')) xlsx("$IVS_W/bal.xlsx" Balance D4) ///
        log(`"`lg'"') logregex("^ +z1 +-?[0-9.]+ +(-?[0-9.]+)")
}
_ivs_result `=_rc' "SP-balance weighted mean in r(), workbook, console = summarize [aw]"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-balance"

**## SP-exogtest HR: r(results), workbook, console agree (and = exp(b))
local ++test_count
capture noisily {
    _ivs_panel
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw_exogtest y, id(id) time(t) maxfu(7) nolog xlsx("$IVS_W/exo.xlsx")
    matrix ivs_R = r(results)
    _ivs_log off
    local cb = colnumb(ivs_R, "b")
    local ch = colnumb(ivs_R, "hr")
    qa_surface_parity, expect(exp(el(ivs_R,1,`cb'))) name(HR of lagged y) ///
        result(el(ivs_R,1,`ch')) xlsx("$IVS_W/exo.xlsx" Exogeneity C4) ///
        log(`"`lg'"') logregex("y \(lag 1\) +([0-9.]+)")
}
_ivs_result `=_rc' "SP-exogtest HR in r(), workbook, console"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-exogtest"

**## SP-fit coefficient: e(b) and console = glm [pw], vce(cluster id)
local ++test_count
capture noisily {
    _ivs_panel
    quietly glm y a z1 t [pw=_iivw_weight], family(gaussian) vce(cluster id)
    scalar ivs_want = _b[a]
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw_fit y a z1, timespec(linear) vce(fixed) replace
    _ivs_log off
    qa_surface_parity, expect(scalar(ivs_want)) name(coefficient of a) ///
        result(_b[a]) log(`"`lg'"') logregex("^ +a [|] +(-?[0-9.]+)")
}
_ivs_result `=_rc' "SP-fit coefficient in e(b) and console = glm oracle"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-fit"

**## SP-bspool (F08) pooled count and percentile limit in every e() field and estat
local ++test_count
capture noisily {
    clear
    set seed 8080
    quietly set obs 80
    gen long id = _n
    gen double y = 1 + rnormal()
    forvalues s = 1/2 {
        quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
            vce(bootstrap, reps(20) fixedweights seed(11)) rngstream(`s') ///
            saving("$IVS_W/sp_`s'", replace)
    }
    iivw_bspool using "$IVS_W/sp_1.dta $IVS_W/sp_2.dta", notable
    * oracle: the appended draw files
    preserve
    use "$IVS_W/sp_1.dta", clear
    append using "$IVS_W/sp_2.dta"
    scalar ivs_n = _N
    unab vv : _all
    local v : word 1 of `vv'
    quietly _pctile `v', p(2.5)
    scalar ivs_lo = r(r1)
    restore
    qa_surface_parity, expect(scalar(ivs_n)) name(pooled draws N_reps) result(e(N_reps))
    qa_surface_parity, expect(scalar(ivs_n)) name(pooled draws completed) ///
        result(e(iivw_bs_reps_completed))
    qa_surface_parity, expect(scalar(ivs_lo)) name(percentile lower iivw) ///
        result(el(e(iivw_ci_percentile),1,1))
    tempfile lg
    _ivs_log on `"`lg'"'
    estat bootstrap, percentile
    _ivs_log off
    qa_surface_parity, expect(scalar(ivs_lo)) name(percentile lower native) ///
        result(el(e(ci_percentile),1,1)) log(`"`lg'"') logregex("_cons [|] +[-0-9.]+ +[-0-9.]+ +[-0-9.]+ +(-?[0-9.]+)")
}
_ivs_result `=_rc' "SP-bspool F08: pooled draw count and percentile limit agree in e(), estat and the draw files"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-bspool"

**## SP-diagnose-ci (F10) the stored percentile interval in r(), workbook, console
local ++test_count
capture noisily {
    _ivs_panel
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(40) seed(71))
    local ac = colnumb(e(b), "a")
    scalar ivs_ll = el(e(iivw_ci), 1, `ac')
    estimates store ivs_pct
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw_diagnose a, unweighted(ivs_pct) weighted(ivs_pct) adjusted(ivs_pct) ///
        exogeneity(exogenous) xlsx("$IVS_W/dci.xlsx") replace
    matrix ivs_E = r(estimates)
    _ivs_log off
    qa_surface_parity, expect(scalar(ivs_ll)) name(weighted lower limit) ///
        result(el(ivs_E,2,3)) xlsx("$IVS_W/dci.xlsx" Diagnostics E5) ///
        log(`"`lg'"') logregex("^ +Weighted +-?[0-9.]+ +[0-9.]+ +(-?[0-9.]+),")
}
_ivs_result `=_rc' "SP-diagnose-ci F10: the stored percentile limit in r(), workbook, console"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-diagnose-ci"

**## SP-diagnose-share (F11) endogenous shares withheld in r(), workbook, console
local ++test_count
capture noisily {
    clear
    set seed 123
    quietly set obs 200
    gen double z = rnormal()
    gen double q = rnormal()
    gen double y = 1 + .5*z + .2*q + rnormal()
    quietly regress y z
    estimates store ivs_E1
    quietly regress y z q
    estimates store ivs_E2
    quietly regress y z q c.z#c.q
    estimates store ivs_E3
    tempfile lg
    _ivs_log on `"`lg'"'
    iivw_diagnose z, unweighted(ivs_E1) weighted(ivs_E2) adjusted(ivs_E3) ///
        exogeneity(endogenous) xlsx("$IVS_W/endog.xlsx") replace
    matrix ivs_D = r(decomp)
    _ivs_log off
    local rs = rownumb(ivs_D, "sampling_share")
    local ra = rownumb(ivs_D, "artifact_share")
    qa_surface_parity, expect(withheld) name(sampling share) ///
        result(el(ivs_D,`rs',1)) xlsx("$IVS_W/endog.xlsx" Diagnostics C11) ///
        log(`"`lg'"') logregex("Sampling share:? +(-?[0-9.]+)")
    qa_surface_parity, expect(withheld) name(artifact share) ///
        result(el(ivs_D,`ra',1)) xlsx("$IVS_W/endog.xlsx" Diagnostics C12) ///
        log(`"`lg'"') logregex("Artifact share:? +(-?[0-9.]+)")
}
_ivs_result `=_rc' "SP-diagnose-share F11: endogenous shares withheld in r(), workbook, console"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-diagnose-share"

**# Hostile times

* Every subject visits at the five qa_hostile_times literals (two that a
* decimal macro rounds down/up, and 1, 1 + 5e-13, 1 + 1e-12), or at their
* ranks 1..5. The Cox visit model sees time only through its order, so both
* panels must give identical weights and everything built on them.
capture program drop _ivs_hpanel
program define _ivs_hpanel
    version 16.0
    args ranks
    clear
    set seed 5150
    quietly set obs 120
    gen long id = _n
    gen double z1 = rnormal()
    gen double k1 = rnormal()
    quietly expand 5
    bysort id: gen int j = _n
    qa_hostile_times
    local v "`r(values)'"
    gen double t = .
    forvalues k = 1/5 {
        local lit : word `k' of `v'
        quietly replace t = cond("`ranks'" != "", `k', `lit') if j == `k'
    }
    * informative visit pattern: drop some later visits by z1
    quietly drop if j > 2 & runiform() > invlogit(.3 + .8*z1)
    gen double y = 1 + .4*z1 + .2*k1 + rnormal()
    sort id t
    local mf = cond("`ranks'" != "", 6, 2)
    quietly iivw_weight, id(id) time(t) visit_cov(z1) maxfu(`mf') nolog
end

**## HF-times weights, balance, exogeneity test and a time-free fit are order-invariant
local ++test_count
capture noisily {
    foreach p in h r {
        local rk = cond("`p'" == "r", "ranks", "")
        _ivs_hpanel `rk'
        tempfile w_`p'
        quietly save `w_`p''
        quietly iivw_balance z1 k1
        scalar ivs_cv_`p' = r(weight_cv)
        local mf = cond("`p'" == "r", 6, 2)
        if "`p'" == "h" {
            * the fixture really holds the five exact literals (no decimal
            * transport in the fixture itself)
            qa_hostile_times
            local v "`r(values)'"
            forvalues k = 1/5 {
                local lit : word `k' of `v'
                quietly count if j == `k' & t != `lit'
                assert r(N) == 0
            }
        }
        quietly iivw_exogtest y, id(id) time(t) maxfu(`mf') nolog
        matrix ivs_X_`p' = r(results)
        quietly iivw_fit y z1 k1, timespec(none) vce(fixed) replace
        matrix ivs_b_`p' = e(b)
    }
    use `w_h', clear
    rename _iivw_weight w_h
    merge 1:1 id j using `w_r', keepusing(_iivw_weight) nogenerate assert(match)
    quietly count if missing(w_h, _iivw_weight)
    assert r(N) == 0
    quietly count if reldif(w_h, _iivw_weight) > 1e-12
    assert r(N) == 0
    qa_assert_equal scalar(ivs_cv_h) scalar(ivs_cv_r), tol(1e-12) ///
        property(balance weight CV invariant to an order-preserving time map)
    local ch = colnumb(ivs_X_h, "hr")
    qa_assert_equal el(ivs_X_h,1,`ch') el(ivs_X_r,1,`ch'), tol(1e-10) ///
        property(exogeneity HR invariant to an order-preserving time map)
    assert !matmissing(ivs_b_h) & !matmissing(ivs_b_r)
    assert mreldif(ivs_b_h, ivs_b_r) < 1e-10
}
_ivs_result `=_rc' "HF-times iivw_weight, iivw_balance, iivw_exogtest, iivw_fit invariant at non-decimal visit times"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HF-times"

**# Hostile strings

* title(): every corpus string reaches workbook cell A1 byte for byte.
capture program drop _ivs_title
program define _ivs_title
    version 16.0
    args g
    global IVS_RES ""
    mata: st_local("tl", st_global("`g'"))
    local x "$IVS_W/hs_$IVS_CMD.xlsx"
    capture erase "`x'"
    if "$IVS_CMD" == "iivw_balance" {
        quietly iivw_balance k1 z1, title(`"`macval(tl)'"') xlsx("`x'") replace
    }
    if "$IVS_CMD" == "iivw_exogtest" {
        quietly iivw_exogtest y, id(id) time(t) maxfu(7) nolog replace ///
            title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "$IVS_CMD" == "iivw_diagnose" {
        quietly iivw_diagnose z1, unweighted(ivs_h1) weighted(ivs_h2) ///
            adjusted(ivs_h3) force title(`"`macval(tl)'"') xlsx("`x'") replace
    }
    local sh "`r(sheet)'"
    preserve
    quietly import excel using "`x'", sheet("`sh'") cellrange(A1:A1) allstring clear
    mata: st_global("IVS_RES", st_nobs() ? st_sdata(1, 1) : "")
    restore
end
* OPEN LEDGER, emptied in 4.3.2: title() was re-expanded as macro text on
* its way to the workbook (frame post and inline if-local re-expand their
* arguments). The TICKPAIR string (a $global and a `lit' pair) reached A1
* altered, and an unbalanced backtick exited r(132). The recorded failure set
* per command must match exactly; empty means every corpus string reaches A1
* byte for byte (red on 4.3.1).
local open_iivw_balance ""
local open_iivw_exogtest ""
local open_iivw_diagnose ""
local hsnames QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_DQ ///
    QA_HS_BSLASH QA_HS_COMMA QA_HS_LEAD QA_HS_UNICODE
foreach cmd in iivw_balance iivw_exogtest iivw_diagnose {
    local ++test_count
    capture noisily {
        _ivs_panel
        quietly regress y z1
        estimates store ivs_h1
        quietly regress y z1 k1
        estimates store ivs_h2
        quietly regress y z1 k1 a
        estimates store ivs_h3
        global IVS_CMD `cmd'
        capture noisily qa_hostile_strings, check(_ivs_title) result(IVS_RES)
        local hsrc = _rc
        local bad ""
        foreach g of local hsnames {
            capture _ivs_title `g'
            local ok = 0
            if !_rc mata: st_local("ok", strofreal(st_global("`g'") == st_global("IVS_RES")))
            if !`ok' local bad "`bad' `g'"
        }
        local bad : list retokenize bad
        display as text "HS-`cmd' failing corpus strings: [`bad'] recorded open: [`open_`cmd'']"
        assert "`bad'" == "`open_`cmd''"
        assert `hsrc' == cond("`open_`cmd''" == "", 0, 9)
    }
    _ivs_result `=_rc' "HS-`cmd' title(): corpus reaches the workbook byte for byte; open set as recorded"
    local pass_count = `pass_count' + r(pass)
    if !r(pass) local failed "`failed' HS-`cmd'"
}

* saving(): a corpus file name is written literally, or refused with r(198)
* when Stata's own option grammar cannot carry it (a comma ends the file
* name in saving(filename, replace); a double quote cannot sit inside a
* quoted file name). No other refusal is documented (iivw_bspool.sthlp,
* iivw_fit forwards to bootstrap's saving()).
capture program drop _ivs_save
program define _ivs_save
    version 16.0
    args g
    global IVS_RES ""
    mata: st_local("s", st_global("`g'"))
    local f `"$IVS_W/hs_`macval(s)'"'
    local fd `"`macval(f)'.dta"'
    capture erase `"`macval(fd)'"'
    if "$IVS_CMD" == "iivw_fit" {
        capture iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
            vce(bootstrap, reps(6) fixedweights seed(11)) rngstream(3) ///
            saving(`"`macval(f)'"', replace)
    }
    else {
        quietly estimates restore ivs_s1
        capture iivw_bspool using "$IVS_W/ss_1.dta $IVS_W/ss_2.dta", notable ///
            saving(`"`macval(f)'"', replace)
    }
    local rc = _rc
    * iivw_fit forwards saving() to Stata's bootstrap, which itself expands
    * a $name, drops a `name' pair and fails on an unbalanced backtick
    * (checked against native bootstrap 2026-09-28): such names are outside
    * the grammar iivw_fit inherits, whatever the outcome.
    mata: st_local("native", strofreal("$IVS_CMD" == "iivw_fit" & ///
        (strpos(st_local("s"), char(36)) | strpos(st_local("s"), char(96)))))
    if `native' {
        capture erase `"`macval(fd)'"'
        mata: st_global("IVS_RES", st_local("s"))
        exit
    }
    mata: st_local("gram", strofreal(strpos(st_local("s"), ",") | strpos(st_local("s"), char(34))))
    if `rc' == 198 & `gram' {
        mata: st_global("IVS_RES", st_local("s"))
        exit
    }
    if `rc' exit `rc'
    mata: st_local("there", strofreal(fileexists(st_local("fd"))))
    assert `there'
    capture erase `"`macval(fd)'"'
    mata: st_global("IVS_RES", st_local("s"))
end
* OPEN LEDGER, emptied in 4.3.2: iivw_bspool saving() wrote the pooled file
* under a macro-expanded name (TICKPAIR), executed an unbalanced backtick
* string as a command (r(199), TICK and DOLLAR), and on a quoted name holding
* a comma wrote the file but failed to stamp it (r(601), COMMA). All four are
* now written literally (red on 4.3.1).
local open_iivw_fit ""
local open_iivw_bspool ""
foreach cmd in iivw_fit iivw_bspool {
    local ++test_count
    capture noisily {
        clear
        set seed 8080
        quietly set obs 80
        gen long id = _n
        gen double y = 1 + rnormal()
        forvalues s = 1/2 {
            quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
                vce(bootstrap, reps(6) fixedweights seed(11)) rngstream(`s') ///
                saving("$IVS_W/ss_`s'", replace)
            estimates store ivs_s`s'
        }
        global IVS_CMD `cmd'
        capture noisily qa_hostile_strings, check(_ivs_save) result(IVS_RES)
        local hsrc = _rc
        local bad ""
        foreach g of local hsnames {
            capture _ivs_save `g'
            local ok = 0
            if !_rc mata: st_local("ok", strofreal(st_global("`g'") == st_global("IVS_RES")))
            if !`ok' local bad "`bad' `g'"
        }
        local bad : list retokenize bad
        display as text "HS-`cmd' failing corpus strings: [`bad'] recorded open: [`open_`cmd'']"
        assert "`bad'" == "`open_`cmd''"
        assert `hsrc' == cond("`open_`cmd''" == "", 0, 9)
    }
    _ivs_result `=_rc' "HS-`cmd' saving(): corpus names written literally or refused by the grammar; open set as recorded"
    local pass_count = `pass_count' + r(pass)
    if !r(pass) local failed "`failed' HS-`cmd'"
}

**# Summary
capture estimates drop ivs_*
capture scalar drop ivs_*
capture matrix drop ivs_*
capture shell rm -rf "$IVS_W"
macro drop IVS_W IVS_RES IVS_CMD
local fail_count = `test_count' - `pass_count'
iivw_qa_summary, name(test_iivw_surfaces) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests(`failed')
