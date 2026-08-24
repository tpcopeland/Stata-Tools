*! test_simtab_documentation_examples.do - executable simtab.sthlp compute examples
version 17.0
clear all
set more off
set varabbrev off
capture log close _all

local tests = 0
local pass = 0
local fail = 0
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall simtab
quietly net install simtab, from("`pkg_dir'") replace

* simtab.sthlp compute-mode examples require posted results in memory.
local ++tests
capture noisily {
    clear
    set obs 8
    gen long sim = _n
    expand 2
    bysort sim: gen byte estimator = _n
    gen byte scenario = mod(sim, 2) + 1
    gen str10 estimand = cond(estimator == 1, "marginal", "contrast")
    gen double estimate = cond(estimator == 1, .10, .50) + (sim - 4) / 1000
    gen double se = .04
    gen double true_value = cond(estimand == "marginal", .10, .50)
    gen byte covered = 1
    simtab estimator, estimate(estimate) se(se) true(true_value) ///
        by(scenario) estimand(estimand) sim(sim) coverage(covered) nsim(1000) ///
        metrics(mean bias empse meanse coverage n nonconv) ///
        xlsx("sim.xlsx") sheet("Table 2") title("Simulation results") ///
        borderstyle(academic) digits(3) plotframe(sim_plot, replace) display
    assert r(N_input) == 16
    frame sim_plot: assert _N > 0
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_simtab_documentation_examples tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 9
