clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

* Public source is reload-safe in an active development session.
run "`pkg_dir'/gcomptab.ado"
run "`pkg_dir'/gcomptab.ado"

set seed 9501
set obs 900
gen double c=rnormal()
gen byte x=rbinomial(1,invlogit(.2*c))
gen byte m=rbinomial(1,invlogit(-.5+.7*x+.2*c))
gen byte y=rbinomial(1,invlogit(-1+.5*x+.7*m+.2*c))
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) sim(400) samples(3) seed(161) savemodels
local models "`e(model_names)'"
local book "/tmp/gcomptab style matrix.xlsx"
capture erase "`book'"

foreach style in academic thin medium none {
    gcomptab, models usemodels(`models') xlsx("`book'") ///
        sheet("`style'") borderstyle(`style') title("Style `style'")
    assert r(N_models)==2
    assert "`r(sheet)'"=="`style'"
}

* Legal Excel sheet punctuation is validated as a sheet name, not a path.
gcomptab, models usemodels(`models') xlsx("`book'") ///
    sheet("Odd & #1") borderstyle(thin)
assert "`r(sheet)'"=="Odd & #1"

* Central validation applies identically before mode dispatch.
capture noisily gcomptab, models usemodels(`models') display decimal(0)
assert _rc==198
capture noisily gcomptab, models usemodels(`models') display fontsize(73)
assert _rc==198
capture noisily gcomptab, models usemodels(`models') display borderstyle(thick)
assert _rc==198
capture noisily gcomptab, models usemodels(`models') display boldp(1)
assert _rc==198
capture noisily gcomptab, models usemodels(`models') display highlight(-.1)
assert _rc==198
capture noisily gcomptab, models usemodels(`models') xlsx("/tmp/not_excel.txt")
assert _rc==198
capture noisily gcomptab, models usemodels(`models') markdown("/tmp/not_markdown.txt")
assert _rc==198
capture noisily gcomptab, models usemodels(`models') csv("/tmp/not_csv.txt")
assert _rc==198

* The write and analytical r() payload survive a best-effort opener failure.
capture program drop _gcomp_xl_open
program define _gcomp_xl_open
    version 16.0
    exit 42
end
gcomptab, models usemodels(`models') xlsx("`book'") ///
    sheet("Open failure") open
assert r(open_rc)==42
assert r(N_models)==2
assert "`r(xlsx)'"=="`book'"
confirm file "`book'"

display "RESULT: GCTAB-H02/H06 option/style/open status=PASS"
display "RESULT: gcomptab_option_style_probe status=PASS"

capture erase "`book'"

display "RESULT: test_gcomptab_option_style tests=1 pass=1 fail=0 status=PASS"

