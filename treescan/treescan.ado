*! treescan Version 1.3.5  2026/02/28
*! Tree-based scan statistic for signal detection
*! Implements Kulldorff et al. (2003) Bernoulli and Poisson models (unconditional and conditional)
*! Author: Tim Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

/*
Syntax:
  treescan diagvar [using treefile.dta], id(varname) exposed(varname)
      [icdversion(cm|se|atc) model(bernoulli|poisson) persontime(varname)
       CONDitional EVENTDate(varname) EXPDate(varname) WINDow(numlist)
       WINDOWScope(string) nsim(integer 999) alpha(real 0.05)
       seed(integer) noisily]

Required:
  diagvar           - Variable containing diagnosis/classification codes (leaf nodes)
  id(varname)       - Person/unit identifier
  exposed(varname)  - Binary exposure/case variable (0/1)

Either icdversion() or using must be specified to provide the tree hierarchy.
Does not accept if/in qualifiers; subset data before calling.

See help treescan for complete documentation.
*/

program define treescan, rclass
    version 16.0
    set varabbrev off
    set more off

    * =====================================================================
    * SYNTAX PARSING
    * =====================================================================
    syntax varlist(min=1 max=1 string) [using/], ///
        ID(varname) EXPosed(varname) ///
        [ICDVersion(string) MODel(string) PERSONTime(varname) ///
         CONDitional EVENTDate(varname) EXPDate(varname) ///
         WINDow(numlist) WINDOWScope(string) ///
         NSIM(integer 999) ALPHa(real 0.05) ///
         SEED(integer -1) NOIsily]

    local diagvar `varlist'
    local treefile `"`using'"'

    * =====================================================================
    * VALIDATE INPUTS
    * =====================================================================

    * Check for reserved variable name collision
    * The tree expansion creates an internal "node" variable; user variables
    * with this name would collide at multiple levels (merge, egen group)
    if "`id'" == "node" | "`exposed'" == "node" | "`persontime'" == "node" {
        display as error ///
            "id(), exposed(), and persontime() variables cannot be named {bf:node}"
        display as error ///
            "rename the variable before calling treescan (e.g., {bf:rename node myid})"
        exit 198
    }

    * Check exposed is binary
    capture assert inlist(`exposed', 0, 1) | missing(`exposed')
    if _rc {
        display as error "exposed() must be a binary (0/1) variable"
        exit 198
    }

    * Check nsim is positive
    if `nsim' < 1 {
        display as error "nsim() must be a positive integer"
        exit 198
    }

    * Check alpha is in (0, 1)
    if `alpha' <= 0 | `alpha' >= 1 {
        display as error "alpha() must be between 0 and 1"
        exit 198
    }

    * Need either icdversion or using
    if `"`treefile'"' == "" & `"`icdversion'"' == "" {
        display as error "must specify either {bf:icdversion()} or {bf:using}"
        exit 198
    }
    if `"`treefile'"' != "" & `"`icdversion'"' != "" {
        display as error "cannot specify both {bf:icdversion()} and {bf:using}"
        exit 198
    }

    * Validate icdversion
    if `"`icdversion'"' != "" {
        local icdversion = lower(`"`icdversion'"')
        if !inlist(`"`icdversion'"', "cm", "se", "atc") {
            display as error "icdversion() must be {bf:cm}, {bf:se}, or {bf:atc}"
            exit 198
        }
    }

    * Validate model
    if `"`model'"' == "" {
        local model "bernoulli"
    }
    else {
        local model = lower(`"`model'"')
        if !inlist(`"`model'"', "bernoulli", "poisson") {
            display as error "model() must be {bf:bernoulli} or {bf:poisson}"
            exit 198
        }
    }

    * Poisson requires persontime
    if "`model'" == "poisson" & "`persontime'" == "" {
        display as error "persontime() is required when model(poisson) is specified"
        exit 198
    }
    if "`model'" == "bernoulli" & "`persontime'" != "" {
        display as error "persontime() is not allowed with model(bernoulli)"
        exit 198
    }

    * Validate persontime if specified
    if "`persontime'" != "" {
        capture assert `persontime' > 0 if !missing(`persontime')
        if _rc {
            display as error "persontime() must be positive"
            exit 198
        }
    }

    * Validate temporal scan window options
    local has_temporal = 0
    if "`eventdate'" != "" | "`expdate'" != "" | "`window'" != "" {
        local has_temporal = 1
        if "`eventdate'" == "" | "`expdate'" == "" | "`window'" == "" {
            display as error ///
                "eventdate(), expdate(), and window() must all be specified together"
            exit 198
        }

        * Parse window numlist: exactly 2 values
        local nwindow : word count `window'
        if `nwindow' != 2 {
            display as error "window() requires exactly 2 values (lower upper)"
            exit 198
        }
        local window_lo : word 1 of `window'
        local window_hi : word 2 of `window'
        if `window_lo' > `window_hi' {
            display as error "window() lower bound must be <= upper bound"
            exit 198
        }

        * Validate windowscope
        if "`windowscope'" == "" {
            local windowscope "exposed"
        }
        else {
            local windowscope = lower("`windowscope'")
            if !inlist("`windowscope'", "exposed", "all") {
                display as error "windowscope() must be {bf:exposed} or {bf:all}"
                exit 198
            }
        }
    }

    * Set seed if specified
    if `seed' >= 0 {
        set seed `seed'
    }

    * Tempnames for simulation matrices (avoids global name collisions)
    tempname _sim_maxllr _pmax

    * Ensure Mata library is available
    capture mata: mata which _treescan_mc_bernoulli()
    if _rc {
        quietly capture mata: mata mlib index
        capture mata: mata which _treescan_mc_bernoulli()
        if _rc {
            display as error "treescan Mata library (ltreescan.mlib) not found"
            exit 601
        }
    }

    * =====================================================================
    * RESOLVE TREE FILE
    * =====================================================================
    if `"`treefile'"' == "" {
        * Find built-in tree relative to the .ado file location
        * Use findfile which searches along adopath
        if "`icdversion'" == "cm" {
            capture findfile icd10cm_tree.dta
            if _rc {
                display as error "built-in ICD-10-CM tree not found"
                display as error "file icd10cm_tree.dta not on adopath"
                exit 601
            }
            local treefile "`r(fn)'"
        }
        else if "`icdversion'" == "se" {
            capture findfile icd10se_tree.dta
            if _rc {
                display as error "built-in ICD-10-SE tree not found"
                display as error "file icd10se_tree.dta not on adopath"
                exit 601
            }
            local treefile "`r(fn)'"
        }
        else if "`icdversion'" == "atc" {
            capture findfile atc_tree.dta
            if _rc {
                display as error "built-in ATC tree not found"
                display as error "file atc_tree.dta not on adopath"
                exit 601
            }
            local treefile "`r(fn)'"
        }
    }

    * Verify tree file exists
    capture confirm file `"`treefile'"'
    if _rc {
        display as error `"tree file not found: `treefile'"'
        exit 601
    }

    * =====================================================================
    * PRESERVE AND PREPARE DATA
    * =====================================================================
    preserve

    * Keep only relevant variables and non-missing observations
    quietly {
        if "`model'" == "poisson" {
            if `has_temporal' {
                keep `diagvar' `id' `exposed' `persontime' `eventdate' `expdate'
                drop if missing(`diagvar') | missing(`id') | missing(`exposed') | missing(`persontime') | missing(`eventdate') | missing(`expdate')
            }
            else {
                keep `diagvar' `id' `exposed' `persontime'
                drop if missing(`diagvar') | missing(`id') | missing(`exposed') | missing(`persontime')
            }
        }
        else {
            if `has_temporal' {
                keep `diagvar' `id' `exposed' `eventdate' `expdate'
                drop if missing(`diagvar') | missing(`id') | missing(`exposed') | missing(`eventdate') | missing(`expdate')
            }
            else {
                keep `diagvar' `id' `exposed'
                drop if missing(`diagvar') | missing(`id') | missing(`exposed')
            }
        }
        count
        local N_obs = r(N)
        if `N_obs' == 0 {
            noisily display as error "no observations"
            exit 2000
        }

        * Apply temporal scan window filter
        if `has_temporal' {
            tempvar _days
            gen double `_days' = `eventdate' - `expdate'

            if "`windowscope'" == "exposed" {
                drop if `exposed' == 1 & ///
                    (`_days' < `window_lo' | `_days' > `window_hi')
            }
            else {
                drop if `_days' < `window_lo' | `_days' > `window_hi'
            }
            drop `_days'

            count
            local N_obs = r(N)
            if `N_obs' == 0 {
                noisily display as error ///
                    "no observations within the specified time window"
                exit 2000
            }
            drop `eventdate' `expdate'
        }

        * Compute global parameters
        tempfile inputdata
        save `inputdata'

        * Check for mixed exposure within individuals (before collapse)
        tempvar _mixed
        bysort `id' (`exposed'): gen byte `_mixed' = ///
            (_n == 1) & (`exposed'[1] != `exposed'[_N])
        quietly count if `_mixed' == 1
        local n_mixed = r(N)
        drop `_mixed'
        if `n_mixed' > 0 {
            noisily display as text ///
                "Note: `n_mixed' individuals have mixed exposure values;" ///
                " using max (ever exposed = exposed)"
        }

        * Get unique individuals and their exposure status
        * Use max to handle any mixed exposure (ever exposed = exposed)
        if "`model'" == "poisson" {
            collapse (max) `exposed' (max) `persontime', by(`id')
        }
        else {
            collapse (max) `exposed', by(`id')
        }

        count
        local N_individuals = r(N)
        count if `exposed' == 1
        local N_exposed = r(N)
        local N_unexposed = `N_individuals' - `N_exposed'

        if `N_exposed' == 0 {
            noisily display as error "no exposed individuals"
            exit 2000
        }
        if `N_unexposed' == 0 {
            noisily display as error "no unexposed individuals"
            exit 2000
        }

        if "`model'" == "bernoulli" {
            local p = `N_exposed' / `N_individuals'
        }
        else {
            * Poisson: compute global rate
            summarize `exposed', meanonly
            local C = r(sum)
            summarize `persontime', meanonly
            local T_total = r(sum)
            local lambda = `C' / `T_total'
        }

        * Save individual-level data for Monte Carlo resampling
        if "`model'" == "poisson" {
            keep `id' `exposed' `persontime'
        }
        else {
            keep `id' `exposed'
        }
        tempfile individuals
        save `individuals'
    }

    * =====================================================================
    * LOAD TREE AND CUT: Expand observations to all ancestor nodes
    * =====================================================================
    if "`noisily'" != "" {
        display as text "Loading tree and mapping codes to ancestors..."
    }

    quietly {
        local _ptopt ""
        if "`model'" == "poisson" {
            local _ptopt "persontime(`persontime')"
        }
        _treescan_cut_tree, inputdata(`inputdata') ///
            treefile(`"`treefile'"') diagvar(`diagvar') ///
            id(`id') exposed(`exposed') model(`model') ///
            `_ptopt' individuals(`individuals')

        * Update N_obs from cut tree (accounts for codes not in tree)
        local N_obs = `_treescan_n_matched'

        * Recompute individual-level totals from the cut tree
        * (some individuals may have lost all codes during tree-matching)
        tempvar _tag_id
        egen byte `_tag_id' = tag(`id')
        count if `_tag_id' == 1
        local N_individuals = r(N)
        count if `_tag_id' == 1 & `exposed' == 1
        local N_exposed = r(N)
        local N_unexposed = `N_individuals' - `N_exposed'
        drop `_tag_id'

        if `N_exposed' == 0 {
            noisily display as error "no exposed individuals after tree matching"
            exit 2000
        }
        if `N_unexposed' == 0 {
            noisily display as error "no unexposed individuals after tree matching"
            exit 2000
        }

        if "`model'" == "bernoulli" {
            local p = `N_exposed' / `N_individuals'
        }
        else {
            * Recompute Poisson totals from matched individuals
            tempvar _pt_tag
            bysort `id': gen byte `_pt_tag' = (_n == 1)
            summarize `exposed' if `_pt_tag' == 1, meanonly
            local C = r(sum)
            summarize `persontime' if `_pt_tag' == 1, meanonly
            local T_total = r(sum)
            local lambda = `C' / `T_total'
            drop `_pt_tag'
        }

        * Save the cut tree
        tempfile cuttree
        save `cuttree'
    }

    * =====================================================================
    * COMPUTE OBSERVED COUNTS AND LLR AT EACH NODE
    * =====================================================================
    if "`noisily'" != "" {
        display as text "Computing observed LLR..."
    }

    quietly {
        use `cuttree', clear

        if "`model'" == "bernoulli" {
            * Collapse to node-level counts
            tempvar _n1 _n0
            gen byte `_n1' = (`exposed' == 1)
            gen byte `_n0' = (`exposed' == 0)
            collapse (sum) n1=`_n1' n0=`_n0', by(node)

            * Total at each node
            gen double n_total = n0 + n1

            * Compute LLR (Bernoulli unconditional)
            gen double q1 = n1 / n_total
            gen double llr = 0

            * Compute LLR only where there's excess risk (q1 > p)
            gen double lla = cond(n1 > 0, n1 * ln(q1), 0) + ///
                             cond(n0 > 0, n0 * ln(1 - q1), 0)
            gen double ll0 = n1 * ln(`p') + n0 * ln(1 - `p')
            replace llr = lla - ll0 if q1 > `p'

            drop lla ll0 q1 n_total
        }
        else {
            * Poisson unconditional model
            tempvar _case
            gen byte `_case' = (`exposed' == 1)
            collapse (sum) c=`_case' T_node=`persontime', by(node)

            * Expected cases at each node
            gen double E = T_node * (`C' / `T_total')

            * LLR: c*ln(c/E) + (C-c)*ln((C-c)/(C-E)) when c > E
            gen double llr = 0
            replace llr = cond(c > 0, c * ln(c / E), 0) + ///
                cond(`C' - c > 0, (`C' - c) * ln((`C' - c) / (`C' - E)), 0) ///
                if c > E

            drop E
        }

        * Count nodes evaluated
        count
        local N_nodes = r(N)

        * Find observed maximum LLR
        summarize llr, meanonly
        local obs_max_llr = r(max)

        * Save observed results
        if "`model'" == "bernoulli" {
            keep node n0 n1 llr
        }
        else {
            keep node c T_node llr
        }
        tempfile obs_results
        save `obs_results'
    }

    * =====================================================================
    * MONTE CARLO SIMULATION + P-VALUES (Mata)
    * =====================================================================
    if "`noisily'" != "" {
        display as text "Running Monte Carlo simulation (`nsim' iterations)..."
    }

    quietly {
        * Load cut tree into memory for Mata
        use `cuttree', clear

        * Create numeric individual index for Mata
        * Map id -> sequential integer 1..N_individuals
        tempvar _id_idx
        egen long `_id_idx' = group(`id')

        * Sort by node for building membership index
        sort node `_id_idx'

        if "`model'" == "bernoulli" {
            mata: _treescan_mc_bernoulli(`N_individuals', `N_exposed', ///
                `p', `nsim', ("`conditional'" != ""), ///
                ("`noisily'" != ""), "`_id_idx'", "`exposed'", ///
                "`_sim_maxllr'")
        }
        else {
            * Note: p_case = C/N_individuals is the per-individual case
            * probability for null resampling. This differs from the rate
            * C/T_total used in the expected count formula (E = T_node * C/T_total).
            * Both are correct: p_case generates case labels, the rate computes E.
            mata: _treescan_mc_poisson(`N_individuals', `C', ///
                `C' / `N_individuals', `nsim', ("`conditional'" != ""), ///
                ("`noisily'" != ""), "`_id_idx'", "`exposed'", ///
                "`persontime'", `T_total', "`_sim_maxllr'")
        }

        * Compute p-values: load observed results and use Mata
        use `obs_results', clear
        gen double pvalue = .

        mata: _treescan_pvalues(`nsim', `obs_max_llr', ///
            "`_sim_maxllr'", "`_pmax'")

        * Read back overall p-value from Mata
        local p_max = `_pmax'[1, 1]
        matrix drop `_pmax'
        matrix drop `_sim_maxllr'

        * Sort by LLR descending
        gsort -llr

        * Save all results
        tempfile allresults
        save `allresults'
    }

    * =====================================================================
    * BUILD RESULTS MATRIX (significant nodes only)
    * =====================================================================
    quietly {
        use `allresults', clear

        * Count significant nodes
        count if pvalue < `alpha'
        local n_sig = r(N)

        * Build results matrix
        if `n_sig' > 0 {
            keep if pvalue < `alpha'
            gsort -llr

            if "`model'" == "bernoulli" {
                * Create matrix: node label | n0 | n1 | LLR | p-value
                local nrows = _N
                tempname results_mat
                matrix `results_mat' = J(`nrows', 4, .)

                forvalues i = 1/`nrows' {
                    matrix `results_mat'[`i', 1] = n0[`i']
                    matrix `results_mat'[`i', 2] = n1[`i']
                    matrix `results_mat'[`i', 3] = llr[`i']
                    matrix `results_mat'[`i', 4] = pvalue[`i']
                }

                * Add row and column names
                local rnames ""
                forvalues i = 1/`nrows' {
                    local nd = node[`i']
                    local rnames `"`rnames' "`nd'""'
                }
                matrix rownames `results_mat' = `rnames'
                matrix colnames `results_mat' = n0 n1 LLR pvalue
            }
            else {
                * Poisson: cases | person-time | LLR | p-value
                local nrows = _N
                tempname results_mat
                matrix `results_mat' = J(`nrows', 4, .)

                forvalues i = 1/`nrows' {
                    matrix `results_mat'[`i', 1] = c[`i']
                    matrix `results_mat'[`i', 2] = T_node[`i']
                    matrix `results_mat'[`i', 3] = llr[`i']
                    matrix `results_mat'[`i', 4] = pvalue[`i']
                }

                local rnames ""
                forvalues i = 1/`nrows' {
                    local nd = node[`i']
                    local rnames `"`rnames' "`nd'""'
                }
                matrix rownames `results_mat' = `rnames'
                matrix colnames `results_mat' = cases persontime LLR pvalue
            }
        }
    }

    * =====================================================================
    * DISPLAY RESULTS
    * =====================================================================
    restore

    display as text ""
    display as text "{hline 70}"
    local cond_label = cond("`conditional'" != "", "Conditional", "Unconditional")
    if "`model'" == "bernoulli" {
        display as text "Tree-Based Scan Statistic (Bernoulli `cond_label')"
    }
    else {
        display as text "Tree-Based Scan Statistic (Poisson `cond_label')"
    }
    display as text "{hline 70}"
    display as text ""
    display as text "Individuals:     " as result %10.0fc `N_individuals'
    if "`model'" == "bernoulli" {
        display as text "  Exposed:       " as result %10.0fc `N_exposed'
        display as text "  Unexposed:     " as result %10.0fc `N_unexposed'
        display as text "p (exposed):     " as result %10.6f `p'
    }
    else {
        display as text "  Cases:         " as result %10.0fc `C'
        display as text "  Non-cases:     " as result %10.0fc `N_individuals' - `C'
        display as text "Person-time:     " as result %10.2f `T_total'
        display as text "Rate (C/T):      " as result %10.6f `lambda'
    }
    if `has_temporal' {
        display as text ""
        display as text "Time window:     " as result ///
            %5.0f `window_lo' as text " to " as result %5.0f `window_hi' as text " days"
        display as text "Window scope:    " as result "`windowscope'"
    }
    display as text ""
    display as text "Tree nodes:      " as result %10.0fc `N_nodes'
    display as text "Simulations:     " as result %10.0fc `nsim'
    if `seed' >= 0 {
        display as text "Seed:            " as result %10.0fc `seed'
    }
    display as text ""
    display as text "Max observed LLR:" as result %10.4f `obs_max_llr'
    display as text "p-value (max):   " as result %10.4f `p_max'
    display as text ""

    if `n_sig' > 0 {
        display as text "{hline 70}"
        display as text "Significant nodes (alpha = " as result %4.2f `alpha' as text ")"
        display as text "{hline 70}"

        if "`model'" == "bernoulli" {
            display as text %~10s "Node" _col(15) %~10s "Unexposed" ///
                _col(30) %~10s "Exposed" _col(43) %~8s "LLR" _col(55) %~10s "p-value"
        }
        else {
            display as text %~10s "Node" _col(15) %~10s "Cases" ///
                _col(30) %~10s "Person-time" _col(43) %~8s "LLR" _col(55) %~10s "p-value"
        }
        display as text "{hline 70}"

        local nrows = rowsof(`results_mat')
        forvalues i = 1/`nrows' {
            * Get row name (node code)
            local nd : word `i' of `rnames'
            local c1_i = `results_mat'[`i', 1]
            local c2_i = `results_mat'[`i', 2]
            local llr_i = `results_mat'[`i', 3]
            local pv_i = `results_mat'[`i', 4]

            if "`model'" == "bernoulli" {
                display as text %10s "`nd'" _col(15) as result %10.0fc `c1_i' ///
                    _col(30) as result %10.0fc `c2_i' ///
                    _col(43) as result %8.4f `llr_i' ///
                    _col(55) as result %10.4f `pv_i'
            }
            else {
                display as text %10s "`nd'" _col(15) as result %10.0fc `c1_i' ///
                    _col(30) as result %10.2f `c2_i' ///
                    _col(43) as result %8.4f `llr_i' ///
                    _col(55) as result %10.4f `pv_i'
            }
        }
        display as text "{hline 70}"
    }
    else {
        display as text "No significant nodes at alpha = " as result `alpha'
    }
    display as text ""

    * =====================================================================
    * RETURN RESULTS
    * =====================================================================
    return scalar max_llr     = `obs_max_llr'
    return scalar p_value     = `p_max'
    return scalar n_nodes     = `N_nodes'
    return scalar n_obs       = `N_obs'
    return scalar n_exposed   = `N_exposed'
    return scalar n_unexposed = `N_unexposed'
    return scalar nsim        = `nsim'
    return scalar alpha       = `alpha'
    return local model        "`model'"
    return local conditional  "`conditional'"

    if "`model'" == "poisson" {
        return scalar total_persontime = `T_total'
        return scalar total_cases      = `C'
    }

    if `has_temporal' {
        return scalar window_lo  = `window_lo'
        return scalar window_hi  = `window_hi'
        return local windowscope "`windowscope'"
    }

    if `n_sig' > 0 {
        return matrix results = `results_mat'
    }

end
