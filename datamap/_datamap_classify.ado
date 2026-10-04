*! _datamap_classify Version 1.9.1  2026/10/04
*! Shared classification engine for datamap and datadict
*! Author: Timothy P Copeland, Karolinska Institutet

// Builds the caller's local `dst' as a Stata string expression that evaluates
// to the caller's local `src' verbatim: runs of ordinary characters in plain
// quotes joined with char() calls for each double quote, backtick and dollar
// sign, so a label holding any of them cannot be read as quote or macro syntax
// when the expression is spliced into a -post- line.
capture mata: mata drop _datamap_strexpr()
mata:
void _datamap_strexpr(string scalar src, string scalar dst)
{
	string scalar s, out, run, ch
	real scalar i, a
	s = st_local(src)
	out = ""
	run = ""
	for (i = 1; i <= strlen(s); i++) {
		ch = substr(s, i, 1)
		a = ascii(ch)
		if (a == 34 | a == 96 | a == 36) {
			if (run != "") out = out + (out == "" ? "" : "+") + char(34) + run + char(34)
			run = ""
			out = out + (out == "" ? "" : "+") + "char(" + strofreal(a) + ")"
		}
		else run = run + ch
	}
	if (run != "" | out == "") out = out + (out == "" ? "" : "+") + char(34) + run + char(34)
	st_local(dst, "(" + out + ")")
}
end

