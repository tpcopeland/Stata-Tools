*! crossval_comorbidity_r.do
*! Cross-validation against R comorbidity 1.1.0
*! Seed 26082451

clear all
set varabbrev off
version 16.0

capture log close _all
log using "crossval_comorbidity_r.log", replace nomsg

local qa_dir "`c(pwd)'"
local r_script "`qa_dir'/tools/crossval_comorbidity_r.R"

do "`qa_dir'/_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Build a seeded wide ICD-10 fixture and exchange it as double/string .dta.
tempfile exchange r_reference
local exchange "`exchange'.dta"
local r_reference "`r_reference'.dta"
clear
input long pid str8 dx1 str8 dx2 str8 dx3
    1 "E100" "E102" "I500"
    2 "C780" "C500" "Z000"
    3 "K721" "K700" "B200"
    4 "N180" "I500" "R640"
    5 "F315" "F412" "E529"
    6 "I100" "I130" "E116"
    7 "C900" "C970" "M460"
    8 "G810" "I480" "E110"
    9 "K257" "J440" "I109"
    10 "Z000" "" ""
    11 "I260" "I120" "D500"
    12 "E890" "F000" "G350"
end
* Seed before the permutation so row order cannot be an implicit mapping key.
set seed 26082451
gen double order_u = runiform()
sort order_u
drop order_u
gen long source_pid = pid
replace pid = _n
save "`exchange'", replace
shell Rscript "`r_script'" "`exchange'" "`r_reference'"

* Charlson indicators and original Charlson weights.
local ++test_count
capture noisily {
    use "`exchange'", clear
    comorbidity dx1 dx2 dx3, id(pid) charlson(original) collapse generate(ch_)
    local stata_N = r(N)
    merge 1:1 pid using "`r_reference'"
    assert _merge == 3
    drop _merge
    foreach name in mi chf pvd cvd dementia copd rheumatic peptic liver_mild ///
        dm_uncomp dm_comp hemiplegia renal cancer liver_severe metastatic hiv {
        assert ch_`name' < .
        assert r_ch_`name' < .
        assert ch_`name' == r_ch_`name'
    }
    assert ch_score < .
    assert r_charlson_original < .
    assert abs(ch_score - r_charlson_original) < 1e-12
    assert `stata_N' == _N
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
}

* Same Quan ICD-10 indicators, updated Quan 2011 weights.
local ++test_count
capture noisily {
    use "`exchange'", clear
    comorbidity dx1 dx2 dx3, id(pid) charlson(quan2011) collapse generate(cq_)
    local stata_N = r(N)
    merge 1:1 pid using "`r_reference'"
    assert _merge == 3
    drop _merge
    foreach name in mi chf pvd cvd dementia copd rheumatic peptic liver_mild ///
        dm_uncomp dm_comp hemiplegia renal cancer liver_severe metastatic hiv {
        assert cq_`name' < .
        assert r_ch_`name' < .
        assert cq_`name' == r_ch_`name'
    }
    assert cq_score < .
    assert r_charlson_quan < .
    assert abs(cq_score - r_charlson_quan) < 1e-12
    assert `stata_N' == _N
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
}

* Elixhauser Quan ICD-10 indicators and van Walraven weights.
local ++test_count
capture noisily {
    use "`exchange'", clear
    comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) collapse generate(el_)
    local stata_N = r(N)
    merge 1:1 pid using "`r_reference'"
    assert _merge == 3
    drop _merge
    foreach name in chf arrhythmia valvular pulmonary_circ pvd htn_uncomp ///
        htn_comp paralysis neuro_other copd dm_uncomp dm_comp hypothyroid renal ///
        liver pud hiv lymphoma metastatic solid_tumor rheumatoid coagulopathy obesity ///
        weight_loss fluid_electrolyte blood_loss_anemia deficiency_anemia alcohol drug ///
        psychoses depression {
        assert el_`name' < .
        assert r_el_`name' < .
        assert el_`name' == r_el_`name'
    }
    assert el_score < .
    assert r_elixhauser_vw < .
    assert abs(el_score - r_elixhauser_vw) < 1e-12
    assert `stata_N' == _N
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
}

_comorbidity_result crossval_comorbidity_r `test_count' `pass_count' `fail_count'
log close _all
