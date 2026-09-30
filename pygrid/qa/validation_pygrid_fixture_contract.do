*! validation_pygrid_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_pygrid_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# One inclusive day and one attached event friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date)
    assert r(N_persons)==40 & r(N_rows)==40 & r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(id) date(date) count(event_count)
    assert r(N_using)==40 & r(N_attached)==40 & r(N_orphan)==0
    assert r(events)==40 & event_count==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: One inclusive day and one attached event friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: One inclusive day and one attached event friendly"
}

**# One inclusive day and one attached event single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date)
    assert r(N_persons)==1 & r(N_rows)==1 & r(pytotal)==1
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(id) date(date) count(event_count)
    assert r(N_using)==1 & r(N_attached)==1 & r(N_orphan)==0
    assert r(events)==1 & event_count==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: One inclusive day and one attached event single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: One inclusive day and one attached event single_row"
}

**# One inclusive day and one attached event boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date)
    assert r(N_persons)==40 & r(N_rows)==40 & r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(id) date(date) count(event_count)
    assert r(N_using)==40 & r(N_attached)==40 & r(N_orphan)==0
    assert r(events)==40 & event_count==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: One inclusive day and one attached event boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: One inclusive day and one attached event boundary_values"
}

**# One inclusive day and one attached event unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date)
    assert r(N_persons)==40 & r(N_rows)==40 & r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(id) date(date) count(event_count)
    assert r(N_using)==40 & r(N_attached)==40 & r(N_orphan)==0
    assert r(events)==40 & event_count==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: One inclusive day and one attached event unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: One inclusive day and one attached event unsorted"
}

display "RESULT: validation_pygrid_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
