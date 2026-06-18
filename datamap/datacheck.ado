*! datacheck Version 1.4.0  2026/06/18
*! Console QC and expectation-gate command for the datamap package
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define datacheck, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved   = 0
    local _pframe_made = 0
    local _cframe_made = 0
    local _vframe_made = 0
    local _sframe_made = 0
    local _pframe      = ""
    local _cframe      = ""
    local _vframe      = ""
    local _sframe      = ""
    capture noisily {

        syntax [anything(name=varlistspec)] [if] [in] , [ ///
            SINGle(string) ///
            MAXCat(integer 25) EXClude(string) ///
            CONTinuous(string) CATegorical(string) date(string) ///
            ID(string) ///
            Detail MAXFreq(integer 20) RARE(integer 0) OUTliers(real 0) ///
            GATESonly ONLYflagged SHOW(string) MINcell(integer 0) MASKrare ///
            NOMISSing PATTERNS ///
            EXPECTN(numlist integer max=2) ISID(string) NODUPS ///
            REQuire(string) NOTMISSing(string) INRANGE(string) WARN ///
            ALLowed(string) FORbid(string) REGEX(string) NOTValues(string) ///
            BY(varlist) OVER(varname) ///
            CHECKs(string) MAKESpec(string) VIOLations(string) ///
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
        if `mincell' < 0 {
            display as error "mincell() must be non-negative"
            exit 198
        }
        local _maskcell = `mincell'
        if "`maskrare'" != "" & `_maskcell' == 0 local _maskcell = `rare'
        if "`maskrare'" != "" & `_maskcell' == 0 local _maskcell = 5
        local show = lower(trim(`"`show'"'))
        local showflagged = 0
        if "`onlyflagged'" != "" local showflagged = 1
        if `"`show'"' != "" {
            if `"`show'"' == "flagged" local showflagged = 1
            else {
                display as error `"show() must be "flagged""'
                exit 198
            }
        }
        if "`gatesonly'" != "" & `showflagged' {
            display as error "cannot specify both gatesonly and onlyflagged/show(flagged)"
            exit 198
        }
        if `"`by'"' != "" & `"`over'"' != "" {
            display as error "cannot specify both by() and over()"
            exit 198
        }
        local byvars `"`by'"'
        if `"`over'"' != "" local byvars `"`over'"'

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

        // ---- checks(): read reusable gate specs from a Stata dataset ----
        if `"`checks'"' != "" {
            gettoken cfile crest : checks, parse(" ,")
            if trim(`"`crest'"') != "" {
                display as error "checks() accepts one Stata dataset filename"
                exit 198
            }
            _datacheck_pathok `"`cfile'"'
            capture confirm file `"`cfile'"'
            if _rc {
                capture confirm file `"`cfile'.dta"'
                if _rc {
                    display as error `"checks() file `cfile' not found"'
                    exit 601
                }
                local cfile `"`cfile'.dta"'
            }
            tempname cframe
            local _cframe "`cframe'"
            frame create `cframe'
            local _cframe_made = 1
            frame `cframe' {
                quietly use `"`cfile'"', clear
                capture confirm variable gate
                if _rc {
                    capture confirm variable check
                    if _rc {
                        display as error "checks() spec must contain string variable check or gate"
                        exit 198
                    }
                    rename check gate
                }
                capture confirm string variable gate
                if _rc {
                    display as error "checks() variable check/gate must be string"
                    exit 198
                }
                capture confirm variable var
                if _rc {
                    capture confirm variable variable
                    if !_rc rename variable var
                }
                local has_var = 0
                local has_arg1 = 0
                local has_arg2 = 0
                local has_values = 0
                local has_pattern = 0
                capture confirm string variable var
                if !_rc local has_var = 1
                capture confirm string variable arg1
                if !_rc local has_arg1 = 1
                capture confirm string variable arg2
                if !_rc local has_arg2 = 1
                capture confirm string variable values
                if !_rc local has_values = 1
                capture confirm string variable pattern
                if !_rc local has_pattern = 1
                quietly count
                local C = r(N)
                forvalues ci = 1/`C' {
                    local cg = lower(strtrim(gate[`ci']))
                    local cv ""
                    local carg1 ""
                    local carg2 ""
                    local cvalues ""
                    local cpattern ""
                    if `has_var'     local cv = strtrim(var[`ci'])
                    if `has_arg1'    local carg1 = strtrim(arg1[`ci'])
                    if `has_arg2'    local carg2 = strtrim(arg2[`ci'])
                    if `has_values'  local cvalues = strtrim(values[`ci'])
                    if `has_pattern' local cpattern = strtrim(pattern[`ci'])
                    if "`cvalues'" == "" local cvalues "`carg1'"
                    if "`cpattern'" == "" local cpattern "`carg1'"
                    if "`cg'" == "" continue
                    if "`cg'" == "expectn" {
                        if "`carg1'" == "" {
                            display as error "checks(): expectn row requires arg1"
                            exit 198
                        }
                        local expectn "`carg1' `carg2'"
                        local expectn = trim("`expectn'")
                    }
                    else if "`cg'" == "isid" | "`cg'" == "id" {
                        if "`cv'" == "" local cv "`cvalues'"
                        if "`cv'" == "" {
                            display as error "checks(): isid row requires var or values"
                            exit 198
                        }
                        local isid "`cv'"
                    }
                    else if "`cg'" == "nodups" {
                        local nodups "nodups"
                    }
                    else if "`cg'" == "require" {
                        if "`cv'" == "" local cv "`cvalues'"
                        if "`cv'" == "" {
                            display as error "checks(): require row requires var or values"
                            exit 198
                        }
                        local require "`require' `cv'"
                    }
                    else if "`cg'" == "notmissing" {
                        if "`cv'" == "" local cv "`cvalues'"
                        if "`cv'" == "" {
                            display as error "checks(): notmissing row requires var or values"
                            exit 198
                        }
                        local notmissing "`notmissing' `cv'"
                    }
                    else if "`cg'" == "inrange" {
                        if "`cv'" == "" | "`carg1'" == "" | "`carg2'" == "" {
                            display as error "checks(): inrange row requires var, arg1, and arg2"
                            exit 198
                        }
                        if `"`inrange'"' == "" local inrange `"`cv' `carg1' `carg2'"'
                        else local inrange `"`inrange' \ `cv' `carg1' `carg2'"'
                    }
                    else if "`cg'" == "allowed" {
                        if "`cv'" == "" | "`cvalues'" == "" {
                            display as error "checks(): allowed row requires var and values"
                            exit 198
                        }
                        if `"`allowed'"' == "" local allowed `"`cv' `cvalues'"'
                        else local allowed `"`allowed' \ `cv' `cvalues'"'
                    }
                    else if "`cg'" == "forbid" | "`cg'" == "forbidden" {
                        if "`cv'" == "" | "`cvalues'" == "" {
                            display as error "checks(): forbid row requires var and values"
                            exit 198
                        }
                        if `"`forbid'"' == "" local forbid `"`cv' `cvalues'"'
                        else local forbid `"`forbid' \ `cv' `cvalues'"'
                    }
                    else if "`cg'" == "notvalues" | "`cg'" == "sentinel" {
                        if "`cv'" == "" | "`cvalues'" == "" {
                            display as error "checks(): notvalues row requires var and values"
                            exit 198
                        }
                        if `"`notvalues'"' == "" local notvalues `"`cv' `cvalues'"'
                        else local notvalues `"`notvalues' \ `cv' `cvalues'"'
                    }
                    else if "`cg'" == "regex" {
                        if "`cv'" == "" | "`cpattern'" == "" {
                            display as error "checks(): regex row requires var and pattern"
                            exit 198
                        }
                        if `"`regex'"' == "" local regex `"`cv' `cpattern'"'
                        else local regex `"`regex' \ `cv' `cpattern'"'
                    }
                    else {
                        display as error "checks(): unsupported gate `cg'"
                        exit 198
                    }
                }
            }
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
        if "`byvars'"      != "" unab byvars      : `byvars'

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
                _datacheck_bound `iv' `"`lo'"'
                local lo_num = r(value)
                _datacheck_bound `iv' `"`hi'"'
                local hi_num = r(value)
                if `lo_num' > `hi_num' {
                    display as error `"inrange() lower bound exceeds upper bound: `part'"'
                    exit 198
                }
                local ++n_inr
                local inr_var`n_inr' "`iv'"
                local inr_lo`n_inr'  "`lo_num'"
                local inr_hi`n_inr'  "`hi_num'"
                local inr_lolab`n_inr' `"`lo'"'
                local inr_hilab`n_inr' `"`hi'"'
                local inrvars "`inrvars' `iv'"
            }
        }

        // ---- parse value-domain gates: "var value [value ...]" specs ----
        local n_allowed = 0
        local n_forbid = 0
        local n_notvalues = 0
        local n_regex = 0
        local value_gatevars ""
        if `"`allowed'"' != "" {
            local rest `"`allowed'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken vv vals : part, quotes
                local vals = trim(`"`vals'"')
                if `"`vv'"' == "" | `"`vals'"' == "" {
                    display as error `"allowed() spec must be "var value [value ...]": `part'"'
                    exit 198
                }
                unab vv : `vv'
                local ++n_allowed
                local allowed_var`n_allowed' "`vv'"
                local allowed_vals`n_allowed' `"`vals'"'
                local value_gatevars "`value_gatevars' `vv'"
            }
        }
        if `"`forbid'"' != "" {
            local rest `"`forbid'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken vv vals : part, quotes
                local vals = trim(`"`vals'"')
                if `"`vv'"' == "" | `"`vals'"' == "" {
                    display as error `"forbid() spec must be "var value [value ...]": `part'"'
                    exit 198
                }
                unab vv : `vv'
                local ++n_forbid
                local forbid_var`n_forbid' "`vv'"
                local forbid_vals`n_forbid' `"`vals'"'
                local value_gatevars "`value_gatevars' `vv'"
            }
        }
        if `"`notvalues'"' != "" {
            local rest `"`notvalues'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken vv vals : part, quotes
                local vals = trim(`"`vals'"')
                if `"`vv'"' == "" | `"`vals'"' == "" {
                    display as error `"notvalues() spec must be "var value [value ...]": `part'"'
                    exit 198
                }
                unab vv : `vv'
                local ++n_notvalues
                local notvalues_var`n_notvalues' "`vv'"
                local notvalues_vals`n_notvalues' `"`vals'"'
                local value_gatevars "`value_gatevars' `vv'"
            }
        }
        if `"`regex'"' != "" {
            local rest `"`regex'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken rv rpat : part, quotes
                local rpat = trim(`"`rpat'"')
                if `"`rv'"' == "" | `"`rpat'"' == "" {
                    display as error `"regex() spec must be "var pattern": `part'"'
                    exit 198
                }
                unab rv : `rv'
                local ++n_regex
                local regex_var`n_regex' "`rv'"
                local regex_pat`n_regex' `"`rpat'"'
                local value_gatevars "`value_gatevars' `rv'"
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
        local unionvars : list unionvars | value_gatevars
        local unionvars : list unionvars | keyvars_all
        local unionvars : list unionvars | byvars
        if `"`varlistspec'"' != "" {
            quietly keep `unionvars'
        }

        tempvar dc_group
        local has_groups = 0
        local group_levels ""
        if "`byvars'" != "" {
            quietly egen long `dc_group' = group(`byvars'), label missing
            quietly levelsof `dc_group', local(group_levels)
            local has_groups = 1
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

        // ---- cache issue flags and continuous summaries once ----
        local flagged_vars ""
        local constant_vars ""
        local highcard_vars ""
        local missing_vars ""
        local outlier_vars ""
        local rare_vars ""
        foreach v of local profilevars {
            local fc "`FC_`v''"
            local flg ""
            local i = `idx_`v''
            if `m_mn`i'' > 0 & `m_mn`i'' < . {
                local missing_vars "`missing_vars' `v'"
            }
            if "`fc'" == "continuous" {
                quietly summarize `v', detail
                local c_N_`v' = r(N)
                local c_mean_`v' = r(mean)
                local c_sd_`v' = r(sd)
                local c_min_`v' = r(min)
                local c_p1_`v' = r(p1)
                local c_p5_`v' = r(p5)
                local c_p10_`v' = r(p10)
                local c_p25_`v' = r(p25)
                local c_p50_`v' = r(p50)
                local c_p75_`v' = r(p75)
                local c_p90_`v' = r(p90)
                local c_p95_`v' = r(p95)
                local c_p99_`v' = r(p99)
                local c_max_`v' = r(max)
                local c_var_`v' = r(Var)
                local c_nout_`v' = 0
                if r(N) > 0 & r(Var) == 0 {
                    local flg "constant"
                    local constant_vars "`constant_vars' `v'"
                }
                else if r(N) > 0 & `outliers' > 0 {
                    local iqr = r(p75) - r(p25)
                    local lof = r(p25) - `outliers' * `iqr'
                    local hif = r(p75) + `outliers' * `iqr'
                    quietly count if (`v' < `lof' | `v' > `hif') & !missing(`v')
                    local c_nout_`v' = r(N)
                    if r(N) > 0 {
                        local flg "outliers"
                        local outlier_vars "`outlier_vars' `v'"
                    }
                }
            }
            else if "`fc'" == "categorical" {
                _datacheck_flag `v' "`fc'" `maxcat' `rare' `outliers'
                local flg "`r(flag)'"
                if "`flg'" == "constant" local constant_vars "`constant_vars' `v'"
                else if "`flg'" == "hi-card" local highcard_vars "`highcard_vars' `v'"
                else if "`flg'" == "rare" local rare_vars "`rare_vars' `v'"
            }
            else if "`fc'" == "string" {
                if `m_uv`i'' > `maxcat' & `m_uv`i'' < . {
                    local flg "hi-card"
                    local highcard_vars "`highcard_vars' `v'"
                }
            }
            if "`flg'" == "" & `m_mn`i'' > 0 & `m_mn`i'' < . local flg "missing"
            if "`flg'" != "" local flagged_vars "`flagged_vars' `v'"
            local flag_`v' "`flg'"
        }
        local flagged_vars : list uniq flagged_vars
        local constant_vars : list uniq constant_vars
        local highcard_vars : list uniq highcard_vars
        local missing_vars : list uniq missing_vars
        local outlier_vars : list uniq outlier_vars
        local rare_vars : list uniq rare_vars
        local n_flagged : word count `flagged_vars'
        local n_constant : word count `constant_vars'
        local n_highcard : word count `highcard_vars'
        local n_missing_vars : word count `missing_vars'
        local n_outlier_vars : word count `outlier_vars'
        local n_rare_vars : word count `rare_vars'

        // ---- groupwise profile summaries ----
        local group_missing_vars ""
        if `has_groups' {
            foreach v of local profilevars {
                if "`FC_`v''" == "excluded" continue
                local has_group_miss = 0
                foreach gg of local group_levels {
                    quietly count if `dc_group' == `gg' & missing(`v')
                    if r(N) > 0 local has_group_miss = 1
                }
                if `has_group_miss' local group_missing_vars "`group_missing_vars' `v'"
            }
        }
        local group_missing_vars : list uniq group_missing_vars
        local n_group_missing_vars : word count `group_missing_vars'
        local group_vallab ""
        if `has_groups' {
            local group_vallab : value label `dc_group'
            foreach gg of local group_levels {
                local group_label`gg' "`gg'"
                if "`group_vallab'" != "" {
                    local _gtxt : label `group_vallab' `gg'
                    if `"`_gtxt'"' != "" local group_label`gg' `"`_gtxt'"'
                }
            }
        }

        // ===================== DISPLAY =====================
        local nv : word count `profilevars'
        if "`gatesonly'" == "" {
            display ""
            display as text "datacheck: " as result "`nobs'" as text " obs, " ///
                as result "`nv'" as text " variables profiled" ///
                as text "  (complete cases: " as result "`n_complete'" ///
                as text " = " as result %4.1f `pct_complete' as text "%)"
        }

        // ---- QUICK REFERENCE ----
        if "`gatesonly'" == "" {
            display ""
            if `showflagged' display as text "QUICK REFERENCE (FLAGGED)"
            else display as text "QUICK REFERENCE"
            display as text "  " %-22s "Variable" %-12s "Class" %-9s "Type" ///
                %7s "Miss%" %9s "Unique" "  " %-14s "Flag"
            local n_shown = 0
            foreach v of local profilevars {
                local flg "`flag_`v''"
                if `showflagged' & "`flg'" == "" continue
                local ++n_shown
                local i = `idx_`v''
                local fc "`FC_`v''"
                local vt "`m_type`i''"
                local mp = `m_mp`i''
                if missing(`mp') local mp = 0
                local uq "."
                if `m_uv`i'' < . local uq = string(`m_uv`i'', "%9.0f")
                local uq = strtrim("`uq'")
                local vshow = substr("`v'", 1, 21)
                display as text "  " as result %-22s "`vshow'" %-12s "`fc'" ///
                    %-9s "`vt'" %6.1f `mp' as text "%" ///
                    as result %9s "`uq'" "  " %-14s "`flg'"
            }
            if `showflagged' & `n_shown' == 0 {
                display as text "  no flagged variables"
            }
        }

        // ---- CONTINUOUS ----
        if "`gatesonly'" == "" & "`f_continuous'" != "" {
            display ""
            display as text "CONTINUOUS"
            foreach v of local f_continuous {
                if `showflagged' & "`flag_`v''" == "" continue
                local n = `c_N_`v''
                if `n' == 0 {
                    display as text "  " as result "`v'" as text ": all missing"
                    continue
                }
                display as text "  " as result "`v'" as text ":  N=" ///
                    as result `c_N_`v'' as text "  mean=" as result %10.4g `c_mean_`v'' ///
                    as text "  sd=" as result %10.4g `c_sd_`v''
                display as text "    min=" as result %10.4g `c_min_`v'' ///
                    as text "  p25=" as result %10.4g `c_p25_`v'' ///
                    as text "  p50=" as result %10.4g `c_p50_`v'' ///
                    as text "  p75=" as result %10.4g `c_p75_`v'' ///
                    as text "  max=" as result %10.4g `c_max_`v''
                if "`detail'" != "" {
                    display as text "    p1=" as result %10.4g `c_p1_`v'' ///
                        as text "  p5=" as result %10.4g `c_p5_`v'' ///
                        as text "  p10=" as result %10.4g `c_p10_`v'' ///
                        as text "  p90=" as result %10.4g `c_p90_`v'' ///
                        as text "  p95=" as result %10.4g `c_p95_`v'' ///
                        as text "  p99=" as result %10.4g `c_p99_`v''
                }
                if `c_var_`v'' == 0 {
                    display as text "    " as error "zero variance (constant)"
                }
                if `outliers' > 0 {
                    local nout = `c_nout_`v''
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
        if "`gatesonly'" == "" & "`f_categorical'" != "" {
            display ""
            display as text "CATEGORICAL"
            foreach v of local f_categorical {
                if `showflagged' & "`flag_`v''" == "" continue
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
                _datacheck_freq `v' `maxfreq' `rare' `_maskcell'
            }
        }

        // ---- DATE ----
        if "`gatesonly'" == "" & "`f_date'" != "" {
            display ""
            display as text "DATE"
            foreach v of local f_date {
                if `showflagged' & "`flag_`v''" == "" continue
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
        if "`gatesonly'" == "" & "`f_string'" != "" {
            display ""
            display as text "STRING"
            foreach v of local f_string {
                if `showflagged' & "`flag_`v''" == "" continue
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
                _datacheck_freq `v' `maxfreq' `rare' `_maskcell'
            }
        }

        // ---- EXCLUDED ----
        if "`gatesonly'" == "" & "`f_excluded'" != "" & !`showflagged' {
            display ""
            display as text "EXCLUDED (listed, contents withheld)"
            display as text "  " as result "`f_excluded'"
        }

        // ---- MISSINGNESS ----
        if "`gatesonly'" == "" & "`nomissing'" == "" & !`showflagged' {
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
        if "`gatesonly'" == "" & "`patterns'" != "" & !`showflagged' {
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

        // ---- GROUPWISE SUMMARY ----
        if "`gatesonly'" == "" & `has_groups' & (!`showflagged' | `n_group_missing_vars' > 0) {
            display ""
            display as text "GROUPWISE SUMMARY"
            display as text "  by: " as result "`byvars'"
            display as text "  " %-20s "Group" %9s "N" %12s "Complete" ///
                %10s "Complete%" %9s "MissVars"
            foreach gg of local group_levels {
                quietly count if `dc_group' == `gg'
                local gn = r(N)
                quietly count if `dc_group' == `gg' & `cc'
                local gc = r(N)
                local gpct = 0
                if `gn' > 0 local gpct = round(100 * `gc' / `gn', 0.1)
                local gmissvars ""
                foreach v of local profilevars {
                    if "`FC_`v''" == "excluded" continue
                    quietly count if `dc_group' == `gg' & missing(`v')
                    if r(N) > 0 local gmissvars "`gmissvars' `v'"
                }
                local gmissvars : list uniq gmissvars
                local gmissct : word count `gmissvars'
                if `showflagged' & `gmissct' == 0 continue
                local gshow = substr(`"`group_label`gg''"', 1, 20)
                display as text "  " as result %-20s `"`gshow'"' ///
                    as result %9.0f `gn' %12.0f `gc' %9.1f `gpct' ///
                    as text "%" as result %9.0f `gmissct'
            }
        }

        if "`gatesonly'" == "" & `has_groups' & `n_group_missing_vars' > 0 {
            display ""
            display as text "GROUPWISE MISSINGNESS"
            display as text "  " %-20s "Group" %-22s "Variable" ///
                %9s "Missing" %10s "Missing%"
            foreach gg of local group_levels {
                quietly count if `dc_group' == `gg'
                local gn = r(N)
                foreach v of local group_missing_vars {
                    quietly count if `dc_group' == `gg' & missing(`v')
                    local gm = r(N)
                    if `gm' == 0 continue
                    local gmpct = 0
                    if `gn' > 0 local gmpct = round(100 * `gm' / `gn', 0.1)
                    local gshow = substr(`"`group_label`gg''"', 1, 20)
                    display as text "  " as result %-20s `"`gshow'"' ///
                        as result %-22s "`v'" %9.0f `gm' %9.1f `gmpct' ///
                        as text "%"
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
        if "`gatesonly'" == "" & `n_key' > 0 & !`showflagged' {
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
           "`require'" != "" | "`notmissing'" != "" | `"`inrange'"' != "" | ///
           `n_allowed' > 0 | `n_forbid' > 0 | `n_regex' > 0 | `n_notvalues' > 0 {
            local gate_on = 1
        }

        local n_viol = 0
        local viol_names ""

        if `gate_on' {
            // require
            if "`require'" != "" {
                local req_missing = trim("`req_missing'")
                if "`req_missing'" != "" {
                    local ++n_viol
                    local viol_names "`viol_names' require"
                    local vgate`n_viol' "require"
                    local vvar`n_viol' "`req_missing'"
                    local vobs`n_viol' "missing"
                    local vexp`n_viol' "present"
                    local vgroup`n_viol' ""
                    local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                    local vmsg`n_viol' "require: missing variable(s) `req_missing'"
                }
            }

            local n_scope = 1
            local scope_if1 "1"
            local scope_lab1 ""
            if `has_groups' {
                local n_scope : word count `group_levels'
                local si = 0
                foreach gg of local group_levels {
                    local ++si
                    local scope_if`si' "`dc_group' == `gg'"
                    local scope_lab`si' "by(`byvars' group `gg')"
                }
            }

            forvalues si = 1/`n_scope' {
                local IF "`scope_if`si''"
                local GP "`scope_lab`si''"
                local PFX ""
                if "`GP'" != "" local PFX "`GP': "
                quietly count if `IF'
                local scope_n = r(N)

                // expectn
                if `"`expectn'"' != "" {
                    local enw : word count `expectn'
                    local elo : word 1 of `expectn'
                    if `enw' == 1 {
                        if `scope_n' != `elo' {
                            local ++n_viol
                            local viol_names "`viol_names' expectn"
                            local vgate`n_viol' "expectn"
                            local vvar`n_viol' ""
                            local vobs`n_viol' "`scope_n'"
                            local vexp`n_viol' "`elo'"
                            local vgroup`n_viol' "`GP'"
                            local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                            local vmsg`n_viol' "`PFX'expectn: expected N = `elo', observed `scope_n'"
                        }
                    }
                    else {
                        local ehi : word 2 of `expectn'
                        if `scope_n' < `elo' | `scope_n' > `ehi' {
                            local ++n_viol
                            local viol_names "`viol_names' expectn"
                            local vgate`n_viol' "expectn"
                            local vvar`n_viol' ""
                            local vobs`n_viol' "`scope_n'"
                            local vexp`n_viol' "[`elo', `ehi']"
                            local vgroup`n_viol' "`GP'"
                            local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                            local vmsg`n_viol' "`PFX'expectn: expected N in [`elo', `ehi'], observed `scope_n'"
                        }
                    }
                }

                // isid
                if "`isid'" != "" {
                    tempvar in_tag
                    quietly egen byte `in_tag' = tag(`isid') if `IF'
                    quietly count if `IF' & `in_tag'
                    local idist = r(N)
                    quietly drop `in_tag'
                    if `idist' != `scope_n' {
                        local ++n_viol
                        local viol_names "`viol_names' isid"
                        local vgate`n_viol' "isid"
                        local vvar`n_viol' "`isid'"
                        local vobs`n_viol' "`scope_n' rows, `idist' distinct"
                        local vexp`n_viol' "unique"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'isid(`isid'): not unique — `scope_n' rows, `idist' distinct"
                    }
                }

                // nodups
                if "`nodups'" != "" {
                    quietly duplicates report if `IF'
                    local ndup = r(N) - r(unique_value)
                    if `ndup' > 0 {
                        local ++n_viol
                        local viol_names "`viol_names' nodups"
                        local vgate`n_viol' "nodups"
                        local vvar`n_viol' ""
                        local vobs`n_viol' "`ndup'"
                        local vexp`n_viol' "0 duplicated rows"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'nodups: `ndup' duplicated row(s)"
                    }
                }

                // notmissing
                if "`notmissing'" != "" {
                    foreach v of local notmissing {
                        quietly count if `IF' & missing(`v')
                        if r(N) > 0 {
                            local nmiss = r(N)
                            local ++n_viol
                            local viol_names "`viol_names' notmissing"
                            local vgate`n_viol' "notmissing"
                            local vvar`n_viol' "`v'"
                            local vobs`n_viol' "`nmiss' missing"
                            local vexp`n_viol' "0 missing"
                            local vgroup`n_viol' "`GP'"
                            local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                            local vmsg`n_viol' "`PFX'notmissing: `v' has `nmiss' missing value(s)"
                        }
                    }
                }

                // inrange
                forvalues k = 1/`n_inr' {
                    local iv "`inr_var`k''"
                    local lo "`inr_lo`k''"
                    local hi "`inr_hi`k''"
                    quietly count if `IF' & (`iv' < `lo' | `iv' > `hi') & !missing(`iv')
                    if r(N) > 0 {
                        local noutr = r(N)
                        quietly summarize `iv' if `IF'
                        local omin = r(min)
                        local omax = r(max)
                        local ++n_viol
                        local viol_names "`viol_names' inrange"
                        local vgate`n_viol' "inrange"
                        local vvar`n_viol' "`iv'"
                        local vobs`n_viol' "`noutr' outside; min `omin', max `omax'"
                        local vexp`n_viol' "[`inr_lolab`k'', `inr_hilab`k'']"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'inrange(`iv'): `noutr' obs outside [`inr_lolab`k'', `inr_hilab`k'']  (min `omin', max `omax')"
                    }
                }

                // allowed
                forvalues k = 1/`n_allowed' {
                    local av "`allowed_var`k''"
                    local vals `"`allowed_vals`k''"'
                    tempvar ok
                    quietly gen byte `ok' = 0 if `IF' & !missing(`av')
                    capture confirm numeric variable `av'
                    if !_rc {
                        foreach val of local vals {
                            quietly replace `ok' = 1 if `IF' & `av' == `val' & !missing(`av')
                        }
                    }
                    else {
                        foreach val of local vals {
                            local sval = subinstr(`"`val'"', char(34), "", .)
                            quietly replace `ok' = 1 if `IF' & `av' == `"`sval'"' & !missing(`av')
                        }
                    }
                    quietly count if `IF' & !missing(`av') & `ok' == 0
                    if r(N) > 0 {
                        local nbad = r(N)
                        local ++n_viol
                        local viol_names "`viol_names' allowed"
                        local vgate`n_viol' "allowed"
                        local vvar`n_viol' "`av'"
                        local vobs`n_viol' "`nbad' disallowed"
                        local vexp`n_viol' "`vals'"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'allowed(`av'): `nbad' obs outside allowed values {`vals'}"
                    }
                    quietly drop `ok'
                }

                // forbid
                forvalues k = 1/`n_forbid' {
                    local fv "`forbid_var`k''"
                    local vals `"`forbid_vals`k''"'
                    tempvar bad
                    quietly gen byte `bad' = 0 if `IF' & !missing(`fv')
                    capture confirm numeric variable `fv'
                    if !_rc {
                        foreach val of local vals {
                            quietly replace `bad' = 1 if `IF' & `fv' == `val' & !missing(`fv')
                        }
                    }
                    else {
                        foreach val of local vals {
                            local sval = subinstr(`"`val'"', char(34), "", .)
                            quietly replace `bad' = 1 if `IF' & `fv' == `"`sval'"' & !missing(`fv')
                        }
                    }
                    quietly count if `IF' & `bad' == 1
                    if r(N) > 0 {
                        local nbad = r(N)
                        local ++n_viol
                        local viol_names "`viol_names' forbid"
                        local vgate`n_viol' "forbid"
                        local vvar`n_viol' "`fv'"
                        local vobs`n_viol' "`nbad' forbidden"
                        local vexp`n_viol' "none of `vals'"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'forbid(`fv'): `nbad' obs contain forbidden values {`vals'}"
                    }
                    quietly drop `bad'
                }

                // notvalues / sentinel
                forvalues k = 1/`n_notvalues' {
                    local nv "`notvalues_var`k''"
                    local vals `"`notvalues_vals`k''"'
                    tempvar bad
                    quietly gen byte `bad' = 0 if `IF' & !missing(`nv')
                    capture confirm numeric variable `nv'
                    if !_rc {
                        foreach val of local vals {
                            quietly replace `bad' = 1 if `IF' & `nv' == `val' & !missing(`nv')
                        }
                    }
                    else {
                        foreach val of local vals {
                            local sval = subinstr(`"`val'"', char(34), "", .)
                            quietly replace `bad' = 1 if `IF' & `nv' == `"`sval'"' & !missing(`nv')
                        }
                    }
                    quietly count if `IF' & `bad' == 1
                    if r(N) > 0 {
                        local nbad = r(N)
                        local ++n_viol
                        local viol_names "`viol_names' notvalues"
                        local vgate`n_viol' "notvalues"
                        local vvar`n_viol' "`nv'"
                        local vobs`n_viol' "`nbad' sentinel"
                        local vexp`n_viol' "none of `vals'"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'notvalues(`nv'): `nbad' obs contain sentinel values {`vals'}"
                    }
                    quietly drop `bad'
                }

                // regex
                forvalues k = 1/`n_regex' {
                    local rv "`regex_var`k''"
                    local pat `"`regex_pat`k''"'
                    capture confirm string variable `rv'
                    if !_rc {
                        quietly count if `IF' & !missing(`rv') & !regexm(`rv', `"`pat'"')
                    }
                    else {
                        quietly count if `IF' & !missing(`rv') & !regexm(string(`rv'), `"`pat'"')
                    }
                    if r(N) > 0 {
                        local nbad = r(N)
                        local ++n_viol
                        local viol_names "`viol_names' regex"
                        local vgate`n_viol' "regex"
                        local vvar`n_viol' "`rv'"
                        local vobs`n_viol' "`nbad' nonmatching"
                        local vexp`n_viol' "`pat'"
                        local vgroup`n_viol' "`GP'"
                        local vsev`n_viol' = cond("`warn'" != "", "warning", "error")
                        local vmsg`n_viol' "`PFX'regex(`rv'): `nbad' obs do not match `pat'"
                    }
                }
            }
        }

        local viol_names = trim("`viol_names'")
        local failed_checks : list uniq viol_names
        local n_failed : word count `failed_checks'
        local n_checks = 0
        if `"`expectn'"' != "" local ++n_checks
        if "`isid'" != "" local ++n_checks
        if "`nodups'" != "" local ++n_checks
        if "`require'" != "" local ++n_checks
        if "`notmissing'" != "" local ++n_checks
        if `n_inr' > 0 local ++n_checks
        if `n_allowed' > 0 local ++n_checks
        if `n_forbid' > 0 local ++n_checks
        if `n_regex' > 0 local ++n_checks
        if `n_notvalues' > 0 local ++n_checks
        local n_passed = `n_checks' - `n_failed'
        if `n_passed' < 0 local n_passed = 0
        local n_groups = 0
        if `has_groups' local n_groups : word count `group_levels'

        // ---- violations(): structured one-row-per-failed-gate artifact ----
        if `"`violations'"' != "" {
            gettoken vdest vrest : violations, parse(" ,")
            local vreplace = 0
            if regexm(`"`vrest'"', "replace") local vreplace = 1
            tempname vframe
            local _vframe "`vframe'"
            frame create `vframe'
            local _vframe_made = 1
            frame `vframe' {
                clear
                quietly set obs `n_viol'
                quietly generate str32 check = ""
                quietly generate str32 gate = ""
                quietly generate str80 variable = ""
                quietly generate str80 group = ""
                quietly generate str80 observed = ""
                quietly generate str120 expected = ""
                quietly generate str12 severity = ""
                quietly generate str244 message = ""
                forvalues j = 1/`n_viol' {
                    quietly replace check = "`vgate`j''" in `j'
                    quietly replace gate = "`vgate`j''" in `j'
                    quietly replace variable = "`vvar`j''" in `j'
                    quietly replace group = "`vgroup`j''" in `j'
                    quietly replace observed = "`vobs`j''" in `j'
                    quietly replace expected = "`vexp`j''" in `j'
                    quietly replace severity = "`vsev`j''" in `j'
                    quietly replace message = "`vmsg`j''" in `j'
                }
            }
            local _isfile = 0
            if substr(`"`vdest'"', -4, 4) == ".dta" local _isfile = 1
            else if strpos(`"`vdest'"', "/") | strpos(`"`vdest'"', "\") local _isfile = 1
            if `_isfile' {
                _datacheck_pathok `"`vdest'"'
                if `vreplace' frame `vframe': quietly save `"`vdest'"', replace
                else          frame `vframe': quietly save `"`vdest'"'
            }
            else {
                capture confirm name `vdest'
                if _rc {
                    display as error "violations() frame name is invalid"
                    exit 198
                }
                capture frame `vdest': describe
                if !_rc & !`vreplace' {
                    display as error "violations() frame `vdest' already exists; specify replace"
                    exit 110
                }
                if `vreplace' {
                    capture frame drop `vdest'
                    if _rc {
                        display as error "violations() could not replace frame `vdest'"
                        exit _rc
                    }
                }
                frame copy `vframe' `vdest'
            }
        }

        // ---- makespec(): starter reusable check spec from observed data ----
        if `"`makespec'"' != "" {
            gettoken sdest srest : makespec, parse(" ,")
            local sreplace = 0
            if regexm(`"`srest'"', "replace") local sreplace = 1
            tempname sframe
            local _sframe "`sframe'"
            frame create `sframe'
            local _sframe_made = 1
            frame `sframe' {
                clear
                quietly generate str16 check = ""
                quietly generate str16 gate = ""
                quietly generate str80 variable = ""
                quietly generate str80 var = ""
                quietly generate str80 arg1 = ""
                quietly generate str80 arg2 = ""
                quietly generate str2045 values = ""
                quietly generate str244 pattern = ""
                quietly generate str244 note = ""
            }
            local srow = 0
            local ++srow
            frame `sframe': quietly set obs `srow'
            frame `sframe': quietly replace check = "expectn" in `srow'
            frame `sframe': quietly replace gate = "expectn" in `srow'
            frame `sframe': quietly replace arg1 = "`nobs'" in `srow'
            frame `sframe': quietly replace arg2 = "`nobs'" in `srow'
            frame `sframe': quietly replace note = "observed N" in `srow'
            local spec_key ""
            foreach v of local profilevars {
                quietly count if missing(`v')
                if r(N) > 0 continue
                capture isid `v'
                if !_rc {
                    local spec_key "`v'"
                    continue, break
                }
            }
            if "`spec_key'" != "" {
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "isid" in `srow'
                frame `sframe': quietly replace gate = "isid" in `srow'
                frame `sframe': quietly replace variable = "`spec_key'" in `srow'
                frame `sframe': quietly replace var = "`spec_key'" in `srow'
                frame `sframe': quietly replace values = "`spec_key'" in `srow'
                frame `sframe': quietly replace note = "candidate key: unique nonmissing" in `srow'
            }
            local ++srow
            frame `sframe': quietly set obs `srow'
            frame `sframe': quietly replace check = "require" in `srow'
            frame `sframe': quietly replace gate = "require" in `srow'
            frame `sframe': quietly replace values = "`profilevars'" in `srow'
            frame `sframe': quietly replace note = "profiled variables" in `srow'
            foreach v of local f_continuous {
                if `c_N_`v'' == 0 continue
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "inrange" in `srow'
                frame `sframe': quietly replace gate = "inrange" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                frame `sframe': quietly replace arg1 = "`c_min_`v''" in `srow'
                frame `sframe': quietly replace arg2 = "`c_max_`v''" in `srow'
                frame `sframe': quietly replace note = "observed continuous range" in `srow'
            }
            foreach v of local f_date {
                quietly summarize `v'
                if r(N) == 0 continue
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "inrange" in `srow'
                frame `sframe': quietly replace gate = "inrange" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                frame `sframe': quietly replace arg1 = "`=r(min)'" in `srow'
                frame `sframe': quietly replace arg2 = "`=r(max)'" in `srow'
                frame `sframe': quietly replace note = "observed date range" in `srow'
            }
            foreach v of local f_categorical {
                local i = `idx_`v''
                if `m_uv`i'' > `maxcat' continue
                quietly levelsof `v' if !missing(`v'), local(_levels) clean
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "allowed" in `srow'
                frame `sframe': quietly replace gate = "allowed" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                frame `sframe': quietly replace values = `"`_levels'"' in `srow'
                frame `sframe': quietly replace note = "observed levels" in `srow'
            }
            foreach v of local f_string {
                local i = `idx_`v''
                if `m_uv`i'' > `maxcat' continue
                quietly levelsof `v' if !missing(`v'), local(_levels) clean
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "allowed" in `srow'
                frame `sframe': quietly replace gate = "allowed" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                frame `sframe': quietly replace values = `"`_levels'"' in `srow'
                frame `sframe': quietly replace note = "observed levels" in `srow'
            }
            local _isfile = 0
            if substr(`"`sdest'"', -4, 4) == ".dta" local _isfile = 1
            else if strpos(`"`sdest'"', "/") | strpos(`"`sdest'"', "\") local _isfile = 1
            if `_isfile' {
                _datacheck_pathok `"`sdest'"'
                if `sreplace' frame `sframe': quietly save `"`sdest'"', replace
                else          frame `sframe': quietly save `"`sdest'"'
            }
            else {
                capture confirm name `sdest'
                if _rc {
                    display as error "makespec() frame name is invalid"
                    exit 198
                }
                capture frame `sdest': describe
                if !_rc & !`sreplace' {
                    display as error "makespec() frame `sdest' already exists; specify replace"
                    exit 110
                }
                if `sreplace' {
                    capture frame drop `sdest'
                    if _rc {
                        display as error "makespec() could not replace frame `sdest'"
                        exit _rc
                    }
                }
                frame copy `sframe' `sdest'
            }
        }

        // ---- return surface (posted after all work succeeds) ----
        return scalar N              = `nobs'
        return scalar complete_cases = `n_complete'
        return scalar complete_pct   = `pct_complete'
        return scalar n_violations   = `n_viol'
        return scalar n_checks       = `n_checks'
        return scalar n_passed       = `n_passed'
        return scalar n_failed       = `n_failed'
        return scalar n_groups       = `n_groups'
        return scalar gatesonly      = ("`gatesonly'" != "")
        return scalar onlyflagged    = (`showflagged')
        return scalar n_continuous   = `: word count `f_continuous''
        return scalar n_categorical  = `: word count `f_categorical''
        return scalar n_date         = `: word count `f_date''
        return scalar n_string       = `: word count `f_string''
        return scalar n_excluded     = `: word count `f_excluded''
        return scalar n_flagged      = `n_flagged'
        return scalar n_constant     = `n_constant'
        return scalar n_highcard     = `n_highcard'
        return scalar n_missing_vars = `n_missing_vars'
        return scalar n_outlier_vars = `n_outlier_vars'
        return scalar n_rare_vars    = `n_rare_vars'
        return scalar n_group_missing_vars = `n_group_missing_vars'
        return scalar mincell        = `mincell'
        return scalar maskrare       = ("`maskrare'" != "")
        return local  violations     "`viol_names'"
        return local  failed_checks  "`failed_checks'"
        return local  continuous_vars "`f_continuous'"
        return local  categorical_vars "`f_categorical'"
        return local  date_vars      "`f_date'"
        return local  string_vars    "`f_string'"
        return local  excluded_vars  "`f_excluded'"
        return local  flagged_vars   "`flagged_vars'"
        return local  constant_vars  "`constant_vars'"
        return local  highcard_vars  "`highcard_vars'"
        return local  missing_vars   "`missing_vars'"
        return local  outlier_vars   "`outlier_vars'"
        return local  rare_vars      "`rare_vars'"
        return local  group_missing_vars "`group_missing_vars'"

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
                        capture frame `sfile': describe
                        if !_rc & !`sreplace' {
                            display as text "  " as error ///
                                "saving: frame `sfile' already exists; specify replace — skipped"
                        }
                        else {
                            if `sreplace' {
                                capture frame drop `sfile'
                                if _rc exit _rc
                            }
                            frame copy `pframe' `sfile'
                        }
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
    local cleanup_rc = 0
    if `_sframe_made' {
        capture frame drop `_sframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_vframe_made' {
        capture frame drop `_vframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_cframe_made' {
        capture frame drop `_cframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_pframe_made' {
        capture frame drop `pframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_preserved' {
        capture restore
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    if `cleanup_rc' exit `cleanup_rc'
end

