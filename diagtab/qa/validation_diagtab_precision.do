*! validation_diagtab_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_diagtab_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _qa_fx_a1.do
do _qa_metamorphic.do

**# nearone precise cutoff classification, rank AUC and raw Wilson bounds
local ++tests
capture noisily {
    qa_fx_a1_diag, clear seed(37)
    replace score=0.99999998099620002 if xcat==1
    replace score=0.99999998099809995 if xcat==2
    replace score=0.99999998099999998 if xcat==3
    replace score=0.99999998100190002 if xcat==4
    replace score=0.99999998100379994 if xcat==5
    quietly diagtab score y, cutoff(0.99999998099999998) optimal auc digits(6)
    assert r(TP)==42 & r(FP)==18 & r(FN)==8 & r(TN)==32
    assert !missing(r(auc),r(optimal_cutoff))
    assert abs(r(auc)-0.81999999999999995)<1e-14
    assert r(optimal_cutoff)==0.99999998099999998
    quietly diagtab score y, cutoffs(0.99999998099809995 0.99999998099999998 0.99999998100190002) digits(6)
    tempname got
    matrix `got'=r(cutoff_table)
    assert rowsof(`got')==3 & colsof(`got')==15
    assert !missing(`got'[1,1]) & abs(`got'[1,1]-0.95999999999999996)<=7.1054273576010019e-15
    assert !missing(`got'[1,2]) & abs(`got'[1,2]-0.8653990931249298)<=7.1054273576010019e-15
    assert !missing(`got'[1,3]) & abs(`got'[1,3]-0.9889611156723801)<=7.1054273576010019e-15
    assert !missing(`got'[1,4]) & abs(`got'[1,4]-0.35999999999999999)<=3.5527136788005009e-15
    assert !missing(`got'[1,5]) & abs(`got'[1,5]-0.24138749651846739)<=1.7763568394002505e-15
    assert !missing(`got'[1,6]) & abs(`got'[1,6]-0.49858983123887302)<=3.5527136788005009e-15
    assert !missing(`got'[1,7]) & abs(`got'[1,7]-0.59999999999999998)<=7.1054273576010019e-15
    assert !missing(`got'[1,8]) & abs(`got'[1,8]-0.49045465005160399)<=3.5527136788005009e-15
    assert !missing(`got'[1,9]) & abs(`got'[1,9]-0.70038172404129062)<=7.1054273576010019e-15
    assert !missing(`got'[1,10]) & abs(`got'[1,10]-0.90000000000000002)<=7.1054273576010019e-15
    assert !missing(`got'[1,11]) & abs(`got'[1,11]-0.69896635477151281)<=7.1054273576010019e-15
    assert !missing(`got'[1,12]) & abs(`got'[1,12]-0.97213351878623189)<=7.1054273576010019e-15
    assert !missing(`got'[1,13]) & abs(`got'[1,13]-0.66000000000000003)<=7.1054273576010019e-15
    assert !missing(`got'[1,14]) & abs(`got'[1,14]-0.56277728854724629)<=7.1054273576010019e-15
    assert !missing(`got'[1,15]) & abs(`got'[1,15]-0.74538479202651831)<=7.1054273576010019e-15
    assert !missing(`got'[2,1]) & abs(`got'[2,1]-0.83999999999999997)<=7.1054273576010019e-15
    assert !missing(`got'[2,2]) & abs(`got'[2,2]-0.71485783936965008)<=7.1054273576010019e-15
    assert !missing(`got'[2,3]) & abs(`got'[2,3]-0.91662579321966597)<=7.1054273576010019e-15
    assert !missing(`got'[2,4]) & abs(`got'[2,4]-0.64000000000000001)<=7.1054273576010019e-15
    assert !missing(`got'[2,5]) & abs(`got'[2,5]-0.50141016876112698)<=7.1054273576010019e-15
    assert !missing(`got'[2,6]) & abs(`got'[2,6]-0.75861250348153253)<=7.1054273576010019e-15
    assert !missing(`got'[2,7]) & abs(`got'[2,7]-0.69999999999999996)<=7.1054273576010019e-15
    assert !missing(`got'[2,8]) & abs(`got'[2,8]-0.57491292053085519)<=7.1054273576010019e-15
    assert !missing(`got'[2,9]) & abs(`got'[2,9]-0.80101833861230887)<=7.1054273576010019e-15
    assert !missing(`got'[2,10]) & abs(`got'[2,10]-0.80000000000000004)<=7.1054273576010019e-15
    assert !missing(`got'[2,11]) & abs(`got'[2,11]-0.65242693653600514)<=7.1054273576010019e-15
    assert !missing(`got'[2,12]) & abs(`got'[2,12]-0.89500010274562292)<=7.1054273576010019e-15
    assert !missing(`got'[2,13]) & abs(`got'[2,13]-0.73999999999999999)<=7.1054273576010019e-15
    assert !missing(`got'[2,14]) & abs(`got'[2,14]-0.64629010550812815)<=7.1054273576010019e-15
    assert !missing(`got'[2,15]) & abs(`got'[2,15]-0.81595301535251863)<=7.1054273576010019e-15
    assert !missing(`got'[3,1]) & abs(`got'[3,1]-0.64000000000000001)<=7.1054273576010019e-15
    assert !missing(`got'[3,2]) & abs(`got'[3,2]-0.50141016876112698)<=7.1054273576010019e-15
    assert !missing(`got'[3,3]) & abs(`got'[3,3]-0.75861250348153253)<=7.1054273576010019e-15
    assert !missing(`got'[3,4]) & abs(`got'[3,4]-0.83999999999999997)<=7.1054273576010019e-15
    assert !missing(`got'[3,5]) & abs(`got'[3,5]-0.71485783936965008)<=7.1054273576010019e-15
    assert !missing(`got'[3,6]) & abs(`got'[3,6]-0.91662579321966597)<=7.1054273576010019e-15
    assert !missing(`got'[3,7]) & abs(`got'[3,7]-0.80000000000000004)<=7.1054273576010019e-15
    assert !missing(`got'[3,8]) & abs(`got'[3,8]-0.65242693653600514)<=7.1054273576010019e-15
    assert !missing(`got'[3,9]) & abs(`got'[3,9]-0.89500010274562292)<=7.1054273576010019e-15
    assert !missing(`got'[3,10]) & abs(`got'[3,10]-0.69999999999999996)<=7.1054273576010019e-15
    assert !missing(`got'[3,11]) & abs(`got'[3,11]-0.57491292053085519)<=7.1054273576010019e-15
    assert !missing(`got'[3,12]) & abs(`got'[3,12]-0.80101833861230887)<=7.1054273576010019e-15
    assert !missing(`got'[3,13]) & abs(`got'[3,13]-0.73999999999999999)<=7.1054273576010019e-15
    assert !missing(`got'[3,14]) & abs(`got'[3,14]-0.64629010550812815)<=7.1054273576010019e-15
    assert !missing(`got'[3,15]) & abs(`got'[3,15]-0.81595301535251863)<=7.1054273576010019e-15
    * Preserve raw precise literal tokens: the helper list(numlist) grammar
    * would itself render these thresholds; compare both native orderings directly.
    quietly diagtab score y, cutoffs(0.99999998100190002 0.99999998099999998 0.99999998099809995) digits(6)
    tempname reordered
    matrix `reordered'=r(cutoff_table)
    forvalues i=1/3 {
        forvalues j=1/15 {
            assert !missing(`reordered'[`i',`j']) & `reordered'[`i',`j']==`got'[`i',`j']
        }
    }

}
if _rc {
    local ++fail
    display as error "FAIL: nearone precise cutoff classification, rank AUC and raw Wilson bounds; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: nearone precise cutoff classification, rank AUC and raw Wilson bounds"
}

**# tiny precise cutoff classification, rank AUC and raw Wilson bounds
local ++tests
capture noisily {
    qa_fx_a1_diag, clear seed(37)
    replace score=1.2341878912344999e-12 if xcat==1
    replace score=1.2343778912345e-12 if xcat==2
    replace score=1.2345678912345e-12 if xcat==3
    replace score=1.2347578912345e-12 if xcat==4
    replace score=1.2349478912345e-12 if xcat==5
    quietly diagtab score y, cutoff(1.2345678912345e-12) optimal auc digits(6)
    assert r(TP)==42 & r(FP)==18 & r(FN)==8 & r(TN)==32
    assert !missing(r(auc),r(optimal_cutoff))
    assert abs(r(auc)-0.81999999999999995)<1e-14
    assert r(optimal_cutoff)==1.2345678912345e-12
    quietly diagtab score y, cutoffs(1.2343778912345e-12 1.2345678912345e-12 1.2347578912345e-12) digits(6)
    tempname got
    matrix `got'=r(cutoff_table)
    assert rowsof(`got')==3 & colsof(`got')==15
    assert !missing(`got'[1,1]) & abs(`got'[1,1]-0.95999999999999996)<=7.1054273576010019e-15
    assert !missing(`got'[1,2]) & abs(`got'[1,2]-0.8653990931249298)<=7.1054273576010019e-15
    assert !missing(`got'[1,3]) & abs(`got'[1,3]-0.9889611156723801)<=7.1054273576010019e-15
    assert !missing(`got'[1,4]) & abs(`got'[1,4]-0.35999999999999999)<=3.5527136788005009e-15
    assert !missing(`got'[1,5]) & abs(`got'[1,5]-0.24138749651846739)<=1.7763568394002505e-15
    assert !missing(`got'[1,6]) & abs(`got'[1,6]-0.49858983123887302)<=3.5527136788005009e-15
    assert !missing(`got'[1,7]) & abs(`got'[1,7]-0.59999999999999998)<=7.1054273576010019e-15
    assert !missing(`got'[1,8]) & abs(`got'[1,8]-0.49045465005160399)<=3.5527136788005009e-15
    assert !missing(`got'[1,9]) & abs(`got'[1,9]-0.70038172404129062)<=7.1054273576010019e-15
    assert !missing(`got'[1,10]) & abs(`got'[1,10]-0.90000000000000002)<=7.1054273576010019e-15
    assert !missing(`got'[1,11]) & abs(`got'[1,11]-0.69896635477151281)<=7.1054273576010019e-15
    assert !missing(`got'[1,12]) & abs(`got'[1,12]-0.97213351878623189)<=7.1054273576010019e-15
    assert !missing(`got'[1,13]) & abs(`got'[1,13]-0.66000000000000003)<=7.1054273576010019e-15
    assert !missing(`got'[1,14]) & abs(`got'[1,14]-0.56277728854724629)<=7.1054273576010019e-15
    assert !missing(`got'[1,15]) & abs(`got'[1,15]-0.74538479202651831)<=7.1054273576010019e-15
    assert !missing(`got'[2,1]) & abs(`got'[2,1]-0.83999999999999997)<=7.1054273576010019e-15
    assert !missing(`got'[2,2]) & abs(`got'[2,2]-0.71485783936965008)<=7.1054273576010019e-15
    assert !missing(`got'[2,3]) & abs(`got'[2,3]-0.91662579321966597)<=7.1054273576010019e-15
    assert !missing(`got'[2,4]) & abs(`got'[2,4]-0.64000000000000001)<=7.1054273576010019e-15
    assert !missing(`got'[2,5]) & abs(`got'[2,5]-0.50141016876112698)<=7.1054273576010019e-15
    assert !missing(`got'[2,6]) & abs(`got'[2,6]-0.75861250348153253)<=7.1054273576010019e-15
    assert !missing(`got'[2,7]) & abs(`got'[2,7]-0.69999999999999996)<=7.1054273576010019e-15
    assert !missing(`got'[2,8]) & abs(`got'[2,8]-0.57491292053085519)<=7.1054273576010019e-15
    assert !missing(`got'[2,9]) & abs(`got'[2,9]-0.80101833861230887)<=7.1054273576010019e-15
    assert !missing(`got'[2,10]) & abs(`got'[2,10]-0.80000000000000004)<=7.1054273576010019e-15
    assert !missing(`got'[2,11]) & abs(`got'[2,11]-0.65242693653600514)<=7.1054273576010019e-15
    assert !missing(`got'[2,12]) & abs(`got'[2,12]-0.89500010274562292)<=7.1054273576010019e-15
    assert !missing(`got'[2,13]) & abs(`got'[2,13]-0.73999999999999999)<=7.1054273576010019e-15
    assert !missing(`got'[2,14]) & abs(`got'[2,14]-0.64629010550812815)<=7.1054273576010019e-15
    assert !missing(`got'[2,15]) & abs(`got'[2,15]-0.81595301535251863)<=7.1054273576010019e-15
    assert !missing(`got'[3,1]) & abs(`got'[3,1]-0.64000000000000001)<=7.1054273576010019e-15
    assert !missing(`got'[3,2]) & abs(`got'[3,2]-0.50141016876112698)<=7.1054273576010019e-15
    assert !missing(`got'[3,3]) & abs(`got'[3,3]-0.75861250348153253)<=7.1054273576010019e-15
    assert !missing(`got'[3,4]) & abs(`got'[3,4]-0.83999999999999997)<=7.1054273576010019e-15
    assert !missing(`got'[3,5]) & abs(`got'[3,5]-0.71485783936965008)<=7.1054273576010019e-15
    assert !missing(`got'[3,6]) & abs(`got'[3,6]-0.91662579321966597)<=7.1054273576010019e-15
    assert !missing(`got'[3,7]) & abs(`got'[3,7]-0.80000000000000004)<=7.1054273576010019e-15
    assert !missing(`got'[3,8]) & abs(`got'[3,8]-0.65242693653600514)<=7.1054273576010019e-15
    assert !missing(`got'[3,9]) & abs(`got'[3,9]-0.89500010274562292)<=7.1054273576010019e-15
    assert !missing(`got'[3,10]) & abs(`got'[3,10]-0.69999999999999996)<=7.1054273576010019e-15
    assert !missing(`got'[3,11]) & abs(`got'[3,11]-0.57491292053085519)<=7.1054273576010019e-15
    assert !missing(`got'[3,12]) & abs(`got'[3,12]-0.80101833861230887)<=7.1054273576010019e-15
    assert !missing(`got'[3,13]) & abs(`got'[3,13]-0.73999999999999999)<=7.1054273576010019e-15
    assert !missing(`got'[3,14]) & abs(`got'[3,14]-0.64629010550812815)<=7.1054273576010019e-15
    assert !missing(`got'[3,15]) & abs(`got'[3,15]-0.81595301535251863)<=7.1054273576010019e-15
    * Preserve raw precise literal tokens: the helper list(numlist) grammar
    * would itself render these thresholds; compare both native orderings directly.
    quietly diagtab score y, cutoffs(1.2347578912345e-12 1.2345678912345e-12 1.2343778912345e-12) digits(6)
    tempname reordered
    matrix `reordered'=r(cutoff_table)
    forvalues i=1/3 {
        forvalues j=1/15 {
            assert !missing(`reordered'[`i',`j']) & `reordered'[`i',`j']==`got'[`i',`j']
        }
    }

}
if _rc {
    local ++fail
    display as error "FAIL: tiny precise cutoff classification, rank AUC and raw Wilson bounds; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: tiny precise cutoff classification, rank AUC and raw Wilson bounds"
}

display "RESULT: validation_diagtab_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
