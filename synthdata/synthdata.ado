*! synthdata Version 1.0.0  2025/12/02  Synthetic data generation
program define synthdata_v2
    version 16.0
    
    syntax [varlist] [if] [in], ///
        [n(integer 0) SAVing(string) REPLACE CLEAR PREfix(string) MULTiple(integer 1)] ///
        [PARAmetric SEQUential BOOTstrap PERMute] ///
        [EMPirical NOISE(real 0.1) SMOOTH] ///
        [CATEgorical(varlist) CONTinuous(varlist) SKIP(varlist) ID(varlist) DATEs(varlist)] ///
        [CORRelations CONDitional CONSTraints(string asis) AUTOCONStraints] ///
        [PANEL(string) PRESERVEvar(varlist) AUTOCORR(integer 0)] ///
        [MINCell(integer 5) TRIM(real 0) BOUNDs(string asis) NOEXTreme] ///
        [COMPare VALidate(string) UTILity GRAPH] ///
        [SEED(integer -1) ITERate(integer 100) TOLerance(real 1e-6)]
    
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
    
    // Determine synthesis method (only one allowed)
    local nmethods = ("`parametric'" != "") + ("`sequential'" != "") + ///
                     ("`bootstrap'" != "") + ("`permute'" != "")
    if `nmethods' > 1 {
        di as error "only one synthesis method may be specified"
        exit 198
    }
    
    local method "parametric"
    if "`sequential'" != "" local method "sequential"
    if "`bootstrap'" != "" local method "bootstrap"
    if "`permute'" != "" local method "permute"
    
    // Default n to current observation count
    local orig_n = _N
    if `n' == 0 local n = `orig_n'
    
    // Classify variables
    _synthdata_classify_v2 `varlist', categorical(`categorical') continuous(`continuous') dates(`dates')
    local catvars `r(catvars)'
    local contvars `r(contvars)'
    local datevars `r(datevars)'
    local strvars `r(strvars)'
    
    // Store original data bounds for noextreme option
    if "`noextreme'" != "" {
        tempfile origbounds
        _synthdata_storebounds_v2 `contvars' `datevars', saving(`origbounds')
    }
    
    // Store original statistics for comparison
    if "`compare'" != "" | "`validate'" != "" | "`utility'" != "" {
        tempfile origstats
        _synthdata_stats_v2 `varlist', saving(`origstats')
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
    
    // Generate synthetic data based on method
    if "`method'" == "parametric" {
        _synthdata_parametric_v2, n(`n') catvars(`catvars') contvars(`contvars') ///
            datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
            `empirical' `smooth' `correlations' ///
            mincell(`mincell') trim(`trim')
    }
    else if "`method'" == "bootstrap" {
        _synthdata_bootstrap_v2, n(`n') noise(`noise') ///
            catvars(`catvars') contvars(`contvars') datevars(`datevars') ///
            strvars(`strvars') origdata(`origdata') ///
            mincell(`mincell') trim(`trim')
    }
    else if "`method'" == "permute" {
        _synthdata_permute_v2 `varlist', n(`n') origdata(`origdata')
    }
    else if "`method'" == "sequential" {
        _synthdata_sequential_v2, n(`n') catvars(`catvars') contvars(`contvars') ///
            datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
            mincell(`mincell') trim(`trim')
    }
    
    // Handle ID variables - generate sequential IDs
    if "`id'" != "" {
        foreach v of local id {
            cap drop `v'
            qui gen long `v' = _n
            label var `v' "Synthetic ID"
        }
    }
    
    // Handle skip variables - set to missing in synthetic data
    if "`skip'" != "" {
        foreach v of local skip {
            cap drop `v'
            cap confirm string variable `v'
            if !_rc {
                qui gen str1 `v' = ""
            }
            else {
                qui gen `v' = .
            }
        }
    }
    
    // Apply bounds first (before constraints, as constraints may depend on bounded values)
    if `"`bounds'"' != "" {
        _synthdata_bounds_v2, bounds(`bounds')
    }
    
    // Enforce no extreme values using stored original bounds
    if "`noextreme'" != "" {
        _synthdata_noextreme_v2 `contvars' `datevars', boundsfile(`origbounds')
    }
    
    // Apply auto-detected constraints
    if "`autoconstraints'" != "" {
        _synthdata_autoconstraints_v2 `contvars' `datevars', iterate(`iterate') origdata(`origdata')
    }
    
    // Apply user constraints
    if `"`constraints'"' != "" {
        _synthdata_constraints_v2, constraints(`constraints') iterate(`iterate')
    }
    
    // Handle panel structure
    if "`panel'" != "" {
        _synthdata_panel_v2, panelid(`panelid') paneltime(`paneltime') ///
            preserve(`preservevar') autocorr(`autocorr') n(`n') origdata(`origdata')
    }
    
    // Store synthetic variable names before prefix (for compare)
    local synthvars `varlist'
    
    // Add prefix to variable names if requested
    if "`prefix'" != "" {
        foreach v of varlist * {
            cap rename `v' `prefix'`v'
        }
    }
    
    // Validation and comparison (must use unprefixed names for stats)
    if "`compare'" != "" {
        _synthdata_compare_v2 `synthvars', origstats(`origstats') prefix(`prefix')
    }
    
    if "`validate'" != "" {
        _synthdata_validate_v2 `synthvars', origstats(`origstats') saving(`validate') prefix(`prefix')
    }
    
    if "`utility'" != "" {
        _synthdata_utility_v2 `synthvars', origstats(`origstats')
    }
    
    if "`graph'" != "" {
        _synthdata_graph_v2 `contvars', origdata(`origdata') prefix(`prefix')
    }
    
    // Handle multiple synthetic datasets
    if `multiple' > 1 {
        if "`saving'" == "" {
            di as error "multiple() requires saving() option"
            exit 198
        }
        
        // Save first dataset
        local savename = subinstr("`saving'", ".dta", "", .)
        qui save "`savename'_1.dta", replace
        
        // Generate additional datasets
        forvalues m = 2/`multiple' {
            qui use `origdata', clear
            
            if `seed' >= 0 {
                set seed `=`seed' + `m''
            }
            
            if "`method'" == "parametric" {
                _synthdata_parametric_v2, n(`n') catvars(`catvars') contvars(`contvars') ///
                    datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
                    `empirical' `smooth' `correlations' ///
                    mincell(`mincell') trim(`trim')
            }
            else if "`method'" == "bootstrap" {
                _synthdata_bootstrap_v2, n(`n') noise(`noise') ///
                    catvars(`catvars') contvars(`contvars') datevars(`datevars') ///
                    strvars(`strvars') origdata(`origdata') ///
                    mincell(`mincell') trim(`trim')
            }
            else if "`method'" == "permute" {
                _synthdata_permute_v2 `varlist', n(`n') origdata(`origdata')
            }
            else if "`method'" == "sequential" {
                _synthdata_sequential_v2, n(`n') catvars(`catvars') contvars(`contvars') ///
                    datevars(`datevars') strvars(`strvars') origdata(`origdata') ///
                    mincell(`mincell') trim(`trim')
            }
            
            if "`id'" != "" {
                foreach v of local id {
                    cap drop `v'
                    qui gen long `v' = _n
                }
            }
            
            if `"`bounds'"' != "" {
                _synthdata_bounds_v2, bounds(`bounds')
            }
            
            if "`noextreme'" != "" {
                _synthdata_noextreme_v2 `contvars' `datevars', boundsfile(`origbounds')
            }
            
            if `"`constraints'"' != "" {
                _synthdata_constraints_v2, constraints(`constraints') iterate(`iterate')
            }
            
            if "`prefix'" != "" {
                foreach v of varlist * {
                    cap rename `v' `prefix'`v'
                }
            }
            
            qui save "`savename'_`m'.dta", replace
        }
        
        di as txt "Saved `multiple' synthetic datasets: `savename'_1.dta to `savename'_`multiple'.dta"
    }
    else {
        // Single dataset handling
        if "`saving'" != "" {
            local savename = subinstr("`saving'", ".dta", "", .)
            qui save "`savename'.dta", replace
            di as txt "Synthetic data saved to `savename'.dta"
        }
        
        if "`replace'" != "" | "`clear'" != "" {
            restore, not
            di as txt "Current data replaced with synthetic version (`n' observations)"
        }
    }
    
    // Display summary
    di as txt _n "Synthetic data generation complete:"
    di as txt "  Method: " as res "`method'"
    di as txt "  Original observations: " as res `orig_n'
    di as txt "  Synthetic observations: " as res `n'
    di as txt "  Variables synthesized: " as res `: word count `varlist''
    if "`contvars'" != "" di as txt "    Continuous: " as res `: word count `contvars''
    if "`catvars'" != "" di as txt "    Categorical (numeric): " as res `: word count `catvars''
    if "`strvars'" != "" di as txt "    Categorical (string): " as res `: word count `strvars''
    if "`datevars'" != "" di as txt "    Dates: " as res `: word count `datevars''
    if "`id'" != "" di as txt "  ID variables (regenerated): " as res "`id'"
    if "`skip'" != "" di as txt "  Skipped variables: " as res "`skip'"
end

// Classify variables as categorical, continuous, date, or string
program define _synthdata_classify_v2, rclass
    syntax varlist, [categorical(varlist) continuous(varlist) dates(varlist)]
    
    local catvars `categorical'
    local contvars `continuous'
    local datevars `dates'
    local strvars ""
    
    foreach v of local varlist {
        // Skip if already classified
        local incat: list v in catvars
        local incont: list v in contvars
        local indate: list v in datevars
        
        if `incat' | `incont' | `indate' continue
        
        // Check if string first
        cap confirm string variable `v'
        if !_rc {
            local strvars `strvars' `v'
            continue
        }
        
        // Check if date format
        local fmt: format `v'
        if strpos("`fmt'", "%t") | strpos("`fmt'", "%d") {
            local datevars `datevars' `v'
            continue
        }
        
        // Check number of unique values (for numeric only)
        qui levelsof `v', local(levels)
        local nuniq: word count `levels'
        
        // Heuristic: if <= 20 unique values or has value label, treat as categorical
        local vallbl: value label `v'
        if `nuniq' <= 20 | "`vallbl'" != "" {
            local catvars `catvars' `v'
        }
        else {
            local contvars `contvars' `v'
        }
    }
    
    return local catvars `catvars'
    return local contvars `contvars'
    return local datevars `datevars'
    return local strvars `strvars'
end

// Store original variable bounds
program define _synthdata_storebounds_v2
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
program define _synthdata_stats_v2
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

// Parametric synthesis method
program define _synthdata_parametric_v2
    syntax, n(integer) [catvars(varlist) contvars(varlist) datevars(varlist) ///
        strvars(string) origdata(string) empirical smooth correlations ///
        mincell(integer 5) trim(real 0)]
    
    local orig_n = _N
    
    // Store continuous variable parameters
    local ncont: word count `contvars'
    
    if `ncont' > 0 {
        // Store means, SDs, and empirical distributions
        tempname means sds mins maxs
        matrix `means' = J(1, `ncont', .)
        matrix `sds' = J(1, `ncont', .)
        matrix `mins' = J(1, `ncont', .)
        matrix `maxs' = J(1, `ncont', .)
        
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
        
        // Compute correlation/covariance matrix
        if `ncont' > 1 {
            qui correlate `contvars', cov
            tempname covmat
            matrix `covmat' = r(C)
            
            // Check for positive definiteness, regularize if needed
            mata: st_local("isposdef", strofreal(_synthdata_isposdef_v2(st_matrix("`covmat'"))))
            if `isposdef' == 0 {
                di as txt "Note: Covariance matrix regularized for positive definiteness"
                mata: st_matrix("`covmat'", _synthdata_regularize_v2(st_matrix("`covmat'")))
            }
        }
    }
    
    // Store categorical variable frequencies
    local ncat: word count `catvars'
    if `ncat' > 0 {
        local catnum = 1
        foreach v of local catvars {
            qui levelsof `v', local(levels_`catnum')
            local nlevels_`catnum': word count `levels_`catnum''
            
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
    
    // Store string variable frequencies
    local nstr: word count `strvars'
    if `nstr' > 0 {
        local strnum = 1
        foreach v of local strvars {
            qui levelsof `v', local(strlevels_`strnum') clean
            local nstrlevels_`strnum': word count `strlevels_`strnum''
            
            // Store frequencies in locals (can't use matrix for strings)
            local j = 1
            foreach lev of local strlevels_`strnum' {
                qui count if `v' == `"`lev'"'
                local strfreq_`strnum'_`j' = r(N)
                local strval_`strnum'_`j' `"`lev'"'
                local ++j
            }
            local ++strnum
        }
    }
    
    // Store date variable parameters (treat as continuous)
    local ndate: word count `datevars'
    if `ndate' > 0 {
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
    
    // Create synthetic dataset
    qui drop _all
    qui set obs `n'
    
    // Generate continuous variables
    if `ncont' > 0 {
        if `ncont' == 1 {
            // Single variable: simple normal
            local v: word 1 of `contvars'
            qui gen double `v' = rnormal(`=`means'[1,1]', `=`sds'[1,1]')
        }
        else {
            // Multivariate normal via Cholesky
            mata: _synthdata_genmvn_v2("`contvars'", st_matrix("`means'"), st_matrix("`covmat'"), `n')
        }
    }
    
    // Generate categorical variables
    if `ncat' > 0 {
        local catnum = 1
        foreach v of local catvars {
            qui gen double `v' = .
            mata: _synthdata_drawcat_v2("`v'", st_matrix("`catfreq_`catnum''"), `n')
            
            // Restore value label
            if "`vallbl_`catnum''" != "" {
                cap label values `v' `vallbl_`catnum''
            }
            local ++catnum
        }
    }
    
    // Generate string variables
    if `nstr' > 0 {
        local strnum = 1
        foreach v of local strvars {
            // Determine max string length
            local maxlen = 1
            forvalues j = 1/`nstrlevels_`strnum'' {
                local len = strlen(`"`strval_`strnum'_`j''"')
                if `len' > `maxlen' local maxlen = `len'
            }
            
            qui gen str`maxlen' `v' = ""
            
            // Build frequency vector and draw
            tempname strfreqmat
            matrix `strfreqmat' = J(`nstrlevels_`strnum'', 1, .)
            forvalues j = 1/`nstrlevels_`strnum'' {
                matrix `strfreqmat'[`j', 1] = `strfreq_`strnum'_`j''
            }
            
            // Draw indices
            tempvar idx
            qui gen long `idx' = .
            mata: _synthdata_drawcatidx_v2("`idx'", st_matrix("`strfreqmat'"), `n')
            
            // Assign string values
            forvalues j = 1/`nstrlevels_`strnum'' {
                qui replace `v' = `"`strval_`strnum'_`j''"' if `idx' == `j'
            }
            drop `idx'
            local ++strnum
        }
    }
    
    // Generate date variables
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
end

