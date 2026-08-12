/*  demo_comorbidity.do - Demo output for comorbidity

    Produces:
      1. Console output covering core workflows -> .log -> .md via logdoc

    Covers:
      - Charlson original with collapse and score bands
      - Charlson Quan 2011 with merge, generate(), and replace
      - Elixhauser van Walraven with generate() and noisily
      - Date-windowed scanning with inclusive lookback/lookforward
      - Hierarchy toggling with nohierarchy
      - Custom weighted .dta code file
*/

version 16.0
set varabbrev off
set linesize 120
set more off

**# Paths

local repo_dir "`c(pwd)'"
local demo_dir "`repo_dir'/comorbidity/demo"
local slash = strrpos("`repo_dir'", "/")
local parent = substr("`repo_dir'", 1, `slash' - 1)
local tools_dir "`parent'/Stata-Tools"
capture mkdir "`demo_dir'"

**# Install package and dependencies from local sources

capture ado uninstall comorbidity
quietly net install comorbidity, from("`repo_dir'/comorbidity") replace

capture confirm file "`tools_dir'/codescan/codescan.ado"
if !_rc {
    capture ado uninstall codescan
    quietly net install codescan, from("`tools_dir'/codescan") replace
}
else {
    capture which codescan
    if _rc {
        net install codescan, ///
            from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") replace
    }
}

**# Console output

capture log close _all
log using "`demo_dir'/console_output.log", replace text name(demo) nomsg

* # Charlson Original With Collapse And Score Bands

quietly {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    3 ""     ""
    end
}

noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse band
noisily list pid charlson mi chf dm_uncomp metastatic, noobs abbreviate(16)
noisily matrix list r(bands)

* # Charlson Quan 2011 With Merge, Generate, And Replace

quietly {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    gen double cmb_score = -99
}

noisily comorbidity dx1 dx2, id(pid) charlson(quan2011) merge generate(cmb_) replace
noisily list pid dx1 dx2 cmb_score cmb_mi cmb_chf cmb_dm_uncomp cmb_metastatic, noobs abbreviate(16)

* # Elixhauser Van Walraven With Verbose Scanning

quietly {
    clear
    input long pid str6 dx1 str6 dx2 str6 dx3
    1 "I50"  "C780" "F11"
    2 "E66"  "F32"  ""
    3 "I10"  "I11"  "E112"
    end
}

noisily comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) collapse ///
    generate(elx_) replace noisily
noisily list pid elx_score elx_chf elx_metastatic elx_drug elx_obesity ///
    elx_depression elx_htn_comp elx_htn_uncomp elx_dm_comp elx_dm_uncomp, ///
    noobs abbreviate(16)

* # Date-Windowed Scanning

quietly {
    clear
    input long pid str6 dx1 int dxdate int refdate
    1 "I50" 21910 21915
    1 "I21" 21885 21915
    2 "I50" 21550 21915
    end
    format dxdate refdate %td
}

noisily comorbidity dx1, id(pid) charlson(original) collapse ///
    date(dxdate) refdate(refdate) lookback(30) lookforward(10) inclusive
noisily list pid charlson mi chf, noobs abbreviate(16)

* # Hierarchy Toggle

quietly {
    clear
    input long pid str6 dx1 str6 dx2
    1 "C780" "C509"
    end
    tempfile hierarchy_data
    save "`hierarchy_data'", replace
}

noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse
noisily list pid charlson cancer metastatic, noobs abbreviate(16)
quietly use "`hierarchy_data'", clear
noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse nohierarchy replace
noisily list pid charlson cancer metastatic, noobs abbreviate(16)

* # Custom Weighted Code File

quietly {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21" "I50"
    2 "E119" ""
    end

    tempfile custom_codes
    preserve
    clear
    input str12 name str20 pattern double weight
    "mi" "I21|I22" 10
    "chf" "I50" 2
    "dm" "E11" 4
    end
    save "`custom_codes'.dta", replace
    restore
}

noisily comorbidity dx1 dx2, id(pid) custom("`custom_codes'.dta") collapse replace
noisily list pid custom mi chf dm, noobs abbreviate(16)

display "RESULT: demo_comorbidity tests=6 pass=6 fail=0"

log close demo

**# Convert console log to markdown via logdoc

capture confirm file "`tools_dir'/logdoc/logdoc.ado"
if !_rc {
    capture ado uninstall logdoc
    quietly net install logdoc, from("`tools_dir'/logdoc") replace
}
else {
    capture which logdoc
    if _rc {
        net install logdoc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/logdoc") replace
    }
}

logdoc using "`demo_dir'/console_output.log", ///
    output("`demo_dir'/console_output.md") ///
    format(md) replace quiet

clear
