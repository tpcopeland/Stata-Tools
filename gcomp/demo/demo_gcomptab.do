/*******************************************************************************
* demo_gcomptab.do
*
* Purpose: Demonstrate the gcomptab command for exporting gcomp mediation
*          results to publication-ready Excel tables
*
* Pipeline: generate synthetic data → run gcomp → export with gcomptab
*
* Author: Timothy P Copeland
* Date: 2026-03-01
*******************************************************************************/

clear all
set more off
version 16.0

* --- Reload gcomptab from local source ---
capture program drop gcomptab
capture program drop _gcomptab_validate_path
quietly run gcomp/gcomptab.ado

* =============================================================================
* GENERATE SYNTHETIC MEDIATION DATA
* =============================================================================
* DGP: x → m → y with confounding by c
*   c ~ N(0,1)
*   x ~ Bernoulli(invlogit(-0.5 + 0.3*c))
*   m ~ Bernoulli(invlogit(-1 + 0.8*x + 0.5*c))
*   y ~ Bernoulli(invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

clear
set seed 20260301
set obs 1000
gen double c = rnormal()
gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

label variable x "Treatment (binary)"
label variable m "Mediator (binary)"
label variable y "Outcome (binary)"
label variable c "Confounder (continuous)"

* =============================================================================
* RUN GCOMP MEDIATION ANALYSIS
* =============================================================================

* OBE mediation with all CI types and CDE
gcomp y m x c, outcome(y) mediation obe ///
	exposure(x) mediator(m) ///
	commands(m: logit, y: logit) ///
	equations(m: x c, y: m x c) ///
	base_confs(c) control(0) sim(500) samples(200) seed(1) all

* =============================================================================
* EXPORT WITH GFORMTAB
* =============================================================================

* Basic export with normal CIs
gcomptab, xlsx(gcomp/demo/demo_gcomptab.xlsx) sheet("Normal CI") ///
	title("Table 1. Causal Mediation Analysis (Normal CIs)")

* Percentile CIs on a second sheet
gcomptab, xlsx(gcomp/demo/demo_gcomptab.xlsx) sheet("Percentile CI") ///
	ci(percentile) title("Table 2. Mediation Results (Percentile CIs)")

* Custom labels with higher precision
gcomptab, xlsx(gcomp/demo/demo_gcomptab.xlsx) sheet("Custom") ///
	labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ CDE") ///
	effect("RD") decimal(4) ///
	title("Table 3. Risk Difference Decomposition")
