*! tabtools theme-option removal regression tests
version 16.0
clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

sysuse auto, clear

capture noisily table1_tc, by(foreign) vars(price contn) theme(lancet)
assert _rc == 198
capture noisily tabtools set theme lancet
assert _rc == 198

display as result "RESULT: test_theme_removed tests=2 pass=2 fail=0"
exit 0
