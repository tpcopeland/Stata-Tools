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
do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_state.do"
local tests=0
local pass=0
local fail=0

**# Literal prefix/regex presence, occurrence counts and output shape
foreach op in friendly codes_sparse prefix_ambiguous_codes empty_slots case_whitespace_variants dates_out_of_window unsorted {
    foreach mode in regex prefix {
        foreach shape in row collapse merge frame count {
            local ++tests
            capture noisily {
                if "`op'"=="friendly" qa_fx_a5_wide, clear tier(micro) seed(931)
                else {
                    * expect: EXACT
                    qa_fx_a5_wide, clear tier(micro) seed(931) perturb(`op')
                }
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
                    if "`shape'"=="merge" replace want_`name'=. if !inrange(date,mdy(1,1,2020),ref)
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
}
**# Describe every raw code frequency by a long reshape oracle
foreach op in friendly empty_slots case_whitespace_variants unsorted {
    local ++tests
    capture noisily {
        if "`op'"=="friendly" qa_fx_a5_wide, clear tier(micro)
        else {
            * expect: EXACT
            qa_fx_a5_wide, clear tier(micro) perturb(`op')
        }
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
}
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
