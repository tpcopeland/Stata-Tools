/*  demo_spaghetti.do - Generate screenshots for spaghetti

    Produces 5 output types:
      1. Console output (return values)           -> .smcl
      2. Graph: basic trajectories with by+mean    -> basic_by_mean.png
      3. Graph: sampled with mean overlay           -> sampled_mean.png
      4. Graph: highlighted individuals             -> highlight.png
      5. Graph: colorby continuous                  -> colorby.png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "spaghetti/demo"
capture mkdir "`pkg_dir'"

* --- Load command ---
capture program drop spaghetti
quietly run spaghetti/spaghetti.ado
capture program drop _spaghetti_sample
quietly run spaghetti/_spaghetti_sample.ado
capture program drop _spaghetti_mean
quietly run spaghetti/_spaghetti_mean.ado

* --- Create synthetic longitudinal data ---
* 100 patients, 12 monthly visits, 2 treatment groups
clear
set seed 20260226
quietly set obs 1200
quietly gen patid = ceil(_n / 12)
bysort patid: gen months = _n - 1
quietly gen byte treatment = (patid > 50)
quietly gen double sdmt = 50 + 1.5*months ///
    - 2.5*treatment*months ///
    + rnormal(0, 4)
quietly gen double baseline_score = .
bysort patid (months): replace baseline_score = sdmt[1]

label variable sdmt "SDMT Score"
label variable months "Months from Baseline"
label define tx 0 "Placebo" 1 "Active"
label values treatment tx

* --- 1. Console output (return values) ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo)

noisily spaghetti sdmt, id(patid) time(months) by(treatment) ///
    mean(bold ci) sample(40) seed(42)
noisily return list

log close demo

* --- 2. By-group trajectories with mean + CI ---
spaghetti sdmt, id(patid) time(months) by(treatment) ///
    mean(bold ci) sample(50) seed(42) ///
    title("SDMT Trajectories by Treatment Group") ///
    name(demo_by_mean)
graph export "`pkg_dir'/basic_by_mean.png", replace width(1200)
capture graph close _all

* --- 3. Sampled trajectories with mean overlay ---
spaghetti sdmt, id(patid) time(months) ///
    mean(bold ci) sample(30) seed(42) ///
    title("Individual Trajectories with Population Mean") ///
    name(demo_sampled)
graph export "`pkg_dir'/sampled_mean.png", replace width(1200)
capture graph close _all

* --- 4. Highlighted individuals ---
spaghetti sdmt, id(patid) time(months) by(treatment) ///
    highlight(patid==5 | patid==55) ///
    mean(bold) ///
    title("Highlighted Patient Trajectories") ///
    name(demo_highlight)
graph export "`pkg_dir'/highlight.png", replace width(1200)
capture graph close _all

* --- 5. Colorby baseline score ---
spaghetti sdmt, id(patid) time(months) ///
    colorby(baseline_score) sample(60) seed(42) ///
    title("Trajectories Colored by Baseline Score") ///
    name(demo_colorby)
graph export "`pkg_dir'/colorby.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
