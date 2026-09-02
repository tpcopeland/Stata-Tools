* crossval_public_studies.do - Public-study parity against crrSC::crrs
* Package: finegray
*
* Public examples from Zhou et al. (2011), Biometrics 67:661-670:
*   bce     ECOG breast-cancer data, regularly stratified by treatment arm
*   center  random 400-patient multicentre transplant subsample, highly
*           stratified by centre
*
* crrSC::crrs is the paper authors' reference implementation. The R companion
* regenerates both datasets and every oracle number on each run. No coefficient
* is hardcoded or copied from this package.
*
* Mapping:
*   ctype=1  -> bstrata(stratum) strata(stratum) nuisance noadjust
*   ctype=2  -> bstrata(stratum) noadjust
*   ctype=3  -> crrc reference, cluster(stratum) nuisance noadjust
*
* The full covariance matrix is comparable for ctype=1 and ctype=3. ctype=2
* uses the paper's highly-stratified variance, which finegray does not claim
* to implement.

clear all
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

local qadir "`c(pwd)'"
local pkg_dir = regexr("`qadir'", "/qa$", "")
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "crossval_public_studies.do must run from finegray/qa"
    exit 601
}

capture log close _all
log using "crossval_public_studies.log", replace text name(_cvpub)

capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

tempfile anchor
local scratch "`anchor'_dir"
capture mkdir "`scratch'"
local data_csv "`scratch'/public_studies.csv"
local oracle_csv "`scratch'/public_studies_oracle.csv"
local status_txt "`scratch'/r_status.txt"

capture erase "`data_csv'"
capture erase "`oracle_csv'"
capture erase "`status_txt'"
shell Rscript "`qadir'/crossval_public_studies_r.R" "`data_csv'" ///
    "`oracle_csv'" && echo 0 > "`status_txt'" || echo 1 > "`status_txt'"

local r_ok = 1
capture confirm file "`status_txt'"
if _rc local r_ok = 0
if `r_ok' {
    tempname sfh
    file open `sfh' using "`status_txt'", read text
    file read `sfh' status_line
    file close `sfh'
    if real(trim("`status_line'")) != 0 local r_ok = 0
}
foreach f in "`data_csv'" "`oracle_csv'" {
    capture confirm file `"`f'"'
    if _rc local r_ok = 0
}

