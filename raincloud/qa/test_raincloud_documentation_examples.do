*! Exact executable examples from raincloud.sthlp
*! Date: 2026-08-23

clear all
set varabbrev off
version 16.0
do "_raincloud_qa_common.do"
_raincloud_qa_bootstrap "`c(pwd)'/.."

local test_count = 0
local pass_count = 0
local fail_count = 0

* All nine help calls share the printed sysuse auto setup.
foreach example in basic groups vertical elements density seed mirror colors styling {
    local ++test_count
    capture noisily {
        sysuse auto, clear
        if "`example'" == "basic" raincloud mpg
        if "`example'" == "groups" raincloud mpg, over(foreign)
        if "`example'" == "vertical" raincloud price, over(foreign) vertical
        if "`example'" == "elements" raincloud mpg, over(foreign) opacity(70) jitter(0.6) mean
        if "`example'" == "density" raincloud mpg, over(foreign) norain nobox
        if "`example'" == "seed" raincloud mpg, over(foreign) seed(12345)
        if "`example'" == "mirror" raincloud mpg, over(foreign) mirror mean
        if "`example'" == "colors" raincloud mpg, over(foreign) colors(red blue)
        if "`example'" == "styling" raincloud mpg, over(foreign) cloudopts(lwidth(medium)) pointopts(msymbol(d) msize(tiny)) boxopts(lwidth(thick))
        assert r(N) == _N
        assert r(n_groups) == cond(inlist("`example'", "basic"), 1, 2)
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
    capture graph drop _all
}

display "RESULT: test_raincloud_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
