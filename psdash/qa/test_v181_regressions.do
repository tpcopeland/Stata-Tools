* test_v181_regressions.do -- support graph x-axis covers the full 0-1 scale
* Author: Timothy P Copeland, Karolinska Institutet
*
* Fail-on-old (psdash 1.8.0): psdash support drew xscale(range(0 1)) with no
* xlabel(), so the axis line and ticks began at the data minimum and the
* Crump/common-support lines sat left of the first tick. The saved .gph of the
* old graph has no .xaxis1.major tick directive at all; the fixed graph has
* .xaxis1.major.range_ticks 0 1 .2 (also on the combined dashboard's support
* panel, which calls psdash support). The assertions read the saved graph.
version 16.0
capture log close _all
log using test_v181_regressions.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local failed ""

tempfile gph
capture mata: mata drop _v181_ticks()
mata:
// Last .xaxis1.major directive in a saved graph that sets ticks, as
// (kind, first, last): kind 1 = range_ticks, 2 = add_ticks. Missing when the
// graph never sets major ticks (auto labels: axis covers the data only).
real rowvector _v181_ticks(string scalar f)
{
    string colvector L
    string rowvector w
    real scalar i, k, n
    real rowvector out
    L = cat(f)
    out = (., ., .)
    k = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 26) == ".xaxis1.major.range_ticks ") {
            w = tokens(substr(L[i], 27, .))
            out = (1, strtoreal(w[1]), strtoreal(w[2]))
        }
        else if (substr(L[i], 1, 24) == ".xaxis1.major.add_ticks ") {
            w = tokens(subinstr(substr(L[i], 25, .), ",", " "))
            n = cols(w)
            if (n > 0) {
                out = (2, min(strtoreal(w)), max(strtoreal(w)))
            }
        }
    }
    return(out)
}
end

clear
set seed 20261029
set obs 800
gen double x = rnormal()
gen byte t = runiform() < invlogit(x)
gen double ps = 0.2 + 0.8 * invlogit(0.8 * x)
label variable t "Treated"

* support graph: axis labels reach from 0 (<= Crump lower bound) to 1
capture noisily {
    graph drop _all
    psdash support t ps, crump name(v181_s)
    local trim_lo = r(trim_lower)
    assert !missing(`trim_lo') & `trim_lo' > 0
    graph save v181_s "`gph'", replace
    mata: st_matrix("tk", _v181_ticks("`gph'"))
    assert !missing(tk[1,1])
    assert tk[1,2] <= 0 & tk[1,2] <= `trim_lo'
    assert tk[1,3] >= 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' support_axis_full_scale"
}
else local ++pass

* without crump the common-support bounds must also sit inside the labelled axis
capture noisily {
    graph drop _all
    psdash support t ps, name(v181_s2)
    local lo = r(lower_bound)
    graph save v181_s2 "`gph'", replace
    mata: st_matrix("tk", _v181_ticks("`gph'"))
    assert !missing(tk[1,1])
    assert tk[1,2] <= `lo' & tk[1,3] >= 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' support_axis_no_crump"
}
else local ++pass

* a user xlabel() in graphoptions() still wins
capture noisily {
    graph drop _all
    psdash support t ps, crump name(v181_s3) graphoptions(xlabel(0 .5 1))
    graph save v181_s3 "`gph'", replace
    mata: st_matrix("tk", _v181_ticks("`gph'"))
    assert tk[1,1] == 2
    assert tk[1,2] == 0 & tk[1,3] == 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' user_xlabel_overrides"
}
else local ++pass

* the combined dashboard's support panel inherits the fix (since the binary
* dashboard shows a Diagnostic Summary instead, request the panel explicitly)
capture noisily {
    graph drop _all
    quietly psdash combined t ps, supportgraph
    graph save psdash_c_support "`gph'", replace
    mata: st_matrix("tk", _v181_ticks("`gph'"))
    assert !missing(tk[1,1])
    assert tk[1,2] <= 0 & tk[1,3] >= 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' combined_support_panel"
}
else local ++pass

capture erase "`gph'"
graph drop _all
display "RESULT: test_v181_regressions tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' display as error "Failed:`failed'"
_psdash_qa_cleanup
log close
if `fail' exit 1
