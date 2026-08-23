* test_tabtools_oracle.do - independent numeric oracle for corrtab's Pearson surface
* Seed: 26082411. Repeated fixtures include zeros, extended missings, and N=2 pairs.

clear all
set varabbrev off
version 17.0

capture log close _all
log using "test_tabtools_oracle.log", replace text name(_tabtools_oracle)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_reps ""

set seed 26082411
forvalues rep = 1/200 {
    local ++test_count
    capture noisily {
        clear
        set obs 12
        gen double x = rnormal()
        gen double y = 0.45 * x + rnormal()
        gen double z = -0.30 * x + rnormal()
        replace x = 0 in 1
        if mod(`rep', 10) == 0 replace z = . in 3/12
        else {
            if mod(`rep', 3) == 0 replace z = .a in 1
            if mod(`rep', 4) == 0 replace y = . in 2
        }
        if mod(`rep', 6) == 0 replace x = .b in 12

        local n_before = _N
        unab vars_before : _all
        capture frame drop _tabtools_oracle_pf
        corrtab x y z, full frame(_tabtools_oracle_pf, replace) digits(6)
        matrix C = r(C)
        matrix P = r(P)
        matrix N = r(N)
        assert _N == `n_before'
        unab vars_after : _all
        assert "`vars_after'" == "`vars_before'"

        local vars x y z
        local got_cols : colnames C
        local got_rows : rownames C
        forvalues i = 1/3 {
            local vi : word `i' of `vars'
            local ci : word `i' of `got_cols'
            local ri : word `i' of `got_rows'
            assert "`ci'" == "`vi'"
            assert "`ri'" == "`vi'"
        }

        local want_total = 0
        local got_total = 0
        forvalues i = 1/3 {
            local vi : word `i' of `vars'
            forvalues j = 1/3 {
                local vj : word `j' of `vars'
                quietly count if !missing(`vi', `vj')
                local want_n = r(N)
                local got_n = N[`i', `j']
                assert `got_n' == `want_n'
                local want_total = `want_total' + `want_n'
                local got_total = `got_total' + `got_n'

                local got_c = C[`i', `j']
                local got_p = P[`i', `j']
                if `i' == `j' {
                    assert `want_n' > 0
                    assert !missing(`got_c')
                    assert abs(`got_c' - 1) < 1e-12
                    assert missing(`got_p')
                }
                else {
                    quietly summarize `vi' if !missing(`vi', `vj'), meanonly
                    local mean_i = r(mean)
                    quietly summarize `vi' if !missing(`vi', `vj')
                    local sd_i = r(sd)
                    quietly summarize `vj' if !missing(`vi', `vj'), meanonly
                    local mean_j = r(mean)
                    quietly summarize `vj' if !missing(`vi', `vj')
                    local sd_j = r(sd)
                    tempvar prod
                    gen double `prod' = (`vi' - `mean_i') * (`vj' - `mean_j') if !missing(`vi', `vj')
                    quietly summarize `prod', meanonly
                    local want_c = (r(sum) / (`want_n' - 1)) / (`sd_i' * `sd_j')
                    drop `prod'
                    assert !missing(`got_c', `want_c')
                    assert abs(`got_c' - `want_c') < 1e-12
                    if `want_n' <= 2 {
                        assert missing(`got_p')
                    }
                    else {
                        if abs(`want_c') < 1 local want_p = 2 * ttail(`want_n' - 2, abs(`want_c' * sqrt((`want_n' - 2) / (1 - (`want_c')^2))))
                        else local want_p = 0
                        assert !missing(`got_p', `want_p')
                        assert abs(`got_p' - `want_p') < 1e-12
                    }
                }
            }
        }
        assert `got_total' == `want_total'
        if mod(`rep', 10) == 0 {
            assert N[1, 3] == 2
            assert missing(P[1, 3])
        }
    }
    local rep_rc = _rc
    capture frame drop _tabtools_oracle_pf
    if `rep_rc' == 0 local ++pass_count
    else {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
        display as error "  FAIL: independent corrtab numeric oracle replication `rep' (rc=`rep_rc')"
    }
}

display "RESULT: test_tabtools_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
log close _tabtools_oracle
