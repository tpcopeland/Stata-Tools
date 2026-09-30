*! _iivw_fixture_excel.do — shared canonical Excel assertions and font forms
*! Author: Timothy P Copeland, Karolinska Institutet
capture program drop _fx_fmt_font
program define _fx_fmt_font, rclass
    version 16.0
    args form
    local expected Arial
    if inlist("`form'","times","simple","compound","nested") local expected "Times New Roman"
    if "`form'"=="unicode" local expected "Ångström Sans"
    if "`form'"=="dollar" mata: st_local("expected","QA "+char(36)+"QAFONT_OPAQUE_BYTE Font")
    if "`form'"=="dollar_only" mata: st_local("expected",char(36)+"QAFONT_UNBOUND")
    if "`form'"=="ticks_only" mata: st_local("expected",char(96)+"unbound"+char(39))
    if "`form'"=="ticks" mata: st_local("expected","QA "+char(96)+"face"+char(39)+" Font")
    if "`form'"=="quotes" local expected "QA Quote Font"
    mata: st_local("raw",st_local("expected"))
    if inlist("`form'","simple","unicode","dollar","ticks") mata: st_local("raw",char(34)+st_local("raw")+char(34))
    if "`form'"=="compound" mata: st_local("raw",char(96)+char(34)+st_local("raw")+char(34)+char(39))
    if "`form'"=="nested" mata: st_local("raw",char(96)+char(34)+char(96)+char(34)+char(34)+st_local("raw")+char(34)+char(34)+char(39)+char(34)+char(39))
    if "`form'"=="quotes" mata: st_local("raw",char(34)+"QA "+char(34)+"Quote"+char(34)+" Font"+char(34))
    return local raw `"`macval(raw)'"'
    return local expected `"`macval(expected)'"'
end
capture program drop _fx_fmt_refusal
program define _fx_fmt_refusal
    version 16.0
    syntax , COMMAND(string asis) CAUSE(string)
    tempfile cause_log
    tempname fh
    log using `cause_log', name(fmt_cause) text replace nomsg
    capture noisily `command'
    local refusal_rc=_rc
    log close fmt_cause
    local named=0
    file open `fh' using `cause_log', read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`macval(line)'"',"`cause'") local named=1
        file read `fh' line
    }
    file close `fh'
    assert `refusal_rc'==198 & `named'==1
    display "ORACLE Excel refusal: rc198 and actual named cause `cause'"
end
capture program drop _fx_visit_excel
program define _fx_visit_excel, rclass
    version 16.0
    args op fonts
    drop if !visit
    iivw_fit y, unweighted id(id) time(time) timespec(linear) nolog
    estimates store fmt_naive
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
    iivw_fit y, vce(fixed) timespec(linear) nolog
    estimates store fmt_weighted
    local tests=0
    local pass=0
    local fail=0
    foreach route in balance diagnose exogtest {
        local command "iivw_balance"
        local mode balance
        if "`route'"=="diagnose" {
            local command "iivw_diagnose time, unweighted(fmt_naive) weighted(fmt_weighted) adjusted(fmt_weighted) exogeneity(exogenous)"
            local mode diagnostics
        }
        if "`route'"=="exogtest" {
            local command "iivw_exogtest y, id(id) time(time) maxfu(4) generate(_fmt_) nolog"
            local mode exogeneity
        }
        local separator ""
        if "`route'"=="balance" local separator ","
        local precisionlist 0 6
        local fontlist Arial times
        if "`fonts'"=="deep" {
            local precisionlist 6
            local fontlist Arial times simple compound nested unicode dollar ticks quotes
        }
        if "`fonts'"=="tokens" {
            local precisionlist 6
            local fontlist dollar_only ticks_only
        }
        foreach decimals of local precisionlist {
            foreach form of local fontlist {
                _fx_fmt_font `form'
                mata: st_local("font_raw",st_global("r(raw)"))
                mata: st_local("font",st_global("r(expected)"))
                tempfile stub marker
                local workbook "`stub'.xlsx"
                local ++tests
                capture noisily {
                    qa_state_snapshot, tag(excel)
                    `command' `separator' decimals(`decimals') font(`macval(font_raw)') xlsx("`workbook'") sheet(Format) replace
                    local gotdec=r(decimals)
                    local gotpath "`r(xlsx)'"
                    local gotsheet "`r(sheet)'"
                    local value=.
                    if "`route'"=="balance" local value=r(balance)[1,1]
                    if "`route'"=="diagnose" local value=r(estimates)[1,1]
                    if "`route'"=="exogtest" local value=r(results)[1,7]
                    assert `gotdec'==`decimals' & "`gotpath'"=="`workbook'" & "`gotsheet'"=="Format"
                    assert !missing(`value')
                    if "`route'"=="exogtest" {
                        confirm variable _fmt_y_lag1
                        * Only the documented generated output column is owned.
                        * Remove it temporarily, then require full original
                        * data columns/order/characteristics and every state
                        * surface to match the pre-call snapshot exactly.
                        preserve
                        drop _fmt_y_lag1
                        capture noisily qa_state_compare, tag(excel)
                        local state_rc=_rc
                        restore
                        drop _fmt_y_lag1
                        if `state_rc' exit `state_rc'
                    }
                    else qa_state_compare, tag(excel)
                    local numeric : display %21.17g `value'
                    tempfile expectation
                    tempname fh
                    file open `fh' using `expectation', write text replace
                    file write `fh' `"`macval(font)'"' _n
                    file close `fh'
                    shell python3 "`c(pwd)'/tools/check_iivw_format.py" "`workbook'" Format `mode' `decimals' "@`expectation'" "`numeric'" "`marker'" C4
                    confirm file "`marker'"
                    erase "`marker'"
                    erase "`workbook'"
                    display "ORACLE VISIT `op' `route': decimal`decimals' expected font `macval(font)' and exported numerical cell"
                }
                if _rc==0 local ++pass
                else {
                    local ++fail
                    display as error "FAIL VISIT Excel `op' `route' decimal`decimals' expected font `macval(font)'"
                }
            }
        }
        if "`fonts'"=="tokens" continue
        * These contextual font refusals follow four friendly export controls.
        * Font names are arbitrary strings: inventing an invalid family would
        * not test a documented boundary. Styling requires xlsx().
        local ++tests
        capture noisily {
            qa_state_snapshot, tag(font_context)
            _fx_fmt_refusal, command(`command' `separator' font("Arial")) cause("font() require xlsx()")
            qa_state_compare, tag(font_context)
        }
        if _rc==0 local ++pass
        else local ++fail
        foreach decimals in -1 7 {
            local ++tests
            capture noisily {
                qa_state_snapshot, tag(decimal_refusal)
                _fx_fmt_refusal, command(`command' `separator' decimals(`decimals') xlsx("refused_format.xlsx") replace) cause("decimals() must be between 0 and 6")
                qa_state_compare, tag(decimal_refusal)
                capture confirm file "refused_format.xlsx"
                assert _rc==601
            }
            if _rc==0 local ++pass
            else local ++fail
        }
    }
    estimates drop fmt_naive fmt_weighted
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
