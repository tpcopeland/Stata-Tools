* Literal executable examples from tc_schemes.sthlp.

version 16.0
clear all
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Literal catalogue examples return the documented semantic results
local ++test_count
capture noisily {
    tc_schemes
    assert !missing(r(n_schemes))
    assert r(n_schemes) == 45
    tc_schemes, detail
    assert r(n_schemes) == 45
    tc_schemes, source(blindschemes) list
    assert r(n_schemes) == 4
    assert "`r(sources)'" == "blindschemes"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Literal all-session scheme example creates a graph under plotplain
local ++test_count
capture noisily {
    set scheme plotplain
    sysuse auto, clear
    scatter mpg weight
    tempfile plotplain_svg
    local plotplain_file "`plotplain_svg'.svg"
    graph export "`plotplain_file'", replace
    tempname plotplain_fh
    file open `plotplain_fh' using "`plotplain_file'", read text
    local plotplain_svg_found = 0
    file read `plotplain_fh' plotplain_line
    while r(eof) == 0 {
        if strpos(lower(`"`plotplain_line'"'), "<svg") > 0 local plotplain_svg_found = 1
        file read `plotplain_fh' plotplain_line
    }
    file close `plotplain_fh'
    assert `plotplain_svg_found' == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Literal single-graph and visual-comparison examples retain named graphs
local ++test_count
capture noisily {
    sysuse auto, clear
    scatter mpg weight, scheme(white_tableau)
    tempfile tableau_svg
    local tableau_file "`tableau_svg'.svg"
    graph export "`tableau_file'", replace
    tempname tableau_fh
    file open `tableau_fh' using "`tableau_file'", read text
    local tableau_svg_found = 0
    file read `tableau_fh' tableau_line
    while r(eof) == 0 {
        if strpos(lower(`"`tableau_line'"'), "<svg") > 0 local tableau_svg_found = 1
        file read `tableau_fh' tableau_line
    }
    file close `tableau_fh'
    assert `tableau_svg_found' == 1
    sysuse auto, clear
    scatter mpg weight, scheme(plotplain) name(g1, replace)
    scatter mpg weight, scheme(gg_viridis) name(g2, replace)
    graph combine g1 g2
    tempfile combined_svg
    local combined_file "`combined_svg'.svg"
    graph export "`combined_file'", replace
    tempname combined_fh
    file open `combined_fh' using "`combined_file'", read text
    local combined_svg_found = 0
    file read `combined_fh' combined_line
    while r(eof) == 0 {
        if strpos(lower(`"`combined_line'"'), "<svg") > 0 local combined_svg_found = 1
        file read `combined_fh' combined_line
    }
    file close `combined_fh'
    assert `combined_svg_found' == 1
    graph drop g1 g2
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# The help's installation guard is a legal conditional no-op when installed
local ++test_count
capture noisily {
    capture which tc_schemes
    if _rc != 0 net install tc_schemes, from("...")
    which tc_schemes
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_tc_schemes_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
