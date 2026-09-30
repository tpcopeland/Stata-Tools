*! test_fixture_text_routes.do -- rendered literal text, raw metadata and native text syntax
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set varabbrev off
set graphics off
capture log close _all
log using "test_fixture_text_routes.log",text replace
args source_override
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
if `"`source_override'"'!="" adopath ++ `"`source_override'"'
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
* Exact friendly graph initializes native graph session metadata before fingerprints.
qa_fx_a7_labelled,clear tier(micro)
quietly raincloud x,nocloud norain name(fxwarm,replace)
graph drop fxwarm
python:
def _qa_rain_svg_read_py():
    from sfi import Macro
    import xml.etree.ElementTree as ET
    root=ET.parse(Macro.getLocal('svg')+'.svg').getroot()
    texts=[e for e in root.iter() if e.tag.split('}')[-1]=='text' and ''.join(e.itertext())]
    role=Macro.getGlobal('QA_RAIN_ROLE')
    if role in ('title','subtitle'): selected=[e for e in texts if float(e.attrib['y'])==min(float(t.attrib['y']) for t in texts)]
    elif role in ('note','xtitle'): selected=[e for e in texts if float(e.attrib['y'])==max(float(t.attrib['y']) for t in texts)]
    elif role=='ytitle': selected=[e for e in texts if float(e.attrib['x'])==min(float(t.attrib['x']) for t in texts)]
    else: raise AssertionError('unknown role')
    assert len(selected)==1, f'ambiguous rendered {role} geometry'
    Macro.setGlobal('QA_RAIN_GOT',''.join(selected[0].itertext()).replace('\u00a0',' '))
def _qa_rain_svg_group_py():
    from sfi import Macro
    from collections import Counter
    import xml.etree.ElementTree as ET
    root=ET.parse(Macro.getLocal('svg')+'.svg').getroot()
    texts=[''.join(e.itertext()).replace('\u00a0',' ') for e in root.iter() if e.tag.split('}')[-1]=='text']
    counts=Counter(texts)
    raw=Macro.getLocal('text')
    assert counts[raw+' A']==2 and counts[raw+' B']==2, 'each actual group axis and legend label must render once'
    assert counts['Value '+raw]==1 and counts['Group '+raw]==1, 'both actual default axis titles must render once'
    Macro.setGlobal('QA_RAIN_GOT',raw)
def _qa_rain_svg_multiline_py():
    from sfi import Macro
    import xml.etree.ElementTree as ET
    root=ET.parse(Macro.getLocal('svg')+'.svg').getroot()
    texts=[e for e in root.iter() if e.tag.split('}')[-1]=='text']
    # Red title text is selected by its actual SVG style, independently of its content.
    actual=[(''.join(e.itertext()),e.attrib['style']) for e in texts if 'fill:#FF0000' in e.attrib.get('style','')]
    assert [x[0] for x in actual]==['First `"nested"\' line','Second line']
    assert all('font-size:79.94px' in x[1] for x in actual), 'native size(small) must be consumed'
import sys,types
_qa_rain_svg_module=types.ModuleType('_qa_rain_svg')
_qa_rain_svg_module.read=_qa_rain_svg_read_py
_qa_rain_svg_module.group=_qa_rain_svg_group_py
_qa_rain_svg_module.multiline=_qa_rain_svg_multiline_py
sys.modules['_qa_rain_svg']=_qa_rain_svg_module
end
capture program drop _qa_rain_text
program define _qa_rain_text
    version 16.0
    args corpus
    mata: st_local("text",st_global(st_local("corpus")))
    local role "$QA_RAIN_ROLE"
    local axes `"xtitle("") ytitle("")"'
    if "`role'"=="xtitle" local axes `"ytitle("")"'
    if "`role'"=="ytitle" local axes `"xtitle("")"'
    qa_state_snapshot,tag(text)
    quietly raincloud x,nocloud norain name(fxtext,replace) `role'(`"`macval(text)'"') xlabel(none) ylabel(none) `axes'
    qa_state_compare,tag(text)
    assert r(N)==40 & r(n_groups)==1
    matrix stats=r(stats)
    assert stats[1,1]==40 & stats[1,2]==20.5 & stats[1,3]==sqrt(410/3) & stats[1,4]==20.5 & stats[1,5]==10.5 & stats[1,6]==30.5 & stats[1,7]==20 & missing(stats[1,8])
    tempfile svg
    quietly graph export "`svg'.svg",as(svg) name(fxtext) replace
    capture noisily python: __import__("_qa_rain_svg").read()
    local rc=_rc
    erase "`svg'.svg"
    if `rc' exit `rc'
