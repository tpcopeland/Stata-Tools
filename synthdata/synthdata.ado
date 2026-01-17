*! synthdata Version 1.6.0  17jan2026  Synthetic data generation with smart realism
program define synthdata
    version 16.0
    set varabbrev off

    syntax [varlist] [if] [in], ///
        [n(integer 0) SAVing(string) REPLACE CLEAR PREfix(string) MULTiple(integer 1)] ///
        [PARAmetric SEQUential BOOTstrap PERMute SMART COMPLEX] ///
        [EMPirical NOISE(real 0.1) SMOOTH AUTOEMPirical] ///
        [CATEgorical(varlist) CONTinuous(varlist) SKIP(varlist) ID(varlist) DATEs(varlist) INTeger(varlist)] ///
        [CORRelations CONDitional CONSTraints(string asis) AUTOCONStraints] ///
        [AUTORELate CONDitionalcat] ///
        [PANEL(string) PRESERVEvar(varlist) AUTOCORR(integer 0) ROWDist(string)] ///
        [MINCell(integer 5) TRIM(real 0) BOUNDs(string asis) NOEXTreme] ///
        [COMPare VALidate(string) UTILity GRAPH FREQcheck] ///
        [SEED(integer -1) ITERate(integer 100) TOLerance(real 1e-6)] ///
        [CONDitionalcont RANDomeffects TRANSform MISSpattern TRENDs] ///
        [PRIVacycheck PRIVacysample(integer 0) PRIVacythresh(real 0.05)]
    
    // Preserve original data
    preserve
    
    // Apply if/in
    marksample touse, novarlist
    qui keep if `touse'
    
    // Check we have data
    if _N == 0 {
        di as error "no observations"
        exit 2000
    }
    
    // Set seed if specified
    if `seed' >= 0 {
        set seed `seed'
    }
    
    // Default to all variables if none specified
    if "`varlist'" == "" {
        qui ds
        local varlist `r(varlist)'
    }
    
    // Remove skip variables from synthesis list
    if "`skip'" != "" {
        local varlist: list varlist - skip
    }
    
    // Remove ID variables from synthesis list (handled separately)
    if "`id'" != "" {
        local varlist: list varlist - id
    }
    
    // Check we have variables to synthesize
    if "`varlist'" == "" {
        di as error "no variables to synthesize"
        exit 102
    }

    // =========================================================================
    // STORE ORIGINAL METADATA: labels, order, missingness, value labels
    // =========================================================================
    // Store the original variable order (all variables, including id/skip)
    qui ds
    local orig_varorder `r(varlist)'

    // Store variable labels, value labels, formats, and missingness rates
    // Create a combined list of all variables we need to track
    local allvars_track `varlist' `id' `skip'
    local allvars_track: list uniq allvars_track

    // Store variable metadata using truncated names to stay within 31-char macro limit
    // Uses single-char prefix + truncated varname (max 30 chars) = max 31 chars
    foreach v of local allvars_track {
        local sv = substr("`v'", 1, 30)

        // Store variable label (L = label)
        local L`sv': variable label `v'

        // Store value label name (N = name of value label)
        local N`sv': value label `v'

        // Store format (F = format)
        local F`sv': format `v'

        // Store variable type for skip variable recreation (T = type, 0=num, 1=str)
        local T`sv' = 0
        cap confirm string variable `v'
        if !_rc {
            local T`sv' = 1
        }

        // Calculate and store missingness rate (M = miss count, R = miss rate)
        qui count if missing(`v')
        local M`sv' = r(N)
        local R`sv' = r(N) / _N
    }

    // =========================================================================
    // CAPTURE MISSINGNESS PATTERNS (if misspattern option enabled)
    // =========================================================================
    local misspattern_file ""
    if "`misspattern'" != "" {
        tempfile misspattern_file
        _synthdata_misspattern_capture `allvars_track', saving(`misspattern_file')
    }

    // =========================================================================
    // DETECT INTEGER (WHOLE NUMBER) CONTINUOUS VARIABLES
    // =========================================================================
    // Integer variables are continuous variables that only contain whole numbers
    // User can specify via integer() option, or we auto-detect
    local intvars `integer'

    // Auto-detect integer variables from continuous variables
    // A variable is considered integer if all non-missing values are whole numbers
    foreach v of local varlist {
        // Skip if already specified in integer()
        local inint: list v in intvars
        if `inint' continue

        // Skip if explicitly specified as categorical, continuous, or date
        local incat: list v in categorical
        local incont: list v in continuous
        local indate: list v in dates
        if `incat' | `incont' | `indate' continue

        // Check if numeric
        cap confirm numeric variable `v'
        if _rc continue

        // Check if has a value label (categorical)
        local vallbl: value label `v'
        if "`vallbl'" != "" continue

        // Check for date format
        local fmt: format `v'
        if strpos("`fmt'", "%t") | strpos("`fmt'", "%d") continue

        // Check unique values - if <= 20, likely categorical
        qui count if !missing(`v')
        if r(N) > 0 {
            qui levelsof `v', local(levels)
            local nuniq: word count `levels'
            if `nuniq' <= 20 continue
        }

        // Now check if all values are integers (whole numbers)
        qui count if !missing(`v') & `v' != floor(`v')
        if r(N) == 0 {
            // All non-missing values are whole numbers
            local intvars `intvars' `v'
        }
    }

    // Determine synthesis method (only one allowed)
    local nmethods = ("`parametric'" != "") + ("`sequential'" != "") + ///
                     ("`bootstrap'" != "") + ("`permute'" != "") + ///
                     ("`smart'" != "") + ("`complex'" != "")
    if `nmethods' > 1 {
        di as error "only one synthesis method may be specified"
        exit 198
    }

    local method "parametric"
    if "`sequential'" != "" local method "sequential"
    if "`bootstrap'" != "" local method "bootstrap"
    if "`permute'" != "" local method "permute"
    if "`smart'" != "" local method "smart"
    if "`complex'" != "" local method "complex"

    // Smart method enables all automatic features
    if "`method'" == "smart" {
        local autoempirical "autoempirical"
        local autorelate "autorelate"
        local conditionalcat "conditionalcat"
        local autoconstraints "autoconstraints"
    }

    // Complex method: smart features + date relationship detection + frequency validation
    if "`method'" == "complex" {
        local autoempirical "autoempirical"
        local autorelate "autorelate"
        local conditionalcat "conditionalcat"
        local autoconstraints "autoconstraints"
        local detect_date_order = 1
        local freqcheck "freqcheck"
        di as txt _n "Complex synthesis mode enabled:"
        di as txt "  - All smart features (auto-empirical, auto-relate, conditional categorical)"
        di as txt "  - Date relationship detection and ordering enforcement"
        di as txt "  - Frequency distribution validation"
    }
    else {
        local detect_date_order = 0
    }
    
    // Default n to current observation count
    local orig_n = _N
    if `n' == 0 local n = `orig_n'
    
    // Classify variables
    _synthdata_classify `varlist', categorical(`categorical') continuous(`continuous') dates(`dates') integer(`intvars')
    local catvars `r(catvars)'
    local contvars `r(contvars)'
    local datevars `r(datevars)'
    local strvars `r(strvars)'
    local intvars `r(intvars)'

    // =========================================================================
    // AUTO-EMPIRICAL: Detect non-normal distributions
    // =========================================================================
    // If autoempirical is specified (or smart method), check each continuous
    // variable for non-normality and flag for empirical synthesis
    local empirical_vars ""
    local normal_vars ""
    if "`autoempirical'" != "" & "`contvars'`intvars'" != "" {
        di as txt _n "Detecting distribution shapes..."
        _synthdata_detect_nonnormal `contvars' `intvars'
        local empirical_vars `r(nonnormal_vars)'
        local normal_vars `r(normal_vars)'
        local n_emp: word count `empirical_vars'
        local n_norm: word count `normal_vars'
        if `n_emp' > 0 {
            di as txt "  Non-normal (using empirical): " as res `n_emp' as txt " variables"
        }
        if `n_norm' > 0 {
            di as txt "  Normal-ish (using parametric): " as res `n_norm' as txt " variables"
        }
    }

    // =========================================================================
    // AUTO-RELATE: Detect variable relationships
    // =========================================================================
    // Detect derived variables (sums, ratios, perfect correlations) and preserve them
    local derived_vars ""
    local base_vars ""
    local n_derived = 0
    if "`autorelate'" != "" & "`contvars'`intvars'" != "" {
        di as txt _n "Detecting variable relationships..."
        _synthdata_detect_relations `contvars' `intvars'
        local derived_vars `r(derived_vars)'
        local base_vars `r(base_vars)'
        local n_derived = r(n_derived)
        if `n_derived' > 0 {
            di as txt "  Derived variables detected: " as res `n_derived'
            // Remove derived vars from synthesis list - they'll be reconstructed
            local contvars: list contvars - derived_vars
            local intvars: list intvars - derived_vars
        }
    }

    // =========================================================================
    // CONDITIONAL CATEGORICAL: Detect associated categoricals
    // =========================================================================
    // Group strongly associated categorical variables for joint synthesis
    local catgroups ""
    if "`conditionalcat'" != "" & "`catvars'" != "" {
        local ncatvars: word count `catvars'
        if `ncatvars' > 1 {
            di as txt _n "Detecting categorical associations..."
            _synthdata_detect_catassoc `catvars'
            local catgroups `"`r(catgroups)'"'
            local joint_catvars `r(joint_catvars)'
            local indep_catvars `r(indep_catvars)'
            // Count quoted groups properly
            local n_groups = 0
            local temp_groups `"`catgroups'"'
            while `"`temp_groups'"' != "" {
                gettoken grp temp_groups : temp_groups
                if `"`grp'"' != "" local ++n_groups
            }
            if `n_groups' > 0 {
                di as txt "  Associated categorical groups: " as res `n_groups'
            }
        }
    }

    // =========================================================================
    // DETECT DATE ORDERING RELATIONSHIPS (if complex method)
    // =========================================================================
    // For panel/longitudinal data with multiple dates, detect if dates have
    // natural ordering (e.g., admission_date < procedure_date < discharge_date)
    local date_orderings ""
    local n_date_orders = 0
    if `detect_date_order' == 1 & "`datevars'" != "" {
        local ndatevars: word count `datevars'
        if `ndatevars' >= 2 {
            di as txt _n "Detecting date ordering relationships..."
            _synthdata_detect_dateorder `datevars'
            local date_orderings `"`r(date_orderings)'"'
            local n_date_orders = r(n_orderings)
            if `n_date_orders' > 0 {
                di as txt "  Date ordering constraints detected: " as res `n_date_orders'
            }
            else {
                di as txt "  No consistent date orderings found"
            }
        }
    }

    // Store original categorical frequencies for freqcheck
    if "`freqcheck'" != "" & "`catvars'" != "" {
        tempfile orig_catfreq
        _synthdata_store_catfreq `catvars', saving(`orig_catfreq')
    }

    // Store original data bounds for noextreme option
    // Include intvars since they're also continuous (just whole numbers)
    if "`noextreme'" != "" {
        tempfile origbounds
        _synthdata_storebounds `contvars' `intvars' `datevars', saving(`origbounds')
    }
    
    // Store original statistics for comparison
    if "`compare'" != "" | "`validate'" != "" | "`utility'" != "" {
        tempfile origstats
        _synthdata_stats `varlist', saving(`origstats')
    }
    
    // Store original data for methods that need it
    tempfile origdata
    qui save `origdata'
    
    // Parse panel structure
    if "`panel'" != "" {
        tokenize `panel'
        local panelid `1'
        local paneltime `2'
        if "`paneltime'" == "" {
            di as error "panel() requires both id and time variables"
            exit 198
        }
    }

    // Validate rowdist option
    if "`rowdist'" == "" local rowdist "empirical"
    local rowdist = lower("`rowdist'")
    if !inlist("`rowdist'", "empirical", "parametric", "exact") {
        di as error "rowdist() must be: empirical, parametric, or exact"
        exit 198
    }

    // =========================================================================
    // ANALYZE ROW-COUNT DISTRIBUTION FOR ID/PANEL VARIABLES
    // =========================================================================
    // If id() or panel() is specified, analyze how many rows per ID exist
    // This is critical for realistic synthesis of longitudinal/panel data
    local has_rowstruct = 0
    if "`id'" != "" {
        local has_rowstruct = 1
    }
    if "`panel'" != "" {
        local has_rowstruct = 1
    }
    local rowcount_info ""
    local orig_n_ids = 0
    local target_n_ids = 0

    if `has_rowstruct' == 1 {
        // Determine ID variable(s)
        if "`panel'" != "" {
            local idvar `panelid'
        }
        else {
            local idvar: word 1 of `id'
        }

        di as txt _n "Analyzing row-count distribution for `idvar'..."

        // Get row counts per ID
        tempvar rowcount
        qui bysort `idvar': gen long `rowcount' = _N
        qui bysort `idvar': keep if _n == 1

        // Store row-count distribution statistics
        qui su `rowcount', detail
        local rc_mean = r(mean)
        local rc_sd = r(sd)
        local rc_min = r(min)
        local rc_max = r(max)
        local rc_p25 = r(p25)
        local rc_p50 = r(p50)
        local rc_p75 = r(p75)
        local orig_n_ids = r(N)

        di as txt "  Unique IDs: " as res `orig_n_ids'
        di as txt "  Rows per ID: mean=" as res %5.1f `rc_mean' ///
            as txt ", median=" as res %3.0f `rc_p50' ///
            as txt ", range=[" as res `rc_min' as txt "-" as res `rc_max' as txt "]"

        // Save row count distribution for later use
        tempfile rowcount_dist
        qui keep `idvar' `rowcount'
        qui save `rowcount_dist'

        // Reload original data
        qui use `origdata', clear

        // Calculate target number of IDs based on n()
        // If n() specified, estimate how many IDs needed to get ~n observations
        if `n' != `orig_n' {
            local target_n_ids = round(`n' / `rc_mean')
            if `target_n_ids' < 1 local target_n_ids = 1
        }
        else {
            local target_n_ids = `orig_n_ids'
        }

        di as txt "  Target IDs: " as res `target_n_ids'
    }

    // =========================================================================
    // DETECT AND APPLY TRANSFORMS (if transform option enabled)
    // =========================================================================
    local transforms ""
    local transform_vars ""
    if "`transform'" != "" & "`contvars'" != "" {
        di as txt _n "Detecting skewed distributions for transformation..."
        _synthdata_transform `contvars', origdata(`origdata')
        local transforms `"`r(transforms)'"'
        local transform_vars "`r(transform_vars)'"
        if "`transform_vars'" != "" {
            di as txt "  Variables to transform: `transform_vars'"
        }
    }

    // =========================================================================
    // SYNTHESIS: Generate synthetic data based on selected method
    // =========================================================================
    // Methods available:
    //   - smart: Adaptive synthesis with auto-detection of best approach
    //   - parametric (default): Multivariate normal with Cholesky decomposition
    //   - sequential: Regression-based sequential synthesis
    //   - bootstrap: Resample with replacement + noise
    //   - permute: Independent permutation per variable (breaks correlations)

    di as txt _n "Synthesizing data using `method' method..."
    di as txt "  Variables: " as res `: word count `varlist''
    di as txt "  Target observations: " as res `n'

    // Include integer variables with continuous for synthesis (they get rounded afterward)
    local synth_contvars `contvars' `intvars'

    // Check if conditionalcont is enabled and we have both continuous and categorical vars
    // Use synth_contvars which includes both continuous and integer variables
    local use_condcont = 0
    if "`conditionalcont'" != "" & "`synth_contvars'" != "" & "`catvars'" != "" {
        local use_condcont = 1
        di as txt "  Using categorical-continuous conditioning..."
    }

    if `use_condcont' {
        // Use conditional continuous synthesis
        _synthdata_condcont, contvars(`synth_contvars') catvars(`catvars') ///
            n(`n') origdata(`origdata')
        // Still need to generate other variables (categorical, string, date)
        // The condcont handles continuous + one categorical already
        // Generate remaining categoricals and other types
        if `: word count `catvars'' > 1 {
            // Generate remaining categorical variables
            preserve
            qui use `origdata', clear
            local catnum = 1
            foreach v of local catvars {
                if `catnum' > 1 {
                    qui levelsof `v', local(levels_`catnum')
                    local nlevels_`catnum': word count `levels_`catnum''
                    if `nlevels_`catnum'' > 0 {
                        tempname catfreq_`catnum'
                        matrix `catfreq_`catnum'' = J(`nlevels_`catnum'', 2, .)
                        local j = 1
                        foreach lev of local levels_`catnum' {
                            qui count if `v' == `lev'
                            matrix `catfreq_`catnum''[`j', 1] = `lev'
                            matrix `catfreq_`catnum''[`j', 2] = r(N)
                            local ++j
                        }
                        local vallbl_`catnum': value label `v'
                    }
                }
                local ++catnum
            }
            restore
            // Generate remaining categoricals in synthetic data
            local catnum = 1
            foreach v of local catvars {
                if `catnum' > 1 & `nlevels_`catnum'' > 0 {
                    cap drop `v'
                    qui gen double `v' = .
                    mata: _synthdata_drawcat("`v'", st_matrix("`catfreq_`catnum''"), `n')
                    if "`vallbl_`catnum''" != "" {
                        cap label values `v' `vallbl_`catnum''
                    }
                }
                local ++catnum
            }
        }
    }
    else if "`method'" == "smart" | "`method'" == "complex" {
        // Smart/Complex method: adaptive synthesis using detected characteristics
        // Complex adds date ordering detection/enforcement and frequency checking
        _synthdata_smart, n(`n') catvars(`catvars') contvars(`synth_contvars') ///
            datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
            empirical_vars(`empirical_vars') normal_vars(`normal_vars') ///
            catgroups(`catgroups') joint_catvars(`joint_catvars') indep_catvars(`indep_catvars') ///
            `smooth' `correlations' ///
            mincell(`mincell') trim(`trim')
    }
    else if "`method'" == "parametric" {
        // Check if autoempirical flagged any variables
        // If so, enable empirical mode for all continuous (uses Gaussian copula for correlations)
        local use_empirical = "`empirical'"
        if "`autoempirical'" != "" & "`empirical_vars'" != "" {
            local use_empirical "empirical"
        }
        _synthdata_parametric, n(`n') catvars(`catvars') contvars(`synth_contvars') ///
            datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
            `use_empirical' `smooth' `correlations' ///
            mincell(`mincell') trim(`trim')
    }
    else if "`method'" == "bootstrap" {
        _synthdata_bootstrap, n(`n') noise(`noise') ///
            catvars(`catvars') contvars(`synth_contvars') datevars(`datevars') ///
            strvars(`strvars') origdata(`origdata') ///
            mincell(`mincell') trim(`trim')
    }
    else if "`method'" == "permute" {
        _synthdata_permute `varlist', n(`n') origdata(`origdata')
    }
    else if "`method'" == "sequential" {
        _synthdata_sequential, n(`n') catvars(`catvars') contvars(`synth_contvars') ///
            datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
            mincell(`mincell') trim(`trim')
    }

    // =========================================================================
    // RECONSTRUCT DERIVED VARIABLES
    // =========================================================================
    // If autorelate detected derived variables, reconstruct them from base vars
    if "`autorelate'" != "" & `n_derived' > 0 {
        di as txt "  Reconstructing derived variables..."
        _synthdata_reconstruct_derived, n_derived(`n_derived')
    }

    // =========================================================================
    // BACK-TRANSFORM (if transform option was used)
    // =========================================================================
    if "`transform'" != "" & "`transform_vars'" != "" {
        di as txt "  Back-transforming skewed variables..."
        _synthdata_backtransform `contvars', transforms(`transforms')
    }

    di as txt "  Synthesis complete."

    // =========================================================================
    // HANDLE ID VARIABLES WITH ROW-COUNT DISTRIBUTION
    // =========================================================================
    // For panel/longitudinal data, preserve realistic row counts per ID
    if `has_rowstruct' == 1 & "`id'" != "" {
        di as txt _n "Generating ID structure with realistic row counts..."

        // Save current synthetic data before ID structure work
        tempfile synthdata_temp
        qui save `synthdata_temp'

        // Generate row counts for synthetic IDs
        _synthdata_rowcounts, target_n_ids(`target_n_ids') ///
            rowcount_dist(`rowcount_dist') rowdist(`rowdist') ///
            rc_mean(`rc_mean') rc_sd(`rc_sd') rc_min(`rc_min') rc_max(`rc_max')

        // Get the generated row counts
        tempfile synth_rowcounts
        qui save `synth_rowcounts'

        // Now expand synthetic data to match ID structure
        // Current synthetic data has `n' rows - we need to restructure
        qui use `synth_rowcounts', clear
        qui su synth_rowcount, meanonly
        local total_synth_rows = r(sum)
        local n_synth_ids = _N

        di as txt "  Generated " as res `n_synth_ids' as txt " IDs with " ///
            as res `total_synth_rows' as txt " total rows"

        // Expand to create proper row structure
        qui expand synth_rowcount
        qui bysort synth_id: gen long _rownum = _n

        // Save the ID structure with observation number for merge
        qui gen long _obs = _n
        tempfile id_structure
        qui keep synth_id _rownum _obs
        qui save `id_structure'

        // Load the synthetic data and adjust to match ID structure
        qui use `synthdata_temp', clear
        local curr_n = _N

        if `total_synth_rows' > `curr_n' {
            // Need to expand - sample with replacement
            qui expand ceil(`total_synth_rows' / `curr_n') + 1
            qui gen double _rand = runiform()
            qui sort _rand
            qui keep in 1/`total_synth_rows'
            drop _rand
        }
        else if `total_synth_rows' < `curr_n' {
            // Need to reduce - random sample
            qui gen double _rand = runiform()
            qui sort _rand
            qui keep in 1/`total_synth_rows'
            drop _rand
        }

        // Assign ID structure
        qui gen long _obs = _n
        qui merge 1:1 _obs using `id_structure', nogen keepusing(synth_id)

        // Create the ID variable(s)
        foreach v of local id {
            cap drop `v'
            qui gen long `v' = synth_id
            label var `v' "Synthetic ID"
        }
        cap drop synth_id _obs _rownum

        di as txt "  ID structure applied successfully"
    }
    else if "`id'" != "" {
        // Simple case - just generate sequential IDs (original behavior)
        foreach v of local id {
            cap drop `v'
            qui gen long `v' = _n
            label var `v' "Synthetic ID"
        }
    }

    // =========================================================================
    // APPLY RANDOM EFFECTS FOR PANEL DATA (if randomeffects option enabled)
    // =========================================================================
    if "`randomeffects'" != "" & "`id'" != "" & "`synth_contvars'" != "" {
        local first_id: word 1 of `id'
        _synthdata_randomeffects, idvar(`first_id') contvars(`synth_contvars') origdata(`origdata')
    }

    // =========================================================================
    // APPLY TEMPORAL TRENDS FOR PANEL DATA (if trends option enabled)
    // =========================================================================
    if "`trends'" != "" & "`id'" != "" & "`synth_contvars'" != "" {
        // Try to detect a time variable - look for common patterns
        local timevar ""
        foreach v of local varlist {
            if inlist("`v'", "time", "visit", "wave", "period", "t", "year", "date") {
                local timevar "`v'"
                continue, break
            }
        }
        // Also check if panel() option specified a time variable
        if "`panel'" != "" {
            tokenize "`panel'"
            if "`2'" != "" {
                local timevar "`2'"
            }
        }
        if "`timevar'" != "" {
            local first_id: word 1 of `id'
            cap confirm numeric variable `timevar'
            if !_rc {
                _synthdata_trends, idvar(`first_id') timevar(`timevar') ///
                    contvars(`synth_contvars') origdata(`origdata')
            }
        }
    }

    // Handle skip variables - set to missing in synthetic data
    if "`skip'" != "" {
        foreach v of local skip {
            cap drop `v'

            // Recreate based on original type (stored in T`sv')
            local sv = substr("`v'", 1, 30)
            if `T`sv'' == 1 {
                qui gen str1 `v' = ""
            }
            else {
                qui gen `v' = .
            }
        }
    }
    
    // Apply bounds first (before constraints, as constraints may depend on bounded values)
    if `"`bounds'"' != "" {
        _synthdata_bounds, bounds(`bounds')
    }
    
    // Enforce no extreme values using stored original bounds
    // Include intvars since they're also continuous (just whole numbers)
    if "`noextreme'" != "" {
        _synthdata_noextreme `contvars' `intvars' `datevars', boundsfile(`origbounds')
    }
    
    // Apply auto-detected constraints (only if there are continuous or date vars)
    if "`autoconstraints'" != "" & ("`contvars'" != "" | "`datevars'" != "") {
        _synthdata_autoconstraints `contvars' `datevars', iterate(`iterate') origdata(`origdata')
    }
    
    // Apply user constraints
    if `"`constraints'"' != "" {
        _synthdata_constraints, constraints(`constraints') iterate(`iterate')
    }

    // =========================================================================
    // ENFORCE DATE ORDERING (if complex method detected orderings)
    // =========================================================================
    if `n_date_orders' > 0 & "`date_orderings'" != "" {
        di as txt "  Enforcing date ordering constraints..."
        _synthdata_enforce_dateorder, orderings(`date_orderings') iterate(`iterate')
    }

    // Handle panel structure
    if "`panel'" != "" {
        if "`preservevar'" != "" {
            _synthdata_panel, panelid(`panelid') paneltime(`paneltime') ///
                preserve(`preservevar') autocorr(`autocorr') nobs(`n') ///
                origdata("`origdata'") rowdist(`rowdist')
        }
        else {
            _synthdata_panel, panelid(`panelid') paneltime(`paneltime') ///
                autocorr(`autocorr') nobs(`n') origdata("`origdata'") rowdist(`rowdist')
        }
    }

    // =========================================================================
    // POST-SYNTHESIS RESTORATION: labels, missingness, integers, variable order
    // =========================================================================

    // Round integer variables to whole numbers
    if "`intvars'" != "" {
        foreach v of local intvars {
            cap confirm variable `v'
            if !_rc {
                qui replace `v' = round(`v')
            }
        }
    }

    // Apply missingness to synthetic data
    // Use pattern-based approach if misspattern option was enabled, otherwise use rate-based
    if "`misspattern'" != "" & "`misspattern_file'" != "" {
        // Pattern-based missingness - preserves which variables are missing together
        di as txt "  Applying missingness patterns..."
        // Build list of variables to apply patterns to (excluding id and skip)
        local miss_varlist ""
        foreach v of local allvars_track {
            cap confirm variable `v'
            if _rc continue
            local isid: list v in id
            if `isid' continue
            local isskip: list v in skip
            if `isskip' continue
            local miss_varlist `miss_varlist' `v'
        }
        if "`miss_varlist'" != "" {
            _synthdata_misspattern_apply `miss_varlist', patterns(`misspattern_file')
        }
    }
    else {
        // Rate-based missingness (original behavior)
        foreach v of local allvars_track {
            cap confirm variable `v'
            if _rc continue

            // Skip ID variables (they have different handling)
            local isid: list v in id
            if `isid' continue

            // Skip skip variables (they're already missing)
            local isskip: list v in skip
            if `isskip' continue

            // Apply missingness if original had any missing values
            local sv = substr("`v'", 1, 30)
            if `R`sv'' > 0 {
                // Generate random missingness at the same rate
                tempvar randmiss
                qui gen double `randmiss' = runiform()
                cap confirm string variable `v'
                if !_rc {
                    // String variable
                    qui replace `v' = "" if `randmiss' < `R`sv''
                }
                else {
                    // Numeric variable
                    qui replace `v' = . if `randmiss' < `R`sv''
                }
                drop `randmiss'
            }
        }
    }

    // Restore variable labels
    foreach v of local allvars_track {
        cap confirm variable `v'
        if _rc continue

        local sv = substr("`v'", 1, 30)

        // Restore variable label if there was one
        if `"`L`sv''"' != "" {
            label variable `v' `"`L`sv''"'
        }

        // Restore value label attachment if there was one
        // (the value label definition itself should still exist)
        if "`N`sv''" != "" {
            cap label values `v' `N`sv''
        }
    }

    // Reorder variables to match original order
    // Build the reorder list from variables that exist in synthetic data
    local reorder_list ""
    foreach v of local orig_varorder {
        cap confirm variable `v'
        if !_rc {
            local reorder_list `reorder_list' `v'
        }
    }
    if "`reorder_list'" != "" {
        order `reorder_list'
    }

    // Store synthetic variable names before prefix (for compare)
    local synthvars `varlist'

    // Add prefix to variable names if requested
    // Uses safe naming to handle 32-character limit
    if "`prefix'" != "" {
        foreach v of varlist * {
            _synthdata_safename `prefix' `v'
            local newname = r(safename)
            if "`newname'" != "`v'" {
                cap rename `v' `newname'
            }
        }
    }
    
    // Validation and comparison (must use unprefixed names for stats)
    if "`compare'" != "" {
        _synthdata_compare `synthvars', origstats(`origstats') prefix(`prefix')
    }
    
    if "`validate'" != "" {
        _synthdata_validate `synthvars', origstats(`origstats') saving(`validate') prefix(`prefix')
    }
    
    if "`utility'" != "" {
        _synthdata_utility `synthvars', origstats(`origstats')
    }
    
    if "`graph'" != "" {
        _synthdata_graph `contvars', origdata(`origdata') prefix(`prefix')
    }
    
    // =========================================================================
    // MULTIPLE DATASETS: Generate multiple synthetic datasets if requested
    // =========================================================================
    if `multiple' > 1 {
        if "`saving'" == "" {
            di as error "multiple() requires saving() option"
            exit 198
        }

        // Sanitize filename for security
        if regexm("`saving'", "[;&|><\$\`]") {
            di as error "saving() contains invalid characters"
            exit 198
        }

        di as txt _n "Generating `multiple' synthetic datasets..."

        // Save first dataset (already generated above)
        local savename = subinstr("`saving'", ".dta", "", .)
        qui save "`savename'_1.dta", replace
        di as txt "  Dataset 1/`multiple' saved."

        // Generate additional datasets with different random seeds
        forvalues m = 2/`multiple' {
            di as txt "  Dataset `m'/`multiple'..." _continue
            qui use `origdata', clear
            
            if `seed' >= 0 {
                set seed `=`seed' + `m''
            }
            
            if "`method'" == "parametric" {
                _synthdata_parametric, n(`n') catvars(`catvars') contvars(`synth_contvars') ///
                    datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
                    `empirical' `smooth' `correlations' ///
                    mincell(`mincell') trim(`trim')
            }
            else if "`method'" == "bootstrap" {
                _synthdata_bootstrap, n(`n') noise(`noise') ///
                    catvars(`catvars') contvars(`synth_contvars') datevars(`datevars') ///
                    strvars(`strvars') origdata(`origdata') ///
                    mincell(`mincell') trim(`trim')
            }
            else if "`method'" == "permute" {
                _synthdata_permute `varlist', n(`n') origdata(`origdata')
            }
            else if "`method'" == "sequential" {
                _synthdata_sequential, n(`n') catvars(`catvars') contvars(`synth_contvars') ///
                    datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
                    mincell(`mincell') trim(`trim')
            }
            
            if "`id'" != "" {
                foreach v of local id {
                    cap drop `v'
                    qui gen long `v' = _n
                    label var `v' "Synthetic ID"
                }
            }

            if "`skip'" != "" {
                foreach v of local skip {
                    cap drop `v'

                    // Recreate based on original type (stored in T`sv')
                    local sv = substr("`v'", 1, 30)
                    if `T`sv'' == 1 {
                        qui gen str1 `v' = ""
                    }
                    else {
                        qui gen `v' = .
                    }
                }
            }
            
            if `"`bounds'"' != "" {
                _synthdata_bounds, bounds(`bounds')
            }
            
            if "`noextreme'" != "" {
                _synthdata_noextreme `contvars' `datevars', boundsfile(`origbounds')
            }
            
            if `"`constraints'"' != "" {
                _synthdata_constraints, constraints(`constraints') iterate(`iterate')
            }

            // Post-synthesis restoration for multiple datasets
            // Round integer variables
            if "`intvars'" != "" {
                foreach v of local intvars {
                    cap confirm variable `v'
                    if !_rc {
                        qui replace `v' = round(`v')
                    }
                }
            }

            // Apply missingness rates
            foreach v of local allvars_track {
                cap confirm variable `v'
                if _rc continue
                local isid: list v in id
                if `isid' continue
                local isskip: list v in skip
                if `isskip' continue
                local sv = substr("`v'", 1, 30)
                if `R`sv'' > 0 {
                    tempvar randmiss
                    qui gen double `randmiss' = runiform()
                    cap confirm string variable `v'
                    if !_rc {
                        qui replace `v' = "" if `randmiss' < `R`sv''
                    }
                    else {
                        qui replace `v' = . if `randmiss' < `R`sv''
                    }
                    drop `randmiss'
                }
            }

            // Restore variable labels
            foreach v of local allvars_track {
                cap confirm variable `v'
                if _rc continue
                local sv = substr("`v'", 1, 30)
                if `"`L`sv''"' != "" {
                    label variable `v' `"`L`sv''"'
                }
                if "`N`sv''" != "" {
                    cap label values `v' `N`sv''
                }
            }

            // Reorder variables
            local reorder_list ""
            foreach v of local orig_varorder {
                cap confirm variable `v'
                if !_rc {
                    local reorder_list `reorder_list' `v'
                }
            }
            if "`reorder_list'" != "" {
                order `reorder_list'
            }

            if "`prefix'" != "" {
                foreach v of varlist * {
                    _synthdata_safename `prefix' `v'
                    local newname = r(safename)
                    if "`newname'" != "`v'" {
                        cap rename `v' `newname'
                    }
                }
            }

            qui save "`savename'_`m'.dta", replace
            di as txt " saved."
        }

        di as txt _n "All `multiple' synthetic datasets saved: `savename'_1.dta to `savename'_`multiple'.dta"
    }
    else {
        // Single dataset handling
        if "`saving'" != "" {
            // Sanitize filename
            if regexm("`saving'", "[;&|><\$\`]") {
                di as error "saving() contains invalid characters"
                exit 198
            }
            local savename = subinstr("`saving'", ".dta", "", .)
            qui save "`savename'.dta", replace
            di as txt "Synthetic data saved to `savename'.dta"
        }
        
        if "`replace'" != "" | "`clear'" != "" {
            restore, not
            di as txt "Current data replaced with synthetic version (`n' observations)"
        }
    }

    // =========================================================================
    // PRIVACY CHECK (if privacycheck option enabled with sample > 0)
    // =========================================================================
    if "`privacycheck'" != "" & `privacysample' > 0 {
        // Build list of numeric variables for distance calculation
        local privacy_vars ""
        foreach v of local contvars {
            cap confirm variable `v'
            if !_rc {
                local privacy_vars `privacy_vars' `v'
            }
        }
        if "`privacy_vars'" != "" {
            _synthdata_privacycheck `privacy_vars', origdata(`origdata') ///
                sample(`privacysample') threshold(`privacythresh')
        }
    }

    // =========================================================================
    // FREQUENCY CHECK (if freqcheck option or complex method)
    // =========================================================================
    if "`freqcheck'" != "" & "`catvars'" != "" {
        di as txt _n "Validating categorical frequency distributions..."
        _synthdata_freqcheck `catvars', origfreq(`orig_catfreq')
    }

    // Display summary
    di as txt _n "Synthetic data generation complete:"
    di as txt "  Method: " as res "`method'"
    di as txt "  Original observations: " as res `orig_n'
    di as txt "  Synthetic observations: " as res `n'
    di as txt "  Variables synthesized: " as res `: word count `varlist''
    if "`contvars'" != "" di as txt "    Continuous: " as res `: word count `contvars''
    if "`intvars'" != "" di as txt "    Integer (whole numbers): " as res `: word count `intvars''
    if "`catvars'" != "" di as txt "    Categorical (numeric): " as res `: word count `catvars''
    if "`strvars'" != "" di as txt "    Categorical (string): " as res `: word count `strvars''
    if "`datevars'" != "" di as txt "    Dates: " as res `: word count `datevars''
    if "`id'" != "" di as txt "  ID variables (regenerated): " as res "`id'"
    if "`skip'" != "" di as txt "  Skipped variables: " as res "`skip'"

    // Display smart synthesis info
    if "`method'" == "smart" | "`method'" == "complex" | "`autoempirical'" != "" {
        di as txt _n "  Smart synthesis features:"
        if "`empirical_vars'" != "" {
            di as txt "    Empirical (non-normal): " as res `: word count `empirical_vars''
        }
        if "`normal_vars'" != "" {
            di as txt "    Parametric (normal): " as res `: word count `normal_vars''
        }
        if "`derived_vars'" != "" {
            di as txt "    Derived (reconstructed): " as res `: word count `derived_vars''
        }
        if `"`catgroups'"' != "" {
            // Count quoted groups properly
            local n_catgroups = 0
            local temp_groups `"`catgroups'"'
            while `"`temp_groups'"' != "" {
                gettoken grp temp_groups : temp_groups
                if `"`grp'"' != "" local ++n_catgroups
            }
            di as txt "    Categorical groups: " as res `n_catgroups'
        }
        if `n_date_orders' > 0 {
            di as txt "    Date orderings enforced: " as res `n_date_orders'
        }
    }

    // Display new realism features used
    local realism_features = 0
    if "`conditionalcont'" != "" local ++realism_features
    if "`randomeffects'" != "" local ++realism_features
    if "`transform'" != "" local ++realism_features
    if "`misspattern'" != "" local ++realism_features
    if "`trends'" != "" local ++realism_features

    if `realism_features' > 0 {
        di as txt _n "  Realism enhancements:"
        if "`conditionalcont'" != "" {
            di as txt "    Categorical-continuous conditioning: " as res "enabled"
        }
        if "`randomeffects'" != "" {
            di as txt "    Within-ID random effects: " as res "enabled"
        }
        if "`transform'" != "" & "`transform_vars'" != "" {
            di as txt "    Skewness transforms: " as res `: word count `transform_vars'' " variables"
        }
        if "`misspattern'" != "" {
            di as txt "    Missingness patterns: " as res "preserved"
        }
        if "`trends'" != "" {
            di as txt "    Temporal trends: " as res "enabled"
        }
    }
end

// =============================================================================
// SAFE PREFIX NAMING (handles 32-char limit)
// =============================================================================
// Creates a safely prefixed variable name, respecting Stata's 32-char limit.
// If prefix + varname exceeds 32 chars, truncates varname to fit.
// Returns the safe name via r(safename).

program define _synthdata_safename, rclass
    version 16.0
    args prefix varname

    local combined `prefix'`varname'
    local len = strlen("`combined'")

    if `len' <= 32 {
        return local safename `combined'
    }
    else {
        // Truncate varname to fit with prefix
        local prefixlen = strlen("`prefix'")
        local maxvarlen = 32 - `prefixlen'
        local truncated = substr("`varname'", 1, `maxvarlen')
        return local safename `prefix'`truncated'
    }
end

// =============================================================================
// VARIABLE CLASSIFICATION
// =============================================================================
// Classifies variables as categorical, continuous, date, string, or integer
// using adaptive heuristics based on:
//   1. String type → always string categorical
//   2. Value labels → always categorical (definitive signal)
//   3. Date format (%t or %d) → date
//   4. Adaptive numeric classification considering:
//      - Unique value count (absolute)
//      - Uniqueness ratio (nuniq / N)
//      - Format hints (decimal display)
//      - Whether all values are integers
//
// The adaptive approach handles varying sample sizes better than fixed thresholds

program define _synthdata_classify, rclass
    version 16.0
    syntax varlist, [categorical(varlist) continuous(varlist) dates(varlist) integer(varlist)]

    local catvars `categorical'
    local contvars `continuous'
    local datevars `dates'
    local intvars `integer'
    local strvars ""

    foreach v of local varlist {
        // ---------------------------------------------------------------------
        // RULE 1: String variables are ALWAYS string categorical
        // ---------------------------------------------------------------------
        cap confirm string variable `v'
        if !_rc {
            // Remove from catvars if user mistakenly specified it there
            local catvars: list catvars - v
            local strvars `strvars' `v'
            continue
        }

        // Skip if already classified by user (for non-string variables only)
        local incat: list v in catvars
        local incont: list v in contvars
        local indate: list v in datevars
        local inint: list v in intvars

        if `incat' | `incont' | `indate' | `inint' continue

        // ---------------------------------------------------------------------
        // RULE 2: Value-labeled variables are ALWAYS categorical
        // ---------------------------------------------------------------------
        local vallbl: value label `v'
        if "`vallbl'" != "" {
            local catvars `catvars' `v'
            continue
        }

        // ---------------------------------------------------------------------
        // RULE 3: Date-formatted variables are dates
        // ---------------------------------------------------------------------
        local fmt: format `v'
        if strpos("`fmt'", "%t") | strpos("`fmt'", "%d") {
            local datevars `datevars' `v'
            continue
        }

        // ---------------------------------------------------------------------
        // RULE 4: Adaptive classification for remaining numeric variables
        // ---------------------------------------------------------------------
        // Compute key metrics for classification decision

        // 4a. Count non-missing and unique values
        qui count if !missing(`v')
        local nobs = r(N)
        if `nobs' == 0 {
            // All missing - treat as continuous (will be all missing anyway)
            local contvars `contvars' `v'
            continue
        }

        qui levelsof `v', local(levels)
        local nuniq: word count `levels'

        // 4b. Compute uniqueness ratio (proportion of values that are unique)
        local ratio = `nuniq' / `nobs'

        // 4c. Check if format explicitly shows decimals (strong continuous signal)
        // Format like %8.2f shows decimals, %9.0g or %8.0f doesn't necessarily
        local shows_decimals = 0
        if regexm("`fmt'", "%[0-9]*\.[1-9]") {
            local shows_decimals = 1
        }

        // 4d. Check if all non-missing values are integers (whole numbers)
        qui count if !missing(`v') & `v' != floor(`v')
        local all_integers = (r(N) == 0)

        // ---------------------------------------------------------------------
        // CLASSIFICATION DECISION TREE (ordered by signal strength)
        // ---------------------------------------------------------------------

        // STRONG CATEGORICAL: Very few unique values (≤10) regardless of N
        if `nuniq' <= 10 {
            local catvars `catvars' `v'
            continue
        }

        // STRONG CONTINUOUS: Format explicitly displays decimals
        if `shows_decimals' {
            local contvars `contvars' `v'
            continue
        }

        // STRONG CONTINUOUS: High uniqueness ratio (>50% unique) or many unique values
        // with moderate ratio (>50 unique AND >20% unique)
        if `ratio' > 0.50 | (`nuniq' > 50 & `ratio' > 0.20) {
            local contvars `contvars' `v'
            continue
        }

        // MODERATE CATEGORICAL: Low uniqueness ratio (<5%) with limited range (≤30 levels)
        // This catches categorical variables in large datasets
        if `ratio' < 0.05 & `nuniq' <= 30 {
            local catvars `catvars' `v'
            continue
        }

        // MODERATE CATEGORICAL: All integers with modest count (11-25 levels)
        // Likely ordinal scales, Likert scales, coded categories
        if `all_integers' & `nuniq' <= 25 {
            local catvars `catvars' `v'
            continue
        }

        // DEFAULT: Treat as continuous
        // When signals are mixed, continuous synthesis is safer
        // (categorical synthesis with many levels is memory-intensive)
        local contvars `contvars' `v'
    }

    return local catvars `catvars'
    return local contvars `contvars'
    return local datevars `datevars'
    return local strvars `strvars'
    return local intvars `intvars'
end

// =============================================================================
// NON-NORMALITY DETECTION
// =============================================================================
// Detects non-normal distributions using skewness and kurtosis.
// Variables with |skewness| > 1 or |kurtosis - 3| > 2 are flagged as non-normal.
// These thresholds are based on common rules of thumb for departures from normality.
//
// Returns:
//   r(nonnormal_vars) - variables that should use empirical synthesis
//   r(normal_vars)    - variables that can use parametric (normal) synthesis

program define _synthdata_detect_nonnormal, rclass
    version 16.0
    syntax varlist

    local nonnormal_vars ""
    local normal_vars ""

    foreach v of local varlist {
        cap confirm numeric variable `v'
        if _rc continue

        // Get sample statistics
        qui su `v', detail
        local n = r(N)

        // Need enough observations for reliable skewness/kurtosis
        if `n' < 20 {
            // Too few obs - default to normal (less risky)
            local normal_vars `normal_vars' `v'
            continue
        }

        local skew = r(skewness)
        local kurt = r(kurtosis)

        // Handle missing skewness/kurtosis (zero variance, etc.)
        if `skew' == . | `kurt' == . {
            local normal_vars `normal_vars' `v'
            continue
        }

        // Non-normality thresholds:
        // |skewness| > 1: Highly skewed (log-normal, exponential, etc.)
        // |kurtosis - 3| > 2: Heavy tails or too peaked (kurtosis=3 for normal)
        local is_nonnormal = 0
        if abs(`skew') > 1 {
            local is_nonnormal = 1
        }
        if abs(`kurt' - 3) > 2 {
            local is_nonnormal = 1
        }

        // Additional check: bounded variables (all positive, all negative, or 0-1)
        // These are often better synthesized empirically
        if r(min) >= 0 & r(max) <= 1 {
            // Proportion/probability variable
            local is_nonnormal = 1
        }

        if `is_nonnormal' {
            local nonnormal_vars `nonnormal_vars' `v'
        }
        else {
            local normal_vars `normal_vars' `v'
        }
    }

    return local nonnormal_vars `nonnormal_vars'
    return local normal_vars `normal_vars'
end

// =============================================================================
// VARIABLE RELATIONSHIP DETECTION
// =============================================================================
// Detects derived variables that are perfect (or near-perfect) functions of
// other variables. These include:
//   1. Sums: total = a + b + c
//   2. Differences: diff = end - start
//   3. Products: interaction = a * b
//   4. Ratios: rate = numerator / denominator
//   5. Perfect linear combinations: z = a*x + b*y + c
//
// Uses regression with R² > 0.999 to detect near-perfect relationships.
// Derived variables are excluded from synthesis and reconstructed afterward.
//
// Returns:
//   r(derived_vars) - variables that are derived from others
//   r(base_vars)    - variables used in derivations
//   r(formulas)     - reconstruction formulas (quoted list)

program define _synthdata_detect_relations, rclass
    version 16.0
    syntax varlist

    local derived_vars ""
    local base_vars ""

    local nvars: word count `varlist'
    if `nvars' < 2 {
        return local derived_vars ""
        return local base_vars ""
        return scalar n_derived = 0
        exit
    }

    // For each variable, check if it's a near-perfect linear function of others
    // We process variables in REVERSE order, so genuinely derived variables
    // (which are usually defined last, like "total = a + b + c") are detected first
    local nvars: word count `varlist'
    local max_derived = max(0, `nvars' - 2)  // Leave at least 2 base vars

    // Build reverse order list (last vars first, as they're likely to be derived)
    local revlist ""
    local i = `nvars'
    while `i' >= 1 {
        local v: word `i' of `varlist'
        local revlist `revlist' `v'
        local i = `i' - 1
    }

    foreach v of local revlist {
        // Skip if already identified as derived
        local is_derived: list v in derived_vars
        if `is_derived' continue

        // Limit how many we mark as derived
        local n_derived: word count `derived_vars'
        if `n_derived' >= `max_derived' continue

        // Build list of potential predictors:
        // Only use variables that appear BEFORE v in the original varlist
        // and are not already identified as derived
        local all_preds ""
        local found_v = 0
        foreach p of local varlist {
            if "`p'" == "`v'" {
                local found_v = 1
            }
            if `found_v' == 0 {
                local is_derived_p: list p in derived_vars
                if !`is_derived_p' {
                    local all_preds `all_preds' `p'
                }
            }
        }

        // Skip if not enough predictors
        local npred: word count `all_preds'
        if `npred' < 2 continue

        // Try to find the SIMPLEST combination that explains v perfectly
        // Start with pairs, then triples, to avoid collinearity issues
        local found_formula = 0
        local best_expr ""
        local best_preds ""

        // Try pairs first (most derived vars are sums/diffs of 2-3 base vars)
        forvalues i = 1/`npred' {
            if `found_formula' continue
            local p1: word `i' of `all_preds'
            local j = `i' + 1
            forvalues j = `j'/`npred' {
                if `found_formula' continue
                local p2: word `j' of `all_preds'
                cap qui regress `v' `p1' `p2'
                if _rc continue
                if e(r2) > 0.9999 {
                    local found_formula = 1
                    local best_preds "`p1' `p2'"
                }
            }
        }

        // Try triples if pairs didn't work
        if !`found_formula' & `npred' >= 3 {
            forvalues i = 1/`npred' {
                if `found_formula' continue
                local p1: word `i' of `all_preds'
                local j = `i' + 1
                forvalues j = `j'/`npred' {
                    if `found_formula' continue
                    local p2: word `j' of `all_preds'
                    local k = `j' + 1
                    forvalues k = `k'/`npred' {
                        if `found_formula' continue
                        local p3: word `k' of `all_preds'
                        cap qui regress `v' `p1' `p2' `p3'
                        if _rc continue
                        if e(r2) > 0.9999 {
                            local found_formula = 1
                            local best_preds "`p1' `p2' `p3'"
                        }
                    }
                }
            }
        }

        if `found_formula' {
            // Re-run regression with best predictors to get coefficients
            qui regress `v' `best_preds'

            // This variable is derived - save the regression formula
            local derived_vars `derived_vars' `v'

            // Store formula in a simpler format using global macros
            local n_derived: word count `derived_vars'

            // Build expression from coefficients
            local expr ""
            local first = 1
            foreach p of local best_preds {
                local coef = round(_b[`p'], 0.0001)
                // Skip near-zero coefficients
                if abs(`coef') > 0.0001 {
                    if `first' {
                        local expr "(`coef')*`p'"
                        local first = 0
                    }
                    else {
                        local expr "`expr'+(`coef')*`p'"
                    }
                    local base_vars `base_vars' `p'
                }
            }
            local const = round(_b[_cons], 0.0001)
            if abs(`const') > 0.0001 {
                local expr "`expr'+(`const')"
            }

            // Store formula in numbered globals (will be cleaned up later)
            // Note: Global names cannot start with underscore in Stata
            local gname "SYNTHDATA_derived_`n_derived'_name"
            local gexpr "SYNTHDATA_derived_`n_derived'_expr"
            global `gname' `v'
            global `gexpr' `expr'
        }
    }

    // Remove duplicates from base_vars
    local base_vars: list uniq base_vars

    // Return count of derived vars (formulas are in globals)
    local n_derived: word count `derived_vars'

    return local derived_vars `derived_vars'
    return local base_vars `base_vars'
    return scalar n_derived = `n_derived'
