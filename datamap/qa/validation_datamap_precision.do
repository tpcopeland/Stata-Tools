*! validation_datamap_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
* 2026-11-10 (datamap 2.0.0): JSON and datadict are removed; see the dated
* notes on tests 1 and 3.
version 16.0
clear all
set more off
capture log close _all
log using "validation_datamap_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
local tests 0
local pass 0
local fail 0
do _qa_fx_a7.do
**# Markdown statistics cells show tiny and large doubles at their scale
* 2026-11-10 (datamap 2.0.0): this was "JSON full stored double numerical
* summaries" (unrounded 17-digit JSON summaries checked in Python).  format(json)
* is removed; the unrounded values are asserted through saving() below.  What
* the Markdown cell owes is scale: a 1e-12 variable must not read 0 and a
* 1.2e12 mean must keep its integer digits.  Oracles: the values written into
* the fixture (mean of the four tiny values 6.339e-12, SD 5.608e-12; big mean
* 1234567891240.25, SD 7.325), rounded to the three significant digits the
* cell carries.
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    tempfile output
    quietly datamap, output("`output'") continuous(x tiny nearone big) mincell(0)
    assert r(nfiles)==1 & r(nobs)==4 & r(nvars)==5
    do "`c(pwd)'/_qa_md.do"
    qa_md_contains using "`output'", needle("N=4; mean=6.34e-12; SD=5.61e-12;")
    assert r(n)==1
    qa_md_contains using "`output'", needle("range=1.23e-12 to 1.23e-11")
    assert r(n)==1
    qa_md_contains using "`output'", needle("N=4; mean=1,234,567,891,240; SD=7.33;")
    assert r(n)==1
    qa_md_contains using "`output'", needle("N=4; mean=0.867; SD=1.08;")
    assert r(n)==1
    qa_md_contains using "`output'", needle("range=1.23e-12 to 2.35")
    assert r(n)==1
    erase "`output'"

}
if _rc {
    local ++fail
    display as error "FAIL: Markdown statistics cells show tiny and large doubles at their scale; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Markdown statistics cells show tiny and large doubles at their scale"
}

**# datamap exact numeric metadata double cells
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    tempfile output metadata
    quietly datamap, output("`output'") saving("`metadata'", replace) continuous(x tiny nearone big) mincell(0)
    use "`metadata'", clear
    format mean sd min max %21x
    noisily list variable mean sd min max, noobs
    assert _N==5
    quietly count if variable=="x"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.86728391783979608)<=3.5527136788005009e-15 if variable=="x"
    assert !missing(sd) & abs(sd-1.0814689812015226)<=7.1054273576010019e-15 if variable=="x"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="x"
    assert !missing(max) & abs(max-2.3456789012344998)<=1.4210854715202004e-14 if variable=="x"
    quietly count if variable=="tiny"
    assert r(N)==1
    assert !missing(mean) & abs(mean-6.3391975058640001e-12)<=1e-25 if variable=="tiny"
    assert !missing(sd) & abs(sd-5.6081592816617421e-12)<=1e-25 if variable=="tiny"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="tiny"
    assert !missing(max) & abs(max-1.2345678912345e-11)<=1e-25 if variable=="tiny"
    quietly count if variable=="nearone"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.99691358020277498)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(sd) & abs(sd-0.0061728388101025076)<=2.7755575615628914e-17 if variable=="nearone"
    assert !missing(min) & abs(min-0.98765432198765002)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(max) & abs(max-1.0000000187)<=7.1054273576010019e-15 if variable=="nearone"
    quietly count if variable=="big"
    assert r(N)==1
    assert !missing(mean) & abs(mean-1234567891240.25)<=0.0078125 if variable=="big"
    assert !missing(sd) & abs(sd-7.3250426619918061)<=2.8421709430404007e-14 if variable=="big"
    assert !missing(min) & abs(min-1234567891234.5)<=0.0078125 if variable=="big"
    assert !missing(max) & abs(max-1234567891250.625)<=0.0078125 if variable=="big"
    erase "`output'"
    erase "`metadata'"

}
if _rc {
    local ++fail
    display as error "FAIL: datamap exact numeric metadata double cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datamap exact numeric metadata double cells"
}

