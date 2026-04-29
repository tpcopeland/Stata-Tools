/*  demo_gcomp.do - Demo output for gcomp

    Produces:
      1. Console output (mediation + time-varying) -> .log -> .md via logdoc
      2. Excel table (gcomptab export)              -> .xlsx

    Covers:
      - OBE mediation (binary exposure)
      - CDE (controlled direct effect)
      - OCE mediation (categorical exposure)
      - Time-varying confounding (longitudinal)
      - gcomptab Excel export

    Note: Bootstrap samples kept low (50) for demo speed.
    Use samples(1000) for real analyses.
*/

version 16.0
set varabbrev off
set linesize 120

* --- Paths ---
local demo_dir "`c(pwd)'/gcomp/demo"
capture mkdir "`demo_dir'"

* --- Install package from local source ---
capture ado uninstall gcomp
quietly net install gcomp, from("`c(pwd)'/gcomp") replace
discard

**# Console output

capture log close _all
log using "`demo_dir'/console_output.log", replace text name(demo) nomsg

* # Binary-exposure mediation (OBE)

quietly {
    clear
    set seed 12345
    set obs 1000
    gen double c = rnormal(50, 10)
    gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
    gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))
}

noisily gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(50) seed(42)

* # Controlled direct effect (CDE)

noisily gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) control(0) sim(500) samples(50) seed(42)

* # Categorical-exposure mediation (OCE)

quietly {
    clear
    set seed 54321
    set obs 1000
    gen double c = rnormal()
    gen double x = floor(runiform() * 3)
    gen double m = rbinomial(1, invlogit(-0.5 + 0.3 * x + 0.2 * c))
    gen double y = rbinomial(1, invlogit(-1 + 0.4 * m - 0.2 * x + 0.1 * c))
}

noisily gcomp y m x c, outcome(y) mediation oce ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(50) seed(42)

* # Time-varying confounding

quietly {
    clear
    set seed 20260421
    set obs 360
    gen long id = ceil(_n / 3)
    bysort id: gen int time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0

    bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1

    bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2

    bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3

    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1

    gen byte outcome = 0
    bysort id (time): replace outcome = rbinomial(1, ///
        invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3
}

noisily gcomp outcome L0 A L Alag Llag id time, outcome(outcome) ///
    idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(L0) ///
    laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
    commands(A: logit, outcome: logit, L: regress) ///
    equations(A: L0 L, outcome: Alag Llag L0, L: Alag Llag L0) ///
    intvars(A) interventions(A=1, A=0) ///
    sim(120) samples(5) seed(20260421) eofu

log close demo

**# Excel export (gcomptab)

quietly {
    clear
    set seed 12345
    set obs 1000
    gen double c = rnormal(50, 10)
    gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
    gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))
}

gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) control(0) sim(500) samples(50) seed(42) all

gcomptab, xlsx("`demo_dir'/demo_gcomptab.xlsx") sheet("Normal CI") ///
    title("Table 1. Causal Mediation Analysis (Normal CIs)")

gcomptab, xlsx("`demo_dir'/demo_gcomptab.xlsx") sheet("Percentile CI") ///
    ci(percentile) title("Table 2. Mediation Results (Percentile CIs)")

**# Convert console log to markdown via logdoc

capture ado uninstall logdoc
quietly net install logdoc, from("~/Stata-Tools/logdoc") replace

logdoc using "`demo_dir'/console_output.log", ///
    output("`demo_dir'/console_output.md") ///
    format(md) replace quiet

* --- Cleanup ---
clear
