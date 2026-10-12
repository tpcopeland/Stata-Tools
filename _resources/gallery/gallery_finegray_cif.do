* gallery_finegray_cif.do - Fine-Gray cumulative incidence of a first cardiovascular event, death competing
* Run with the working directory set to the Stata-Tools repository root.
version 16.0
set linesize 120
set more off

net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
net install finegray, from("`c(pwd)'/finegray") replace
set scheme white_tableau
assert "`c(scheme)'" == "white_tableau"

use _data/cohort.dta, clear
merge 1:1 id using _data/treatment.dta, nogen assert(match)
merge 1:1 id using _data/outcomes.dta, nogen assert(match)

* status: 1 = first cardiovascular event, 2 = death first (competing), 0 = censored at study_exit
generate byte cvf = !missing(cv_event_date) & cv_event_date <= study_exit
generate byte dth = !missing(death_date) & death_date <= study_exit
generate byte status = cond(cvf & (!dth | cv_event_date <= death_date), 1, cond(dth, 2, 0))
generate long endd = cond(status == 1, cv_event_date, cond(status == 2, death_date, study_exit))
generate byte anyev = status > 0
stset endd, failure(anyev) origin(study_entry) scale(365.25) id(id)

finegray i.treated index_age i.female i.education i.born_abroad, compete(status) cause(1) nolog

* CIFs by arm with analytic pointwise 95% bands, all computed by finegray_cif
finegray_cif, over(treated) ci timepoints(0(0.1)17.9) ///
    plot1opts(lcolor("0 114 178") lwidth(medthick)) plot2opts(lcolor("213 94 0") lwidth(medthick)) ///
    ci1opts(color("0 114 178%22") lwidth(none)) ci2opts(color("213 94 0%22") lwidth(none)) ///
    title("Cumulative incidence of cardiovascular events", size(large)) ///
    xtitle("Years since cohort entry", size(medlarge)) ytitle("") ///
    xlabel(0(5)15, labsize(medlarge)) ///
    ylabel(0 "0%" .2 "20%" .4 "40%" .6 "60%", labsize(medlarge) angle(0)) ///
    legend(ring(0) position(5) cols(1) size(large) region(fcolor(white) lstyle(none)) ///
        order(3 4) label(3 "SSRI") label(4 "SNRI")) xsize(6) ysize(4)
graph export _resources/gallery/finegray_cif.png, replace width(1600)
