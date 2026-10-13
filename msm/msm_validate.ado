*! msm_validate Version 2.0.0  2026/10/13
*! Removed in msm 2.0.0: prints the replacement and exits 199
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* This stub ships for all of msm 2.x. `net install msm, replace' does not delete
* files dropped from the package, so only a file with this name reliably
* displaces the 1.4.x command on an upgraded machine. Removed at msm 3.0.0.

program define msm_validate
    version 16.0
    display as error "msm_validate was removed in msm 2.0.0."
    display as error `"Its checks moved into the core: {bf:msm_prepare} refuses duplicates,"'
    display as error `"non-binary values and non-integer periods, and reports gaps, missing values,"'
    display as error `"constant covariates and sparse periods; {bf:msm_weight} refuses gaps and"'
    display as error `"missing model inputs; post-event and post-censoring rows leave the risk set"'
    display as error `"(_msm_decision_risk); {bf:msm_diagnose} flags periods without a treatment"'
    display as error `"contrast and the positivity floor."'
    display as error `"See {help msm##companions:help msm} for the replacement map."'
    exit 199
end
