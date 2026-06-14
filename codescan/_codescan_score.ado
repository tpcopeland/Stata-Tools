*! _codescan_score Version 1.1.3  2026/06/14
*! Private score helpers for codescan
*! Author: Timothy P Copeland

capture program drop _codescan_assign_score_weights
program define _codescan_assign_score_weights, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , SCOREType(string) NCONDITIONS(integer) NAMES(string asis) [GENerate(string)]

    local _score_type = lower("`scoretype'")
    local _names `"`names'"'
    if strlen(`"`_names'"') >= 2 {
        if substr(`"`_names'"', 1, 1) == char(34) & ///
            substr(`"`_names'"', strlen(`"`_names'"'), 1) == char(34) {
            local _names = substr(`"`_names'"', 2, strlen(`"`_names'"') - 2)
        }
    }

    if "`_score_type'" == "charlson" {
        * Quan et al. 2011 updated Charlson weights (ICD-10 codes from Quan et al. 2005)
        * Map condition names to standard Charlson weights
        forvalues i = 1/`nconditions' {
            local def_name_`i' : word `i' of `_names'
            local _snm = lower("`def_name_`i''")
            * Strip any generate() prefix for matching
            if "`generate'" != "" {
                local _snm = substr("`_snm'", strlen("`generate'") + 1, .)
            }
            local def_weight_`i' = 0
            if inlist("`_snm'", "mi", "chf", "pvd", "dementia", "copd") {
                local def_weight_`i' = 1
            }
            if inlist("`_snm'", "cvd", "stroke", "cerebrovascular") {
                local def_weight_`i' = 1
            }
            if inlist("`_snm'", "rheumatic", "rheumatoid", "connective") {
                local def_weight_`i' = 1
            }
            if inlist("`_snm'", "peptic", "ulcer", "pud") {
                local def_weight_`i' = 1
            }
            if inlist("`_snm'", "liver_mild", "mild_liver") {
                local def_weight_`i' = 1
            }
            if inlist("`_snm'", "dm", "dm1", "dm2", "dm_uncomp", "diabetes") {
                local def_weight_`i' = 1
            }
            if inlist("`_snm'", "dm_comp", "dm_complicated", "diabetes_comp") {
                local def_weight_`i' = 2
            }
            if inlist("`_snm'", "hemiplegia", "paraplegia", "paralysis") {
                local def_weight_`i' = 2
            }
            if inlist("`_snm'", "renal", "ckd", "kidney") {
                local def_weight_`i' = 2
            }
            if inlist("`_snm'", "cancer", "malignancy", "tumor") {
                local def_weight_`i' = 2
            }
            if inlist("`_snm'", "liver_severe", "severe_liver") {
                local def_weight_`i' = 3
            }
            if inlist("`_snm'", "metastatic", "mets") {
                local def_weight_`i' = 6
            }
            if inlist("`_snm'", "hiv", "aids") {
                local def_weight_`i' = 6
            }
        }
        * Warn for unrecognized condition names
        forvalues i = 1/`nconditions' {
            if `def_weight_`i'' == 0 {
                local _warn_nm = lower("`def_name_`i''")
                if "`generate'" != "" {
                    local _warn_nm = substr("`_warn_nm'", strlen("`generate'") + 1, .)
                }
                noisily display as text ///
                    "(note: `_warn_nm' is not a recognized Charlson condition name; weight = 0)"
            }
        }
    }
    else if "`_score_type'" == "elixhauser" {
        * Van Walraven et al. 2009 Elixhauser weights
        * ICD-10 condition names mapped to van Walraven weights
        * _elix_matched_`i' = 1 when name was recognized (even if weight = 0)
        forvalues i = 1/`nconditions' {
            local def_name_`i' : word `i' of `_names'
            local _snm = lower("`def_name_`i''")
            if "`generate'" != "" {
                local _snm = substr("`_snm'", strlen("`generate'") + 1, .)
            }
            local def_weight_`i' = 0
            local _elix_matched_`i' = 0
            if inlist("`_snm'", "chf", "heart_failure") {
                local def_weight_`i' = 7
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "arrhythmia", "cardiac_arrhythmia") {
                local def_weight_`i' = 5
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "valvular", "valvular_disease") {
                local def_weight_`i' = -1
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "pulmonary_circ", "pulmonary_circulation") {
                local def_weight_`i' = 4
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "pvd", "peripheral_vascular") {
                local def_weight_`i' = 2
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "htn_uncomp", "hypertension_uncomp") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "htn_comp", "hypertension_comp") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "paralysis") {
                local def_weight_`i' = 7
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "neuro_other", "other_neurological") {
                local def_weight_`i' = 6
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "copd", "chronic_pulmonary") {
                local def_weight_`i' = 3
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "dm_uncomp", "diabetes_uncomp") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "dm_comp", "diabetes_comp") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "hypothyroid", "hypothyroidism") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "renal", "renal_failure") {
                local def_weight_`i' = 5
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "liver", "liver_disease") {
                local def_weight_`i' = 11
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "pud", "peptic_ulcer") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "hiv", "aids") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "lymphoma") {
                local def_weight_`i' = 9
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "metastatic", "metastatic_cancer") {
                local def_weight_`i' = 12
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "solid_tumor", "solid_tumour") {
                local def_weight_`i' = 4
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "rheumatoid", "rheumatoid_arthritis", "collagen") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "coagulopathy") {
                local def_weight_`i' = 3
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "obesity") {
                local def_weight_`i' = -4
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "weight_loss") {
                local def_weight_`i' = 6
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "fluid_electrolyte", "fluid_electrolytes") {
                local def_weight_`i' = 5
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "blood_loss_anemia", "blood_loss") {
                local def_weight_`i' = -2
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "deficiency_anemia", "anemia") {
                local def_weight_`i' = -2
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "alcohol", "alcohol_abuse") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "drug", "drug_abuse") {
                local def_weight_`i' = -7
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "psychoses", "psychosis") {
                local def_weight_`i' = 0
                local _elix_matched_`i' = 1
            }
            if inlist("`_snm'", "depression") {
                local def_weight_`i' = -3
                local _elix_matched_`i' = 1
            }
        }
        * Warn for unrecognized Elixhauser condition names (matched flag = 0)
        forvalues i = 1/`nconditions' {
            if !`_elix_matched_`i'' {
                local _warn_nm = lower("`def_name_`i''")
                if "`generate'" != "" {
                    local _warn_nm = substr("`_warn_nm'", strlen("`generate'") + 1, .)
                }
                noisily display as text ///
                    "(note: `_warn_nm' is not a recognized Elixhauser condition name; weight = 0)"
            }
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    forvalues i = 1/`nconditions' {
        return local def_weight_`i' "`def_weight_`i''"
    }
