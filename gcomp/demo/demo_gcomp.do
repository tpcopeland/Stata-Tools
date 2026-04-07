/*  demo_gcomp.do - G-computation formula demo

    Demonstrates gcomp in two modes:
      1. Causal mediation (binary exposure, OBE)
      2. Causal mediation (categorical exposure, OCE)

    Produces:
      - Console output (both analyses) -> .smcl

    Note: Bootstrap samples kept low (50) for demo speed.
    Use samples(1000) for real analyses.
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "gcomp/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop gcomp
capture program drop _gcomp_bootstrap
capture program drop _gcomp_display_stats
capture program drop _gcomp_detangle
capture program drop _gcomp_formatline
quietly run gcomp/gcomp.ado

* --- Begin console log ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* =====================================================================
* EXAMPLE 1: Mediation with binary exposure (OBE)
* =====================================================================
* Scenario: Does smoking (x) affect lung function (y),
*   and how much is mediated through inflammation (m)?
*   Adjusted for age (c).

noisily display as text "EXAMPLE 1: Binary exposure mediation (OBE)"

clear
set seed 12345
set obs 1000

* Generate data with known causal structure
gen double c = rnormal(50, 10)
gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))

noisily gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(50) seed(42)

* =====================================================================
* EXAMPLE 2: Mediation with categorical exposure (OCE)
* =====================================================================
* Scenario: Physical activity level (0=none, 1=moderate, 2=high)
*   affecting depression (y), mediated through sleep quality (m).

noisily display _newline
noisily display as text "EXAMPLE 2: Categorical exposure mediation (OCE)"

clear
set seed 54321
set obs 1000

gen double c = rnormal()
gen double x = floor(runiform() * 3)
gen double m = rbinomial(1, invlogit(-0.5 + 0.3 * x + 0.2 * c))
gen double y = rbinomial(1, invlogit(-1 + 0.4 * m - 0.2 * x + 0.1 * c))

noisily gcomp y m x c, outcome(y) mediation oce ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(50) seed(42)

log close demo

* --- Cleanup ---
clear
