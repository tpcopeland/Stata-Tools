/*  demo_simtab.do - Monte Carlo simulation performance tables with simtab

    simtab turns replication-level simulation results (or an already-computed
    summary) into a styled, exportable performance table. It pairs with simsum
    and siman, which own the statistics; simtab owns the publication table.

    Produces:
      1. Console output (4 tables) -> .log -> .md via logdoc
           a. compute mode: scenarios x estimators, with non-convergence
              reporting (nsim) and off-nominal coverage flagging
           b. multi-estimand markdown report (merged-header Excel + flat md)
           c. figure-ready numeric companion frame (plotframe)
           d. ingest mode: render a pre-computed per-cell summary (from(summary))
      2. Excel workbook (2 sheets) -> demo_simtab.xlsx
      3. Markdown report           -> demo_simtab_report.md
*/

version 16.0
set varabbrev off
set linesize 120

* --- Paths ---
local pkg_dir "tabtools/demo"
local repo_root "`c(pwd)'"
capture mkdir "`pkg_dir'"

* --- Install package from local source ---
capture ado uninstall tabtools
quietly net install tabtools, from("`repo_root'/tabtools") replace

* --- Clean prior artifacts so the demo is idempotent ---
capture erase "`pkg_dir'/demo_simtab.xlsx"
capture erase "`pkg_dir'/demo_simtab_report.md"
capture erase "`pkg_dir'/console_simtab.log"
capture erase "`pkg_dir'/console_simtab.md"

* =====================================================================
* Synthetic replication-level results (IIVW-style)
*   3 scenarios x 3 estimators x 2 estimands, ~400 replications each.
*   Unweighted is biased (low coverage); IIW is well-calibrated;
*   IIW + log(test) carries a small residual bias. A handful of
*   Unweighted fits "fail" to convergence and are dropped, so n < nsim.
* =====================================================================
clear
set seed 20260608
local R 400
set obs `R'
gen long sim = _n
expand 3
bysort sim: gen byte estid = _n
expand 3
bysort sim estid: gen byte scen = _n
expand 2
bysort sim estid scen: gen byte emd = _n

label define sclbl  1 "A" 2 "B" 3 "C", replace
label values scen sclbl
label define estlbl 1 "Unweighted" 2 "IIW" 3 "IIW + log(test)", replace
label values estid estlbl
label define emdlbl 1 "Marginal slope" 2 "Treatment contrast", replace
label values emd emdlbl
label variable scen "Scenario"
label variable estid "Estimator"

gen double truev = cond(emd==1, 0.10, 0.50)
* estimator-specific bias on the estimate scale, with a mild scenario nudge
gen double bias_e = cond(estid==1, 0.05, cond(estid==3, 0.02, 0)) + 0.008*(scen-2)
gen double sd_e = 0.04
gen double est = truev + bias_e + rnormal(0, sd_e)
gen double se  = sd_e + runiform()*0.004
gen double lo  = est - 1.96*se
gen double hi  = est + 1.96*se
gen byte covered = (lo <= truev & truev <= hi)

* simulate ~6% non-convergence for the Unweighted estimator
gen double _u = runiform()
drop if estid==1 & _u < 0.06
drop _u bias_e sd_e

label variable est "Slope estimate"
tempfile reps
quietly save "`reps'"

**# Console output
capture log close _all
log using "`pkg_dir'/console_simtab.log", replace text name(demo) nomsg

* # simtab: Monte Carlo simulation performance tables

* simtab summarizes one row per replication x estimator x estimand x scenario
* into table-grade performance measures, then styles and exports the table.

* ## Compute mode: scenarios, estimators, non-convergence, coverage flag

* The intended replication count is nsim(400). Estimators whose fits failed
* to converge show nfail > 0 via the nonconv column. Coverage that deviates
* from the nominal 95% by more than 2 Monte Carlo SEs is flagged with "*".

use "`reps'", clear
keep if emd == 1
noisily simtab estid, estimate(est) se(se) true(truev)              ///
    by(scen) sim(sim) coverage(covered) nsim(400)                   ///
    metrics(mean bias empse meanse coverage n nonconv)              ///
    digits(3) xlsx("`pkg_dir'/demo_simtab.xlsx") sheet("Scenarios") ///
    title("Simulation results by scenario (400 replications)")      ///
    footnote("Coverage is empirical 95% CI coverage; * flags off-nominal coverage.") ///
    display

* ## Figure-ready companion frame (plotframe)

* plotframe() stores one row per by x estimator x estimand cell with the raw
* measures and their Monte Carlo SEs - the structured source for figures,
* replacing the fragile "parse a text log" boundary.

use "`reps'", clear
keep if emd == 1
quietly simtab estid, estimate(est) se(se) true(truev)   ///
    by(scen) sim(sim) coverage(covered) nsim(400)        ///
    metrics(mean bias empse coverage n) plotframe(simfig, replace)
frame simfig: format mean bias empse %6.3f
frame simfig: format coverage mcse_coverage %5.3f
noisily frame simfig: list by_label estimator_label mean bias empse ///
    coverage mcse_coverage nfail n, noobs sepby(by_label)

* ## Ingest mode: render a pre-computed summary (from(summary))

* When the per-cell numbers already exist - computed by simsum, siman, or any
* collapse - simtab renders them without recomputation. from(summary) maps the
* columns explicitly and never depends on an external package.

use "`reps'", clear
keep if emd == 1
collapse (mean) avg=est (sd) sdest=est (mean) cov=covered ///
    (count) nrep=est, by(scen estid)
gen double b = avg - 0.10
noisily list scen estid avg b sdest cov nrep, noobs sepby(scen)
noisily simtab, from(summary) byvar(scen) estimatorvar(estid)         ///
    measures(mean=avg bias=b empse=sdest coverage=cov n=nrep)         ///
    title("Ingested per-cell summary (no recomputation)") display

log close demo

**# Multi-estimand: merged-header Excel + flattened Markdown report

* Two estimands become a merged column group in Excel (one block per estimand)
* and flattened "Estimand: metric" columns in Markdown/CSV.
use "`reps'", clear
simtab estid, estimate(est) se(se) true(truev)                       ///
    by(scen) estimand(emd) sim(sim) coverage(covered) nsim(400)      ///
    metrics(mean bias coverage n)                                    ///
    digits(3) xlsx("`pkg_dir'/demo_simtab.xlsx") sheet("Multi-estimand") ///
    title("Simulation results by scenario and estimand")             ///
    footnote("Coverage is empirical 95% CI coverage.")               ///
    markdown("`pkg_dir'/demo_simtab_report.md") borderstyle(academic) zebra

* verify the Excel merged-header row was written
* layout: 2 lead cols + 4 metrics x 2 estimands = 10 cols (A-J);
* estimand group labels sit at the block-start columns C and G of row 2
import excel using "`pkg_dir'/demo_simtab.xlsx", sheet("Multi-estimand") ///
    cellrange(A2:J2) clear allstring
assert C[1] == "Marginal slope"
assert G[1] == "Treatment contrast"

**# Convert console logs to markdown via logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`repo_root'/logdoc") replace
logdoc using "`pkg_dir'/console_simtab.log",   ///
    output("`pkg_dir'/console_simtab.md")      ///
    format(md) replace quiet

* --- Cleanup ---
capture frame drop simfig
clear