end

capture program drop _codescan_apply_score
program define _codescan_apply_score
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , SCOREType(string) SCOREName(name) NAMES(string asis) WEIGHTS(string asis) [REPlace]

    local _score_type = lower("`scoretype'")
    local _names `"`names'"'
    if strlen(`"`_names'"') >= 2 {
        if substr(`"`_names'"', 1, 1) == char(34) & ///
            substr(`"`_names'"', strlen(`"`_names'"'), 1) == char(34) {
            local _names = substr(`"`_names'"', 2, strlen(`"`_names'"') - 2)
        }
    }
    local _weights `"`weights'"'
    if strlen(`"`_weights'"') >= 2 {
        if substr(`"`_weights'"', 1, 1) == char(34) & ///
            substr(`"`_weights'"', strlen(`"`_weights'"'), 1) == char(34) {
            local _weights = substr(`"`_weights'"', 2, strlen(`"`_weights'"') - 2)
        }
    }
    local _n_names : word count `_names'
    local _n_weights : word count `_weights'
    if `_n_names' != `_n_weights' {
        display as error "_codescan_apply_score: names and weights must have the same length"
        exit 198
    }

    if "`replace'" != "" {
        capture drop `scorename'
    }
    quietly gen double `scorename' = 0
    forvalues i = 1/`_n_names' {
        local name : word `i' of `_names'
        local wt : word `i' of `_weights'
        if `wt' != 0 {
            if inlist("`_score_type'", "charlson", "elixhauser") {
                * Charlson/Elixhauser: binary presence regardless of countmode
                * sign() preserves missing propagation for unmatched merge rows
                quietly replace `scorename' = `scorename' + `wt' * sign(`name')
            }
            else {
                quietly replace `scorename' = `scorename' + `wt' * `name'
            }
        }
    }
    label variable `scorename' "`_score_type' score"

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
