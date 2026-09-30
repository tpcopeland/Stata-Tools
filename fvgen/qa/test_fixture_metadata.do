*! test_fixture_metadata.do -- exact text/names, finite singleton and named refusals
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
args source_override
capture log close _all
log using "test_fixture_metadata.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
if "`source_override'"!="" adopath ++ "`source_override'"
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
capture program drop _qa_fv_text
program define _qa_fv_text
    version 16.0
    args corpus
    mata: st_local("text",st_global(st_local("corpus")))
    quietly fvgen, drop
    mata: st_varlabel("x",st_local("text")); assert(st_varlabel("x")==st_local("text"))
    quietly fvgen c.x, center prefix(text_)
    local generated "`r(genvars)'"
    assert `: word count `generated''==1
    local got : variable label `generated'
    mata: actual=st_local("got"); assert(substr(actual,strlen(actual)-10,.)==" (centered)"); st_global("QA_FV_GOT",substr(actual,1,strlen(actual)-11))
end
capture program drop _qa_fv_factor
program define _qa_fv_factor
    version 16.0
    args corpus
    mata: st_local("text",st_global(st_local("corpus")))
    quietly fvgen, drop
    local vl : value label group
    mata: st_vlmodify(st_local("vl"),(1\2),("BASE"\st_local("text"))); assert(st_vlmap(st_local("vl"),2)==st_local("text"))
    mata: st_varlabel("x","X")
    local suffix ""
    if "$QA_FV_MODE"=="factor" quietly fvgen i.group, prefix(text_)
    if "$QA_FV_MODE"=="vsref" {
        quietly fvgen i.group, prefix(text_) vsref("(vs. @)")
        local suffix " (vs. BASE)"
    }
    if "$QA_FV_MODE"=="interaction" {
        quietly fvgen i.group##c.x, prefix(text_)
        local suffix " × X"
    }
    if "$QA_FV_MODE"=="simple" quietly fvgen i.group##c.x, simple(group) prefix(text_)
    if inlist("$QA_FV_MODE","square","continuous") {
        mata: st_varlabel("x",st_local("text"))
        if "$QA_FV_MODE"=="square" {
            quietly fvgen c.x#c.x, prefix(text_)
            local suffix "²"
        }
        else {
            mata: st_varlabel("shared","OTHER")
            quietly fvgen c.x#c.shared, prefix(text_)
            local suffix " × OTHER"
        }
    }
    local generated "`r(genvars)'"
    local matched=0
    foreach v of local generated {
        local term : char `v'[fvgen_term]
        local match=("`term'"=="2.group")
        if inlist("$QA_FV_MODE","interaction","simple") local match=("`term'"=="2.group#c.x")
        if "$QA_FV_MODE"=="square" local match=("`term'"=="c.x#c.x")
        if "$QA_FV_MODE"=="continuous" local match=("`term'"=="c.x#c.shared")
        if !`match' continue
        local ++matched
        local got : variable label `v'
        if "$QA_FV_MODE"=="simple" {
            mata: actual=st_local("got"); assert(substr(actual,1,3)=="X (" & substr(actual,-1,1)==")"); st_global("QA_FV_GOT",substr(actual,4,strlen(actual)-4))
        }
        else {
            mata: actual=st_local("got"); suffix=st_local("suffix"); if (suffix!="") assert(substr(actual,strlen(actual)-strlen(suffix)+1,.)==suffix); st_global("QA_FV_GOT",substr(actual,1,strlen(actual)-strlen(suffix)))
        }
    }
    assert `matched'==1
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear tier(micro)
    * expect: EXACT (read-back generated variable labels, not echoed input)
    qa_hostile_strings, check(_qa_fv_text) result(QA_FV_GOT)
    assert r(n)==9
}
if _rc local ++fail
else local ++pass
foreach mode in factor vsref interaction simple square continuous {
    local ++tests
    capture noisily {
        qa_fx_a7_labelled, clear tier(micro)
        global QA_FV_MODE `mode'
        * expect: EXACT (raw actual generated labels and intentional suffixes)
        qa_hostile_strings, check(_qa_fv_factor) result(QA_FV_GOT)
        assert r(n)==9
    }
    if _rc local ++fail
    else local ++pass
}
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear tier(micro)
    mata: longText=invtokens(J(1,80,"Å"),""); st_varlabel("x",longText); assert(ustrlen(st_varlabel("x"))==80)
    quietly fvgen c.x, center prefix(long_)
    local generated "`r(genvars)'"
    local got : variable label `generated'
    mata: assert(st_local("got")==usubstr(longText+" (centered)",1,80)); assert(ustrlen(st_local("got"))==80)
    assert `generated'==x-20.5
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT (case twins and names differing at character32)
    qa_hostile_names, clear
    local twins "`r(twins)'"
    local long "`r(long)'"
    local want "`twins' `long'"
    quietly fvgen `want', prefix(names_)
    assert "`r(allvars)'"=="`want'" & "`r(genvars)'"==""
    assert y==1+cond(mod(_n,2),1,-1)
    assert Y==1+cond(mod(_n,2),10,-10)
    local first : word 1 of `long'
    local last : word 2 of `long'
    assert strlen("`first'")==32 & strlen("`last'")==32 & "`first'"!="`last'"
    assert `first'==_n & `last'==-_n
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT (center of sole defined observation)
    qa_fx_a7_labelled, clear tier(micro) perturb(single_row)
    quietly fvgen i.group##c.x, center prefix(one_)
    local generated "`r(genvars)'"
    assert _N==1 & `: word count `generated''==3
    foreach v of local generated {
        local role : char `v'[fvgen_role]
        if "`role'"=="main" assert `v'==1
        else {
            assert inlist("`role'","centered","interaction") & `v'==0
        }
    }
    quietly fvgen, drop
    assert r(k_dropped)==3 & x==1
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: REFUSED (all-missing continuous input)
    qa_fx_a7_labelled, clear tier(micro) perturb(miss_all_column)
    tempfile errorlog
    qa_state_snapshot, tag(missing)
    log using "`errorlog'", text replace name(refusal)
    capture noisily fvgen c.x, center prefix(empty_)
    local gotrc=_rc
    log close refusal
    qa_state_compare, tag(missing)
    mata: st_local("named",strofreal(any(strpos(cat(st_local("errorlog")),"no observations"))))
    assert `gotrc'==2000 & `named'==1
}
if _rc local ++fail
else local ++pass
foreach kind in negative big {
    local ++tests
    capture noisily {
        * expect: REFUSED (native factor code domain; exact state)
        qa_hostile_codes, clear
        if "`kind'"=="negative" keep if code<=20
        else keep if code>c(maxlong)
        assert _N==cond("`kind'"=="negative",9,6)
        tempfile errorlog
        qa_state_snapshot, tag(code)
        log using "`errorlog'", text replace name(refusal)
        capture noisily fvgen i.code, prefix(code_)
        local gotrc=_rc
        log close refusal
        qa_state_compare, tag(code)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("errorlog"))),"factor variables"))))
        assert `gotrc'==452 & `named'==1
    }
    if _rc local ++fail
    else local ++pass
}
display "RESULT: test_fixture_metadata tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
