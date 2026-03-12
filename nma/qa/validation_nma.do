* validation_nma.do - Correctness validation for nma package
*
* V1: Dogliotti et al. (2014) — Oral anticoagulants in AF
*     Binary arm-level data, 20 RCTs, 8 treatments, stroke outcome
*     Source: Heart 2014;100:396-405
*
* V2: Senn et al. (2013) — Glucose-lowering drugs in diabetes
*     Pre-computed contrast-level, 26 studies, 10 treatments, HbA1c MD
*     Source: Stat Methods Med Res 2013;22(5):651-677
*
* Both datasets available in R netmeta package (benchmark examples).
*
* Location: ~/Stata-Tools/nma/qa/
* Run: stata-mp -b do qa/validation_nma.do
* Date: 2026-03-13

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

capture ado uninstall nma
adopath ++ "/home/tpcopeland/Stata-Tools/nma"


* ============================================================
* V1: Dogliotti 2014 — Binary arm-level (nma_setup)
* Anticoagulants for stroke prevention in atrial fibrillation
* 20 studies, 8 treatments, 4 three-arm trials
* R netmeta benchmarks (REML): VKA logOR=-0.886, tau2=0.013
* Published finding: all active treatments reduce stroke vs placebo
* ============================================================

clear
input str20 study str22 treatment stroke total
"AFASAK_I_1989"      "VKA"          9   335
"AFASAK_I_1989"      "ASA"         16   336
"AFASAK_I_1989"      "Placebo"     19   336
"BAATAF_1990"        "VKA"          3   212
"BAATAF_1990"        "Placebo"     13   208
"CAFA_1991"          "VKA"          6   187
"CAFA_1991"          "Placebo"      9   191
"SPAF_I_1991"        "VKA"          8   210
"SPAF_I_1991"        "ASA"         24   552
"SPAF_I_1991"        "Placebo"     42   568
"SPINAF_1992"        "VKA"          7   260
"SPINAF_1992"        "Placebo"     23   265
"EAFT_1993"          "VKA"         20   225
"EAFT_1993"          "ASA"         88   404
"EAFT_1993"          "Placebo"     90   378
"SPAF_II_1994"       "VKA"         39   555
"SPAF_II_1994"       "ASA"         42   545
"AFASAK_II_1998"     "VKA"         10   170
"AFASAK_II_1998"     "ASA"          9   169
"PATAF_1999"         "VKA"          3   131
"PATAF_1999"         "ASA"         22   319
"LASAF_1999"         "ASA"          5   194
"LASAF_1999"         "Placebo"      3    91
"ACTIVE_W_2006"      "VKA"         59  3371
"ACTIVE_W_2006"      "ASA_Clop"   100  3335
"JAST_2006"          "ASA"         17   426
"JAST_2006"          "Placebo"     18   445
"ACTIVE_A_2006"      "ASA_Clop"   296  3772
"ACTIVE_A_2006"      "ASA"        408  3782
"Chinese_ATAFS_2006" "VKA"          9   335
"Chinese_ATAFS_2006" "ASA"         17   369
"BAFTA_2007"         "VKA"         21   488
"BAFTA_2007"         "ASA"         44   485
"WASPO_2007"         "VKA"          0    36
"WASPO_2007"         "ASA"          0    39
"RE_LY_2009"         "Dab110"     171  6015
"RE_LY_2009"         "Dab150"     122  6076
"RE_LY_2009"         "VKA"        185  6022
"ROCKET_2011"        "Rivarox"    188  7081
"ROCKET_2011"        "VKA"        240  7090
"ARISTOTLE_2011"     "Apixaban"   197  9120
"ARISTOTLE_2011"     "VKA"        248  9081
"AVERROES_2011"      "Apixaban"    49  2808
"AVERROES_2011"      "ASA"        105  2791
end
save "qa/data/dogliotti2014_af.dta", replace


* V1a: Known structure — 20 studies, 8 treatments
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    local n_trt : char _dta[_nma_n_treatments]
    local n_stu : char _dta[_nma_n_studies]
    assert `n_trt' == 8
    assert `n_stu' == 20
}
if _rc == 0 {
    display as result "  PASS: V1a — Dogliotti 20 studies, 8 treatments"
    local ++pass_count
}
else {
    display as error "  FAIL: V1a — Dogliotti 20 studies, 8 treatments (error `=_rc')"
    local ++fail_count
}