end

// =============================================================================
// CATEGORICAL ASSOCIATION DETECTION
// =============================================================================
// Detects strongly associated categorical variables using Cramér's V.
// Associated variables are grouped for joint synthesis to preserve their
// relationship (e.g., region and country, diagnosis and treatment).
//
// Cramér's V thresholds:
//   V > 0.5: Strong association - synthesize jointly
//   V > 0.3: Moderate association - consider joint synthesis
//
// Returns:
//   r(catgroups)     - groups of associated variables (quoted list)
//   r(joint_catvars) - all variables in groups
//   r(indep_catvars) - independent variables (not in any group)

program define _synthdata_detect_catassoc, rclass
    version 16.0
    syntax varlist

    local catgroups ""
    local joint_catvars ""
    local indep_catvars ""

    local ncats: word count `varlist'
    if `ncats' < 2 {
        return local catgroups ""
        return local joint_catvars ""
        return local indep_catvars `varlist'
        exit
    }

    // Build association matrix
    // For now, use a simpler approach: pair variables with V > 0.5
    local paired ""

    forvalues i = 1/`=`ncats'-1' {
        local v1: word `i' of `varlist'
        local v1_paired: list v1 in paired
        if `v1_paired' continue

        forvalues j = `=`i'+1'/`ncats' {
            local v2: word `j' of `varlist'
            local v2_paired: list v2 in paired
            if `v2_paired' continue

            // Compute Cramér's V
            cap qui tab `v1' `v2', chi2
            if _rc continue
            if r(chi2) == . continue

            local chi2 = r(chi2)
            local n = r(N)
            local r = r(r)
            local c = r(c)
            local minrc = min(`r', `c') - 1

            if `minrc' <= 0 | `n' <= 0 continue

            local cramers_v = sqrt(`chi2' / (`n' * `minrc'))

            // Strong association threshold
            if `cramers_v' > 0.5 {
                local catgroups `"`catgroups' "`v1' `v2'""'
                local paired `paired' `v1' `v2'
                local joint_catvars `joint_catvars' `v1' `v2'
            }
        }
    }

    // Remaining vars are independent
    local indep_catvars: list varlist - joint_catvars

    // Remove duplicates
    local joint_catvars: list uniq joint_catvars

    return local catgroups `"`catgroups'"'
    return local joint_catvars `"`joint_catvars'"'
    return local indep_catvars `"`indep_catvars'"'
