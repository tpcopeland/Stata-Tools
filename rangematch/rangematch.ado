*! rangematch Version 1.0.0  2026/05/12
*! Range join using Stata frames and Mata binary search
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

capture program drop rangematch
program define rangematch, rclass
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * Load Mata backend only when missing or stale.
    local _rm_required_mata_version "1.0.0"
    local _rm_mata_loaded ""
    capture mata: st_local("_rm_mata_loaded", _rm_mata_version())
    local _rm_mata_rc = _rc
    if `_rm_mata_rc' | "`_rm_mata_loaded'" != "`_rm_required_mata_version'" {
        capture findfile _rangematch_mata.ado
        if _rc == 0 {
            run "`r(fn)'"
            local _rm_mata_loaded ""
            capture mata: st_local("_rm_mata_loaded", _rm_mata_version())
            local _rm_mata_rc = _rc
            if `_rm_mata_rc' | "`_rm_mata_loaded'" != "`_rm_required_mata_version'" {
                display as error ///
                    "_rangematch_mata.ado did not load the expected Mata backend version"
                exit 111
            }
        }
        else {
            display as error "_rangematch_mata.ado not found; reinstall rangematch"
            exit 111
        }
    }

    * -------------------------------------------------------------------
    * Parse syntax
    * -------------------------------------------------------------------
    local _rm_caller_frame = c(frame)
    local _rm_cmdline `"rangematch `0'"'

    syntax anything(name=interval id="keyvar low high") ///
        [if] [in] using/ , ///
        [ BY(varlist) KEEPUsing(string) Prefix(string) Suffix(string) ///
          ALL UNMATCHed(string) GENerate(name) DISTance(name) ///
          MASTERID(name) USINGID(name) ///
          MAXPairs(integer 0) FRAME(name) REPLACE STATS noSORT ///
          CLOSED(string) NEARest(string) TIES(string) ///
          TOLerance(real 0) MISSing(string) ///
          ASsert(string) SAVing(string asis) DRYRun COUNT VERBOSE ]

    tokenize `"`interval'"'
    local key   `"`1'"'
    local low   `"`2'"'
    local high  `"`3'"'
    if `"`4'"' != "" {
        display as error "too many variables specified; expected: keyvar low high"
        exit 103
    }
    if `"`high'"' == "" {
        display as error "too few variables specified; expected: keyvar low high"
        exit 102
    }

    foreach bnd in low high {
        local `bnd'_kind ""
        capture confirm numeric variable ``bnd''
        if !_rc {
            local `bnd'_kind "variable"
        }
        else {
            if `"``bnd''"' == "." {
                local `bnd'_kind "literal"
            }
            else {
                capture confirm number ``bnd''
                if !_rc {
                    local `bnd'_kind "literal"
                }
                else {
                    display as error ///
                        `"{bf:``bnd''} must be a numeric master variable or numeric scalar bound"'
                    exit 198
                }
            }
        }
    }

    local low_uses_key = 0
    local high_uses_key = 0
    if "`low_kind'" == "literal" {
        if (`low' < .) local low_uses_key = 1
    }
    if "`high_kind'" == "literal" {
        if (`high' < .) local high_uses_key = 1
    }
    local uses_key_offsets = (`low_uses_key' | `high_uses_key')

    if `uses_key_offsets' {
        capture confirm numeric variable `key'
        if _rc {
            display as error ///
                `"scalar bounds require numeric key variable {bf:`key'} in the master data"'
            display as error ///
                `"use bound variables, or add {bf:`key'} to the master data before using scalar offsets"'
            exit 111
        }
    }

    local nearest_code = 0
    if `"`nearest'"' != "" {
        local nearest = lower(`"`nearest'"')
        if !inlist(`"`nearest'"', "before", "after", "both") {
            display as error ///
                "nearest() must be {bf:before}, {bf:after}, or {bf:both}"
            exit 198
        }
        if "`nearest'" == "before" local nearest_code = 1
        if "`nearest'" == "after"  local nearest_code = 2
        if "`nearest'" == "both"   local nearest_code = 3
        capture confirm numeric variable `key'
        if _rc {
            display as error ///
                `"nearest() requires numeric key variable {bf:`key'} in the master data"'
            exit 111
        }
    }
    if `"`ties'"' == "" local ties "all"
    local ties = lower(`"`ties'"')
    if !inlist(`"`ties'"', "all", "first", "last") {
        display as error "ties() must be {bf:all}, {bf:first}, or {bf:last}"
        exit 198
    }
    if `"`ties'"' != "all" & `"`nearest'"' == "" {
        display as error "ties() is only allowed with nearest()"
        exit 198
    }
    local ties_code = 1
    if "`ties'" == "first" local ties_code = 2
    if "`ties'" == "last"  local ties_code = 3

    local assert = lower(strtrim(`"`assert'"'))
    if `"`assert'"' != "" {
        local assert : subinstr local assert "," " ", all
        local assert : list retokenize assert
        local assert_seen ""
        foreach a of local assert {
            if !inlist(`"`a'"', "match", "using") {
                display as error "assert() may contain {bf:match}, {bf:using}, or both"
                exit 198
            }
            if strpos(" `assert_seen' ", " `a' ") == 0 {
                local assert_seen `"`assert_seen' `a'"'
            }
        }
        local assert : list retokenize assert_seen
    }

    if "`closed'" == "" local closed "both"
    local closed = lower(`"`closed'"')
    if !inlist(`"`closed'"', "both", "left", "right", "none") {
        display as error "closed() must be {bf:both}, {bf:left}, {bf:right}, or {bf:none}"
        exit 198
    }
    local closed_code = 1
    if "`closed'" == "left"  local closed_code = 2
    if "`closed'" == "right" local closed_code = 3
    if "`closed'" == "none"  local closed_code = 4

    if `tolerance' < 0 | `tolerance' >= . {
        display as error "tolerance() must be a nonnegative finite number"
        exit 198
    }

    if `"`missing'"' == "" local missing "wildcard"
    local missing = lower(`"`missing'"')
    if !inlist(`"`missing'"', "wildcard", "drop", "error") {
        display as error ///
            "missing() must be {bf:wildcard}, {bf:drop}, or {bf:error}"
        exit 198
    }

    local nosort ""
    if "`sort'" == "nosort" {
        local nosort "nosort"
        local sort ""
    }
    else {
        local sort "sort"
    }
    local sort_output = ("`nosort'" == "")

    if `"`unmatched'"' == "" local unmatched "master"
    local unmatched = lower(`"`unmatched'"')
    if !inlist(`"`unmatched'"', "master", "none", "using", "both") {
        display as error ///
            "unmatched() must be {bf:master}, {bf:none}, {bf:using}, or {bf:both}"
        exit 198
    }
    local keep_unmatched_master = inlist(`"`unmatched'"', "master", "both")
    local keep_unmatched_using  = inlist(`"`unmatched'"', "using", "both")

    if "`generate'" != "" {
        confirm new variable `generate'
    }
    if "`distance'" != "" {
        confirm new variable `distance'
        capture confirm numeric variable `key'
        if _rc {
            display as error ///
                `"distance() requires numeric key variable {bf:`key'} in the master data"'
            exit 111
        }
    }
    if "`masterid'" != "" {
        confirm new variable `masterid'
    }
    if "`usingid'" != "" {
        confirm new variable `usingid'
    }

    if "`prefix'" == "" & "`suffix'" == "" {
        local suffix "_U"
    }

    local dryrun_mode = ("`dryrun'" != "" | "`count'" != "")
    local _rm_timing = ("`verbose'" != "")
    if `_rm_timing' {
        capture timer clear 91
        capture timer clear 92
        capture timer clear 93
        timer on 91
    }

    local saving_file ""
    local saving_replace ""
    if `"`saving'"' != "" {
        _parse comma saving_file saving_opts : saving
        if `"`saving_file'"' == "" {
            display as error "saving() requires a filename"
            exit 198
        }
        local saving_file : subinstr local saving_file `"""' "", all
        if `"`saving_opts'"' != "" {
            if substr(`"`saving_opts'"', 1, 1) == "," {
                local saving_opts = substr(`"`saving_opts'"', 2, .)
            }
            local saving_opts = lower(strtrim(`"`saving_opts'"'))
            if `"`saving_opts'"' != "replace" {
                display as error "saving() only allows the {bf:replace} suboption"
                exit 198
            }
            local saving_replace "replace"
        }
    }

    if "`replace'" != "" & "`frame'" == "" {
        display as error "replace is only allowed with frame()"
        exit 198
    }
    if `"`saving_file'"' != "" & "`frame'" != "" {
        display as error "saving() may not be combined with frame()"
        exit 198
    }
    if `"`saving_file'"' != "" & `dryrun_mode' {
        display as error "saving() may not be combined with dryrun or count"
        exit 198
    }
    if "`frame'" != "" & !`dryrun_mode' {
        if "`frame'" == "`_rm_caller_frame'" {
            display as error "frame() must name a frame other than the current frame"
            exit 198
        }
        if substr("`frame'", 1, 5) == "__rm_" {
            display as error "frame() may not use names beginning with __rm_"
            exit 198
        }
        local _rm_frame_exists = 0
        capture frame `frame': describe
        if !_rc local _rm_frame_exists = 1
        if `_rm_frame_exists' & "`replace'" == "" {
            display as error `"frame {bf:`frame'} already exists"'
            display as error "specify replace to overwrite it"
            exit 110
        }
    }

    marksample touse, novarlist

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N_master = r(N)

    * -------------------------------------------------------------------
    * Count master rows with missing variable bounds and apply missing()
    * policy. Applies only to bound variables; a literal `.' positional
    * bound is the user's explicit open-ended token and is unaffected.
    * -------------------------------------------------------------------
    local N_missing_bounds = 0
    if "`low_kind'" == "variable" & "`high_kind'" == "variable" {
        quietly count if `touse' & (missing(`low') | missing(`high'))
        local N_missing_bounds = r(N)
    }
    else if "`low_kind'" == "variable" {
        quietly count if `touse' & missing(`low')
        local N_missing_bounds = r(N)
    }
    else if "`high_kind'" == "variable" {
        quietly count if `touse' & missing(`high')
        local N_missing_bounds = r(N)
    }
    if `N_missing_bounds' > 0 {
        if "`missing'" == "error" {
            display as error ///
                "`N_missing_bounds' master row(s) have missing values in low or high"
            display as error ///
                "specify {bf:missing(drop)} to ignore them or {bf:missing(wildcard)} to keep current open-ended behavior"
            exit 459
        }
        else if "`missing'" == "drop" {
            if "`low_kind'" == "variable" {
                quietly replace `touse' = 0 if missing(`low')
            }
            if "`high_kind'" == "variable" {
                quietly replace `touse' = 0 if missing(`high')
            }
            quietly count if `touse'
            local N_master = r(N)
            if `N_master' == 0 {
                display as error ///
                    "missing(drop) removed all master observations"
                exit 2000
            }
        }
    }

    local using_source "file"
    local using_frame ""
    local using_is_frame = 0
    capture confirm name `using'
    if !_rc {
        capture frame `using': describe
        if !_rc {
            local using_source "frame"
            local using_frame "`using'"
            local using_is_frame = 1
        }
    }
    if `using_is_frame' {
        if "`using_frame'" == "`_rm_caller_frame'" {
            display as error "using frame must be different from the current frame"
            exit 198
        }
        if substr("`using_frame'", 1, 5) == "__rm_" {
            display as error "using frame may not use names beginning with __rm_"
            exit 198
        }
    }
    else {
        confirm file `"`using'"'
    }

    local N_using_pre = .
    if `using_is_frame' {
        frame `using_frame': local N_using_pre = _N
    }
    else {
        quietly describe using `"`using'"'
        local N_using_pre = r(N)
    }
    local large_using_warn_threshold = 10000000
    if `N_using_pre' > `large_using_warn_threshold' ///
            & "`by'" == "" & `"`keepusing'"' == "" {
        display as error ///
            "warning: using data contain `N_using_pre' rows and no by() or keepusing() was specified"
        display as error ///
            "consider by() to partition matching or keepusing() to limit carried variables"
    }

    if `"`keepusing'"' != "" {
        if `using_is_frame' {
            foreach kv of local keepusing {
                frame `using_frame': capture confirm variable `kv'
                if _rc {
                    display as error ///
                        `"keepusing() variable {bf:`kv'} not found in using frame {bf:`using_frame'}"'
                    exit 111
                }
            }
        }
        else {
            capture quietly describe `keepusing' using `"`using'"'
            if _rc {
                local _rm_keep_rc = _rc
                quietly describe using `"`using'"', varlist
                local _rm_using_vars `r(varlist)'
                local _rm_missing_keep ""
                foreach kv of local keepusing {
                    capture confirm name `kv'
                    if !_rc {
                        if strpos(" `_rm_using_vars' ", " `kv' ") == 0 {
                            local _rm_missing_keep ///
                                `"`_rm_missing_keep' `kv'"'
                        }
                    }
                }
                local _rm_missing_keep : list retokenize _rm_missing_keep
                if `"`_rm_missing_keep'"' != "" {
                    display as error ///
                        `"keepusing() variable(s) not found in using dataset: `_rm_missing_keep'"'
                }
                else {
                    display as error ///
                        `"one or more keepusing() variables were not found in using dataset"'
                    display as error `"requested: `keepusing'"'
                }
                exit `_rm_keep_rc'
            }
        }
    }

    * -------------------------------------------------------------------
    * Load using data into frame
    * -------------------------------------------------------------------
    local all_using_vars ""
    if `dryrun_mode' {
        if `using_is_frame' {
            frame `using_frame': quietly describe, varlist short
            local all_using_vars `r(varlist)'
        }
        else {
            quietly describe using `"`using'"', varlist
            local all_using_vars `r(varlist)'
        }
    }

    local using_load_vars `"`key'"'
    if "`by'" != "" {
        local using_load_vars `"`using_load_vars' `by'"'
    }
    if `"`keepusing'"' != "" & !`dryrun_mode' {
        local using_load_vars `"`using_load_vars' `keepusing'"'
    }
    * Deduplicate
    local using_load_vars : list uniq using_load_vars

    capture frame drop __rm_using
    if `using_is_frame' {
        if `"`keepusing'"' != "" | `dryrun_mode' {
            frame `using_frame': frame put `using_load_vars', into(__rm_using)
        }
        else {
            frame `using_frame': frame put _all, into(__rm_using)
        }
    }
    else {
        frame create __rm_using
        if `"`keepusing'"' != "" | `dryrun_mode' {
            frame __rm_using: use `using_load_vars' using `"`using'"'
        }
        else {
            frame __rm_using: use `"`using'"'
        }
    }

    * Validate using-side key
    frame __rm_using {
        capture confirm variable `key'
        if _rc {
            noisily display as error ///
                `"variable {bf:`key'} not found in using dataset"'
            exit 111
        }
        capture confirm numeric variable `key'
        if _rc {
            noisily display as error ///
                `"key variable {bf:`key'} must be numeric in using dataset"'
            exit 109
        }
    }

    * Validate by-variables in using
    if "`by'" != "" {
        foreach bv of local by {
            frame __rm_using {
                capture confirm variable `bv'
                if _rc {
                    noisily display as error ///
                        `"by-variable {bf:`bv'} not found in using dataset"'
                    exit 111
                }
            }
            local m_isstr = 0
            local u_isstr = 0
            capture confirm string variable `bv'
            if !_rc local m_isstr = 1
            frame __rm_using {
                capture confirm string variable `bv'
                if !_rc local u_isstr = 1
            }
            if `m_isstr' != `u_isstr' {
                display as error ///
                    `"by-variable {bf:`bv'} has different types in master and using"'
                exit 109
            }
            if !`m_isstr' {
                local m_type : type `bv'
                frame __rm_using: local u_type : type `bv'
                local m_integer = inlist("`m_type'", "byte", "int", "long")
                local u_integer = inlist("`u_type'", "byte", "int", "long")
                if "`m_type'" != "`u_type'" & !(`m_integer' & `u_integer') {
                    display as error ///
                        `"numeric by-variable {bf:`bv'} has storage types `m_type' and `u_type'"'
                    display as error ///
                        "recast the by-variable to the same exact storage type in both datasets"
                    exit 109
                }
            }
        }
    }

    local N_using = 0
    frame __rm_using: local N_using = _N

    * -------------------------------------------------------------------
    * Determine carry variables and output names
    * -------------------------------------------------------------------
    if !`dryrun_mode' {
        frame __rm_using: quietly describe, varlist short
        local all_using_vars `r(varlist)'
    }

    if `"`keepusing'"' != "" {
        local carry_vars `"`keepusing'"'
    }
    else {
        local carry_vars ""
        foreach v of local all_using_vars {
            local is_by = 0
            if "`by'" != "" {
                foreach bv of local by {
                    if "`v'" == "`bv'" local is_by = 1
                }
            }
            if !`is_by' {
                local carry_vars `"`carry_vars' `v'"'
            }
        }
        local carry_vars : list retokenize carry_vars
    }

    * Build output names (handle conflicts)
    quietly describe, varlist short
    local master_vars `r(varlist)'

    local out_names ""
    foreach v of local carry_vars {
        local outname "`prefix'`v'`suffix'"
        if "`all'" != "" {
            local out_names `"`out_names' `outname'"'
        }
        else {
            local conflict = 0
            foreach mv of local master_vars {
                if "`v'" == "`mv'" local conflict = 1
            }
            if `conflict' {
                local out_names `"`out_names' `outname'"'
            }
            else {
                local out_names `"`out_names' `v'"'
            }
        }
    }
    local out_names : list retokenize out_names

    * Check for collisions
    local all_out "`master_vars' `out_names'"
    if "`generate'" != "" local all_out "`all_out' `generate'"
    if "`distance'" != "" local all_out "`all_out' `distance'"
    if "`masterid'" != "" local all_out "`all_out' `masterid'"
    if "`usingid'" != "" local all_out "`all_out' `usingid'"
    local n_all : word count `all_out'
    local all_out_uniq : list uniq all_out
    local n_uniq : word count `all_out_uniq'
    if `n_all' != `n_uniq' {
        display as error "output variable name collision after applying prefix/suffix"
        display as error "use {bf:prefix()} or {bf:suffix()} to resolve"
        exit 110
    }

    if `_rm_timing' {
        timer off 91
        timer on 92
    }

    * -------------------------------------------------------------------
    * Preserve caller's data
    * -------------------------------------------------------------------
    preserve

    * -------------------------------------------------------------------
    * Build working frames with real (non-temp) variable names
    * -------------------------------------------------------------------
    * Master working frame: __rm_gid, __rm_low, __rm_high, __rm_obs,
    * plus __rm_key only for nearest().
    capture frame drop __rm_master
    local _rm_need_master_key = (`nearest_code' != 0)
    quietly {
        gen long __rm_obs = _n
        if `_rm_need_master_key' {
            gen double __rm_key = `key'
        }
        if "`low_kind'" == "variable" {
            gen double __rm_low = `low'
        }
        else if `low' >= . {
            gen double __rm_low = .
        }
        else {
            gen double __rm_low = `key' + (`low')
        }
        if "`high_kind'" == "variable" {
            gen double __rm_high = `high'
        }
        else if `high' >= . {
            gen double __rm_high = .
        }
        else {
            gen double __rm_high = `key' + (`high')
        }
        if `uses_key_offsets' {
            replace __rm_low = 1 if `key' >= .
            replace __rm_high = 0 if `key' >= .
        }
    }

    frame __rm_using {
        quietly gen long __rm_obs = _n
    }

    local _rm_need_obs_resort = 0
    if "`by'" != "" {
        local _rm_direct_gid = 0
        local _rm_by_n : word count `by'
        if `_rm_by_n' == 1 {
            local _rm_by1 : word 1 of `by'
            capture confirm numeric variable `_rm_by1'
            if !_rc {
                quietly count if `touse' & missing(`_rm_by1')
                local _rm_miss_master = r(N)
                frame __rm_using: quietly count if missing(`_rm_by1')
                local _rm_miss_using = r(N)
                quietly count if `touse' ///
                    & (`_rm_by1' < 1 | `_rm_by1' != floor(`_rm_by1'))
                local _rm_bad_master = r(N)
                frame __rm_using: quietly count ///
                    if `_rm_by1' < 1 | `_rm_by1' != floor(`_rm_by1')
                local _rm_bad_using = r(N)
                quietly summarize `_rm_by1' if `touse', meanonly
                local _rm_gid_max_master = r(max)
                frame __rm_using: quietly summarize `_rm_by1', meanonly
                local _rm_gid_max_using = r(max)
                local _rm_gid_max = max(`_rm_gid_max_master', ///
                    `_rm_gid_max_using')

                if `_rm_miss_master' == 0 & `_rm_miss_using' == 0 ///
                        & `_rm_bad_master' == 0 & `_rm_bad_using' == 0 ///
                        & `_rm_gid_max' <= (`N_master' + `N_using') {
                    local _rm_direct_gid = 1
                }
            }
        }

        if `_rm_direct_gid' {
            quietly gen double __rm_gid = `_rm_by1'
            frame __rm_using {
                quietly gen double __rm_gid = `_rm_by1'
            }
        }
        else {
            local _rm_need_obs_resort = 1
            * Create aligned group IDs across both frames.
            * Build catalog of unique by-value combinations from both sides,
            * then merge the sequential group ID back into each.

            * Extract unique master by-values into a temp frame
            capture frame drop __rm_grp
            quietly frame put `by' if `touse', into(__rm_grp)
            frame __rm_grp: quietly duplicates drop

            * Append unique using by-values
            frame __rm_using {
                capture frame drop __rm_grp_u
                quietly frame put `by', into(__rm_grp_u)
                frame __rm_grp_u: quietly duplicates drop
            }

            * Combine and deduplicate
            tempfile _grp_u_tmp
            frame __rm_grp_u: quietly save `"`_grp_u_tmp'"'
            frame __rm_grp {
                quietly {
                    append using `"`_grp_u_tmp'"'
                    duplicates drop
                    sort `by'
                    gen long __rm_gid = _n
                }
            }
            capture frame drop __rm_grp_u

            * Save catalog to tempfile for merging
            tempfile _grp_catalog
            frame __rm_grp: quietly save `"`_grp_catalog'"'

            * Merge group IDs into master (default frame, already preserved)
            quietly {
                merge m:1 `by' using `"`_grp_catalog'"', ///
                    keep(match master) nogenerate keepusing(__rm_gid)
                replace __rm_gid = 0 if __rm_gid >= .
            }

            * Merge group IDs into using
            frame __rm_using {
                quietly {
                    merge m:1 `by' using `"`_grp_catalog'"', ///
                        keep(match master) nogenerate keepusing(__rm_gid)
                    replace __rm_gid = 0 if __rm_gid >= .
                }
            }

            capture frame drop __rm_grp
        }
    }
    else {
        quietly gen byte __rm_gid = 1
        frame __rm_using {
            quietly gen byte __rm_gid = 1
        }
    }

    if `_rm_need_obs_resort' {
        quietly sort __rm_obs
        frame __rm_using {
            quietly sort __rm_obs
        }
    }

    * Create master work frame
    local _rm_master_work_vars "__rm_gid __rm_low __rm_high __rm_obs"
    if `_rm_need_master_key' {
        local _rm_master_work_vars "`_rm_master_work_vars' __rm_key"
    }
    quietly frame put `_rm_master_work_vars' if `touse', ///
        into(__rm_master)

    * Create using work frame
    frame __rm_using {
        quietly {
            frame put __rm_gid `key' __rm_obs, into(__rm_uwork)
        }
    }

    * -------------------------------------------------------------------
    * Call Mata backend
    * -------------------------------------------------------------------
    if "`verbose'" != "" {
        display as text "Master observations: " as result `N_master'
        display as text "Using observations:  " as result `N_using'
        display as text "By-groups:           " as result ///
            cond("`by'" != "", "yes (`by')", "none")
    }

    capture frame drop __rm_out
    if !`dryrun_mode' {
        frame create __rm_out
    }

    local _rm_show_progress = ("`verbose'" != "" & `N_master' > 100000)
    local _rm_stats_mode = ("`stats'" != "")
    local _rm_assert_match = (strpos(" `assert' ", " match ") > 0)
    local _rm_assert_using = (strpos(" `assert' ", " using ") > 0)
    local _rm_backend "binary"
    local _rm_try_sweep = (`nearest_code' == 0)
    local _rm_sweep_sort_allowed = (`sort_output' | `dryrun_mode')
    local _rm_sweep_ready 0
    local _rm_sweep_sorted 0
    local _rm_sweep_mode 0
    if `_rm_try_sweep' {
        mata: _rm_prepare_sweep_master("__rm_master", ///
            `_rm_sweep_sort_allowed')
    }
    if `_rm_try_sweep' & `_rm_sweep_ready' {
        mata: _rm_build_pairs_sweep("__rm_master", "__rm_uwork", ///
            "__rm_out", `keep_unmatched_master', `keep_unmatched_using', ///
            `maxpairs', `closed_code', `tolerance', `dryrun_mode', ///
            `_rm_show_progress', `_rm_stats_mode', `_rm_assert_match', ///
            `_rm_assert_using', `_rm_sweep_mode')
        if "`_rm_err_maxpairs'" != "1" {
            local _rm_backend "sweep"
        }
    }
    if !`_rm_try_sweep' | !`_rm_sweep_ready' {
        mata: _rm_build_pairs("__rm_master", "__rm_uwork", "__rm_out", ///
            `keep_unmatched_master', `keep_unmatched_using', ///
            `maxpairs', `closed_code', `nearest_code', `ties_code', ///
            `tolerance', `dryrun_mode', `_rm_show_progress', ///
            `_rm_stats_mode', `_rm_assert_match', `_rm_assert_using')
    }

    if `_rm_timing' {
        timer off 92
    }

    if "`_rm_err_maxpairs'" == "1" {
        display as error ///
            "maxpairs(`maxpairs') exceeded; join would produce `_rm_n_pairs' output rows"
        display as error "increase maxpairs() or add by() to reduce output size"
        exit 198
    }

    local N_pairs = `_rm_n_pairs'
    local N_matched_pairs = `_rm_n_matched_pairs'
    local N_unmatched = `N_pairs' - `N_matched_pairs'
    if `_rm_stats_mode' | `_rm_assert_match' {
        local N_unmatched_master = `_rm_n_unmatched_master'
    }
    if `_rm_stats_mode' | `_rm_assert_using' {
        local N_unmatched_using = `_rm_n_unmatched_using'
    }
    if `_rm_stats_mode' {
        local N_matched_master = `_rm_n_matched_master'
        local N_matched_using = `_rm_n_matched_using'
        local N_unmatched_master = `_rm_n_unmatched_master'
        local N_unmatched_using = `_rm_n_unmatched_using'
        local max_matches = `_rm_max_matches'
        local mean_matches = `_rm_mean_matches'
        local median_matches = `_rm_median_matches'
        local p50_matches = `_rm_p50_matches'
        local p90_matches = `_rm_p90_matches'
        local p99_matches = `_rm_p99_matches'
        local N_empty_groups = `_rm_n_empty_groups'
        local N_master_groups = `_rm_n_master_groups'
        local density_warn_threshold = 100
    }

    if `"`assert'"' != "" {
        if `_rm_assert_match' {
            if `N_unmatched_master' > 0 {
                display as error ///
                    "assert(match) failed: `N_unmatched_master' master observations had no match"
                exit 9
            }
        }
        if `_rm_assert_using' {
            if `N_unmatched_using' > 0 {
                display as error ///
                    "assert(using) failed: `N_unmatched_using' using observations had no match"
                exit 9
            }
        }
    }

    if `dryrun_mode' {
        restore

        display as text ""
        display as text "    Dry run result               " ///
            "Number of obs"
        display as text "    {hline 49}"
        display as text "    Not matched" ///
            _col(44) as result %12.0fc `N_unmatched'
        display as text "    Matched" ///
            _col(44) as result %12.0fc `N_matched_pairs'
        display as text "    {hline 49}"
        display as text "    Total output" ///
            _col(44) as result %12.0fc `N_pairs'
        display as text "    (data unchanged)"

        if `_rm_stats_mode' {
            if `max_matches' > `density_warn_threshold' {
                display as error ///
                    "warning: one master row matched `max_matches' using rows; consider maxpairs(), by(), or nearest()"
            }
            if "`by'" != "" & `N_master_groups' > 0 ///
                    & `N_empty_groups' > (`N_master_groups' / 2) {
                display as error ///
                    "warning: `N_empty_groups' of `N_master_groups' by-groups had no using rows; check by() coding"
            }

            display as text ""
            display as text "    Match density                " ///
                "Value"
            display as text "    {hline 49}"
            display as text "    Matched master rows" ///
                _col(44) as result %12.0fc `N_matched_master'
            display as text "    Unmatched master rows" ///
                _col(44) as result %12.0fc `N_unmatched_master'
            display as text "    Unmatched using rows" ///
                _col(44) as result %12.0fc `N_unmatched_using'
            display as text "    Max matches/master row" ///
                _col(44) as result %12.0fc `max_matches'
            display as text "    Mean matches/master row" ///
                _col(44) as result %12.3fc `mean_matches'
            display as text "    p50 matches/master row" ///
                _col(44) as result %12.3fc `median_matches'
            display as text "    p90 matches/master row" ///
                _col(44) as result %12.3fc `p90_matches'
            display as text "    p99 matches/master row" ///
                _col(44) as result %12.3fc `p99_matches'
            display as text "    Master groups with no using keys" ///
                _col(44) as result %12.0fc `N_empty_groups'
            display as text "    Master groups considered" ///
                _col(44) as result %12.0fc `N_master_groups'
        }

        if `_rm_timing' {
            quietly timer list 91
            local _rm_t_load = r(t91)
            quietly timer list 92
            local _rm_t_match = r(t92)
            local _rm_t_materialize = 0
            display as text ""
            display as text "    Timing                       Seconds"
            display as text "    {hline 49}"
            display as text "    Load" ///
                _col(44) as result %12.3fc `_rm_t_load'
            display as text "    Match" ///
                _col(44) as result %12.3fc `_rm_t_match'
            display as text "    Materialize" ///
                _col(44) as result %12.3fc `_rm_t_materialize'
            capture timer clear 91
            capture timer clear 92
            capture timer clear 93
        }

        return scalar N_master         = `N_master'
        return scalar N_using          = `N_using'
        return scalar N_pairs          = `N_pairs'
        return scalar N_unmatched      = `N_unmatched'
        return scalar N_matched_pairs  = `N_matched_pairs'
        return scalar N_missing_bounds = `N_missing_bounds'
        if `_rm_stats_mode' {
            return scalar N_matched_master = `N_matched_master'
            return scalar N_matched_using  = `N_matched_using'
            return scalar N_unmatched_master = `N_unmatched_master'
            return scalar N_unmatched_using = `N_unmatched_using'
            return scalar max_matches      = `max_matches'
            return scalar mean_matches     = `mean_matches'
            return scalar median_matches   = `median_matches'
            return scalar p50_matches      = `p50_matches'
            return scalar p90_matches      = `p90_matches'
            return scalar p99_matches      = `p99_matches'
            return scalar N_empty_groups   = `N_empty_groups'
            return scalar N_master_groups  = `N_master_groups'
        }
        return scalar tolerance        = `tolerance'
        return local using `"`using'"'
        return local using_source "`using_source'"
        return local key `"`key'"'
        return local low `"`low'"'
        return local high `"`high'"'
        return local by `"`by'"'
        return local keepusing `"`keepusing'"'
        return local prefix `"`prefix'"'
        return local suffix `"`suffix'"'
        return local unmatched `"`unmatched'"'
        return local closed `"`closed'"'
        return local missing `"`missing'"'
        return local nearest `"`nearest'"'
        return local ties `"`ties'"'
        return local sort "`sort'"
        return local nosort "`nosort'"
        return local assert `"`assert'"'
        return local generate `"`generate'"'
        return local distance `"`distance'"'
        return local masterid `"`masterid'"'
        return local usingid `"`usingid'"'
        return local maxpairs "`maxpairs'"
        return local all "`all'"
        return local stats "`stats'"
        return local dryrun "`dryrun'"
        return local count "`count'"
        return local verbose "`verbose'"
        return local backend "`_rm_backend'"
        return local cmdline `"`_rm_cmdline'"'
        return local cmd "rangematch"
    }
    else {

    * -------------------------------------------------------------------
    * Materialize output
    * -------------------------------------------------------------------
    if `_rm_timing' {
        timer on 93
    }

    * Materialize master variables
    if "`master_vars'" != "" {
        mata: _rm_materialize("__rm_out", "`_rm_caller_frame'", ///
            "__rm_mi", ///
            tokens(st_local("master_vars")), ///
            tokens(st_local("master_vars")))
    }

    * Materialize using variables
    if "`carry_vars'" != "" {
        mata: _rm_materialize("__rm_out", "__rm_using", ///
            "__rm_ui", ///
            tokens(st_local("carry_vars")), ///
            tokens(st_local("out_names")))
    }

    * Fill equality keys from using rows for full-outer by() output.
    if "`by'" != "" & `keep_unmatched_using' {
        mata: _rm_fill_using_only("__rm_out", "__rm_using", ///
            "__rm_mi", "__rm_ui", ///
            tokens(st_local("by")), tokens(st_local("by")))
    }

    * Expose original row numbers when requested.
    if "`masterid'" != "" {
        frame __rm_out {
            quietly gen long `masterid' = __rm_mi
        }
    }
    if "`usingid'" != "" {
        frame __rm_out {
            quietly gen long `usingid' = __rm_ui
        }
    }

    * Generate signed using-key minus master-key distance when requested.
    if "`distance'" != "" {
        mata: _rm_generate_distance("__rm_out", "`_rm_caller_frame'", ///
            "__rm_using", "__rm_mi", "__rm_ui", "`key'", "`key'", ///
            "`distance'")
    }

    * Generate match indicator
    if "`generate'" != "" {
        frame __rm_out {
            quietly gen byte `generate' = ///
                cond(__rm_mi >= . & __rm_ui < ., 2, ///
                cond(__rm_ui < ., 3, 1))
            label define __rm_merge 1 "master only" ///
                2 "using only" 3 "matched", replace
            label values `generate' __rm_merge
        }
    }

    * Apply deterministic output ordering unless the caller requests nosort.
    if `sort_output' {
        frame __rm_out {
            quietly sort __rm_mi __rm_ui
        }
    }

    * Drop internal columns
    frame __rm_out {
        quietly drop __rm_mi __rm_ui
    }

    * -------------------------------------------------------------------
    * Route output
    * -------------------------------------------------------------------
    if "`frame'" != "" {
        restore
        if "`replace'" != "" {
            capture frame drop `frame'
        }
        frame rename __rm_out `frame'
        frame change `_rm_caller_frame'
    }
    else if `"`saving_file'"' != "" {
        restore
        if "`saving_replace'" != "" {
            frame __rm_out: save `"`saving_file'"', replace
        }
        else {
            frame __rm_out: save `"`saving_file'"'
        }
        frame change `_rm_caller_frame'
    }
    else {
        restore, not
        frame change __rm_out
        capture frame drop `_rm_caller_frame'
        if _rc {
            frame change `_rm_caller_frame'

            frame __rm_out: quietly describe, varlist short
            local outvars `r(varlist)'
            frame __rm_out: local outN = _N

            clear
            quietly set obs `outN'

            * Create variables with correct types
            foreach v of local outvars {
                frame __rm_out {
                    local vtype : type `v'
                    local vfmt  : format `v'
                    local vlbl  : variable label `v'
                    local vvallbl : value label `v'
                }
                if substr("`vtype'", 1, 3) == "str" {
                    quietly gen `vtype' `v' = ""
                }
                else {
                    quietly gen `vtype' `v' = .
                }
                format `v' `vfmt'
                if `"`vlbl'"' != "" {
                    label variable `v' `"`vlbl'"'
                }
                if `"`vvallbl'"' != "" {
                    capture label values `v' `vvallbl'
                }
            }

            mata: _rm_copy_output("__rm_out", tokens(st_local("outvars")))
        }
        else {
            frame rename __rm_out `_rm_caller_frame'
        }
    }

    if `_rm_timing' {
        timer off 93
    }

    * -------------------------------------------------------------------
    * Display
    * -------------------------------------------------------------------
    display as text ""
    display as text "    Result                       " ///
        "Number of obs"
    display as text "    {hline 49}"
    display as text "    Not matched" ///
        _col(44) as result %12.0fc `N_unmatched'
    display as text "    Matched" ///
        _col(44) as result %12.0fc `N_matched_pairs'
    display as text "    {hline 49}"
    display as text "    Total output" ///
        _col(44) as result %12.0fc `N_pairs'
    if "`frame'" != "" {
        display as text "    Output frame" _col(44) as result "`frame'"
    }
    if `"`saving_file'"' != "" {
        display as text "    Output file" _col(44) as result `"`saving_file'"'
    }
    if `_rm_stats_mode' {
        if `max_matches' > `density_warn_threshold' {
            display as error ///
                "warning: one master row matched `max_matches' using rows; consider maxpairs(), by(), or nearest()"
        }
        if "`by'" != "" & `N_master_groups' > 0 ///
                & `N_empty_groups' > (`N_master_groups' / 2) {
            display as error ///
                "warning: `N_empty_groups' of `N_master_groups' by-groups had no using rows; check by() coding"
        }

        display as text ""
        display as text "    Match density                " ///
            "Value"
        display as text "    {hline 49}"
        display as text "    Matched master rows" ///
            _col(44) as result %12.0fc `N_matched_master'
        display as text "    Unmatched master rows" ///
            _col(44) as result %12.0fc `N_unmatched_master'
        display as text "    Unmatched using rows" ///
            _col(44) as result %12.0fc `N_unmatched_using'
        display as text "    Max matches/master row" ///
            _col(44) as result %12.0fc `max_matches'
        display as text "    Mean matches/master row" ///
            _col(44) as result %12.3fc `mean_matches'
        display as text "    p50 matches/master row" ///
            _col(44) as result %12.3fc `median_matches'
        display as text "    p90 matches/master row" ///
            _col(44) as result %12.3fc `p90_matches'
        display as text "    p99 matches/master row" ///
            _col(44) as result %12.3fc `p99_matches'
        display as text "    Master groups with no using keys" ///
            _col(44) as result %12.0fc `N_empty_groups'
        display as text "    Master groups considered" ///
            _col(44) as result %12.0fc `N_master_groups'
    }

    if `_rm_timing' {
        quietly timer list 91
        local _rm_t_load = r(t91)
        quietly timer list 92
        local _rm_t_match = r(t92)
        quietly timer list 93
        local _rm_t_materialize = r(t93)
        display as text ""
        display as text "    Timing                       Seconds"
        display as text "    {hline 49}"
        display as text "    Load" ///
            _col(44) as result %12.3fc `_rm_t_load'
        display as text "    Match" ///
            _col(44) as result %12.3fc `_rm_t_match'
        display as text "    Materialize" ///
            _col(44) as result %12.3fc `_rm_t_materialize'
        capture timer clear 91
        capture timer clear 92
        capture timer clear 93
    }

    * -------------------------------------------------------------------
    * Return results
    * -------------------------------------------------------------------
    return scalar N_master         = `N_master'
    return scalar N_using          = `N_using'
    return scalar N_pairs          = `N_pairs'
    return scalar N_unmatched      = `N_unmatched'
    return scalar N_matched_pairs  = `N_matched_pairs'
    return scalar N_missing_bounds = `N_missing_bounds'
    if `_rm_stats_mode' {
        return scalar N_matched_master = `N_matched_master'
        return scalar N_matched_using  = `N_matched_using'
        return scalar N_unmatched_master = `N_unmatched_master'
        return scalar N_unmatched_using = `N_unmatched_using'
        return scalar max_matches      = `max_matches'
        return scalar mean_matches     = `mean_matches'
        return scalar median_matches   = `median_matches'
        return scalar p50_matches      = `p50_matches'
        return scalar p90_matches      = `p90_matches'
        return scalar p99_matches      = `p99_matches'
        return scalar N_empty_groups   = `N_empty_groups'
        return scalar N_master_groups  = `N_master_groups'
    }
    return scalar tolerance        = `tolerance'
    return local using `"`using'"'
    return local using_source "`using_source'"
    if "`frame'" != "" return local frame "`frame'"
    if `"`saving_file'"' != "" return local saving `"`saving_file'"'
    return local key `"`key'"'
    return local low `"`low'"'
    return local high `"`high'"'
    return local by `"`by'"'
    return local keepusing `"`keepusing'"'
    return local prefix `"`prefix'"'
    return local suffix `"`suffix'"'
    return local unmatched `"`unmatched'"'
    return local closed `"`closed'"'
    return local missing `"`missing'"'
    return local nearest `"`nearest'"'
    return local ties `"`ties'"'
    return local sort "`sort'"
    return local nosort "`nosort'"
    return local assert `"`assert'"'
    return local generate `"`generate'"'
    return local distance `"`distance'"'
    return local masterid `"`masterid'"'
    return local usingid `"`usingid'"'
    return local maxpairs "`maxpairs'"
    return local all "`all'"
    return local stats "`stats'"
    return local dryrun "`dryrun'"
    return local count "`count'"
    return local verbose "`verbose'"
    return local backend "`_rm_backend'"
    return local cmdline `"`_rm_cmdline'"'
    return local cmd "rangematch"

    * Drop internal vars that may have leaked into current data
    capture drop __rm_gid __rm_obs __rm_low __rm_high __rm_key

    }

    }
    local rc = _rc
    capture frame drop __rm_master
    capture frame drop __rm_using
    capture frame drop __rm_uwork
    capture frame drop __rm_out
    capture frame drop __rm_grp
    capture frame drop __rm_grp_u
    capture matrix drop __rm_mi
    capture matrix drop __rm_ui
    capture drop __rm_gid __rm_obs __rm_low __rm_high __rm_key
    capture timer clear 91
    capture timer clear 92
    capture timer clear 93
    set varabbrev `_orig_varabbrev'
    if `rc' {
        capture restore
        exit `rc'
    }
end
