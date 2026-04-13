clear all
capture ado uninstall tabtools
quietly net install tabtools, from("/home/tpcopeland/Stata-Tools/tabtools") replace
clear
set obs 5
gen test = .
gen gold = .
capture noisily diagtab test gold, display
local rc = _rc
display as text "RC=`rc'"
return list
exit 0