end

// =============================================================================
// RECONSTRUCT DERIVED VARIABLES
// =============================================================================
// Reconstructs derived variables from their base variables using stored formulas.

program define _synthdata_reconstruct_derived
    version 16.0
    syntax, n_derived(integer)

    // Reconstruct each derived variable using formulas stored in globals
    // Note: Global names use SYNTHDATA prefix (no leading underscore)
    forvalues i = 1/`n_derived' {
        local vname = "${SYNTHDATA_derived_`i'_name}"
        local expr = "${SYNTHDATA_derived_`i'_expr}"

        if "`vname'" == "" | "`expr'" == "" {
            di as txt "    Warning: Missing formula for derived variable `i'"
            continue
        }

        // Check if variable exists (shouldn't, but be safe)
        cap drop `vname'

        // Generate the derived variable from the expression
        cap qui gen double `vname' = `expr'
        if _rc {
            di as txt "    Warning: Could not reconstruct `vname' (rc=`=_rc')"
            di as txt "    Expression was: `expr'"
        }

        // Clean up globals
        macro drop SYNTHDATA_derived_`i'_name
        macro drop SYNTHDATA_derived_`i'_expr
    }
end

// Store original variable bounds
program define _synthdata_storebounds
    version 16.0
    syntax varlist, saving(string)
    
    tempname memhold
    postfile `memhold' str32 varname double(vmin vmax) using `saving', replace
    
    foreach v of local varlist {
        qui su `v', meanonly
        post `memhold' ("`v'") (r(min)) (r(max))
    }
    
    postclose `memhold'
end

// Store original statistics (numeric variables only)
program define _synthdata_stats
    version 16.0
    syntax varlist, saving(string)
    
    tempname memhold
    postfile `memhold' str32 varname double(mean sd min max p25 p50 p75 N) using `saving', replace
    
    foreach v of local varlist {
        cap confirm numeric variable `v'
        if _rc continue
        
        qui su `v', detail
        if r(N) > 0 {
            post `memhold' ("`v'") (r(mean)) (r(sd)) (r(min)) (r(max)) (r(p25)) (r(p50)) (r(p75)) (r(N))
        }
    }
    
    postclose `memhold'
end

// =============================================================================
// PARAMETRIC SYNTHESIS METHOD
// =============================================================================
// Uses multivariate normal distribution with Cholesky decomposition to preserve
// correlation structure among continuous variables. Categorical variables are
// synthesized independently using observed frequency distributions.
//
// Algorithm:
// 1. Compute means, SDs, and covariance matrix from original data
// 2. Regularize covariance matrix if not positive definite
// 3. Generate multivariate normal draws via Cholesky: X = Z * L' + mu
// 4. Draw categorical variables from observed frequency distributions
// 5. Handle string and date variables appropriately

program define _synthdata_parametric
    version 16.0
    syntax, n(integer) [catvars(varlist) contvars(varlist) datevars(varlist) ///
        strvars(string) origdata(string) empirical smooth correlations ///
        mincell(integer 5) trim(real 0)]

    local orig_n = _N

    // Count variables for progress reporting
    local ncont: word count `contvars'
    local ncat: word count `catvars'
    local nstr: word count `strvars'
    local ndate: word count `datevars'
    local ntotal = `ncont' + `ncat' + `nstr' + `ndate'

    // -------------------------------------------------------------------------
    // STEP 1: Compute continuous variable parameters (mean, SD, covariance)
    // -------------------------------------------------------------------------
    // For empirical synthesis: store sorted values for quantile mapping
    // For parametric (normal) synthesis: store mean, SD, covariance matrix

    if `ncont' > 0 {
        if "`empirical'" != "" {
            di as txt "    [1/4] Storing sorted values for empirical synthesis (`ncont' variables)..."
        }
        else {
            di as txt "    [1/4] Computing continuous variable parameters (`ncont' variables)..."
        }

        // Allocate matrices for means, SDs, and bounds
        tempname means sds mins maxs
        matrix `means' = J(1, `ncont', .)
        matrix `sds' = J(1, `ncont', .)
        matrix `mins' = J(1, `ncont', .)
        matrix `maxs' = J(1, `ncont', .)

        // For empirical synthesis, store sorted values
        // NOTE: We use Mata directly to avoid Stata matrix size limits (11k rows in SE)
        // Sorted values are stored in a tempfile to handle large datasets
        if "`empirical'" != "" {
            tempfile sorteddata

            // Store sorted values for each variable in a tempfile
            // This approach works for any dataset size and avoids matrix limitations
            preserve

            // Keep only continuous variables, sort and save
            qui keep `contvars'

            // For each variable, sort and store non-missing values
            local varnum = 1
            foreach v of local contvars {
                // Create a sorted copy of each variable
                tempvar sortorder`varnum'
                qui gen long `sortorder`varnum'' = _n
                local ++varnum
            }

            qui save `sorteddata', replace
            restore
        }

        local i = 1
        foreach v of local contvars {
            qui su `v', detail
            matrix `means'[1, `i'] = r(mean)
            matrix `sds'[1, `i'] = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))

            if `trim' > 0 {
                // Use percentiles for trimming
                local plo = `trim'
                local phi = 100 - `trim'
                // Stata stores p1, p5, p10, p25, p50, p75, p90, p95, p99
                if `plo' <= 1 {
                    matrix `mins'[1, `i'] = r(p1)
                }
                else if `plo' <= 5 {
                    matrix `mins'[1, `i'] = r(p5)
                }
                else {
                    matrix `mins'[1, `i'] = r(p10)
                }
                if `phi' >= 99 {
                    matrix `maxs'[1, `i'] = r(p99)
                }
                else if `phi' >= 95 {
                    matrix `maxs'[1, `i'] = r(p95)
                }
                else {
                    matrix `maxs'[1, `i'] = r(p90)
                }
            }
            else {
                matrix `mins'[1, `i'] = r(min)
                matrix `maxs'[1, `i'] = r(max)
            }

            local ++i
        }

        // Compute correlation matrix (needed for both normal and empirical+corr)
        // First check for complete cases (observations with all contvars non-missing)
        local no_complete_cases = 0
        if `ncont' > 1 {
            // Build condition for complete cases
            local complete_cond "1"
            foreach v of local contvars {
                local complete_cond "`complete_cond' & !missing(`v')"
            }
            qui count if `complete_cond'
            local n_complete = r(N)

            if `n_complete' == 0 {
                // No complete cases - cannot compute correlations
                di as txt "Warning: No observations with all continuous variables non-missing."
                di as txt "         Correlations cannot be preserved; variables will be synthesized independently."
                local no_complete_cases = 1
            }
            else {
                // Have complete cases - compute correlation matrix
                qui correlate `contvars', cov
                tempname covmat corrmat
                matrix `covmat' = r(C)

                // Also compute correlation matrix for empirical copula approach
                qui correlate `contvars'
                matrix `corrmat' = r(C)

                // Check for positive definiteness, regularize if needed
                mata: st_local("isposdef", strofreal(_synthdata_isposdef(st_matrix("`covmat'"))))
                if `isposdef' == 0 {
                    di as txt "Note: Covariance matrix regularized for positive definiteness"
                    mata: st_matrix("`covmat'", _synthdata_regularize(st_matrix("`covmat'")))
                }

                // Check correlation matrix too
                mata: st_local("isposdef_corr", strofreal(_synthdata_isposdef(st_matrix("`corrmat'"))))
                if `isposdef_corr' == 0 {
                    mata: st_matrix("`corrmat'", _synthdata_regularize(st_matrix("`corrmat'")))
                }
            }
        }
    }
    
    // -------------------------------------------------------------------------
    // STEP 2: Compute categorical variable frequency distributions
    // -------------------------------------------------------------------------
    // For each categorical variable, store:
    // - Unique values (levels)
    // - Frequency counts (with rare category pooling if mincell > 0)
    // - Value labels for restoration

    if `ncat' > 0 {
        di as txt "    [2/4] Computing categorical variable frequencies (`ncat' variables)..."
        local catnum = 1
        foreach v of local catvars {
            qui levelsof `v', local(levels_`catnum')
            local nlevels_`catnum': word count `levels_`catnum''

            // Handle all-missing categorical variables (zero levels)
            if `nlevels_`catnum'' == 0 {
                // No non-missing values - skip matrix creation
                // Will generate all missing in synthesis step
                local vallbl_`catnum' ""
                local ++catnum
                continue
            }

            // Store frequencies
            tempname catfreq_`catnum'
            matrix `catfreq_`catnum'' = J(`nlevels_`catnum'', 2, .)

            local j = 1
            foreach lev of local levels_`catnum' {
                qui count if `v' == `lev'
                local freq = r(N)
                // Pool rare categories
                if `freq' < `mincell' & `mincell' > 0 {
                    local freq = `mincell'
                }
                matrix `catfreq_`catnum''[`j', 1] = `lev'
                matrix `catfreq_`catnum''[`j', 2] = `freq'
                local ++j
            }

            // Store value label if exists
            local vallbl_`catnum': value label `v'
            local ++catnum
        }
    }
    
    // -------------------------------------------------------------------------
    // STEP 2b: String variables (high-cardinality support)
    // -------------------------------------------------------------------------
    // String variables are synthesized entirely in Mata to support high-cardinality
    // variables (thousands of unique values like ATC codes, substance names, etc.)
    // without hitting Stata's macro or matrix limits. No preprocessing needed here.

    if `nstr' > 0 {
        di as txt "    [2/4] String variables will be synthesized from original data (`nstr' variables)..."
    }
    
    // -------------------------------------------------------------------------
    // STEP 2c: Compute date variable parameters
    // -------------------------------------------------------------------------
    // Dates are treated similarly to continuous variables (mean, SD, bounds)
    // but are rounded to integer values and formatted appropriately.

    if `ndate' > 0 {
        di as txt "    [2/4] Computing date variable parameters (`ndate' variables)..."
        local datenum = 1
        foreach v of local datevars {
            qui su `v', detail
            local datemean_`datenum' = r(mean)
            local datesd_`datenum' = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))
            local datemin_`datenum' = r(min)
            local datemax_`datenum' = r(max)
            local datefmt_`datenum': format `v'
            local ++datenum
        }
    }
    
    // =========================================================================
    // STEP 3: Create synthetic dataset structure
    // =========================================================================
    di as txt "    [3/4] Creating synthetic dataset (`n' observations)..."
    qui drop _all
    qui set obs `n'

    // -------------------------------------------------------------------------
    // STEP 4: Generate synthetic values for each variable type
    // -------------------------------------------------------------------------

    // --- Generate continuous variables ---
    // Two approaches available:
    //   1. EMPIRICAL: Uses quantile mapping from sorted original values
    //      - Always stays within original [min, max] bounds
    //      - Preserves original distribution shape (skewness, kurtosis, etc.)
    //      - Uses Gaussian copula to preserve correlations when ncont > 1
    //   2. PARAMETRIC (default): Uses multivariate normal
    //      - Assumes normality, values can exceed original range
    //      - Faster for very large datasets

    if `ncont' > 0 {
        local smooth_flag = ("`smooth'" != "")

        if "`empirical'" != "" {
            // EMPIRICAL QUANTILE SYNTHESIS
            // NOTE: We avoid Stata matrices entirely to support datasets larger than
            // Stata/SE's 11,000 row matrix limit. Instead, we use Mata's st_data()
            // which can handle any dataset size.
            di as txt "    [4/4] Generating continuous variables via empirical quantiles (`ncont')..."

            // Create variables first
            foreach v of local contvars {
                qui gen double `v' = .
            }

            if `ncont' == 1 | `no_complete_cases' {
                // Single variable or no correlation: generate each independently
                // This is memory-efficient - loads sorted values one variable at a time
                foreach v of local contvars {
                    // Load sorted values from original data directly into Mata
                    mata: _synthdata_genquantile_fromdata("`v'", "`sorteddata'", `n', `smooth_flag')
                }
            }
            else {
                // Multiple variables: Gaussian copula + quantile mapping
                // This preserves correlations while maintaining bounded empirical distributions
                // Uses Mata's st_data() to load sorted values (no matrix size limits)
                mata: _synth_genquant_corr_fromdata("`contvars'", "`sorteddata'", ///
                    st_matrix("`corrmat'"), `n', `smooth_flag')
            }
        }
        else {
            // PARAMETRIC (NORMAL) SYNTHESIS
            di as txt "    [4/4] Generating continuous variables (`ncont')..."

            if `ncont' == 1 {
                // Single variable: simple univariate normal N(mean, sd)
                local v: word 1 of `contvars'
                qui gen double `v' = rnormal(`=`means'[1,1]', `=`sds'[1,1]')
            }
            else if `no_complete_cases' {
                // No complete cases: generate each variable independently
                local i = 1
                foreach v of local contvars {
                    qui gen double `v' = rnormal(`=`means'[1, `i']', `=`sds'[1, `i']')
                    local ++i
                }
            }
            else {
                // Multiple variables: multivariate normal via Cholesky decomposition
                // IMPORTANT: Variables must exist before Mata st_store() call
                foreach v of local contvars {
                    qui gen double `v' = .
                }
                // Generate MVN: X = Z * L' + mu, where L = cholesky(Sigma)
                mata: _synthdata_genmvn("`contvars'", st_matrix("`means'"), st_matrix("`covmat'"), `n')
            }
        }
    }

    // --- Generate categorical variables ---
    // Draws from observed frequency distribution (with rare category pooling)
    if `ncat' > 0 {
        di as txt "    [4/4] Generating categorical variables (`ncat')..."
        local catnum = 1
        foreach v of local catvars {
            qui gen double `v' = .

            // Handle all-missing categorical variables (zero levels)
            if `nlevels_`catnum'' == 0 {
                // Variable was all missing - leave as missing
                local ++catnum
                continue
            }

            // Draw from categorical distribution using inverse CDF method
            mata: _synthdata_drawcat("`v'", st_matrix("`catfreq_`catnum''"), `n')

            // Restore value label for categorical interpretation
            if "`vallbl_`catnum''" != "" {
                cap label values `v' `vallbl_`catnum''
            }
            local ++catnum
        }
    }

    // --- Generate string variables ---
    // Uses Mata-based synthesis to handle high-cardinality strings (thousands of unique values)
    // without hitting Stata's macro limits or requiring O(n*nlevels) replace loops
    if `nstr' > 0 {
        di as txt "    [4/4] Generating string variables (`nstr')..."
        // Synthesize all string variables directly in Mata from original data
        mata: _synthdata_synthstr_multi("`strvars'", "`origdata'", `n')
    }
    
    // --- Generate date variables ---
    // Treated as continuous but rounded to integer and bounded
    if `ndate' > 0 {
        di as txt "    [4/4] Generating date variables (`ndate')..."
        local datenum = 1
        foreach v of local datevars {
            // Generate from normal distribution centered on original mean
            qui gen double `v' = round(rnormal(`datemean_`datenum'', `datesd_`datenum''))
            // Clip to original date range
            qui replace `v' = max(`v', `datemin_`datenum'')
            qui replace `v' = min(`v', `datemax_`datenum'')
            // Restore original date format
            format `v' `datefmt_`datenum''
            local ++datenum
        }
    }
end

// =============================================================================
// SMART SYNTHESIS METHOD
// =============================================================================
// Adaptive synthesis that automatically uses the best approach for each variable:
//   1. Non-normal continuous variables -> empirical quantile synthesis
//   2. Normal continuous variables -> parametric (MVN) synthesis
//   3. Associated categoricals -> joint synthesis
//   4. Independent categoricals -> marginal frequency synthesis
//   5. Dates -> bounded normal synthesis
//   6. Strings -> frequency-based synthesis
//
// This method combines all automatic detection features for realistic synthesis
// with minimal user configuration.

program define _synthdata_smart
    version 16.0
    syntax, n(integer) [catvars(varlist) contvars(varlist) ///
        datevars(varlist) strvars(string) origdata(string) ///
        empirical_vars(string) normal_vars(string) ///
        catgroups(string asis) joint_catvars(string) indep_catvars(string) ///
        smooth correlations ///
        mincell(integer 5) trim(real 0)]

    local orig_n = _N

    // Count variables for progress reporting
    local ncont: word count `contvars'
    local ncat: word count `catvars'
    local nstr: word count `strvars'
    local ndate: word count `datevars'
    local n_emp: word count `empirical_vars'
    local n_norm: word count `normal_vars'

    // -------------------------------------------------------------------------
    // STEP 1: Prepare for synthesis - compute all required parameters
    // -------------------------------------------------------------------------

    // 1a. Store sorted values for empirical variables
    if `n_emp' > 0 {
        di as txt "    [1/5] Preparing empirical variables (`n_emp')..."
        tempfile sorteddata_emp
        preserve
        qui keep `empirical_vars'
        qui save `sorteddata_emp', replace
        restore
    }

    // 1b. Compute MVN parameters for normal variables
    if `n_norm' > 0 {
        di as txt "    [2/5] Computing parametric parameters (`n_norm')..."
        tempname means_n sds_n
        matrix `means_n' = J(1, `n_norm', .)
        matrix `sds_n' = J(1, `n_norm', .)

        local i = 1
        foreach v of local normal_vars {
            qui su `v', detail
            matrix `means_n'[1, `i'] = r(mean)
            matrix `sds_n'[1, `i'] = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))
            local ++i
        }

        // Compute covariance matrix for normal variables
        if `n_norm' > 1 {
            qui correlate `normal_vars', cov
            tempname covmat_n corrmat_n
            matrix `covmat_n' = r(C)
            qui correlate `normal_vars'
            matrix `corrmat_n' = r(C)

            // Regularize if needed
            mata: st_local("isposdef", strofreal(_synthdata_isposdef(st_matrix("`covmat_n'"))))
            if `isposdef' == 0 {
                mata: st_matrix("`covmat_n'", _synthdata_regularize(st_matrix("`covmat_n'")))
            }
            mata: st_local("isposdef_corr", strofreal(_synthdata_isposdef(st_matrix("`corrmat_n'"))))
            if `isposdef_corr' == 0 {
                mata: st_matrix("`corrmat_n'", _synthdata_regularize(st_matrix("`corrmat_n'")))
            }
        }
    }

    // 1c. Compute categorical frequencies
    if `ncat' > 0 {
        di as txt "    [3/5] Computing categorical frequencies (`ncat')..."
        local catnum = 1
        foreach v of local catvars {
            qui levelsof `v', local(levels_`catnum')
            local nlevels_`catnum': word count `levels_`catnum''

            if `nlevels_`catnum'' == 0 {
                local vallbl_`catnum' ""
                local ++catnum
                continue
            }

            tempname catfreq_`catnum'
            matrix `catfreq_`catnum'' = J(`nlevels_`catnum'', 2, .)

            local j = 1
            foreach lev of local levels_`catnum' {
                qui count if `v' == `lev'
                local freq = r(N)
                if `freq' < `mincell' & `mincell' > 0 {
                    local freq = `mincell'
                }
                matrix `catfreq_`catnum''[`j', 1] = `lev'
                matrix `catfreq_`catnum''[`j', 2] = `freq'
                local ++j
            }

            local vallbl_`catnum': value label `v'
            local ++catnum
        }
    }

    // 1d. Compute date parameters
    if `ndate' > 0 {
        di as txt "    [3/5] Computing date parameters (`ndate')..."
        local datenum = 1
        foreach v of local datevars {
            qui su `v', detail
            local datemean_`datenum' = r(mean)
            local datesd_`datenum' = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))
            local datemin_`datenum' = r(min)
            local datemax_`datenum' = r(max)
            local datefmt_`datenum': format `v'
            local ++datenum
        }
    }

    // -------------------------------------------------------------------------
    // STEP 2: Create empty synthetic dataset
    // -------------------------------------------------------------------------
    di as txt "    [4/5] Creating synthetic dataset (`n' observations)..."
    qui drop _all
    qui set obs `n'

    // -------------------------------------------------------------------------
    // STEP 3: Generate synthetic values using adaptive methods
    // -------------------------------------------------------------------------
    di as txt "    [5/5] Generating synthetic values..."

    // 3a. Generate empirical variables via quantile mapping
    if `n_emp' > 0 {
        foreach v of local empirical_vars {
            qui gen double `v' = .
        }
        // Use correlated empirical synthesis if multiple vars
        if `n_emp' == 1 {
            local v: word 1 of `empirical_vars'
            local smooth_flag = ("`smooth'" != "")
            mata: _synthdata_genquantile_fromdata("`v'", "`sorteddata_emp'", `n', `smooth_flag')
        }
        else {
            // For correlated empirical: need to compute correlation of empirical vars
            preserve
            qui use `sorteddata_emp', clear
            qui correlate `empirical_vars'
            tempname corrmat_emp
            matrix `corrmat_emp' = r(C)
            mata: st_local("isposdef_emp", strofreal(_synthdata_isposdef(st_matrix("`corrmat_emp'"))))
            if `isposdef_emp' == 0 {
                mata: st_matrix("`corrmat_emp'", _synthdata_regularize(st_matrix("`corrmat_emp'")))
            }
            restore
            local smooth_flag = ("`smooth'" != "")
            mata: _synth_genquant_corr_fromdata("`empirical_vars'", "`sorteddata_emp'", ///
                st_matrix("`corrmat_emp'"), `n', `smooth_flag')
        }
    }

    // 3b. Generate normal variables via MVN
    if `n_norm' > 0 {
        foreach v of local normal_vars {
            qui gen double `v' = .
        }
        if `n_norm' == 1 {
            local v: word 1 of `normal_vars'
            qui replace `v' = rnormal(`=`means_n'[1,1]', `=`sds_n'[1,1]')
        }
        else {
            mata: _synthdata_genmvn("`normal_vars'", st_matrix("`means_n'"), st_matrix("`covmat_n'"), `n')
        }
    }

    // 3c. Generate categorical variables
    // Handle joint categoricals (associated pairs) separately from independent ones
    if `ncat' > 0 {
        // First, synthesize joint categorical groups
        local joint_vars_done ""
        if `"`catgroups'"' != "" {
            local remaining_groups `"`catgroups'"'
            while `"`remaining_groups'"' != "" {
                // Extract next group (pair of variables)
                gettoken group remaining_groups : remaining_groups

                // Parse the pair
                tokenize `group'
                local v1 `1'
                local v2 `2'

                if "`v1'" == "" | "`v2'" == "" continue

                // Sample from joint distribution of this pair
                // Load original data to get joint distribution
                preserve
                qui use `origdata', clear

                // Keep only non-missing combinations
                qui keep if !missing(`v1') & !missing(`v2')

                // Contract to get unique combinations with frequencies
                qui contract `v1' `v2', freq(_jfreq)

                // Apply mincell threshold
                if `mincell' > 0 {
                    qui replace _jfreq = max(_jfreq, `mincell')
                }

                local njoint = _N

                if `njoint' > 0 {
                    // Store joint distribution in matrix
                    tempname jointfreq
                    matrix `jointfreq' = J(`njoint', 3, .)
                    forvalues i = 1/`njoint' {
                        matrix `jointfreq'[`i', 1] = `v1'[`i']
                        matrix `jointfreq'[`i', 2] = `v2'[`i']
                        matrix `jointfreq'[`i', 3] = _jfreq[`i']
                    }

                    // Store value labels
                    local vallbl_v1: value label `v1'
                    local vallbl_v2: value label `v2'

                    restore

                    // Generate both variables jointly
                    qui gen double `v1' = .
                    qui gen double `v2' = .

                    // Draw from joint distribution
                    mata: _synthdata_drawjoint("`v1'", "`v2'", st_matrix("`jointfreq'"), `n')

                    // Restore value labels
                    if "`vallbl_v1'" != "" {
                        cap label values `v1' `vallbl_v1'
                    }
                    if "`vallbl_v2'" != "" {
                        cap label values `v2' `vallbl_v2'
                    }

                    local joint_vars_done `joint_vars_done' `v1' `v2'
                }
                else {
                    restore
                }
            }
        }

        // Now synthesize independent categoricals (not in any joint group)
        local catnum = 1
        foreach v of local catvars {
            // Skip if already done as part of joint group
            local is_joint: list v in joint_vars_done
            if `is_joint' {
                local ++catnum
                continue
            }

            qui gen double `v' = .

            if `nlevels_`catnum'' == 0 {
                local ++catnum
                continue
            }

            mata: _synthdata_drawcat("`v'", st_matrix("`catfreq_`catnum''"), `n')

            if "`vallbl_`catnum''" != "" {
                cap label values `v' `vallbl_`catnum''
            }
            local ++catnum
        }
    }

    // 3d. Generate string variables
    if `nstr' > 0 {
        mata: _synthdata_synthstr_multi("`strvars'", "`origdata'", `n')
    }

    // 3e. Generate date variables
    if `ndate' > 0 {
        local datenum = 1
        foreach v of local datevars {
            qui gen double `v' = round(rnormal(`datemean_`datenum'', `datesd_`datenum''))
            qui replace `v' = max(`v', `datemin_`datenum'')
            qui replace `v' = min(`v', `datemax_`datenum'')
            format `v' `datefmt_`datenum''
            local ++datenum
        }
    }

    di as txt "    Smart synthesis complete."
end

// Bootstrap synthesis method
program define _synthdata_bootstrap
    version 16.0
    syntax, n(integer) noise(real) [catvars(varlist) contvars(varlist) ///
        datevars(varlist) strvars(string) origdata(string) ///
        mincell(integer 5) trim(real 0)]

    local orig_n = _N

    // Store SDs for noise addition
    if "`contvars'" != "" {
        foreach v of local contvars {
            qui su `v'
            local sd_`v' = cond(r(sd) == 0 | r(sd) == ., 0, r(sd))
        }
    }
    if "`datevars'" != "" {
        foreach v of local datevars {
            qui su `v'
            local sd_`v' = cond(r(sd) == 0 | r(sd) == ., 0, r(sd))
            local fmt_`v': format `v'
        }
    }
    
    // Store categorical levels for perturbation
    if "`catvars'" != "" {
        foreach v of local catvars {
            qui levelsof `v', local(levels_`v')
            local nlevels_`v': word count `levels_`v''
        }
    }
    
    // Sample with replacement
    qui bsample `n'
    
    // Add noise to continuous variables
    if "`contvars'" != "" {
        foreach v of local contvars {
            if `sd_`v'' > 0 {
                qui replace `v' = `v' + rnormal(0, `noise' * `sd_`v'')
            }
        }
    }
    
    // Add noise to date variables
    if "`datevars'" != "" {
        foreach v of local datevars {
            if `sd_`v'' > 0 {
                qui replace `v' = round(`v' + rnormal(0, `noise' * `sd_`v''))
            }
            format `v' `fmt_`v''
        }
    }
    
    // Perturb categorical variables (swap with small probability)
    if "`catvars'" != "" & `noise' > 0 {
        foreach v of local catvars {
            local nlevels = `nlevels_`v''
            if `nlevels' > 1 {
                tempvar u randidx
                qui gen double `u' = runiform()
                qui gen long `randidx' = ceil(runiform() * `nlevels')
                
                // Get level values into a matrix for lookup
                tempname levmat
                matrix `levmat' = J(`nlevels', 1, .)
                local j = 1
                foreach lev of local levels_`v' {
                    matrix `levmat'[`j', 1] = `lev'
                    local ++j
                }
                
                // Swap with probability noise/10
                forvalues j = 1/`nlevels' {
                    qui replace `v' = `levmat'[`j', 1] if `u' < `=`noise'/10' & `randidx' == `j'
                }
                drop `u' `randidx'
            }
        }
    }
