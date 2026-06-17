*! datacheck Version 1.2.0  2026/06/17
*! Console QC and expectation-gate command for the datamap package
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define datacheck, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved   = 0
    local _pframe_made = 0
    local _pframe      = ""
    capture noisily {

        syntax [anything(name=varlistspec)] [if] [in] , [ ///
            SINGle(string) ///
            MAXCat(integer 25) EXClude(string) ///
            CONTinuous(string) CATegorical(string) date(string) ///
            ID(string) ///
            Detail MAXFreq(integer 20) RARE(integer 0) OUTliers(real 0) ///
            NOMISSing PATTERNS ///
            EXPECTN(numlist integer max=2) ISID(string) NODUPS ///
            REQuire(string) NOTMISSing(string) INRANGE(string) WARN ///
            SAVing(string) ]

        if `maxcat' <= 0 {
            display as error "maxcat() must be positive"
            exit 198
        }
        if `maxfreq' <= 0 {
            display as error "maxfreq() must be positive"
            exit 198
        }
        if `outliers' < 0 {
            display as error "outliers() must be non-negative"
            exit 198
        }

        // ---- preserve the user's data; everything below runs on a copy ----
        preserve
        local _preserved = 1

        // ---- single(): load a saved file in place of memory ----
        if `"`single'"' != "" {
            _datacheck_pathok `"`single'"'
            capture confirm file `"`single'"'
            if _rc {
                capture confirm file `"`single'.dta"'
                if _rc {
                    display as error `"file `single' not found"'
                    exit 601
                }
                local single `"`single'.dta"'
            }
            quietly use `"`single'"', clear
        }

        if c(N) == 0 {
            display as error "no observations"
            exit 2000
        }
        if c(k) == 0 {
            display as error "no variables"
            exit 102
        }

        // ---- resolve the profile varlist against the (now correct) data ----
        if `"`varlistspec'"' != "" {
            unab profilevars : `varlistspec'
        }
        else {
            quietly ds
            local profilevars `r(varlist)'
        }

        // ---- row subset from if/in ----
        tempvar touse
        marksample touse, novarlist
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations satisfy if/in"
            exit 2000
        }

        // ---- require() gate is checked against existence, before any drop ----
        local req_missing ""
        foreach v of local require {
            capture confirm variable `v', exact
            if _rc local req_missing "`req_missing' `v'"
        }

        quietly keep if `touse'
        // touse is now constant (all rows kept); drop it so it never reaches
        // the classifier as a phantom variable in r() lists or saving().
        quietly drop `touse'

        // ---- validate option varlists against the loaded data ----
        if "`exclude'"     != "" unab exclude     : `exclude'
        if "`continuous'"  != "" unab continuous  : `continuous'
        if "`categorical'" != "" unab categorical : `categorical'
        if "`date'"        != "" unab date        : `date'
        if "`isid'"        != "" unab isid        : `isid'
        if "`notmissing'"  != "" unab notmissing  : `notmissing'

        // ---- parse inrange(): backslash-separated "var lo hi" specs ----
        local n_inr = 0
        local inrvars ""
        if `"`inrange'"' != "" {
            local rest `"`inrange'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                local nw : word count `part'
                if `nw' != 3 {
                    display as error `"inrange() spec must be "var lo hi": `part'"'
                    exit 198
                }
                local iv : word 1 of `part'
                local lo : word 2 of `part'
                local hi : word 3 of `part'
                unab iv : `iv'
                confirm number `lo'
                confirm number `hi'
                local ++n_inr
                local inr_var`n_inr' "`iv'"
                local inr_lo`n_inr'  "`lo'"
                local inr_hi`n_inr'  "`hi'"
                local inrvars "`inrvars' `iv'"
            }
        }

        // ---- parse id(): backslash-separated keys (each key = space-sep vars) ----
        local n_key = 0
        local keyvars_all ""
        local id_inferred = 0
        if `"`id'"' != "" {
            local rest `"`id'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                unab part : `part'
                local ++n_key
                local key`n_key' "`part'"
                local keyvars_all "`keyvars_all' `part'"
            }
        }

        // ---- restrict columns to the union we actually need ----
        local unionvars : list profilevars | exclude
        local unionvars : list unionvars | continuous
        local unionvars : list unionvars | categorical
        local unionvars : list unionvars | date
        local unionvars : list unionvars | isid
        local unionvars : list unionvars | notmissing
        local unionvars : list unionvars | inrvars
        local unionvars : list unionvars | keyvars_all
        if `"`varlistspec'"' != "" {
            quietly keep `unionvars'
        }

        // ---- classify via the shared engine ----
        tempfile proff
        // `using' is required by the classifier syntax but ignored under `loaded'.
        quietly _datamap_classify using "memory", loaded saving(`"`proff'"') ///
            maxcat(`maxcat') exclude("`exclude'") detect_binary(1)
        local all_vars       "`r(all_vars)'"
        local cls_continuous "`r(continuous_vars)'"
        local cls_categorical "`r(categorical_vars)'"
        local cls_date       "`r(date_vars)'"
        local cls_string     "`r(string_vars)'"
        local cls_excluded   "`r(excluded_vars)'"
        local sugg_exclude   "`r(suggested_exclude)'"

        // ---- read per-variable metadata into parallel locals ----
        tempname pframe
        frame create `pframe'
        local _pframe_made = 1
        frame `pframe' {
            quietly use `"`proff'"', clear
            quietly count
            local P = r(N)
            forvalues i = 1/`P' {
                local vn = varname[`i']
                local idx_`vn' = `i'
                local m_class`i' = classification[`i']
                local m_type`i'  = vartype[`i']
                local m_mn`i'    = missing_n[`i']
                local m_mp`i'    = missing_pct[`i']
                local m_uv`i'    = unique_vals[`i']
                local m_ml`i'    = max_length[`i']
                local m_qf`i'    = quality_flag[`i']
            }
        }

        // ---- final class assignment (auto classifier + manual overrides) ----
        local f_continuous ""
        local f_categorical ""
        local f_date ""
        local f_string ""
        local f_excluded ""
        foreach v of local profilevars {
            local vv "`v'"
            local i = `idx_`v''
            local fc "`m_class`i''"
            if `: list vv in continuous'       local fc "continuous"
            else if `: list vv in categorical' local fc "categorical"
            else if `: list vv in date'        local fc "date"
            local f_`fc' "`f_`fc'' `v'"
            local FC_`v' "`fc'"
        }

        // ---- N and complete-case accounting on the analytical varlist ----
        // Excluded variables are withheld from the profile, so they do not
        // drive the completeness denominator.
        local nobs = c(N)
        tempvar cc
        quietly gen byte `cc' = 1
        foreach v of local profilevars {
            if "`FC_`v''" == "excluded" continue
            quietly replace `cc' = 0 if missing(`v')
        }
        quietly count if `cc'
        local n_complete = r(N)
        local pct_complete = 0
        if `nobs' > 0 local pct_complete = round(100 * `n_complete' / `nobs', 0.1)

        // ===================== DISPLAY =====================
        local nv : word count `profilevars'
        display ""
        display as text "datacheck: " as result "`nobs'" as text " obs, " ///
            as result "`nv'" as text " variables profiled" ///
            as text "  (complete cases: " as result "`n_complete'" ///
            as text " = " as result %4.1f `pct_complete' as text "%)"

        // ---- QUICK REFERENCE ----
        display ""
        display as text "QUICK REFERENCE"
        display as text "  " %-22s "Variable" %-12s "Class" %-9s "Type" ///
            %7s "Miss%" %9s "Unique" "  " %-14s "Flag"
        foreach v of local profilevars {
            local i = `idx_`v''
            local fc "`FC_`v''"
            local vt "`m_type`i''"
            local mp = `m_mp`i''
            if missing(`mp') local mp = 0
            local uq "."
            if `m_uv`i'' < . local uq = string(`m_uv`i'', "%9.0f")
            local uq = strtrim("`uq'")
            local flg ""
            _datacheck_flag `v' "`fc'" `maxcat' `rare' `outliers'
            local flg "`r(flag)'"
            local vshow = substr("`v'", 1, 21)
            display as text "  " as result %-22s "`vshow'" %-12s "`fc'" ///
                %-9s "`vt'" %6.1f `mp' as text "%" ///
                as result %9s "`uq'" "  " %-14s "`flg'"
        }

        // ---- CONTINUOUS ----
        if "`f_continuous'" != "" {
            display ""
            display as text "CONTINUOUS"
            foreach v of local f_continuous {
                quietly summarize `v', detail
                local n = r(N)
                if `n' == 0 {
                    display as text "  " as result "`v'" as text ": all missing"
                    continue
                }
                display as text "  " as result "`v'" as text ":  N=" ///
                    as result r(N) as text "  mean=" as result %10.4g r(mean) ///
                    as text "  sd=" as result %10.4g r(sd)
                display as text "    min=" as result %10.4g r(min) ///
                    as text "  p25=" as result %10.4g r(p25) ///
                    as text "  p50=" as result %10.4g r(p50) ///
                    as text "  p75=" as result %10.4g r(p75) ///
                    as text "  max=" as result %10.4g r(max)
                if "`detail'" != "" {
                    display as text "    p1=" as result %10.4g r(p1) ///
                        as text "  p5=" as result %10.4g r(p5) ///
                        as text "  p10=" as result %10.4g r(p10) ///
                        as text "  p90=" as result %10.4g r(p90) ///
                        as text "  p95=" as result %10.4g r(p95) ///
                        as text "  p99=" as result %10.4g r(p99)
                }
                if r(Var) == 0 {
                    display as text "    " as error "zero variance (constant)"
                }
                if `outliers' > 0 {
                    local iqr = r(p75) - r(p25)
                    local lof = r(p25) - `outliers' * `iqr'
                    local hif = r(p75) + `outliers' * `iqr'
                    quietly count if (`v' < `lof' | `v' > `hif') & !missing(`v')
                    local nout = r(N)
                    if `nout' > 0 {
                        local pout = round(100 * `nout' / `n', 0.1)
                        display as text "    " as error "`nout' outlier(s)" ///
                            as text " (" as result %3.1f `pout' as text "%) beyond " ///
                            as result `outliers' as text " IQR"
                    }
                }
            }
        }

        // ---- CATEGORICAL ----
        if "`f_categorical'" != "" {
            display ""
            display as text "CATEGORICAL"
            foreach v of local f_categorical {
                local i = `idx_`v''
                local nlev = `m_uv`i''
                display as text "  " as result "`v'" as text ":  " ///
                    as result `nlev' as text " levels"
                if `nlev' == 1 {
                    display as text "    " as error "single level (constant)"
                }
                if `nlev' > `maxcat' {
                    display as text "    " as error "level count exceeds maxcat(" ///
                        "`maxcat')" as text " — possible free-text/misclassification"
                }
                _datacheck_freq `v' `maxfreq' `rare'
            }
        }

        // ---- DATE ----
        if "`f_date'" != "" {
            display ""
            display as text "DATE"
            foreach v of local f_date {
                local i = `idx_`v''
                local vfmt : format `v'
                quietly summarize `v'
                local n = r(N)
                if `n' == 0 {
                    display as text "  " as result "`v'" as text ": all missing"
                    continue
                }
                local dmin : display `vfmt' r(min)
                local dmax : display `vfmt' r(max)
                local span = r(max) - r(min)
                display as text "  " as result "`v'" as text ":  min=" ///
                    as result "`dmin'" as text "  max=" as result "`dmax'" ///
                    as text "  span=" as result `span' as text " days  missing=" ///
                    as result `m_mn`i''
                forvalues k = 1/`n_inr' {
                    if "`inr_var`k''" == "`v'" {
                        quietly count if (`v' < `inr_lo`k'' | `v' > `inr_hi`k'') & !missing(`v')
                        display as text "    " as result r(N) ///
                            as text " obs outside declared window"
                    }
                }
            }
        }

        // ---- STRING ----
        if "`f_string'" != "" {
            display ""
            display as text "STRING"
            foreach v of local f_string {
                local i = `idx_`v''
                quietly count if `v' == ""
                local nblank = r(N)
                local ml "."
                if `m_ml`i'' < . local ml = string(`m_ml`i'', "%9.0f")
                local ml = strtrim("`ml'")
                local uq "."
                if `m_uv`i'' < . local uq = string(`m_uv`i'', "%9.0f")
                local uq = strtrim("`uq'")
                display as text "  " as result "`v'" as text ":  unique=" ///
                    as result "`uq'" as text "  blank=" as result `nblank' ///
                    as text "  maxlen=" as result "`ml'"
                _datacheck_freq `v' `maxfreq' `rare'
            }
        }

        // ---- EXCLUDED ----
        if "`f_excluded'" != "" {
            display ""
            display as text "EXCLUDED (listed, contents withheld)"
            display as text "  " as result "`f_excluded'"
        }

        // ---- MISSINGNESS ----
        if "`nomissing'" == "" {
            display ""
            display as text "MISSINGNESS"
            local any_miss = 0
            foreach v of local profilevars {
                local i = `idx_`v''
                if "`FC_`v''" == "excluded" continue
                if `m_mn`i'' > 0 & `m_mn`i'' < . {
                    local any_miss = 1
                    display as text "  " as result %-22s "`v'" as text "  " ///
                        as result `m_mn`i'' as text " missing  (" ///
                        as result %4.1f `m_mp`i'' as text "%)"
                }
            }
            if !`any_miss' {
                display as text "  no missing values in profiled variables"
            }
        }

        // ---- MISSING-VALUE PATTERNS (independent of nomissing) ----
        if "`patterns'" != "" {
            capture which datamvp
            if _rc {
                display ""
                display as text "  " as error ///
                    "patterns: datamvp unavailable — skipping pattern table"
            }
            else {
                display ""
                display as text "MISSING-VALUE PATTERNS (datamvp)"
                capture noisily datamvp `profilevars'
                if _rc {
                    display as text "  " as error ///
                        "patterns: datamvp could not render a table for these variables"
                }
            }
        }

        // ---- KEY STRUCTURE / UNIQUENESS ----
        if `n_key' == 0 & `"`sugg_exclude'"' != "" {
            // default to inferred identifier-like keys, one per variable
            local id_inferred = 1
            foreach v of local sugg_exclude {
                local ++n_key
                local key`n_key' "`v'"
            }
        }
        if `n_key' > 0 {
            display ""
            display as text "KEY STRUCTURE"
            if `id_inferred' {
                display as text "  (id() not given; inferred from identifier-like names)"
            }
            forvalues k = 1/`n_key' {
                local kv "`key`k''"
                tempvar kn ktag
                quietly bysort `kv' : gen long `kn' = _N
                quietly by `kv' : gen byte `ktag' = (_n == 1)
                quietly count if `ktag'
                local ndist = r(N)
                quietly summarize `kn' if `ktag', detail
                local kmin = r(min)
                local kmed = r(p50)
                local kmax = r(max)
                quietly count if `ktag' & `kn' > 1
                local nmulti = r(N)
                local kvkey = subinstr("`kv'", " ", "_", .)
                return scalar n_dup_`kvkey' = `nmulti'
                display as text "  key (" as result "`kv'" as text "):  " ///
                    as result `nobs' as text " obs, " as result `ndist' ///
                    as text " distinct, records/key min/median/max = " ///
                    as result `kmin' "/" `kmed' "/" `kmax' as text ", " ///
                    as result `nmulti' as text " key(s) with >1 record"
                quietly drop `kn' `ktag'
            }
        }

        // ===================== GATES =====================
        local gate_on = 0
        if `"`expectn'"' != "" | "`isid'" != "" | "`nodups'" != "" | ///
           "`require'" != "" | "`notmissing'" != "" | `"`inrange'"' != "" {
            local gate_on = 1
        }

        local n_viol = 0
        local viol_names ""

        if `gate_on' {
            // expectn
            if `"`expectn'"' != "" {
                local enw : word count `expectn'
                local elo : word 1 of `expectn'
                if `enw' == 1 {
                    if `nobs' != `elo' {
                        local ++n_viol
                        local viol_names "`viol_names' expectn"
                        local vmsg`n_viol' "expectn: expected N = `elo', observed `nobs'"
                    }
                }
                else {
                    local ehi : word 2 of `expectn'
                    if `nobs' < `elo' | `nobs' > `ehi' {
                        local ++n_viol
                        local viol_names "`viol_names' expectn"
                        local vmsg`n_viol' "expectn: expected N in [`elo', `ehi'], observed `nobs'"
                    }
                }
            }
            // isid
            if "`isid'" != "" {
                tempvar in_tag
                quietly bysort `isid' : gen byte `in_tag' = (_n == 1)
                quietly count if `in_tag'
                local idist = r(N)
                quietly drop `in_tag'
                if `idist' != `nobs' {
                    local ++n_viol
                    local viol_names "`viol_names' isid"
                    local vmsg`n_viol' "isid(`isid'): not unique — `nobs' rows, `idist' distinct"
                }
            }
            // nodups
            if "`nodups'" != "" {
                quietly duplicates report
                local ndup = r(N) - r(unique_value)
                if `ndup' > 0 {
                    local ++n_viol
                    local viol_names "`viol_names' nodups"
                    local vmsg`n_viol' "nodups: `ndup' duplicated row(s)"
                }
            }
            // require
            if "`require'" != "" {
                local req_missing = trim("`req_missing'")
                if "`req_missing'" != "" {
                    local ++n_viol
                    local viol_names "`viol_names' require"
                    local vmsg`n_viol' "require: missing variable(s) `req_missing'"
                }
            }
            // notmissing
            if "`notmissing'" != "" {
                foreach v of local notmissing {
                    quietly count if missing(`v')
                    if r(N) > 0 {
                        local ++n_viol
                        local viol_names "`viol_names' notmissing"
                        local vmsg`n_viol' "notmissing: `v' has `r(N)' missing value(s)"
                    }
                }
            }
            // inrange
            forvalues k = 1/`n_inr' {
                local iv "`inr_var`k''"
                local lo "`inr_lo`k''"
                local hi "`inr_hi`k''"
                quietly count if (`iv' < `lo' | `iv' > `hi') & !missing(`iv')
                if r(N) > 0 {
                    local noutr = r(N)
                    quietly summarize `iv'
                    local ++n_viol
                    local viol_names "`viol_names' inrange"
                    local vmsg`n_viol' "inrange(`iv'): `noutr' obs outside [`lo', `hi']  (min `=r(min)', max `=r(max)')"
                }
            }
        }

        local viol_names = trim("`viol_names'")

        // ---- return surface (posted after all work succeeds) ----
        return scalar N              = `nobs'
        return scalar complete_cases = `n_complete'
        return scalar complete_pct   = `pct_complete'
        return scalar n_violations   = `n_viol'
        return local  violations     "`viol_names'"
        return local  continuous_vars "`f_continuous'"
        return local  categorical_vars "`f_categorical'"
        return local  date_vars      "`f_date'"
        return local  string_vars    "`f_string'"
        return local  excluded_vars  "`f_excluded'"

        // ---- optional saving() of the per-variable profile ----
        // Non-fatal: a bad saving() path must not strand the console report or
        // the gate verdict; warn and continue instead of aborting.
        if `"`saving'"' != "" {
            gettoken sfile srest : saving, parse(" ,")
            local sreplace = 0
            if regexm(`"`srest'"', "replace") local sreplace = 1
            local _bad = 0
            foreach _c in ";" "&" "|" ">" "<" "$" {
                if strpos(`"`sfile'"', "`_c'") local _bad = 1
            }
            if strpos(`"`sfile'"', char(96)) | strpos(`"`sfile'"', char(34)) local _bad = 1
            if `_bad' {
                display as text "  " as error "saving: illegal characters in path — skipped"
            }
            else {
                // datacheck's addition to the classifier profile: post-override class
                frame `pframe': quietly gen str16 dc_class = classification
                foreach v of local profilevars {
                    frame `pframe': quietly replace dc_class = "`FC_`v''" if varname == "`v'"
                }
                local _isfile = 0
                if substr(`"`sfile'"', -4, 4) == ".dta" local _isfile = 1
                else if strpos(`"`sfile'"', "/") | strpos(`"`sfile'"', "\") local _isfile = 1
                capture noisily {
                    if `_isfile' {
                        if `sreplace' frame `pframe': quietly save `"`sfile'"', replace
                        else          frame `pframe': quietly save `"`sfile'"'
                    }
                    else {
                        capture frame drop `sfile'
                        frame copy `pframe' `sfile'
                    }
                }
                if _rc {
                    display as text "  " as error "saving: could not write `sfile' — skipped"
                }
            }
        }

        // ---- gate verdict ----
        if `n_viol' > 0 {
            display ""
            if "`warn'" != "" {
                display as text "WARNINGS (`n_viol')"
                forvalues j = 1/`n_viol' {
                    display as text "  " as result "`vmsg`j''"
                }
            }
            else {
                display as error "EXPECTATION VIOLATIONS (`n_viol')"
                forvalues j = 1/`n_viol' {
                    display as error "  `vmsg`j''"
                }
                exit 9
            }
        }
    }
    local rc = _rc
    if `_pframe_made' capture frame drop `pframe'
    if `_preserved'   capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// ---------------------------------------------------------------------------
// Helpers (bundled; loaded with datacheck.ado)
// ---------------------------------------------------------------------------

capture program drop _datacheck_pathok
program define _datacheck_pathok, nclass
    // Reject shell metacharacters / quotes in user-supplied file paths.
    // char(96) = backtick, char(34) = double quote — built via char() so the
    // source string itself never contains a backtick (which would macro-expand).
    gettoken p 0 : 0
    local bad = 0
    foreach c in ";" "&" "|" ">" "<" "$" {
        if strpos(`"`p'"', "`c'") local bad = 1
    }
    if strpos(`"`p'"', char(96)) | strpos(`"`p'"', char(34)) local bad = 1
    if `bad' {
        display as error "illegal characters in path"
        exit 198
    }
end

capture program drop _datacheck_flag
program define _datacheck_flag, rclass
    // Compact one-word flag for the QUICK REFERENCE table.
    args v fc maxcat rare outliers
    local flag ""
    if "`fc'" == "continuous" {
        quietly summarize `v', detail
        if r(N) > 0 & r(Var) == 0 local flag "constant"
        else if `outliers' > 0 {
            local iqr = r(p75) - r(p25)
            quietly count if (`v' < r(p25) - `outliers'*`iqr' | ///
                `v' > r(p75) + `outliers'*`iqr') & !missing(`v')
            if r(N) > 0 local flag "outliers"
        }
    }
    else if "`fc'" == "categorical" {
        quietly levelsof `v', missing
        local nlev = r(r)
        if `nlev' == 1 local flag "constant"
        else if `nlev' > `maxcat' local flag "hi-card"
        else if `rare' > 0 {
            tempname fr
            frame put `v', into(`fr')
            frame `fr' {
                quietly contract `v', freq(__f)
                quietly count if __f < `rare'
                if r(N) > 0 local flag "rare"
            }
            frame drop `fr'
        }
    }
    return local flag "`flag'"
