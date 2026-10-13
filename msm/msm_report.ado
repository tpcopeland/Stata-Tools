*! msm_report Version 2.0.0  2026/10/13
*! Removed in msm 2.0.0: prints the replacement and exits 199
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* This stub ships for all of msm 2.x. `net install msm, replace' does not delete
* files dropped from the package, so only a file with this name reliably
* displaces the 1.4.x command on an upgraded machine. Removed at msm 3.0.0.

program define msm_report
    version 16.0
    display as error "msm_report was removed in msm 2.0.0."
    display as error `"Use {bf:collect: msm_fit ...} then {bf:regtab} for the outcome model, and"'
    display as error `"{bf:msm_predict, difference}, {bf:matrix RD = r(rd)} and {bf:effecttab, from(RD)} for"'
    display as error `"standardized risk differences (tabtools)."'
    display as error `"See {help msm##companions:help msm} for the replacement map."'
    exit 199
end
