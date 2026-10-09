*! _gcomp_split_interventions Version 2.0.3  2026/10/09
*! Split only top-level arm commas, retaining Stata expression bytes
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_split_interventions
program define _gcomp_split_interventions
    version 16.0
    tempname caller_r
    _return hold `caller_r'
    local original_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, TEXT(string) PREFIX(name)
        if strlen("`prefix'")>20 {
            display as error "intervention parser prefix must be at most 20 characters"
            exit 198
        }
        mata: _gcomp_split_arm_locals(st_local("text"))
        c_local `prefix'n = `_gc_split_n'
        c_local `prefix'ifpos = `_gc_split_ifpos'
        if `_gc_split_n'>0 {
            forvalues index=1/`_gc_split_n' {
                c_local `prefix'`index' `"`macval(_gc_split_arm`index')'"'
            }
        }
    }
    local rc = _rc
    set varabbrev `original_varabbrev'
    _return restore `caller_r'
    if `rc' exit `rc'
end

capture mata: mata drop _gcomp_split_arm_locals()
local _gcomp_split_strict = c(matastrict)
capture noisily mata:
mata set matastrict on
void _gcomp_split_arm_locals(string scalar text)
{
    string rowvector arms
    string scalar ch, next, piece, stack, expected
    real scalar i, start, ordinary, compound, length, ifpos

    arms=J(1,0,"")
    start=1
    stack=""
    ordinary=0
    compound=0
    length=strlen(text)
    ifpos=0
    for(i=1;i<=length;i++) {
        ch=substr(text,i,1)
        next=(i<length ? substr(text,i+1,1) : "")
        if (compound) {
            if (ch==char(96) & next==char(34)) {
                compound++
                i++
                continue
            }
            if (ch==char(34) & next==char(39)) {
                compound--
                i++
                continue
            }
            continue
        }
        if (ordinary) {
            if (ch==char(34)) ordinary=0
            continue
        }
        if (ch==char(96) & next==char(34)) {
            compound=1
            i++
            continue
        }
        if (ch==char(34)) {
            ordinary=1
            continue
        }
        if (ifpos==0 & stack=="" & i>1 & i+2<=length & strlower(substr(text,i,2))=="if" &
            strpos(" "+char(9)+char(10)+char(13),substr(text,i-1,1)) &
            strpos(" "+char(9)+char(10)+char(13),substr(text,i+2,1))) ifpos=i
        if (ch=="(" | ch=="[") stack=stack+ch
        else if (ch==")" | ch=="]") {
            expected=(ch==")" ? "(" : "[")
            if (strlen(stack)==0 | substr(stack,strlen(stack),1)!=expected) {
                errprintf("interventions(): unbalanced expression delimiters\n")
                _error(198)
            }
            stack=substr(stack,1,strlen(stack)-1)
        }
        else if (ch=="," & stack=="") {
            piece=strtrim(substr(text,start,i-start))
            if (piece!="") arms=arms,piece
            start=i+1
        }
    }
    if (stack!="" | ordinary | compound) {
        errprintf("interventions(): unbalanced expression delimiters or quotes\n")
        _error(198)
    }
    piece=strtrim(substr(text,start,.))
    if (piece!="") arms=arms,piece
    st_local("_gc_split_ifpos",strofreal(ifpos))
    st_local("_gc_split_n",strofreal(cols(arms)))
    for(i=1;i<=cols(arms);i++) st_local("_gc_split_arm"+strofreal(i),arms[i])
}
end
local _gcomp_split_compile_rc = _rc
set matastrict `_gcomp_split_strict'
if `_gcomp_split_compile_rc' exit `_gcomp_split_compile_rc'
