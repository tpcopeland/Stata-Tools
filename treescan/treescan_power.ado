*! treescan_power Version 1.3.5  2026/02/28
*! Power evaluation for tree-based scan statistic
*! Simulation-based power to detect a signal at a target node
*! Author: Tim Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+, treescan

/*
Syntax:
  treescan_power diagvar [using treefile.dta], id(varname) exposed(varname)
      target(string) rr(real) [icdversion(string) model(string)
      persontime(varname) CONDitional nsim(integer 999)
      nsimpower(integer 500) alpha(real 0.05) seed(integer) noisily]

See help treescan_power for complete documentation.
*/

program define treescan_power, rclass
    version 16.0
    set varabbrev off
    set more off

    * =====================================================================
    * ENSURE MATA LIBRARY AVAILABLE
    * =====================================================================
    capture mata: mata which _treescan_mc_bernoulli()
    if _rc {
        quietly capture mata: mata mlib index
        capture mata: mata which _treescan_mc_bernoulli()
        if _rc {
            display as error "treescan Mata library (ltreescan.mlib) not found"
            exit 601
        }
    }

    * Tempname for simulation matrix (avoids global name collisions)
    tempname _sim_maxllr

    * =====================================================================
    * SYNTAX PARSING
    * =====================================================================
    syntax varlist(min=1 max=1 string) [using/], ///
        ID(varname) EXPosed(varname) TARGet(string) RR(real) ///
        [ICDVersion(string) MODel(string) PERSONTime(varname) ///
         CONDitional NSIM(integer 999) NSIMPOWer(integer 500) ///
         ALPHa(real 0.05) SEED(integer -1) NOIsily]

    local diagvar `varlist'
    local treefile `"`using'"'

    * =====================================================================
    * VALIDATE INPUTS
    * =====================================================================

    * Check for reserved variable name collision
    if "`id'" == "node" | "`exposed'" == "node" | "`persontime'" == "node" {
        display as error ///
            "id(), exposed(), and persontime() variables cannot be named {bf:node}"
        display as error ///
            "rename the variable before calling treescan_power (e.g., {bf:rename node myid})"
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

    * Check nsimpower is positive
    if `nsimpower' < 1 {
        display as error "nsimpower() must be a positive integer"
        exit 198
    }

    * Check alpha is in (0, 1)
    if `alpha' <= 0 | `alpha' >= 1 {
        display as error "alpha() must be between 0 and 1"
        exit 198
    }

    * Check rr > 1
    if `rr' <= 1 {
        display as error "rr() must be greater than 1"
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

    * Set seed if specified
    if `seed' >= 0 {
        set seed `seed'
    }

    * =====================================================================
    * RESOLVE TREE FILE
    * =====================================================================
    if `"`treefile'"' == "" {
        if "`icdversion'" == "cm" {
            capture findfile icd10cm_tree.dta
            if _rc {
                display as error "built-in ICD-10-CM tree not found"
                exit 601
            }
            local treefile "`r(fn)'"
        }
        else if "`icdversion'" == "se" {
            capture findfile icd10se_tree.dta
            if _rc {
                display as error "built-in ICD-10-SE tree not found"
                exit 601
            }
            local treefile "`r(fn)'"
        }
        else if "`icdversion'" == "atc" {
            capture findfile atc_tree.dta
            if _rc {
                display as error "built-in ATC tree not found"
                exit 601
            }
            local treefile "`r(fn)'"
        }
    }

    capture confirm file `"`treefile'"'
    if _rc {
        display as error `"tree file not found: `treefile'"'
        exit 601
    }

    * =====================================================================
    * PREPARE DATA AND COMPUTE OBSERVED STATISTICS
    * =====================================================================
    display as text ""
    display as text "{hline 70}"
    display as text "Tree-Based Scan Power Evaluation"
    display as text "{hline 70}"
    display as text ""
    display as text "Step 1: Establishing null distribution critical value..."

    preserve

    quietly {
        if "`model'" == "poisson" {
            keep `diagvar' `id' `exposed' `persontime'
            drop if missing(`diagvar') | missing(`id') | ///
                missing(`exposed') | missing(`persontime')
        }
        else {
            keep `diagvar' `id' `exposed'
            drop if missing(`diagvar') | missing(`id') | missing(`exposed')
        }

        * Save input data
        tempfile inputdata
        save `inputdata'

        * Collapse to individual level
        if "`model'" == "poisson" {
            collapse (max) `exposed' (max) `persontime', by(`id')
        }
        else {
            collapse (max) `exposed', by(`id')
        }

        if "`model'" == "poisson" {
            keep `id' `exposed' `persontime'
        }
        else {
            keep `id' `exposed'
        }
        tempfile individuals
        save `individuals'

        * Compute observed statistics from individual-level data
        count
        local N_individuals = r(N)
        if `N_individuals' == 0 {
            noisily display as error "no observations"
            exit 2000
        }
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
            summarize `exposed', meanonly
            local C = r(sum)
            summarize `persontime', meanonly
            local T_total = r(sum)
        }

        * Load tree and expand to all ancestor nodes
        local _ptopt ""
        if "`model'" == "poisson" {
            local _ptopt "persontime(`persontime')"
        }
        _treescan_cut_tree, inputdata(`inputdata') ///
            treefile(`"`treefile'"') diagvar(`diagvar') ///
            id(`id') exposed(`exposed') model(`model') ///
            `_ptopt' individuals(`individuals')

        * Count unique tree nodes
        tempvar _tag
        egen byte `_tag' = tag(node)
        quietly count if `_tag' == 1
        local N_nodes = r(N)
        drop `_tag'

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
            tempvar _pt_tag
            bysort `id': gen byte `_pt_tag' = (_n == 1)
            summarize `exposed' if `_pt_tag' == 1, meanonly
            local C = r(sum)
            summarize `persontime' if `_pt_tag' == 1, meanonly
            local T_total = r(sum)
            drop `_pt_tag'
        }

        tempfile cuttree
        save `cuttree'
    }

    * =====================================================================
    * VALIDATE TARGET NODE
    * =====================================================================
    quietly {
        local target_upper = upper(trim("`target'"))
        local target_upper = subinstr("`target_upper'", ".", "", .)

        * Check if target exists as a node in the cut tree
        use `cuttree', clear
        count if node == "`target_upper'"
        if r(N) == 0 {
            noisily display as error ///
                `"target node "`target'" not found in tree"'
            exit 198
        }

        * Identify individuals at target node (or its descendants)
        * These are individuals who have at least one diagnosis at the
        * target node in the expanded tree
        keep if node == "`target_upper'"
        keep `id'
        duplicates drop
        tempvar _at_target
        gen byte `_at_target' = 1
        tempfile target_ids
        save `target_ids'
    }

    * =====================================================================
    * NULL SIMULATION FOR CRITICAL VALUE (Mata)
    * =====================================================================
    if "`noisily'" != "" {
        display as text "Running null simulation for critical value..."
    }

    quietly {
        * Load cut tree for Mata
        use `cuttree', clear

        * Create numeric individual index
        tempvar _id_idx
        egen long `_id_idx' = group(`id')
        sort node `_id_idx'

        if "`model'" == "bernoulli" {
            mata: _treescan_mc_bernoulli(`N_individuals', `N_exposed', ///
                `p', `nsim', ("`conditional'" != ""), ///
                ("`noisily'" != ""), "`_id_idx'", "`exposed'", ///
                "`_sim_maxllr'")
        }
        else {
            mata: _treescan_mc_poisson(`N_individuals', `C', ///
                `C' / `N_individuals', `nsim', ("`conditional'" != ""), ///
                ("`noisily'" != ""), "`_id_idx'", "`exposed'", ///
                "`persontime'", `T_total', "`_sim_maxllr'")
        }

        * Compute critical value from null distribution (via Mata)
        mata: _treescan_critval(`nsim', `alpha', "`_sim_maxllr'")
        matrix drop `_sim_maxllr'
    }

    display as text "  Critical value (alpha=" as result %4.2f `alpha' ///
        as text "): " as result %8.4f `crit_val'

    * =====================================================================
    * POWER LOOP — inject signal and test (Mata)
    * =====================================================================
    display as text ""
    display as text "Step 2: Estimating power (RR=`rr' at node `target')..."

    quietly {
        * Load cut tree for Mata power loop
        use `cuttree', clear

        tempvar _id_idx
        egen long `_id_idx' = group(`id')
        sort node `_id_idx'

        * Build at_target vector: for each individual, 1 if at target node
        * First, get individual-level target mapping
        merge m:1 `id' using `target_ids', keep(master match) nogenerate

        * Create individual-level at_target vector in Mata
        * Need: for each unique _id_idx, whether at_target == 1
        * Since at_target is constant per individual, take max per id
        tempvar _at_tgt
        bysort `_id_idx': egen byte `_at_tgt' = max(`_at_target' == 1)

        * Re-sort by node for Mata node index (bysort above changed order)
        sort node `_id_idx'

        if "`model'" == "bernoulli" {
            mata: st_local("n_reject", strofreal( ///
                _treescan_power_bernoulli(`N_individuals', `N_exposed', ///
                `p', `nsimpower', `crit_val', `rr', ///
                ("`conditional'" != ""), ("`noisily'" != ""), ///
                "`_id_idx'", "`exposed'", ///
                _treescan_indiv_vec("`_id_idx'", "`_at_tgt'", ///
                    `N_individuals'))))
        }
        else {
            mata: st_local("n_reject", strofreal( ///
                _treescan_power_poisson(`N_individuals', `C', ///
                `C' / `N_individuals', `nsimpower', `crit_val', `rr', ///
                ("`conditional'" != ""), ("`noisily'" != ""), ///
                "`_id_idx'", "`exposed'", "`persontime'", `T_total', ///
                _treescan_indiv_vec("`_id_idx'", "`_at_tgt'", ///
                    `N_individuals'))))
        }
    }

    * =====================================================================
    * COMPUTE POWER AND CONFIDENCE INTERVAL
    * =====================================================================
    local power = `n_reject' / `nsimpower'

    * Wald 95% CI for power (normal approximation)
    local se_power = sqrt(`power' * (1 - `power') / `nsimpower')
    local power_ci_lo = max(0, `power' - 1.96 * `se_power')
    local power_ci_hi = min(1, `power' + 1.96 * `se_power')

    * =====================================================================
    * DISPLAY RESULTS
    * =====================================================================
    restore

    display as text ""
    display as text "{hline 70}"
    display as text "Power Evaluation Results"
    display as text "{hline 70}"
    display as text ""
    local cond_label = cond("`conditional'" != "", "Conditional", ///
        "Unconditional")
    display as text "Model:           " as result "`model' `cond_label'"
    display as text "Target node:     " as result "`target'"
    display as text "Relative risk:   " as result %10.2f `rr'
    display as text "Individuals:     " as result %10.0fc `N_individuals'
    display as text "Tree nodes:      " as result %10.0fc `N_nodes'
    display as text ""
    display as text "Null simulations:" as result %10.0fc `nsim'
    display as text "Power iterations:" as result %10.0fc `nsimpower'
    display as text "Alpha:           " as result %10.4f `alpha'
    display as text "Critical LLR:    " as result %10.4f `crit_val'
    display as text ""
    display as text "{hline 40}"
    display as result "  Power:         " as result %10.4f `power'
    display as result "  95% CI:        " as result ///
        "[" %6.4f `power_ci_lo' ", " %6.4f `power_ci_hi' "]"
    display as text "{hline 40}"
    display as text ""
    display as text "Rejections:      " as result ///
        %10.0fc `n_reject' as text " / " as result `nsimpower'
    display as text ""

    * =====================================================================
    * RETURN RESULTS
    * =====================================================================
    return scalar power       = `power'
    return scalar power_ci_lo = `power_ci_lo'
    return scalar power_ci_hi = `power_ci_hi'
    return scalar crit_val    = `crit_val'
    return scalar rr          = `rr'
    return scalar nsim        = `nsim'
    return scalar nsim_power  = `nsimpower'
    return scalar alpha       = `alpha'
    return scalar n_reject    = `n_reject'
    return scalar n_individuals = `N_individuals'
    return scalar n_nodes     = `N_nodes'
    return local target       "`target'"
    return local model        "`model'"
    return local conditional  "`conditional'"

end