// Bootstrap synthesis method
program define _synthdata_bootstrap_v2
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
program define _synthdata_permute_v2
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

// Sequential regression method
program define _synthdata_sequential_v2
    syntax, n(integer) [catvars(varlist) contvars(varlist) ///
        datevars(varlist) strvars(string) origdata(string) ///
        mincell(integer 5) trim(real 0)]
    
    // Combine all vars in synthesis order (continuous first, then categorical)
    local allvars `contvars' `datevars' `catvars' `strvars'
    
    if "`allvars'" == "" {
        di as error "no variables to synthesize"
        exit 102
    }
    
    // Store original data info
    foreach v of local allvars {
        local iscat_`v': list v in catvars
        local isdate_`v': list v in datevars
        local isstr_`v': list v in strvars
        
        if `isstr_`v'' {
            qui levelsof `v', local(levels_`v') clean
        }
        else if `iscat_`v'' {
            qui levelsof `v', local(levels_`v')
        }
        
        // Store format
        local fmt_`v': format `v'
    }
    
    // Create empty synthetic dataset structure
    tempfile origdata_temp
    qui save `origdata_temp'
    
    qui drop _all
    qui set obs `n'
    
    local prevvars ""
    
    foreach v of local allvars {
        // Load original to fit model
        preserve
        qui use `origdata_temp', clear
        
        local iscat = `iscat_`v''
        local isdate = `isdate_`v''
        local isstr = `isstr_`v''
        
        if "`prevvars'" == "" {
            // First variable: draw from marginal
            if `isstr' {
                // String: store frequencies
                local nlevels: word count `levels_`v''
                tempname freqmat
                matrix `freqmat' = J(`nlevels', 1, .)
                local j = 1
                foreach lev of local levels_`v' {
                    qui count if `v' == `"`lev'"'
                    matrix `freqmat'[`j', 1] = r(N)
                    local strval_`j' `"`lev'"'
                    local ++j
                }
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
                // String: use marginal (regression not applicable)
                local nlevels: word count `levels_`v''
                tempname freqmat
                matrix `freqmat' = J(`nlevels', 1, .)
                local j = 1
                foreach lev of local levels_`v' {
                    qui count if `v' == `"`lev'"'
                    matrix `freqmat'[`j', 1] = r(N)
                    local strval_`j' `"`lev'"'
                    local ++j
                }
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
            // String variable
            local maxlen = 1
            local nlevels: word count `levels_`v''
            forvalues j = 1/`nlevels' {
                local len = strlen(`"`strval_`j''"')
                if `len' > `maxlen' local maxlen = `len'
            }
            
            qui gen str`maxlen' `v' = ""
            tempvar idx
            qui gen long `idx' = .
            mata: _synthdata_drawcatidx_v2("`idx'", st_matrix("`freqmat'"), `n')
            
            forvalues j = 1/`nlevels' {
                qui replace `v' = `"`strval_`j''"' if `idx' == `j'
            }
            drop `idx'
        }
        else if `iscat' {
            qui gen double `v' = .
            // Draw from marginal
            tempname catcomb
            matrix `catcomb' = `catvals', `catfreqs'
            mata: _synthdata_drawcat_v2("`v'", st_matrix("`catcomb'"), `n')
        }
        else {
            // Continuous or date
            if "`prevvars'" == "" | `use_reg' != 1 {
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
            }
        }
        
        local prevvars `prevvars' `v'
    }
