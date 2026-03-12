clear all
discard
adopath + "/home/tpcopeland/Stata-Tools/tte"
which _tte_check_expanded
capture _tte_check_expanded
display "rc = " _rc
