*! _tabtools_simtab_ingest Version 1.9.10  2026/07/17
*! Ingest a pre-computed simulation summary (simsum / siman / generic) for simtab
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Isolated adapter for simtab's ingest mode. Maps an already-computed
    simulation summary -- produced by simsum (White 2010), siman analyse (UCL),
    or any generic per-cell summary -- onto simtab's internal cell model:

        by x estimator x estimand x {measure value, mcse}

    The current data in memory IS the summary. No recomputation is performed;
    values and Monte Carlo SEs are taken as-is. simsum/siman are reached only
    through their public output contracts, never forked or redistributed.

    Leaves a standardized per-cell summary in memory with columns:
        byord bylab estord estlab emdord emdlab n truev
        m_mean m_bias m_pctbias m_empse m_meanse m_relerr m_mse m_rmse
        m_coverage m_power m_nfail m_pctfail
        mc_mean mc_bias mc_pctbias mc_empse mc_mse mc_rmse mc_coverage mc_power

    Returns: r(source) r(has_by) r(has_emd) r(measures) r(by_header)
             r(est_header) r(n_by) r(n_estimators) r(n_estimands)
*/

capture program drop _tabtools_simtab_ingest_ready
program _tabtools_simtab_ingest_ready
    version 16.0
end

capture program drop _tabtools_simtab_ingest
program define _tabtools_simtab_ingest, rclass
    version 16.0
    syntax , SOURCE(string) [BYVar(name) ESTIMATORVar(name) ///
        ESTIMANDVar(name) MEASures(string asis) ORDER(string)]

    local source = strtrim(lower("`source'"))

    if "`source'" == "summary" {
        _tabtools_simtab_ingest_summary, byvar(`byvar') estimatorvar(`estimatorvar') ///
            estimandvar(`estimandvar') measures(`measures') order(`order')
    }
    else if "`source'" == "simsum" {
        _tabtools_simtab_ingest_simsum, order(`order')
    }
    else if "`source'" == "siman" {
        _tabtools_simtab_ingest_siman, order(`order')
    }
    else {
        display as error "from() must be one of: simsum, siman, summary"
        exit 198
    }

    * ----- standardized finalizer -----
    local _has_by  = `r(has_by)'
    local _has_emd = `r(has_emd)'
    local _by_header  "`r(by_header)'"
    local _est_header "`r(est_header)'"

    * ensure all standardized columns exist
    foreach v in n truev m_mean m_bias m_pctbias m_empse m_meanse m_relerr ///
        m_mse m_rmse m_coverage m_power m_nfail m_pctfail ///
        mc_mean mc_bias mc_pctbias mc_empse mc_mse mc_rmse mc_coverage mc_power {
        capture confirm variable `v'
        if _rc quietly gen double `v' = .
    }
    capture confirm variable bylab
    if _rc quietly gen str1 bylab = ""
    capture confirm variable estlab
    if _rc {
        display as error "ingest produced no estimator labels; data does not match `source' output"
        exit 459
    }
    capture confirm variable emdlab
    if _rc quietly gen str1 emdlab = ""
    capture confirm variable byord
    if _rc quietly gen byte byord = 1
    capture confirm variable estord
    if _rc quietly egen long estord = group(estlab)
    capture confirm variable emdord
    if _rc quietly gen byte emdord = 1

    * which measures are actually present (non-missing somewhere)
    local _measures ""
    foreach tok in mean bias pctbias empse meanse relerr mse rmse coverage power {
        quietly count if !missing(m_`tok')
        if r(N) > 0 local _measures "`_measures' `tok'"
    }
    quietly count if !missing(n)
    if r(N) > 0 local _measures "`_measures' n"
    local _measures = strtrim("`_measures'")

    quietly summarize byord, meanonly
    return scalar n_by = r(max)
    quietly summarize estord, meanonly
    return scalar n_estimators = r(max)
    quietly summarize emdord, meanonly
    return scalar n_estimands = r(max)
    return local measures "`_measures'"
    return scalar has_by = `_has_by'
    return scalar has_emd = `_has_emd'
    if "`_by_header'" == "" local _by_header "Group"
    if "`_est_header'" == "" local _est_header "Method"
    return local by_header "`_by_header'"
    return local est_header "`_est_header'"
    return local source "`source'"
end


* ============================================================================
* Generic per-cell summary (the stable, dependency-free contract)
* ============================================================================
capture program drop _tabtools_simtab_ingest_identity
program _tabtools_simtab_ingest_identity
    version 16.0
    args var ordvar labvar seq order

    capture confirm string variable `var'
    if !_rc quietly replace `labvar' = `var'
    else {
        local _vl : value label `var'
        if "`_vl'" != "" {
            tempvar _decoded
            quietly decode `var', generate(`_decoded')
            quietly replace `labvar' = `_decoded'
        }
        else quietly replace `labvar' = strtrim(string(`var', "%21.0g"))
    }

    if "`order'" == "sort" quietly egen long `ordvar' = group(`var')
    else {
        tempvar _first
        quietly egen long `_first' = min(`seq'), by(`var')
        quietly egen long `ordvar' = group(`_first')
    }

    tempvar _lmin _lmax _raw
    quietly egen long `_lmin' = min(`ordvar'), by(`labvar')
    quietly egen long `_lmax' = max(`ordvar'), by(`labvar')
    capture confirm string variable `var'
    if !_rc quietly gen str244 `_raw' = `var'
    else quietly gen str244 `_raw' = strtrim(string(`var', "%21x"))
    quietly replace `labvar' = substr(`labvar' + " [" + `_raw' + "]", 1, 244) ///
        if `_lmin' != `_lmax'
