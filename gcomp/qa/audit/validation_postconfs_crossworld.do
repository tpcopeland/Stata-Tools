* validation_postconfs_crossworld.do
* GCOMP-C08 — post_confs() cross-world conditioning oracle.
*
* A post-exposure confounder that feeds a mediator model must, for the
* natural-direct-effect arm, be drawn under the BASELINE exposure world x'
* (Daniel, De Stavola & Cousens 2011 SJ 11(4):479-517; Daniel et al. 2015
* Biometrics 71(1):1-14; VanderWeele 2015).  Estimand:
*   E[Y(x, M(x'))] = sum_c sum_z sum_m E[Y|x,z,m,c] f(z|x,c)
*                      [ sum_z' f(m|x',z',c) f(z'|x',c) ] f(c)
*
* Linear DGP (all correctly specified), analytic truths derived by hand:
*   Z = 0.8 X + 0.2 C + e_z
*   M = 0.5 X + 0.6 Z + 0.2 C + e_m
*   Y = 0.3 X + 0.5 M + 0.4 Z + 0.1 C + e_y
*   E[Y(x,M(x'))] = 0.62 x + 0.49 x'  =>  NDE=0.62, NIE=0.49, TCE=1.11, PM=0.44
*
* Pre-fix code conditioned the arm-1 mediator on Z(x) (outcome world) instead of
* Z(x'), inflating NDE by b_y*b_m*a_z = 0.5*0.6*0.8 = 0.24 (NDE->0.86, NIE->0.25,
* PM->0.22).  This suite FAILS on the pre-fix code and PASSES on the fix.

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

local tests 0
local pass 0
local fail 0

**# Scenario A — obe: post_conf Z in the mediator model (the biased path)
local ++tests
capture noisily {
    clear
    set seed 8675309
    set obs 20000
    gen double c = rnormal()
    gen double x = rbinomial(1, 0.5)
    gen double z = 0.8*x + 0.2*c + rnormal()
    gen double m = 0.5*x + 0.6*z + 0.2*c + rnormal()
    gen double y = 0.3*x + 0.5*m + 0.4*z + 0.1*c + rnormal()
    gcomp y z m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(z: regress, m: regress, y: regress) ///
        equations(z: x c, m: x z c, y: m x z c) ///
        base_confs(c) post_confs(z) sim(20000) samples(2) seed(101)
    display "A obe: TCE=" %7.4f e(tce) " NDE=" %7.4f e(nde) ///
        " NIE=" %7.4f e(nie) " PM=" %7.4f e(pm)
    assert abs(e(tce) - 1.11) < 0.04
    assert abs(e(nde) - 0.62) < 0.04
    assert abs(e(nie) - 0.49) < 0.04
    assert abs(e(pm)  - 0.44) < 0.05
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: postconf_crossworld_obe"
}
else {
    local ++fail
    display as error "  FAIL: postconf_crossworld_obe (rc=`=_rc')"
}

**# Scenario B — no-bias control: post_conf Z in the OUTCOME model only
* Z does not feed the mediator, so no cross-world bias is possible; both the
* pre-fix and fixed code must recover NDE=0.62, NIE=0.25.  This guards against a
* fix that perturbs the ordinary (unaffected) path.
* Oracle: M=0.5X+0.2C  =>  E[M(x')]=0.5x'; E[Y(x,M(x'))]=0.62 x + 0.25 x'.
local ++tests
capture noisily {
    clear
    set seed 8675309
    set obs 20000
    gen double c = rnormal()
    gen double x = rbinomial(1, 0.5)
    gen double z = 0.8*x + 0.2*c + rnormal()
    gen double m = 0.5*x + 0.2*c + rnormal()
    gen double y = 0.3*x + 0.5*m + 0.4*z + 0.1*c + rnormal()
    gcomp y z m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(z: regress, m: regress, y: regress) ///
        equations(z: x c, m: x c, y: m x z c) ///
        base_confs(c) post_confs(z) sim(20000) samples(2) seed(101)
    display "B ctrl: TCE=" %7.4f e(tce) " NDE=" %7.4f e(nde) " NIE=" %7.4f e(nie)
    assert abs(e(nde) - 0.62) < 0.04
    assert abs(e(nie) - 0.25) < 0.04
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: postconf_crossworld_control"
}
else {
    local ++fail
    display as error "  FAIL: postconf_crossworld_control (rc=`=_rc')"
}

**# Scenario C — oce: two exposure contrasts share the arm-1 swap
* Oracle per level j (X=j vs 0): NDE=0.62 j, NIE=0.49 j.
local ++tests
capture noisily {
    clear
    set seed 24601
    set obs 20000
    gen double c = rnormal()
    gen double x = floor(runiform()*3)
    gen double z = 0.8*x + 0.2*c + rnormal()
    gen double m = 0.5*x + 0.6*z + 0.2*c + rnormal()
    gen double y = 0.3*x + 0.5*m + 0.4*z + 0.1*c + rnormal()
    gcomp y z m x c, outcome(y) mediation oce exposure(x) mediator(m) ///
        commands(z: regress, m: regress, y: regress) ///
        equations(z: x c, m: x z c, y: m x z c) ///
        base_confs(c) post_confs(z) sim(20000) samples(2) seed(7)
    display "C oce X1: NDE=" %7.4f e(nde_1) " NIE=" %7.4f e(nie_1) ///
        " | X2: NDE=" %7.4f e(nde_2) " NIE=" %7.4f e(nie_2)
    assert abs(e(nde_1) - 0.62) < 0.06
    assert abs(e(nie_1) - 0.49) < 0.06
    assert abs(e(nde_2) - 1.24) < 0.06
    assert abs(e(nie_2) - 0.98) < 0.06
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: postconf_crossworld_oce"
}
else {
    local ++fail
    display as error "  FAIL: postconf_crossworld_oce (rc=`=_rc')"
}

display "RESULT: validation_postconfs_crossworld tests=`tests' pass=`pass' fail=`fail' status=" cond(`fail'==0, "PASS", "FAIL")
if `fail' > 0 exit 9