if !`r_ok' {
    display as error "R oracle generation failed; crrSC and Rscript are required"
    local test_count = 5
    local skip_count = 5
}

if `r_ok' {
    * Read oracle values into locals before loading the study rows.
    import delimited using "`oracle_csv'", clear varnames(1) case(preserve)
    local n_oracle = _N
    assert `n_oracle' == 47
    forvalues i = 1/`n_oracle' {
        local ds = dataset[`i']
        local ct = ctype[`i']
        local qt = quantity[`i']
        local rw = row[`i']
        local cl = col[`i']
        if "`cl'" == "" local cl "z"
        local ref_`ds'_`ct'_`qt'_`rw'_`cl' = value[`i']
    }

    **# P1: Oracle shape and public-study composition
    local ++test_count
    capture noisily {
        assert `ref_bce_1_meta_n_total_z' == 200
        assert `ref_bce_1_meta_n_used_z' == 200
        assert `ref_bce_1_meta_n_strata_z' == 2
        assert `ref_center_2_meta_n_total_z' == 400
        assert `ref_center_2_meta_n_used_z' < 400
        assert `ref_center_2_meta_n_used_z' > 350
        assert `ref_center_2_meta_n_strata_z' > 100
        assert `ref_bce_1_meta_converged_z' == 1
        assert `ref_bce_2_meta_converged_z' == 1
        assert `ref_center_2_meta_converged_z' == 1
        assert `ref_center_3_meta_converged_z' == 1
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: P1 public datasets and oracle metadata are complete"
    }
    else {
        local ++fail_count
        display as error "  FAIL: P1 oracle shape/composition (rc=`=_rc')"
    }

    **# P2: ECOG bce, regular strata (ctype=1), coefficients and full V
    local ++test_count
    capture noisily {
        import delimited using "`data_csv'", clear varnames(1) case(preserve)
        keep if dataset == "bce"
        gen long sid = _n
        gen byte anyevent = status != 0
        quietly stset time, failure(anyevent == 1) id(sid)
        quietly finegray x1 x2 x3, compete(status) cause(1) ///
            bstrata(stratum) strata(stratum) nuisance noadjust nolog
        assert e(converged) == 1
        assert e(N) == `ref_bce_1_meta_n_used_z'
        assert e(N_fail) == `ref_bce_1_meta_n_fail_z'
        assert e(N_compete) == `ref_bce_1_meta_n_compete_z'
        assert e(k_bstrata) == `ref_bce_1_meta_n_strata_z'
        assert "`e(vce_meat)'" == "nuisance_adjusted"
        matrix V = e(V)
        local worst_b = 0
        local worst_v = 0
        foreach a in x1 x2 x3 {
            local db = abs(_b[`a'] - `ref_bce_1_coef_`a'_z')
            if `db' > `worst_b' local worst_b = `db'
            assert `db' < 1e-5
            foreach b in x1 x2 x3 {
                local den = sqrt(V[colnumb(V,"`a'"),colnumb(V,"`a'")] * ///
                    V[colnumb(V,"`b'"),colnumb(V,"`b'")])
                local dv = abs(V[colnumb(V,"`a'"),colnumb(V,"`b'")] - ///
                    `ref_bce_1_vcov_`a'_`b'') / `den'
                if `dv' > `worst_v' local worst_v = `dv'
                assert `dv' < 1e-6
            }
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: P2 ECOG bce ctype=1 b and full V agree (max b=`=string(`worst_b',"%8.2e")', V=`=string(`worst_v',"%8.2e")')"
    }
    else {
        local ++fail_count
        display as error "  FAIL: P2 ECOG bce ctype=1 (rc=`=_rc')"
    }

    **# P3: ECOG bce, pooled censoring distribution (ctype=2)
    local ++test_count
    capture noisily {
        import delimited using "`data_csv'", clear varnames(1) case(preserve)
        keep if dataset == "bce"
        gen long sid = _n
        gen byte anyevent = status != 0
        quietly stset time, failure(anyevent == 1) id(sid)
        quietly finegray x1 x2 x3, compete(status) cause(1) ///
            bstrata(stratum) noadjust nolog
        assert e(converged) == 1
        local worst_b2 = 0
        foreach a in x1 x2 x3 {
            local db = abs(_b[`a'] - `ref_bce_2_coef_`a'_z')
            if `db' > `worst_b2' local worst_b2 = `db'
            assert `db' < 1e-5
        }
        * The two censoring regimes must be distinguishable on this study.
        local regime_gap = 0
        foreach a in x1 x2 x3 {
            local dg = abs(`ref_bce_1_coef_`a'_z' - `ref_bce_2_coef_`a'_z')
            if `dg' > `regime_gap' local regime_gap = `dg'
        }
        assert `regime_gap' > 1e-5
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: P3 ECOG bce ctype=2 coefficients agree (max=`=string(`worst_b2',"%8.2e")')"
    }
    else {
        local ++fail_count
        display as error "  FAIL: P3 ECOG bce ctype=2 (rc=`=_rc')"
    }

    **# P4: Multicentre transplant subsample, high stratification (ctype=2)
    local ++test_count
    capture noisily {
        import delimited using "`data_csv'", clear varnames(1) case(preserve)
        keep if dataset == "center"
        gen long sid = _n
        gen byte anyevent = status != 0
        quietly stset time, failure(anyevent == 1) id(sid)
        quietly finegray x1 x2, compete(status) cause(1) ///
            bstrata(stratum) noadjust nolog
        assert e(converged) == 1
        assert e(N) == `ref_center_2_meta_n_used_z'
        assert e(N_fail) == `ref_center_2_meta_n_fail_z'
        assert e(N_compete) == `ref_center_2_meta_n_compete_z'
        assert e(k_bstrata) == `ref_center_2_meta_n_strata_z'
        local worst_bc = 0
        foreach a in x1 x2 {
            local db = abs(_b[`a'] - `ref_center_2_coef_`a'_z')
            if `db' > `worst_bc' local worst_bc = `db'
            assert `db' < 1e-5
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: P4 multicentre high-strata coefficients agree (max=`=string(`worst_bc',"%8.2e")')"
    }
    else {
        local ++fail_count
        display as error "  FAIL: P4 multicentre high-strata parity (rc=`=_rc')"
    }

    **# P5: Same multicentre study, marginal clustered estimator (crrc)
    local ++test_count
    capture noisily {
        import delimited using "`data_csv'", clear varnames(1) case(preserve)
        keep if dataset == "center"
        gen long sid = _n
        gen byte anyevent = status != 0
        quietly stset time, failure(anyevent == 1) id(sid)
        quietly finegray x1 x2, compete(status) cause(1) ///
            cluster(stratum) nuisance noadjust nolog
        assert e(converged) == 1
        assert e(N) == `ref_center_3_meta_n_used_z'
        assert e(N_fail) == `ref_center_3_meta_n_fail_z'
        assert e(N_compete) == `ref_center_3_meta_n_compete_z'
        assert e(N_clust) == `ref_center_3_meta_n_strata_z'
        assert "`e(vce)'" == "cluster"
        assert "`e(vce_meat)'" == "nuisance_adjusted"
        matrix V = e(V)
        local worst_bcl = 0
        local worst_vcl = 0
        foreach a in x1 x2 {
            local db = abs(_b[`a'] - `ref_center_3_coef_`a'_z')
            if `db' > `worst_bcl' local worst_bcl = `db'
            assert `db' < 1e-5
            foreach b in x1 x2 {
                local den = sqrt(V[colnumb(V,"`a'"),colnumb(V,"`a'")] * ///
                    V[colnumb(V,"`b'"),colnumb(V,"`b'")])
                local dv = abs(V[colnumb(V,"`a'"),colnumb(V,"`b'")] - ///
                    `ref_center_3_vcov_`a'_`b'') / `den'
                if `dv' > `worst_vcl' local worst_vcl = `dv'
                assert `dv' < 1e-5
            }
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: P5 crrc clustered b and full V agree (max b=`=string(`worst_bcl',"%8.2e")', V=`=string(`worst_vcl',"%8.2e")')"
    }
    else {
        local ++fail_count
        display as error "  FAIL: P5 multicentre crrc cluster parity (rc=`=_rc')"
    }
}

display as text "RESULT: crossval_public_studies tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

capture erase "`data_csv'"
capture erase "`oracle_csv'"
capture erase "`status_txt'"
capture rmdir "`scratch'"

* A SKIPPED EXTERNAL ORACLE IS AN UNRUN CHECK, NOT A PASS (2026-09-02).
* This suite used to print "RESULT: PASS (n passed, k skipped)" and exit 0 when
* the R oracle was unavailable, so a machine with no R -- or with the package
* missing -- produced a green cross-validation that had cross-validated nothing.
* run_all.do already treats skip > 0 as a lane failure by parsing the machine
* sentinel, but a human reading the suite's own last line was told PASS.  Match
* crossval_pweight.do: skip > 0 exits 1, and the word PASS is not printed on a
* skipped run.  The machine sentinel above is unchanged -- run_all.do parses
* `RESULT: <name> tests=.. pass=.. fail=.. skip=..' and nothing else.
if `fail_count' > 0 {
    capture log close _cvpub
    exit 1
}
if `skip_count' > 0 {
    display as error ///
        "NOT RUN: `skip_count' check(s) SKIPPED -- the R oracle was unavailable"
    display as error "Install the missing R dependency and re-run; a skipped oracle is not evidence."
    capture log close _cvpub
    exit 1
}
capture log close _cvpub
