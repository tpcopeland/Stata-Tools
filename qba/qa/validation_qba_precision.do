*! validation_qba_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_qba_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0

**# misclass OR nearone cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1.2345678912344999) b(0.99999998099999998) c(1.2345678912344999) d(0.99999999912344995) seca(1) spca(1) type(outcome) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    quietly qba_misclass, a(1.2345678912344999) b(0.99999998099999998) c(1.2345678912344999) d(0.99999999912344995) seca(1) spca(1) type(outcome) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000181234503))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(a_corr) & abs(a_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass OR nearone cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass OR nearone cell-scale 1"
}

**# misclass OR nearone cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1234571.5949381737) b(1000002.980999943) c(1234571.5949381737) d(1000002.9991234473) seca(1) spca(1) type(outcome) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    quietly qba_misclass, a(1234571.5949381737) b(1000002.980999943) c(1234571.5949381737) d(1000002.9991234473) seca(1) spca(1) type(outcome) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000181234503))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(a_corr) & abs(a_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass OR nearone cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass OR nearone cell-scale 1000003"
}

**# selection OR nearone cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(0.15241578780672002) b(0.74999998575000004) c(0.98765431298759998) d(0.99999998012345004) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    quietly qba_selection, a(0.15241578780672002) b(0.74999998575000004) c(0.98765431298759998) d(0.99999998012345004) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000181234503))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(a_corr) & abs(a_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection OR nearone cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection OR nearone cell-scale 1"
}

**# selection OR nearone cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(152416.24505408344) b(750002.23574995727) c(987657.27595053893) d(1000002.9801233904) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    quietly qba_selection, a(152416.24505408344) b(750002.23574995727) c(987657.27595053893) d(1000002.9801233904) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000181234503))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(a_corr) & abs(a_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection OR nearone cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection OR nearone cell-scale 1000003"
}

**# multi OR nearone cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(0.15241578780672002) b(0.74999998575000004) c(0.98765431298759998) d(0.99999998012345004) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000181234503))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(a_corr) & abs(a_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi OR nearone cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi OR nearone cell-scale 1"
}

**# multi OR nearone cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(152416.24505408344) b(750002.23574995727) c(987657.27595053893) d(1000002.9801233904) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000181234503))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.0000000181234503)<=max(1e-25,1e-12*abs(1.0000000181234503))
    assert !missing(a_corr) & abs(a_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi OR nearone cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi OR nearone cell-scale 1000003"
}

**# misclass RR nearone cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1.2345678912344999) b(0.99999998099999998) c(1.2345678912344999) d(0.99999999912344995) seca(1) spca(1) type(outcome) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    quietly qba_misclass, a(1.2345678912344999) b(0.99999998099999998) c(1.2345678912344999) d(0.99999999912344995) seca(1) spca(1) type(outcome) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000090617251))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(a_corr) & abs(a_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass RR nearone cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass RR nearone cell-scale 1"
}

**# misclass RR nearone cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1234571.5949381737) b(1000002.980999943) c(1234571.5949381737) d(1000002.9991234473) seca(1) spca(1) type(outcome) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    quietly qba_misclass, a(1234571.5949381737) b(1000002.980999943) c(1234571.5949381737) d(1000002.9991234473) seca(1) spca(1) type(outcome) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000090617251))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(a_corr) & abs(a_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass RR nearone cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass RR nearone cell-scale 1000003"
}

**# selection RR nearone cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(0.15241578780672002) b(0.74999998575000004) c(0.98765431298759998) d(0.99999998012345004) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    quietly qba_selection, a(0.15241578780672002) b(0.74999998575000004) c(0.98765431298759998) d(0.99999998012345004) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000090617251))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(a_corr) & abs(a_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection RR nearone cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection RR nearone cell-scale 1"
}

**# selection RR nearone cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(152416.24505408344) b(750002.23574995727) c(987657.27595053893) d(1000002.9801233904) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    quietly qba_selection, a(152416.24505408344) b(750002.23574995727) c(987657.27595053893) d(1000002.9801233904) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000090617251))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(a_corr) & abs(a_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection RR nearone cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection RR nearone cell-scale 1000003"
}

**# multi RR nearone cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(0.15241578780672002) b(0.74999998575000004) c(0.98765431298759998) d(0.99999998012345004) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000090617251))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(a_corr) & abs(a_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.99999999912344995)<=max(1e-25,1e-12*abs(0.99999999912344995))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi RR nearone cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi RR nearone cell-scale 1"
}

**# multi RR nearone cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(152416.24505408344) b(750002.23574995727) c(987657.27595053893) d(1000002.9801233904) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.0000000090617251))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.0000000090617251)<=max(1e-25,1e-12*abs(1.0000000090617251))
    assert !missing(a_corr) & abs(a_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-1000002.9991234473)<=max(1e-25,1e-12*abs(1000002.9991234473))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi RR nearone cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi RR nearone cell-scale 1000003"
}

