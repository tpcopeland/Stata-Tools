*! validation_fixture_contract.do — canonical F/U numerical contract for codescan
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_contract.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_codescan_qa_common.do"
quietly _codescan_qa_bootstrap
local qa_owner=r(owner)
do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"

capture program drop _fx_codescan_2
program define _fx_codescan_2, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    local ++tests
    capture noisily {
        quietly use `fx_input', clear
                _return restore `fx_returns', hold
        tempfile tally
        preserve
            keep id dx1-dx4
            reshape long dx, i(id) j(slot)
            drop if dx=="" | dx=="."
            contract dx, freq(want)
            local n_unique=_N
            egen double total=total(want)
            local n_entries=total[1]
            save `tally'
        restore
        qa_state_snapshot, tag(desc_f)
        codescan_describe dx1-dx4, top(100)
        qa_state_compare, tag(desc_f)
        assert r(n_unique)==`n_unique' & r(n_entries)==`n_entries' & r(n_vars)==4
        tempname C
        matrix `C'=r(top_codes)
        forvalues i=1/`n_unique' {
            local code`i' `"`r(top_code_`i')'"'
        }
        forvalues i=1/`n_unique' {
            local code `"`code`i''"'
            preserve
                use `tally', clear
                assert _N==`n_unique'
                assert want==`C'[`i',1] if dx==`"`code'"'
                count if dx==`"`code'"'
                assert r(N)==1
            restore
        }
    }
    local case_rc=_rc
    capture restore
    if `case_rc'==0 local ++pass
    else local ++fail

    local ++tests
    capture noisily {
        quietly use `fx_input', clear
        preserve
            use `tally', clear
            quietly summarize want, meanonly
            local largest=r(max)
        restore
        * expect: EXACT
        qa_state_snapshot, tag(desc_top)
        codescan_describe dx1-dx4, top(1)
        qa_state_compare, tag(desc_top)
        assert rowsof(r(top_codes))==1 & r(top_codes)[1,1]==`largest'
        di "ORACLE codescan_describe `op' top1: maximum raw frequency exact"
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        quietly use `fx_input', clear
        * expect: EXACT
        qa_option_domain, command(codescan_describe dx1-dx4, top(@v@)) inside(1;100) outside(0;0.5)
    }
    if _rc==0 local ++pass
    else local ++fail

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

capture program drop _fx_codescan_1
program define _fx_codescan_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    
local tests=0
    local pass=0
    local fail=0

    foreach mode in regex prefix {
        foreach shape in row collapse merge frame count {
            local ++tests
            capture noisily {
                quietly use `fx_input', clear
                _return restore `fx_returns', hold
                tempname T
                matrix `T'=r(truth_ids)
                gen double ref=mdy(1,4,2020)
                format ref %td
                forvalues c=1/4 {
                    local name : word `c' of mi diabetes renal metastatic
                    local pat : word `c' of I21 E11 N18 C78
                    gen double want_`name'=0
                    forvalues j=1/4 {
                        if "`mode'"=="prefix" replace want_`name'=want_`name'+(substr(upper(subinstr(dx`j',".","",.)),1,3)=="`pat'")
                        else replace want_`name'=want_`name'+(strpos(upper(subinstr(dx`j',".","",.)),"`pat'")>0)
                    }
                    replace want_`name'=0 if !inrange(date,mdy(1,1,2020),ref)
                    if "`shape'"!="count" replace want_`name'=want_`name'>0
                    * Unanalyzed rows are missing under merge and, since v4.3.0, at the row level
                    if inlist("`shape'","merge","row") replace want_`name'=. if !inrange(date,mdy(1,1,2020),ref)
                }
                tempname W
                preserve
                    sort id
                    mkmat want_mi want_diabetes want_renal want_metastatic, matrix(`W')
                restore
                local opts ""
                if inlist("`shape'","collapse","count") local opts "collapse"
                if "`shape'"=="merge" local opts "merge"
                if "`shape'"=="frame" local opts "collapse frame(fx_codes)"
                if "`shape'"=="count" local opts "collapse countmode"
                * Prefix retains leading whitespace; explicit regex rules below
                * permit leading spaces rather than silently trimming the input.
                local lead ""
                if "`mode'"=="regex" local lead " *"
                codescan dx1-dx4, define(mi "`lead'I21" | diabetes "`lead'E11" | renal "`lead'N18" | metastatic "`lead'C78") id(id) mode(`mode') nodots nocase date(date) refdate(ref) lookback(3) inclusive `opts'
                if "`shape'"=="frame" {
                    forvalues i=1/4 {
                        local valid=inrange(date[`i'],mdy(1,1,2020),ref[`i'])
                        local ident=id[`i']
                        forvalues c=1/4 {
                            local name : word `c' of mi diabetes renal metastatic
                            scalar want=want_`name'[`i']
                            if `valid' frame fx_codes: assert `name'==scalar(want) if id==`ident'
                        }
                    }
                    frame drop fx_codes
                }
                else if inlist("`shape'","collapse","count") {
                    forvalues i=1/`=_N' {
                        local ident=id[`i']
                        forvalues c=1/4 {
                            local name : word `c' of mi diabetes renal metastatic
                            assert `name'[`i']==`W'[`ident',`c']
                        }
                    }
                    assert _N==cond("`op'"=="dates_out_of_window",3,4)
                }
                else {
                    foreach name in mi diabetes renal metastatic {
                        assert `name'==want_`name'
                    }
                }
                assert r(n_conditions)==4
            }
            local case_rc=_rc
            capture frame drop fx_codes
            if `case_rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL codescan `op' `mode' `shape' rc=`case_rc'"
            }
        }
    }

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

local tests=0
local pass=0
local fail=0

**# Literal prefix/regex presence, occurrence counts and output shape
qa_fx_a5_wide, clear tier(micro) seed(931)
_fx_codescan_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) seed(931) perturb(codes_sparse)
_fx_codescan_1 codes_sparse "perturb(codes_sparse)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) seed(931) perturb(prefix_ambiguous_codes)
_fx_codescan_1 prefix_ambiguous_codes "perturb(prefix_ambiguous_codes)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) seed(931) perturb(empty_slots)
_fx_codescan_1 empty_slots "perturb(empty_slots)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) seed(931) perturb(case_whitespace_variants)
_fx_codescan_1 case_whitespace_variants "perturb(case_whitespace_variants)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) seed(931) perturb(dates_out_of_window)
_fx_codescan_1 dates_out_of_window "perturb(dates_out_of_window)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) seed(931) perturb(unsorted)
_fx_codescan_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
**# Describe every raw code frequency by a long reshape oracle
qa_fx_a5_wide, clear tier(micro)
_fx_codescan_2 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(empty_slots)
_fx_codescan_2 empty_slots "perturb(empty_slots)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(case_whitespace_variants)
_fx_codescan_2 case_whitespace_variants "perturb(case_whitespace_variants)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
_fx_codescan_2 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(codes_sparse)
_fx_codescan_2 codes_sparse "perturb(codes_sparse)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(prefix_ambiguous_codes)
_fx_codescan_2 prefix_ambiguous_codes "perturb(prefix_ambiguous_codes)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(dates_out_of_window)
_fx_codescan_2 dates_out_of_window "perturb(dates_out_of_window)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
_codescan_qa_restore "`qa_owner'"
_codescan_qa_publish "validation_fixture_contract" `tests' `pass' `fail'
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
