*! validation_diagtab_fixture_contract.do -- exact canonical-fixture recovery and hostile contracts
*! Author: Timothy P Copeland, Karolinska Institutet
* guard: expected green at pre-fix ref; fixture adoption, no package fix.
version 16.0
clear all
set more off
capture log close _all
log using "validation_diagtab_fixture_contract.log", text replace
local pkg_dir = substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do "_qa_fx_a1.do"
local tests 0
local pass 0
local fail 0

**# Diagnostic exact counts and AUC friendly
local ++tests
capture noisily {
    qa_fx_a1_diag, clear tier(micro) seed(37)
    tempname truth auc got
    matrix `truth' = r(truth_cutoffs)
    scalar `auc' = r(truth_auc)
    local cuts ""
    forvalues j=1/`=rowsof(`truth')' {
        local cut = `truth'[`j',1]
        local cuts `cuts' `cut'
        quietly diagtab score y, cutoff(`cut') auc
        assert r(TP)==`truth'[`j',4] & r(FP)==`truth'[`j',5]
        assert r(TN)==`truth'[`j',6] & r(FN)==`truth'[`j',7]
        assert abs(r(sensitivity)-`truth'[`j',2])<1e-14
        assert abs(r(specificity)-`truth'[`j',3])<1e-14
        * Native roctab observed .8199999856948854 vs exact .82; float-grid bound.
        assert abs(r(auc)-scalar(`auc'))<1e-7
    }
    quietly diagtab score y, cutoffs(`cuts')
    matrix `got' = r(cutoff_table)
    assert rowsof(`got')==rowsof(`truth')
    forvalues j=1/`=rowsof(`truth')' {
        assert abs(`got'[`j',1]-`truth'[`j',2])<1e-14
        assert abs(`got'[`j',4]-`truth'[`j',3])<1e-14
    }
}
if _rc {
    local ++fail
    display as error "FAIL: Diagnostic exact counts and AUC friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Diagnostic exact counts and AUC friendly"
}

**# Diagnostic exact counts and AUC unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_diag, clear tier(micro) seed(37) perturb(unsorted)
    tempname truth auc got
    matrix `truth' = r(truth_cutoffs)
    scalar `auc' = r(truth_auc)
    local cuts ""
    forvalues j=1/`=rowsof(`truth')' {
        local cut = `truth'[`j',1]
        local cuts `cuts' `cut'
        quietly diagtab score y, cutoff(`cut') auc
        assert r(TP)==`truth'[`j',4] & r(FP)==`truth'[`j',5]
        assert r(TN)==`truth'[`j',6] & r(FN)==`truth'[`j',7]
        assert abs(r(sensitivity)-`truth'[`j',2])<1e-14
        assert abs(r(specificity)-`truth'[`j',3])<1e-14
        * Native roctab observed .8199999856948854 vs exact .82; float-grid bound.
        assert abs(r(auc)-scalar(`auc'))<1e-7
    }
    quietly diagtab score y, cutoffs(`cuts')
    matrix `got' = r(cutoff_table)
    assert rowsof(`got')==rowsof(`truth')
    forvalues j=1/`=rowsof(`truth')' {
        assert abs(`got'[`j',1]-`truth'[`j',2])<1e-14
        assert abs(`got'[`j',4]-`truth'[`j',3])<1e-14
    }
}
if _rc {
    local ++fail
    display as error "FAIL: Diagnostic exact counts and AUC unsorted; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Diagnostic exact counts and AUC unsorted"
}

**# Diagnostic exact counts and AUC miss_subgroup
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_diag, clear tier(micro) seed(37) perturb(miss_subgroup)
    tempname truth auc got
    matrix `truth' = r(truth_cutoffs)
    scalar `auc' = r(truth_auc)
    local cuts ""
    forvalues j=1/`=rowsof(`truth')' {
        local cut = `truth'[`j',1]
        local cuts `cuts' `cut'
        quietly diagtab score y, cutoff(`cut') auc
        assert r(TP)==`truth'[`j',4] & r(FP)==`truth'[`j',5]
        assert r(TN)==`truth'[`j',6] & r(FN)==`truth'[`j',7]
        assert abs(r(sensitivity)-`truth'[`j',2])<1e-14
        assert abs(r(specificity)-`truth'[`j',3])<1e-14
        * Native roctab observed .8199999856948854 vs exact .82; float-grid bound.
        assert abs(r(auc)-scalar(`auc'))<1e-7
    }
    quietly diagtab score y, cutoffs(`cuts')
    matrix `got' = r(cutoff_table)
    assert rowsof(`got')==rowsof(`truth')
    forvalues j=1/`=rowsof(`truth')' {
        assert abs(`got'[`j',1]-`truth'[`j',2])<1e-14
        assert abs(`got'[`j',4]-`truth'[`j',3])<1e-14
    }
}
if _rc {
    local ++fail
    display as error "FAIL: Diagnostic exact counts and AUC miss_subgroup; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Diagnostic exact counts and AUC miss_subgroup"
}

**# Diagnostic exact counts and AUC single_level
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_diag, clear tier(micro) seed(37) perturb(single_level)
    tempname truth auc got
    matrix `truth' = r(truth_cutoffs)
    scalar `auc' = r(truth_auc)
    local cuts ""
    forvalues j=1/`=rowsof(`truth')' {
        local cut = `truth'[`j',1]
        local cuts `cuts' `cut'
        quietly diagtab score y, cutoff(`cut') auc
        assert r(TP)==`truth'[`j',4] & r(FP)==`truth'[`j',5]
        assert r(TN)==`truth'[`j',6] & r(FN)==`truth'[`j',7]
        assert abs(r(sensitivity)-`truth'[`j',2])<1e-14
        assert abs(r(specificity)-`truth'[`j',3])<1e-14
        * Native roctab observed .8199999856948854 vs exact .82; float-grid bound.
        assert abs(r(auc)-scalar(`auc'))<1e-7
    }
    quietly diagtab score y, cutoffs(`cuts')
    matrix `got' = r(cutoff_table)
    assert rowsof(`got')==rowsof(`truth')
    forvalues j=1/`=rowsof(`truth')' {
        assert abs(`got'[`j',1]-`truth'[`j',2])<1e-14
        assert abs(`got'[`j',4]-`truth'[`j',3])<1e-14
    }
}
if _rc {
    local ++fail
    display as error "FAIL: Diagnostic exact counts and AUC single_level; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Diagnostic exact counts and AUC single_level"
}

**# Diagnostic exact counts and AUC codes_multidigit
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_diag, clear tier(micro) seed(37) perturb(codes_multidigit)
    tempname truth auc got
    matrix `truth' = r(truth_cutoffs)
    scalar `auc' = r(truth_auc)
    local cuts ""
    forvalues j=1/`=rowsof(`truth')' {
        local cut = `truth'[`j',1]
        local cuts `cuts' `cut'
        quietly diagtab score y, cutoff(`cut') auc
        assert r(TP)==`truth'[`j',4] & r(FP)==`truth'[`j',5]
        assert r(TN)==`truth'[`j',6] & r(FN)==`truth'[`j',7]
        assert abs(r(sensitivity)-`truth'[`j',2])<1e-14
        assert abs(r(specificity)-`truth'[`j',3])<1e-14
        * Native roctab observed .8199999856948854 vs exact .82; float-grid bound.
        assert abs(r(auc)-scalar(`auc'))<1e-7
    }
    quietly diagtab score y, cutoffs(`cuts')
    matrix `got' = r(cutoff_table)
    assert rowsof(`got')==rowsof(`truth')
    forvalues j=1/`=rowsof(`truth')' {
        assert abs(`got'[`j',1]-`truth'[`j',2])<1e-14
        assert abs(`got'[`j',4]-`truth'[`j',3])<1e-14
    }
}
if _rc {
    local ++fail
    display as error "FAIL: Diagnostic exact counts and AUC codes_multidigit; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Diagnostic exact counts and AUC codes_multidigit"
}

**# Diagnostic exact counts and AUC codes_sparse
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_diag, clear tier(micro) seed(37) perturb(codes_sparse)
    tempname truth auc got
    matrix `truth' = r(truth_cutoffs)
    scalar `auc' = r(truth_auc)
    local cuts ""
    forvalues j=1/`=rowsof(`truth')' {
        local cut = `truth'[`j',1]
        local cuts `cuts' `cut'
        quietly diagtab score y, cutoff(`cut') auc
        assert r(TP)==`truth'[`j',4] & r(FP)==`truth'[`j',5]
        assert r(TN)==`truth'[`j',6] & r(FN)==`truth'[`j',7]
        assert abs(r(sensitivity)-`truth'[`j',2])<1e-14
        assert abs(r(specificity)-`truth'[`j',3])<1e-14
        * Native roctab observed .8199999856948854 vs exact .82; float-grid bound.
        assert abs(r(auc)-scalar(`auc'))<1e-7
    }
    quietly diagtab score y, cutoffs(`cuts')
    matrix `got' = r(cutoff_table)
    assert rowsof(`got')==rowsof(`truth')
    forvalues j=1/`=rowsof(`truth')' {
        assert abs(`got'[`j',1]-`truth'[`j',2])<1e-14
        assert abs(`got'[`j',4]-`truth'[`j',3])<1e-14
    }
}
if _rc {
    local ++fail
    display as error "FAIL: Diagnostic exact counts and AUC codes_sparse; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Diagnostic exact counts and AUC codes_sparse"
}

do "_qa_state.do"

**# Absent positive class refusal preserves caller
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a1_diag, clear tier(micro) seed(37) perturb(noevent)
    qa_state_snapshot, tag(diag_refused)
    capture noisily diagtab score y, cutoff(3) auc
    local refusal=_rc
    assert `refusal'==198
    qa_state_compare, tag(diag_refused)

}
if _rc {
    local ++fail
    display as error "FAIL: Absent positive class refusal preserves caller; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Absent positive class refusal preserves caller"
}

display "RESULT: validation_diagtab_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