end

// Permute method (breaks all relationships)
program define _synthdata_permute
    version 16.0
    syntax varlist, n(integer) origdata(string)
    
    local orig_n = _N
    
    // If n > orig_n, expand first
    if `n' > `orig_n' {
        local expand_factor = ceil(`n' / `orig_n')
        qui expand `expand_factor'
    }
    
    // Permute each variable independently
    foreach v of local varlist {
        tempvar order newval
        qui gen double `order' = runiform()
        qui gen `newval' = `v'
        sort `order'
        qui replace `v' = `newval'[_n]
        drop `order' `newval'
    }
    
    // Trim to n observations
    if _N > `n' {
        qui keep in 1/`n'
    }
    else if _N < `n' {
        // Need more obs - sample with replacement from permuted data
        local deficit = `n' - _N
        tempfile permuted
        qui save `permuted'
        qui bsample `deficit'
        qui append using `permuted'
    }
end

// =============================================================================
// SEQUENTIAL SYNTHESIS METHOD
// =============================================================================
// Generates synthetic data using conditional modeling approach:
//   1. First variable drawn from its marginal distribution
//   2. Each subsequent variable modeled conditional on previous variables
//   3. For continuous: linear regression + random residuals
//   4. For categorical/string: marginal frequency distribution
//
// Advantages: Handles mixed variable types naturally
// Limitations: Order-dependent, may not fully preserve correlations
//
// Reference: Similar to MICE imputation approach but for synthesis

program define _synthdata_sequential
    version 16.0
    syntax, n(integer) [catvars(varlist) contvars(varlist) ///
        datevars(varlist) strvars(string) origdata(string) ///
        mincell(integer 5) trim(real 0)]

    // -------------------------------------------------------------------------
    // STEP 1: Determine synthesis order and variable count
    // -------------------------------------------------------------------------
    // Order: continuous -> dates -> categorical -> string
    // This order helps continuous regression models work better
    local allvars `contvars' `datevars' `catvars' `strvars'
    local nvars: word count `allvars'

    if "`allvars'" == "" {
        di as error "no variables to synthesize"
        exit 102
    }

    di as txt "    Sequential synthesis: `nvars' variables"

    // -------------------------------------------------------------------------
    // STEP 2: Pre-compute variable properties for all variables
    // -------------------------------------------------------------------------
    local vnum = 0
    foreach v of local allvars {
        local iscat_`v': list v in catvars
        local isdate_`v': list v in datevars
        local isstr_`v': list v in strvars

        // String variables: no preprocessing needed (handled in Mata)
        if `iscat_`v'' & !`isstr_`v'' {
            qui levelsof `v', local(levels_`v')
        }

        // Store format
        local fmt_`v': format `v'
    }
    
    // -------------------------------------------------------------------------
    // STEP 3: Create empty synthetic dataset and synthesize sequentially
    // -------------------------------------------------------------------------
    tempfile origdata_temp
    qui save `origdata_temp'

    qui drop _all
    qui set obs `n'

    local prevvars ""
    local vnum = 0

    foreach v of local allvars {
        local ++vnum
        di as txt "      Variable `vnum'/`nvars': `v'" _continue

        // Load original data to fit conditional model
        preserve
        qui use `origdata_temp', clear

        local iscat = `iscat_`v''
        local isdate = `isdate_`v''
        local isstr = `isstr_`v''
        
        if "`prevvars'" == "" {
            // First variable: draw from marginal
            if `isstr' {
                // String: synthesized directly from original data via Mata
                // (no preprocessing needed - handled in generation step)
            }
            else if `iscat' {
                // Categorical: store frequencies
                qui tab `v', matrow(__vals) matcell(__freqs)
                tempname catvals catfreqs
                matrix `catvals' = __vals
                matrix `catfreqs' = __freqs
                cap matrix drop __vals __freqs
            }
            else {
                // Continuous/date: store mean/sd
                qui su `v'
                local vmean = r(mean)
                local vsd = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))
            }
        }
        else {
            // Regress on previous variables
            if `iscat' & !`isstr' {
                // Try regression, fall back to marginal
                qui tab `v', matrow(__vals) matcell(__freqs)
                tempname catvals catfreqs
                matrix `catvals' = __vals
                matrix `catfreqs' = __freqs
                cap matrix drop __vals __freqs
                local use_marginal = 1
            }
            else if `isstr' {
                // String: synthesized directly from original data via Mata
                // (no preprocessing needed - handled in generation step)
            }
            else {
                // Continuous: linear regression
                local use_reg = 0
                cap regress `v' `prevvars'
                if !_rc & e(N) > 0 {
                    tempname betamat
                    matrix `betamat' = e(b)
                    local rmse = e(rmse)
                    if `rmse' == 0 | `rmse' == . {
                        qui su `v'
                        local rmse = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))
                    }
                    local use_reg = 1
                    local reg_const = _b[_cons]
                }
                else {
                    qui su `v'
                    local vmean = r(mean)
                    local vsd = cond(r(sd) == 0 | r(sd) == ., 1, r(sd))
                    local use_reg = 0
                }
            }
        }
        
        restore
        
        // Generate synthetic variable
        if `isstr' {
            // String variable: synthesize directly from original data via Mata
            // This handles high-cardinality strings without local macro limits
            mata: _synthdata_synthstr_fromdata("`v'", "`origdata_temp'", `n')
            di as txt " (string, marginal)"
        }
        else if `iscat' {
            qui gen double `v' = .
            // Draw from marginal frequency distribution
            tempname catcomb
            matrix `catcomb' = `catvals', `catfreqs'
            mata: _synthdata_drawcat("`v'", st_matrix("`catcomb'"), `n')
            di as txt " (categorical, marginal)"
        }
        else {
            // Continuous or date
            // Note: use_reg is only defined when prevvars != "", so check separately
            if "`prevvars'" == "" {
                qui gen double `v' = rnormal(`vmean', `vsd')
            }
            else if `use_reg' != 1 {
                qui gen double `v' = rnormal(`vmean', `vsd')
            }
            else {
                // Predicted + residual
                qui gen double `v' = `reg_const'
                local ncols = colsof(`betamat') - 1
                local pv = 1
                foreach pvar of local prevvars {
                    if `pv' <= `ncols' {
                        qui replace `v' = `v' + `=`betamat'[1, `pv']' * `pvar'
                    }
                    local ++pv
                }
                qui replace `v' = `v' + rnormal(0, `rmse')
            }
            
            if `isdate' {
                qui replace `v' = round(`v')
                format `v' `fmt_`v''
                di as txt " (date, regression)"
            }
            else {
                di as txt " (continuous, regression)"
            }
        }

        local prevvars `prevvars' `v'
    }

    di as txt "    Sequential synthesis complete."
