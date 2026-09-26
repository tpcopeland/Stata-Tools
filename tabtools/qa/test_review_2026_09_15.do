* test_review_2026_09_15.do - row identity regressions from the September review
* Author: Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set processors 1
capture log close _all
log using "test_review_2026_09_15.log", text replace name(review0915)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
local pass_count = 0
local fail_count = 0
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which _tabtools_collect_render

capture program drop _review_data
program define _review_data
    version 17.0
    clear
    quietly set obs 100
    generate byte tr = mod(_n, 2)
    generate double x = sin(_n)
    generate double y = 1 + tr + x + cos(_n/3)
    label define arms 0 "Control" 1 "Treatment", replace
    label values tr arms
    collect clear
end

**# F1 nondefault control retains contrast and exported row
capture noisily {
    _review_data
    quietly collect: teffects ipw (y) (tr x), control(1)
    tempname b t
    matrix `b' = e(b)
    local ate = `b'[1, colnumb(`b', "ATE:r0vs1.tr")]
    assert !missing(`ate')
    tempfile csv
    * csv() requires a .csv extension
    local csv "`csv'.csv"
    quietly effecttab, clean digits(6) frame(f1, replace) csv("`csv'")
    matrix `t' = r(table)
    assert rowsof(`t') == 2
    assert abs(`t'[1,1] - `ate') < 5.1e-7
    frame f1: count if strtrim(A) == "Control vs Treatment"
    assert r(N) == 1
    preserve
    import delimited using "`csv'", clear varnames(nonames) stringcols(_all)
    count if strtrim(v1) == "Control vs Treatment" & abs(real(v2) - `ate') < 5.1e-7
    assert r(N) == 1
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F1 nondefault control retains contrast and exported row"
}
else {
    local ++fail_count
    display as error "FAIL: F1 nondefault control retains contrast and exported row (rc=`=_rc')"
}

**# F2 distinct treatment names retain both models
capture noisily {
    _review_data
    generate byte tr2 = tr
    quietly collect: teffects ipw (y) (tr x)
    tempname b1 b2 t
    matrix `b1' = e(b)
    quietly collect: teffects ipw (y) (tr2 x)
    matrix `b2' = e(b)
    tempfile csv
    * csv() requires a .csv extension
    local csv "`csv'.csv"
    quietly effecttab, digits(6) frame(f2, replace) csv("`csv'")
    matrix `t' = r(table)
    assert colsof(`t') == 4
    forvalues m = 1/2 {
        local tv = cond(`m' == 1, "tr", "tr2")
        local cc = 3 * (`m' - 1) + 1
        local ate = `b`m''[1, colnumb(`b`m'', "ATE:r1vs0.`tv'")]
        local rr = rownumb(`t', "r1vs0_`tv'")
        assert !missing(`rr')
        assert abs(`t'[`rr', 2*`m'-1] - `ate') < 5.1e-7
        frame f2: count if strtrim(A) == "r1vs0.`tv'" & abs(real(c`cc') - `ate') < 5.1e-7
        assert r(N) == 1
        local pom = `b`m''[1, colnumb(`b`m'', "POmean:0.`tv'")]
        frame f2: count if strtrim(A) == "0.`tv'" & abs(real(c`cc') - `pom') < 5.1e-7
        assert r(N) == 1
        local vc = `cc' + 1
        preserve
        import delimited using "`csv'", clear varnames(nonames) stringcols(_all)
        count if v1 == "r1vs0.`tv'" & abs(real(v`vc') - `ate') < 5.1e-7
        assert r(N) == 1
        count if v1 == "0.`tv'" & abs(real(v`vc') - `pom') < 5.1e-7
        assert r(N) == 1
        restore
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F2 distinct treatment names retain both models"
}
else {
    local ++fail_count
    display as error "FAIL: F2 distinct treatment names retain both models (rc=`=_rc')"
}

**# F3 duplicate labels preserve each selected coefficient
capture noisily {
    foreach selected in x1 x2 {
        _review_data
        rename x x1
        generate double x2 = cos(_n)
        replace y = 2*x1 + 3*x2 + cos(_n/3)
        label variable x1 "Same label"
        label variable x2 "Same label"
        quietly collect: regress y x1 x2
        local wanted = _b[`selected']
        tempname t
        tempfile csv
        * csv() requires a .csv extension
        local csv "`csv'.csv"
        quietly regtab, keep(`selected') nointercept digits(6) frame(f3, replace) csv("`csv'")
        matrix `t' = r(table)
        assert rowsof(`t') == 1
        assert abs(`t'[1,1] - `wanted') < 5.1e-7
        preserve
        import delimited using "`csv'", clear varnames(nonames) stringcols(_all)
        count if v1 == "Same label"
        assert r(N) == 1
        assert abs(real(v2) - `wanted') < 5.1e-7 if v1 == "Same label"
        restore
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F3 duplicate labels preserve each selected coefficient"
}
else {
    local ++fail_count
    display as error "FAIL: F3 duplicate labels preserve each selected coefficient (rc=`=_rc')"
}

**# F4 mixed case treatment is not replaced by lowercase variable
capture noisily {
    forvalues collision = 0/1 {
        _review_data
        rename tr Tr
        if `collision' {
            generate byte tr = 1 - Tr
            label define wrong 0 "WRONG zero" 1 "WRONG one", replace
            label values tr wrong
        }
        quietly collect: teffects ipw (y) (Tr x)
        tempname b t
        matrix `b' = e(b)
        local ate = `b'[1, colnumb(`b', "ATE:r1vs0.Tr")]
        quietly effecttab, clean digits(6) frame(f4, replace)
        matrix `t' = r(table)
        assert rowsof(`t') == 2
        assert abs(`t'[1,1] - `ate') < 5.1e-7
        frame f4: count if strtrim(A) == "Treatment vs Control"
        assert r(N) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F4 mixed case treatment is not replaced by lowercase variable"
}
else {
    local ++fail_count
    display as error "FAIL: F4 mixed case treatment is not replaced by lowercase variable (rc=`=_rc')"
}

**# F5 clean labels survive cleared data
capture noisily {
    _review_data
    quietly collect: teffects ipw (y) (tr x)
    tempname b t
    matrix `b' = e(b)
    clear
    tempfile csv
    * csv() requires a .csv extension
    local csv "`csv'.csv"
    quietly effecttab, clean digits(6) frame(f5, replace) csv("`csv'")
    matrix `t' = r(table)
    assert rowsof(`t') == 2
    frame f5: count if strtrim(A) == "Tr (1 vs 0)"
    assert r(N) == 1
    frame f5: count if strtrim(A) == "Tr = 0 (PO Mean)"
    assert r(N) == 1
    preserve
    import delimited using "`csv'", clear varnames(nonames) stringcols(_all)
    count if v1 == "Tr (1 vs 0)"
    assert r(N) == 1
    assert strpos(v1, char(92)) == 0
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F5 clean labels survive cleared data"
}
else {
    local ++fail_count
    display as error "FAIL: F5 clean labels survive cleared data (rc=`=_rc')"
}

**# F6 exact names do not select overlapping or case distinct names
capture noisily {
    foreach action in keep drop {
        _review_data
        rename x age
        generate double stage = cos(_n)
        generate double Age = sin(_n/3)
        replace y = 2*age + 3*stage + 4*Age + cos(_n/3)
        quietly collect: regress y age stage Age
        tempname b t
        matrix `b' = e(b)
        quietly regtab, `action'(age) nointercept digits(6)
        matrix `t' = r(table)
        if "`action'" == "keep" {
            assert rowsof(`t') == 1
            assert abs(`t'[1,1] - `b'[1,1]) < 5.1e-7
        }
        else {
            assert rowsof(`t') == 2
            assert abs(`t'[1,1] - `b'[1,2]) < 5.1e-7
            assert abs(`t'[2,1] - `b'[1,3]) < 5.1e-7
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F6 exact names do not select overlapping or case distinct names"
}
else {
    local ++fail_count
    display as error "FAIL: F6 exact names do not select overlapping or case distinct names (rc=`=_rc')"
}

**# F7 every manifest ado shares flagship version and date
capture noisily {
    clear
    tempname fh manifest
    file open `fh' using "`pkg_dir'/tabtools.ado", read text
    file read `fh' line
    local expected_version = word(`"`line'"', 4)
    local expected_date = word(`"`line'"', 5)
    file close `fh'
    file open `manifest' using "`pkg_dir'/tabtools.pkg", read text
    file read `manifest' line
    local bad = 0
    local seen = 0
    while r(eof) == 0 {
        if regexm(`"`line'"', "^f ([^ ]+[.]ado)$") {
            local source = regexs(1)
            file open `fh' using "`pkg_dir'/`source'", read text
            file read `fh' header
            file close `fh'
            local ++seen
            if word(`"`header'"', 4) != "`expected_version'" | ///
                word(`"`header'"', 5) != "`expected_date'" {
                display as error "Header mismatch: `source'"
                local ++bad
            }
        }
        file read `manifest' line
    }
    file close `manifest'
    assert `seen' > 0
    assert `bad' == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F7 every manifest ado shares flagship version and date"
}
else {
    local ++fail_count
    display as error "FAIL: F7 every manifest ado shares flagship version and date (rc=`=_rc')"
}

**# F2 nuisance coefficients cannot fill another treatment row
capture noisily {
    _review_data
    generate byte tr2 = mod(floor(_n/2), 2)
    replace y = y + 0.3*tr2
    quietly collect: teffects ipw (y) (tr x), control(1)
    quietly collect: teffects ipw (y) (tr2 x i.tr)
    tempname b t
    matrix `b' = e(b)
    local ate = `b'[1, colnumb(`b', "ATE:r1vs0.tr2")]
    quietly effecttab, digits(6) frame(f2n, replace)
    frame f2n: count if strtrim(A) == "1.tr" & strtrim(c4) == ""
    assert r(N) == 1
    frame f2n: count if strtrim(A) == "r1vs0.tr2" & abs(real(c4) - `ate') < 5.1e-7
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F2 nuisance coefficients cannot fill another treatment row"
}
else {
    local ++fail_count
    display as error "FAIL: F2 nuisance coefficients cannot fill another treatment row (rc=`=_rc')"
}

**# F6 explicit factor levels and interactions are exact
capture noisily {
    foreach spec in 2.grp 20.grp i.grp 2.grp#c.x {
        _review_data
        generate byte grp = cond(mod(_n,3) == 0, 20, cond(mod(_n,3) == 1, 1, 2))
        replace y = 2*x + 0.4*(grp==2) + 0.8*(grp==20) + cos(_n/3)
        quietly collect: regress y i.grp##c.x
        local b2 = _b[2.grp]
        local b20 = _b[20.grp]
        local bx2 = _b[2.grp#c.x]
        quietly regtab, keep(`spec') nointercept digits(6) frame(ffv, replace)
        if "`spec'" == "2.grp" {
            frame ffv: count if (strtrim(A) == "20" | strpos(A, "20.grp#"))
            assert r(N) == 0
            frame ffv: count if strtrim(A) == "2" & abs(real(c1) - `b2') < 5.1e-7
            assert r(N) == 1
        }
        if "`spec'" == "20.grp" {
            frame ffv: count if strtrim(A) == "2"
            assert r(N) == 0
            frame ffv: count if strtrim(A) == "20" & abs(real(c1) - `b20') < 5.1e-7
            assert r(N) == 1
        }
        if "`spec'" == "i.grp" {
            frame ffv: count if strtrim(A) == "2" & abs(real(c1) - `b2') < 5.1e-7
            assert r(N) == 1
            frame ffv: count if strtrim(A) == "20" & abs(real(c1) - `b20') < 5.1e-7
            assert r(N) == 1
        }
        if "`spec'" == "2.grp#c.x" {
            tempname t
            matrix `t' = r(table)
            assert rowsof(`t') == 1
            assert abs(`t'[1,1] - `bx2') < 5.1e-7
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F6 explicit factor levels and interactions are exact"
}
else {
    local ++fail_count
    display as error "FAIL: F6 explicit factor levels and interactions are exact (rc=`=_rc')"
}

**# F3 long raw names sharing a label stay separate
capture noisily {
    _review_data
    local n1 "abcdefghijklmnopqrstuvwxyzaaaaa1"
    local n2 "abcdefghijklmnopqrstuvwxyzaaaaa2"
    rename x `n1'
    generate double `n2' = cos(_n)
    label variable `n1' "Repeated label"
    label variable `n2' "Repeated label"
    quietly collect: regress y `n1' `n2'
    local expected = _b[`n2']
    quietly regtab, keep(`n2') nointercept digits(6)
    tempname t
    matrix `t' = r(table)
    assert rowsof(`t') == 1
    assert abs(`t'[1,1] - `expected') < 5.1e-7
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F3 long raw names sharing a label stay separate"
}
else {
    local ++fail_count
    display as error "FAIL: F3 long raw names sharing a label stay separate (rc=`=_rc')"
}

**# F6 label matching is explicit and varabbrev survives errors
capture noisily {
    _review_data
    label variable x "Fuel efficiency"
    quietly collect: regress y x
    set varabbrev on
    capture quietly regtab, keep(Fuel) nointercept
    assert _rc == 198
    assert c(varabbrev) == "on"
    quietly regtab, keep(Fuel) labelmatch nointercept frame(flabel, replace)
    assert c(varabbrev) == "on"
    frame flabel: count if strtrim(A) == "Fuel efficiency"
    assert r(N) == 1
    capture quietly regtab, labelmatch
    assert _rc == 198
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F6 label matching is explicit and varabbrev survives errors"
}
else {
    local ++fail_count
    display as error "FAIL: F6 label matching is explicit and varabbrev survives errors (rc=`=_rc')"
}

**# F1 F5 workbook Markdown and CSV retain the same treatment rows
capture noisily {
    foreach cleared in 0 1 {
        _review_data
        quietly collect: teffects ipw (y) (tr x), control(1)
        tempname b fh
        matrix `b' = e(b)
        local ate = `b'[1, colnumb(`b', "ATE:r0vs1.tr")]
        local label "Control vs Treatment"
        if `cleared' {
            clear
            local label "Tr (0 vs 1)"
        }
        tempfile base check
        quietly effecttab, clean digits(6) frame(fsinks, replace) ///
            xlsx("`base'.xlsx") sheet(Effects) csv("`base'.csv") markdown("`base'.md")
        frame fsinks: count if strtrim(A) == "`label'" & abs(real(c1) - `ate') < 5.1e-7
        assert r(N) == 1
        preserve
        import excel using "`base'.xlsx", sheet(Effects) clear allstring
        generate long rownum = _n
        quietly summarize rownum if strtrim(B) == "`label'", meanonly
        assert r(N) == 1
        local rr = r(min)
        assert abs(real(C[`rr']) - `ate') < 5.1e-7
        restore
        shell python3 "`pkg_dir'/qa/tools/check_xlsx.py" "`base'.xlsx" --sheet Effects --cell B`rr' "`label'" --cell-approx C`rr' `ate' 0.00000051 --result-file "`check'" --quiet
        file open `fh' using "`check'", read text
        file read `fh' result
        file close `fh'
        assert "`result'" == "PASS"
        file open `fh' using "`base'.md", read text
        file read `fh' line
        local found = 0
        while r(eof) == 0 {
            if strpos(`"`line'"', "`label'") local ++found
            assert strpos(`"`line'"', char(92)+"3") == 0
            file read `fh' line
        }
        file close `fh'
        assert `found' == 1
        preserve
        import delimited using "`base'.csv", clear varnames(nonames) stringcols(_all)
        count if v1 == "`label'" & abs(real(v2) - `ate') < 5.1e-7
        assert r(N) == 1
        restore
        erase "`base'.xlsx"
        erase "`base'.csv"
        erase "`base'.md"
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F1 F5 workbook Markdown and CSV retain the same treatment rows"
}
else {
    local ++fail_count
    display as error "FAIL: F1 F5 workbook Markdown and CSV retain the same treatment rows (rc=`=_rc')"
}

local total = `pass_count' + `fail_count'
display "RESULT: test_review_2026_09_15 tests=`total' pass=`pass_count' fail=`fail_count' skip=0"
log close review0915
if `fail_count' exit 1
