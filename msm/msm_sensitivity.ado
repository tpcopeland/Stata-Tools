*! msm_sensitivity Version 2.0.0  2026/10/13
*! Removed in msm 2.0.0: prints the replacement and exits 199
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* This stub ships for all of msm 2.x. `net install msm, replace' does not delete
* files dropped from the package, so only a file with this name reliably
* displaces the 1.4.x command on an upgraded machine. Removed at msm 3.0.0.

program define msm_sensitivity
    version 16.0
    display as error "msm_sensitivity was removed in msm 2.0.0."
    display as error `"Use {bf:qba_confound, from_model coef(treatment) evalue measure(HR)} (qba)"'
    display as error `"after msm_fit. Add {bf:commonoutcome} when the cumulative incidence at the"'
    display as error `"end of follow-up (from {bf:msm_predict}) is 15% or more. help qba_confound"'
    display as error `"documents the rare/common choice and the bounding factor."'
    display as error `"See {help msm##companions:help msm} for the replacement map."'
    exit 199
end