end

// Apply user constraints via rejection/clipping
program define _synthdata_constraints
    version 16.0
    syntax, constraints(string asis) iterate(integer)
    
    local iter = 0
    local satisfied = 0
    
    while `iter' < `iterate' & !`satisfied' {
        local satisfied = 1
        
        // Parse and check each constraint
        local remaining `"`constraints'"'
        while `"`remaining'"' != "" {
            gettoken constraint remaining: remaining
            
            // Check if constraint is satisfied
            cap count if !(`constraint') & !missing(`constraint')
            if _rc {
                di as txt "Warning: constraint '`constraint'' could not be evaluated"
                continue
            }
            
            if r(N) > 0 {
                local satisfied = 0
                local nviolate = r(N)
                
                // Handle common patterns: var>=val, var<=val, var>val, var<val
                if regexm("`constraint'", "^([a-zA-Z_][a-zA-Z0-9_]*)>=(.+)$") {
                    local cvar = regexs(1)
                    local cval = regexs(2)
                    cap confirm variable `cvar'
                    if !_rc {
                        qui replace `cvar' = `cval' if `cvar' < `cval'
                    }
                }
                else if regexm("`constraint'", "^([a-zA-Z_][a-zA-Z0-9_]*)<=(.+)$") {
                    local cvar = regexs(1)
                    local cval = regexs(2)
                    cap confirm variable `cvar'
                    if !_rc {
                        qui replace `cvar' = `cval' if `cvar' > `cval'
                    }
                }
                else if regexm("`constraint'", "^([a-zA-Z_][a-zA-Z0-9_]*)>(.+)$") {
                    local cvar = regexs(1)
                    local cval = regexs(2)
                    cap confirm variable `cvar'
                    if !_rc {
                        qui replace `cvar' = `cval' + 0.001 if `cvar' <= `cval'
                    }
                }
                else if regexm("`constraint'", "^([a-zA-Z_][a-zA-Z0-9_]*)<(.+)$") {
                    local cvar = regexs(1)
                    local cval = regexs(2)
                    cap confirm variable `cvar'
                    if !_rc {
                        qui replace `cvar' = `cval' - 0.001 if `cvar' >= `cval'
                    }
                }
                // For var1 < var2 style constraints
                else if regexm("`constraint'", "^([a-zA-Z_][a-zA-Z0-9_]*)<([a-zA-Z_][a-zA-Z0-9_]*)$") {
                    local cvar1 = regexs(1)
                    local cvar2 = regexs(2)
                    cap confirm variable `cvar1'
                    if !_rc {
                        cap confirm variable `cvar2'
                        if !_rc {
                            // Swap values where constraint violated
                            tempvar tmp
                            qui gen double `tmp' = `cvar1' if `cvar1' >= `cvar2'
                            qui replace `cvar1' = `cvar2' if `cvar1' >= `cvar2'
                            qui replace `cvar2' = `tmp' if `tmp' != .
                            drop `tmp'
                        }
                    }
                }
            }
        }
        local ++iter
    }
    
    if !`satisfied' {
        // Final count of violations
        local remaining `"`constraints'"'
        local total_violations = 0
        while `"`remaining'"' != "" {
            gettoken constraint remaining: remaining
            cap count if !(`constraint') & !missing(`constraint')
            if !_rc {
                local total_violations = `total_violations' + r(N)
            }
        }
        if `total_violations' > 0 {
            di as txt "Warning: `total_violations' constraint violations remain after `iterate' iterations"
        }
    }
end

// Auto-detect and apply constraints
program define _synthdata_autoconstraints
    version 16.0
    syntax varlist, iterate(integer) origdata(string)
    
    local constraints ""
    
    preserve
    qui use `origdata', clear
    
    // Check for non-negative variables
    foreach v of local varlist {
        cap confirm numeric variable `v'
        if _rc continue
        
        qui su `v', meanonly
        if r(min) >= 0 {
            local constraints `"`constraints' "`v'>=0""'
        }
    }
    
    restore
    
    if `"`constraints'"' != "" {
        _synthdata_constraints, constraints(`constraints') iterate(`iterate')
    }
end

// Apply bounds
program define _synthdata_bounds
    version 16.0
    syntax, bounds(string asis)
    
    local remaining `"`bounds'"'
    while `"`remaining'"' != "" {
        gettoken spec remaining: remaining
        
        // Parse "varname min max"
        tokenize `"`spec'"'
        local v `1'
        local lo `2'
        local hi `3'
        
        cap confirm variable `v'
        if !_rc {
            cap confirm numeric variable `v'
            if !_rc {
                if "`lo'" != "" & "`lo'" != "." {
                    qui replace `v' = `lo' if `v' < `lo' & !missing(`v')
                }
                if "`hi'" != "" & "`hi'" != "." {
                    qui replace `v' = `hi' if `v' > `hi' & !missing(`v')
                }
            }
        }
        else {
            di as txt "Warning: variable `v' not found for bounds"
        }
    }
end

// Enforce no values outside observed range (with privacy buffer)
// PRIVACY CONSIDERATION: The noextreme option constrains synthetic data to avoid
// extreme outliers. However, using exact min/max values from the original data
// would leak information about the most extreme individuals (e.g., the exact
// highest salary or age in the dataset). This violates differential privacy principles.
// SOLUTION: We apply a 5% buffer to the bounds to prevent exact value leakage
// while still constraining outliers. The buffer is calculated as 5% of the
// original data range, and is subtracted from min and added to max.
program define _synthdata_noextreme
    version 16.0
    syntax varlist, boundsfile(string) [buffer(real 0.05)]

    // Load bounds into locals FIRST, before modifying data
    preserve
    qui use `boundsfile', clear
    local nbounds = _N

    forvalues i = 1/`nbounds' {
        local vn_`i' = varname[`i']
        local vmin_`i' = vmin[`i']
        local vmax_`i' = vmax[`i']

        // Calculate privacy buffer: 5% of the range by default
        // This prevents exact data leakage while still constraining outliers
        local range_`i' = `vmax_`i'' - `vmin_`i''
        if `range_`i'' > 0 {
            local buffer_`i' = `range_`i'' * `buffer'
            // Apply buffer: shrink the allowed range slightly
            local vmin_`i' = `vmin_`i'' + `buffer_`i''
            local vmax_`i' = `vmax_`i'' - `buffer_`i''
        }
    }
    restore

    // Now apply bounds (with privacy buffer) to synthetic data
    forvalues i = 1/`nbounds' {
        cap confirm variable `vn_`i''
        if !_rc {
            qui replace `vn_`i'' = `vmin_`i'' if `vn_`i'' < `vmin_`i'' & !missing(`vn_`i'')
            qui replace `vn_`i'' = `vmax_`i'' if `vn_`i'' > `vmax_`i'' & !missing(`vn_`i'')
        }
    }
end

// =========================================================================
// GENERATE SYNTHETIC ROW COUNTS PER ID
// =========================================================================
// This subroutine generates realistic row counts for synthetic IDs
// by sampling from or fitting the original row-count distribution
program define _synthdata_rowcounts
    version 16.0
    syntax, target_n_ids(integer) rowcount_dist(string) rowdist(string) ///
        rc_mean(real) rc_sd(real) rc_min(real) rc_max(real)

    // Load original row count distribution
    qui use "`rowcount_dist'", clear

    // Get the row count variable name (second variable in file)
    qui ds
    local varlist `r(varlist)'
    local rcvar: word 2 of `varlist'

    if "`rowdist'" == "exact" {
        // Use exact distribution - sample IDs with replacement
        // This preserves the exact shape of the distribution
        qui gen double _rand = runiform()
        qui sort _rand
        if `target_n_ids' <= _N {
            qui keep in 1/`target_n_ids'
        }
        else {
            // Need more IDs than original - sample with replacement
            local orig_n = _N
            qui expand ceil(`target_n_ids' / `orig_n') + 1
            qui gen double _rand2 = runiform()
            qui sort _rand2
            qui keep in 1/`target_n_ids'
            drop _rand2
        }
        qui gen long synth_id = _n
        qui gen long synth_rowcount = `rcvar'
        drop _rand
    }
    else if "`rowdist'" == "empirical" {
        // Bootstrap from observed distribution
        // Sample row counts with replacement from original
        local orig_n = _N
        preserve
        qui keep `rcvar'
        tempfile rc_vals
        qui save `rc_vals'
        restore

        clear
        qui set obs `target_n_ids'
        qui gen long synth_id = _n
        qui gen long synth_rowcount = .

        // Sample row counts from original distribution
        forvalues i = 1/`target_n_ids' {
            local rand_idx = ceil(runiform() * `orig_n')
            preserve
            qui use `rc_vals', clear
            qui keep in `rand_idx'
            local sampled_rc = `rcvar'[1]
            restore
            qui replace synth_rowcount = `sampled_rc' in `i'
        }
    }
    else if "`rowdist'" == "parametric" {
        // Fit parametric distribution (negative binomial or Poisson)
        // and generate from fitted distribution
        clear
        qui set obs `target_n_ids'
        qui gen long synth_id = _n

        // Use negative binomial if variance > mean (overdispersion)
        // Otherwise use Poisson
        local variance = `rc_sd'^2
        if `variance' > `rc_mean' & `rc_sd' > 0 {
            // Negative binomial: parameterize via mean and dispersion
            // dispersion r = mean^2 / (variance - mean)
            local r_param = `rc_mean'^2 / (`variance' - `rc_mean')
            local p_param = `r_param' / (`r_param' + `rc_mean')

            // Generate using gamma-Poisson mixture
            qui gen double _lambda = rgamma(`r_param', (1 - `p_param') / `p_param')
            qui gen long synth_rowcount = rpoisson(_lambda)
            drop _lambda
        }
        else {
            // Poisson distribution
            qui gen long synth_rowcount = rpoisson(`rc_mean')
        }

        // Enforce min/max constraints
        qui replace synth_rowcount = `rc_min' if synth_rowcount < `rc_min'
        qui replace synth_rowcount = `rc_max' if synth_rowcount > `rc_max'
        qui replace synth_rowcount = 1 if synth_rowcount < 1
    }

    // Keep only needed variables
    qui keep synth_id synth_rowcount
end

// Handle panel structure with improved row-count distribution
program define _synthdata_panel
    version 16.0
    syntax, panelid(string) paneltime(string) ///
        [preserve(varlist) autocorr(integer 0) Nobs(integer 0) origdata(string) ///
         rowdist(string) rowcount_dist(string)]

    // Get original panel structure info
    preserve
    qui use "`origdata'", clear

    // Analyze original panel structure
    tempvar nper orig_timevar
    qui bysort `panelid': gen long `nper' = _N
    qui bysort `panelid' (`paneltime'): gen long `orig_timevar' = _n

    // Get row count statistics
    qui bysort `panelid': keep if _n == 1
    qui su `nper', detail
    local rc_mean = r(mean)
    local rc_sd = r(sd)
    local rc_min = r(min)
    local rc_max = r(max)
    local npanels = r(N)

    // Save row count distribution if not provided
    if "`rowcount_dist'" == "" {
        tempfile rowcount_dist
        qui keep `panelid' `nper'
        qui save `rowcount_dist'
    }

    restore

    // Determine target number of panels
    local target_panels = `npanels'
    if `nobs' > 0 {
        local target_panels = round(`nobs' / `rc_mean')
        if `target_panels' < 1 local target_panels = 1
    }

    di as txt "  Panel structure: " as res `target_panels' as txt " panels"
    di as txt "  Rows per panel: mean=" as res %5.1f `rc_mean' ///
        as txt ", range=[" as res `rc_min' as txt "-" as res `rc_max' as txt "]"

    // Generate row counts for synthetic panels
    if "`rowdist'" == "" local rowdist "empirical"

    _synthdata_rowcounts, target_n_ids(`target_panels') ///
        rowcount_dist(`rowcount_dist') rowdist(`rowdist') ///
        rc_mean(`rc_mean') rc_sd(`rc_sd') rc_min(`rc_min') rc_max(`rc_max')

    // Get the generated structure
    qui su synth_rowcount, meanonly
    local total_rows = r(sum)

    // Expand to create panel structure
    qui expand synth_rowcount
    qui bysort synth_id: gen long _timevar = _n

    // Now merge back with synthetic data
    // The current data has the ID structure; we need to sample from synthetic values
    tempfile panel_structure
    qui keep synth_id _timevar synth_rowcount
    qui save `panel_structure'

    // Load synthetic data and restructure
    restore, preserve

    local curr_n = _N
    if `total_rows' != `curr_n' {
        if `total_rows' > `curr_n' {
            qui expand ceil(`total_rows' / `curr_n') + 1
        }
        qui gen double _rand = runiform()
        qui sort _rand
        qui keep in 1/`total_rows'
        drop _rand
    }

    // Assign panel structure
    qui gen long _obs = _n
    qui merge 1:1 _obs using `panel_structure', nogen

    // Create/replace panel variables
    cap drop `panelid'
    qui gen long `panelid' = synth_id
    label var `panelid' "Synthetic panel ID"

    cap drop `paneltime'
    qui gen long `paneltime' = _timevar
    label var `paneltime' "Synthetic time index"

    // Handle preserved variables (constant within panel)
    if "`preserve'" != "" {
        foreach v of local preserve {
            cap confirm variable `v'
            if !_rc {
                // Make variable constant within panel by taking first value
                tempvar first_val
                qui bysort `panelid' (`paneltime'): gen `first_val' = `v'[1]
                qui replace `v' = `first_val'
                drop `first_val'
            }
        }
    }

    // Clean up
    cap drop synth_id _timevar synth_rowcount _obs

    di as txt "  Panel structure applied: " as res `total_rows' as txt " total observations"
end

// Compare original and synthetic statistics
program define _synthdata_compare
    version 16.0
    syntax varlist, origstats(string) [prefix(string)]
    
    // Compute synthetic stats
    tempfile synthstats
    
    // Handle prefix (using safe naming for 32-char limit)
    if "`prefix'" != "" {
        local synthvarlist ""
        foreach v of local varlist {
            _synthdata_safename `prefix' `v'
            local synthvarlist `synthvarlist' `r(safename)'
        }
    }
    else {
        local synthvarlist `varlist'
    }

    _synthdata_stats `synthvarlist', saving(`synthstats')
    
    preserve
    
    di as txt _n "Comparison of Original vs Synthetic Data:"
    di as txt "{hline 76}"
    di as txt %20s "Variable" %12s "Orig Mean" %12s "Synth Mean" %12s "Orig SD" %12s "Synth SD" %8s "Diff%"
    di as txt "{hline 76}"
    
    qui use `origstats', clear
    rename (mean sd) (orig_mean orig_sd)
    tempfile orig
    qui save `orig'
    
    qui use `synthstats', clear
    
    // Remove prefix from varname for matching
    if "`prefix'" != "" {
        qui replace varname = subinstr(varname, "`prefix'", "", 1)
    }
    
    rename (mean sd) (synth_mean synth_sd)
    
    qui merge 1:1 varname using `orig', nogen keep(match)
    
    qui count
    if r(N) == 0 {
        di as txt "  (No matching numeric variables for comparison)"
    }
    else {
        forvalues i = 1/`=_N' {
            local vn = varname[`i']
            local om = orig_mean[`i']
            local sm = synth_mean[`i']
            local os = orig_sd[`i']
            local ss = synth_sd[`i']
            
            // Percent difference in mean
            if `os' != 0 & `os' != . {
                local pctdiff = 100 * abs(`om' - `sm') / `os'
            }
            else {
                local pctdiff = .
            }
            
            di as txt %20s abbrev("`vn'", 20) %12.3f `om' %12.3f `sm' %12.3f `os' %12.3f `ss' %8.1f `pctdiff'
        }
    }
    
    di as txt "{hline 76}"
    di as txt "Note: Diff% = |orig_mean - synth_mean| / orig_sd * 100"
    
    restore
end

// Save validation statistics
program define _synthdata_validate
    version 16.0
    syntax varlist, origstats(string) saving(string) [prefix(string)]

    // Handle prefix (using safe naming for 32-char limit)
    if "`prefix'" != "" {
        local synthvarlist ""
        foreach v of local varlist {
            _synthdata_safename `prefix' `v'
            local synthvarlist `synthvarlist' `r(safename)'
        }
    }
    else {
        local synthvarlist `varlist'
    }

    tempfile synthstats
    _synthdata_stats `synthvarlist', saving(`synthstats')

    preserve

    // Load origstats and save to tempfile
    qui use `origstats', clear
    rename (mean sd min max p25 p50 p75 N) =_orig
    tempfile orig
    qui save `orig'

    // Load synthstats and remove prefix BEFORE merging
    qui use `synthstats', clear
    if "`prefix'" != "" {
        qui replace varname = subinstr(varname, "`prefix'", "", 1)
    }
    rename (mean sd min max p25 p50 p75 N) =_synth

    // Now merge with matching varnames
    qui merge 1:1 varname using `orig', nogen
    
    // Compute utility metrics
    qui gen mean_diff_pct = abs(mean_orig - mean_synth) / sd_orig * 100 if sd_orig != 0
    qui gen sd_ratio = sd_synth / sd_orig if sd_orig != 0
    qui gen range_coverage = (max_synth - min_synth) / (max_orig - min_orig) if (max_orig - min_orig) != 0

    // Sanitize filename
    if regexm("`saving'", "[;&|><\$\`]") {
        di as error "validate() filename contains invalid characters"
        exit 198
    }
    local savename = subinstr("`saving'", ".dta", "", .)
    qui save "`savename'.dta", replace
    
    di as txt "Validation statistics saved to `savename'.dta"
    restore
end

// Utility metrics
program define _synthdata_utility
    version 16.0
    syntax varlist, origstats(string)
    
    di as txt _n "Utility Metrics Summary:"
    di as txt "  (See validate() output for detailed statistics)"
    di as txt "  Key metrics: mean_diff_pct, sd_ratio, range_coverage"
end

// Density comparison graphs
program define _synthdata_graph
    version 16.0
    syntax varlist, origdata(string) [prefix(string)]
    
    local ngraphs: word count `varlist'
    if `ngraphs' == 0 {
        di as txt "No continuous variables to graph"
        exit
    }
    
    di as txt "Generating density comparison plots..."
    
    // Store current synthetic data
    tempfile synthdata
    qui save `synthdata'
    
    local gnum = 1
    foreach v of local varlist {
        // Determine synthetic variable name (using safe naming for 32-char limit)
        if "`prefix'" != "" {
            _synthdata_safename `prefix' `v'
            local synthv `r(safename)'
        }
        else {
            local synthv `v'
        }
        
        // Create combined dataset for comparison
        preserve
        qui use `origdata', clear
        qui keep `v'
        qui rename `v' value
        qui gen byte source = 0
        tempfile orig
        qui save `orig'
        
        qui use `synthdata', clear
        cap confirm variable `synthv'
        if _rc {
            restore
            continue
        }
        qui keep `synthv'
        qui rename `synthv' value
        qui gen byte source = 1
        qui append using `orig'
        
        label define source 0 "Original" 1 "Synthetic", replace
        label values source source
        
        twoway (kdensity value if source == 0, lcolor(blue) lwidth(medium)) ///
               (kdensity value if source == 1, lcolor(red) lpattern(dash) lwidth(medium)), ///
               legend(order(1 "Original" 2 "Synthetic")) ///
               title("Distribution: `v'") ///
               name(synth_`gnum', replace)
        
        restore
        local ++gnum
    }
    
    di as txt "Created `=`gnum'-1' density comparison graphs"
end

// =============================================================================
// CATEGORICAL-CONTINUOUS CONDITIONING
// =============================================================================
// Generates continuous variables stratified by categorical variable levels
// This preserves relationships like different heights for males vs females
//
// Process:
//   1. Identify main stratification categorical (most levels or user-specified)
//   2. For each stratum level, compute separate means/SDs/correlations
//   3. Generate continuous values stratum-by-stratum using MVN
//   4. Combine strata into final synthetic data

program define _synthdata_condcont, rclass
    version 16.0
    syntax, contvars(varlist) catvars(varlist) n(integer) origdata(string)

    // Use first categorical as stratification variable (typically the most important)
    local stratvar: word 1 of `catvars'

    // Load original data to compute stratum-specific parameters
    preserve
    qui use `origdata', clear

    // Get stratum levels
    qui levelsof `stratvar', local(strat_levels)
    local nstrat: word count `strat_levels'

    if `nstrat' < 2 | `nstrat' > 50 {
        // Too few or too many strata - fall back to unconditional
        restore
        return local used_conditioning = 0
        exit
    }

    di as txt "    Conditioning on `stratvar' (`nstrat' levels)..."

    // Compute stratum counts and proportions
    local total_n = _N
    foreach lev of local strat_levels {
        qui count if `stratvar' == `lev'
        local strat_n_`lev' = r(N)
        local strat_prop_`lev' = r(N) / `total_n'
    }

    // Compute means and SDs per stratum per variable
    local ncont: word count `contvars'
    foreach lev of local strat_levels {
        local j = 1
        foreach v of local contvars {
            qui su `v' if `stratvar' == `lev', meanonly
            local strat_mean_`lev'_`j' = cond(r(N) > 0, r(mean), 0)
            qui su `v' if `stratvar' == `lev'
            local strat_sd_`lev'_`j' = cond(r(N) > 1 & r(sd) > 0, r(sd), 1)
            local ++j
        }

        // Compute correlation matrix for this stratum if ncont > 1
        if `ncont' > 1 {
            qui correlate `contvars' if `stratvar' == `lev', cov
            if _rc == 0 & r(N) >= `ncont' {
                tempname covmat_`lev'
                matrix `covmat_`lev'' = r(C)
                // Check and regularize if needed
                mata: st_local("isposdef", strofreal(_synthdata_isposdef(st_matrix("`covmat_`lev''"))))
                if `isposdef' == 0 {
                    mata: st_matrix("`covmat_`lev''", _synthdata_regularize(st_matrix("`covmat_`lev''")))
                }
            }
            else {
                // Fall back to diagonal covariance
                tempname covmat_`lev'
                matrix `covmat_`lev'' = J(`ncont', `ncont', 0)
                local j = 1
                foreach v of local contvars {
                    matrix `covmat_`lev''[`j', `j'] = `strat_sd_`lev'_`j''^2
                    local ++j
                }
            }
        }
    }

    restore

    // Now generate synthetic data stratum by stratum
    qui drop _all

    foreach lev of local strat_levels {
        // Calculate n for this stratum
        local strat_synth_n = round(`n' * `strat_prop_`lev'')
        if `strat_synth_n' < 1 local strat_synth_n = 1

        // Create temp dataset for this stratum
        preserve
        qui drop _all
        qui set obs `strat_synth_n'

        // Generate stratification variable
        qui gen double `stratvar' = `lev'

        // Generate continuous variables
        if `ncont' == 1 {
            local v: word 1 of `contvars'
            qui gen double `v' = rnormal(`strat_mean_`lev'_1', `strat_sd_`lev'_1')
        }
        else {
            // Multivariate normal generation
            tempname means_strat
            matrix `means_strat' = J(1, `ncont', .)
            local j = 1
            foreach v of local contvars {
                matrix `means_strat'[1, `j'] = `strat_mean_`lev'_`j''
                local ++j
            }

            foreach v of local contvars {
                qui gen double `v' = .
            }

            mata: _synthdata_genmvn("`contvars'", st_matrix("`means_strat'"), ///
                st_matrix("`covmat_`lev''"), `strat_synth_n')
        }

        tempfile strat_`lev'
        qui save `strat_`lev''
        restore
    }

    // Combine all strata
    qui drop _all
    local first = 1
    foreach lev of local strat_levels {
        if `first' {
            qui use `strat_`lev'', clear
            local first = 0
        }
        else {
            qui append using `strat_`lev''
        }
    }

    // Shuffle and trim/expand to exact n
    qui gen double _rand = runiform()
    sort _rand
    drop _rand

    if _N > `n' {
        qui keep in 1/`n'
    }
    else if _N < `n' {
        local deficit = `n' - _N
        qui expand ceil(`n' / _N) + 1
        qui gen double _rand = runiform()
        sort _rand
        qui keep in 1/`n'
        drop _rand
    }

    return local used_conditioning = 1
    return local strat_var "`stratvar'"
end

// =============================================================================
// WITHIN-ID RANDOM EFFECTS FOR PANEL DATA
// =============================================================================
// Adds ID-level random effects to preserve within-person correlation
// For longitudinal data, if person A has high BP at visit 1, they likely
// have high BP at visits 2-3 too.
//
// Process:
//   1. For each continuous variable, estimate ICC from original data
//   2. Generate a random effect for each synthetic ID
//   3. Add the random effect to all rows within that ID
//   4. Scale to preserve overall variance

program define _synthdata_randomeffects
    version 16.0
    syntax, idvar(varname) contvars(varlist) origdata(string)

    // Load original data to compute ICCs
    preserve
    qui use `origdata', clear

    local ncont: word count `contvars'
    if `ncont' == 0 {
        restore
        exit
    }

    di as txt "    Computing intra-class correlations..."

    // Compute ICC for each continuous variable using one-way ANOVA
    // ICC = (MSB - MSW) / (MSB + (k-1)*MSW) where k = mean cluster size
    foreach v of local contvars {
        // Check if variable exists and has variation
        cap confirm variable `v'
        if _rc {
            local icc_`v' = 0
            continue
        }

        qui su `v'
        if r(sd) == 0 | r(sd) == . {
            local icc_`v' = 0
            continue
        }

        // Compute between and within variance using mixed model approach
        // Simplified: use variance decomposition
        cap quietly anova `v' `idvar'
        if _rc {
            local icc_`v' = 0
            continue
        }

        // Get mean squares
        local msb = e(mss) / e(df_m)
        local msw = e(rss) / e(df_r)

        // Mean cluster size
        qui tab `idvar'
        local n_ids = r(r)
        local k = _N / `n_ids'

        // ICC
        if `msb' + (`k' - 1) * `msw' > 0 {
            local icc_`v' = (`msb' - `msw') / (`msb' + (`k' - 1) * `msw')
            if `icc_`v'' < 0 local icc_`v' = 0
            if `icc_`v'' > 1 local icc_`v' = 1
        }
        else {
            local icc_`v' = 0
        }
    }

    restore

    // Now apply random effects to synthetic data
    // Get unique IDs in synthetic data
    tempvar id_num
    qui egen `id_num' = group(`idvar')
    qui su `id_num', meanonly
    local n_synth_ids = r(max)

    foreach v of local contvars {
        if `icc_`v'' > 0.01 {
            // Generate random effect for each ID
            // RE variance = ICC * total_var
            // Within variance = (1-ICC) * total_var

            qui su `v'
            local total_var = r(Var)
            local total_sd = r(sd)
            local total_mean = r(mean)

            if `total_sd' > 0 {
                local re_sd = sqrt(`icc_`v'') * `total_sd'

                // Generate one random effect per ID
                tempvar re_`v'
                qui gen double `re_`v'' = .

                // Create ID-level random effects
                forvalues i = 1/`n_synth_ids' {
                    local this_re = rnormal(0, `re_sd')
                    qui replace `re_`v'' = `this_re' if `id_num' == `i'
                }

                // Scale within-ID variance to maintain total variance
                // New value = mean + (value - mean) * sqrt(1-ICC) + RE
                qui replace `v' = `total_mean' + (`v' - `total_mean') * sqrt(1 - `icc_`v'') + `re_`v''
                drop `re_`v''
            }
        }
    }

    drop `id_num'

    di as txt "    Random effects applied to continuous variables"
end

// =============================================================================
// MARGINAL DISTRIBUTION TRANSFORMS
// =============================================================================
// Detects and applies transforms to handle skewed distributions
// For non-normal variables: transform -> synthesize as normal -> back-transform
//
// Supported transforms:
//   - log: for positive skewed data (min > 0)
//   - sqrt: for count-like data (min >= 0)
//   - none: for approximately normal data

program define _synthdata_transform, rclass
    version 16.0
    syntax varlist, origdata(string) [SAVing(string)]

    // Load original data
    preserve
    qui use `origdata', clear

    local transforms ""
    local transform_vars ""

    foreach v of local varlist {
        cap confirm numeric variable `v'
        if _rc continue

        qui su `v', detail
        if r(N) < 10 | r(sd) == 0 {
            local transforms `"`transforms' "none""'
            continue
        }

        local skew = r(skewness)
        local vmin = r(min)
        local vmean = r(mean)
        local vsd = r(sd)

        // Decision logic for transform
        if abs(`skew') < 0.5 {
            // Approximately normal
            local transforms `"`transforms' "none""'
        }
        else if `skew' > 0.5 & `vmin' > 0 {
            // Positive skew and positive values -> log transform
            local transforms `"`transforms' "log""'
            local transform_vars `transform_vars' `v'
        }
        else if `skew' > 0.5 & `vmin' >= 0 {
            // Positive skew and non-negative -> sqrt transform
            local transforms `"`transforms' "sqrt""'
            local transform_vars `transform_vars' `v'
        }
        else if `skew' < -0.5 {
            // Negative skew -> reflect and log
            local transforms `"`transforms' "neglog""'
            local transform_vars `transform_vars' `v'
        }
        else {
            local transforms `"`transforms' "none""'
        }
    }

    restore

    // Store transform info for later back-transformation
    if "`saving'" != "" {
        local i = 1
        foreach v of local varlist {
            local trans: word `i' of `transforms'
            c_local _trans_`v' "`trans'"
            local ++i
        }
    }

    // Return the list of transformed variables
    return local transform_vars "`transform_vars'"
    return local transforms `"`transforms'"'
