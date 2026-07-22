/*  demo_tabtools_eplot.do - tabtools + eplot integration demo

    Demonstrates the table-to-forest-plot pipeline that tabtools and eplot
    share through the eplotframe() option. A regression table built by
    regtab/effecttab/comptab carries a graph-ready companion frame that
    eplot turns into a forest plot - no manual re-entry of estimates.

    This same demo ships in both the tabtools/demo and eplot/demo folders.

    Produces:
      1. Console output (regtab + comptab tables) -> console_tabtools_eplot.log
      2. Single-model forest plot (regtab -> eplot)   -> forest_regtab.png
      3. Model-comparison forest plot (comptab forest) -> forest_comptab.png
*/

version 16.0

* --- Session isolation ---------------------------------------------------
* This demo installs three packages. Doing that in the user's real sysdirs
* would PERSISTENTLY replace their installed tabtools, eplot and tc_schemes --
* a documentation asset must not repackage someone's ado tree. Install into
* disposable PLUS/PERSONAL trees instead, and snapshot every session setting
* this file changes so that sourcing it into a live session is also safe.
* This mirrors demo_tabtools.do; keep the two in step.
local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
local _orig_scheme "`c(scheme)'"
local _orig_linesize = c(linesize)
local _orig_varabbrev "`c(varabbrev)'"
local _orig_more "`c(more)'"
tempname _demo_id
local _demo_tag = subinstr("`_demo_id'", "__", "", .)
local _demo_plus "`c(tmpdir)'/tabtools_eplot_demo_plus_`_demo_tag'"
local _demo_personal "`c(tmpdir)'/tabtools_eplot_demo_personal_`_demo_tag'"
local _demo_isolated 0
local _demo_success ""

capture noisily {
set varabbrev off
set linesize 120

* --- Paths ---
* This file lives in either tabtools/demo or eplot/demo; both packages live
* in the same Stata-Tools repo, so install both from the repo root.
local repo_root "`c(pwd)'"
capture confirm file "`repo_root'/tabtools/tabtools.pkg"
if _rc {
    local repo_root = subinstr("`repo_root'", "/tabtools/demo", "", 1)
    local repo_root = subinstr("`repo_root'", "/eplot/demo", "", 1)
    capture confirm file "`repo_root'/tabtools/tabtools.pkg"
    if _rc {
        display as error "Run demo_tabtools_eplot.do from the Stata-Tools repo root, tabtools/demo, or eplot/demo"
        exit 601
    }
}
local pkg_dir "`repo_root'/tabtools/demo"
capture mkdir "`pkg_dir'"

* --- Install all three packages into the disposable tree ---
capture mkdir "`_demo_plus'"
capture mkdir "`_demo_personal'"
sysdir set PLUS "`_demo_plus'"
sysdir set PERSONAL "`_demo_personal'"
discard
local _demo_isolated 1

capture ado uninstall tabtools
quietly net install tabtools, from("`repo_root'/tabtools") replace
capture ado uninstall eplot
quietly net install eplot, from("`repo_root'/eplot") replace

* --- Graph scheme ---
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`repo_root'/tc_schemes") replace
set scheme plotplainblind

**# Build analysis dataset
use "`repo_root'/_data/cohort.dta", clear
merge 1:1 id using "`repo_root'/_data/treatment.dta", nogen keep(match)
merge 1:1 id using "`repo_root'/_data/comorbidities.dta", nogen keep(master match) nolabel
merge 1:1 id using "`repo_root'/_data/outcomes.dta", nogen keep(master match)

foreach v in diabetes hypertension anxiety prior_cvd {
    replace `v' = 0 if missing(`v')
}

gen byte cv_event = (cv_event_date < .)
label variable cv_event "Cardiovascular event"

label define female_lbl 0 "Male" 1 "Female", replace
label values female female_lbl
label variable treated "Treated"
label variable index_age "Age at index"
label variable diabetes "Diabetes"
label variable hypertension "Hypertension"
label variable prior_cvd "Prior CVD"

**# Console output
* Close only this demo's named log (not _all) so the demo stays embeddable in
* the release gate without closing the caller's log. Matches demo_tabtools.do.
capture log close demo
log using "`pkg_dir'/console_tabtools_eplot.log", replace text name(demo) nomsg

* # tabtools + eplot integration

* The same effect estimates feed both a publication table and a forest plot.
* regtab builds the odds-ratio table and, with eplotframe(), stores a
* graph-ready companion frame that eplot reads directly.

* ## Adjusted odds-ratio table (regtab)

collect clear
quietly collect: logistic cv_event treated index_age female diabetes hypertension prior_cvd
noisily regtab, coef("OR") noint eplotframe(or_effects, replace)

* ## Model comparison table (comptab)

* Crude and adjusted treatment effects, each captured as a regtab frame, then
* combined with comptab. The composite carries its own eplot companion frame.

collect clear
quietly collect: logistic cv_event treated
quietly regtab, coef("OR") noint frame(m_crude, replace) eplotframe(e_crude, replace)

collect clear
quietly collect: logistic cv_event treated index_age female diabetes hypertension prior_cvd
quietly regtab, coef("OR") noint frame(m_adj, replace) eplotframe(e_adj, replace)

noisily comptab m_crude m_adj, rows(1 \ 1) ///
    section("Crude" \ "Adjusted") ///
    title("Treatment effect across specifications")

log close demo

**# Graph 1: single-model forest plot (regtab -> eplot)
* The companion frame stored above is plotted with eplot frame mode.
eplot, frame(or_effects) labels(label) rowtype(rowtype) ///
    null(1) values stars vformat(%4.2f) ///
    effect("Odds Ratio (95% CI)") ///
    title("Predictors of cardiovascular events") ///
    subtitle("Adjusted logistic model - regtab to eplot")
graph export "`pkg_dir'/forest_regtab.png", replace width(1400)
capture graph close _all

**# Graph 2: model-comparison forest plot (comptab forest one-step)
* comptab's forest option calls eplot directly from the composite frame.
collect clear
quietly collect: logistic cv_event treated
quietly regtab, coef("OR") noint frame(g_crude, replace) eplotframe(ge_crude, replace)

collect clear
quietly collect: logistic cv_event treated index_age female diabetes hypertension prior_cvd
quietly regtab, coef("OR") noint frame(g_adj, replace) eplotframe(ge_adj, replace)

comptab g_crude g_adj, rows(1 \ 1) ///
    section("Crude" \ "Adjusted") ///
    forest ///
    eplotoptions(null(1) title("Treatment effect: crude vs adjusted") ///
        subtitle("comptab forest - one-step table to plot") ///
        name(forest_comptab, replace))
graph export "`pkg_dir'/forest_comptab.png", replace width(1400)
capture graph close _all

* --- Cleanup ---
clear
capture frame change default
foreach f in or_effects m_crude m_adj e_crude e_adj g_crude g_adj ge_crude ge_adj {
    capture frame drop `f'
}

local _demo_success "1"
}
local _rc = _rc
if "`_demo_success'" == "1" local _rc = 0

* --- Restore the session exactly as we found it -------------------------
set scheme `_orig_scheme'
set linesize `_orig_linesize'
set varabbrev `_orig_varabbrev'
set more `_orig_more'
if `_demo_isolated' {
    capture ado uninstall tabtools
    capture ado uninstall eplot
    capture ado uninstall tc_schemes
    sysdir set PLUS "`_orig_plus'"
    sysdir set PERSONAL "`_orig_personal'"
    discard
    capture shell rm -rf "`_demo_plus'" "`_demo_personal'"
}
if `_rc' exit `_rc'
