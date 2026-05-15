*! _codescan_codefile Version 1.1.0  2026/04/24
*! Private codefile helpers for codescan
*! Author: Timothy P Copeland

program define _codescan_parse_codefile, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _did_preserve = 0
    capture noisily {

    syntax , CODEFILE(string) [SCOREType(string)]

    local resolved_codefile `"`codefile'"'
    local ext = lower(substr(`"`resolved_codefile'"', -4, .))
    if "`ext'" != ".csv" & "`ext'" != ".dta" {
        display as error "codefile() must be a .csv or .dta file"
        exit 198
    }
    capture confirm file `"`resolved_codefile'"'
    if _rc {
        local _cf_base = lower(regexr(`"`resolved_codefile'"', ".*[\\/]", ""))
        if inlist("`_cf_base'", "charlson_icd10_example.csv", "elixhauser_icd10_example.csv") {
            local _builtin_found = 0
            capture findfile "`_cf_base'"
            if _rc == 0 {
                local resolved_codefile `"`r(fn)'"'
                local ext ".csv"
                local _builtin_found = 1
            }
            if !`_builtin_found' {
                capture findfile codescan.ado
                if _rc == 0 {
                    local _pkg_dir = regexr(`"`r(fn)'"', "codescan\.ado$", "")
                    local _pkg_csv `"`_pkg_dir'`_cf_base'"'
                    capture confirm file `"`_pkg_csv'"'
                    if _rc == 0 {
                        local resolved_codefile `"`_pkg_csv'"'
                        local ext ".csv"
                        local _builtin_found = 1
                    }
                }
            }
            if !`_builtin_found' {
                tempfile _builtin_codefile
                _codescan_write_builtin_codefile, name("`_cf_base'") target("`_builtin_codefile'")
                local resolved_codefile "`_builtin_codefile'"
                local ext ".dta"
            }
        }
        else {
            display as error `"codefile(): file not found: `resolved_codefile'"'
            exit 601
        }
    }

    preserve
    local _did_preserve = 1
    quietly {
        if "`ext'" == ".csv" {
            import delimited `"`resolved_codefile'"', clear stringcols(_all) varnames(1)
        }
        else {
            use `"`resolved_codefile'"', clear
        }
    }

    * R2: Case-tolerant column name matching
    foreach _cfcol in name pattern label exclusion weight {
        capture confirm variable `_cfcol'
        if _rc {
            * Try case-insensitive match
            foreach _v of varlist * {
                if lower("`_v'") == "`_cfcol'" & "`_v'" != "`_cfcol'" {
                    rename `_v' `_cfcol'
                    continue, break
                }
            }
        }
    }

    * Validate required columns
    capture confirm string variable name
    if _rc {
        display as error "codefile(): file must contain a string variable {bf:name}"
        exit 198
    }
    capture confirm string variable pattern
    if _rc {
        display as error "codefile(): file must contain a string variable {bf:pattern}"
        exit 198
    }

    * Optional columns
    capture confirm string variable label
    local _cf_has_label = (_rc == 0)
    capture confirm string variable exclusion
    local _cf_has_excl = (_rc == 0)
    capture confirm variable weight
    local _cf_has_weight = (_rc == 0)

    quietly count
    local n_conditions = r(N)
    if `n_conditions' == 0 {
        display as error "codefile(): file is empty"
        exit 198
    }

    local all_names ""
    local n_labels = 0
    forvalues i = 1/`n_conditions' {
        local def_name_`i' = name[`i']
        local def_pattern_`i' = pattern[`i']
        local def_excl_`i' ""
        local all_names "`all_names' `def_name_`i''"

        if `_cf_has_label' {
            local _lbl = label[`i']
            if `"`_lbl'"' != "" {
                local ++n_labels
                local lab_name_`n_labels' "`def_name_`i''"
                local lab_label_`n_labels' `"`_lbl'"'
            }
        }
        if `_cf_has_excl' {
            local _excl = exclusion[`i']
            if `"`_excl'"' != "" {
                local def_excl_`i' `"`_excl'"'
            }
        }
        if `_cf_has_weight' {
            local def_weight_`i' = weight[`i']
        }
        else {
            local def_weight_`i' = 0
        }
    }
    local all_names = trim("`all_names'")

    * R3: Codefile schema validation — batch all errors
    local _cf_errors ""
    local _cf_nerr = 0
    if "`scoretype'" == "custom" & !`_cf_has_weight' {
        local ++_cf_nerr
        local _cf_errors `"`_cf_errors'"score(custom) requires a weight column in codefile()" "'
    }
    forvalues i = 1/`n_conditions' {
        if "`def_name_`i''" == "" {
            local ++_cf_nerr
            local _cf_errors `"`_cf_errors'"row `i': empty name" "'
        }
        if `"`def_pattern_`i''"' == "" {
            local ++_cf_nerr
            local _cf_errors `"`_cf_errors'"row `i': empty pattern" "'
        }
        if "`def_name_`i''" != "" {
            capture confirm name `def_name_`i''
            if _rc {
                local ++_cf_nerr
                local _cf_errors `"`_cf_errors'"row `i': '`def_name_`i''' is not a valid Stata name" "'
            }
        }
        if "`scoretype'" == "custom" & `_cf_has_weight' {
            local _wval = weight[`i']
            local _wnum = real("`_wval'")
            if "`_wval'" == "" | "`_wnum'" == "." {
                local ++_cf_nerr
                local _cf_errors `"`_cf_errors'"row `i': weight is missing or non-numeric ('`_wval'')" "'
            }
        }
        forvalues j = 1/`=`i'-1' {
            if "`def_name_`i''" == "`def_name_`j''" & "`def_name_`i''" != "" {
                local ++_cf_nerr
                local _cf_errors `"`_cf_errors'"row `i': duplicate name '`def_name_`i''' (same as row `j')" "'
                continue, break
            }
        }
    }
    if `_cf_nerr' > 0 {
        display as error "codefile(): `_cf_nerr' validation error(s):"
        local _cf_remain `"`_cf_errors'"'
        forvalues _ei = 1/`_cf_nerr' {
            gettoken _emsg _cf_remain : _cf_remain
            display as error "  `_emsg'"
        }
        exit 198
    }

    }
    local rc = _rc
    if `_did_preserve' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_conditions = `n_conditions'
    return scalar n_labels = `n_labels'
    return local all_names "`all_names'"
    return local resolved_codefile `"`resolved_codefile'"'
    forvalues i = 1/`n_conditions' {
        return local def_name_`i' "`def_name_`i''"
        return local def_pattern_`i' `"`def_pattern_`i''"'
        return local def_excl_`i' `"`def_excl_`i''"'
        return local def_weight_`i' "`def_weight_`i''"
    }
    if `n_labels' > 0 {
        forvalues i = 1/`n_labels' {
            return local lab_name_`i' "`lab_name_`i''"
            return local lab_label_`i' `"`lab_label_`i''"'
        }
    }