**# datamap exact numeric metadata double cells, compact document with a title
* 2026-11-10 (datamap 2.0.0): was the datadict twin of the test above (datadict
* is removed).  The same exact-value assertions now run through the document
* mode (title() and compact), so a second render path must write the same
* unrounded saving() table.
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    tempfile output metadata
    quietly datamap, output("`output'") saving("`metadata'", replace) continuous(x tiny nearone big) mincell(0) compact title("Precision")
    use "`metadata'", clear
    format mean sd min max %21x
    noisily list variable mean sd min max, noobs
    assert _N==5
    quietly count if variable=="x"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.86728391783979608)<=3.5527136788005009e-15 if variable=="x"
    assert !missing(sd) & abs(sd-1.0814689812015226)<=7.1054273576010019e-15 if variable=="x"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="x"
    assert !missing(max) & abs(max-2.3456789012344998)<=1.4210854715202004e-14 if variable=="x"
    quietly count if variable=="tiny"
    assert r(N)==1
    assert !missing(mean) & abs(mean-6.3391975058640001e-12)<=1e-25 if variable=="tiny"
    assert !missing(sd) & abs(sd-5.6081592816617421e-12)<=1e-25 if variable=="tiny"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="tiny"
    assert !missing(max) & abs(max-1.2345678912345e-11)<=1e-25 if variable=="tiny"
    quietly count if variable=="nearone"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.99691358020277498)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(sd) & abs(sd-0.0061728388101025076)<=2.7755575615628914e-17 if variable=="nearone"
    assert !missing(min) & abs(min-0.98765432198765002)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(max) & abs(max-1.0000000187)<=7.1054273576010019e-15 if variable=="nearone"
    quietly count if variable=="big"
    assert r(N)==1
    assert !missing(mean) & abs(mean-1234567891240.25)<=0.0078125 if variable=="big"
    assert !missing(sd) & abs(sd-7.3250426619918061)<=2.8421709430404007e-14 if variable=="big"
    assert !missing(min) & abs(min-1234567891234.5)<=0.0078125 if variable=="big"
    assert !missing(max) & abs(max-1234567891250.625)<=0.0078125 if variable=="big"
    erase "`output'"
    erase "`metadata'"

}
if _rc {
    local ++fail
    display as error "FAIL: datamap exact numeric metadata double cells, compact document; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datamap exact numeric metadata double cells, compact document"
}

**# dataprobe dataqa valid masked numeric ledger transport
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    * Genuine release-copy masking domain: five copies of each stored IEEE
    * value give twenty rows; means unchanged, sum and sampleSD rederived.
    expand 5
    assert _N==20
    tempfile ledger exported
    quietly dataprobe, gatesonly maskrare mincell(5) stat(mean x 0 3 \ sum tiny 0 1 \ sd nearone 0 1) ledger("`ledger'", run(precision)) name(precise)
    * Three stat entries belong to one evaluated gate family.
    assert r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0
    quietly dataqa export using "`ledger'", run(precision) saving("`exported'") threshold(5)
    local exported_path `"`r(saving)'"'
    use "`exported_path'", clear
    format observed_num %21x
    noisily list family label observed_num status masked, noobs
    assert _N==3 & family=="stat" & status=="pass" & masked==1 & mincell==5 & obs_masked==0 & n_scope==20
    quietly count if label=="mean x"
    assert r(N)==1
    assert !missing(observed_num) & abs(observed_num-0.86728391783979608)<=3.5527136788005009e-15 if label=="mean x"
    quietly count if label=="sum tiny"
    assert r(N)==1
    assert !missing(observed_num) & abs(observed_num-1.2678395011727999e-10)<=8.2718061255302767e-25 if label=="sum tiny"
    quietly count if label=="sd nearone"
    assert r(N)==1
    assert !missing(observed_num) & abs(observed_num-0.005484711212627987)<=2.7755575615628914e-17 if label=="sd nearone"
    erase "`ledger'"
    erase "`exported_path'"

}
if _rc {
    local ++fail
    display as error "FAIL: dataprobe dataqa valid masked numeric ledger transport; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: dataprobe dataqa valid masked numeric ledger transport"
}

**# datamvp nonterminating missingness counts
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    expand 2 if id==40
    generate double partial=1
    replace partial=. in 1
    tempfile patterns
    quietly datamvp x partial, nodrop save("`patterns'")
    assert r(N)==41 & r(N_complete)==40 & r(N_incomplete)==1 & r(N_patterns)==2
    assert !missing(r(mean_miss)) & abs(r(mean_miss)-1/41)<1e-15
    use "`patterns'",clear
    assert _N==2
    assert freq==40 & nmiss==0 & abs(percent-4000/41)<1e-12 if pattern=="++"
    assert freq==1 & nmiss==1 & abs(percent-100/41)<1e-12 if pattern=="+."
    quietly count if pattern=="++"
    assert r(N)==1
    quietly count if pattern=="+."
    assert r(N)==1
    erase "`patterns'"

}
if _rc {
    local ++fail
    display as error "FAIL: datamvp nonterminating missingness counts; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datamvp nonterminating missingness counts"
}

display "RESULT: validation_datamap_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
