*! cdp Version 1.5.1  2026/07/19
*! Confirmed Disability Progression from baseline EDSS
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Confirmed Disability Progression (CDP) Algorithm:

1. Baseline EDSS: First measurement within baselinewindow of diagnosis date
   (or earliest available if none within window)
2. Progression threshold (two-tier default; threetier for Lublin/Kappos rule):
   - two-tier:  ≥1.0 if baseline ≤5.5, ≥0.5 if baseline >5.5
   - threetier: ≥1.5 if baseline 0, ≥1.0 if 1.0-5.5, ≥0.5 if >5.5
3. Confirmation (confirmtype): sustained (min of all later EDSS, default) or
   visit (EDSS at the first measurement ≥confirmdays later)

Basic syntax:
  cdp idvar edssvar datevar, dxdate(varname) [options]

Required:
  dxdate(varname)      - Diagnosis date variable

Options:
  generate(name)       - Name for CDP date variable (default: cdp_date)
  confirmdays(#)       - Days for confirmation (default: 180 = 6 months)
  confirmtype(type)    - sustained (default) or visit
  baselinewindow(#)    - Days from diagnosis for baseline EDSS (default: 730 = 24 months)
  threetier            - Use the three-tier progression threshold (default two-tier)
  eventvar(name)       - Create a 0/1 stset-ready CDP event indicator
  roving               - Use roving baseline (reset after each confirmed progression)
  allevents            - Track all CDP events, not just first
  keepall              - Retain all observations (default: keep only those with CDP)
  quietly              - Suppress output messages

See help cdp for complete documentation
*/

program define cdp, rclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    local _cdp_preserved = 0
    set varabbrev off

    capture noisily {

    syntax varlist(min=3 max=3) [if] [in], ///
        DXdate(varname) ///
        [ ///
        GENerate(name) ///
        CONFirmdays(integer 180) ///
        BASElinewindow(integer 730) ///
        THREEtier ///
        CONFIRMType(string) ///
        EVENTvar(name) ///
        EVENTNUMvar(name) ///
        BASEEDSSvar(name) ///
        EXIT(varname) ///
        ROVING ///
        ALLevents ///
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
    local _cdp_date_fmt : format `datevar'
    if lower(substr("`_cdp_date_fmt'", 1, 3)) != "%td" {
        di as error "`datevar' must be a Stata daily date variable with %td format"
        exit 109
    }
    capture confirm numeric variable `dxdate'
    if _rc {
        di as error "`dxdate' must be numeric (Stata date format)"
        exit 109
    }
    local _cdp_dx_fmt : format `dxdate'
    if lower(substr("`_cdp_dx_fmt'", 1, 3)) != "%td" {
        di as error "`dxdate' must be a Stata daily date variable with %td format"
        exit 109
    }

    if `confirmdays' <= 0 {
        di as error "confirmdays() must be positive"
        exit 198
    }
    if `baselinewindow' <= 0 {
        di as error "baselinewindow() must be positive"
        exit 198
    }

    if "`allevents'" != "" & "`roving'" == "" {
        di as error "allevents requires roving"
        exit 198
    }
    if ("`eventnumvar'" != "" | "`baseedssvar'" != "") & ///
        !("`roving'" != "" & "`allevents'" != "") {
        di as error "eventnumvar() and baseedssvar() require roving allevents"
        exit 198
    }

    // Confirmation type
    if "`confirmtype'" == "" {
        local confirmtype "sustained"
    }
    local confirmtype = lower("`confirmtype'")
    if !inlist("`confirmtype'", "sustained", "visit") {
        di as error "confirmtype() must be sustained or visit"
        exit 198
    }

    if "`generate'" == "" {
        local generate "cdp_date"
    }
    if "`roving'" != "" & "`allevents'" != "" {
        if "`eventnumvar'" == "" local eventnumvar "event_num"
        if "`baseedssvar'" == "" local baseedssvar "baseline_edss_at_event"
    }

    * Preflight the complete public output set before any mutation.
    local _cdp_outputs "`generate' `eventvar' `eventnumvar' `baseedssvar'"
    local _cdp_seen ""
    foreach _cdp_out of local _cdp_outputs {
        local _cdp_out_lc = lower("`_cdp_out'")
        if strpos(" `_cdp_seen' ", " `_cdp_out_lc' ") {
            di as error "prospective output variable names must be distinct: `_cdp_out'"
            exit 198
        }
        local _cdp_seen "`_cdp_seen' `_cdp_out_lc'"
        capture confirm new variable `_cdp_out'
        if _rc {
            di as error "variable `_cdp_out' already exists"
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
    qui count if `touse' & !missing(`dxdate') & `dxdate' != floor(`dxdate')
    if r(N) > 0 {
        di as error "`dxdate' must contain whole-number Stata daily dates"
        exit 109
    }

    local n_censored_exit = 0
    if "`exit'" != "" {
        capture confirm numeric variable `exit'
        if _rc {
            di as error "exit() must be a numeric Stata daily date variable"
            exit 109
        }
        local _cdp_exit_fmt : format `exit'
        if lower(substr("`_cdp_exit_fmt'", 1, 3)) != "%td" {
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

    tempvar baseline_edss baseline_date sortorder personorder ///
        dx_min dx_max exit_min exit_max eventnum_internal ///
        baseevent_internal core_base core_confdate core_confedss idtag
    tempfile original_full analytic persons working results results_all

    * The preserved caller dataset remains available until the final result is
    * fully assembled.  Any later error restores it byte-for-byte.
    preserve
    local _cdp_preserved = 1
    qui gen long `sortorder' = _n
    qui save `original_full', replace

    qui keep if `touse'
    local _cdp_workvars "`idvar' `edssvar' `datevar' `dxdate' `exit' `sortorder'"
    local _cdp_workvars : list uniq _cdp_workvars
    qui keep `_cdp_workvars'
    qui drop if missing(`edssvar') | missing(`datevar')
    qui count
    if r(N) == 0 {
        di as error "no valid observations after dropping missing values"
        exit 2000
    }

    * dxdate() is person-level. Mixed missing/nonmissing rows are accepted and
    * normalized to the unique nonmissing value; conflicting values are not.
    qui egen double `dx_min' = min(`dxdate'), by(`idvar')
    qui egen double `dx_max' = max(`dxdate'), by(`idvar')
    qui count if !missing(`dx_min') & `dx_min' != `dx_max'
    if r(N) > 0 {
        di as error "dxdate() must have at most one distinct nonmissing value per person"
        exit 459
    }
    qui replace `dxdate' = `dx_min'
    qui drop if missing(`dxdate')
    qui count
    if r(N) == 0 {
        di as error "no valid observations with a person-level diagnosis date"
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
    local _cdp_personvars "`idvar' `dxdate' `exit' `personorder'"
    local _cdp_personvars : list uniq _cdp_personvars
    qui keep `_cdp_personvars'
    qui duplicates drop `idvar', force
    qui save `persons', replace

    qui use `analytic', clear
    qui sort `idvar' `datevar' `edssvar'
    _setools_cdp_baseline `idvar' `edssvar' `datevar', dxdate(`dxdate') ///
        baselinewindow(`baselinewindow') edssout(`baseline_edss') dateout(`baseline_date')

    if !("`roving'" != "" & "`allevents'" != "") {
        * Roving without allevents is deliberately the identical first-event
        * estimand and therefore uses the same retry engine.
        _setools_cdp_core `idvar' `edssvar' `datevar', ///
            baseedss(`baseline_edss') basedate(`baseline_date') ///
            confirmdays(`confirmdays') genname(`generate') ///
            `threetier' confirmtype("`confirmtype'")
        local cdp_converged  = r(converged)
        local cdp_iterations = r(iterations)
        qui save `results', replace
    }
    else {
        qui save `working', replace
        local _cdp_id_type : type `idvar'
        clear
        if `id_is_str' {
            qui gen `_cdp_id_type' `idvar' = ""
        }
        else {
            qui gen `_cdp_id_type' `idvar' = .
        }
        qui gen long `generate' = .
        qui gen long `eventnum_internal' = .
        qui gen double `baseevent_internal' = .
        qui save `results_all', replace emptyok

        qui use `working', clear
        qui count
        local max_roving_iter = r(N) + 1
        local event_counter = 1
        local cdp_iterations = 0
        local keep_going = 1
        while `keep_going' {
            if `event_counter' > `max_roving_iter' {
                di as error "roving CDP failed to converge"
                exit 430
            }
            qui use `working', clear
            _setools_cdp_core `idvar' `edssvar' `datevar', ///
                baseedss(`baseline_edss') basedate(`baseline_date') ///
                confirmdays(`confirmdays') genname(`generate') ///
                baseout(`core_base') confdate(`core_confdate') ///
                confedss(`core_confedss') `threetier' ///
                confirmtype("`confirmtype'")
            local cdp_iterations = `cdp_iterations' + r(iterations)
            qui count
            local n_new = r(N)
            if `n_new' == 0 {
                local keep_going = 0
                continue
            }

            tempfile new_events append_events
            qui gen long `eventnum_internal' = `event_counter'
            qui save `new_events', replace

            qui keep `idvar' `generate' `eventnum_internal' `core_base'
            qui rename `core_base' `baseevent_internal'
            qui save `append_events', replace
            qui use `results_all', clear
            qui append using `append_events'
            qui save `results_all', replace

            * Only IDs that just confirmed can have a new roving baseline.
            * Reset at the actual confirming assessment and discard all visits
            * through that date, including intervening dips and same-day ties.
            qui use `working', clear
            qui merge m:1 `idvar' using `new_events', nogen keep(3)
            qui drop if `datevar' <= `core_confdate'
            qui replace `baseline_edss' = `core_confedss'
            qui replace `baseline_date' = `core_confdate'
            qui drop `generate' `eventnum_internal' `core_base' ///
                `core_confdate' `core_confedss'
            qui count
            if r(N) == 0 {
                local keep_going = 0
            }
            else {
                qui save `working', replace
                local event_counter = `event_counter' + 1
            }
        }
        local cdp_converged = 1
        qui use `results_all', clear
        qui save `results', replace
    }

    * Apply person-level exit censoring before attaching results to any
    * measurement rows.
    if !("`roving'" != "" & "`allevents'" != "") {
        qui use `results', clear
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
        local n_persons = `n_events'
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
        label var `generate' "Confirmed disability progression date"
        format `generate' %tdCCYY/NN/DD
        if "`eventvar'" != "" {
            qui gen byte `eventvar' = !missing(`generate') if `touse'
            label var `eventvar' "CDP event (1 = confirmed progression)"
        }
    }
    else {
        if "`quietly'" == "" {
            di as text "Note: allevents reshapes data to event-level (one row per CDP event)"
        }
        qui use `persons', clear
        if "`keepall'" == "" {
            qui merge 1:m `idvar' using `results', nogen keep(3)
        }
        else {
            qui merge 1:m `idvar' using `results', nogen
        }
        if "`exit'" != "" {
            qui count if !missing(`generate') & !missing(`exit') & `generate' > `exit'
            local n_censored_exit = r(N)
            qui replace `generate' = . if !missing(`generate') & !missing(`exit') & `generate' > `exit'
        }
        qui count if !missing(`generate')
        local n_events = r(N)
        qui egen byte `idtag' = tag(`idvar') if !missing(`generate')
        qui count if `idtag'
        local n_persons = r(N)
        qui drop `idtag'
        qui sort `personorder' `eventnum_internal'
        qui drop `personorder'
        qui rename `eventnum_internal' `eventnumvar'
        qui rename `baseevent_internal' `baseedssvar'
        format `generate' %tdCCYY/NN/DD
        label var `generate' "Confirmed disability progression date"
        label var `eventnumvar' "CDP event number"
        label var `baseedssvar' "Baseline EDSS at CDP event"
        if "`eventvar'" != "" {
            qui gen byte `eventvar' = !missing(`generate')
            label var `eventvar' "CDP event (1 = confirmed progression)"
        }
    }

    if "`quietly'" == "" {
        di as text _n "Confirmed Disability Progression (CDP) complete"
        di as text "  Baseline window: `baselinewindow' days from diagnosis"
        di as text "  Confirmation period: `confirmdays' days"
        di as text "  Confirmation type: `confirmtype'"
        di as text "  Threshold rule: " cond("`threetier'" != "", "three-tier", "two-tier")
        di as text "  Roving baseline: " cond("`roving'" != "", "Yes", "No")
        di as text "  Persons with CDP: `n_persons'"
        if "`allevents'" != "" & "`roving'" != "" {
            di as text "  Total CDP events: `n_events'"
        }
        if "`exit'" != "" {
            di as text "  Events censored after study exit: `n_censored_exit'"
        }
        di as text "  Variable created: `generate'"
        if "`eventvar'" != "" {
            di as text "  Event indicator: `eventvar'"
        }
        if `cdp_converged' == 0 {
            di as text "  Note: confirmation did not converge (results may be approximate)"
        }
    }

    restore, not
    local _cdp_preserved = 0

    return scalar N_persons = `n_persons'
    return scalar N_events = `n_events'
    return scalar confirmdays = `confirmdays'
    return scalar baselinewindow = `baselinewindow'
    return scalar converged = `cdp_converged'
    return local varname "`generate'"
    return local confirmtype "`confirmtype'"
    return local threetier = cond("`threetier'" != "", "yes", "no")
    return local roving = cond("`roving'" != "", "yes", "no")
    if "`eventvar'" != "" {
        return local eventvar "`eventvar'"
    }
    if "`eventnumvar'" != "" {
        return local eventnumvar "`eventnumvar'"
    }
    if "`baseedssvar'" != "" {
        return local baseedssvar "`baseedssvar'"
    }
    if "`exit'" != "" {
        return local exit "`exit'"
        return scalar N_censored_exit = `n_censored_exit'
    }

    }
    local _rc = _rc
    if `_rc' & `_cdp_preserved' {
        capture restore
    }
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
