*! _datamap_classify Version 1.1.1  2026/06/16
*! Shared classification engine for datamap and datadict
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_classify, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _post_open = 0
    capture noisily {
        syntax using/ , SAVing(string) [MAXCat(integer 25) OBS(integer -1) ///
            EXClude(string) DETECT_binary(integer 0) QUality_level(string) ///
            LOADED]

        if `maxcat' <= 0 {
            noisily display as error "maxcat must be positive"
            exit 198
        }
        if !inlist("`quality_level'", "", "basic", "strict") {
            noisily display as error "quality_level must be blank, basic, or strict"
            exit 198
        }

        if "`loaded'" == "" {
            confirm file `"`using'"'
            quietly use `"`using'"', clear
        }
        else if c(N) == 0 | c(k) == 0 {
            noisily display as error "loaded classification requires data in memory"
            exit 198
        }
        if `obs' < 0 local obs = c(N)

        quietly describe, varlist
        local all_vars `r(varlist)'
        local nvars : word count `all_vars'

        tempname posth
        postfile `posth' str32 varname str12 vartype str48 varformat ///
            str2045 varlabel str80 valuelabel double missing_n ///
            double missing_pct str16 classification double unique_vals ///
            byte is_binary str80 quality_flag int orig_position ///
            double max_length using `"`saving'"', replace
        local _post_open = 1

        local categorical_vars ""
        local continuous_vars ""
        local date_vars ""
        local string_vars ""
        local excluded_vars ""
        local suggested_exclude ""
        local n_categorical = 0
        local n_continuous = 0
        local n_date = 0
        local n_string = 0
        local n_excluded = 0
        local n_suggested_exclude = 0

        local i = 0
        foreach vname of local all_vars {
            local ++i
            local vtype : type `vname'
            local vfmt : format `vname'
            local vlab : variable label `vname'
            local valab : value label `vname'

            quietly count if missing(`vname')
            local nmiss = r(N)
            local pctmiss = 0
            if `obs' > 0 {
                local pctmiss = round(100 * `nmiss' / `obs', 0.1)
            }

            local isexcluded = 0
            foreach ev of local exclude {
                if "`vname'" == "`ev'" local isexcluded = 1
            }

            local nuniq .
            local is_binary = 0
            local maxlen .

            // Privacy: never compute values/stats for excluded variables.
            // Leaving unique_vals/is_binary/max_length unset is what stops the
            // Binary section, QUICK REFERENCE, and JSON from leaking an excluded
            // variable's cardinality, max length, or frequency distribution.
            if !`isexcluded' {
                if strpos("`vtype'", "str") == 1 {
                    capture quietly duplicates report `vname'
                    if _rc == 0 local nuniq = r(unique_value)

                    tempvar _slen
                    quietly gen double `_slen' = length(`vname')
                    quietly summarize `_slen'
                    if r(N) > 0 local maxlen = r(max)
                    quietly drop `_slen'
                }
                else {
                    capture quietly tab `vname'
                    if _rc == 0 {
                        local nuniq = r(r)
                        if `detect_binary' & r(r) == 2 local is_binary = 1
                    }
                    else {
                        capture quietly duplicates report `vname'
                        if _rc == 0 local nuniq = r(unique_value)
                    }
                }
            }

            local class ""
            if `isexcluded' {
                local class "excluded"
            }
            else if strpos("`vtype'", "str") == 1 {
                local class "string"
            }
            else if strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0 {
                local class "date"
            }
            else if "`valab'" != "" {
                local class "categorical"
            }
            else if `nuniq' < . & `nuniq' <= `maxcat' {
                local class "categorical"
            }
            else {
                local class "continuous"
            }

            local qflag ""
            if "`quality_level'" != "" & !`isexcluded' {
                capture confirm numeric variable `vname'
                if _rc == 0 {
                    if regexm(lower("`vname'"), "^age$|^age_|_age$|_age_") {
                        quietly summarize `vname'
                        if !missing(r(min)) & r(min) < 0 {
                            local qflag "negative age values"
                        }
                        else if !missing(r(max)) {
                            if "`quality_level'" == "strict" & r(max) > 100 {
                                local qflag "age >100"
                            }
                            else if r(max) > 120 {
                                local qflag "age >120"
                            }
                        }
                    }
                    else if regexm(lower("`vname'"), "^count$|_count$|_count_|^n_|^number$|_number$") {
                        quietly summarize `vname'
                        if !missing(r(min)) & r(min) < 0 {
                            local qflag "negative count"
                        }
                    }
                    else if regexm(lower("`vname'"), "^percent$|_percent$|^pct$|_pct$|_pct_|^proportion$|_proportion$") {
                        quietly summarize `vname'
                        if !missing(r(min)) & (r(min) < 0 | r(max) > 100) {
                            local qflag "percent out of range 0-100"
                        }
                    }
                }
            }

            if "`class'" == "categorical" {
                local ++n_categorical
                local categorical_vars "`categorical_vars' `vname'"
            }
            else if "`class'" == "continuous" {
                local ++n_continuous
                local continuous_vars "`continuous_vars' `vname'"
            }
            else if "`class'" == "date" {
                local ++n_date
                local date_vars "`date_vars' `vname'"
            }
            else if "`class'" == "string" {
                local ++n_string
                local string_vars "`string_vars' `vname'"
            }
            else if "`class'" == "excluded" {
                local ++n_excluded
                local excluded_vars "`excluded_vars' `vname'"
            }

            if regexm(lower("`vname'"), "id$|_id$|^id_|patient|subject|person|lopnr|identifier") & !`isexcluded' {
                local ++n_suggested_exclude
                local suggested_exclude "`suggested_exclude' `vname'"
            }

            // Privacy: do not attribute a value label to an excluded variable.
            // Blanking it here drops the variable from the VALUE LABEL
            // DEFINITIONS section and the JSON value_label field, so an excluded
            // variable's coding (e.g. 0=Negative/1=Positive) is not disclosed.
            // A label shared with a non-excluded variable still prints via that
            // variable; classification above already used the real `valab'.
            local valab_post `"`valab'"'
            if `isexcluded' local valab_post ""

            post `posth' (`"`vname'"') (`"`vtype'"') (`"`vfmt'"') ///
                (`"`macval(vlab)'"') (`"`valab_post'"') (`nmiss') (`pctmiss') ///
                (`"`class'"') (`nuniq') (`is_binary') (`"`qflag'"') (`i') (`maxlen')
        }

        postclose `posth'
        local _post_open = 0

        return scalar nvars = `nvars'
        return scalar n_categorical = `n_categorical'
        return scalar n_continuous = `n_continuous'
        return scalar n_date = `n_date'
        return scalar n_string = `n_string'
        return scalar n_excluded = `n_excluded'
        return scalar n_suggested_exclude = `n_suggested_exclude'
        return local all_vars "`all_vars'"
        return local categorical_vars "`categorical_vars'"
        return local continuous_vars "`continuous_vars'"
        return local date_vars "`date_vars'"
        return local string_vars "`string_vars'"
        return local excluded_vars "`excluded_vars'"
        return local suggested_exclude "`suggested_exclude'"
    }
    local rc = _rc
	    if `_post_open' {
	        capture postclose `posth'
	        local _postclose_rc = _rc
	        if !`rc' & `_postclose_rc' local rc = `_postclose_rc'
	    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
