* test_simtab_oracle.do - independent numeric compute-mode oracle
* Seed: 26082410. Each replication has zero estimates, missing SEs, and small cells.

clear all
set varabbrev off
version 17.0

capture log close _all
log using "test_simtab_oracle.log", replace text name(_simtab_oracle)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall simtab
quietly net install simtab, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_reps ""

set seed 26082410
forvalues rep = 1/200 {
    local ++test_count
    capture noisily {
        clear
        set obs 16
        gen str1 method = cond(mod(_n, 2), "A", "B")
        gen double est = rnormal(0, 0.7)
        gen double se = 0.05 + runiform()
        tempvar se_draw
        gen double `se_draw' = se
        gen double truev = 0
        gen byte cov = abs(est) <= 1.96 * se
        gen byte rej = abs(est / se) > 1.96

        * Every draw contains a literal zero and incomplete replications.
        replace est = 0 in 1
        replace est = 0 in 2
        replace se = . if mod(_n + `rep', 7) == 0
        if mod(`rep', 10) == 0 {
            replace se = . if method == "B"
            replace se = `se_draw' if method == "B" & _n <= 4
        }
        drop `se_draw'

        gen byte usable = !missing(est, se)
        quietly count if est == 0
        assert r(N) == 2
        quietly count if missing(se)
        assert !missing(r(N))
        assert r(N) > 0
        if mod(`rep', 10) == 0 {
            quietly count if method == "B" & usable
            assert r(N) == 2
        }

        forvalues g = 1/2 {
            local label "A"
            if `g' == 2 local label "B"
            quietly summarize est if method == "`label'" & usable, meanonly
            local want_n`g' = r(N)
            local want_mean`g' = r(mean)
            quietly summarize est if method == "`label'" & usable
            local want_empse`g' = r(sd)
            tempvar sesq
            gen double `sesq' = se^2 if method == "`label'" & usable
            quietly summarize `sesq', meanonly
            local want_meanse`g' = sqrt(r(mean))
            drop `sesq'
            tempvar sq
            gen double `sq' = (est - truev)^2 if method == "`label'" & usable
            quietly summarize `sq', meanonly
            local want_mse`g' = r(mean)
            drop `sq'
            quietly summarize cov if method == "`label'" & usable, meanonly
            local want_coverage`g' = r(mean)
            quietly summarize rej if method == "`label'" & usable, meanonly
            local want_power`g' = r(mean)
            local want_bias`g' = `want_mean`g''
            local want_rmse`g' = sqrt(`want_mse`g'')
            local want_nfail`g' = 8 - `want_n`g''
            local want_pctfail`g' = 100 * `want_nfail`g'' / 8
        }

        local n_before = _N
        unab vars_before : _all
        capture frame drop _simtab_oracle_pf
        simtab method, estimate(est) se(se) true(truev) coverage(cov) reject(rej) ///
            nsim(8) minreps(2) ///
            metrics(mean bias empse meanse mse rmse coverage power n nonconv) ///
            plotframe(_simtab_oracle_pf, replace)
        assert _N == `n_before'
        unab vars_after : _all
        assert "`vars_after'" == "`vars_before'"
        assert r(N_input) == 16
        assert !missing(r(n_dropped_se))
        assert r(n_dropped_se) > 0

        forvalues g = 1/2 {
            local label "A"
            if `g' == 2 local label "B"
            foreach metric in mean bias empse meanse mse rmse coverage power n nfail pctfail {
                frame _simtab_oracle_pf: quietly summarize `metric' if estimator_label == "`label'", meanonly
                assert r(N) == 1
                local got_`metric'`g' = r(mean)
                assert !missing(`got_`metric'`g'')
            }
            foreach metric in mean bias empse meanse mse rmse coverage power {
                assert abs(`got_`metric'`g'' - `want_`metric'`g'') < 1e-12
            }
            foreach metric in n nfail pctfail {
                assert `got_`metric'`g'' == `want_`metric'`g''
            }
        }
    }
    local rep_rc = _rc
    capture frame drop _simtab_oracle_pf
    if `rep_rc' == 0 local ++pass_count
    else {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
        display as error "  FAIL: independent simtab numeric oracle replication `rep' (rc=`rep_rc')"
    }
}

display "RESULT: test_simtab_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
log close _simtab_oracle