end

// Apply transforms to original data before synthesis
program define _synthdata_apply_transform
    version 16.0
    syntax varlist, transforms(string asis)

    local i = 1
    foreach v of local varlist {
        local trans: word `i' of `transforms'

        if "`trans'" == "log" {
            qui replace `v' = ln(`v')
        }
        else if "`trans'" == "sqrt" {
            qui replace `v' = sqrt(`v')
        }
        else if "`trans'" == "neglog" {
            qui su `v', meanonly
            local vmax = r(max)
            qui replace `v' = ln(`vmax' + 1 - `v')
            c_local _neglog_max_`v' = `vmax'
        }
        local ++i
    }
end

// Back-transform synthetic data
program define _synthdata_backtransform
    version 16.0
    syntax varlist, transforms(string asis)

    local i = 1
    foreach v of local varlist {
        local trans: word `i' of `transforms'

        if "`trans'" == "log" {
            qui replace `v' = exp(`v')
        }
        else if "`trans'" == "sqrt" {
            qui replace `v' = `v'^2
            qui replace `v' = 0 if `v' < 0  // Handle numerical issues
        }
        else if "`trans'" == "neglog" {
            // Need the original max value - stored in c_local
            local vmax = ${_neglog_max_`v'}
            if "`vmax'" != "" {
                qui replace `v' = `vmax' + 1 - exp(`v')
            }
        }
        local ++i
    }
end

