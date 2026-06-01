* test_adversarial_breakage.do - adversarial QA across every public tabtools command
* Run from the package qa/ directory.

clear all
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _adversarial
log using "`output_dir'/test_adversarial_breakage.log", replace text name(_adversarial)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Install Surface and Helper Auto-Load
local ++test_count
capture noisily {
    foreach cmd in tabtools table1_tc regtab effecttab stratetab hrcomptab ///
        comptab survtab crosstab diagtab corrtab {
        which `cmd'
    }

    clear
    input byte row byte col
    0 0
    0 1
    1 0
    1 1
    end
    crosstab row col, display
    assert r(N) == 4
}
if _rc == 0 {
    display as result "  PASS: install surface and helper auto-load"
    local ++pass_count
}
else {
    display as error "  FAIL: install surface and helper auto-load (rc=`=_rc')"
    local ++fail_count
}

**# tabtools Controller
local ++test_count
capture noisily {
    tabtools set clear

    tabtools
    assert r(n_commands) == 14
    assert "`r(commands)'" == ///
        "table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab diagtab comptab hrcomptab puttab stacktab tabtools"

    set varabbrev on
    capture tabtools nonsense
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture tabtools, category(garbage)
    assert _rc == 198
    assert c(varabbrev) == "on"

    tabtools set theme lancet
    tabtools set font Calibri
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_FONT" == "Calibri"

    capture tabtools set theme custom, fontsize(5)
    assert _rc == 198

    tabtools set clear
    assert "$TABTOOLS_THEME" == ""
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: tabtools rejects bad controller/default inputs cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools adversarial controller/default inputs (rc=`=_rc')"
    local ++fail_count
}

**# table1_tc
local ++test_count
capture noisily {
    clear
    set obs 6
    gen double x = _n
    gen byte group = mod(_n, 2)
    gen double wt = 1
    replace wt = -5 in 6
    gen byte keepme = (_n < 6)
    gen int fw = 1
    tempfile table1_before
    save "`table1_before'", replace

    set varabbrev on
    capture table1_tc
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture table1_tc x, by(group) vars(x nonsense)
    assert _rc == 498
    assert c(varabbrev) == "on"

    capture table1_tc x, by(group) vars(x contn) wt(wt)
    assert _rc == 498
    assert c(varabbrev) == "on"

    table1_tc x if keepme, by(group) vars(x contn) wt(wt)
    cf _all using "`table1_before'"

    capture table1_tc x [fweight=fw], by(group) vars(x contn) wt(wt)
    assert _rc == 198

    gen byte N = group
    capture table1_tc x, by(N) vars(x contn)
    assert _rc == 498

    gen byte bin12 = cond(_n <= 3, 1, 2)
    capture table1_tc, vars(bin12 bin)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: table1_tc adversarial inputs and preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc adversarial inputs and preservation (rc=`=_rc')"
    local ++fail_count
}

**# crosstab
local ++test_count
capture noisily {
    clear
    input str1 row_s byte col
    "a" 0
    "b" 1
    "a" 0
    "b" 1
    end

    set varabbrev on
    capture crosstab row_s col
    assert _rc == 109
    assert c(varabbrev) == "on"

    clear
    input byte row byte col int freq
    0 0 10
    0 1 20
    1 0 30
    1 1 40
    end
    expand freq

    capture crosstab row col, rowpct colpct
    assert _rc == 198
    assert c(varabbrev) == "on"

    gen byte row3 = cond(_n <= 30, 0, cond(_n <= 70, 1, 2))
    capture crosstab row3 col, or
    assert _rc == 198

    capture crosstab row col if 0
    assert _rc == 2000

    capture crosstab row col, open
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: crosstab adversarial inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab adversarial inputs (rc=`=_rc')"
    local ++fail_count
}

**# corrtab
local ++test_count
capture noisily {
    clear
    input double x y z
    1 1 1
    2 2 .
    3 3 .
    4 4 4
    5 . 5
    . 6 6
    end

    set varabbrev on
    capture corrtab x y z, lower upper
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture corrtab x y z, pvalues star(0.05)
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture corrtab x y z, star(0 0.05)
    assert _rc == 198

    capture corrtab x y z if 0
    assert _rc == 2000

    capture frame drop corr_adv
    corrtab x y z, full frame(corr_adv, replace)
    matrix N = r(N)
    assert N[1,1] == 5
    assert N[1,2] == 4
    assert N[1,3] == 3
    assert N[2,3] == 3
    assert N[3,3] == 4
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: corrtab conflicts and pairwise-missing N matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab conflicts and pairwise-missing N matrix (rc=`=_rc')"
    local ++fail_count
}
capture frame drop corr_adv

**# diagtab
local ++test_count
capture noisily {
    clear
    input double score byte test byte gold
    0.10 0 0
    0.20 0 0
    0.80 1 1
    0.90 1 1
    0.40 1 0
    0.60 0 1
    end

    set varabbrev on
    capture diagtab score gold
    assert _rc == 198
    assert c(varabbrev) == "on"

    replace gold = 2 in 1
    capture diagtab test gold
    assert _rc == 198
    assert c(varabbrev) == "on"
    replace gold = 0 in 1

    capture diagtab test gold, prevalence(0)
    assert _rc == 198

    capture diagtab test gold, prevalence(1)
    assert _rc == 198

    capture diagtab score gold, cutoff(0.5) cutoffs(0.2 0.5)
    assert _rc == 198

    capture diagtab score gold, cutoffs(0.2 0.5) auc
    assert _rc == 198

    capture diagtab score gold, cutoffs(0.2 0.5) optimal
    assert _rc == 198

    capture diagtab test gold if 0
    assert _rc == 2000
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: diagtab adversarial inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab adversarial inputs (rc=`=_rc')"
    local ++fail_count
}

**# regtab
local ++test_count
capture noisily {
    collect clear
    set varabbrev on
    capture regtab
    assert _rc == 2000
    assert c(varabbrev) == "on"

    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local e_cmd "`e(cmd)'"
    local e_N = e(N)

    capture regtab, digits(7)
    assert _rc == 198
    assert c(varabbrev) == "on"
    assert "`e(cmd)'" == "`e_cmd'"
    assert e(N) == `e_N'

    capture regtab, keep(mpg) drop(weight)
    assert _rc == 198
    assert "`e(cmd)'" == "`e_cmd'"
    assert e(N) == `e_N'

    capture regtab, open
    assert _rc == 198

    capture regtab, xlsx("bad.txt")
    assert _rc == 198

    capture regtab, starslevels(0.05 0.01)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: regtab rejects invalid state/options without clearing e()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab invalid state/options or e() preservation (rc=`=_rc')"
    local ++fail_count
}
collect clear

**# effecttab
local ++test_count
capture noisily {
    collect clear
    set varabbrev on
    capture effecttab
    assert _rc == 198
    assert c(varabbrev) == "on"

    matrix bad_eff = J(1, 3, .)
    capture effecttab, from(bad_eff)
    assert _rc == 198
    assert c(varabbrev) == "on"

    matrix adv_eff = (1, 0.5, 1.5, 0.04 \ -0.5, -1, 0, 0.051)
    matrix rownames adv_eff = exposure dose
    capture frame drop adv_eff1
    effecttab, from(adv_eff) frame(adv_eff1, replace) display
    assert "`r(frame)'" == "adv_eff1"
    assert r(N_rows) == 5

    capture effecttab, from(adv_eff) type(garbage)
    assert _rc == 198

    capture effecttab, from(adv_eff) open
    assert _rc == 198

    capture effecttab, from(adv_eff) boldp(1)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: effecttab adversarial from()/option inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab adversarial from()/option inputs (rc=`=_rc')"
    local ++fail_count
}

**# stratetab
local ++test_count
capture noisily {
    clear
    input byte id double x
    1 10
    2 20
    3 30
    end
    tempfile strat_user_before
    save "`strat_user_before'", replace

    set varabbrev on
    capture stratetab, using(one two three) outcomes(2)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`strat_user_before'"

    capture stratetab, using("bad;name") outcomes(1)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`strat_user_before'"

    capture stratetab, using(one) outcomes(0)
    assert _rc == 198
    cf _all using "`strat_user_before'"

    capture stratetab, using(one) outcomes(1) xlsx("bad.txt")
    assert _rc == 198
    cf _all using "`strat_user_before'"

    local badbase "`c(tmpdir)'/tabtools_adv_bad_`c(pid)'"
    preserve
        clear
        input byte bogus
        1
        end
        save "`badbase'.dta", replace
    restore

    capture stratetab, using("`badbase'") outcomes(1)
    assert _rc == 111
    assert c(varabbrev) == "on"
    cf _all using "`strat_user_before'"
    capture erase "`badbase'.dta"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: stratetab rejects malformed file contracts and restores data"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab malformed file contracts or data restore (rc=`=_rc')"
    local ++fail_count
}

**# survtab
local ++test_count
capture noisily {
    clear
    set obs 6
    gen double t = _n
    gen byte fail = (_n <= 3)
    gen byte group = 1

    set varabbrev on
    capture survtab, times(1)
    assert _rc == 119
    assert c(varabbrev) == "on"

    stset t, failure(fail)

    capture survtab, times(1) difference
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture survtab, times(1) by(group)
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture survtab, times(1) timeunit(fortnights)
    assert _rc == 198

    capture survtab, times(1) rmst(0)
    assert _rc == 198

    capture survtab, times(1) digits(7)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: survtab adversarial stset/group/options"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab adversarial stset/group/options (rc=`=_rc')"
    local ++fail_count
}

**# comptab
local ++test_count
capture noisily {
    matrix comp_eff = (1, 0.5, 1.5, 0.04 \ 2, 1, 3, 0.20)
    matrix rownames comp_eff = exposure dose
    capture frame drop adv_eff1
    capture frame drop adv_eff2
    capture frame drop adv_comp
    effecttab, from(comp_eff) frame(adv_eff1, replace)
    effecttab, from(comp_eff) frame(adv_eff2, replace)

    set varabbrev on
    capture comptab adv_eff1 adv_eff2
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture comptab adv_eff1 adv_eff2, rows(1 \ 1) rownames(exposure \ dose)
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture comptab adv_eff1 adv_eff2, rows(1 99 \ 1) display
    assert _rc == 198

    capture comptab adv_eff1 adv_eff2, rownames("__definitely_absent__ \ exposure") display
    assert _rc == 198

    comptab adv_eff1 adv_eff2, rows(1 2 \ 1 2) frame(adv_comp, replace)
    assert r(N_frames) == 2
    assert r(N_models) == 1

    capture frame drop adv_bad_comp
    frame create adv_bad_comp
    frame adv_bad_comp {
        set obs 3
        gen str244 A = ""
        gen str244 c1 = ""
        replace A = "label" in 3
    }
    capture comptab adv_bad_comp, rows(1) display
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: comptab adversarial frame/row contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab adversarial frame/row contracts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop adv_comp
capture frame drop adv_bad_comp

**# hrcomptab
local ++test_count
capture noisily {
    clear
    input byte id double x
    1 10
    2 20
    end
    tempfile hr_user_before
    save "`hr_user_before'", replace

    set varabbrev on
    capture hrcomptab missing_rates, modelframes(missing_model) rows(1)
    assert _rc == 111
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"

    capture frame drop adv_rate_bad
    frame create adv_rate_bad
    frame adv_rate_bad {
        set obs 3
        gen str244 c1 = ""
        gen str244 c2 = ""
        gen str244 c3 = ""
    }
    capture hrcomptab adv_rate_bad, modelframes(missing_model) rows(1)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"

    capture hrcomptab adv_rate_bad, modelframes(missing_model)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"

    capture hrcomptab adv_rate_bad, modelframes(missing_model) rows(1) rownames(foo)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: hrcomptab adversarial scaffold/model contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab adversarial scaffold/model contracts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop adv_rate_bad
capture frame drop adv_eff1
capture frame drop adv_eff2

display as result "adversarial breakage QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _adversarial
