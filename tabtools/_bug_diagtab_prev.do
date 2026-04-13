clear all
capture ado uninstall tabtools
quietly net install tabtools, from("/home/tpcopeland/Stata-Tools/tabtools") replace
sysuse auto, clear
gen byte foreign2 = foreign
capture noisily diagtab foreign2 foreign, prevalence(1.2) display
local rc = _rc
display as text "RC=`rc'"
exit 0