// =============================================================================
// MISSINGNESS PATTERN PRESERVATION
// =============================================================================
// Preserves the pattern of missingness, not just the rate
// If variables A and B are often missing together, this structure is maintained
//
// Process:
//   1. Create missingness indicator matrix from original
//   2. Identify unique missingness patterns and their frequencies
//   3. Sample patterns proportionally for synthetic data
//   4. Apply patterns to make values missing

program define _synthdata_misspattern_capture
    version 16.0
    syntax varlist, SAVing(string)

    // Create missingness indicator for each variable
    local nvars: word count `varlist'

    // Create a pattern string for each observation
    tempvar pattern
    qui gen str`nvars' `pattern' = ""

    foreach v of local varlist {
        qui replace `pattern' = `pattern' + cond(missing(`v'), "1", "0")
    }

    // Get unique patterns and counts
    preserve
    qui contract `pattern', freq(_freq)
    qui rename `pattern' pattern
    qui gen double _prop = _freq / _N

    // Save patterns
    qui save `saving', replace
    restore
end

program define _synthdata_misspattern_apply
    version 16.0
    syntax varlist, patterns(string)

    // Load patterns
    preserve
    qui use `patterns', clear
    local npatterns = _N

    // Build pattern list and cumulative probabilities
    local cumprob = 0
    forvalues i = 1/`npatterns' {
        local pat`i' = pattern[`i']
        local prop`i' = _prop[`i']
        local cumprob = `cumprob' + `prop`i''
        local cumprob`i' = `cumprob'
    }
    restore

    // Apply patterns to synthetic data
    tempvar u assigned_pattern
    qui gen double `u' = runiform()
    qui gen str`=length("`pat1'")' `assigned_pattern' = ""

    // Assign patterns based on cumulative probability
    forvalues i = 1/`npatterns' {
        if `i' == 1 {
            qui replace `assigned_pattern' = "`pat`i''" if `u' <= `cumprob`i''
        }
        else {
            local prev = `i' - 1
            qui replace `assigned_pattern' = "`pat`i''" if `u' > `cumprob`prev'' & `u' <= `cumprob`i''
        }
    }

    // Apply missingness based on pattern
    local j = 1
    foreach v of local varlist {
        tempvar should_miss
        qui gen byte `should_miss' = substr(`assigned_pattern', `j', 1) == "1"

        cap confirm string variable `v'
        if !_rc {
            qui replace `v' = "" if `should_miss'
        }
        else {
            qui replace `v' = . if `should_miss'
        }
        drop `should_miss'
        local ++j
    }

    drop `u' `assigned_pattern'
end

// =============================================================================
// PRIVACY DISTANCE CHECK (OPTIONAL, SAMPLING-BASED)
// =============================================================================
// Checks that synthetic records are not too close to original records
// Uses Gower distance (handles mixed types) on a sample of synthetic records
//
// Off by default (privacysample = 0)

program define _synthdata_privacycheck, rclass
    version 16.0
    syntax varlist, origdata(string) [sample(integer 1000) threshold(real 0.05)]

    if `sample' <= 0 {
        di as txt "  Privacy check skipped (privacysample = 0)"
        exit
    }

    local n_synth = _N
    if `sample' > `n_synth' {
        local sample = `n_synth'
    }

    di as txt _n "Privacy check (sampling `sample' synthetic records)..."

    // Sample synthetic records
    tempvar rand_order
    qui gen double `rand_order' = runiform()
    sort `rand_order'

    // Save sampled synthetic records
    tempfile synth_sample
    preserve
    qui keep in 1/`sample'
    qui gen long _synth_id = _n
    qui save `synth_sample'
    restore
    drop `rand_order'

    // Load original data
    preserve
    qui use `origdata', clear
    local n_orig = _N

    // Keep only relevant variables
    qui keep `varlist'

    // For each sampled synthetic record, find minimum distance to any original
    // This is O(sample * n_orig) which is manageable

    // Compute variable ranges for Gower distance normalization
    local nvars: word count `varlist'
    local j = 1
    foreach v of local varlist {
        cap confirm numeric variable `v'
        if !_rc {
            qui su `v'
            local range_`j' = r(max) - r(min)
            if `range_`j'' == 0 local range_`j' = 1
            local type_`j' = "num"
        }
        else {
            local range_`j' = 1
            local type_`j' = "str"
        }
        local ++j
    }

    // Save original
    tempfile orig_temp
    qui save `orig_temp'

    // Process synthetic sample
    qui use `synth_sample', clear

    tempvar min_dist
    qui gen double `min_dist' = .

    // For computational efficiency, use Mata
    mata: _synthdata_compute_mindist("`varlist'", "`orig_temp'", `sample', `nvars')

    // Report statistics
    qui su `min_dist', detail
    local mean_dist = r(mean)
    local min_dist_val = r(min)
    local p5_dist = r(p5)

    local n_close = 0
    qui count if `min_dist' < `threshold'
    local n_close = r(N)
    local pct_close = 100 * `n_close' / `sample'

    di as txt "  Mean distance to nearest original: " as res %6.4f `mean_dist'
    di as txt "  Minimum distance found: " as res %6.4f `min_dist_val'
    di as txt "  5th percentile distance: " as res %6.4f `p5_dist'
    di as txt "  Records within threshold (`threshold'): " as res `n_close' " (" %4.1f `pct_close' "%)"

    if `n_close' > 0 {
        di as txt "  Warning: `n_close' synthetic records may be too similar to originals"
    }
    else {
        di as txt "  Privacy check passed: no records below threshold"
    }

    restore

    return scalar mean_dist = `mean_dist'
    return scalar min_dist = `min_dist_val'
    return scalar n_close = `n_close'
    return scalar pct_close = `pct_close'
end

// =============================================================================
// TEMPORAL TREND PRESERVATION FOR PANEL DATA
// =============================================================================
// For longitudinal data with time variables, preserves within-ID trends
// If disease progresses over time in original, synthetic shows similar patterns
//
// Process:
//   1. Detect time/visit variable in panel
//   2. Estimate within-ID slopes for continuous outcomes
//   3. Generate synthetic slopes from the distribution
//   4. Apply trends to synthetic data

program define _synthdata_trends
    version 16.0
    syntax, idvar(varname) timevar(varname) contvars(varlist) origdata(string)

    // Load original to estimate trend distributions
    preserve
    qui use `origdata', clear

    di as txt "    Analyzing within-ID temporal trends..."

    // For each continuous variable, estimate within-ID slopes
    foreach v of local contvars {
        cap confirm numeric variable `v'
        if _rc continue

        // Check that variable has variation
        qui su `v'
        if r(sd) == 0 | r(sd) == . continue

        // Estimate slopes per ID using regression
        // Store slope distribution parameters
        tempvar slope_`v'

        // Statsby approach to get slopes
        cap statsby _b[`timevar'], by(`idvar') saving(`"`c(tmpdir)'/slopes_`v'"', replace): ///
            regress `v' `timevar'

        if _rc {
            // Fall back - no trends for this variable
            local slope_mean_`v' = 0
            local slope_sd_`v' = 0
            continue
        }

        qui use `"`c(tmpdir)'/slopes_`v'"', clear
        qui su _stat_1
        local slope_mean_`v' = r(mean)
        local slope_sd_`v' = r(sd)
        if `slope_sd_`v'' == . local slope_sd_`v' = 0

        // Clean up
        cap erase `"`c(tmpdir)'/slopes_`v'.dta"'
    }

    restore

    // Apply trends to synthetic data
    // Get unique IDs
    tempvar id_num
    qui egen `id_num' = group(`idvar')
    qui su `id_num', meanonly
    local n_synth_ids = r(max)

    // Get time values
    qui su `timevar'
    local time_mean = r(mean)

    foreach v of local contvars {
        if `slope_sd_`v'' > 0 {
            // Generate one slope per ID
            tempvar synth_slope
            qui gen double `synth_slope' = .

            forvalues i = 1/`n_synth_ids' {
                local this_slope = rnormal(`slope_mean_`v'', `slope_sd_`v'')
                qui replace `synth_slope' = `this_slope' if `id_num' == `i'
            }

            // Apply trend: value += slope * (time - mean_time)
            qui replace `v' = `v' + `synth_slope' * (`timevar' - `time_mean')
            drop `synth_slope'
        }
    }

    drop `id_num'

    di as txt "    Temporal trends applied"
end

// =============================================================================
// DATE ORDERING DETECTION (for complex method)
// =============================================================================
// Detects date variables that consistently follow ordering patterns.
// For example: admission_date < procedure_date < discharge_date
// Only pairs where >95% of observations satisfy ordering are returned.

program define _synthdata_detect_dateorder, rclass
    version 16.0
    syntax varlist

    local orderings ""
    local n_orderings = 0

    local nvars: word count `varlist'
    if `nvars' < 2 {
        return local date_orderings ""
        return scalar n_orderings = 0
        exit
    }

    // Check all pairs of date variables for consistent ordering
    forvalues i = 1/`=`nvars'-1' {
        local d1: word `i' of `varlist'
        forvalues j = `=`i'+1'/`nvars' {
            local d2: word `j' of `varlist'

            // Count where d1 < d2 (excluding missing)
            qui count if !missing(`d1') & !missing(`d2')
            local n_valid = r(N)
            if `n_valid' < 10 continue

            qui count if `d1' < `d2' & !missing(`d1') & !missing(`d2')
            local n_d1_before = r(N)

            qui count if `d1' > `d2' & !missing(`d1') & !missing(`d2')
            local n_d2_before = r(N)

            // Check if ordering is consistent (>95% in one direction)
            local pct_d1_before = `n_d1_before' / `n_valid'
            local pct_d2_before = `n_d2_before' / `n_valid'

            if `pct_d1_before' >= 0.95 {
                // d1 is consistently before d2
                local orderings `orderings' `d1'<`d2'
                local ++n_orderings
                di as txt "    `d1' < `d2' (" as res %4.1f `=`pct_d1_before'*100' as txt "% consistent)"
            }
            else if `pct_d2_before' >= 0.95 {
                // d2 is consistently before d1
                local orderings `orderings' `d2'<`d1'
                local ++n_orderings
                di as txt "    `d2' < `d1' (" as res %4.1f `=`pct_d2_before'*100' as txt "% consistent)"
            }
        }
    }

    return local date_orderings `orderings'
    return scalar n_orderings = `n_orderings'
end

// =============================================================================
// DATE ORDERING ENFORCEMENT (for complex method)
// =============================================================================
// Enforces detected date orderings by sorting dates within each observation.

program define _synthdata_enforce_dateorder
    version 16.0
    syntax, orderings(string asis) [iterate(integer 100)]

    // Parse orderings to extract unique date variables in order
    // Orderings is space-separated list like: d1<d2 d1<d3 d2<d3
    local date_vars ""
    foreach ordering of local orderings {
        // Parse ordering like "date1<date2"
        if regexm("`ordering'", "([a-zA-Z_][a-zA-Z0-9_]*)<([a-zA-Z_][a-zA-Z0-9_]*)") {
            local d1 = regexs(1)
            local d2 = regexs(2)

            local is_in1: list d1 in date_vars
            if !`is_in1' {
                local date_vars `date_vars' `d1'
            }
            local is_in2: list d2 in date_vars
            if !`is_in2' {
                local date_vars `date_vars' `d2'
            }
        }
    }

    local ndates: word count `date_vars'
    if `ndates' < 2 {
        exit
    }

    // Sort dates within each observation using row-by-row approach
    // This is robust and works with any dataset structure
    local n = _N
    forvalues obs = 1/`n' {
        // Collect date values for this observation into numbered locals
        local k = 1
        foreach v of local date_vars {
            local val`k' = `v'[`obs']
            local ++k
        }

        // Sort the values (bubble sort for small n)
        forvalues pass = 1/`=`ndates'-1' {
            forvalues i = 1/`=`ndates'-`pass'' {
                local j = `i' + 1
                if `val`i'' > `val`j'' {
                    // Swap
                    local tmp = `val`i''
                    local val`i' = `val`j''
                    local val`j' = `tmp'
                }
            }
        }

        // Replace values in sorted order
        local k = 1
        foreach v of local date_vars {
            qui replace `v' = `val`k'' in `obs'
            local ++k
        }
    }
end

// =============================================================================
// STORE CATEGORICAL FREQUENCIES (for freqcheck)
// =============================================================================
// Saves frequency tables for all categorical variables to a tempfile.