end

// Apply user constraints via rejection/clipping
program define _synthdata_constraints_v2
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
program define _synthdata_autoconstraints_v2
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
        _synthdata_constraints_v2, constraints(`constraints') iterate(`iterate')
    }
end

// Apply bounds
program define _synthdata_bounds_v2
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

// Enforce no values outside observed range
program define _synthdata_noextreme_v2
    syntax varlist, boundsfile(string)
    
    preserve
    qui use `boundsfile', clear
    local nbounds = _N
    
    forvalues i = 1/`nbounds' {
        local vn = varname[`i']
        local vmin = vmin[`i']
        local vmax = vmax[`i']
        
        restore, preserve
        cap confirm variable `vn'
        if !_rc {
            qui replace `vn' = `vmin' if `vn' < `vmin' & !missing(`vn')
            qui replace `vn' = `vmax' if `vn' > `vmax' & !missing(`vn')
        }
    }
    
    restore, not
end

// Handle panel structure
program define _synthdata_panel_v2
    syntax, panelid(string) paneltime(string) [preserve(varlist) autocorr(integer 0) n(integer) origdata(string)]
    
    di as txt "Note: Panel structure synthesis generates similar panel structure but simplified correlations"
    
    // Get original panel structure info
    preserve
    qui use `origdata', clear
    
    qui duplicates report `panelid'
    local npanels = r(unique_value)
    
    // Compute obs per panel
    tempvar nper
    qui bysort `panelid': gen `nper' = _N
    qui su `nper', meanonly
    local mean_nper = round(r(mean))
    
    restore
    
    // Restructure to match panel pattern
    cap confirm variable `panelid'
    if !_rc {
        qui replace `panelid' = mod(_n - 1, `npanels') + 1
    }
    
    cap confirm variable `paneltime'
    if !_rc {
        qui bysort `panelid': replace `paneltime' = _n
    }