end

capture program drop _datacheck_freq
program define _datacheck_freq, nclass
    // Frequency table sorted by descending count, capped at maxfreq.
    args v maxfreq rare
    tempname fr
    frame put `v', into(`fr')
    frame `fr' {
        quietly contract `v', freq(__f)
        quietly count
        local nlev = r(N)
        quietly summarize __f
        local tot = r(sum)
        gsort -__f
        local lblname : value label `v'
        local show = min(`nlev', `maxfreq')
        forvalues r = 1/`show' {
            local lv = `v'[`r']
            local ct = __f[`r']
            local pc = 100 * `ct' / `tot'
            local disp "`lv'"
            if "`lblname'" != "" {
                local lab : label `lblname' `lv'
                if "`lab'" != "" & "`lab'" != "`lv'" local disp "`lv' `lab'"
            }
            local rflag ""
            if `rare' > 0 & `ct' < `rare' local rflag "  <rare"
            display as text "    " as result %-28s `"`disp'"' ///
                as result %9.0f `ct' as text "  (" as result %4.1f `pc' ///
                as text "%)" as error "`rflag'"
        }
        if `nlev' > `maxfreq' {
            display as text "    ... " as result `=`nlev'-`maxfreq'' ///
                as text " more level(s) not shown (maxfreq)"
        }
    }
    frame drop `fr'
end