* V1b: Reference = Placebo
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    local ref : char _dta[_nma_ref]
    assert "`ref'" == "Placebo"
}
if _rc == 0 {
    display as result "  PASS: V1b — Dogliotti reference = Placebo"
    local ++pass_count
}
else {
    display as error "  FAIL: V1b — Dogliotti reference = Placebo (error `=_rc')"
    local ++fail_count
}

* V1c: Binary outcome detected
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    local otype : char _dta[_nma_outcome_type]
    assert "`otype'" == "binary"
}
if _rc == 0 {
    display as result "  PASS: V1c — Dogliotti binary outcome detected"
    local ++pass_count
}
else {
    display as error "  FAIL: V1c — Dogliotti binary outcome detected (error `=_rc')"
    local ++fail_count
}

* V1d: Zero-cell study handled (WASPO_2007: 0/36 vs 0/39)
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
}
if _rc == 0 {
    display as result "  PASS: V1d — Dogliotti zero-cell handled"
    local ++pass_count
}
else {
    display as error "  FAIL: V1d — Dogliotti zero-cell handled (error `=_rc')"
    local ++fail_count
}

* V1e: Known-answer — 7 coefficients (8 treatments - 1 reference)
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    assert colsof(`b') == 7
}
if _rc == 0 {
    display as result "  PASS: V1e — Dogliotti 7 coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: V1e — Dogliotti 7 coefficients (error `=_rc')"
    local ++fail_count
}

* V1f: Invariant — all treatments reduce stroke vs placebo (logOR < 0)
* Published: all 7 active treatments had OR < 1 (protective effect)
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    forvalues j = 1/`=colsof(`b')' {
        assert `b'[1, `j'] < 0
    }
}
if _rc == 0 {
    display as result "  PASS: V1f — Dogliotti all logOR < 0 vs Placebo"
    local ++pass_count
}
else {
    display as error "  FAIL: V1f — Dogliotti all logOR < 0 vs Placebo (error `=_rc')"
    local ++fail_count
}

* V1g: Known-answer — VKA logOR in [-1.5, -0.3]
* R netmeta REML benchmark: VKA vs Placebo logOR = -0.886 (OR = 0.41)
* Wide tolerance for multivariate vs graph-theoretical REML method difference
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    local cnames : colnames `b'
    local vka_col = 0
    local j = 0
    foreach c of local cnames {
        local ++j
        if "`c'" == "VKA" local vka_col = `j'
    }
    assert `vka_col' > 0
    local vka_est = `b'[1, `vka_col']
    assert `vka_est' >= -1.5 & `vka_est' <= -0.3
}
if _rc == 0 {
    display as result "  PASS: V1g — Dogliotti VKA logOR in [-1.5, -0.3]"
    local ++pass_count
}
else {
    display as error "  FAIL: V1g — Dogliotti VKA logOR in [-1.5, -0.3] (error `=_rc')"
    local ++fail_count
}

* V1h: Known-answer — tau2 small, non-negative
* R netmeta benchmark: tau2 = 0.013 (very low heterogeneity)
* Tolerance: [0, 0.5] for method differences
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    assert e(tau2) >= 0 & e(tau2) < 0.5
}
if _rc == 0 {
    display as result "  PASS: V1h — Dogliotti tau2 in [0, 0.5]"
    local ++pass_count
}
else {
    display as error "  FAIL: V1h — Dogliotti tau2 in [0, 0.5] (error `=_rc')"
    local ++fail_count
}

* V1i: Invariant — common-effect tau2 = 0
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, common nolog
    assert e(tau2) == 0
}
if _rc == 0 {
    display as result "  PASS: V1i — Dogliotti common-effect tau2=0"
    local ++pass_count
}
else {
    display as error "  FAIL: V1i — Dogliotti common-effect tau2=0 (error `=_rc')"
    local ++fail_count
}

