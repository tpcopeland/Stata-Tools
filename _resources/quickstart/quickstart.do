foreach p in tabtools kmplot tc_schemes {
    capture ado uninstall `p'
    net install `p', from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/`p'") replace
}

local data "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data"
use "`data'/cohort.dta", clear
merge 1:1 id using "`data'/treatment.dta", nogenerate
merge 1:1 id using "`data'/outcomes.dta", nogenerate keepusing(cv_event_date)

* Table 1 with standardized mean differences, to Excel and Markdown
table1_tc index_age female education income_quintile born_abroad, ///
    by(treated) smd xlsx("table1.xlsx") markdown("table1.md")

* Time to first cardiovascular event
generate cv   = !missing(cv_event_date) & cv_event_date <= study_exit
generate exit = cond(cv, cv_event_date, study_exit)
stset exit, failure(cv) origin(study_entry) scale(365.25)

set scheme white_tableau
kmplot, by(treated) failure ci risktable pvalue ///
    title("First cardiovascular event") xtitle("Years since initiation")
graph export "_resources/quickstart/quickstart_kmplot.png", width(1600) replace
