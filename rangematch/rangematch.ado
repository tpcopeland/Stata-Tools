*! rangematch Version 1.2.0  2026/06/30
*! Range join using Stata frames and Mata binary search
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

capture program drop rangematch
capture program drop _rangematch_display_counts
capture program drop _rangematch_display_stats
capture program drop _rangematch_display_timing
capture program drop _rangematch_build_output_names
capture program drop _rangematch_load_using
capture program drop _rangematch_build_group_ids
capture program drop _rangematch_run_backend
capture program drop _rangematch_warn_float

program define _rangematch_display_counts
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , TITLE(string) UNMATCHed(real) MATCHed(real) PAIRS(real) ///
            [ FRAME(string) SAVing(string) DRYRun ]

        display as text ""
        if `"`title'"' == "Dry run result" {
            display as text "    Dry run result               " ///
                "Number of obs"
        }
        else {
            display as text "    Result                       " ///
                "Number of obs"
        }
        display as text "    {hline 49}"
        display as text "    Not matched" ///
            _col(44) as result %12.0fc `unmatched'
        display as text "    Matched" ///
            _col(44) as result %12.0fc `matched'
        display as text "    {hline 49}"
        display as text "    Total output" ///
            _col(44) as result %12.0fc `pairs'
        if `"`dryrun'"' != "" {
            display as text "    (data unchanged)"
        }
        if `"`frame'"' != "" {
            display as text "    Output frame" _col(44) as result "`frame'"
        }
        if `"`saving'"' != "" {
            display as text "    Output file" _col(44) as result `"`saving'"'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_display_stats
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , MAXMatches(real) DENSITYWarn(real) ///
            NMATCHedmaster(real) NUNMATCHedmaster(real) ///
            NUNMATCHedusing(real) MEANMatches(real) ///
            MEDIANMatches(real) P90(real) P99(real) ///
            NEMPTYgroups(real) NMASTERgroups(real) [ BY(string) ]

        if `maxmatches' > `densitywarn' {
            display as error ///
                "warning: one master row matched `maxmatches' using rows; consider maxpairs(), by(), or nearest()"
        }
        if `"`by'"' != "" & `nmastergroups' > 0 ///
                & `nemptygroups' > (`nmastergroups' / 2) {
            display as error ///
                "warning: `nemptygroups' of `nmastergroups' by-groups had no using rows; check by() coding"
        }

        display as text ""
        display as text "    Match density                " ///
            "Value"
        display as text "    {hline 49}"
        display as text "    Matched master rows" ///
            _col(44) as result %12.0fc `nmatchedmaster'
        display as text "    Unmatched master rows" ///
            _col(44) as result %12.0fc `nunmatchedmaster'
        display as text "    Unmatched using rows" ///
            _col(44) as result %12.0fc `nunmatchedusing'
        display as text "    Max matches/master row" ///
            _col(44) as result %12.0fc `maxmatches'
        display as text "    Mean matches/master row" ///
            _col(44) as result %12.3fc `meanmatches'
        display as text "    p50 matches/master row" ///
            _col(44) as result %12.3fc `medianmatches'
        display as text "    p90 matches/master row" ///
            _col(44) as result %12.3fc `p90'
        display as text "    p99 matches/master row" ///
            _col(44) as result %12.3fc `p99'
        display as text "    Master groups with no using keys" ///
            _col(44) as result %12.0fc `nemptygroups'
        display as text "    Master groups considered" ///
            _col(44) as result %12.0fc `nmastergroups'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_display_timing
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , LOADTime(real) MATCHTime(real) MATERIALIZETime(real)

        display as text ""
        display as text "    Timing                       Seconds"
        display as text "    {hline 49}"
        display as text "    Load" ///
            _col(44) as result %12.3fc `loadtime'
        display as text "    Match" ///
            _col(44) as result %12.3fc `matchtime'
        if `materializetime' >= . {
            display as text "    Materialize" ///
                _col(44) as result "     (skipped)"
        }
        else {
            display as text "    Materialize" ///
                _col(44) as result %12.3fc `materializetime'
        }
        capture timer clear 91
        capture timer clear 92
        capture timer clear 93
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_build_output_names, sclass
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args all_using_vars touse keepusing by prefix suffix all generate ///
            distance masterid usingid

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

        quietly describe, varlist short
        local master_vars `r(varlist)'
        local _rm_touse_var "`touse'"
        local master_vars : list master_vars - _rm_touse_var

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

        sreturn clear
        sreturn local carry_vars `"`carry_vars'"'
        sreturn local master_vars `"`master_vars'"'
        sreturn local out_names `"`out_names'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_load_using, sclass
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args using key by keepusing dryrun_mode caller_frame

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
            if "`using_frame'" == "`caller_frame'" {
                display as error "using frame must be different from the current frame"
                exit 198
            }
            if substr("`using_frame'", 1, 5) == "__rm_" {
                display as error "using frame may not use names beginning with __rm_"
                exit 198
            }
        }
        else {
            * Mirror Stata's `use` behavior: append .dta if no extension supplied
            capture confirm file `"`using'"'
            if _rc {
                capture confirm file `"`using'.dta"'
                if !_rc {
                    local using `"`using'.dta"'
                }
                else {
                    confirm file `"`using'"'
                }
            }
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
        local using_load_vars : list uniq using_load_vars

        capture frame drop __rm_using
        local _rm_drop_rc = _rc
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

        sreturn clear
        sreturn local using `"`using'"'
        sreturn local using_source "`using_source'"
        sreturn local using_frame "`using_frame'"
        sreturn local using_is_frame "`using_is_frame'"
        sreturn local all_using_vars `"`all_using_vars'"'
        sreturn local N_using_pre "`N_using_pre'"
        sreturn local N_using "`N_using'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_build_group_ids
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args by touse N_master N_using master_gid using_gid master_obs using_obs

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
                quietly gen double `master_gid' = `_rm_by1'
                frame __rm_using {
                    quietly gen double `using_gid' = `_rm_by1'
                }
            }
            else {
                tempvar _rm_catalog_gid
                local _rm_need_obs_resort = 1
                capture frame drop __rm_grp
                local _rm_drop_rc = _rc
                quietly frame put `by' if `touse', into(__rm_grp)
                frame __rm_grp: quietly duplicates drop

                frame __rm_using {
                    capture frame drop __rm_grp_u
                    local _rm_drop_rc = _rc
                    quietly frame put `by', into(__rm_grp_u)
                    frame __rm_grp_u: quietly duplicates drop
                }

                tempfile _grp_u_tmp
                frame __rm_grp_u: quietly save `"`_grp_u_tmp'"'
                frame __rm_grp {
                    quietly {
                        append using `"`_grp_u_tmp'"'
                        duplicates drop
                        sort `by'
                        gen long `_rm_catalog_gid' = _n
                    }
                }
                capture frame drop __rm_grp_u
                local _rm_drop_rc = _rc

                tempfile _grp_catalog
                frame __rm_grp: quietly save `"`_grp_catalog'"'

                quietly {
                    merge m:1 `by' using `"`_grp_catalog'"', ///
                        keep(match master) nogenerate ///
                        keepusing(`_rm_catalog_gid')
                    rename `_rm_catalog_gid' `master_gid'
                    replace `master_gid' = 0 if `master_gid' >= .
                }

                frame __rm_using {
                    quietly {
                        merge m:1 `by' using `"`_grp_catalog'"', ///
                            keep(match master) nogenerate ///
                            keepusing(`_rm_catalog_gid')
                        rename `_rm_catalog_gid' `using_gid'
                        replace `using_gid' = 0 if `using_gid' >= .
                    }
                }

                capture frame drop __rm_grp
                local _rm_drop_rc = _rc
            }
        }
        else {
            quietly gen byte `master_gid' = 1
            frame __rm_using {
                quietly gen byte `using_gid' = 1
            }
        }

        if `_rm_need_obs_resort' {
            quietly sort `master_obs'
            frame __rm_using {
                quietly sort `using_obs'
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_run_backend, sclass
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , TRYSweep(real) SWEEPSort(real) DRYRun(real) ///
            SHOWProgress(real) STATSmode(real) ASSERTMatch(real) ///
            ASSERTUsing(real) KEEPMASTER(real) KEEPUSING(real) ///
            MAXPairs(real) CLOSEDCode(real) TOLerance(real) ///
            NEARESTCode(real) TIESCode(real) TIMing(real) ///
            OVERLAPMode(real)

        capture frame drop __rm_out
        local _rm_drop_rc = _rc
        if !`dryrun' {
            frame create __rm_out
        }

        local _rm_backend "binary"
        local _rm_sweep_ready 0
        local _rm_sweep_mode 0
        if `overlapmode' {
            mata: _rm_build_pairs_overlap("__rm_master", "__rm_uwork", ///
                "__rm_out", `keepmaster', `keepusing', `maxpairs', ///
                `closedcode', `tolerance', `dryrun', `showprogress', ///
                `statsmode', `assertmatch', `assertusing')
            local _rm_backend "overlap"
        }
        else {
            if `trysweep' {
                mata: _rm_prepare_sweep_master("__rm_master", `sweepsort')
            }
            if `trysweep' & `_rm_sweep_ready' {
                mata: _rm_build_pairs_sweep("__rm_master", "__rm_uwork", ///
                    "__rm_out", `keepmaster', `keepusing', ///
                    `maxpairs', `closedcode', `tolerance', `dryrun', ///
                    `showprogress', `statsmode', `assertmatch', ///
                    `assertusing', `_rm_sweep_mode')
                if "`_rm_err_maxpairs'" != "1" {
                    local _rm_backend "sweep"
                }
            }
            if !`trysweep' | !`_rm_sweep_ready' {
                mata: _rm_build_pairs("__rm_master", "__rm_uwork", ///
                    "__rm_out", `keepmaster', `keepusing', `maxpairs', ///
                    `closedcode', `nearestcode', `tiescode', `tolerance', ///
                    `dryrun', `showprogress', `statsmode', `assertmatch', ///
                    `assertusing')
            }
        }

        if `timing' {
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
        if `statsmode' | `assertmatch' {
            local N_unmatched_master = `_rm_n_unmatched_master'
        }
        if `statsmode' | `assertusing' {
            local N_unmatched_using = `_rm_n_unmatched_using'
        }
        if `statsmode' {
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
        }

        if `assertmatch' {
            if `N_unmatched_master' > 0 {
                display as error ///
                    "assert(match) failed: `N_unmatched_master' master observations had no match"
                exit 9
            }
        }
        if `assertusing' {
            if `N_unmatched_using' > 0 {
                display as error ///
                    "assert(using) failed: `N_unmatched_using' using observations had no match"
                exit 9
            }
        }

        sreturn clear
        sreturn local backend "`_rm_backend'"
        sreturn local N_pairs "`N_pairs'"
        sreturn local N_matched_pairs "`N_matched_pairs'"
        sreturn local N_unmatched "`N_unmatched'"
        if `statsmode' | `assertmatch' {
            sreturn local N_unmatched_master "`N_unmatched_master'"
        }
        if `statsmode' | `assertusing' {
            sreturn local N_unmatched_using "`N_unmatched_using'"
        }
        if `statsmode' {
            sreturn local N_matched_master "`N_matched_master'"
            sreturn local N_matched_using "`N_matched_using'"
            sreturn local max_matches "`max_matches'"
            sreturn local mean_matches "`mean_matches'"
            sreturn local median_matches "`median_matches'"
            sreturn local p50_matches "`p50_matches'"
            sreturn local p90_matches "`p90_matches'"
            sreturn local p99_matches "`p99_matches'"
            sreturn local N_empty_groups "`N_empty_groups'"
            sreturn local N_master_groups "`N_master_groups'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _rangematch_warn_float
    * Emit a non-fatal precision warning when a matching variable is stored as
    * float and carries values beyond float's exact-integer range (2^24). Such
    * values (notably %tc datetime clocks) lose precision at boundary equality;
    * %td dates and small magnitudes are within float's exact range and are not
    * flagged. frm == "." means the current (master) data; otherwise a frame.
    version 16.1
    args lab frm var restrict
    local _hz 0
    if `"`frm'"' == "." {
        local _t : type `var'
        if "`_t'" == "float" {
            quietly count if `restrict' & !missing(`var') & abs(`var') > 16777216
            if r(N) > 0 local _hz 1
        }
    }
    else {
        frame `frm' {
            local _t : type `var'
            if "`_t'" == "float" {
                quietly count if !missing(`var') & abs(`var') > 16777216
                if r(N) > 0 local _hz 1
            }
        }
    }
    if `_hz' {
        display as error ///
            "warning: `lab' {bf:`var'} is stored as float with values beyond 2^24;"
        display as error ///
            "         boundary matches may be imprecise -- recast to double or use tolerance()"
    }
