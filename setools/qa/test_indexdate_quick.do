// Quick test of indexdate syntax
version 16.0
set more off
set varabbrev off

// Force reload of synthdata program
cap program drop synthdata
cap program drop _synthdata_indexdate_analyze
cap program drop _synthdata_apply_offsets
run synthdata/synthdata.ado

clear
set obs 10
set seed 42
gen double indexdate = _n
gen double visitdate = _n + 30
format *date %td
synthdata, dates(indexdate visitdate) indexdate(indexdate) datenoise(14) smart replace
di "SUCCESS: indexdate syntax parsed correctly"
