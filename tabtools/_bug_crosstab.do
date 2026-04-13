clear all
capture ado uninstall tabtools
quietly net install tabtools, from("/home/tpcopeland/Stata-Tools/tabtools") replace
clear
input byte(r c)
1 1
1 2
2 1
2 3
3 2
end
capture noisily crosstab r c, display
local rc = _rc
display as text "RC=`rc'"
exit 0
