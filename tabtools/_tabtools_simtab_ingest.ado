*! _tabtools_simtab_ingest Version 1.8.4  2026/06/23
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
        ESTIMANDVar(name) MEASures(string asis)]

    local source = strtrim(lower("`source'"))

    if "`source'" == "summary" {
        _tabtools_simtab_ingest_summary, byvar(`byvar') estimatorvar(`estimatorvar') ///
            estimandvar(`estimandvar') measures(`measures')
    }
    else if "`source'" == "simsum" {
        _tabtools_simtab_ingest_simsum
    }
    else if "`source'" == "siman" {
        _tabtools_simtab_ingest_siman
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
capture program drop _tabtools_simtab_ingest_summary
program _tabtools_simtab_ingest_summary, rclass
    version 16.0
    syntax , ESTIMATORVar(name) [BYVar(name) ESTIMANDVar(name) MEASures(string)]

    confirm variable `estimatorvar'
    local _has_by  = (`"`byvar'"' != "")
    local _has_emd = (`"`estimandvar'"' != "")
    if `_has_by'  confirm variable `byvar'
    if `_has_emd' confirm variable `estimandvar'

    * ----- estimator labels/ord -----
    quietly gen str244 estlab = ""
    capture confirm string variable `estimatorvar'
    if !_rc quietly replace estlab = `estimatorvar'
    else {
        local _vl : value label `estimatorvar'
        if "`_vl'" != "" {
            tempvar _d
            quietly decode `estimatorvar', generate(`_d')
            quietly replace estlab = `_d'
        }
        else quietly replace estlab = strtrim(string(`estimatorvar', "%14.0g"))
    }
    quietly egen long estord = group(`estimatorvar')

    * ----- by labels/ord -----
    if `_has_by' {
        quietly gen str244 bylab = ""
        capture confirm string variable `byvar'
        if !_rc quietly replace bylab = `byvar'
        else {
            local _vl : value label `byvar'
            if "`_vl'" != "" {
                tempvar _db
                quietly decode `byvar', generate(`_db')
                quietly replace bylab = `_db'
            }
            else quietly replace bylab = strtrim(string(`byvar', "%14.0g"))
        }
        quietly egen long byord = group(`byvar')
    }
    else {
        quietly gen str1 bylab = ""
        quietly gen byte byord = 1
    }

    * ----- estimand labels/ord -----
    if `_has_emd' {
        quietly gen str244 emdlab = ""
        capture confirm string variable `estimandvar'
        if !_rc quietly replace emdlab = `estimandvar'
        else {
            local _vl : value label `estimandvar'
            if "`_vl'" != "" {
                tempvar _de
                quietly decode `estimandvar', generate(`_de')
                quietly replace emdlab = `_de'
            }
            else quietly replace emdlab = strtrim(string(`estimandvar', "%14.0g"))
        }
        quietly egen long emdord = group(`estimandvar')
    }
    else {
        quietly gen str1 emdlab = ""
        quietly gen byte emdord = 1
    }

    * ----- measure mapping -----
    if `"`measures'"' == "" {
        display as error "from(summary) requires measures() mapping, e.g. measures(mean=m bias=b coverage=cov n=nrep)"
        exit 198
    }
    local _valid "mean bias pctbias empse meanse relerr mse rmse coverage power n"
    foreach _pair of local measures {
        local _eq = strpos("`_pair'", "=")
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
        confirm variable `_col'
        if "`_tok'" == "n" {
            quietly gen double n = `_col'
        }
        else {
            quietly gen double m_`_tok' = `_col'
        }
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

    quietly gen long _obs = _n

    * by levels
    if `_has_by' {
        capture confirm string variable `_byvar'
        local _bystr = (_rc == 0)
        tempvar _bytag
        quietly egen long `_bytag' = group(`_byvar')
        quietly summarize `_bytag', meanonly
        local _nbylev = r(max)
    }
    else {
        local _nbylev = 1
    }

    local _estord = 0
    foreach _vc of local _valcols {
        local ++_estord
        local _mlab : variable label `_vc'
        if `"`_mlab'"' == "" local _mlab "`_vc'"
        local _mc "`_vc'_mcse"
        capture confirm variable `_mc'
        local _has_mc = (_rc == 0)

        forvalues _bl = 1/`_nbylev' {
            local _bylab ""
            local _bycond "1"
            if `_has_by' {
                quietly summarize _obs if `_bytag' == `_bl', meanonly
                local _bidx = r(min)
                if `_bystr' local _bylab = `_byvar'[`_bidx']
                else {
                    local _vl : value label `_byvar'
                    if "`_vl'" != "" local _bylab : label `_vl' `=`_byvar'[`_bidx']'
                    else local _bylab = strtrim(string(`_byvar'[`_bidx'], "%14.0g"))
                }
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
                quietly summarize _obs if perfmeascode == "`_code'" & `_bycond', meanonly
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
    local _truev  : char _dta[siman_true]
    if "`_method'" == "" {
        capture confirm variable method
        if !_rc local _method "method"
    }
    if "`_method'" == "" {
        display as error "siman ingest could not identify the method variable; use from(summary)"
        exit 459
    }
    * dgm() may be a varlist; use the first variable for the by dimension
    local _dgm1 : word 1 of `_dgm'

    * keep performance rows only
    quietly keep if !missing(`_codevar')
    quietly count
    if r(N) == 0 {
        display as error "no siman performance rows found; run `siman analyse' first"
        exit 459
    }

    * ----- standardized estimator labels/ords -----
    quietly gen str244 estlab = ""
    capture confirm string variable `_method'
    if !_rc quietly replace estlab = `_method'
    else {
        local _vl : value label `_method'
        if "`_vl'" != "" {
            tempvar _de
            quietly decode `_method', generate(`_de')
            quietly replace estlab = `_de'
        }
        else quietly replace estlab = strtrim(string(`_method', "%14.0g"))
    }
    quietly egen long estord = group(`_method')

    * ----- by (dgm) -----
    local _has_by = 0
    if "`_dgm1'" != "" {
        local _has_by = 1
        quietly gen str244 bylab = ""
        capture confirm string variable `_dgm1'
        if !_rc quietly replace bylab = `_dgm1'
        else {
            local _vl : value label `_dgm1'
            if "`_vl'" != "" {
                tempvar _db
                quietly decode `_dgm1', generate(`_db')
                quietly replace bylab = `_db'
            }
            else quietly replace bylab = strtrim(string(`_dgm1', "%14.0g"))
        }
        quietly egen long byord = group(`_dgm')
    }
    else {
        quietly gen str1 bylab = ""
        quietly gen byte byord = 1
    }

    * ----- estimand (target) -----
    local _has_emd = 0
    if "`_target'" != "" {
        local _has_emd = 1
        quietly gen str244 emdlab = ""
        capture confirm string variable `_target'
        if !_rc quietly replace emdlab = `_target'
        else {
            local _vl : value label `_target'
            if "`_vl'" != "" {
                tempvar _det
                quietly decode `_target', generate(`_det')
                quietly replace emdlab = `_det'
            }
            else quietly replace emdlab = strtrim(string(`_target', "%14.0g"))
        }
        quietly egen long emdord = group(`_target')
    }
    else {
        quietly gen str1 emdlab = ""
        quietly gen byte emdord = 1
    }

    * ----- true value -----
    quietly gen double truev = .
    if "`_truev'" != "" {
        capture confirm variable `_truev'
        if !_rc quietly replace truev = `_truev'
    }

    * ----- pivot siman codes to measure value (estimate) + mcse (se) columns -----
    local _codes  "estreps bias pctbias mean empse modelse relerror cover power mse rmse"
    local _tokens "n       bias pctbias mean empse meanse  relerr   coverage power mse rmse"
    local _nc : word count `_codes'
    forvalues _k = 1/`_nc' {
        local _code : word `_k' of `_codes'
        local _tok  : word `_k' of `_tokens'
        if "`_tok'" == "n" {
            quietly gen double n = estimate if `_codevar' == "`_code'"
        }
        else {
            quietly gen double m_`_tok'  = .
            quietly gen double mc_`_tok' = .
            if inlist("`_tok'", "coverage", "power") {
                quietly replace m_`_tok'  = estimate/100 if `_codevar' == "`_code'"
                quietly replace mc_`_tok' = se/100       if `_codevar' == "`_code'"
            }
            else {
                quietly replace m_`_tok'  = estimate if `_codevar' == "`_code'"
                quietly replace mc_`_tok' = se       if `_codevar' == "`_code'"
            }
        }
    }
    * meanse/relerr have no mcse slot in the standardized schema; drop the temps
    capture drop mc_meanse
    capture drop mc_relerr

    * ----- collapse to one row per cell (each measure non-missing in one row) -----
    tempvar _cellid
    local _cellvars `_method'
    if "`_dgm'" != ""    local _cellvars "`_cellvars' `_dgm'"
    if "`_target'" != "" local _cellvars "`_cellvars' `_target'"
    quietly egen long `_cellid' = group(`_cellvars')
    collapse (firstnm) estlab estord bylab byord emdlab emdord truev ///
        (max) n m_* mc_*, by(`_cellid')
    quietly drop `_cellid'

    local _by_header "DGM"
    if "`_dgm1'" != "" local _by_header "`_dgm1'"
    local _est_header "`_method'"
    return scalar has_by = `_has_by'
    return scalar has_emd = `_has_emd'
    return local by_header "`_by_header'"
    return local est_header "`_est_header'"
end