**# misclass OR tiny cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1.2345678912345e-12) b(0.99999998099999998) c(1.2345678912344999) d(0.12345678912345) seca(1) spca(1) type(outcome) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    quietly qba_misclass, a(1.2345678912345e-12) b(0.99999998099999998) c(1.2345678912344999) d(0.12345678912345) seca(1) spca(1) type(outcome) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(a_corr) & abs(a_corr-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass OR tiny cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass OR tiny cell-scale 1"
}

**# misclass OR tiny cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1.2345715949381738e-06) b(1000002.980999943) c(1234571.5949381737) d(123457.15949381737) seca(1) spca(1) type(outcome) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    quietly qba_misclass, a(1.2345715949381738e-06) b(1000002.980999943) c(1234571.5949381737) d(123457.15949381737) seca(1) spca(1) type(outcome) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(a_corr) & abs(a_corr-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass OR tiny cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass OR tiny cell-scale 1000003"
}

**# selection OR tiny cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(1.5241578780672001e-13) b(0.74999998575000004) c(0.98765431298759998) d(0.12345678677777101) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    quietly qba_selection, a(1.5241578780672001e-13) b(0.74999998575000004) c(0.98765431298759998) d(0.12345678677777101) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(a_corr) & abs(a_corr-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection OR tiny cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection OR tiny cell-scale 1"
}

**# selection OR tiny cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(1.5241624505408345e-07) b(750002.23574995727) c(987657.27595053893) d(123457.15714813134) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    quietly qba_selection, a(1.5241624505408345e-07) b(750002.23574995727) c(987657.27595053893) d(123457.15714813134) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(a_corr) & abs(a_corr-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection OR tiny cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection OR tiny cell-scale 1000003"
}

**# multi OR tiny cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(1.5241578780672001e-13) b(0.74999998575000004) c(0.98765431298759998) d(0.12345678677777101) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(a_corr) & abs(a_corr-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi OR tiny cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi OR tiny cell-scale 1"
}

**# multi OR tiny cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(1.5241624505408345e-07) b(750002.23574995727) c(987657.27595053893) d(123457.15714813134) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or)
    assert abs(corrected_or-1.2345679146912903e-13)<=max(1e-25,1e-12*abs(1.2345679146912903e-13))
    assert !missing(a_corr) & abs(a_corr-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi OR tiny cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi OR tiny cell-scale 1000003"
}

**# misclass RR tiny cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1.2345678912345e-12) b(0.99999998099999998) c(1.2345678912344999) d(0.12345678912345) seca(1) spca(1) type(outcome) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    quietly qba_misclass, a(1.2345678912345e-12) b(0.99999998099999998) c(1.2345678912344999) d(0.12345678912345) seca(1) spca(1) type(outcome) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(a_corr) & abs(a_corr-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass RR tiny cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass RR tiny cell-scale 1"
}

**# misclass RR tiny cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_misclass, a(1.2345715949381738e-06) b(1000002.980999943) c(1234571.5949381737) d(123457.15949381737) seca(1) spca(1) type(outcome) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    quietly qba_misclass, a(1.2345715949381738e-06) b(1000002.980999943) c(1234571.5949381737) d(123457.15949381737) seca(1) spca(1) type(outcome) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(a_corr) & abs(a_corr-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: misclass RR tiny cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass RR tiny cell-scale 1000003"
}

**# selection RR tiny cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(1.5241578780672001e-13) b(0.74999998575000004) c(0.98765431298759998) d(0.12345678677777101) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    quietly qba_selection, a(1.5241578780672001e-13) b(0.74999998575000004) c(0.98765431298759998) d(0.12345678677777101) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(a_corr) & abs(a_corr-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection RR tiny cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection RR tiny cell-scale 1"
}