end
capture program drop _qa_rain_group_text
program define _qa_rain_group_text
    version 16.0
    args corpus
    mata: st_local("text",st_global(st_local("corpus")))
    qa_fx_a7_labelled,clear tier(micro)
    generate byte code=1+(group>2)
    if "$QA_RAIN_GROUP_TYPE"=="numeric" {
        tempname vl
        mata: st_vlmodify(st_local("vl"),(1\2),(st_local("text")+" A"\st_local("text")+" B"))
        label values code `vl'
        local grouping "code"
    }
    else {
        generate str100 stringgroup=""
        mata: st_sstore(selectindex(st_data(.,"code"):==1),"stringgroup",J(20,1,st_local("text")+" A")); st_sstore(selectindex(st_data(.,"code"):==2),"stringgroup",J(20,1,st_local("text")+" B"))
        local grouping "stringgroup"
    }
    mata: st_varlabel("x","Value "+st_local("text"));st_varlabel(st_local("grouping"),"Group "+st_local("text"))
    local orientation "$QA_RAIN_ORIENT"
    local layers "$QA_RAIN_LAYERS"
    * Native bandwidth reference has an unlabeled numeric copy; the raw source
    * labels remain untouched. Finite moments below are computed independently.
    matrix native_bw=J(2,1,.)
    if strpos("`layers'","nocloud")==0 {
        preserve
        quietly set obs 200
        tempvar oracle_x density_x density_y
        generate double `oracle_x'=x
        forvalues j=1/2 {
            quietly kdensity `oracle_x' if code==`j',generate(`density_x' `density_y') nograph n(200) kernel(epanechnikov)
            matrix native_bw[`j',1]=r(bwidth)
            drop `density_x' `density_y'
        }
        restore
    }
    qa_state_snapshot,tag(grouptext)
    quietly raincloud x,over(`grouping') `orientation' `layers' name(fxtext,replace) seed(1701)
    qa_state_compare,tag(grouptext)
    assert r(N)==40 & r(n_groups)==2
    matrix stats=r(stats)
    assert stats[1,1]==20 & stats[2,1]==20 & stats[1,2]==10.5 & stats[2,2]==30.5 & stats[1,3]==sqrt(35) & stats[2,3]==sqrt(35)
    forvalues j=1/2 {
        assert stats[`j',4]==10.5+20*(`j'-1) & stats[`j',5]==5.5+20*(`j'-1) & stats[`j',6]==15.5+20*(`j'-1) & stats[`j',7]==10
        if strpos("`layers'","nocloud")==0 assert stats[`j',8]==native_bw[`j',1] & !missing(stats[`j',8])
        else assert missing(stats[`j',8])
    }
    mata: assert(st_global("r(group_labels)")==" "+char(96)+char(34)+st_local("text")+" A"+char(34)+char(39)+" "+char(96)+char(34)+st_local("text")+" B"+char(34)+char(39))
    tempfile svg
    quietly graph export "`svg'.svg",as(svg) name(fxtext) replace
    capture noisily python: __import__("_qa_rain_svg").group()
    local rc=_rc
    erase "`svg'.svg"
    if `rc' exit `rc'
end
local tests=0
local pass=0
local fail=0
foreach role in title subtitle note xtitle ytitle {
    local ++tests
    capture noisily {
        qa_fx_a7_labelled,clear tier(micro)
        global QA_RAIN_ROLE `role'
        * expect: EXACT
        qa_hostile_strings,check(_qa_rain_text) result(QA_RAIN_GOT)
        assert r(n)==9
    }
    if _rc local ++fail
    else local ++pass
}
foreach kind in numeric string {
    foreach orient in horizontal vertical {
        foreach layers in cloud rain box {
            local ++tests
            capture noisily {
                qa_fx_a7_labelled,clear tier(micro)
                global QA_RAIN_GROUP_TYPE `kind'
                global QA_RAIN_ORIENT `orient'
                if "`layers'"=="cloud" global QA_RAIN_LAYERS "norain nobox"
                if "`layers'"=="rain" global QA_RAIN_LAYERS "nocloud nobox"
                if "`layers'"=="box" global QA_RAIN_LAYERS "nocloud norain"
                * expect: EXACT
                qa_hostile_strings,check(_qa_rain_group_text) result(QA_RAIN_GOT)
                assert r(n)==9
            }
            if _rc local ++fail
            else local ++pass
        }
    }
}
local ++tests
capture noisily {
    qa_fx_a7_labelled,clear tier(micro)
    mata: st_global("QA_RAIN_ADJACENT","A"+char(34)+char(39)+"B")
    foreach kind in numeric string {
        global QA_RAIN_GROUP_TYPE `kind'
        global QA_RAIN_ORIENT horizontal
        global QA_RAIN_LAYERS "nocloud norain"
        _qa_rain_group_text QA_RAIN_ADJACENT
        mata: assert(st_global("QA_RAIN_GOT")==st_global("QA_RAIN_ADJACENT"))
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    qa_fx_a7_labelled,clear tier(micro)
    mata: st_local("nested",char(96)+char(34)+"First "+char(96)+char(34)+"nested"+char(34)+char(39)+" line"+char(34)+char(39)+" "+char(96)+char(34)+"Second line"+char(34)+char(39)+", size(small) color(red)")
    quietly raincloud x,nocloud norain title(`macval(nested)') name(fxtext,replace)
    assert r(N)==40
    tempfile svg
    quietly graph export "`svg'.svg",as(svg) name(fxtext) replace
    python: __import__("_qa_rain_svg").multiline()
    erase "`svg'.svg"
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    qa_fx_a7_labelled,clear tier(micro)
    mata: st_local("bad",char(96)+char(34)+"Unclosed")
    capture noisily twoway scatter x id,title(`macval(bad)') name(nativebad,replace)
    local native_rc=_rc
    capture noisily raincloud x,nocloud norain title(`macval(bad)') name(fxtext,replace)
    local candidate_rc=_rc
    * Native graph parser132 and public syntax parser198 both explicitly refuse malformed quoting.
    assert `native_rc'==132 & `candidate_rc'==198
}
if _rc local ++fail
else local ++pass
foreach suffix in ROLE GOT GROUP_TYPE ORIENT LAYERS ADJACENT {
    global QA_RAIN_`suffix'
}
display "RESULT: test_fixture_text_routes tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