end

program define _codescan_write_builtin_codefile, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _post_closed = 0
    local _return_path ""
    capture noisily {

    syntax , NAME(string) TARGET(string)

    tempname _cfh
    postfile `_cfh' str32 name str2045 pattern str2045 exclusion str80 label double weight ///
        using `"`target'"', replace

    if lower("`name'") == "charlson_icd10_example.csv" {
        post `_cfh' ("mi") ("I21|I22|I252") ("") ("Myocardial Infarction") (1)
        post `_cfh' ("chf") ("I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290") ("") ("Congestive Heart Failure") (1)
        post `_cfh' ("pvd") ("I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959") ("") ("Peripheral Vascular Disease") (1)
        post `_cfh' ("cvd") ("G45|G46|H340|I60|I61|I62|I63|I64|I65|I66|I67|I68|I69") ("") ("Cerebrovascular Disease") (1)
        post `_cfh' ("dementia") ("F00|F01|F02|F03|F051|G30|G311") ("") ("Dementia") (1)
        post `_cfh' ("copd") ("I278|I279|J40|J41|J42|J43|J44|J45|J46|J47|J60|J61|J62|J63|J64|J65|J66|J67|J684|J701|J703") ("") ("Chronic Pulmonary Disease") (1)
        post `_cfh' ("rheumatic") ("M05|M06|M315|M32|M33|M34|M351|M353|M360") ("") ("Rheumatic Disease") (1)
        post `_cfh' ("peptic") ("K25|K26|K27|K28") ("") ("Peptic Ulcer Disease") (1)
        post `_cfh' ("liver_mild") ("B18|K700|K701|K702|K703|K709|K713|K714|K715|K717|K73|K74|K760|K762|K763|K764|K768|K769|Z944") ("") ("Mild Liver Disease") (1)
        post `_cfh' ("dm_uncomp") ("E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149") ("") ("Diabetes without Complications") (1)
        post `_cfh' ("dm_comp") ("E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147") ("") ("Diabetes with Complications") (2)
        post `_cfh' ("hemiplegia") ("G041|G114|G801|G802|G81|G82|G830|G831|G832|G833|G834|G839") ("") ("Hemiplegia or Paraplegia") (2)
        post `_cfh' ("renal") ("I120|I131|N032|N033|N034|N035|N036|N037|N052|N053|N054|N055|N056|N057|N18|N19|N250|Z490|Z491|Z492|Z940|Z992") ("") ("Renal Disease") (2)
        post `_cfh' ("cancer") ("C00|C01|C02|C03|C04|C05|C06|C07|C08|C09|C10|C11|C12|C13|C14|C15|C16|C17|C18|C19|C20|C21|C22|C23|C24|C25|C26|C30|C31|C32|C33|C34|C37|C38|C39|C40|C41|C43|C45|C46|C47|C48|C49|C50|C51|C52|C53|C54|C55|C56|C57|C58|C60|C61|C62|C63|C64|C65|C66|C67|C68|C69|C70|C71|C72|C73|C74|C75|C76|C81|C82|C83|C84|C85|C88|C90|C91|C92|C93|C94|C95|C96|C97") ("") ("Any Malignancy") (2)
        post `_cfh' ("liver_severe") ("I850|I859|I864|I982|K704|K711|K721|K729|K765|K766|K767") ("") ("Moderate or Severe Liver Disease") (3)
        post `_cfh' ("metastatic") ("C77|C78|C79|C80") ("") ("Metastatic Solid Tumor") (6)
        post `_cfh' ("hiv") ("B20|B21|B22|B24") ("") ("HIV/AIDS") (6)
    }
    else if lower("`name'") == "elixhauser_icd10_example.csv" {
        post `_cfh' ("chf") ("I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290") ("") ("Congestive Heart Failure") (7)
        post `_cfh' ("arrhythmia") ("I441|I442|I443|I456|I459|I47|I48|I49|R000|R001|R008|T821|Z450|Z950") ("") ("Cardiac Arrhythmias") (5)
        post `_cfh' ("valvular") ("A520|I05|I06|I07|I08|I091|I098|I34|I35|I36|I37|I38|I39|Q230|Q231|Q232|Q233|Z952|Z953|Z954") ("") ("Valvular Disease") (-1)
        post `_cfh' ("pulmonary_circ") ("I26|I27|I280|I288|I289") ("") ("Pulmonary Circulation Disorders") (4)
        post `_cfh' ("pvd") ("I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959") ("") ("Peripheral Vascular Disorders") (2)
        post `_cfh' ("htn_uncomp") ("I10") ("") ("Hypertension Uncomplicated") (0)
        post `_cfh' ("htn_comp") ("I11|I12|I13|I15") ("") ("Hypertension Complicated") (0)
        post `_cfh' ("paralysis") ("G041|G114|G801|G802|G803|G81|G82|G830|G831|G832|G833|G834|G839") ("") ("Paralysis") (7)
        post `_cfh' ("neuro_other") ("G10|G11|G12|G13|G20|G21|G22|G254|G255|G312|G318|G319|G32|G35|G36|G37|G40|G41|G931|G934") ("") ("Other Neurological Disorders") (6)
        post `_cfh' ("copd") ("I278|I279|J40|J41|J42|J43|J44|J45|J46|J47|J60|J61|J62|J63|J64|J65|J66|J67|J684|J701|J703") ("") ("Chronic Pulmonary Disease") (3)
        post `_cfh' ("dm_uncomp") ("E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149") ("") ("Diabetes Uncomplicated") (0)
        post `_cfh' ("dm_comp") ("E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147") ("") ("Diabetes Complicated") (0)
        post `_cfh' ("hypothyroid") ("E00|E01|E02|E03|E890") ("") ("Hypothyroidism") (0)
        post `_cfh' ("renal") ("I120|I131|N032|N033|N034|N035|N036|N037|N052|N053|N054|N055|N056|N057|N18|N19|N250|Z490|Z491|Z492|Z940|Z992") ("") ("Renal Failure") (5)
        post `_cfh' ("liver") ("B18|I850|I859|I864|I982|K700|K701|K702|K703|K704|K709|K711|K713|K714|K715|K717|K721|K729|K73|K74|K760|K762|K763|K764|K765|K766|K767|K768|K769|Z944") ("") ("Liver Disease") (11)
        post `_cfh' ("pud") ("K25|K26|K27|K28") ("") ("Peptic Ulcer Disease") (0)
        post `_cfh' ("hiv") ("B20|B21|B22|B24") ("") ("AIDS/HIV") (0)
        post `_cfh' ("lymphoma") ("C81|C82|C83|C84|C85|C88|C96") ("") ("Lymphoma") (9)
        post `_cfh' ("metastatic") ("C77|C78|C79|C80") ("") ("Metastatic Cancer") (12)
        post `_cfh' ("solid_tumor") ("C00|C01|C02|C03|C04|C05|C06|C07|C08|C09|C10|C11|C12|C13|C14|C15|C16|C17|C18|C19|C20|C21|C22|C23|C24|C25|C26|C30|C31|C32|C33|C34|C37|C38|C39|C40|C41|C43|C45|C46|C47|C48|C49|C50|C51|C52|C53|C54|C55|C56|C57|C58|C60|C61|C62|C63|C64|C65|C66|C67|C68|C69|C70|C71|C72|C73|C74|C75|C76") ("") ("Solid Tumor Without Metastasis") (4)
        post `_cfh' ("rheumatoid") ("L940|L941|L943|M05|M06|M08|M120|M123|M30|M31|M32|M33|M34|M35|M45|M46") ("") ("Rheumatoid Arthritis/Collagen Vascular Disease") (0)
        post `_cfh' ("coagulopathy") ("D65|D66|D67|D68|D691|D693|D694|D695|D696") ("") ("Coagulopathy") (3)
        post `_cfh' ("obesity") ("E66") ("") ("Obesity") (-4)
        post `_cfh' ("weight_loss") ("E40|E41|E42|E43|E44|E45|E46|R634") ("") ("Weight Loss") (6)
        post `_cfh' ("fluid_electrolyte") ("E222|E86|E87") ("") ("Fluid and Electrolyte Disorders") (5)
        post `_cfh' ("blood_loss_anemia") ("D500") ("") ("Blood Loss Anemia") (-2)
        post `_cfh' ("deficiency_anemia") ("D508|D509|D51|D52|D53") ("") ("Deficiency Anemia") (-2)
        post `_cfh' ("alcohol") ("F10|K700|K703|K709|T51") ("") ("Alcohol Abuse") (0)
        post `_cfh' ("drug") ("F11|F12|F13|F14|F15|F16|F18|F19") ("") ("Drug Abuse") (-7)
        post `_cfh' ("psychoses") ("F20|F22|F23|F24|F25|F28|F29|F302|F312|F313|F314|F315") ("") ("Psychoses") (0)
        post `_cfh' ("depression") ("F204|F313|F314|F315|F32|F33|F341|F351|F38|F39") ("") ("Depression") (-3)
    }
    else {
        postclose `_cfh'
        display as error "built-in codefile `name' is not supported"
        exit 601
    }

    postclose `_cfh'
    local _post_closed = 1
    local _return_path `"`target'"'
    }
    local rc = _rc
    if !`_post_closed' capture postclose `_cfh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local path `"`_return_path'"'
end
