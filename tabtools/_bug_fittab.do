clear all
capture ado uninstall tabtools
quietly net install tabtools, from("/home/tpcopeland/Stata-Tools/tabtools") replace
sysuse auto, clear
regress price mpg
estimates store m0
regress price mpg weight
estimates store m1
regress price weight
local before "`e(cmd)'"
capture noisily fittab m1 missing_model, display
local rc = _rc
display as text "RC=`rc'"
display as text "BEFORE=`before' AFTER=`e(cmd)'"
exit 0
