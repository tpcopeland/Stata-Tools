* gallery_eplot_outcomes.do - SNRI vs SSRI adjusted hazard ratios across four outcomes
* Run with the working directory set to the Stata-Tools repository root.
* Route: stcox -> collect -> regtab (eplotframe) -> comptab (eplotframe) -> eplot, frame()
version 17.0  // regtab and comptab (tabtools) need Stata 17
set linesize 120
set more off

net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
net install tabtools, from("`c(pwd)'/tabtools") replace
net install eplot, from("`c(pwd)'/eplot") replace
set scheme white_tableau
assert "`c(scheme)'" == "white_tableau"

use _data/cohort.dta, clear
merge 1:1 id using _data/treatment.dta, nogen assert(match)
merge 1:1 id using _data/outcomes.dta, nogen assert(match)

* Follow-up from study_entry to the earlier of the event date or study_exit;
* one adjusted Cox model per outcome, each tabulated by regtab
local k = 0
foreach o in cv_event selfharm fracture gi_bleed {
    local ++k
    generate byte f_`o' = !missing(`o'_date) & `o'_date <= study_exit
    generate long x_`o' = cond(f_`o', `o'_date, study_exit)
    quietly stset x_`o', failure(f_`o') origin(study_entry) scale(365.25)
    collect clear
    quietly collect: stcox i.treated index_age i.female i.education i.born_abroad
    quietly regtab, coef("HR") noint frame(m`k', replace) eplotframe(e`k', replace)
}

* Row 3 of each regtab frame is the SNRI-vs-SSRI hazard ratio
comptab m1 m2 m3 m4, rows(3 \ 3 \ 3 \ 3) ///
    section("Cardiovascular event" \ "Self-harm" \ "Fracture" \ "GI bleeding") ///
    eplotframe(ec, replace) frame(cc, replace)

eplot, frame(ec) null(1, lcolor(gs10) lwidth(medthick) lpattern(solid)) logscale ///
    values vformat(%4.2f) vtitle("HR (95% CI)") vsize(medlarge) vgap(.08) vcolor(gs3) ///
    labsize(medlarge) mcolor("213 94 0") msize(vlarge) cicolor("213 94 0") ///
    ciwidth(thick) cicap xlabel(.85 1 1.15, labsize(medlarge)) ///
    effect("Hazard ratio, SNRI vs SSRI") favors("Favors SNRI" "Favors SSRI") ///
    title("Adjusted hazard ratios", size(large)) xsize(6) ysize(4)
graph export _resources/gallery/eplot_outcomes.png, replace width(1600)
