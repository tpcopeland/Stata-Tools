* Test synthdata with large dataset
clear all
set more off

di "Creating test dataset with 50000 obs..."
set obs 50000
gen x1 = rnormal()
gen x2 = rnormal() + 0.5*x1
gen x3 = rnormal() + 0.3*x2
gen x4 = rnormal()
gen x5 = rnormal()

di "Testing synthdata empirical with 50000 obs, 5 continuous vars..."
synthdata x1-x5, n(50000) empirical seed(12345) clear
di "Rows: " _N
su

di _n "Test with correlation preservation..."
clear
set obs 50000
gen x1 = rnormal()
gen x2 = rnormal() + 0.5*x1
gen x3 = rnormal() + 0.3*x2
gen x4 = rnormal()
gen x5 = rnormal()

synthdata x1-x5, n(50000) empirical correlations seed(12345) clear
di "Rows: " _N
su

di _n "TESTS COMPLETED SUCCESSFULLY"
