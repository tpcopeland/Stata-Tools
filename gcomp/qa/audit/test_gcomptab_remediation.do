clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

* Public source can be reloaded repeatedly.
run "`pkg_dir'/gcomptab.ado"
run "`pkg_dir'/gcomptab.ado"

set seed 8102
set obs 1800
gen double c=rnormal()
gen byte x=rbinomial(1,invlogit(.2*c))
gen double m=.8*x+.3*c+rnormal()
gen double y=1.2*x+.5*m+.2*c+rnormal()
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: regress, y: regress) equations(m: x c, y: x m c) ///
    base_confs(c) msm(regress y x m) sim(900) samples(3) seed(441) savemodels
assert `"`e(model_capture)'"'=="analytic_sample_refit_approximation"
assert e(N_models)==2
assert `"`e(model_names)'"'!=""

local outdir "/tmp/gcomp table output"
capture mkdir "`outdir'"
local xlsx "`outdir'/models table.xlsx"
local md "`outdir'/models table.md"
local csv "`outdir'/models table.csv"
capture erase "`xlsx'"
capture erase "`md'"
capture erase "`csv'"
local ttl `"A deliberately long title | with "quotes", commas, Unicode Å, and enough trailing text to exceed one hundred characters without truncation in any export surface"'
local mlabs `"Mediator | "joint" model \ Outcome, model"'
mata: b=42
gcomptab, models xlsx("`xlsx'") sheet("Models & QA") markdown("`md'") csv("`csv'") ///
    modellabels(`"`mlabs'"') title(`"`ttl'"') footnote(`"Footnote | "quoted" Å"') ///
    borderstyle(academic) decimal(4) fontsize(10)
mata: assert(b==42)
assert r(N_models)==2
assert r(N_rows)>0
assert `"`r(xlsx)'"'==`"`xlsx'"'
preserve
import excel using "`xlsx'", sheet("Models & QA") cellrange(A1:A1) clear allstring
assert A[1] == `"`ttl'"'
restore

* Distinct legal coefficient identities that used to sanitize to one key.
clear
set obs 500
gen double a=rnormal()
gen double bvar=rnormal()
gen double c_a_c_b=rnormal()
gen double yy=1.1*c_a_c_b+2.2*a*bvar+rnormal()
regress yy c_a_c_b c.a#c.bvar
estimates store collision_model
gcomptab, models usemodels(collision_model) display nointercept decimal(3)
assert r(N_rows)==2
assert strpos(`"`r(term_names)'"',"c_a_c_b")
assert strpos(`"`r(term_names)'"',"c.a#c.bvar")
display "RESULT: gcomptab_remediation_probe status=PASS"

capture erase "`xlsx'"
capture erase "`md'"
capture erase "`csv'"

display "RESULT: test_gcomptab_remediation tests=1 pass=1 fail=0 status=PASS"
