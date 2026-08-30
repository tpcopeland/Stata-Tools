*! _comorbidity_dictionary Version 1.0.1  2026/08/30
*! Built-in ICD-10 condition dictionaries for comorbidity
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _comorbidity_dictionary
local _drop_rc = _rc
if `_drop_rc' & `_drop_rc' != 111 {
    exit `_drop_rc'
}
program define _comorbidity_dictionary, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _post_open = 0
    local _return_target ""

    capture noisily {
        syntax , INDEX(string) TARGET(string)
        local index = lower(strtrim("`index'"))

        tempname fh
        quietly postfile `fh' str32 name str2045 pattern str2045 exclusion ///
            str80 label double weight using `"`target'"', replace
        local _post_open = 1

        if "`index'" == "charlson" {
            post `fh' ("mi") ("I21|I22|I252") ("") ("Myocardial Infarction") (0)
            post `fh' ("chf") ("I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290") ("") ("Congestive Heart Failure") (0)
            post `fh' ("pvd") ("I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959") ("") ("Peripheral Vascular Disease") (0)
            post `fh' ("cvd") ("G45|G46|H340|I60|I61|I62|I63|I64|I65|I66|I67|I68|I69") ("") ("Cerebrovascular Disease") (0)
            post `fh' ("dementia") ("F00|F01|F02|F03|F051|G30|G311") ("") ("Dementia") (0)
            post `fh' ("copd") ("I278|I279|J40|J41|J42|J43|J44|J45|J46|J47|J60|J61|J62|J63|J64|J65|J66|J67|J684|J701|J703") ("") ("Chronic Pulmonary Disease") (0)
            post `fh' ("rheumatic") ("M05|M06|M315|M32|M33|M34|M351|M353|M360") ("") ("Rheumatic Disease") (0)
            post `fh' ("peptic") ("K25|K26|K27|K28") ("") ("Peptic Ulcer Disease") (0)
            post `fh' ("liver_mild") ("B18|K700|K701|K702|K703|K709|K713|K714|K715|K717|K73|K74|K760|K762|K763|K764|K768|K769|Z944") ("") ("Mild Liver Disease") (0)
            post `fh' ("dm_uncomp") ("E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149") ("") ("Diabetes without Complications") (0)
            post `fh' ("dm_comp") ("E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147") ("") ("Diabetes with Complications") (0)
            post `fh' ("hemiplegia") ("G041|G114|G801|G802|G81|G82|G830|G831|G832|G833|G834|G839") ("") ("Hemiplegia or Paraplegia") (0)
            post `fh' ("renal") ("I120|I131|N032|N033|N034|N035|N036|N037|N052|N053|N054|N055|N056|N057|N18|N19|N250|Z490|Z491|Z492|Z940|Z992") ("") ("Renal Disease") (0)
            post `fh' ("cancer") ("C00|C01|C02|C03|C04|C05|C06|C07|C08|C09|C10|C11|C12|C13|C14|C15|C16|C17|C18|C19|C20|C21|C22|C23|C24|C25|C26|C30|C31|C32|C33|C34|C37|C38|C39|C40|C41|C43|C45|C46|C47|C48|C49|C50|C51|C52|C53|C54|C55|C56|C57|C58|C60|C61|C62|C63|C64|C65|C66|C67|C68|C69|C70|C71|C72|C73|C74|C75|C76|C81|C82|C83|C84|C85|C88|C90|C91|C92|C93|C94|C95|C96|C97") ("") ("Any Malignancy") (0)
            post `fh' ("liver_severe") ("I850|I859|I864|I982|K704|K711|K721|K729|K765|K766|K767") ("") ("Moderate or Severe Liver Disease") (0)
            post `fh' ("metastatic") ("C77|C78|C79|C80") ("") ("Metastatic Solid Tumor") (0)
            post `fh' ("hiv") ("B20|B21|B22|B24") ("") ("HIV/AIDS") (0)
        }
        else if "`index'" == "elixhauser_vw" {
            post `fh' ("chf") ("I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290") ("") ("Congestive Heart Failure") (0)
            post `fh' ("arrhythmia") ("I441|I442|I443|I456|I459|I47|I48|I49|R000|R001|R008|T821|Z450|Z950") ("") ("Cardiac Arrhythmias") (0)
            post `fh' ("valvular") ("A520|I05|I06|I07|I08|I091|I098|I34|I35|I36|I37|I38|I39|Q230|Q231|Q232|Q233|Z952|Z953|Z954") ("") ("Valvular Disease") (0)
            post `fh' ("pulmonary_circ") ("I26|I27|I280|I288|I289") ("") ("Pulmonary Circulation Disorders") (0)
            post `fh' ("pvd") ("I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959") ("") ("Peripheral Vascular Disorders") (0)
            post `fh' ("htn_uncomp") ("I10") ("") ("Hypertension Uncomplicated") (0)
            post `fh' ("htn_comp") ("I11|I12|I13|I15") ("") ("Hypertension Complicated") (0)
            post `fh' ("paralysis") ("G041|G114|G801|G802|G803|G81|G82|G830|G831|G832|G833|G834|G839") ("") ("Paralysis") (0)
            post `fh' ("neuro_other") ("G10|G11|G12|G13|G20|G21|G22|G254|G255|G312|G318|G319|G32|G35|G36|G37|G40|G41|G931|G934|R470|R56") ("") ("Other Neurological Disorders") (0)
            post `fh' ("copd") ("I278|I279|J40|J41|J42|J43|J44|J45|J46|J47|J60|J61|J62|J63|J64|J65|J66|J67|J684|J701|J703") ("") ("Chronic Pulmonary Disease") (0)
            post `fh' ("dm_uncomp") ("E100|E101|E109|E110|E111|E119|E120|E121|E129|E130|E131|E139|E140|E141|E149") ("") ("Diabetes Uncomplicated") (0)
            post `fh' ("dm_comp") ("E102|E103|E104|E105|E106|E107|E108|E112|E113|E114|E115|E116|E117|E118|E122|E123|E124|E125|E126|E127|E128|E132|E133|E134|E135|E136|E137|E138|E142|E143|E144|E145|E146|E147|E148") ("") ("Diabetes Complicated") (0)
            post `fh' ("hypothyroid") ("E00|E01|E02|E03|E890") ("") ("Hypothyroidism") (0)
            post `fh' ("renal") ("I120|I131|N18|N19|N250|Z490|Z491|Z492|Z940|Z992") ("") ("Renal Failure") (0)
            post `fh' ("liver") ("B18|I85|I864|I982|K70|K711|K713|K714|K715|K717|K72|K73|K74|K760|K762|K763|K764|K765|K766|K767|K768|K769|Z944") ("") ("Liver Disease") (0)
            post `fh' ("pud") ("K257|K259|K267|K269|K277|K279|K287|K289") ("") ("Peptic Ulcer Disease Excluding Bleeding") (0)
            post `fh' ("hiv") ("B20|B21|B22|B24") ("") ("AIDS/HIV") (0)
            post `fh' ("lymphoma") ("C81|C82|C83|C84|C85|C88|C96|C900|C902") ("") ("Lymphoma") (0)
            post `fh' ("metastatic") ("C77|C78|C79|C80") ("") ("Metastatic Cancer") (0)
            post `fh' ("solid_tumor") ("C00|C01|C02|C03|C04|C05|C06|C07|C08|C09|C10|C11|C12|C13|C14|C15|C16|C17|C18|C19|C20|C21|C22|C23|C24|C25|C26|C30|C31|C32|C33|C34|C37|C38|C39|C40|C41|C43|C45|C46|C47|C48|C49|C50|C51|C52|C53|C54|C55|C56|C57|C58|C60|C61|C62|C63|C64|C65|C66|C67|C68|C69|C70|C71|C72|C73|C74|C75|C76|C97") ("") ("Solid Tumor Without Metastasis") (0)
            post `fh' ("rheumatoid") ("L940|L941|L943|M05|M06|M08|M120|M123|M30|M310|M311|M312|M313|M32|M33|M34|M35|M45|M461|M468|M469") ("") ("Rheumatoid Arthritis/Collagen Vascular Disease") (0)
            post `fh' ("coagulopathy") ("D65|D66|D67|D68|D691|D693|D694|D695|D696") ("") ("Coagulopathy") (0)
            post `fh' ("obesity") ("E66") ("") ("Obesity") (0)
            post `fh' ("weight_loss") ("E40|E41|E42|E43|E44|E45|E46|R634|R64") ("") ("Weight Loss") (0)
            post `fh' ("fluid_electrolyte") ("E222|E86|E87") ("") ("Fluid and Electrolyte Disorders") (0)
            post `fh' ("blood_loss_anemia") ("D500") ("") ("Blood Loss Anemia") (0)
            post `fh' ("deficiency_anemia") ("D508|D509|D51|D52|D53") ("") ("Deficiency Anemia") (0)
            post `fh' ("alcohol") ("F10|E52|G621|I426|K292|K700|K703|K709|T51|Z502|Z714|Z721") ("") ("Alcohol Abuse") (0)
            post `fh' ("drug") ("F11|F12|F13|F14|F15|F16|F18|F19|Z715|Z722") ("") ("Drug Abuse") (0)
            post `fh' ("psychoses") ("F20|F22|F23|F24|F25|F28|F29|F302|F312|F315") ("") ("Psychoses") (0)
            post `fh' ("depression") ("F204|F313|F314|F315|F32|F33|F341|F412|F432") ("") ("Depression") (0)
        }
        else if "`index'" == "elixhauser_ahrq" {
            postclose `fh'
            local _post_open = 0
            display as error "elixhauser_ahrq dictionary not yet implemented; AHRQ source curation required"
            exit 198
        }
        else {
            postclose `fh'
            local _post_open = 0
            display as error "unknown index `index'"
            exit 198
        }

        postclose `fh'
        local _post_open = 0
        local _return_target `"`target'"'
    }
    local rc = _rc
    if `_post_open' {
        capture postclose `fh'
        local _post_rc = _rc
        if `rc' == 0 & `_post_rc' {
            local rc = `_post_rc'
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local target `"`_return_target'"'
end
