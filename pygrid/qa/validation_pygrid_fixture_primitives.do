*! validation_pygrid_fixture_primitives.do -- exact hostile key attachment and partial intervals
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_pygrid_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Retained metadata label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date group x)
    assert r(N_persons)==40 & r(N_rows)==40 & r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(id) date(date) count(event_count)
    assert r(N_using)==40 & r(N_attached)==40 & r(N_orphan)==0
    assert r(events)==40 & event_count==1
    assert inlist(group,1,2,5,9)

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Retained metadata label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Retained metadata label_gaps"
}

**# Retained metadata miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date group x)
    assert r(N_persons)==40 & r(N_rows)==40 & r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(id) date(date) count(event_count)
    assert r(N_using)==40 & r(N_attached)==40 & r(N_orphan)==0
    assert r(events)==40 & event_count==1
    assert missing(x)

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Retained metadata miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Retained metadata miss_all_column"
}

**# Negative and above-maxlong exact key twins
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    generate double date=td(01jan2020)+y
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(code) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date )
    assert r(N_persons)==5 & r(N_rows)==15 & r(pytotal)==15
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(code) date(date) count(event_count)
    assert r(N_using)==15 & r(N_attached)==15 & r(N_orphan)==0
    assert r(events)==15 & event_count==1
    assert inlist(code,-7,2,20,3000000000,3000000001)
    quietly count if code==3000000000
    assert r(N)==3
    quietly count if code==3000000001
    assert r(N)==3

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Negative and above-maxlong exact key twins; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Negative and above-maxlong exact key twins"
}

**# Exact32-character id/date twins
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    local twins `r(long)'
    local key: word 1 of `twins'
    local day: word 2 of `twins'
    replace `day'=td(01jan2020)+`key'
    tempfile events
    quietly save `events'
    generate double stop=`day'
    quietly pygrid, id(`key') start(`day') end(stop) axis(fixed) origin(`day') unit(day) width(1) pyunit(day) keep(`day' )
    assert r(N_persons)==20 & r(N_rows)==20 & r(pytotal)==20
    assert person_years==1 & period_start==`day' & period_stop==`day'
    quietly pyattach using `events', id(`key') date(`day') count(event_count)
    assert r(N_using)==20 & r(N_attached)==20 & r(N_orphan)==0
    assert r(events)==20 & event_count==1

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Exact32-character id/date twins; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact32-character id/date twins"
}

**# Opaque fixed-width string identities
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate str244 opaque_id=""
    local j=0
    foreach g of local corpus {
        local ++j
        mata: st_sstore(strtoreal(st_local("j")),"opaque_id",st_global(st_local("g")))
    }
    forvalues j=10/40 {
        replace opaque_id="ordinary unique `j'" in `j'
    }
    tempfile events
    quietly save `events'
    generate double stop=date
    quietly pygrid, id(opaque_id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(1) pyunit(day) keep(date )
    assert r(N_persons)==40 & r(N_rows)==40 & r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    quietly pyattach using `events', id(opaque_id) date(date) count(event_count)
    assert r(N_using)==40 & r(N_attached)==40 & r(N_orphan)==0
    assert r(events)==40 & event_count==1
    foreach g of local corpus {
        mata: assert(sum(st_sdata(.,"opaque_id"):==st_global(st_local("g")))==1)
    }

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque fixed-width string identities; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque fixed-width string identities"
}

**# Exact1-day partial within2-day nominal keep
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(anniversary) origin(date) unit(day) width(2) pyunit(day) keep(date) partial(keep)
    assert r(N_partial)==40 & r(N_rows)==40 & r(N_persons)==40
    assert r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Exact1-day partial within2-day nominal keep; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact1-day partial within2-day nominal keep"
}

**# Exact1-day partial within2-day nominal flag
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    generate double stop=date
    quietly pygrid, id(id) start(date) end(stop) axis(anniversary) origin(date) unit(day) width(2) pyunit(day) keep(date) partial(flag)
    assert r(N_partial)==40 & r(N_rows)==40 & r(N_persons)==40
    assert r(pytotal)==40
    assert person_years==1 & period_start==date & period_stop==date
    assert _partial==1

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Exact1-day partial within2-day nominal flag; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact1-day partial within2-day nominal flag"
}

**# Exact1-day partial within2-day nominal drop
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    generate double stop=date
    * expect: REFUSED
    qa_state_snapshot, tag(py_partial)
    capture noisily pygrid, id(id) start(date) end(stop) axis(anniversary) origin(date) unit(day) width(2) pyunit(day) keep(date) partial(drop)
    assert _rc==2000
    qa_state_compare, tag(py_partial)

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: Exact1-day partial within2-day nominal drop; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact1-day partial within2-day nominal drop"
}

display "RESULT: validation_pygrid_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
