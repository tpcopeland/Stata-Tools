*! test_diagtab_fixture_text.do -- exact literal captions in real output sinks
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
java set heapmax 256m
capture log close _all
log using test_diagtab_fixture_text.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
qa_hostile_strings
local corpus `r(names)'
python:
def _qa_diag_text_check():
    from pathlib import Path
    from sfi import Macro
    import csv,openpyxl
    caption=Macro.getLocal('caption')
    route=Macro.getLocal('route')
    rows=list(csv.reader(Path(Macro.getLocal('csv')).open(newline='',encoding='utf-8')))
    assert rows[0][0]==caption,(caption,rows[0])
    assert rows[-1][0]==caption,(caption,rows[-1])
    # Markdown escaping is documented presentation, so compare with a separate
    # explicit escape mapping; literal macro-looking tokens must remain literal.
    escaped=caption.strip().replace('\\','\\\\').replace('|','\\|').replace('*','\\*').replace('_','\\_').replace('\r\n','<br>').replace('\r','<br>').replace('\n','<br>')
    text=Path(Macro.getLocal('md')).read_text(encoding='utf-8')
    assert text.startswith('### '+escaped+'\n\n'),(caption,text)
    assert text.endswith('*'+escaped+'*\n'),(caption,text)
    w=openpyxl.load_workbook(Macro.getLocal('out'))
    worksheet=w['Diagnostics']
    assert worksheet['A1'].value==caption,(caption,worksheet['A1'].value)
    values=[c.value for row in worksheet for c in row if isinstance(c.value,str)]
    expected=caption
    if route=='undefined':
        expected=caption.strip()
        expected+=(' ' if expected[-1:] in '.;:!?' else '; ')+'Undefined estimates are shown as --.'
    assert expected in values,(expected,values)
    w.close()
    console=Path(Macro.getLocal('console')).read_text(encoding='utf-8')
    assert 'EXPANDED' not in console
end
foreach route in single multiple undefined {
foreach corpus_name of local corpus {
    local ++tests
    local root ""
    capture noisily {
        * expect: EXACT
        qa_fx_a7_files, clear seed(37)
        local root `"`r(root)'"'
        local out `"`macval(root)'/text.xlsx"'
        local csv `"`macval(root)'/text.csv"'
        local md `"`macval(root)'/text.md"'
        qa_fx_a7_labelled, clear seed(37)
        mata: st_local("caption",st_global(st_local("corpus_name")))
        local cut "cutoff(20.5)"
        if "`route'"=="multiple" local cut "cutoffs(20.5 21.5)"
        if "`route'"=="undefined" local cut "cutoff(100)"
        tempfile console
        log using `console', text replace name(text_console)
        qa_state_snapshot, tag(diag_text)
        noisily diagtab x y, `cut' title(`"`macval(caption)'"') footnote(`"`macval(caption)'"') xlsx(`"`out'"') csv(`"`csv'"') markdown(`"`md'"') frame(fixture_result)
        log close text_console
        frame fixture_result: mata: assert(st_sdata(1,"title")==st_local("caption"))
        frame drop fixture_result
        qa_state_compare, tag(diag_text)
        python: _qa_diag_text_check()
    }
    local outcome=_rc
    capture frame drop fixture_result
    capture log close text_console
    if `"`root'"'!="" {
        capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
        if _rc & !`outcome' local outcome=_rc
    }
    if `outcome' {
        local ++fail
        display as error "FAIL: `route' `corpus_name'; rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: `route' `corpus_name'"
    }
}
}
display "RESULT: test_diagtab_fixture_text tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
