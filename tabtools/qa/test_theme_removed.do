*! tabtools theme-option removal regression tests
version 16.0
clear all
set more off

sysuse auto, clear

capture noisily table1_tc, by(foreign) vars(price contn) theme(lancet)
assert _rc == 198
capture noisily tabtools set theme lancet
assert _rc == 198

display as result "RESULT: test_theme_removed tests=2 pass=2 fail=0"
exit 0
