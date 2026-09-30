*! validation_qba_fixture_plots.do -- actual plotted numerical series from canonical bias cells
*! Author: Timothy P Copeland, Karolinska Institutet
* Matrix inversion independently inverts forward outcome misclassification cells.
* Native serset interface: installed Stata17 [P] serset documentation.
version 16.0
clear all
set more off
capture log close _all
log using "validation_qba_fixture_plots.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_state.do
* Native first graph initializes T_gm_fix_span; proven by the native-only
* control receipt. Initialize it with native twoway before package fingerprints.
set obs 3
generate double native_x=_n
quietly twoway line native_x native_x
graph drop _all
clear
local tests 0
local pass 0
local fail 0

**# Tornado plotted cells outcome friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    tempname target M N1 N0
    matrix `target'=J(3,2,.)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local sp=sp[1]
    forvalues j=1/3 {
        local se=.7+.1*`j'
        matrix `M'=(`se',1-`sp' \ 1-`se',`sp')
        matrix `N1'=inv(`M')*(`a' \ `c')
        matrix `N0'=inv(`M')*(`b' \ `d')
        matrix `target'[`j',1]=(`N1'[1,1]*`N0'[2,1])/(`N0'[1,1]*`N1'[2,1])
        matrix `target'[`j',2]=`se'
    }
    qa_state_snapshot, tag(qba_plot_data)
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(se) range1(.8 1) base_sp(`sp') steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_plot_data)
    * Read the actual graph's retained numeric series; file existence/labels
    * alone would not reveal a wrong corrected curve.
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    forvalues j=1/3 {
        assert !missing(corrected[`j'],param_value[`j'])
        assert abs(corrected[`j']-`target'[`j',1])<1e-12
        assert abs(param_value[`j']-`target'[`j',2])<1e-12
    }
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: outcome friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: outcome friendly"
}

**# Tornado plotted cells selection friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    tempname target M N1 N0
    matrix `target'=J(3,2,.)
    local a=selection_n[1]
    local b=selection_n[3]
    local c=selection_n[2]
    local d=selection_n[4]
    * Observed OR4/3; dividing the exposed-case inclusion probability
    * restores40 at .5 and gives the exact entire three-point curve.
    forvalues j=1/3 {
        local sela=.25+.25*`j'
        matrix `target'[`j',1]=(`a'/`sela')*`d'/(`b'*`c')
        matrix `target'[`j',2]=`sela'
    }
    qa_state_snapshot, tag(qba_plot_data)
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') param1(sela) range1(.5 1) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_plot_data)
    * Read the actual graph's retained numeric series; file existence/labels
    * alone would not reveal a wrong corrected curve.
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    forvalues j=1/3 {
        assert !missing(corrected[`j'],param_value[`j'])
        assert abs(corrected[`j']-`target'[`j',1])<1e-12
        assert abs(param_value[`j']-`target'[`j',2])<1e-12
    }
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: selection friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: selection friendly"
}

**# Tornado plotted cells confounding friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    tempname target M N1 N0
    matrix `target'=J(3,2,.)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    local rr=rr_uy[1]
    local p0=p_u0[1]
    forvalues j=1/3 {
        local p1=.25*(`j'-1)
        matrix `target'[`j',1]=2*(1+`p0'*(`rr'-1))/(1+`p1'*(`rr'-1))
        matrix `target'[`j',2]=`p1'
    }
    qa_state_snapshot, tag(qba_plot_data)
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(`p0') base_rrcd(`rr') steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_plot_data)
    * Read the actual graph's retained numeric series; file existence/labels
    * alone would not reveal a wrong corrected curve.
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    forvalues j=1/3 {
        assert !missing(corrected[`j'],param_value[`j'])
        assert abs(corrected[`j']-`target'[`j',1])<1e-12
        assert abs(param_value[`j']-`target'[`j',2])<1e-12
    }
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: confounding friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: confounding friendly"
}

**# Tornado plotted cells outcome boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname target M N1 N0
    matrix `target'=J(3,2,.)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local sp=sp[1]
    forvalues j=1/3 {
        local se=.7+.1*`j'
        matrix `M'=(`se',1-`sp' \ 1-`se',`sp')
        matrix `N1'=inv(`M')*(`a' \ `c')
        matrix `N0'=inv(`M')*(`b' \ `d')
        matrix `target'[`j',1]=(`N1'[1,1]*`N0'[2,1])/(`N0'[1,1]*`N1'[2,1])
        matrix `target'[`j',2]=`se'
    }
    qa_state_snapshot, tag(qba_plot_data)
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(se) range1(.8 1) base_sp(`sp') steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_plot_data)
    * Read the actual graph's retained numeric series; file existence/labels
    * alone would not reveal a wrong corrected curve.
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    forvalues j=1/3 {
        assert !missing(corrected[`j'],param_value[`j'])
        assert abs(corrected[`j']-`target'[`j',1])<1e-12
        assert abs(param_value[`j']-`target'[`j',2])<1e-12
    }
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: outcome boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: outcome boundary_values"
}

**# Tornado plotted cells selection boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname target M N1 N0
    matrix `target'=J(3,2,.)
    local a=selection_n[1]
    local b=selection_n[3]
    local c=selection_n[2]
    local d=selection_n[4]
    * Observed OR4/3; dividing the exposed-case inclusion probability
    * restores40 at .5 and gives the exact entire three-point curve.
    forvalues j=1/3 {
        local sela=.25+.25*`j'
        matrix `target'[`j',1]=(`a'/`sela')*`d'/(`b'*`c')
        matrix `target'[`j',2]=`sela'
    }
    qa_state_snapshot, tag(qba_plot_data)
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') param1(sela) range1(.5 1) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_plot_data)
    * Read the actual graph's retained numeric series; file existence/labels
    * alone would not reveal a wrong corrected curve.
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    forvalues j=1/3 {
        assert !missing(corrected[`j'],param_value[`j'])
        assert abs(corrected[`j']-`target'[`j',1])<1e-12
        assert abs(param_value[`j']-`target'[`j',2])<1e-12
    }
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: selection boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: selection boundary_values"
}

**# Tornado plotted cells confounding boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname target M N1 N0
    matrix `target'=J(3,2,.)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    local rr=rr_uy[1]
    local p0=p_u0[1]
    forvalues j=1/3 {
        local p1=.25*(`j'-1)
        matrix `target'[`j',1]=2*(1+`p0'*(`rr'-1))/(1+`p1'*(`rr'-1))
        matrix `target'[`j',2]=`p1'
    }
    qa_state_snapshot, tag(qba_plot_data)
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(`p0') base_rrcd(`rr') steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_plot_data)
    * Read the actual graph's retained numeric series; file existence/labels
    * alone would not reveal a wrong corrected curve.
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    forvalues j=1/3 {
        assert !missing(corrected[`j'],param_value[`j'])
        assert abs(corrected[`j']-`target'[`j',1])<1e-12
        assert abs(param_value[`j']-`target'[`j',2])<1e-12
    }
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: confounding boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: confounding boundary_values"
}

display "RESULT: validation_qba_fixture_plots tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
