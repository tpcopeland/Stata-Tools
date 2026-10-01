*! validation_dataqa_writer_precision.do -- proposed focused numerical writer adapter
*! Author: Timothy P Copeland, Karolinska Institutet
* Unreviewed and unrun; private proposal, not registered.
version 16.0
clear all
set more off
capture log close _all
log using "validation_dataqa_writer_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
import json,math
from sfi import Macro,Data
_dataqa_writer_truth=json.loads((Path.cwd()/'tools'/'dataqa_writer_oracles.json').read_text())
end

**# dataqa compare exact tiny baseline relative drift flags
local ++tests
capture noisily {
    clear
    set obs 1
    generate double x=1.2345678912345e-12
    tempfile ledger baseline current
    quietly datacheck, gatesonly stat(mean x 0 1) ledger("`ledger'",run(fx)) name(precise)
    assert r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0
    use "`ledger'",clear
    assert _N==1 & family=="stat" & label=="mean x" & masked==0 & obs_masked==0
    * Author raw comparison inputs independently; upstream stat transport is
    * covered separately. Signature/key/row-scope stay identical across files.
    replace signature=""
    replace observed_num=1.2345678912345e-12
    assert observed_num==1.2345678912345e-12
    save "`baseline'"
    forvalues scenario=1/2 {
        use "`baseline'",clear
        python: Data.store('observed_num',None,[_dataqa_writer_truth['currents'][int(Macro.getLocal('scenario'))-1]])
        python: assert Data.getAt('observed_num',0)==_dataqa_writer_truth['currents'][int(Macro.getLocal('scenario'))-1]
        save "`current'",replace
        quietly dataqa compare using "`current'",run(fx) baseledger("`baseline'") baseline(fx) stattol(1e-12)
        assert r(n_flags)==`scenario'-1
    }
    erase "`ledger'"
    erase "`baseline'"
    erase "`current'"
}
if _rc {
    local ++fail
    display as error "FAIL: dataqa compare exact tiny baseline relative drift flags; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: dataqa compare exact tiny baseline relative drift flags"
}

**# groupstat valid masked raw double ledger export
local ++tests
capture noisily {
    clear
    set obs 4
    generate byte g=cond(_n<=2,1,2)
    generate double x=.
    replace x=1.2345678912345e-12 in 1
    replace x=1.9e-12 in 2
    replace x=9.8765432198764995e-12 in 3
    replace x=1.2345678912345e-11 in 4
    tempfile ledger exported
    expand 5
    assert _N==20
    capture noisily datacheck, gatesonly maskrare mincell(5) groupstat(mean x, by(g) band(0 0)) ledger("`ledger'",run(fx)) name(precise)
    local result=_rc
    assert `result'==9
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local exported_path `"`r(saving)'"'
    use "`exported_path'",clear
    assert _N==3 & family=="groupstat" & label=="mean x" & masked==1 & mincell==5 & obs_masked==0 & n_scope==20
    quietly count if status=="review"
    assert r(N)==1
    assert missing(observed_num) if status=="review"
    quietly count if status=="fail"
    assert r(N)==2
    forvalues group=1/2 {
        quietly count if status=="fail" & grp=="by(g) = `group'"
        assert r(N)==1
        python: Macro.setLocal('target',repr(_dataqa_writer_truth['group_means'][int(Macro.getLocal('group'))-1])); Macro.setLocal('bound',repr(max(1e-25,32*math.ulp(_dataqa_writer_truth['group_means'][int(Macro.getLocal('group'))-1]))))
        assert !missing(observed_num) & abs(observed_num-`target')<=`bound' if status=="fail" & grp=="by(g) = `group'"
    }
    erase "`ledger'"
    erase "`exported_path'"
}
if _rc {
    local ++fail
    display as error "FAIL: groupstat valid masked raw double ledger export; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: groupstat valid masked raw double ledger export"
}

display "RESULT: validation_dataqa_writer_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
