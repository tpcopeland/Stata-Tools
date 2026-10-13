* gallery_psdash_balance.do - psdash's native Love plot, unweighted vs PS-weighted SMDs
* Run with the working directory set to the Stata-Tools repository root.
version 16.0
set seed 20261012
set linesize 120
clear all

quietly net install psdash, from("`c(pwd)'/psdash") replace
quietly net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
set scheme white_tableau
assert c(scheme) == "white_tableau"

use _data/cohort.dta, clear
merge 1:1 id using _data/treatment.dta, nogen assert(match)
merge 1:1 id using _data/comorbidities.dta, nogen
merge 1:1 id using _data/cci.dta, nogen assert(match)
generate byte married = (civil_status == 2) if !missing(civil_status)

* psdash 1.8.0 labels Love-plot rows with variable labels; short ones keep the
* plot region wide enough for the ~350px README tile.
label variable female "Female"
label variable index_age "Age"
label variable education "Education"
label variable income_quintile "Income quintile"
label variable born_abroad "Born abroad"
label variable married "Married"
label variable diabetes "Diabetes"
label variable hypertension "Hypertension"
label variable anxiety "Anxiety"
label variable prior_cvd "Prior CVD"
label variable charlson "Charlson index"

local cov female index_age education income_quintile born_abroad married ///
    diabetes hypertension anxiety prior_cvd charlson
logit treated `cov', nolog
predict double ps, pr

psdash balance treated ps, covariates(`cov') estimand(ate) loveplot ///
    title("Covariate balance, SNRI vs SSRI") scheme(white_tableau) ///
    graphoptions(xsize(6) ysize(4) xlabel(-.1 0 .1, labsize(medlarge)) ///
    xscale(range(-.14 .14)) ylabel(1(1)11, valuelabel angle(0) labsize(medlarge)) ///
    xtitle("Standardized mean difference", size(medlarge)) ///
    title("Covariate balance, SNRI vs SSRI", size(large)) ///
    legend(order(1 "Unweighted" 2 "PS-weighted") rows(1) position(6) size(medlarge)))

capture mkdir _resources
capture mkdir _resources/gallery
graph export "_resources/gallery/psdash_balance.png", width(1600) replace