program define _synthdata_store_catfreq
    version 16.0
    syntax varlist, saving(string)

    tempname memhold
    postfile `memhold' str32 varname double(value freq pct) using `saving', replace

    foreach v of local varlist {
        qui levelsof `v', local(levels)
        foreach lev of local levels {
            qui count if `v' == `lev'
            local freq = r(N)
            local pct = `freq' / _N
            post `memhold' ("`v'") (`lev') (`freq') (`pct')
        }
    }

    postclose `memhold'
end

// =============================================================================
// FREQUENCY CHECK (for complex method or freqcheck option)
// =============================================================================
// Compares categorical frequency distributions between original and synthetic.
// Reports total variation distance (TVD) for each variable.

program define _synthdata_freqcheck
    version 16.0
    syntax varlist, origfreq(string)

    di as txt "{hline 60}"
    di as txt %20s "Variable" %15s "Max Diff" %15s "TVD" %10s "Status"
    di as txt "{hline 60}"

    local total_tvd = 0
    local n_vars = 0
    local n_good = 0
    local n_warn = 0

    foreach v of local varlist {
        // Get synthetic frequencies
        qui levelsof `v', local(synth_levels)
        local synth_n = _N

        local max_diff = 0
        local tvd = 0

        foreach lev of local synth_levels {
            // Synthetic proportion
            qui count if `v' == `lev'
            local synth_pct = r(N) / `synth_n'

            // Original proportion (from stored file)
            preserve
            qui use `origfreq', clear
            qui su pct if varname == "`v'" & value == `lev', meanonly
            local orig_pct = cond(r(N) > 0, r(mean), 0)
            restore

            local diff = abs(`synth_pct' - `orig_pct')
            local tvd = `tvd' + `diff'
            if `diff' > `max_diff' {
                local max_diff = `diff'
            }
        }

        // TVD is sum of |p-q| / 2
        local tvd = `tvd' / 2

        // Determine status
        if `max_diff' < 0.03 {
            local status "OK"
            local ++n_good
        }
        else if `max_diff' < 0.10 {
            local status "WARN"
            local ++n_warn
        }
        else {
            local status "POOR"
        }

        di as txt %20s abbrev("`v'", 20) %15.3f `max_diff' %15.3f `tvd' %10s "`status'"

        local total_tvd = `total_tvd' + `tvd'
        local ++n_vars
    }

    di as txt "{hline 60}"

    if `n_vars' > 0 {
        local avg_tvd = `total_tvd' / `n_vars'
        di as txt "Average TVD: " as res %6.4f `avg_tvd'
    }

    if `n_warn' > 0 | `n_good' < `n_vars' {
        di as txt "Note: Frequency differences may indicate joint synthesis needed"
    }
    else {
        di as txt "All categorical frequencies well preserved"
    }
end

// Mata helper functions
mata:

// Check if matrix is positive definite
real scalar _synthdata_isposdef(real matrix A)
{
    real matrix eigvals
    real scalar i
    
    eigvals = eigenvalues(A)
    for (i = 1; i <= length(eigvals); i++) {
        if (Re(eigvals[i]) <= 0) return(0)
    }
    return(1)
}

// Regularize covariance matrix
real matrix _synthdata_regularize(real matrix A)
{
    real scalar mineval, ridge
    real matrix eigvals
    
    eigvals = eigenvalues(A)
    mineval = min(Re(eigvals))
    
    // Add ridge to make positive definite
    if (mineval <= 0) {
        ridge = abs(mineval) + 0.001 * trace(A) / rows(A)
        A = A + ridge * I(rows(A))
    }
    
    return(A)
}

// Generate multivariate normal
void _synthdata_genmvn(string scalar varlist, real matrix means, real matrix cov, real scalar n)
{
    real matrix L, Z, X
    string rowvector vars
    real scalar i, nvars
    
    vars = tokens(varlist)
    nvars = cols(vars)
    
    // Cholesky decomposition
    L = cholesky(cov)
    
    // Generate standard normal draws
    Z = rnormal(n, nvars, 0, 1)
    
    // Transform: X = Z * L' + means
    X = Z * L'
    for (i = 1; i <= nvars; i++) {
        X[., i] = X[., i] :+ means[1, i]
    }
    
    // Store in Stata
    for (i = 1; i <= nvars; i++) {
        st_store(., vars[i], X[., i])
    }
}

// Draw from categorical distribution (vals in col 1, freqs in col 2)
void _synthdata_drawcat(string scalar varname, real matrix valfreq, real scalar n)
{
    real matrix u, cumprob, result
    real scalar i, j, nlevels, total
    real colvector vals, freqs
    
    vals = valfreq[., 1]
    freqs = valfreq[., 2]
    nlevels = rows(vals)
    
    // Normalize frequencies to probabilities
    total = sum(freqs)
    if (total == 0) total = 1
    cumprob = runningsum(freqs) :/ total
    
    u = runiform(n, 1)
    result = J(n, 1, vals[1])
    
    for (i = 1; i <= n; i++) {
        for (j = 1; j <= nlevels; j++) {
            if (u[i] <= cumprob[j]) {
                result[i] = vals[j]
                break
            }
        }
    }
    
    st_store(., varname, result)
}

// Draw from joint distribution of two categorical variables
// valfreq has 3 columns: val1, val2, frequency
void _synthdata_drawjoint(string scalar varname1, string scalar varname2,
                          real matrix valfreq, real scalar n)
{
    real colvector u, cumprob, result1, result2, freqs
    real matrix vals
    real scalar i, j, nlevels, total

    vals = valfreq[., 1..2]
    freqs = valfreq[., 3]
    nlevels = rows(vals)

    // Normalize frequencies to probabilities
    total = sum(freqs)
    if (total == 0) total = 1
    cumprob = runningsum(freqs) :/ total

    u = runiform(n, 1)
    result1 = J(n, 1, vals[1, 1])
    result2 = J(n, 1, vals[1, 2])

    for (i = 1; i <= n; i++) {
        for (j = 1; j <= nlevels; j++) {
            if (u[i] <= cumprob[j]) {
                result1[i] = vals[j, 1]
                result2[i] = vals[j, 2]
                break
            }
        }
    }

    st_store(., varname1, result1)
    st_store(., varname2, result2)
}

// Sort date values within each observation to enforce ordering
void _synthdata_sortdates(string scalar varlist)
{
    string rowvector vars
    real matrix data, sorted_data
    real rowvector vals, sorted_vals, idx
    real scalar n, nvars, i, j

    vars = tokens(varlist)
    nvars = cols(vars)

    if (nvars < 2) return

    n = st_nobs()

    // Load date data
    data = st_data(., vars)
    sorted_data = data

    // For each observation, sort the non-missing values
    for (i = 1; i <= n; i++) {
        vals = data[i, .]

        // Get indices of non-missing values
        idx = selectindex(vals :< .)

        if (cols(idx) < 2) continue

        // Extract non-missing values and sort
        sorted_vals = sort(vals[1, idx]', 1)'

        // Put sorted values back in same positions
        for (j = 1; j <= cols(idx); j++) {
            sorted_data[i, idx[j]] = sorted_vals[j]
        }
    }

    // Store back
    st_store(., vars, sorted_data)
}

// Draw categorical index (for string variables)
void _synthdata_drawcatidx(string scalar varname, real matrix freqs, real scalar n)
{
    real matrix u, cumprob, result
    real scalar i, j, nlevels, total

    nlevels = rows(freqs)

    // Normalize frequencies to probabilities
    total = sum(freqs)
    if (total == 0) total = 1
    cumprob = runningsum(freqs) :/ total

    u = runiform(n, 1)
    result = J(n, 1, 1)

    for (i = 1; i <= n; i++) {
        for (j = 1; j <= nlevels; j++) {
            if (u[i] <= cumprob[j]) {
                result[i] = j
                break
            }
        }
    }

    st_store(., varname, result)
}

// Draw categorical index for string variables by reading frequencies from Stata locals
// This avoids Stata matrix size limits for high-cardinality string variables
void _synthdata_drawstridx(string scalar varname, real scalar nlevels,
                            string scalar strnum, real scalar n)
{
    real colvector freqs, cumprob, u, result
    real scalar i, j, total
    string scalar localname

    // Build frequency vector by reading from Stata locals
    freqs = J(nlevels, 1, .)
    for (j = 1; j <= nlevels; j++) {
        localname = "strfreq_" + strnum + "_" + strofreal(j)
        freqs[j] = strtoreal(st_local(localname))
    }

    // Normalize frequencies to probabilities
    total = sum(freqs)
    if (total == 0) total = 1
    cumprob = runningsum(freqs) :/ total

    u = runiform(n, 1)
    result = J(n, 1, 1)

    for (i = 1; i <= n; i++) {
        for (j = 1; j <= nlevels; j++) {
            if (u[i] <= cumprob[j]) {
                result[i] = j
                break
            }
        }
    }

    st_store(., varname, result)
}

// =============================================================================
// EMPIRICAL QUANTILE SYNTHESIS
// =============================================================================
// Generates synthetic values that:
//   1. ALWAYS stay within original data bounds [min, max]
//   2. Follow the same distribution as original data
//   3. Are computationally efficient (O(n log n) for sort, O(n) for generation)
//
// Algorithm:
//   1. Sort original non-missing values to get empirical CDF
//   2. Generate uniform random draws U ~ Uniform(0, 1)
//   3. Map each U to a value via linear interpolation between sorted values
//   4. Optionally add small noise for smoothing (jitter within quantile bins)
//
// This is equivalent to sampling from the empirical distribution function,
// which perfectly preserves the original distribution shape including
// skewness, kurtosis, and bounds.

void _synthdata_genquantile(string scalar varname, real colvector sorted_vals,
                            real scalar n, real scalar smooth)
{
    real colvector u, result, ecdf
    real scalar i, nvals, idx_lo, idx_hi, idx_mid, frac, jitter_sd

    nvals = rows(sorted_vals)
    if (nvals == 0) {
        st_store(., varname, J(n, 1, .))
        return
    }

    // Special case: single unique value
    if (nvals == 1) {
        st_store(., varname, J(n, 1, sorted_vals[1]))
        return
    }

    // Generate uniform random draws
    u = runiform(n, 1)
    result = J(n, 1, .)

    // Build empirical CDF positions: ecdf[i] = (i - 0.5) / nvals
    // Using (i - 0.5) / nvals gives midpoint of each probability bin
    ecdf = ((1::nvals) :- 0.5) :/ nvals

    // For each uniform draw, find corresponding quantile via interpolation
    for (i = 1; i <= n; i++) {
        // Find bracketing indices in ecdf
        // Binary search would be faster for large nvals, but linear is fine
        // for typical dataset sizes and is simpler

        if (u[i] <= ecdf[1]) {
            // Below first quantile - use minimum
            result[i] = sorted_vals[1]
        }
        else if (u[i] >= ecdf[nvals]) {
            // Above last quantile - use maximum
            result[i] = sorted_vals[nvals]
        }
        else {
            // Find bracketing indices: ecdf[idx_lo] <= u[i] < ecdf[idx_hi]
            idx_lo = 1
            idx_hi = nvals
            while (idx_hi - idx_lo > 1) {
                idx_mid = floor((idx_lo + idx_hi) / 2)
                if (ecdf[idx_mid] <= u[i]) {
                    idx_lo = idx_mid
                }
                else {
                    idx_hi = idx_mid
                }
            }

            // Linear interpolation between sorted_vals[idx_lo] and sorted_vals[idx_hi]
            frac = (u[i] - ecdf[idx_lo]) / (ecdf[idx_hi] - ecdf[idx_lo])
            result[i] = sorted_vals[idx_lo] + frac * (sorted_vals[idx_hi] - sorted_vals[idx_lo])
        }
    }

    // Optional smoothing: add small jitter within the local bin width
    // This prevents exact replication of original values while staying bounded
    if (smooth) {
        for (i = 1; i <= n; i++) {
            // Estimate local density (bin width) around the generated value
            // Use a small fraction of the range as jitter
            jitter_sd = (sorted_vals[nvals] - sorted_vals[1]) / (2 * nvals)
            result[i] = result[i] + rnormal(1, 1, 0, jitter_sd)
            // Clip to bounds
            if (result[i] < sorted_vals[1]) result[i] = sorted_vals[1]
            if (result[i] > sorted_vals[nvals]) result[i] = sorted_vals[nvals]
        }
    }

    st_store(., varname, result)
}

// Generate empirical quantile values for multiple variables with correlation preservation
// Uses Gaussian copula approach: generate correlated normals, transform to uniforms,
// then map to empirical distributions
void _synthdata_genquantile_corr(string scalar varlist, real matrix sorted_data,
                                  real matrix covmat, real scalar n, real scalar smooth)
{
    real matrix L, Z, U, X
    string rowvector vars
    real scalar i, j, nvars, nvals
    real colvector sorted_v, ecdf, result
    real scalar idx_lo, idx_hi, idx_mid, frac, jitter_sd

    vars = tokens(varlist)
    nvars = cols(vars)

    // Step 1: Generate correlated standard normals via Cholesky
    L = cholesky(covmat)
    Z = rnormal(n, nvars, 0, 1)
    Z = Z * L'

    // Step 2: Transform to uniform via normal CDF (Gaussian copula)
    U = normal(Z)

    // Step 3: For each variable, map uniforms to empirical quantiles
    X = J(n, nvars, .)

    for (j = 1; j <= nvars; j++) {
        sorted_v = sorted_data[., j]
        // Remove missing values
        sorted_v = select(sorted_v, sorted_v :!= .)
        nvals = rows(sorted_v)

        if (nvals == 0) {
            X[., j] = J(n, 1, .)
            continue
        }
        if (nvals == 1) {
            X[., j] = J(n, 1, sorted_v[1])
            continue
        }

        // Build ECDF positions
        ecdf = ((1::nvals) :- 0.5) :/ nvals
        result = J(n, 1, .)

        for (i = 1; i <= n; i++) {
            if (U[i, j] <= ecdf[1]) {
                result[i] = sorted_v[1]
            }
            else if (U[i, j] >= ecdf[nvals]) {
                result[i] = sorted_v[nvals]
            }
            else {
                // Binary search for bracketing indices
                idx_lo = 1
                idx_hi = nvals
                while (idx_hi - idx_lo > 1) {
                    idx_mid = floor((idx_lo + idx_hi) / 2)
                    if (ecdf[idx_mid] <= U[i, j]) {
                        idx_lo = idx_mid
                    }
                    else {
                        idx_hi = idx_mid
                    }
                }
                frac = (U[i, j] - ecdf[idx_lo]) / (ecdf[idx_hi] - ecdf[idx_lo])
                result[i] = sorted_v[idx_lo] + frac * (sorted_v[idx_hi] - sorted_v[idx_lo])
            }
        }

        // Optional smoothing
        if (smooth) {
            jitter_sd = (sorted_v[nvals] - sorted_v[1]) / (2 * nvals)
            for (i = 1; i <= n; i++) {
                result[i] = result[i] + rnormal(1, 1, 0, jitter_sd)
                if (result[i] < sorted_v[1]) result[i] = sorted_v[1]
                if (result[i] > sorted_v[nvals]) result[i] = sorted_v[nvals]
            }
        }

        X[., j] = result
    }

    // Store results
    for (j = 1; j <= nvars; j++) {
        st_store(., vars[j], X[., j])
    }
}

// =============================================================================
// FILE-BASED EMPIRICAL QUANTILE SYNTHESIS
// =============================================================================
// These functions load sorted values from a tempfile instead of using Stata
// matrices. This avoids Stata/SE's 11,000 row matrix limit and can handle
// datasets of any size that fit in memory.

// Generate quantile values for a single variable by loading from tempfile
void _synthdata_genquantile_fromdata(string scalar varname, string scalar datafile,
                                      real scalar n, real scalar smooth)
{
    real colvector sorted_vals, u, result, ecdf
    real scalar i, nvals, idx_lo, idx_hi, idx_mid, frac, jitter_sd
    real scalar varidx

    // Save current data state
    stata("preserve")

    // Load the tempfile containing sorted values
    stata("qui use " + char(34) + datafile + char(34) + ", clear")

    // Find the variable index
    varidx = st_varindex(varname)
    if (varidx == .) {
        stata("restore")
        st_store(., varname, J(n, 1, .))
        return
    }

    // Extract non-missing values and sort them
    sorted_vals = st_data(., varidx)
    sorted_vals = select(sorted_vals, sorted_vals :!= .)
    if (rows(sorted_vals) > 0) {
        sorted_vals = sort(sorted_vals, 1)
    }

    // Restore original data state
    stata("restore")

    // Now generate values using the standard algorithm
    nvals = rows(sorted_vals)
    if (nvals == 0) {
        st_store(., varname, J(n, 1, .))
        return
    }

    if (nvals == 1) {
        st_store(., varname, J(n, 1, sorted_vals[1]))
        return
    }

    u = runiform(n, 1)
    result = J(n, 1, .)
    ecdf = ((1::nvals) :- 0.5) :/ nvals

    for (i = 1; i <= n; i++) {
        if (u[i] <= ecdf[1]) {
            result[i] = sorted_vals[1]
        }
        else if (u[i] >= ecdf[nvals]) {
            result[i] = sorted_vals[nvals]
        }
        else {
            idx_lo = 1
            idx_hi = nvals
            while (idx_hi - idx_lo > 1) {
                idx_mid = floor((idx_lo + idx_hi) / 2)
                if (ecdf[idx_mid] <= u[i]) {
                    idx_lo = idx_mid
                }
                else {
                    idx_hi = idx_mid
                }
            }
            frac = (u[i] - ecdf[idx_lo]) / (ecdf[idx_hi] - ecdf[idx_lo])
            result[i] = sorted_vals[idx_lo] + frac * (sorted_vals[idx_hi] - sorted_vals[idx_lo])
        }
    }

    if (smooth) {
        jitter_sd = (sorted_vals[nvals] - sorted_vals[1]) / (2 * nvals)
        for (i = 1; i <= n; i++) {
            result[i] = result[i] + rnormal(1, 1, 0, jitter_sd)
            if (result[i] < sorted_vals[1]) result[i] = sorted_vals[1]
            if (result[i] > sorted_vals[nvals]) result[i] = sorted_vals[nvals]
        }
    }

    st_store(., varname, result)
}

// Generate correlated quantile values for multiple variables from tempfile
// Uses Gaussian copula: correlated normals -> uniforms -> empirical quantiles
void _synth_genquant_corr_fromdata(string scalar varlist, string scalar datafile,
                                    real matrix corrmat, real scalar n, real scalar smooth)
{
    real matrix L, Z, U, X
    string rowvector vars
    real scalar i, j, nvars, nvals, varidx
    real colvector sorted_v, ecdf, result, all_vals
    real scalar idx_lo, idx_hi, idx_mid, frac, jitter_sd

    vars = tokens(varlist)
    nvars = cols(vars)

    // Step 1: Generate correlated standard normals via Cholesky
    L = cholesky(corrmat)
    Z = rnormal(n, nvars, 0, 1)
    Z = Z * L'

    // Step 2: Transform to uniform via normal CDF (Gaussian copula)
    U = normal(Z)

    // Step 3: For each variable, load sorted values and map uniforms to quantiles
    X = J(n, nvars, .)

    // Save current data and load tempfile
    stata("preserve")
    stata("qui use " + char(34) + datafile + char(34) + ", clear")

    for (j = 1; j <= nvars; j++) {
        varidx = st_varindex(vars[j])
        if (varidx == .) {
            X[., j] = J(n, 1, .)
            continue
        }

        // Extract and sort non-missing values
        all_vals = st_data(., varidx)
        sorted_v = select(all_vals, all_vals :!= .)
        if (rows(sorted_v) > 0) {
            sorted_v = sort(sorted_v, 1)
        }
        nvals = rows(sorted_v)

        if (nvals == 0) {
            X[., j] = J(n, 1, .)
            continue
        }
        if (nvals == 1) {
            X[., j] = J(n, 1, sorted_v[1])
            continue
        }

        ecdf = ((1::nvals) :- 0.5) :/ nvals
        result = J(n, 1, .)

        for (i = 1; i <= n; i++) {
            if (U[i, j] <= ecdf[1]) {
                result[i] = sorted_v[1]
            }
            else if (U[i, j] >= ecdf[nvals]) {
                result[i] = sorted_v[nvals]
            }
            else {
                idx_lo = 1
                idx_hi = nvals
                while (idx_hi - idx_lo > 1) {
                    idx_mid = floor((idx_lo + idx_hi) / 2)
                    if (ecdf[idx_mid] <= U[i, j]) {
                        idx_lo = idx_mid
                    }
                    else {
                        idx_hi = idx_mid
                    }
                }
                frac = (U[i, j] - ecdf[idx_lo]) / (ecdf[idx_hi] - ecdf[idx_lo])
                result[i] = sorted_v[idx_lo] + frac * (sorted_v[idx_hi] - sorted_v[idx_lo])
            }
        }

        if (smooth) {
            jitter_sd = (sorted_v[nvals] - sorted_v[1]) / (2 * nvals)
            for (i = 1; i <= n; i++) {
                result[i] = result[i] + rnormal(1, 1, 0, jitter_sd)
                if (result[i] < sorted_v[1]) result[i] = sorted_v[1]
                if (result[i] > sorted_v[nvals]) result[i] = sorted_v[nvals]
            }
        }

        X[., j] = result
    }

    // Restore original data
    stata("restore")

    // Store results
    for (j = 1; j <= nvars; j++) {
        st_store(., vars[j], X[., j])
    }
}

// =============================================================================
// HIGH-CARDINALITY STRING SYNTHESIS
// =============================================================================
// Synthesizes string variables entirely in Mata to avoid:
//   1. Stata's local macro limits (thousands of strval_* locals)
//   2. O(n * nlevels) replace loop performance issues
//   3. Matrix size limits
//
// Algorithm:
//   1. Load original string data from tempfile
//   2. Compute frequency distribution using Mata string operations
//   3. Draw random indices based on frequency distribution
//   4. Map indices to string values
//   5. Store results using st_sstore()

void _synthdata_synthstr_fromdata(string scalar varname, string scalar datafile,
                                   real scalar n)
{
    string colvector all_vals, nonmiss_vals, uniq_vals, result
    real colvector freqs, cumprob, u, indices
    real scalar i, j, nvals, nuniq, total, maxlen

    // Save current data and load tempfile
    stata("preserve")
    stata("qui use " + char(34) + datafile + char(34) + ", clear")

    // Check if variable exists
    if (st_varindex(varname) == .) {
        stata("restore")
        // Variable doesn't exist - will be created later as empty
        return
    }

    // Extract all string values
    all_vals = st_sdata(., varname)

    // Get non-missing values
    nonmiss_vals = select(all_vals, all_vals :!= "")
    nvals = rows(nonmiss_vals)

    // Restore original data state immediately
    stata("restore")

    // Handle empty case
    if (nvals == 0) {
        // Create empty string variable
        (void) st_addvar("str1", varname, 1)
        st_sstore(., varname, J(n, 1, ""))
        return
    }

    // Sort to group identical values together
    nonmiss_vals = sort(nonmiss_vals, 1)

    // Count unique values and their frequencies
    // First pass: count uniques
    nuniq = 1
    for (i = 2; i <= nvals; i++) {
        if (nonmiss_vals[i] != nonmiss_vals[i-1]) {
            nuniq++
        }
    }

    // Second pass: build unique values and frequency vectors
    uniq_vals = J(nuniq, 1, "")
    freqs = J(nuniq, 1, 0)

    j = 1
    uniq_vals[1] = nonmiss_vals[1]
    freqs[1] = 1

    for (i = 2; i <= nvals; i++) {
        if (nonmiss_vals[i] != nonmiss_vals[i-1]) {
            j++
            uniq_vals[j] = nonmiss_vals[i]
            freqs[j] = 1
        }
        else {
            freqs[j] = freqs[j] + 1
        }
    }

    // Compute cumulative probabilities
    total = sum(freqs)
    cumprob = runningsum(freqs) :/ total

    // Draw random indices based on frequency distribution
    u = runiform(n, 1)
    indices = J(n, 1, 1)

    for (i = 1; i <= n; i++) {
        for (j = 1; j <= nuniq; j++) {
            if (u[i] <= cumprob[j]) {
                indices[i] = j
                break
            }
        }
    }

    // Map indices to string values
    result = J(n, 1, "")
    for (i = 1; i <= n; i++) {
        result[i] = uniq_vals[indices[i]]
    }

    // Determine max string length for variable creation
    maxlen = 1
    for (j = 1; j <= nuniq; j++) {
        if (strlen(uniq_vals[j]) > maxlen) {
            maxlen = strlen(uniq_vals[j])
        }
    }

    // Create and populate string variable
    // Use str# type to match max length
    (void) st_addvar("str" + strofreal(maxlen), varname, 1)
    st_sstore(., varname, result)
}

// Wrapper that synthesizes multiple string variables
// Called from Stata with list of variable names
void _synthdata_synthstr_multi(string scalar varlist, string scalar datafile,
                                real scalar n)
{
    string rowvector vars
    real scalar j, nvars

    vars = tokens(varlist)
    nvars = cols(vars)

    for (j = 1; j <= nvars; j++) {
        _synthdata_synthstr_fromdata(vars[j], datafile, n)
    }
}

// Compute minimum Gower distance from each synthetic record to any original
// This is O(n_synth * n_orig) but manageable for sampled synthetic records
void _synthdata_compute_mindist(string scalar varlist, string scalar origfile,
                                 real scalar n_synth, real scalar nvars)
{
    real matrix synth_data, orig_data
    real colvector min_dists, ranges
    string rowvector vars
    real scalar i, j, k, n_orig, dist, d_ij, range_k
    real rowvector synth_row, orig_row

    vars = tokens(varlist)

    // Load synthetic data (currently in memory)
    synth_data = st_data(., vars)

    // Load original data
    stata("preserve")
    stata("qui use `" + origfile + "', clear")
    orig_data = st_data(., vars)
    stata("restore")

    n_orig = rows(orig_data)
    min_dists = J(n_synth, 1, .)

    // Compute ranges for normalization (from original data)
    ranges = J(nvars, 1, 1)
    for (k = 1; k <= nvars; k++) {
        range_k = max(orig_data[., k]) - min(orig_data[., k])
        if (range_k > 0) ranges[k] = range_k
    }

    // For each synthetic record, find minimum distance to any original
    for (i = 1; i <= n_synth; i++) {
        synth_row = synth_data[i, .]
        min_dists[i] = .

        for (j = 1; j <= n_orig; j++) {
            orig_row = orig_data[j, .]

            // Compute Gower distance
            dist = 0
            for (k = 1; k <= nvars; k++) {
                // Handle missing values
                if (synth_row[k] == . | orig_row[k] == .) {
                    continue
                }
                // Normalized absolute difference for numeric
                d_ij = abs(synth_row[k] - orig_row[k]) / ranges[k]
                dist = dist + d_ij
            }
            dist = dist / nvars

            if (min_dists[i] == . | dist < min_dists[i]) {
                min_dists[i] = dist
            }
        }
    }

    // Store results back to Stata
    // Find the min_dist variable index
    real scalar idx
    idx = st_varindex("__min_dist__")
    if (idx == .) {
        idx = st_addvar("double", "__min_dist__")
    }
    st_store(., idx, min_dists)
}

end