end

program define rangematch, rclass
    version 16.1
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * Load Mata backend only when missing or stale.
    local _rm_required_mata_version "1.2.0"
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
          MASTERID(name) USINGID(name) OVERLAP(string) ///
          MAXPairs(integer 0) FRAME(name) REPLACE STATS NOSORT ///
          CLOSED(string) NEARest(string) TIES(string) ///
          TOLerance(real 0) MISSing(string) ///
          ASsert(string) SAVing(string asis) DRYRun COUNT VERBOSE ]

    * -------------------------------------------------------------------
    * Interval-overlap mode is selected by overlap(ulow uhigh). It names
    * the two using-interval bound variables; the positional low/high then
    * define the master interval (no point keyvar).
    * -------------------------------------------------------------------
    local overlap_mode = 0
    local ulo ""
    local uhi ""
    if `"`overlap'"' != "" {
        local overlap_mode = 1
        tokenize `"`overlap'"'
        local ulo `"`1'"'
        local uhi `"`2'"'
        if `"`3'"' != "" {
            display as error ///
                "overlap() takes exactly two using variables: ulow uhigh"
            exit 198
        }
        if `"`uhi'"' == "" {
            display as error ///
                "overlap() requires two using variables: ulow uhigh"
            exit 198
        }
        confirm name `ulo'
        confirm name `uhi'
    }

    tokenize `"`interval'"'
    if `overlap_mode' {
        local key   ""
        local low   `"`1'"'
        local high  `"`2'"'
        if `"`3'"' != "" {
            display as error ///
                "with overlap(), specify only the master interval: low high"
            exit 103
        }
        if `"`high'"' == "" {
            display as error ///
                "with overlap(), specify the master interval: low high"
            exit 102
        }
    }
    else {
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

    * -------------------------------------------------------------------
    * Overlap-mode constraints. Point-only features (scalar offsets,
    * nearest/ties/distance) have no meaning when both sides are intervals,
    * and endpoint closure is restricted to both/none (left/right are
    * ambiguous for an interval-interval comparison).
    * -------------------------------------------------------------------
    if `overlap_mode' {
        if `uses_key_offsets' {
            display as error ///
                "overlap() does not support scalar offset bounds; use master interval variables or {bf:.}"
            exit 198
        }
        if `"`nearest'"' != "" {
            display as error "nearest() is not allowed with overlap()"
            exit 198
        }
        if "`distance'" != "" {
            display as error "distance() is not allowed with overlap()"
            exit 198
        }
        if `"`ties'"' != "" {
            display as error "ties() is not allowed with overlap()"
            exit 198
        }
        local _rm_ovclosed = lower(strtrim(`"`closed'"'))
        if "`_rm_ovclosed'" != "" & !inlist("`_rm_ovclosed'", "both", "none") {
            display as error ///
                "overlap() supports only {bf:closed(both)} or {bf:closed(none)}"
            exit 198
        }
    }

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

    if `maxpairs' < 0 {
        display as error "maxpairs() must be a nonnegative integer"
        exit 198
    }

    if `"`missing'"' == "" local missing "wildcard"
    local missing = lower(`"`missing'"')
    if !inlist(`"`missing'"', "wildcard", "drop", "error") {
        display as error ///
            "missing() must be {bf:wildcard}, {bf:drop}, or {bf:error}"
        exit 198
    }

    if "`nosort'" == "nosort" {
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
        foreach _rm_timer in 91 92 93 {
            capture timer clear `_rm_timer'
            local _rm_timer_rc = _rc
        }
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
        local saving_file = subinstr(`"`saving_file'"', char(34), "", .)
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

    * -------------------------------------------------------------------
    * Load and validate using data
    * -------------------------------------------------------------------
    if `overlap_mode' {
        local _rm_using_keys "`ulo' `uhi'"
    }
    else {
        local _rm_using_keys "`key'"
    }
    _rangematch_load_using `"`using'"' `"`_rm_using_keys'"' `"`by'"' ///
        `"`keepusing'"' `"`dryrun_mode'"' `"`_rm_caller_frame'"'
    local using `"`s(using)'"'
    local using_source "`s(using_source)'"
    local using_frame "`s(using_frame)'"
    local using_is_frame = `s(using_is_frame)'
    local all_using_vars `"`s(all_using_vars)'"'
    local N_using_pre = `s(N_using_pre)'
    local N_using = `s(N_using)'

    * -------------------------------------------------------------------
    * Apply the missing() policy to the using side, symmetrically with the
    * master side. wildcard (the default) preserves historical behavior
    * exactly: in point mode a missing using key never matches; in overlap
    * mode a missing using bound is open-ended on that side. error and drop
    * extend the policy to the using rows. This runs before _rm_uobs is
    * generated so dropped rows never enter the work frame or the output.
    * -------------------------------------------------------------------
    if `overlap_mode' {
        frame __rm_using: quietly count if missing(`ulo') | missing(`uhi')
    }
    else {
        frame __rm_using: quietly count if missing(`key')
    }
    local N_using_missing = r(N)
    if `N_using_missing' > 0 {
        if "`missing'" != "wildcard" {
            if "`missing'" == "error" {
                if `overlap_mode' {
                    display as error ///
                        "`N_using_missing' using row(s) have missing values in {bf:`ulo'} or {bf:`uhi'}"
                }
                else {
                    display as error ///
                        "`N_using_missing' using row(s) have a missing match key {bf:`key'}"
                }
                display as error ///
                    "specify {bf:missing(drop)} to ignore them or {bf:missing(wildcard)} to keep open-ended/never-match behavior"
                exit 459
            }
            else if "`missing'" == "drop" {
                if `overlap_mode' {
                    frame __rm_using: quietly drop if missing(`ulo') | missing(`uhi')
                }
                else {
                    frame __rm_using: quietly drop if missing(`key')
                }
                frame __rm_using: local N_using = _N
                if `N_using' == 0 {
                    display as error ///
                        "missing(drop) removed all using observations"
                    exit 2000
                }
            }
        }
    }

    * -------------------------------------------------------------------
    * Non-fatal float-precision warnings (A2). Matching variables stored as
    * float lose exact equality beyond 2^24 (notably %tc clocks); flag them so
    * the user can recast to double or use tolerance(). %td dates and small
    * magnitudes are within float's exact-integer range and are not flagged.
    * -------------------------------------------------------------------
    if "`low_kind'" == "variable" {
        _rangematch_warn_float "master bound" "." `low' "`touse'"
    }
    if "`high_kind'" == "variable" {
        _rangematch_warn_float "master bound" "." `high' "`touse'"
    }
    if `overlap_mode' {
        _rangematch_warn_float "using bound" "__rm_using" `ulo' ""
        _rangematch_warn_float "using bound" "__rm_using" `uhi' ""
    }
    else {
        if `uses_key_offsets' {
            _rangematch_warn_float "master key" "." `key' "`touse'"
        }
        _rangematch_warn_float "using key" "__rm_using" `key' ""
    }

    * -------------------------------------------------------------------
    * Determine carry variables and output names
    * -------------------------------------------------------------------
    if !`dryrun_mode' {
        frame __rm_using: quietly describe, varlist short
        local all_using_vars `r(varlist)'
    }

    _rangematch_build_output_names `"`all_using_vars'"' `"`touse'"' ///
        `"`keepusing'"' `"`by'"' `"`prefix'"' `"`suffix'"' `"`all'"' ///
        `"`generate'"' `"`distance'"' `"`masterid'"' `"`usingid'"'
    local carry_vars `"`s(carry_vars)'"'
    local master_vars `"`s(master_vars)'"'
    local out_names `"`s(out_names)'"'

    if `_rm_timing' {
        timer off 91
        timer on 92
    }

    * -------------------------------------------------------------------
    * Preserve caller's data
    * -------------------------------------------------------------------
    preserve

    * -------------------------------------------------------------------
    * Build working frames. User-facing frames use tempvars; disposable work
    * frames are renamed to the fixed column order expected by the Mata backend.
    * -------------------------------------------------------------------
    * Master work frame: __rm_gid, __rm_low, __rm_high, __rm_obs,
    * plus __rm_key only for nearest().
    capture frame drop __rm_master
    local _rm_drop_rc = _rc
    local _rm_need_master_key = (`nearest_code' != 0)
    tempvar _rm_obs _rm_key _rm_low _rm_high _rm_gid _rm_uobs _rm_ugid
    quietly {
        gen long `_rm_obs' = _n
        if `_rm_need_master_key' {
            gen double `_rm_key' = `key'
        }
        if "`low_kind'" == "variable" {
            gen double `_rm_low' = `low'
        }
        else if `low' >= . {
            gen double `_rm_low' = .
        }
        else {
            gen double `_rm_low' = `key' + (`low')
        }
        if "`high_kind'" == "variable" {
            gen double `_rm_high' = `high'
        }
        else if `high' >= . {
            gen double `_rm_high' = .
        }
        else {
            gen double `_rm_high' = `key' + (`high')
        }
        if `uses_key_offsets' {
            replace `_rm_low' = 1 if `key' >= .
            replace `_rm_high' = 0 if `key' >= .
        }
    }

    frame __rm_using {
        quietly gen long `_rm_uobs' = _n
    }
    _rangematch_build_group_ids `"`by'"' `"`touse'"' ///
        `"`N_master'"' `"`N_using'"' `"`_rm_gid'"' `"`_rm_ugid'"' ///
        `"`_rm_obs'"' `"`_rm_uobs'"'

    * Create master work frame
    local _rm_master_work_vars "`_rm_gid' `_rm_low' `_rm_high' `_rm_obs'"
    if `_rm_need_master_key' {
        local _rm_master_work_vars "`_rm_master_work_vars' `_rm_key'"
    }
    quietly frame put `_rm_master_work_vars' if `touse', ///
        into(__rm_master)
    frame __rm_master {
        rename `_rm_gid' __rm_gid
        rename `_rm_low' __rm_low
        rename `_rm_high' __rm_high
        rename `_rm_obs' __rm_obs
        if `_rm_need_master_key' {
            rename `_rm_key' __rm_key
        }
    }

    * Create using work frame
    frame __rm_using {
        quietly {
            frame put `_rm_ugid' `_rm_using_keys' `_rm_uobs', into(__rm_uwork)
        }
    }
    frame __rm_uwork {
        rename `_rm_ugid' __rm_gid
        rename `_rm_uobs' __rm_obs
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

    local _rm_show_progress = ("`verbose'" != "" & `N_master' > 100000)
    local _rm_stats_mode = ("`stats'" != "")
    local _rm_assert_match = (strpos(" `assert' ", " match ") > 0)
    local _rm_assert_using = (strpos(" `assert' ", " using ") > 0)
    local _rm_try_sweep = (`nearest_code' == 0 & !`overlap_mode')
    local _rm_sweep_sort_allowed = (`sort_output' | `dryrun_mode')

    _rangematch_run_backend, trysweep(`_rm_try_sweep') ///
        sweepsort(`_rm_sweep_sort_allowed') dryrun(`dryrun_mode') ///
        showprogress(`_rm_show_progress') statsmode(`_rm_stats_mode') ///
        assertmatch(`_rm_assert_match') assertusing(`_rm_assert_using') ///
        keepmaster(`keep_unmatched_master') keepusing(`keep_unmatched_using') ///
        maxpairs(`maxpairs') closedcode(`closed_code') ///
        tolerance(`tolerance') nearestcode(`nearest_code') ///
        tiescode(`ties_code') timing(`_rm_timing') ///
        overlapmode(`overlap_mode')

    local _rm_backend "`s(backend)'"
    local N_pairs = `s(N_pairs)'
    local N_matched_pairs = `s(N_matched_pairs)'
    local N_unmatched = `s(N_unmatched)'
    if `_rm_stats_mode' | `_rm_assert_match' {
        local N_unmatched_master = `s(N_unmatched_master)'
    }
    if `_rm_stats_mode' | `_rm_assert_using' {
        local N_unmatched_using = `s(N_unmatched_using)'
    }
    if `_rm_stats_mode' {
        local N_matched_master = `s(N_matched_master)'
        local N_matched_using = `s(N_matched_using)'
        local N_unmatched_master = `s(N_unmatched_master)'
        local N_unmatched_using = `s(N_unmatched_using)'
        local max_matches = `s(max_matches)'
        local mean_matches = `s(mean_matches)'
        local median_matches = `s(median_matches)'
        local p50_matches = `s(p50_matches)'
        local p90_matches = `s(p90_matches)'
        local p99_matches = `s(p99_matches)'
        local N_empty_groups = `s(N_empty_groups)'
        local N_master_groups = `s(N_master_groups)'
        local density_warn_threshold = 100
    }

    if `dryrun_mode' {
        restore

        _rangematch_display_counts, title("Dry run result") ///
            unmatched(`N_unmatched') matched(`N_matched_pairs') ///
            pairs(`N_pairs') dryrun

        if `_rm_stats_mode' {
            if "`by'" != "" {
                _rangematch_display_stats, maxmatches(`max_matches') ///
                    densitywarn(`density_warn_threshold') ///
                    nmatchedmaster(`N_matched_master') ///
                    nunmatchedmaster(`N_unmatched_master') ///
                    nunmatchedusing(`N_unmatched_using') ///
                    meanmatches(`mean_matches') ///
                    medianmatches(`median_matches') ///
                    p90(`p90_matches') p99(`p99_matches') ///
                    nemptygroups(`N_empty_groups') ///
                    nmastergroups(`N_master_groups') by("`by'")
            }
            else {
                _rangematch_display_stats, maxmatches(`max_matches') ///
                    densitywarn(`density_warn_threshold') ///
                    nmatchedmaster(`N_matched_master') ///
                    nunmatchedmaster(`N_unmatched_master') ///
                    nunmatchedusing(`N_unmatched_using') ///
                    meanmatches(`mean_matches') ///
                    medianmatches(`median_matches') ///
                    p90(`p90_matches') p99(`p99_matches') ///
                    nemptygroups(`N_empty_groups') ///
                    nmastergroups(`N_master_groups')
            }
        }

        if `_rm_timing' {
            quietly timer list 91
            local _rm_t_load = r(t91)
            quietly timer list 92
            local _rm_t_match = r(t92)
            local _rm_t_materialize = .
            _rangematch_display_timing, loadtime(`_rm_t_load') ///
                matchtime(`_rm_t_match') ///
                materializetime(`_rm_t_materialize')
        }

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
            local _rm_drop_rc = _rc
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
                    local _rm_label_rc = _rc
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
    if "`frame'" != "" {
        _rangematch_display_counts, title("Result") ///
            unmatched(`N_unmatched') matched(`N_matched_pairs') ///
            pairs(`N_pairs') frame("`frame'")
    }
    else if `"`saving_file'"' != "" {
        _rangematch_display_counts, title("Result") ///
            unmatched(`N_unmatched') matched(`N_matched_pairs') ///
            pairs(`N_pairs') saving(`"`saving_file'"')
    }
    else {
        _rangematch_display_counts, title("Result") ///
            unmatched(`N_unmatched') matched(`N_matched_pairs') ///
            pairs(`N_pairs')
    }
    if `_rm_stats_mode' {
        if "`by'" != "" {
            _rangematch_display_stats, maxmatches(`max_matches') ///
                densitywarn(`density_warn_threshold') ///
                nmatchedmaster(`N_matched_master') ///
                nunmatchedmaster(`N_unmatched_master') ///
                nunmatchedusing(`N_unmatched_using') ///
                meanmatches(`mean_matches') ///
                medianmatches(`median_matches') ///
                p90(`p90_matches') p99(`p99_matches') ///
                nemptygroups(`N_empty_groups') ///
                nmastergroups(`N_master_groups') by("`by'")
        }
        else {
            _rangematch_display_stats, maxmatches(`max_matches') ///
                densitywarn(`density_warn_threshold') ///
                nmatchedmaster(`N_matched_master') ///
                nunmatchedmaster(`N_unmatched_master') ///
                nunmatchedusing(`N_unmatched_using') ///
                meanmatches(`mean_matches') ///
                medianmatches(`median_matches') ///
                p90(`p90_matches') p99(`p99_matches') ///
                nemptygroups(`N_empty_groups') ///
                nmastergroups(`N_master_groups')
        }
    }

    if `_rm_timing' {
        quietly timer list 91
        local _rm_t_load = r(t91)
        quietly timer list 92
        local _rm_t_match = r(t92)
        quietly timer list 93
        local _rm_t_materialize = r(t93)
        _rangematch_display_timing, loadtime(`_rm_t_load') ///
            matchtime(`_rm_t_match') ///
            materializetime(`_rm_t_materialize')
    }
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
    return scalar N_using_missing  = `N_using_missing'
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
    if "`frame'" != "" & !`dryrun_mode' return local frame "`frame'"
    if `"`saving_file'"' != "" & !`dryrun_mode' return local saving `"`saving_file'"'
    return local key `"`key'"'
    return local low `"`low'"'
    return local high `"`high'"'
    if `overlap_mode' return local overlap `"`ulo' `uhi'"'
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
    local rc = _rc
    foreach _rm_frame in __rm_master __rm_using __rm_uwork __rm_out __rm_grp __rm_grp_u {
        capture frame drop `_rm_frame'
        local _rm_cleanup_rc = _rc
    }
    foreach _rm_matrix in __rm_mi __rm_ui {
        capture matrix drop `_rm_matrix'
        local _rm_cleanup_rc = _rc
    }
    foreach _rm_timer in 91 92 93 {
        capture timer clear `_rm_timer'
        local _rm_cleanup_rc = _rc
    }
    set varabbrev `_orig_varabbrev'
    if `rc' {
        capture restore
        exit `rc'
    }
end