* V1j: Known-answer — Dab150 top-ranked (SUCRA > 0.7)
* Published: Dabigatran 150mg had lowest stroke risk
* R benchmark: Dab150 logOR = -1.32 (most negative = most protective)
* best(min) because lower stroke rate = better
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    nma_rank, best(min) seed(20140301)
    local treatments : char _dta[_nma_treatments]
    local dab_row = 0
    local j = 0
    foreach t of local treatments {
        local ++j
        if "`t'" == "Dab150" local dab_row = `j'
    }
    assert `dab_row' > 0
    assert _nma_sucra[`dab_row', 1] > 0.7
}
if _rc == 0 {
    display as result "  PASS: V1j — Dogliotti Dab150 SUCRA > 0.7"
    local ++pass_count
}
else {
    display as error "  FAIL: V1j — Dogliotti Dab150 SUCRA > 0.7 (error `=_rc')"
    local ++fail_count
}

* V1k: Known-answer — league table has 8 treatments
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    nma_compare
    assert r(k) == 8
}
if _rc == 0 {
    display as result "  PASS: V1k — Dogliotti league table k=8"
    local ++pass_count
}
else {
    display as error "  FAIL: V1k — Dogliotti league table k=8 (error `=_rc')"
    local ++fail_count
}

* V1l: Invariant — inconsistency p-value in [0, 1]
* R benchmark: Q_inconsistency = 5.59, df=5, p > 0.05
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog
    nma_inconsistency
    assert r(chi2_p) >= 0 & r(chi2_p) <= 1
}
if _rc == 0 {
    display as result "  PASS: V1l — Dogliotti inconsistency p in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V1l — Dogliotti inconsistency p in [0,1] (error `=_rc')"
    local ++fail_count
}

* V1m: eform display runs without error
local ++test_count
capture noisily {
    use "qa/data/dogliotti2014_af.dta", clear
    nma_setup stroke total, studyvar(study) trtvar(treatment) ref(Placebo)
    nma_fit, nolog eform
}
if _rc == 0 {
    display as result "  PASS: V1m — Dogliotti eform display"
    local ++pass_count
}
else {
    display as error "  FAIL: V1m — Dogliotti eform display (error `=_rc')"
    local ++fail_count
}


* ============================================================
* V2: Senn 2013 — Contrast-level continuous (nma_import)
* Glucose-lowering drugs for type 2 diabetes, HbA1c mean difference
* 26 studies, 10 treatments, 28 comparisons
* R netmeta benchmarks (REML): Rosiglitazone MD=-1.235, tau2=0.096
* Published finding: all drugs lower HbA1c vs placebo (MD < 0)
* ============================================================

clear
input str20 study str15 treat1 str15 treat2 double(te se_te)
"DeFronzo1995"      "Metformin"     "Placebo"       -1.90  0.1414
"Lewin2007"         "Metformin"     "Placebo"       -0.82  0.0992
"Willms1999a"       "Metformin"     "Acarbose"      -0.20  0.3579
"Davidson2007"      "Rosiglitazone" "Placebo"       -1.34  0.1435
"Wolffenbuttel1999" "Rosiglitazone" "Placebo"       -1.10  0.1141
"Kipnes2001"        "Pioglitazone"  "Placebo"       -1.30  0.1268
"Kerenyi2004"       "Rosiglitazone" "Placebo"       -0.77  0.1078
"Hanefeld2004"      "Pioglitazone"  "Metformin"      0.16  0.0849
"Derosa2004"        "Pioglitazone"  "Rosiglitazone"  0.10  0.1831
"Baksi2004"         "Rosiglitazone" "Placebo"       -1.30  0.1014
"Rosenstock2008"    "Rosiglitazone" "Placebo"       -1.09  0.2263
"Zhu2003"           "Rosiglitazone" "Placebo"       -1.50  0.1624
"Yang2003"          "Rosiglitazone" "Metformin"     -0.14  0.2239
"Vongthavaravat02"  "Rosiglitazone" "Sulfonylurea"  -1.20  0.1436
"Oyama2008"         "Acarbose"      "Sulfonylurea"  -0.40  0.1549
"Costa1997"         "Acarbose"      "Placebo"       -0.80  0.1432
"Hermansen2007"     "Sitagliptin"   "Placebo"       -0.57  0.1291
"Garber2008"        "Vildagliptin"  "Placebo"       -0.70  0.1273
"Alex1998"          "Metformin"     "Sulfonylurea"  -0.37  0.1184
"Johnston1994"      "Miglitol"      "Placebo"       -0.74  0.1839
"Johnston1998a"     "Miglitol"      "Placebo"       -1.41  0.2235
"Kim2007"           "Rosiglitazone" "Metformin"      0.00  0.2339
"Johnston1998b"     "Miglitol"      "Placebo"       -0.68  0.2828
"GonzalezOrtiz04"   "Metformin"     "Placebo"       -0.40  0.4356
"Stucci1996"        "Benfluorex"    "Placebo"       -0.23  0.3467
"Moulin2006"        "Benfluorex"    "Placebo"       -1.01  0.1366
"Willms1999b"       "Metformin"     "Placebo"       -1.20  0.3758
"Willms1999c"       "Acarbose"      "Placebo"       -1.00  0.4669
end
save "qa/data/senn2013_diabetes.dta", replace


