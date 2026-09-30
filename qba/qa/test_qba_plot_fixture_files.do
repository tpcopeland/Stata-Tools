*! test_qba_plot_fixture_files.do -- exported SVG curve and untouched owned-tree refusals
*! Author: Timothy P Copeland, Karolinska Institutet
version 16
clear all
set more off
capture log close _all
log using test_qba_plot_fixture_files.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
from sfi import Macro
import hashlib,xml.etree.ElementTree as ET,re

def _qba_tree():
    root=Path(Macro.getLocal('root'))
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}

def _qba_svg_cells():
    tree=ET.parse(Macro.getLocal('output'))
    assert 'Known RR curve' in ''.join(tree.getroot().itertext())
    candidates=[]
    for e in tree.iter():
        if e.tag.endswith('polyline'):
            xy=[tuple(map(float,p.split(','))) for p in e.attrib.get('points','').split()]
            if len(xy)==3: candidates.append(xy)
    for e in tree.iter():
        if e.tag.endswith('path') and e.attrib.get('d','').count('L')==2:
            nums=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',e.attrib['d'])))
            if len(nums)==6: candidates.append(list(zip(nums[::2],nums[1::2])))
    assert any(abs((p[1][0]-p[0][0])/(p[2][0]-p[1][0])-1)<.001 and abs((p[1][1]-p[0][1])/(p[2][1]-p[1][1])-2)<.001 for p in candidates if p[2][1]!=p[1][1]),candidates
end

**# path_hostile
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    mata: st_local("output",substr(st_local("output"),1,strlen(st_local("output"))-5)+".svg")
    python: _qba_tree_before=_qba_tree()
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_file)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3) title("Known RR curve") saving(`"`macval(output)'"')
    assert r(n_missing)==0
    python: _qba_svg_cells()
    python: _changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _qba_tree().items() if k!=_changed}==_qba_tree_before
    qa_state_compare, tag(qba_file)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: path_hostile"
}

**# path_noext
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _qba_tree_before=_qba_tree()
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_file)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3) title("Known RR curve") saving(`"`macval(output)'"')
    assert _rc==602
    python: assert _qba_tree()==_qba_tree_before
    qa_state_compare, tag(qba_file)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: path_noext"
}

**# unicode_spaces
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local output `"`macval(root)'/Known curve Å spaces.svg"'
    python: _qba_tree_before=_qba_tree()
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_file)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3) title("Known RR curve") saving(`"`macval(output)'"')
    assert r(n_missing)==0
    python: _qba_svg_cells()
    python: _changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _qba_tree().items() if k!=_changed}==_qba_tree_before
    qa_state_compare, tag(qba_file)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: unicode_spaces rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: unicode_spaces"
}

display "RESULT: test_qba_plot_fixture_files tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
