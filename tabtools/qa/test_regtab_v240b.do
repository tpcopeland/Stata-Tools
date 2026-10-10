* test_regtab_v240b.do - regtab 2.4.0 development: user feedback, wave 2
* Covers, each on its happy path, its refusal paths, and a known answer:
*   E1  stats() e(name, %fmt) and e(name, fmt(%fmt)) display formats
*   E2  stats() e(name, mincell(#)) small-cell masking of statistic rows
*   E3  stats() e(name1|name2) combined rows "value1 (value2)"
*   E4  stats() text("label" value ...) per-model text rows
*   T1  transpose collabels(name "label" ...)
*   T2  transpose addcol(..., after(term))
*   D1  help file documents the new syntax; its example runs as displayed
* Every expected value comes from the fit's own e(), from scalars the test
* puts into the collection itself, or from the fixture's design.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv240b
log using "test_regtab_v240b.log", replace text name(_rv240b)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

* Trimmed cell of column `col' on the one row of frame `fr' whose trimmed
* label (variable `lv') is `label'.
capture program drop _vb_cell
program define _vb_cell, rclass
    version 17.0
    args fr lv label col
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(`lv') == `"`label'"'
        if r(N) != 1 {
            display as error `"frame `fr': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(`lv') == `"`label'"', meanonly
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

* Two stcox fits (everyone; drug != 3) with their e() kept for the oracle,
* and a test-owned result tt_vbz holding 0, 3, and (model 3) 7.
capture program drop _vb_fix
program define _vb_fix
    version 17.0
    sysuse cancer, clear
    quietly generate id = _n
    quietly stset studytime, failure(died) id(id)
    collect clear
    quietly collect: stcox i.drug age
    global VB_F1 = e(N_fail)
    global VB_S1 = e(N_sub)
    global VB_N1 = e(N)
    quietly collect get tt_vbz = (0), tags(cmdset[1])
    quietly collect: stcox i.drug age if drug != 3
    global VB_F2 = e(N_fail)
    global VB_S2 = e(N_sub)
    global VB_N2 = e(N)
    quietly collect get tt_vbz = (3), tags(cmdset[2])
    quietly collect get tt_vbone = (11), tags(cmdset[1])
end

**# E1 display formats
local ++test_count
capture noisily {
    _vb_fix
    regtab, stats(e(N_fail, %9.1f)="Failures" e(N, fmt(%9.0fc))="Rows") frame(_e1, replace)
    _vb_cell _e1 A "Failures" c1
    assert "`r(cell)'" == strtrim(string($VB_F1, "%9.1f"))
    _vb_cell _e1 A "Failures" c4
    assert "`r(cell)'" == strtrim(string($VB_F2, "%9.1f"))
    _vb_cell _e1 A "Rows" c1
    assert "`r(cell)'" == strtrim(string($VB_N1, "%9.0fc"))
    * default format unchanged: an integer with thousands separators
    regtab, stats(e(N_fail)) frame(_e1, replace)
    _vb_cell _e1 A "N_fail" c1
    assert "`r(cell)'" == strtrim(string($VB_F1, "%12.0fc"))
    * refusals
    foreach bad in "e(N, %bad)" "e(N, %td)" "e(N, fmt(%9s))" "e(N, %9.0f fmt(%9.1f))" ///
        "e(N, junk(1))" "e(N|)" "e(N, mincell(1))" "e(N) e(N)" {
        capture regtab, stats(`bad')
        if _rc != 198 {
            display as error "stats(`bad') returned `=_rc', not 198"
            exit 9
        }
    }
    * the same name with a different partner is a different row
    regtab, stats(e(N) e(N|N_sub)) frame(_e1, replace)
}
if _rc == 0 {
    display as result "  PASS: E1 e(name, %fmt) formats; malformed items refused"
    local ++pass_count
}
else {
    display as error "  FAIL: E1 e() formats (rc=`=_rc')"
    local ++fail_count
}

**# E2 mincell()
* tt_vbz is 0 in model 1 and 3 in model 2: with mincell(5), 0 stays 0 (a zero
* is not a small cell, as in tabcell and ratetab) and 3 prints "<5"; r() keeps
* the value; mincell(3) leaves 3 unmasked.
local ++test_count
capture noisily {
    _vb_fix
    regtab, stats(e(tt_vbz, mincell(5))="Z" e(N_fail, mincell(`=$VB_F2 + 1'))="F") frame(_e2, replace)
    assert r(N_stats_masked) == 2
    assert r(e_tt_vbz_1) == 0 & r(e_tt_vbz_2) == 3
    _vb_cell _e2 A "Z" c1
    assert "`r(cell)'" == "0"
    _vb_cell _e2 A "Z" c4
    assert "`r(cell)'" == "<5"
    _vb_cell _e2 A "F" c4
    assert "`r(cell)'" == "<`=$VB_F2 + 1'"
    _vb_cell _e2 A "F" c1
    assert "`r(cell)'" == strtrim(string($VB_F1, "%12.0fc"))
    regtab, stats(e(tt_vbz, mincell(3))="Z") frame(_e2, replace)
    assert r(N_stats_masked) == 0
    _vb_cell _e2 A "Z" c4
    assert "`r(cell)'" == "3"
    * no mincell(): no r(N_stats_masked)
    regtab, stats(e(tt_vbz))
    capture assert r(N_stats_masked) < .
    assert _rc
}
if _rc == 0 {
    display as result "  PASS: E2 mincell() masks 1..#-1 as <#; r() unmasked"
    local ++pass_count
}
else {
    display as error "  FAIL: E2 mincell() (rc=`=_rc')"
    local ++fail_count
}

**# E3 e(a|b)
local ++test_count
capture noisily {
    _vb_fix
    regtab, stats(e(N_fail|N_sub)="Events (subjects)" e(tt_vbz|tt_vbone, mincell(5))) frame(_e3, replace)
    assert r(e_N_fail_2) == $VB_F2 & r(e_N_sub_2) == $VB_S2
    _vb_cell _e3 A "Events (subjects)" c1
    assert "`r(cell)'" == strtrim(string($VB_F1, "%12.0fc")) + " (" + strtrim(string($VB_S1, "%12.0fc")) + ")"
    _vb_cell _e3 A "Events (subjects)" c4
    assert "`r(cell)'" == strtrim(string($VB_F2, "%12.0fc")) + " (" + strtrim(string($VB_S2, "%12.0fc")) + ")"
    * default label; a part masked alone; a missing second part leaves the first
    _vb_cell _e3 A "tt_vbz (tt_vbone)" c1
    assert "`r(cell)'" == "0 (11)"
    _vb_cell _e3 A "tt_vbz (tt_vbone)" c4
    assert "`r(cell)'" == "<5"
    * a missing first value leaves the cell blank, never "(b)"
    regtab, stats(e(tt_vbone|N_fail)) frame(_e3, replace)
    _vb_cell _e3 A "tt_vbone (N_fail)" c1
    assert "`r(cell)'" == "11 (" + strtrim(string($VB_F1, "%12.0fc")) + ")"
    _vb_cell _e3 A "tt_vbone (N_fail)" c4
    assert "`r(cell)'" == ""
}
if _rc == 0 {
    display as result "  PASS: E3 e(a|b) prints value1 (value2)"
    local ++pass_count
}
else {
    display as error "  FAIL: E3 e(a|b) (rc=`=_rc')"
    local ++fail_count
}

**# E4 text()
local ++test_count
capture noisily {
    _vb_fix
    regtab, stats(n text("Weighting" "Unweighted" "Inverse probability") e(N_fail)) frame(_e4, replace)
    _vb_cell _e4 A "Weighting" c1
    assert "`r(cell)'" == "Unweighted"
    _vb_cell _e4 A "Weighting" c4
    assert "`r(cell)'" == "Inverse probability"
    * order among the generic rows as given
    frame _e4 {
        generate long rn = _n
        quietly summarize rn if strtrim(A) == "Weighting", meanonly
        local rw = r(min)
        quietly summarize rn if strtrim(A) == "N_fail", meanonly
        assert r(min) == `rw' + 1
    }
    * compound quotes, bare words, fewer values than models
    regtab, stats(text(`"Arm "A""' x)) frame(_e4, replace)
    _vb_cell _e4 A `"Arm "A""' c1
    assert "`r(cell)'" == "x"
    _vb_cell _e4 A `"Arm "A""' c4
    assert "`r(cell)'" == ""
    capture regtab, stats(text("W" a b c))
    assert _rc == 198
    capture regtab, stats(text())
    assert _rc == 198
    * $name and a backquote are data: compared byte for byte in Mata
    global VB_HOMEX "EXPANDED"
    local tv = "US" + char(36) + "VB_HOMEX" + char(96) + "q" + char(39)
    regtab, stats(text("W" "`macval(tv)'")) addrow("L`macval(tv)'" "v`macval(tv)'") frame(_e4m, replace)
    frame _e4m {
        mata: st_local("ok1", strofreal(anyof(strtrim(st_sdata(., "c1")), st_local("tv"))))
        mata: st_local("ok2", strofreal(anyof(strtrim(st_sdata(., "A")), "L" + st_local("tv"))))
        mata: st_local("ok3", strofreal(anyof(strtrim(st_sdata(., "c1")), "v" + st_local("tv"))))
        mata: st_local("bad", strofreal(any(strpos(st_sdata(., "c1") + st_sdata(., "A"), "EXPANDED"))))
    }
    assert `ok1' & `ok2' & `ok3' & !`bad'
    * a column under transpose
    regtab, transpose stats(text("Weighting" None IPW)) frame(_e4t, replace)
    frame _e4t {
        assert strtrim(c1[2]) == "Weighting"
        assert strtrim(c1[4]) == "None" & strtrim(c1[5]) == "IPW"
    }
}
if _rc == 0 {
    display as result "  PASS: E4 text() rows, in order, transposed to a column"
    local ++pass_count
}
else {
    display as error "  FAIL: E4 text() (rc=`=_rc')"
    local ++fail_count
}

**# T1 collabels()
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    quietly collect: regress price mpg i.foreign weight
    regtab, transpose collabels(mpg "Mileage" 1.foreign "Imported") frame(_t1, replace)
    frame _t1 {
        assert strtrim(c1[2]) == "Mileage" & strtrim(c2[2]) == "Mileage"
        assert strtrim(c1[3]) != "" & strtrim(c2[3]) == "p-value"
        quietly count if _n == 2
        local hit = 0
        foreach v of varlist c* {
            if strtrim(`v'[2]) == "Imported" local ++hit
            assert strtrim(`v'[2]) != "Car origin: Foreign"
        }
        assert `hit' == 2
    }
    * multi-equation: every header keeps its equation; eq:name picks one
    collect clear
    quietly collect: mlogit rep78 mpg if rep78 >= 3
    regtab, transpose collabels(mpg "Miles") frame(_t1m, replace)
    frame _t1m {
        assert strtrim(c1[2]) == "4: Miles" & strtrim(c2[2]) == "4: Miles"
        assert strtrim(c3[2]) == "5: Miles" & strtrim(c4[2]) == "5: Miles"
    }
    regtab, transpose collabels(4:mpg "Miles") frame(_t1m, replace)
    frame _t1m {
        assert strtrim(c1[2]) == "4: Miles"
        assert strtrim(c3[2]) == "5: Mileage (mpg)"
    }
    capture regtab, transpose collabels(9:mpg "x")
    assert _rc == 198
    collect clear
    quietly collect: regress price mpg i.foreign
    quietly collect: regress price mpg i.foreign weight
    capture regtab, collabels(mpg "x")
    assert _rc == 198
    capture regtab, transpose collabels(nosuch "x")
    assert _rc == 198
    capture regtab, transpose collabels(mpg)
    assert _rc == 198
    capture regtab, transpose collabels(MPG "x")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T1 collabels() renames a term's transposed columns"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 collabels() (rc=`=_rc')"
    local ++fail_count
}

**# T2 addcol(..., after())
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    quietly collect: regress price mpg i.foreign weight
    regtab, transpose addcol("N1" a b, after(mpg) \ "End" x y \ "N2" c d, after(mpg)) frame(_t2, replace)
    frame _t2 {
        * mpg's estimate and p-value columns are c1 c2; the placed columns follow
        assert strtrim(c1[2]) == "Mileage (mpg)" & strtrim(c2[2]) == "Mileage (mpg)"
        assert strtrim(c3[2]) == "N1" & strtrim(c3[4]) == "a" & strtrim(c3[5]) == "b"
        assert strtrim(c4[2]) == "N2" & strtrim(c4[4]) == "c"
        unab cv : c*
        local last : word count `cv'
        assert strtrim(c`last'[2]) == "End" & strtrim(c`last'[5]) == "y"
        * the variables are in column order
        local want ""
        forvalues j = 1/`last' {
            local want "`want' c`j'"
        }
        assert "`cv'" == strtrim("`want'")
    }
    * nopvalue: one column per term
    regtab, transpose nopvalue addcol("N1" a b, after(mpg)) frame(_t2, replace)
    frame _t2: assert strtrim(c2[2]) == "N1"
    capture regtab, transpose addcol("x" 1, after(nosuch))
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2 addcol(after()) places transposed columns"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 addcol(after()) (rc=`=_rc')"
    local ++fail_count
}

**# V1 review fixes to wave 1 (base levels, after(), counts)
* V1a: nbreg with an omitted continuous term records the base as "empty"
* beside an "omit": the base (e(b) 1b.cohort, the factor's only constrained
* level) is the reference (2.3.1 printed Empty). An fvset base set after the
* fit does not describe it: the b. level of e(b) stays the reference (2.3.1
* printed Reference). ib(last).: the reference is the last level.
local ++test_count
capture noisily {
    webuse rod93, clear
    quietly generate c2 = 2 * exposure
    local l1 : label (cohort) 1
    local l3 : label (cohort) 3
    collect clear
    quietly collect: nbreg deaths i.cohort c2 exposure
    local cn : colnames e(b)
    assert strpos(" `cn' ", " 1b.cohort ") & strpos(" `cn' ", " o.exposure ")
    regtab, noint coef("IRR") frame(_v1, replace)
    _vb_cell _v1 A "`l1'" c1
    assert "`r(cell)'" == "Reference"
    frame _v1: quietly count if inlist(strtrim(c1), "Empty", "Reference")
    assert r(N) == 1
    collect clear
    quietly collect: nbreg deaths i.cohort, exposure(exposure)
    local cn : colnames e(b)
    assert strpos(" `cn' ", " 1b.cohort ")
    fvset base 3 cohort
    regtab, noint coef("IRR") frame(_v1, replace)
    fvset clear cohort
    _vb_cell _v1 A "`l1'" c1
    assert "`r(cell)'" == "Reference"
    _vb_cell _v1 A "`l3'" c1
    assert !inlist("`r(cell)'", "Reference", "Empty", "")
    collect clear
    quietly collect: nbreg deaths ib(last).cohort, exposure(exposure)
    local cn : colnames e(b)
    assert strpos(" `cn' ", " 3b.cohort ")
    regtab, noint coef("IRR") frame(_v1, replace)
    _vb_cell _v1 A "`l3'" c1
    assert "`r(cell)'" == "Reference"
    _vb_cell _v1 A "`l1'" c1
    assert !inlist("`r(cell)'", "Reference", "Empty", "")
}
if _rc == 0 {
    display as result "  PASS: V1a nbreg omitted term, later fvset, ib(last) base levels"
    local ++pass_count
}
else {
    display as error "  FAIL: V1a nbreg omitted term/fvset/ib(last) (rc=`=_rc')"
    local ++fail_count
}
* V1a (continued): the counterfeit twin. x = (g == 3) makes 3o.g a
* collinear level that is constrained like the base 1b.g; fvset base 3 g after
* the fit. With the fit active its e(b) decides: 1 Reference, 3 Omitted.
* After an unrelated fit only fvset names a base, so neither constrained
* level is called the reference (2.3.1 printed both as Reference).
local ++test_count
capture noisily {
    clear
    set seed 240
    quietly set obs 400
    quietly generate g = 1 + mod(_n, 3)
    quietly generate x = g == 3
    quietly generate z = rnormal()
    quietly generate y = rpoisson(exp(0.3 * z + 0.2 * (g == 2)))
    collect clear
    quietly collect: nbreg y x z i.g
    local cn : colnames e(b)
    assert strpos(" `cn' ", " 1b.g ") & strpos(" `cn' ", " 3o.g ")
    fvset base 3 g
    regtab, noint frame(_v1t, replace)
    _vb_cell _v1t A "1" c1
    assert "`r(cell)'" == "Reference"
    _vb_cell _v1t A "3" c1
    assert "`r(cell)'" == "Omitted"
    quietly regress z y
    regtab, noint notestlabel("NE") frame(_v1t, replace)
    fvset clear g
    _vb_cell _v1t A "1" c1
    assert "`r(cell)'" == "NE"
    _vb_cell _v1t A "3" c1
    assert "`r(cell)'" == "NE"
    frame _v1t: quietly count if strtrim(c1) == "Reference"
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: V1a counterfeit twin: with the fit active e(b) decides (1 Reference, 3 Omitted); after an unrelated fit only fvset names a base"
    local ++pass_count
}
else {
    display as error "  FAIL: V1a counterfeit twin base levels (rc=`=_rc')"
    local ++fail_count
}

* V1b: a command line typed with an abbreviation (i.coh) expands under the
* user's varabbrev (an unrelated fit after it, so the specification route
* decides): the collinear level 1o.dupc is Omitted, not a second reference,
* and the user's varabbrev survives.
local ++test_count
capture noisily {
    webuse rod93, clear
    quietly generate byte dupc = cohort == 2
    set varabbrev on
    collect clear
    quietly collect: nbreg deaths i.coh i.dupc, exposure(exposure)
    local cn : colnames e(b)
    quietly regress deaths exposure
    regtab, noint coef("IRR") notestlabel("NE") frame(_v2, replace)
    local va = c(varabbrev)
    set varabbrev off
    assert "`va'" == "on"
    assert strpos(" `cn' ", " 0b.dupc ") & strpos(" `cn' ", " 1o.dupc ")
    frame _v2 {
        generate long rn = _n
        quietly summarize rn if strtrim(A) == "dupc", meanonly
        local h = r(min)
        assert strtrim(A[`h' + 1]) == "0" & strtrim(c1[`h' + 1]) == "Reference"
        assert strtrim(A[`h' + 2]) == "1" & strtrim(c1[`h' + 2]) == "Omitted"
    }
}
if _rc == 0 {
    display as result "  PASS: V1b abbreviated e(cmdline) expands under the user's varabbrev"
    local ++pass_count
}
else {
    set varabbrev off
    display as error "  FAIL: V1b abbreviated cmdline (rc=`=_rc')"
    local ++fail_count
}

* V1c: after() takes keep()'s form (c. and level markers); a multi-equation
* table refuses after() of a term listed once per equation.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.foreign##c.mpg
    regtab, addrow("x" 1, after(1.foreign#c.mpg) \ "y" 2, after(1b.foreign)) frame(_v3, replace)
    frame _v3 {
        generate long rn = _n
        quietly summarize rn if strtrim(A) == "x", meanonly
        * 2.6.2: the interaction level is labelled from its components
        assert strtrim(A[r(min) - 1]) == "Foreign # Mileage (mpg)"
        quietly summarize rn if strtrim(A) == "y", meanonly
        assert strtrim(A[r(min) - 1]) == "Foreign"
    }
    regtab, transpose collabels(1.foreign#c.mpg "Slope diff") addcol("z" 1, after(1.foreign#c.mpg)) frame(_v3t, replace)
    frame _v3t {
        local hit = 0
        foreach v of varlist c* {
            if strtrim(`v'[2]) == "Slope diff" local last "`v'"
        }
        local j = real(substr("`last'", 2, .))
        assert strtrim(c`=`j' + 1'[2]) == "z"
    }
    collect clear
    quietly collect: mlogit rep78 i.foreign mpg
    capture regtab, addrow("x" 1, after(1.foreign))
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V1c after()/collabels() take keep()'s form; multi-equation refused"
    local ++pass_count
}
else {
    display as error "  FAIL: V1c after() keep() form (rc=`=_rc')"
    local ++fail_count
}

**# V2 review fixes, round 3
* V2a: eleven models. collect lists cmdset levels as 1 10 11 2 ...; every
* column must read its own model. Model 3 (x3 = g == 3: e(b) 1b.g 2.g 3o.g)
* keeps one reference; model 11, the active fit (x2 = g == 2: 1b.g 2o.g
* 3.g), shows its own markers; stats(e(N)) matches each model's n.
local ++test_count
capture noisily {
    clear
    set seed 2402
    quietly set obs 2200
    quietly generate ds = 1 + mod(_n, 11)
    quietly generate g = 1 + mod(floor(_n / 11), 3)
    quietly generate x3 = g == 3
    quietly generate x2 = g == 2
    quietly generate z = rnormal()
    quietly generate y = rpoisson(exp(0.3 * z + 0.2 * (g == 2)))
    collect clear
    forvalues k = 1/11 {
        local xv = cond(`k' == 11, "x2", "x3")
        quietly collect: nbreg y `xv' z i.g if ds == `k' & _n <= 1000 + 100 * `k'
        local N`k' = e(N)
        if `k' == 3 local cn3 : colnames e(b)
    }
    local cn11 : colnames e(b)
    assert strpos(" `cn3' ", " 1b.g ") & strpos(" `cn3' ", " 3o.g ")
    assert strpos(" `cn11' ", " 1b.g ") & strpos(" `cn11' ", " 2o.g ")
    regtab, noint compact nopvalue stats(n e(N)) frame(_v2a, replace)
    frame _v2a {
        generate long rn = _n
        quietly summarize rn if strtrim(A) == "g", meanonly
        local h = r(min)
        * model 3: column c3
        assert strtrim(c3[`h' + 1]) == "Reference"
        assert strtrim(c3[`h' + 3]) == "Omitted"
        assert !inlist(strtrim(c3[`h' + 2]), "Reference", "Omitted", "")
        * model 11: column c11
        assert strtrim(c11[`h' + 1]) == "Reference"
        assert strtrim(c11[`h' + 2]) == "Omitted"
        forvalues j = 1/11 {
            quietly count if _n > 2 & strtrim(c`j') == "Reference"
            assert r(N) == 1
            assert strtrim(c`j'[_N]) == strtrim(string(`N`j'', "%12.0fc"))
            assert strtrim(c`j'[_N - 1]) == strtrim(string(`N`j'', "%12.0fc"))
        }
    }
}
if _rc == 0 {
    display as result "  PASS: V2a eleven models: each column reads its own cmdset"
    local ++pass_count
}
else {
    display as error "  FAIL: V2a eleven models (rc=`=_rc')"
    local ++fail_count
}

* V2b: collabels() labels are data ($name, a backquote), compared in Mata.
* V2c: at most one reference per factor: the data no longer hold level 1 of
* the fit, so its base cannot be verified; levels 1 and 3 (3o.g) are not
* estimable rather than two references.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    global VB_HOMEX "EXPANDED"
    local cl = "Lab" + char(36) + "VB_HOMEX" + char(96) + "q" + char(39)
    regtab, transpose collabels(mpg "`macval(cl)'") frame(_v2b, replace)
    frame _v2b {
        mata: st_local("ok", strofreal(st_sdata(2, "c1") == st_local("cl")))
        mata: st_local("bad", strofreal(strpos(st_sdata(2, "c1"), "EXPANDED") > 0))
    }
    assert `ok' & !`bad'
    clear
    set seed 240
    quietly set obs 400
    quietly generate g = 1 + mod(_n, 3)
    quietly generate x = g == 3
    quietly generate z = rnormal()
    quietly generate y = rpoisson(exp(0.3 * z + 0.2 * (g == 2)))
    collect clear
    quietly collect: nbreg y x z i.g
    quietly regress z y
    quietly drop if g == 1
    regtab, noint notestlabel("NE") frame(_v2c, replace)
    frame _v2c {
        quietly count if strtrim(c1) == "Reference"
        assert r(N) == 0
        generate long rn = _n
        quietly summarize rn if strtrim(A) == "g", meanonly
        local h = r(min)
        assert strtrim(c1[`h' + 1]) == "NE" & strtrim(c1[`h' + 3]) == "NE"
    }
}
if _rc == 0 {
    display as result "  PASS: V2b/V2c collabels() data; one reference per factor at most"
    local ++pass_count
}
else {
    display as error "  FAIL: V2b/V2c (rc=`=_rc')"
    local ++fail_count
}

**# V3 user text is data in every option
* Each text option carries "$VB_HOMEX" and a backquote; read back in Mata,
* every cell holds it byte for byte and "EXPANDED" appears nowhere: models(),
* coef(), refcat(), cilabel(), plabel(), cutlabels(), cellnote(), title(),
* footnote() (CSV), statlabels(), omitlabel(), notestlabel(), emptylabel()
* (mincount), exposurelabel(), and the transposed estimate header.
local ++test_count
capture noisily {
    global VB_HOMEX "EXPANDED"
    local t = char(36) + "VB_HOMEX" + char(96) + "q" + char(39)
    local csvf "`qa_dir'/output/_rv240b_v3.csv"
    capture mkdir "`qa_dir'/output"
    capture erase "`csvf'"
    sysuse auto, clear
    collect clear
    quietly collect: ologit rep78 mpg i.foreign
    quietly collect: ologit rep78 mpg
    regtab, frame(_v3, replace) stats(n) statlabels(n "N`macval(t)'") ///
        models("M1`macval(t)' \ M2") coef("C`macval(t)'") refcat("R`macval(t)'") ///
        cilabel("CI`macval(t)'") plabel("P`macval(t)'") cutlabels("Cut`macval(t)' \ b \ c") ///
        title("T`macval(t)'") footnote("F`macval(t)'") csv("`csvf'") keepintercept ///
        cellnote("Mileage (mpg)" 2 "Note`macval(t)'")
    mata: st_local("rcl", st_global("r(coef_label)"))
    mata: st_local("ok", strofreal(st_local("rcl") == "C" + st_local("t")))
    assert `ok'
    local want "M1 C CI P R Cut Note N"
    frame _v3 {
        mata: _vb_S = st_sdata(., ("title", "A", "c1", "c2", "c3", "c4", "c5", "c6"))
        foreach w of local want {
            mata: st_local("ok", strofreal(any(strtrim(_vb_S) :== "`w'" + st_local("t"))))
            if !`ok' {
                display as error "V3: `w' + text not found"
                exit 9
            }
        }
        mata: st_local("ok", strofreal(any(strtrim(_vb_S) :== "T" + st_local("t"))))
        assert `ok'
        mata: st_local("bad", strofreal(any(strpos(_vb_S, "EXPANDED"))))
        assert !`bad'
    }
    mata: _vb_C = cat(st_local("csvf"))
    mata: st_local("ok", strofreal(any(strpos(_vb_C, "F" + st_local("t")))))
    mata: st_local("bad", strofreal(any(strpos(_vb_C, "EXPANDED"))))
    assert `ok' & !`bad'
    collect clear
    quietly collect: logit foreign mpg i.rep78
    regtab, omitlabel("O`macval(t)'") notestlabel("NT`macval(t)'") frame(_v3, replace)
    regtab, transpose coef("C`macval(t)'") frame(_v3t, replace)
    frame _v3t {
        mata: st_local("ok", strofreal(any(strtrim(st_sdata(., "c1")) :== "C" + st_local("t") + " (95% CI)")))
        assert `ok'
    }
    frame _v3 {
        mata: _vb_S = st_sdata(., "c1")
        mata: st_local("ok", strofreal(any(strtrim(_vb_S) :== "O" + st_local("t")) & any(strtrim(_vb_S) :== "NT" + st_local("t"))))
        assert `ok'
    }
    webuse drugtr, clear
    collect clear
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) exposure(_t) terms
    regtab, stats(exposure) exposurelabel("X`macval(t)'") mincount(50) emptylabel("Em`macval(t)'") frame(_v3, replace)
    frame _v3 {
        mata: _vb_S = st_sdata(., ("A", "c1"))
        mata: st_local("ok", strofreal(any(strtrim(_vb_S) :== "X" + st_local("t")) & any(strtrim(_vb_S) :== "Em" + st_local("t"))))
        mata: st_local("bad", strofreal(any(strpos(_vb_S, "EXPANDED"))))
        assert `ok' & !`bad'
    }
    capture mata: mata drop _vb_S _vb_C
}
if _rc == 0 {
    display as result "  PASS: V3 every user-text option is data (dollar sign, backquote)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 user text expanded (rc=`=_rc')"
    local ++fail_count
}

**# D1 help file
local ++test_count
capture noisily {
    mata: _h = invtokens(cat(st_local("pkg_dir") + "/regtab.sthlp")', " ")
    foreach w in "coll:abels(string asis)" "mincell(" "text(" "r(N_stats_masked)" "e(N_fail|N_sub)" {
        mata: st_local("hit", strofreal(strpos(_h, st_local("w")) > 0))
        assert `hit'
    }
    capture mata: mata drop _h
    * the help example, as displayed
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    quietly collect: regress price mpg i.foreign weight
    regtab, transpose keep(mpg 1.foreign) stats(e(N, %9.0fc)="N" text("Adjustment" "None" "Weight")) collabels(mpg "Mileage") addcol("Note" a b, after(mpg)) nopvalue
}
if _rc == 0 {
    display as result "  PASS: D1 help file documents wave-2 syntax; example runs"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 help file (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display "RESULT: test_regtab_v240b tests=`test_count' pass=`pass_count' fail=`fail_count'"
macro drop VB_*
capture tabtools set clear
log close _rv240b
if `fail_count' > 0 exit 1