// ---------------------------------------------------------------------------
// Helpers (bundled; loaded with datacheck.ado)
// ---------------------------------------------------------------------------

capture program drop _datacheck_pathok
local _drop_pathok_rc = _rc
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

capture program drop _datacheck_bound
local _drop_bound_rc = _rc
program define _datacheck_bound, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken v raw : 0
        local raw = trim(`"`raw'"')
        if `"`raw'"' == "" {
            display as error "empty range bound"
            exit 198
        }
        tempname val
        capture scalar `val' = `raw'
        if !_rc {
            local out = scalar(`val')
        }
        else {
            local clean = subinstr(`"`raw'"', char(34), "", .)
            local vfmt : format `v'
            local vfmt = lower("`vfmt'")
            if strpos("`vfmt'", "%tm") {
                scalar `val' = monthly(`"`clean'"', "YM")
            }
            else if strpos("`vfmt'", "%tq") {
                scalar `val' = quarterly(`"`clean'"', "YQ")
            }
            else if strpos("`vfmt'", "%tw") {
                scalar `val' = weekly(`"`clean'"', "YW")
            }
            else if strpos("`vfmt'", "%ty") {
                scalar `val' = yearly(`"`clean'"', "Y")
            }
            else {
                scalar `val' = daily(`"`clean'"', "DMY")
                if missing(`val') scalar `val' = daily(`"`clean'"', "YMD")
                if missing(`val') scalar `val' = daily(`"`clean'"', "MDY")
            }
            if missing(`val') {
                display as error `"could not parse range bound `raw' for `v'"'
                exit 198
            }
            local out = scalar(`val')
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar value = `out'
end

capture program drop _datacheck_flag
local _drop_flag_rc = _rc
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
local _drop_freq_rc = _rc
program define _datacheck_freq, nclass
    // Frequency table sorted by descending count, capped at maxfreq.
    args v maxfreq rare maskcell
    if "`maskcell'" == "" local maskcell = 0
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
            if `maskcell' > 0 & `ct' < `maskcell' {
                display as text "    " as result %-28s "[suppressed]" ///
                    as text "  suppressed (<" as result `maskcell' as text ")" ///
                    as error "`rflag'"
            }
            else {
                display as text "    " as result %-28s `"`disp'"' ///
                    as result %9.0f `ct' as text "  (" as result %4.1f `pc' ///
                    as text "%)" as error "`rflag'"
            }
        }
        if `nlev' > `maxfreq' {
            display as text "    ... " as result `=`nlev'-`maxfreq'' ///
                as text " more level(s) not shown (maxfreq)"
        }
    }
    frame drop `fr'
end
