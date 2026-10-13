*! msm_table Version 2.0.0  2026/10/13
*! Removed in msm 2.0.0: prints the replacement and exits 199
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* This stub ships for all of msm 2.x. `net install msm, replace' does not delete
* files dropped from the package, so only a file with this name reliably
* displaces the 1.4.x command on an upgraded machine. Removed at msm 3.0.0.

program define msm_table
    version 16.0
    display as error "msm_table was removed in msm 2.0.0."
    display as error `"coefficients:  {bf:collect: msm_fit ...} then {bf:regtab, xlsx() sheet()} (tabtools)"'
    display as error `"predictions:   {bf:matrix RD = r(rd)} then {bf:effecttab, from(RD) xlsx()} or {bf:puttab using f.xlsx, matrix(r(predictions))}"'
    display as error `"balance:       {bf:psdash balance ..., xlsx()} or {bf:puttab ..., matrix(r(treatment_balance))}"'
    display as error `"weights:       {bf:psdash weights ..., wvar(_msm_weight) xlsx()}"'
    display as error `"E-values:      {bf:qba_confound, from_model ... evalue} (qba)"'
    display as error `"See {help msm##companions:help msm} for the replacement map."'
    exit 199
end
