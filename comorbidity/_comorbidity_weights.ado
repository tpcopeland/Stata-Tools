*! _comorbidity_weights Version 1.0.1  2026/08/30
*! Published comorbidity scheme weight vectors
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _comorbidity_weights
local _drop_rc = _rc
if `_drop_rc' & `_drop_rc' != 111 {
    exit `_drop_rc'
}
program define _comorbidity_weights, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , INDEX(string) SCHEME(string) NAMES(string asis) [PREFIX(string)]
        local index = lower(strtrim("`index'"))
        local scheme = lower(strtrim("`scheme'"))
        local clean_names `"`names'"'
        if strlen(`"`clean_names'"') >= 2 {
            if substr(`"`clean_names'"', 1, 1) == char(34) & ///
                substr(`"`clean_names'"', strlen(`"`clean_names'"'), 1) == char(34) {
                local clean_names = substr(`"`clean_names'"', 2, strlen(`"`clean_names'"') - 2)
            }
        }

        if "`index'" == "charlson" {
            if !inlist("`scheme'", "original", "quan2011") {
                display as error "charlson scheme must be original or quan2011"
                exit 198
            }
        }
        else if "`index'" == "elixhauser" {
            if inlist("`scheme'", "ahrq_mortality", "ahrq_readmission") {
                display as error "ahrq weights not yet implemented; AHRQ source curation required"
                exit 198
            }
            if "`scheme'" != "vanwalraven" {
                display as error "elixhauser scheme must be vanwalraven, ahrq_mortality, or ahrq_readmission"
                exit 198
            }
        }
        else {
            display as error "unknown index `index'"
            exit 198
        }

        local weights ""
        foreach nm of local clean_names {
            local s = lower("`nm'")
            if `"`prefix'"' != "" {
                local plen = strlen(`"`prefix'"')
                if substr("`s'", 1, `plen') == lower(`"`prefix'"') {
                    local s = substr("`s'", `plen' + 1, .)
                }
            }
            local w ""

            if "`index'" == "charlson" {
                if "`scheme'" == "original" {
                    if inlist("`s'", "mi", "chf", "pvd", "cvd", "dementia") {
                        local w = 1
                    }
                    if inlist("`s'", "copd", "rheumatic", "peptic", "liver_mild", "dm_uncomp") {
                        local w = 1
                    }
                    if inlist("`s'", "dm_comp", "hemiplegia", "renal", "cancer") {
                        local w = 2
                    }
                    if "`s'" == "liver_severe" {
                        local w = 3
                    }
                    if inlist("`s'", "metastatic", "hiv") {
                        local w = 6
                    }
                }
                else {
                    if inlist("`s'", "mi", "pvd", "cvd", "peptic", "dm_uncomp") {
                        local w = 0
                    }
                    if inlist("`s'", "chf", "dementia", "liver_mild", "hemiplegia", "cancer") {
                        local w = 2
                    }
                    if inlist("`s'", "copd", "rheumatic", "dm_comp", "renal") {
                        local w = 1
                    }
                    if "`s'" == "liver_severe" {
                        local w = 4
                    }
                    if "`s'" == "metastatic" {
                        local w = 6
                    }
                    if "`s'" == "hiv" {
                        local w = 4
                    }
                }
            }
            else if "`index'" == "elixhauser" {
                if inlist("`s'", "htn_uncomp", "htn_comp", "dm_uncomp", "dm_comp", "hypothyroid") {
                    local w = 0
                }
                if inlist("`s'", "pud", "hiv", "rheumatoid", "alcohol", "psychoses") {
                    local w = 0
                }
                if "`s'" == "chf" local w = 7
                if "`s'" == "arrhythmia" local w = 5
                if "`s'" == "valvular" local w = -1
                if "`s'" == "pulmonary_circ" local w = 4
                if "`s'" == "pvd" local w = 2
                if "`s'" == "paralysis" local w = 7
                if "`s'" == "neuro_other" local w = 6
                if "`s'" == "copd" local w = 3
                if "`s'" == "renal" local w = 5
                if "`s'" == "liver" local w = 11
                if "`s'" == "lymphoma" local w = 9
                if "`s'" == "metastatic" local w = 12
                if "`s'" == "solid_tumor" local w = 4
                if "`s'" == "coagulopathy" local w = 3
                if "`s'" == "obesity" local w = -4
                if "`s'" == "weight_loss" local w = 6
                if "`s'" == "fluid_electrolyte" local w = 5
                if "`s'" == "blood_loss_anemia" local w = -2
                if "`s'" == "deficiency_anemia" local w = -2
                if "`s'" == "drug" local w = -7
                if "`s'" == "depression" local w = -3
            }

            if "`w'" == "" {
                display as error "no `scheme' weight defined for condition `s'"
                exit 498
            }

            local weights "`weights' `w'"
            local retname "w_`nm'"
            return local `retname' "`w'"
        }
        local weights = strtrim("`weights'")
        return local weights "`weights'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