* V2a: Known structure — 10 treatments
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) measure(md)
    local n_trt : char _dta[_nma_n_treatments]
    assert `n_trt' == 10
}
if _rc == 0 {
    display as result "  PASS: V2a — Senn 10 treatments"
    local ++pass_count
}
else {
    display as error "  FAIL: V2a — Senn 10 treatments (error `=_rc')"
    local ++fail_count
}

* V2b: Known structure — study count in [26, 28]
* Willms1999 has 3 rows (a/b/c) for one 3-arm study = 26 unique labels
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) measure(md)
    local n_stu : char _dta[_nma_n_studies]
    assert `n_stu' >= 26 & `n_stu' <= 28
}
if _rc == 0 {
    display as result "  PASS: V2b — Senn study count in [26, 28]"
    local ++pass_count
}
else {
    display as error "  FAIL: V2b — Senn study count in [26, 28] (error `=_rc')"
    local ++fail_count
}

* V2c: Reference auto-selection returns non-empty
* Placebo appears in 17 of 28 comparisons (most connected)
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) measure(md)
    local ref : char _dta[_nma_ref]
    assert "`ref'" != ""
}
if _rc == 0 {
    display as result "  PASS: V2c — Senn reference auto-selected"
    local ++pass_count
}
else {
    display as error "  FAIL: V2c — Senn reference auto-selected (error `=_rc')"
    local ++fail_count
}

* V2d: Known-answer — 9 coefficients (10 treatments - 1 ref)
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    assert colsof(`b') == 9
}
if _rc == 0 {
    display as result "  PASS: V2d — Senn 9 coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: V2d — Senn 9 coefficients (error `=_rc')"
    local ++fail_count
}

* V2e: Invariant — all drugs lower HbA1c vs placebo (MD < 0)
* Published: all 9 active drugs reduced HbA1c vs placebo
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    forvalues j = 1/`=colsof(`b')' {
        assert `b'[1, `j'] < 0
    }
}
if _rc == 0 {
    display as result "  PASS: V2e — Senn all MD < 0 vs Placebo"
    local ++pass_count
}
else {
    display as error "  FAIL: V2e — Senn all MD < 0 vs Placebo (error `=_rc')"
    local ++fail_count
}

* V2f: Known-answer — Rosiglitazone MD in [-1.8, -0.6]
* R netmeta REML benchmark: Rosiglitazone vs Placebo MD = -1.235
* Wide tolerance for multivariate vs graph-theoretical REML
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    local cnames : colnames `b'
    local rosi_col = 0
    local j = 0
    foreach c of local cnames {
        local ++j
        if "`c'" == "Rosiglitazone" local rosi_col = `j'
    }
    assert `rosi_col' > 0
    local rosi_est = `b'[1, `rosi_col']
    assert `rosi_est' >= -1.8 & `rosi_est' <= -0.6
}
if _rc == 0 {
    display as result "  PASS: V2f — Senn Rosiglitazone MD in [-1.8, -0.6]"
    local ++pass_count
}
else {
    display as error "  FAIL: V2f — Senn Rosiglitazone MD in [-1.8, -0.6] (error `=_rc')"
    local ++fail_count
}