program define _datamap_classify, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _post_open = 0
    local _pfh_open = 0
    capture noisily {
        syntax using/ , [SAVing(string) MAXCat(integer 25) OBS(integer -1) ///
            EXClude(string) CONTinuous(string) CATegorical(string) date(string) ///
            DETECT_binary(integer 0) QUality_level(string) LOADED ///
            CAPacity(integer 1000) SRCname(string) PRECHECK MEMory]

        // precheck: `using' is a text file listing one dataset per line.
        // Before any output is written, check every exclude() token against
        // every file (variable names only, via -describe using-):
        //   - a range (a-c) whose endpoints are not both in a file errors
        //     r(111), naming the file: the range cannot be resolved there,
        //     and guessing which variables it covers would fail open;
        //   - a token that matches no variable in ANY file gets a note
        //     (r(unmatched)); a name absent from only some files is normal.
        if "`precheck'" != "" {
            local _unmatched ""
            local _ntok : word count `exclude'
            forvalues t = 1/`_ntok' {
                local _hit`t' = 0
            }
            tempname _pfh
            file open `_pfh' using `"`using'"', read text
            local _pfh_open = 1
            file read `_pfh' _pf
            while r(eof) == 0 {
                if trim(`"`macval(_pf)'"') != "" {
                    quietly describe using `"`_pf'"', varlist
                    local _pvars `"`r(varlist)'"'
                    local _plab `"`_pf'"'
                    if "`memory'" != "" local _plab "memory"
                    local t = 0
                    foreach _etok of local exclude {
                        local ++t
                        if strpos(`"`_etok'"', "-") {
                            gettoken _lo _hi : _etok, parse("-")
                            local _hi = substr(`"`_hi'"', 2, .)
                            local _miss ""
                            if !`: list _lo in _pvars' local _miss "`_lo'"
                            if !`: list _hi in _pvars' local _miss "`_miss' `_hi'"
                            // both present but in reverse order: -unab- would
                            // refuse the range later, after output is open
                            local _plo : list posof "`_lo'" in _pvars
                            local _phi : list posof "`_hi'" in _pvars
                            if `"`_miss'"' == "" & `_plo' > `_phi' {
                                file close `_pfh'
                                local _pfh_open = 0
                                noisily display as error ///
                                    `"exclude(): range `_etok' cannot be resolved in `_plab' (`_hi' comes before `_lo')"'
                                noisily display as error ///
                                    "list the variables to withhold by name or wildcard instead"
                                exit 111
                            }
                            if `"`_miss'"' != "" {
                                file close `_pfh'
                                local _pfh_open = 0
                                noisily display as error ///
                                    `"exclude(): range `_etok' cannot be resolved in `_plab' (`=strtrim("`_miss'")' not found)"'
                                noisily display as error ///
                                    "list the variables to withhold by name or wildcard instead"
                                exit 111
                            }
                            local _hit`t' = 1
                        }
                        else {
                            mata: st_local("_m", strofreal(sum(strmatch(tokens(st_local("_pvars")), ///
                                subinstr(st_local("_etok"), "~", "*")))))
                            if `_m' > 0 local _hit`t' = 1
                        }
                    }
                }
                file read `_pfh' _pf
            }
            file close `_pfh'
            local _pfh_open = 0
            local t = 0
            foreach _etok of local exclude {
                local ++t
                if !`_hit`t'' local _unmatched `"`_unmatched' `_etok'"'
            }
            local _unmatched = strtrim(`"`_unmatched'"')
            if `"`_unmatched'"' != "" {
                noisily display as text ///
                    `"note: exclude() matches no variable in any dataset: `_unmatched'"'
            }
            return local unmatched `"`_unmatched'"'
            // a clean exit leaves the capture block without reaching the
            // restore below
            set varabbrev `_orig_varabbrev'
            exit
        }
        if `"`saving'"' == "" {
            noisily display as error "option saving() required"
            exit 198
        }

        if `maxcat' <= 0 {
            noisily display as error "maxcat must be positive"
            exit 198
        }
        // A censored unique count is only safe if the cap sits above every
        // threshold the count is later compared against.  Below maxcat, a
        // capped variable could be misclassified as continuous when it is not.
        if `capacity' < 0 {
            noisily display as error "cap must be non-negative"
            exit 198
        }
        if `capacity' > 0 & `capacity' < `maxcat' {
            noisily display as error ///
                "cap (`capacity') must be >= maxcat (`maxcat')"
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
        // A zero-observation dataset with variables is still documentable
        // (structure only); only a dataset with no variables is refused.
        else if c(k) == 0 {
            noisily display as error "loaded classification requires data in memory"
            exit 198
        }
        if `obs' < 0 local obs = c(N)

        quietly describe, varlist
        local all_vars `r(varlist)'
        local nvars : word count `all_vars'

        // exclude() is a varlist: expand wildcards and ranges (exclude(ssn*),
        // exclude(name1-name3)) against this dataset.  A literal-only match
        // silently excluded nothing for a pattern, disclosing every variable
        // the user meant to withhold.  A token that matches nothing here is
        // kept verbatim, so names absent from one file of a multi-file run
        // are still ignored rather than an error.
        // A range (a-c) must resolve: if it does not, error rather than keep
        // it as literal text, which excluded nothing (fail open).
        if `"`srcname'"' == "" local srcname `"`using'"'
        local _exclude_x ""
        foreach _etok of local exclude {
            capture unab _eexp : `_etok'
            if _rc {
                if strpos(`"`_etok'"', "-") {
                    noisily display as error ///
                        `"exclude(): range `_etok' cannot be resolved in `srcname'"'
                    exit 111
                }
                local _eexp `"`_etok'"'
            }
            local _exclude_x : list _exclude_x | _eexp
        }
        local exclude `"`_exclude_x'"'

        local force_continuous "`continuous'"
        if `"`continuous'"' != "" {
            capture unab force_continuous : `continuous'
            if _rc local force_continuous "`continuous'"
        }
        local force_categorical "`categorical'"
        if `"`categorical'"' != "" {
            capture unab force_categorical : `categorical'
            if _rc local force_categorical "`categorical'"
        }
        local force_date "`date'"
        if `"`date'"' != "" {
            capture unab force_date : `date'
            if _rc local force_date "`date'"
        }
        local _overlap : list force_continuous & force_categorical
        if `"`_overlap'"' != "" {
            noisily display as error "classification override conflict: `_overlap' in both continuous() and categorical()"
            exit 198
        }
        local _overlap : list force_continuous & force_date
        if `"`_overlap'"' != "" {
            noisily display as error "classification override conflict: `_overlap' in both continuous() and date()"
            exit 198
        }
        local _overlap : list force_categorical & force_date
        if `"`_overlap'"' != "" {
            noisily display as error "classification override conflict: `_overlap' in both categorical() and date()"
            exit 198
        }

        tempname posth
        quietly postfile `posth' str32 varname str12 vartype str48 varformat ///
            str2045 varlabel str80 valuelabel double missing_n ///
            double missing_pct str16 classification double unique_vals ///
            byte is_binary str80 quality_flag int orig_position ///
            double max_length byte unique_capped using `"`saving'"', replace
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
            local ncapped = 0

            // Privacy: never compute values/stats for excluded variables.
            // Leaving unique_vals/is_binary/max_length unset is what stops the
            // Binary section, QUICK REFERENCE, and JSON from leaking an excluded
            // variable's cardinality, max length, or frequency distribution.
            if !`isexcluded' {
                if strpos("`vtype'", "str") == 1 {
                    // Non-empty values only: "" is Stata's string missing, and
                    // counting it made datamap report one more unique value
                    // than datadict for the same variable (shared saving()
                    // schema).  Missing is never a value, as for numerics.
                    capture _datamap_nuniq `vname', cap(`capacity')
                    if _rc == 0 {
                        local nuniq = r(n)
                        local ncapped = r(capped)
                    }

                    tempvar _slen
                    quietly gen double `_slen' = length(`vname')
                    quietly summarize `_slen'
                    if r(N) > 0 local maxlen = r(max)
                    quietly drop `_slen'
                }
                else {
                    capture _datamap_nuniq `vname', cap(`capacity')
                    if _rc == 0 {
                        local nuniq = r(n)
                        local ncapped = r(capped)
                        // cap >= maxcat >= 2 is enforced above, so a censored
                        // count can never be mistaken for a binary variable.
                        if `detect_binary' & `nuniq' == 2 & !`ncapped' ///
                            local is_binary = 1
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
            // A left-justified display format (%-td, %-tc, ...) is still a
            // date format; strip the justification flag before testing.
            else if strpos(subinstr("`vfmt'", "%-", "%", 1), "%t") > 0 | ///
                strpos(subinstr("`vfmt'", "%-", "%", 1), "%d") > 0 {
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

            local _v "`vname'"
            if !`isexcluded' {
                if `: list _v in force_continuous' {
                    local class "continuous"
                }
                else if `: list _v in force_categorical' {
                    local class "categorical"
                }
                else if `: list _v in force_date' {
                    local class "date"
                }
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

            mata: _datamap_strexpr("vlab", "_dmx_vlab")
            post `posth' (`"`vname'"') (`"`vtype'"') (`"`vfmt'"') ///
                (`_dmx_vlab') (`"`valab_post'"') (`nmiss') (`pctmiss') ///
                (`"`class'"') (`nuniq') (`is_binary') (`"`qflag'"') (`i') ///
                (`maxlen') (`ncapped')
        }

        postclose `posth'
        local _post_open = 0

        return scalar cap = `capacity'
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
    if `_pfh_open' capture file close `_pfh'
	    if `_post_open' {
	        capture postclose `posth'
	        local _postclose_rc = _rc
	        if !`rc' & `_postclose_rc' local rc = `_postclose_rc'
	    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
