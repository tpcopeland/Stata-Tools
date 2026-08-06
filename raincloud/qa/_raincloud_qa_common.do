* _raincloud_qa_common.do - isolated QA installation bootstrap for raincloud

capture program drop _raincloud_qa_bootstrap
program define _raincloud_qa_bootstrap
    args pkg_dir

    tempfile _plus_seed _personal_seed
    local plus_dir "`_plus_seed'_plus"
    local personal_dir "`_personal_seed'_personal"
    capture mkdir "`plus_dir'"
    capture mkdir "`personal_dir'"
    sysdir set PLUS "`plus_dir'"
    sysdir set PERSONAL "`personal_dir'"

    * Inventory and remove only this package before the local install.
    capture noisily ado dir
    capture ado uninstall raincloud
    quietly net install raincloud, from("`pkg_dir'") replace
end
