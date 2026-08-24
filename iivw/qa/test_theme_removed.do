*! iivw reporting theme-option removal regression tests
version 16.0
local qa_dir = regexr("`c(pwd)'", "/+$", "")
do "`qa_dir'/_iivw_qa_common.do"
quietly iivw_qa_bootstrap
capture noisily iivw_balance, theme(lancet)
assert _rc == 198
sysuse auto, clear
quietly regress price mpg
estimates store _iivw_theme_unweighted
estimates store _iivw_theme_weighted
estimates store _iivw_theme_adjusted
capture noisily iivw_diagnose mpg, unweighted(_iivw_theme_unweighted) ///
    weighted(_iivw_theme_weighted) adjusted(_iivw_theme_adjusted) theme(lancet)
assert _rc == 198
estimates clear
generate long id = _n
generate byte time = 0
capture noisily iivw_exogtest price, id(id) time(time) maxfu(1) theme(lancet)
assert _rc == 198
display "RESULT: test_theme_removed tests=3 pass=3 fail=0"
exit 0
