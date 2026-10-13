*! msm_plot Version 2.0.0  2026/10/13
*! Removed in msm 2.0.0: prints the replacement and exits 199
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* This stub ships for all of msm 2.x. `net install msm, replace' does not delete
* files dropped from the package, so only a file with this name reliably
* displaces the 1.4.x command on an upgraded machine. Removed at msm 3.0.0.

program define msm_plot
    version 16.0
    display as error "msm_plot was removed in msm 2.0.0."
    display as error `"weights:     {bf:psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) graph}"'
    display as error `"balance:     {bf:psdash balance treatment _msm_ps if _msm_decision_risk, covariates(...) wvar(_msm_weight) loveplot}"'
    display as error `"survival:    {bf:msm_predict, ... frame(F)} then {bf:twoway} (see help msm_predict)"'
    display as error `"trajectory:  {bf:gen pstop = period + 1} then {bf:swimlane, id(id) start(period) stop(pstop) state(treatment)}"'
    display as error `"positivity:  {bf:psdash combined, wvar(_msm_weight)} and {bf:msm_diagnose}"'
    display as error `"See {help msm##companions:help msm} for the replacement map."'
    exit 199
end