end

capture program drop _tabtools_simtab_ingest_summary
program _tabtools_simtab_ingest_summary, rclass
    version 16.0
    syntax , ESTIMATORVar(name) [BYVar(name) ESTIMANDVar(name) ///
        MEASures(string) ORDER(string)]

    local order = lower(strtrim("`order'"))
    if "`order'" == "" local order "data"
    if !inlist("`order'", "data", "sort") {
        display as error "order() must be data or sort"
        exit 198
    }

    confirm variable `estimatorvar'
    local _has_by  = (`"`byvar'"' != "")
    local _has_emd = (`"`estimandvar'"' != "")
    if `_has_by'  confirm variable `byvar'
    if `_has_emd' confirm variable `estimandvar'

    tempvar _seq _estlab _estord _bylab _byord _emdlab _emdord
    quietly gen long `_seq' = _n

    * ----- estimator labels/ord -----
    quietly gen str244 `_estlab' = ""
    _tabtools_simtab_ingest_identity `estimatorvar' `_estord' `_estlab' `_seq' "`order'"

    * ----- by labels/ord -----
    if `_has_by' {
        quietly gen str244 `_bylab' = ""
        _tabtools_simtab_ingest_identity `byvar' `_byord' `_bylab' `_seq' "`order'"
    }
    else {
        quietly gen str1 `_bylab' = ""
        quietly gen byte `_byord' = 1
    }

    * ----- estimand labels/ord -----
    if `_has_emd' {
        quietly gen str244 `_emdlab' = ""
        _tabtools_simtab_ingest_identity `estimandvar' `_emdord' `_emdlab' `_seq' "`order'"
    }
    else {
        quietly gen str1 `_emdlab' = ""
        quietly gen byte `_emdord' = 1
    }

    capture isid `_byord' `_estord' `_emdord'
    if _rc {
        display as error "duplicate summary cells found for by() x estimator x estimand"
        exit 459
    }

    * ----- measure mapping -----
    if `"`measures'"' == "" {
        display as error "from(summary) requires measures() mapping, e.g. measures(mean=m bias=b coverage=cov n=nrep)"
        exit 198
    }
    local _valid "mean bias pctbias empse meanse relerr mse rmse coverage power n"
    local _mapped ""
    local _measure_keep ""
    foreach _pair of local measures {
        local _eq = strpos("`_pair'", "=")
        if `_eq' <= 1 {
            display as error "measures(): bad pair `_pair' (use token=column)"
            exit 198
        }
        local _tok = lower(strtrim(substr("`_pair'", 1, `_eq' - 1)))
        local _col = strtrim(substr("`_pair'", `_eq' + 1, .))
        if "`_tok'" == "" | "`_col'" == "" {
            display as error "measures(): bad pair `_pair' (use token=column)"
            exit 198
        }
        if !`: list _tok in _valid' {
            display as error "measures(): unknown token `_tok'"
            exit 198
        }
        if `: list _tok in _mapped' {
            display as error "measures(): token `_tok' was mapped more than once"
            exit 198
        }
        confirm variable `_col'
        tempvar _std
        quietly gen double `_std' = `_col'
        local _std_`_tok' "`_std'"
        local _mapped "`_mapped' `_tok'"
        local _measure_keep "`_measure_keep' `_std'"
    }

    keep `_byord' `_bylab' `_estord' `_estlab' `_emdord' `_emdlab' `_measure_keep'
    rename `_byord' byord
    rename `_bylab' bylab
    rename `_estord' estord
    rename `_estlab' estlab
    rename `_emdord' emdord
    rename `_emdlab' emdlab
    local _rename_queue "`_measure_keep'"
    foreach _pair of local measures {
        gettoken _stdvar _rename_queue : _rename_queue
        local _eq = strpos("`_pair'", "=")
        local _tok = lower(strtrim(substr("`_pair'", 1, `_eq' - 1)))
        if "`_tok'" == "n" rename `_stdvar' n
        else rename `_stdvar' m_`_tok'
    }

    local _by_header "`byvar'"
    local _est_header "`estimatorvar'"
    return scalar has_by = `_has_by'
    return scalar has_emd = `_has_emd'
    return local by_header "`_by_header'"
    return local est_header "`_est_header'"
end


* ============================================================================
* simsum clear output  (measure-by-row, method-by-column)
*   vars: perfmeascode (str codes), estimate0 estimate1 ... (var label=method),
*         optional estimateK_mcse, optional single by-variable column.
* ============================================================================
capture program drop _tabtools_simtab_ingest_simsum
program _tabtools_simtab_ingest_simsum, rclass
    version 16.0
    syntax , [ORDER(string)]

    local order = lower(strtrim("`order'"))
    if "`order'" == "" local order "data"
    if !inlist("`order'", "data", "sort") {
        display as error "order() must be data or sort"
        exit 198
    }

    capture which simsum
    if _rc {
        display as text "note: simsum is not installed; reading current data as simsum output (ssc install simsum)"
    }

    capture confirm variable perfmeascode
    if _rc {
        display as error "data does not look like simsum output (no perfmeascode variable)"
        display as error "run `simsum ..., clear' first, or use from(summary) with explicit column options"
        exit 459
    }

    * value columns = estimate* not ending in _mcse
    quietly ds estimate*
    local _allest "`r(varlist)'"
    local _valcols ""
    local _mcsecols ""
    foreach v of local _allest {
        if regexm("`v'", "_mcse$") local _mcsecols "`_mcsecols' `v'"
        else local _valcols "`_valcols' `v'"
    }
    if "`_valcols'" == "" {
        display as error "data does not look like simsum output (no estimate* value columns)"
        exit 459
    }

    * by columns = anything that is not perfmeas* or estimate*
    quietly ds perfmeas* estimate*
    local _known "`r(varlist)'"
    quietly ds
    local _allvars "`r(varlist)'"
    local _bycols : list _allvars - _known
    local _nby_cols : word count `_bycols'
    if `_nby_cols' > 1 {
        display as error "simsum output has multiple by-variables; use from(summary) for this layout"
        exit 459
    }
    local _has_by = (`_nby_cols' == 1)
    local _byvar "`_bycols'"

    * code -> token map
    local _codes  "bsims bias pctbias mean empse mse rmse modelse relerror cover power"
    local _tokens "n     bias pctbias mean empse mse rmse meanse  relerr   coverage power"

    tempfile _out
    tempname _pf
    quietly postfile `_pf' byord str244 bylab estord str244 estlab ///
        double(n m_mean m_bias m_pctbias m_empse m_meanse m_relerr m_mse m_rmse m_coverage m_power) ///
        double(mc_mean mc_bias mc_pctbias mc_empse mc_mse mc_rmse mc_coverage mc_power) ///
        using `"`_out'"'

    tempvar _obs
    quietly gen long `_obs' = _n

    * by levels
    if `_has_by' {
        tempvar _bytag _bylabtmp
        quietly gen str244 `_bylabtmp' = ""
        _tabtools_simtab_ingest_identity `_byvar' `_bytag' `_bylabtmp' `_obs' "`order'"
        quietly summarize `_bytag', meanonly
        local _nbylev = r(max)
    }
    else {
        local _nbylev = 1
    }

    * Disambiguate repeated method labels, then honor data/sorted order.
    local _nval : word count `_valcols'
    forvalues _vi = 1/`_nval' {
        local _vc : word `_vi' of `_valcols'
        local _mlab_`_vc' : variable label `_vc'
        if `"`_mlab_`_vc''"' == "" local _mlab_`_vc' "`_vc'"
    }
    forvalues _vi = 1/`_nval' {
        local _vc : word `_vi' of `_valcols'
        local _dup = 0
        forvalues _vj = 1/`_nval' {
            local _other : word `_vj' of `_valcols'
            if `"`_mlab_`_vc''"' == `"`_mlab_`_other''"' local ++_dup
        }
        if `_dup' > 1 local _mlab_`_vc' `"`_mlab_`_vc'' [`_vc']"'
    }
    local _ordered_valcols "`_valcols'"
    if "`order'" == "sort" {
        local _ordered_valcols ""
        local _remaining "`_valcols'"
        while `"`_remaining'"' != "" {
            local _best ""
            local _best_label ""
            foreach _vc of local _remaining {
                local _candidate = lower(`"`_mlab_`_vc''"')
                if `"`_best'"' == "" | `"`_candidate'"' < `"`_best_label'"' {
                    local _best "`_vc'"
                    local _best_label `"`_candidate'"'
                }
            }
            local _ordered_valcols "`_ordered_valcols' `_best'"
            local _remaining : list _remaining - _best
        }
    }

    local _estord = 0
    foreach _vc of local _ordered_valcols {
        local ++_estord
        local _mlab `"`_mlab_`_vc''"'
        local _mc "`_vc'_mcse"
        capture confirm variable `_mc'
        local _has_mc = (_rc == 0)

        forvalues _bl = 1/`_nbylev' {
            local _bylab ""
            local _bycond "1"
            if `_has_by' {
                quietly summarize `_obs' if `_bytag' == `_bl', meanonly
                local _bidx = r(min)
                local _bylab = `_bylabtmp'[`_bidx']
                local _bycond "`_bytag' == `_bl'"
            }

            * gather mapped measures for this method x by cell
            foreach _t in n m_mean m_bias m_pctbias m_empse m_meanse m_relerr m_mse m_rmse m_coverage m_power mc_mean mc_bias mc_pctbias mc_empse mc_mse mc_rmse mc_coverage mc_power {
                local _v_`_t' = .
            }
            local _nc : word count `_codes'
            forvalues _k = 1/`_nc' {
                local _code : word `_k' of `_codes'
                local _tok  : word `_k' of `_tokens'
                quietly summarize `_obs' if perfmeascode == "`_code'" & `_bycond', meanonly
                if r(N) > 0 {
                    local _ridx = r(min)
                    local _raw = `_vc'[`_ridx']
                    if "`_tok'" == "n" local _v_n = `_raw'
                    else if inlist("`_tok'", "coverage", "power") local _v_m_`_tok' = `_raw'/100
                    else local _v_m_`_tok' = `_raw'
                    if `_has_mc' {
                        local _rawmc = `_mc'[`_ridx']
                        if inlist("`_tok'", "coverage", "power") local _v_mc_`_tok' = `_rawmc'/100
                        else if !inlist("`_tok'", "n", "meanse", "relerr") local _v_mc_`_tok' = `_rawmc'
                    }
                }
            }

            post `_pf' (`_bl') ("`_bylab'") (`_estord') ("`_mlab'") ///
                (`_v_n') (`_v_m_mean') (`_v_m_bias') (`_v_m_pctbias') (`_v_m_empse') ///
                (`_v_m_meanse') (`_v_m_relerr') (`_v_m_mse') (`_v_m_rmse') ///
                (`_v_m_coverage') (`_v_m_power') ///
                (`_v_mc_mean') (`_v_mc_bias') (`_v_mc_pctbias') (`_v_mc_empse') ///
                (`_v_mc_mse') (`_v_mc_rmse') (`_v_mc_coverage') (`_v_mc_power')
        }
    }
    postclose `_pf'

    use `"`_out'"', clear
    quietly gen str1 emdlab = ""
    quietly gen byte emdord = 1

    return scalar has_by = `_has_by'
    return scalar has_emd = 0
    return local by_header "Scenario"
    return local est_header "Method"
end


* ============================================================================
* siman analyse output  (long performance rows; reached only through siman's
*   public output contract). siman setup/analyse appends performance rows
*   flagged by a non-missing _perfmeascode; the measure VALUE is in `estimate'
*   and its Monte Carlo SE in `se'. Structure variables (method/dgm/target/true)
*   are read from the siman_* _dta characteristics setup leaves behind.
* ============================================================================
capture program drop _tabtools_simtab_ingest_siman
program _tabtools_simtab_ingest_siman, rclass
    version 16.0
    syntax , [ORDER(string)]

    local order = lower(strtrim("`order'"))
    if "`order'" == "" local order "data"
    if !inlist("`order'", "data", "sort") {
        display as error "order() must be data or sort"
        exit 198
    }

    capture which siman
    if _rc {
        display as text "note: siman is not installed; reading current data as siman analyse output"
    }

    * performance-measure code column + value column
    local _codevar ""
    foreach v in _perfmeascode perfmeascode {
        capture confirm variable `v'
        if !_rc {
            local _codevar "`v'"
            continue, break
        }
    }
    capture confirm variable estimate
    local _has_est = (_rc == 0)
    if "`_codevar'" == "" | !`_has_est' {
        display as error "data does not look like siman analyse output (no performance-measure code / estimate column)"
        display as error "run `siman setup' then `siman analyse' first, or use from(summary) with explicit column options"
        exit 459
    }

    * structure variables from siman characteristics (robust), with fallbacks
    local _method : char _dta[siman_method]
    local _dgm    : char _dta[siman_dgm]
    local _target : char _dta[siman_target]
    local _true_source : char _dta[siman_true]
    if "`_method'" == "" {
        capture confirm variable method
        if !_rc local _method "method"
    }
    if "`_method'" == "" {
        display as error "siman ingest could not identify the method variable; use from(summary)"
        exit 459
    }
    local _dgm1 : word 1 of `_dgm'
    local _target1 : word 1 of `_target'

    * keep performance rows only
    quietly keep if !missing(`_codevar')
    quietly count
    if r(N) == 0 {
        display as error "no siman performance rows found; run `siman analyse' first"
        exit 459
    }

    tempvar _seq _estlab _estord _bylab _byord _emdlab _emdord _truev
    quietly gen long `_seq' = _n

    * ----- standardized estimator labels/ords -----
    quietly gen str244 `_estlab' = ""
    _tabtools_simtab_ingest_identity `_method' `_estord' `_estlab' `_seq' "`order'"

    * ----- by (dgm) -----
    local _has_by = 0
    if "`_dgm1'" != "" {
        local _has_by = 1
        quietly gen str244 `_bylab' = ""
        local _n_dgm : word count `_dgm'
        local _dgm_i = 0
        foreach _dv of local _dgm {
            local ++_dgm_i
            confirm variable `_dv'
            tempvar _component _component_ord
            quietly gen str244 `_component' = ""
            _tabtools_simtab_ingest_identity `_dv' `_component_ord' `_component' `_seq' "`order'"
            if `_n_dgm' == 1 {
                quietly replace `_bylab' = `_component'
            }
            else if `_dgm_i' == 1 {
                quietly replace `_bylab' = substr("`_dv'=" + `_component', 1, 244)
            }
            else {
                quietly replace `_bylab' = substr(`_bylab' + "; `_dv'=" + `_component', 1, 244)
            }
        }
        if "`order'" == "sort" quietly egen long `_byord' = group(`_bylab')
        else {
            tempvar _byfirst
            quietly egen long `_byfirst' = min(`_seq'), by(`_dgm')
            quietly egen long `_byord' = group(`_byfirst')
        }
    }
    else {
        quietly gen str1 `_bylab' = ""
        quietly gen byte `_byord' = 1
    }

    * ----- estimand (target) -----
    local _has_emd = 0
    if "`_target1'" != "" {
        local _has_emd = 1
        quietly gen str244 `_emdlab' = ""
        _tabtools_simtab_ingest_identity `_target1' `_emdord' `_emdlab' `_seq' "`order'"
    }
    else {
        quietly gen str1 `_emdlab' = ""
        quietly gen byte `_emdord' = 1
    }

    * ----- true value -----
    quietly gen double `_truev' = .
    if "`_true_source'" != "" {
        capture confirm variable `_true_source'
        if !_rc quietly replace `_truev' = `_true_source'
    }

    * The raw cell identity includes every DGM dimension, method, and target.
    tempvar _cellid
    local _cellvars `_method'
    if "`_dgm'" != ""    local _cellvars "`_cellvars' `_dgm'"
    if "`_target1'" != "" local _cellvars "`_cellvars' `_target1'"
    quietly egen long `_cellid' = group(`_cellvars')
    capture isid `_cellid' `_codevar'
    if _rc {
        display as error "duplicate siman performance rows found for a simulation cell and measure"
        exit 459
    }

    * ----- pivot siman codes to measure value (estimate) + mcse (se) columns -----
    local _codes  "estreps bias pctbias mean empse modelse relerror cover power mse rmse"
    local _tokens "n       bias pctbias mean empse meanse  relerr   coverage power mse rmse"
    local _nc : word count `_codes'
    tempvar _n_std
    quietly gen double `_n_std' = .
    local _measure_vars ""
    local _measure_tokens ""
    local _mc_vars ""
    local _mc_tokens ""
    capture confirm variable se
    local _has_se = (_rc == 0)
    forvalues _k = 1/`_nc' {
        local _code : word `_k' of `_codes'
        local _tok  : word `_k' of `_tokens'
        if "`_tok'" == "n" {
            quietly replace `_n_std' = estimate if `_codevar' == "`_code'"
        }
        else {
            tempvar _mv _mcv
            quietly gen double `_mv' = .
            quietly gen double `_mcv' = .
            if inlist("`_tok'", "coverage", "power") {
                quietly replace `_mv' = estimate/100 if `_codevar' == "`_code'"
                if `_has_se' quietly replace `_mcv' = se/100 if `_codevar' == "`_code'"
            }
            else {
                quietly replace `_mv' = estimate if `_codevar' == "`_code'"
                if `_has_se' quietly replace `_mcv' = se if `_codevar' == "`_code'"
            }
            local _measure_vars "`_measure_vars' `_mv'"
            local _measure_tokens "`_measure_tokens' `_tok'"
            if !inlist("`_tok'", "meanse", "relerr") {
                local _mc_vars "`_mc_vars' `_mcv'"
                local _mc_tokens "`_mc_tokens' `_tok'"
            }
        }
    }

    * ----- collapse to one row per cell (each measure non-missing in one row) -----
    collapse (firstnm) `_estlab' `_estord' `_bylab' `_byord' `_emdlab' `_emdord' `_truev' ///
        (max) `_n_std' `_measure_vars' `_mc_vars', by(`_cellid')
    quietly drop `_cellid'

    rename `_estlab' estlab
    rename `_estord' estord
    rename `_bylab' bylab
    rename `_byord' byord
    rename `_emdlab' emdlab
    rename `_emdord' emdord
    rename `_truev' truev
    rename `_n_std' n
    local _n_measure_vars : word count `_measure_vars'
    forvalues _k = 1/`_n_measure_vars' {
        local _mv : word `_k' of `_measure_vars'
        local _tok : word `_k' of `_measure_tokens'
        rename `_mv' m_`_tok'
    }
    local _n_mc_vars : word count `_mc_vars'
    forvalues _k = 1/`_n_mc_vars' {
        local _mcv : word `_k' of `_mc_vars'
        local _tok : word `_k' of `_mc_tokens'
        rename `_mcv' mc_`_tok'
    }

    local _by_header "DGM"
    if "`_dgm'" != "" local _by_header "DGM (`_dgm')"
    local _est_header "`_method'"
    return scalar has_by = `_has_by'
    return scalar has_emd = `_has_emd'
    return local by_header "`_by_header'"
    return local est_header "`_est_header'"
end
