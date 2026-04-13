clear all
capture ado uninstall tabtools
quietly net install tabtools, from("/home/tpcopeland/Stata-Tools/tabtools") replace
sysuse auto, clear
gen fw = 1
capture noisily crosstab foreign rep78 [fw=fw], exact display
local rc = _rc
display as text "RC=`rc'"
exit 0