**# selection RR tiny cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_selection, a(1.5241624505408345e-07) b(750002.23574995727) c(987657.27595053893) d(123457.15714813134) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR)
    assert !missing(r(corrected)) & abs(r(corrected)-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(r(corrected_a)) & abs(r(corrected_a)-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(r(corrected_b)) & abs(r(corrected_b)-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(r(corrected_c)) & abs(r(corrected_c)-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(r(corrected_d)) & abs(r(corrected_d)-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    quietly qba_selection, a(1.5241624505408345e-07) b(750002.23574995727) c(987657.27595053893) d(123457.15714813134) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(a_corr) & abs(a_corr-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: selection RR tiny cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection RR tiny cell-scale 1000003"
}

**# multi RR tiny cell-scale 1
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(1.5241578780672001e-13) b(0.74999998575000004) c(0.98765431298759998) d(0.12345678677777101) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(a_corr) & abs(a_corr-1.2345678912345e-12)<=max(1e-25,1e-12*abs(1.2345678912345e-12))
    assert !missing(b_corr) & abs(b_corr-0.99999998099999998)<=max(1e-25,1e-12*abs(0.99999998099999998))
    assert !missing(c_corr) & abs(c_corr-1.2345678912344999)<=max(1e-25,1e-12*abs(1.2345678912344999))
    assert !missing(d_corr) & abs(d_corr-0.12345678912345)<=max(1e-25,1e-12*abs(0.12345678912345))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi RR tiny cell-scale 1; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi RR tiny cell-scale 1"
}

**# multi RR tiny cell-scale 1000003
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_multi, a(1.5241624505408345e-07) b(750002.23574995727) c(987657.27595053893) d(123457.15714813134) sela(0.12345678912345) selb(0.75) selc(0.80000000000000004) seld(0.99999998099999998) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    foreach result in corrected mean ci_lower ci_upper {
        assert !missing(r(`result')) & abs(r(`result')-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    }
    assert !missing(r(sd)) & abs(r(sd))<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr)
    assert abs(corrected_rr-1.1234567914680055e-12)<=max(1e-25,1e-12*abs(1.1234567914680055e-12))
    assert !missing(a_corr) & abs(a_corr-1.2345715949381738e-06)<=max(1e-25,1e-12*abs(1.2345715949381738e-06))
    assert !missing(b_corr) & abs(b_corr-1000002.980999943)<=max(1e-25,1e-12*abs(1000002.980999943))
    assert !missing(c_corr) & abs(c_corr-1234571.5949381737)<=max(1e-25,1e-12*abs(1234571.5949381737))
    assert !missing(d_corr) & abs(d_corr-123457.15949381737)<=max(1e-25,1e-12*abs(123457.15949381737))
    erase "`draws'"
}
if _rc {
    local ++fail
    display as error "FAIL: multi RR tiny cell-scale 1000003; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi RR tiny cell-scale 1000003"
}

**# confound OR precise saved ratio
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_confound, estimate(0.99999998099999998) p1(0.12345678912345) p0(1.2345678912345e-12) rrcd(1.2345678912344999) measure(OR)
    assert !missing(r(corrected),r(bias_factor))
    assert abs(r(corrected)-0.97185600425280461)<1e-12
    assert abs(r(bias_factor)-1.0289589986829721)<1e-12
    quietly qba_confound, estimate(0.99999998099999998) p1(0.12345678912345) p0(1.2345678912345e-12) rrcd(1.2345678912344999) measure(OR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    assert !missing(r(corrected)) & abs(r(corrected)-0.97185600425280461)<1e-12
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_or,bias_factor,p1,p0,rr_confounder)
    assert abs(corrected_or-0.97185600425280461)<1e-12
    assert abs(bias_factor-1.0289589986829721)<1e-12
    assert abs(p1-0.12345678912345)<1e-14 & abs(p0-1.2345678912345e-12)<1e-24
    assert abs(rr_confounder-1.2345678912344999)<1e-14
    erase "`draws'"

}
if _rc {
    local ++fail
    display as error "FAIL: confound OR precise saved ratio; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: confound OR precise saved ratio"
}

**# confound RR precise saved ratio
local ++tests
capture noisily {
    clear
    set obs 1
    tempfile draws
    quietly qba_confound, estimate(0.99999998099999998) p1(0.12345678912345) p0(1.2345678912345e-12) rrcd(1.2345678912344999) measure(RR)
    assert !missing(r(corrected),r(bias_factor))
    assert abs(r(corrected)-0.97185600425280461)<1e-12
    assert abs(r(bias_factor)-1.0289589986829721)<1e-12
    quietly qba_confound, estimate(0.99999998099999998) p1(0.12345678912345) p0(1.2345678912345e-12) rrcd(1.2345678912344999) measure(RR) reps(100) seed(37) saving("`draws'", replace)
    assert r(reps)==100 & r(n_valid)==100
    assert !missing(r(corrected)) & abs(r(corrected)-0.97185600425280461)<1e-12
    use "`draws'", clear
    assert _N==100
    assert !missing(corrected_rr,bias_factor,p1,p0,rr_confounder)
    assert abs(corrected_rr-0.97185600425280461)<1e-12
    assert abs(bias_factor-1.0289589986829721)<1e-12
    assert abs(p1-0.12345678912345)<1e-14 & abs(p0-1.2345678912345e-12)<1e-24
    assert abs(rr_confounder-1.2345678912344999)<1e-14
    erase "`draws'"

}
if _rc {
    local ++fail
    display as error "FAIL: confound RR precise saved ratio; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: confound RR precise saved ratio"
}

display "RESULT: validation_qba_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
