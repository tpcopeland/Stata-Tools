clear all
set more off
version 16.0

clear
set obs 10
gen x = _n
gen y = _n * 2

mvp

display as text "Return values:"
display as text "  r(N) = " r(N)
display as text "  r(N_complete) = " r(N_complete)
display as text "  r(N_incomplete) = " r(N_incomplete)
display as text "  r(N_vars) = " r(N_vars)
display as text "  r(N_patterns) = " r(N_patterns)