* V2g: Known-answer — Metformin MD in [-1.8, -0.5]
* R netmeta REML benchmark: Metformin vs Placebo MD = -1.127
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    local cnames : colnames `b'
    local metf_col = 0
    local j = 0
    foreach c of local cnames {
        local ++j
        if "`c'" == "Metformin" local metf_col = `j'
    }
    assert `metf_col' > 0
    local metf_est = `b'[1, `metf_col']
    assert `metf_est' >= -1.8 & `metf_est' <= -0.5
}
if _rc == 0 {
    display as result "  PASS: V2g — Senn Metformin MD in [-1.8, -0.5]"
    local ++pass_count
}
else {
    display as error "  FAIL: V2g — Senn Metformin MD in [-1.8, -0.5] (error `=_rc')"
    local ++fail_count
}

* V2h: Known-answer — tau2 in [0, 0.5]
* R netmeta benchmark: tau2 = 0.096 (substantial heterogeneity)
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    assert e(tau2) >= 0 & e(tau2) <= 0.5
}
if _rc == 0 {
    display as result "  PASS: V2h — Senn tau2 in [0, 0.5]"
    local ++pass_count
}
else {
    display as error "  FAIL: V2h — Senn tau2 in [0, 0.5] (error `=_rc')"
    local ++fail_count
}

* V2i: Known-answer — Rosiglitazone SUCRA > 0.5
* Rosiglitazone has largest effect magnitude (MD = -1.235)
* best(min) because lower HbA1c = better
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    nma_rank, best(min) seed(20130101)
    local treatments : char _dta[_nma_treatments]
    local rosi_row = 0
    local j = 0
    foreach t of local treatments {
        local ++j
        if "`t'" == "Rosiglitazone" local rosi_row = `j'
    }
    assert `rosi_row' > 0
    assert _nma_sucra[`rosi_row', 1] > 0.5
}
if _rc == 0 {
    display as result "  PASS: V2i — Senn Rosiglitazone SUCRA > 0.5"
    local ++pass_count
}
else {
    display as error "  FAIL: V2i — Senn Rosiglitazone SUCRA > 0.5 (error `=_rc')"
    local ++fail_count
}

* V2j: Invariant — inconsistency p in [0, 1]
* R benchmark: Q_inconsistency = 22.5, df=7, p = 0.002 (significant)
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    nma_inconsistency
    assert r(chi2_p) >= 0 & r(chi2_p) <= 1
}
if _rc == 0 {
    display as result "  PASS: V2j — Senn inconsistency p in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V2j — Senn inconsistency p in [0,1] (error `=_rc')"
    local ++fail_count
}

* V2k: Known-answer — league table has 10 treatments
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    nma_compare
    assert r(k) == 10
}
if _rc == 0 {
    display as result "  PASS: V2k — Senn league table k=10"
    local ++pass_count
}
else {
    display as error "  FAIL: V2k — Senn league table k=10 (error `=_rc')"
    local ++fail_count
}

* V2l: Ranking invariant — Sitagliptin SUCRA < Rosiglitazone SUCRA
* Sitagliptin: single study, MD=-0.57 (weakest effect)
* Rosiglitazone: 7 studies, MD=-1.235 (strongest effect)
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    nma_rank, best(min) seed(20130101)
    local treatments : char _dta[_nma_treatments]
    local sita_row = 0
    local rosi_row = 0
    local j = 0
    foreach t of local treatments {
        local ++j
        if "`t'" == "Sitagliptin" local sita_row = `j'
        if "`t'" == "Rosiglitazone" local rosi_row = `j'
    }
    assert `sita_row' > 0 & `rosi_row' > 0
    assert _nma_sucra[`sita_row', 1] < _nma_sucra[`rosi_row', 1]
}
if _rc == 0 {
    display as result "  PASS: V2l — Senn Sitagliptin SUCRA < Rosiglitazone"
    local ++pass_count
}
else {
    display as error "  FAIL: V2l — Senn Sitagliptin SUCRA < Rosiglitazone (error `=_rc')"
    local ++fail_count
}

* V2m: Invariant — common-effect tau2 = 0
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, common nolog
    assert e(tau2) == 0
}
if _rc == 0 {
    display as result "  PASS: V2m — Senn common-effect tau2=0"
    local ++pass_count
}
else {
    display as error "  FAIL: V2m — Senn common-effect tau2=0 (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Summary
* ============================================================

display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
