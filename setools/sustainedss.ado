*! sustainedss Version 1.5.1  2026/07/19
*! Compute sustained EDSS progression date
*! Part of the setools package
*! Author: Timothy P Copeland, Karolinska Institutet

program define sustainedss, rclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    local _ss_preserved = 0
    set varabbrev off

    capture noisily {

    syntax varlist(min=3 max=3) [if] [in], ///
        THreshold(real) ///
        [ ///
        GENerate(name) ///
        CONFirmwindow(integer 182) ///
        CONFirmvisit(string) ///
        BASElinethreshold(real -1) ///
        EVENTvar(name) ///
        EXIT(varname) ///
        KEEPall ///
        Quietly ///
        ]
    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'
    
    // Validate variable types
    capture confirm numeric variable `edssvar'
    if _rc {
        di as error "`edssvar' must be numeric"
        exit 109
    }
    capture confirm numeric variable `datevar'
    if _rc {
        di as error "`datevar' must be numeric (Stata date format)"
        exit 109
    }
    local _sustainedss_date_fmt : format `datevar'
    if lower(substr("`_sustainedss_date_fmt'", 1, 3)) != "%td" {
        di as error "`datevar' must be a Stata daily date variable with %td format"
        exit 109
    }
    
    // Check threshold value
    if `threshold' <= 0 {
        di as error "threshold() must be positive"
        exit 198
    }

    if `confirmwindow' <= 0 {
        di as error "confirmwindow() must be positive"
        exit 198
    }

    if `baselinethreshold' == -1 {
        local baselinethreshold = `threshold'
    }
    else if `baselinethreshold' < 0 {
        di as error "baselinethreshold() must be non-negative"
        exit 198
    }

    local confirmvisit = lower(strtrim("`confirmvisit'"))
    if "`confirmvisit'" != "" & ///
        !inlist("`confirmvisit'", "window", "unlimited") {
        di as error "confirmvisit() must be window or unlimited"
        exit 198
    }

    if "`generate'" == "" {
        local _ss_threshold_name = ///
            strtrim(strofreal(`threshold', "%21.15g"))
        local _ss_threshold_name = ///
            subinstr("`_ss_threshold_name'", ".", "_", .)
        local _ss_threshold_name = ///
            subinstr("`_ss_threshold_name'", "-", "m", .)
        local _ss_threshold_name = ///
            subinstr("`_ss_threshold_name'", "+", "p", .)
        local generate "sustained`_ss_threshold_name'_dt"
        capture confirm name `generate'
        if _rc {
            di as error "threshold() cannot be encoded in a valid default name; specify generate()"
            exit 198
        }
    }

    local _ss_outputs "`generate' `eventvar'"
    local _ss_seen ""
    foreach _ss_out of local _ss_outputs {
        local _ss_out_lc = lower("`_ss_out'")
        if strpos(" `_ss_seen' ", " `_ss_out_lc' ") {
            di as error "prospective output variable names must be distinct: `_ss_out'"
            exit 198
        }
        local _ss_seen "`_ss_seen' `_ss_out_lc'"
        capture confirm new variable `_ss_out'
        if _rc {
            di as error "variable `_ss_out' already exists"
            exit 110
        }
    }

    marksample touse, strok
    capture confirm string variable `idvar'
    local id_is_str = (_rc == 0)
    if `id_is_str' {
        quietly replace `touse' = 0 if trim(`idvar') == "" & `touse'
    }
    else {
        markout `touse' `idvar'
    }
    qui count if `touse' & !missing(`datevar') & `datevar' != floor(`datevar')
    if r(N) > 0 {
        di as error "`datevar' must contain whole-number Stata daily dates"
        exit 109
    }

    local n_censored_exit = 0
    if "`exit'" != "" {
        capture confirm numeric variable `exit'
        if _rc {
            di as error "exit() must be a numeric Stata daily date variable"
            exit 109
        }
        local _ss_exit_fmt : format `exit'
        if lower(substr("`_ss_exit_fmt'", 1, 3)) != "%td" {
            di as error "exit() must be a Stata daily date variable with %td format"
            exit 109
        }
        qui count if `touse' & !missing(`exit') & `exit' != floor(`exit')
        if r(N) > 0 {
            di as error "exit() must contain whole-number Stata daily dates"
            exit 109
        }
    }

    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }
    qui count
    local n_original = r(N)
    tempvar sortorder exit_min exit_max candidate eligible minfollow minall ///
        nextdate nextedss accepted personorder
    tempfile original_full analytic persons results

    preserve
    local _ss_preserved = 1
    qui gen long `sortorder' = _n
    qui save `original_full', replace
    qui keep if `touse'
    local _ss_workvars "`idvar' `edssvar' `datevar' `exit' `sortorder'"
    local _ss_workvars : list uniq _ss_workvars
    qui keep `_ss_workvars'
    qui drop if missing(`edssvar') | missing(`datevar')
    qui count
    if r(N) == 0 {
        di as error "no valid observations after dropping missing values"
        exit 2000
    }

    if "`exit'" != "" {
        qui egen double `exit_min' = min(`exit'), by(`idvar')
        qui egen double `exit_max' = max(`exit'), by(`idvar')
        qui count if !missing(`exit_min') & `exit_min' != `exit_max'
        if r(N) > 0 {
            di as error "exit() must have at most one distinct nonmissing value per person"
            exit 459
        }
        qui replace `exit' = `exit_min'
    }

    qui bysort `idvar' (`sortorder'): gen long `personorder' = `sortorder'[1]
    qui save `analytic', replace
    local _ss_personvars "`idvar' `exit' `personorder'"
    local _ss_personvars : list uniq _ss_personvars
    qui keep `_ss_personvars'
    qui duplicates drop `idvar', force
    qui save `persons', replace

    * Same-date duplicates are reduced conservatively to the lowest EDSS.
    qui use `analytic', clear
    qui collapse (min) `edssvar', by(`idvar' `datevar')
    qui sort `idvar' `datevar'
    qui gen byte `eligible' = (`edssvar' >= `threshold')
    qui gen byte `accepted' = 0

    qui count
    local max_iterations = r(N) + 1
    local iteration = 1
    local finished = 0
    while !`finished' {
        if `iteration' > `max_iterations' {
            di as error "sustainedss failed to converge"
            exit 430
        }
        foreach _ss_work in `candidate' `minfollow' `minall' `nextdate' ///
            `nextedss' `accepted' {
            capture drop `_ss_work'
        }
        qui egen long `candidate' = ///
            min(cond(`eligible', `datevar', .)), by(`idvar')
        qui count if !missing(`candidate')
        if r(N) == 0 {
            qui gen byte `accepted' = 0
            local finished = 1
            continue
        }

        qui egen double `minfollow' = min(cond( ///
            `datevar' > `candidate' & ///
            `datevar' <= `candidate' + `confirmwindow', `edssvar', .)), ///
            by(`idvar')
        qui egen double `minall' = min(cond( ///
            `datevar' > `candidate', `edssvar', .)), by(`idvar')

        if "`confirmvisit'" == "unlimited" {
            qui egen long `nextdate' = min(cond( ///
                `datevar' > `candidate', `datevar', .)), by(`idvar')
        }
        else {
            qui egen long `nextdate' = min(cond( ///
                `datevar' > `candidate' & ///
                `datevar' <= `candidate' + `confirmwindow', `datevar', .)), ///
                by(`idvar')
        }
        qui egen double `nextedss' = min(cond( ///
            `datevar' == `nextdate', `edssvar', .)), by(`idvar')

        if "`confirmvisit'" == "" {
            * Package convention: no follow-up implies sustainment; observed
            * values anywhere in available follow-up must not fall below the
            * chosen floor.
            qui gen byte `accepted' = missing(`minall') | ///
                `minall' >= `baselinethreshold'
        }
        else if "`confirmvisit'" == "window" {
            qui gen byte `accepted' = !missing(`nextdate') & ///
                `nextedss' >= `threshold' & ///
                `minfollow' >= `baselinethreshold'
        }
        else {
            * Unlimited mode uses the first later assessment and therefore
            * cannot skip an intervening reversal to find a later high value.
            * All later observed values must also remain above the floor.
            qui gen byte `accepted' = !missing(`nextdate') & ///
                `nextedss' >= `threshold' & ///
                `minall' >= `baselinethreshold'
        }

        qui count if !`accepted' & !missing(`candidate') & ///
            `datevar' == `candidate'
        local n_rejected = r(N)
        if `n_rejected' == 0 {
            local finished = 1
        }
        else {
            qui replace `eligible' = 0 if !`accepted' & ///
                `datevar' == `candidate'
            local iteration = `iteration' + 1
        }
    }

    qui gen long `generate' = `candidate' if `accepted'
    qui keep `idvar' `generate'
    qui duplicates drop `idvar', force
    qui drop if missing(`generate')
    format `generate' %tdCCYY/NN/DD
    qui save `results', replace

    qui merge 1:1 `idvar' using `persons', nogen keep(3)
    if "`exit'" != "" {
        qui count if !missing(`generate') & !missing(`exit') & ///
            `generate' > `exit'
        local n_censored_exit = r(N)
        qui replace `generate' = . if !missing(`generate') & ///
            !missing(`exit') & `generate' > `exit'
    }
    qui count if !missing(`generate')
    local n_events = r(N)
    qui keep `idvar' `generate'
    qui save `results', replace

    qui use `original_full', clear
    if "`keepall'" == "" {
        qui merge m:1 `idvar' using `results', nogen keep(3)
    }
    else {
        qui merge m:1 `idvar' using `results', nogen
    }
    qui sort `sortorder'
    qui drop `sortorder'
    label var `generate' "Sustained EDSS >= `threshold' date"
    format `generate' %tdCCYY/NN/DD

    if "`eventvar'" != "" {
        qui gen byte `eventvar' = !missing(`generate') if `touse'
        label var `eventvar' "Sustained EDSS event (1 = threshold reached)"
    }

    qui count
    local n_retained = r(N)

    // Display results
    if "`quietly'" == "" {
        di as text _n "Sustained EDSS >= `threshold' computation complete"
        di as text "  Confirmation window: `confirmwindow' days"
        di as text "  Confirmation visit: " ///
            cond("`confirmvisit'" == "", "not required", "`confirmvisit'")
        di as text "  Baseline threshold: `baselinethreshold'"
        di as text "  Events identified: `n_events'"
        if "`exit'" != "" {
            di as text "  Events censored after study exit: `n_censored_exit'"
        }
        di as text "  Iterations required: `iteration'"
        di as text "  Variable created: `generate'"
        if "`keepall'" == "" & `n_retained' < `n_original' {
            di as text "  Observations: `n_retained' of `n_original' retained" ///
                " (use {bf:keepall} to keep all)"
        }
    }
    
    restore, not
    local _ss_preserved = 0

    return scalar N_events = `n_events'
    return scalar iterations = `iteration'
    return scalar converged = 1
    return scalar threshold = `threshold'
    return scalar confirmwindow = `confirmwindow'
    return local varname "`generate'"
    return local confirmvisit "`confirmvisit'"
    if "`eventvar'" != "" {
        return local eventvar "`eventvar'"
    }
    if "`exit'" != "" {
        return local exit "`exit'"
        return scalar N_censored_exit = `n_censored_exit'
    }

    }
    local _rc = _rc
    if `_rc' & `_ss_preserved' {
        capture restore
    }
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
