*! test_fixture_compile_state.do -- actual compilation faults preserve strict and original rc
* Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set processors 1
set more off
set varabbrev off
capture log close _all
log using "test_fixture_compile_state.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
tempfile token
local faults "`token'_faults"
mkdir "`faults'"
python:
from pathlib import Path
from sfi import Macro
root=Path(Macro.getLocal('pkgdir'))
out=Path(Macro.getLocal('faults'))
n=0
quote=lambda name: chr(96)+name+chr(39)
rc_tail='if '+quote('_st_compile_rc')+' exit '+quote('_st_compile_rc')
for name in ('_simtab_common.ado','_simtab_xlsx_write.ado'):
    source=(root/name).read_text()
    blocks=[]
    start=0
    while True:
        begin=source.find('local _st_compile_ms = c(matastrict)\ncapture noisily {\nmata:\n',start)
        if begin<0: break
        end=source.index(rc_tail,begin)+len(rc_tail)
        blocks.append((begin,end));start=end
    for begin,end in blocks:
        n+=1
        block=source[begin:end]
        block=block.replace('\nend\n}\n','\nvoid _qa_sim_compile_fault( { }\nend\n}\n',1)
        guarded=source[:begin]+block+source[end:]
        # Actual native compiler is the reference for the preserved rc.
        native=guarded.replace('local _st_compile_ms = c(matastrict)\ncapture noisily {\nmata:\n','mata:\n')
        native=native.replace('end\n}\nlocal _st_compile_rc = _rc\nmata: mata set matastrict '+quote('_st_compile_ms')+'\n'+rc_tail,'end')
        (out/f'guarded{n}.do').write_text(guarded)
        (out/f'native{n}.do').write_text(native)
assert n==5, f'expected five real compilation blocks, got {n}'
end
local tests=0
local pass=0
local fail=0
foreach strict in off on {
    forvalues block=1/5 {
        local ++tests
        capture noisily {
            clear
            set obs 3
            generate double caller_value=_n/7
            mata: mata set matastrict `strict'
            capture noisily run "`faults'/native`block'.do"
            local native_rc=_rc
            assert `native_rc'!=0
            mata: mata set matastrict `strict'
            capture noisily run "`faults'/guarded`block'.do"
            local guarded_rc=_rc
            assert `guarded_rc'==`native_rc' & "`c(matastrict)'"=="`strict'"
            assert caller_value==_n/7 & _N==3
            mata: assert(sum((1,2,3))==6)
            display "COMPILE block`block' strict=`strict': native=`native_rc' guarded=`guarded_rc' strict restored"
        }
        if _rc local ++fail
        else local ++pass
    }
}
python:
from pathlib import Path
from sfi import Macro
out=Path(Macro.getLocal('faults'))
for path in out.iterdir(): path.unlink()
out.rmdir()
end
display "RESULT: test_fixture_compile_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
