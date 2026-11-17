* crossval_qba_published_greenland-1996.do -- reproduce Greenland (1996) worked examples
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do crossval_qba_published_greenland-1996.do
*
* Published reproduction. Every target below is a number printed in
* Greenland S. Basic methods for sensitivity analysis of biases. Int J
* Epidemiol 1996;25:1107-1116, computed by the author, not by this package.
* Data: the resins-lung cancer table (Table 1): exposed cases 45, unexposed
* cases 94, exposed controls 257, unexposed controls 945 (crude OR 1.76).
* Targets are compared at the precision the paper prints.

clear all
set linesize 255

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* _g96_printed <value> <published string>: value rounded to the number of
* decimals the published string shows equals the published value
capture program drop _g96_printed
program define _g96_printed
    args value published
    local dot = strpos("`published'", ".")
    local dec = cond(`dot' > 0, strlen("`published'") - `dot', 0)
    assert !missing(`value')
    assert abs(round(`value', 10^(-`dec')) - `published') < 1e-9
end

**# G1: external adjustment for confounding, p.1109
local ++test_count
capture noisily {
    * Greenland's worked example: P_Z1 = 0.70, P_Z0 = 0.50, OR_DZ = 5
    * gives the externally adjusted OR_DX = 1.39 (p.1109).
    local crude = (45 * 945) / (94 * 257)
    _g96_printed `crude' 1.76
    qba_confound, estimate(`crude') measure(OR) p1(.7) p0(.5) rrcd(5)
    _g96_printed r(corrected) 1.39
    local qba_or = r(corrected)
    * Greenland's own cell reconstruction, eq. (1)-(2) p.1108, computed here
    * independently of the bias factor: B11 = P_Z1*B1+, A11 = OR*A1+*B11 /
    * (OR*B11 + B1+ - B11); the stratum Z=1 odds ratio is A11*B01/(B11*A01).
    local B11 = .7 * 257
    local B01 = .5 * 945
    local A11 = 5 * 45 * `B11' / (5 * `B11' + 257 - `B11')
    local A01 = 5 * 94 * `B01' / (5 * `B01' + 945 - `B01')
    _g96_printed `B11' 179.9
    _g96_printed `A11' 41.45
    _g96_printed `A01' 78.33
    local or_z1 = (`A11' * `B01') / (`B11' * `A01')
    local or_z0 = ((45 - `A11') * (945 - `B01')) / ((257 - `B11') * (94 - `A01'))
    * the two strata agree, and agree with the bias-factor result exactly
    assert !missing(`or_z1') & !missing(`or_z0') & reldif(`or_z1', `or_z0') < 1e-12
    assert !missing(`qba_or') & !missing(`or_z1') & reldif(`qba_or', `or_z1') < 1e-12
    * rrud() is the same bias factor
    qba_confound, estimate(`crude') measure(OR) p1(.7) p0(.5) rrud(5)
    assert !missing(r(corrected)) & !missing(`qba_or') & reldif(r(corrected), `qba_or') < 1e-14
}
if _rc == 0 {
    display as result "  PASS: G1 external adjustment 1.39 (p.1109)"
    local ++pass_count
}
else {
    display as error "  FAIL: G1 external adjustment (error `=_rc')"
    local ++fail_count
}

**# G2: differential exposure misclassification worked example, p.1111
local ++test_count
capture noisily {
    * cases Se = 0.9, Sp = 0.8; controls Se = 0.8, Sp = 0.8
    qba_misclass, a(45) b(94) c(257) d(945) seca(.9) spca(.8) ///
        secb(.8) spcb(.8) type(exposure)
    _g96_printed r(corrected_a) 24.57
    _g96_printed r(corrected_b) 114.43
    _g96_printed r(corrected_c) 27.67
    _g96_printed r(corrected_d) 1174.33
    _g96_printed r(corrected) 9.1
    _g96_printed r(observed) 1.8
}
if _rc == 0 {
    display as result "  PASS: G2 corrected cells and OR 9.1 (p.1111)"
    local ++pass_count
}
else {
    display as error "  FAIL: G2 misclassification example (error `=_rc')"
    local ++fail_count
}

**# G3: Table 4 corrected ORs over case x control (Se, Sp), p.1111
local ++test_count
capture noisily {
    * Rows: case (Se, Sp); columns: control (Se, Sp), each in the order
    * (.9,.9) (.8,.9) (.9,.8) (.8,.8). Published values from Table 4.
    local se_list .9 .8 .9 .8
    local sp_list .9 .9 .8 .8
    local row1 2.34 2.00 19.3 16.5
    local row2 2.83 2.42 23.3 19.9
    local row3 1.29 1.11 10.7 9.1
    local row4 1.57 1.34 12.9 11.0
    local n_checked = 0
    forvalues i = 1/4 {
        local se1 : word `i' of `se_list'
        local sp1 : word `i' of `sp_list'
        forvalues j = 1/4 {
            local se0 : word `j' of `se_list'
            local sp0 : word `j' of `sp_list'
            local pub : word `j' of `row`i''
            quietly qba_misclass, a(45) b(94) c(257) d(945) ///
                seca(`se1') spca(`sp1') secb(`se0') spcb(`sp0') type(exposure)
            _g96_printed r(corrected) `pub'
            local ++n_checked
        }
    }
    assert `n_checked' == 16
}
if _rc == 0 {
    display as result "  PASS: G3 Table 4, 16/16 corrected ORs"
    local ++pass_count
}
else {
    display as error "  FAIL: G3 Table 4 (error `=_rc')"
    local ++fail_count
}

**# G4: selection-bias factor, eq. (10) p.1114
local ++test_count
capture noisily {
    * eq. (10): corrected OR = observed OR / [S_A1*S_B0 / (S_A0*S_B1)];
    * the paper prints the formula, not a numeric example, so the target is
    * eq. (10) evaluated here on Table 1 with illustrative probabilities.
    local obs = (45 * 945) / (94 * 257)
    local sbf = (.8 * .5) / (.6 * .7)
    qba_selection, a(45) b(94) c(257) d(945) sela(.8) selb(.6) selc(.7) seld(.5)
    assert !missing(r(bias_factor)) & !missing(`sbf') & reldif(r(bias_factor), `sbf') < 1e-14
    assert !missing(r(corrected)) & !missing(`obs' / `sbf') & reldif(r(corrected), `obs' / `sbf') < 1e-12
    * no bias iff the factor is 1: S_Aj = t_A*U_j, S_Bj = t_B*U_j (p.1115)
    qba_selection, a(45) b(94) c(257) d(945) sela(.9) selb(.6) selc(.3) seld(.2)
    assert !missing(r(bias_factor)) & !missing(1) & reldif(r(bias_factor), 1) < 1e-14
    assert !missing(r(corrected)) & !missing(`obs') & reldif(r(corrected), `obs') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: G4 selection-bias factor eq. (10)"
    local ++pass_count
}
else {
    display as error "  FAIL: G4 selection-bias factor (error `=_rc')"
    local ++fail_count
}

display as result "Greenland (1996) reproduction: `pass_count'/`test_count' passed, `fail_count' failed"
capture ado uninstall qba
if `fail_count' > 0 {
    display "RESULT: crossval_qba_published_greenland-1996 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display "RESULT: crossval_qba_published_greenland-1996 tests=`test_count' pass=`pass_count' fail=`fail_count'"
