/*  demo_simtab.do - Standalone simtab Monte Carlo demo

    Produces demo/demo_simtab.xlsx from deterministic replication-level data.
*/

version 17.0
local _demo_varabbrev = c(varabbrev)
set varabbrev off
set linesize 120

local pkg_dir "`c(pwd)'/simtab"
local demo_dir "`pkg_dir'/demo"
capture mkdir "`demo_dir'"

capture ado uninstall simtab
quietly net install simtab, from("`pkg_dir'") replace

clear
set seed 20260819
set obs 800
generate int sim = mod(_n - 1, 100) + 1
generate byte estimator = mod(floor((_n - 1) / 100), 2) + 1
generate byte scenario = mod(floor((_n - 1) / 200), 2) + 1
generate byte estimand = mod(floor((_n - 1) / 400), 2) + 1
label define estimator_lbl 1 "Method A" 2 "Method B"
label values estimator estimator_lbl
label define scenario_lbl 1 "Base" 2 "Stress"
label values scenario scenario_lbl
label define estimand_lbl 1 "Mean" 2 "Contrast"
label values estimand estimand_lbl
generate double true_value = cond(estimand == 1, 1, .5)
generate double se = cond(scenario == 1, .20, .30)
generate double estimate = true_value + (estimator == 2) * .05 + rnormal() * se
generate byte covered = abs(estimate - true_value) <= invnormal(.975) * se

capture erase "`demo_dir'/demo_simtab.xlsx"
simtab estimator, estimate(estimate) se(se) true(true_value) ///
    by(scenario) estimand(estimand) sim(sim) coverage(covered) nsim(100) ///
    metrics(mean bias empse meanse coverage n nonconv) ///
    xlsx("`demo_dir'/demo_simtab.xlsx") sheet("Performance") ///
    title("Monte Carlo performance") theme(nejm)

preserve
quietly import excel using "`demo_dir'/demo_simtab.xlsx", ///
    sheet("Performance") clear allstring
assert _N >= 8
count if A == "Monte Carlo performance"
assert r(N) == 1
restore

set varabbrev `_demo_varabbrev'

