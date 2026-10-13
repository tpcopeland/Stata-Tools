*! msm_diagtab Version 2.0.0  2026/10/13
*! Removed in msm 2.0.0: prints the replacement and exits 199
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* This stub ships for all of msm 2.x. `net install msm, replace' does not delete
* files dropped from the package, so only a file with this name reliably
* displaces the 1.4.x command on an upgraded machine. Removed at msm 3.0.0.

program define msm_diagtab
    version 16.0
    display as error "msm_diagtab was removed in msm 2.0.0."
    display as error `"There is no replacement. Post the {bf:msm_diagnose} or {bf:psdash} returns"'
    display as error `"you need with {bf:frame post} and export the frame with {bf:puttab, frame()}."'
    display as error `"See {help msm##companions:help msm} for the replacement map."'
    exit 199
end