end

// Compare original and synthetic statistics
program define _synthdata_compare_v2
    syntax varlist, origstats(string) [prefix(string)]
    
    // Compute synthetic stats
    tempfile synthstats
    
    // Handle prefix
    if "`prefix'" != "" {
        local synthvarlist ""
        foreach v of local varlist {
            local synthvarlist `synthvarlist' `prefix'`v'
        }
    }
    else {
        local synthvarlist `varlist'
    }
    
    _synthdata_stats_v2 `synthvarlist', saving(`synthstats')
    
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
program define _synthdata_validate_v2
    syntax varlist, origstats(string) saving(string) [prefix(string)]
    
    // Handle prefix
    if "`prefix'" != "" {
        local synthvarlist ""
        foreach v of local varlist {
            local synthvarlist `synthvarlist' `prefix'`v'
        }
    }
    else {
        local synthvarlist `varlist'
    }
    
    tempfile synthstats
    _synthdata_stats_v2 `synthvarlist', saving(`synthstats')
    
    preserve
    qui use `origstats', clear
    rename (mean sd min max p25 p50 p75 N) =_orig
    
    qui merge 1:1 varname using `synthstats', nogen
    
    // Remove prefix for matching
    if "`prefix'" != "" {
        qui replace varname = subinstr(varname, "`prefix'", "", 1)
    }
    
    rename (mean sd min max p25 p50 p75 N) =_synth
    
    // Compute utility metrics
    qui gen mean_diff_pct = abs(mean_orig - mean_synth) / sd_orig * 100 if sd_orig != 0
    qui gen sd_ratio = sd_synth / sd_orig if sd_orig != 0
    qui gen range_coverage = (max_synth - min_synth) / (max_orig - min_orig) if (max_orig - min_orig) != 0
    
    local savename = subinstr("`saving'", ".dta", "", .)
    qui save "`savename'.dta", replace
    
    di as txt "Validation statistics saved to `savename'.dta"
    restore
end

// Utility metrics
program define _synthdata_utility_v2
    syntax varlist, origstats(string)
    
    di as txt _n "Utility Metrics Summary:"
    di as txt "  (See validate() output for detailed statistics)"
    di as txt "  Key metrics: mean_diff_pct, sd_ratio, range_coverage"
end

// Density comparison graphs
program define _synthdata_graph_v2
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
        // Determine synthetic variable name
        if "`prefix'" != "" {
            local synthv `prefix'`v'
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

// Mata helper functions
mata:

// Check if matrix is positive definite
real scalar _synthdata_isposdef_v2(real matrix A)
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
real matrix _synthdata_regularize_v2(real matrix A)
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
void _synthdata_genmvn_v2(string scalar varlist, real matrix means, real matrix cov, real scalar n)
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
void _synthdata_drawcat_v2(string scalar varname, real matrix valfreq, real scalar n)
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

// Draw categorical index (for string variables)
void _synthdata_drawcatidx_v2(string scalar varname, real matrix freqs, real scalar n)
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

end
