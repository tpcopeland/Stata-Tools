* test_kmplot_saved_files.do
* saving() and risksaving() files: path validation before any side effect,
* one file per output, dataset-level metadata, and the row contract
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init
global TABTOOLS_set_smallcells ""

local work "`c(tmpdir)'/kmplot_saved_files_`c(current_time)'"
local work = subinstr("`work'", ":", "", .)
capture mkdir "`work'"

**## F1 saving() and risksaving() naming one file is refused before anything is written
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach pair in "same.dta same.dta" "same same.dta" "./same.dta same" "sub/../same.dta same.dta" {
        gettoken p1 p2 : pair
        local p2 = strtrim("`p2'")
        capture erase "`work'/same.dta"
        _kmqa_expect, rc(198) ///
            cmd(kmplot, by(drug) saving(`work'/`p1', replace) risksaving(`work'/`p2', replace) nodraw) ///
            text("same file")
        capture confirm file "`work'/same.dta"
        assert _rc != 0
    }
    * distinct files are both written
    kmplot, by(drug) saving("`work'/c1", replace) risksaving("`work'/r1", replace) nodraw
    local ntp = r(n_timepoints)
    assert `ntp' > 0 & `ntp' < .
    use "`work'/c1", clear
    assert _N == 48 + 3
    confirm variable estimate anchor
    use "`work'/r1", clear
    assert _N == 3 * `ntp'
    confirm variable at_risk events censored
    assert at_risk[1] == 20
}
_kmqa_record, name("F1 saving() and risksaving() on one file: r(198), nothing written") rc(`=_rc')

**## F2 invalid saving()/risksaving() paths are refused before the graph is drawn or exported
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    capture graph drop _all
    capture erase "`work'/side.png"
    _kmqa_expect, rc(198) ///
        cmd(kmplot, by(drug) export(`work'/side.png, replace) saving(`work'/bad;path.dta, replace)) ///
        text("saving()")
    capture confirm file "`work'/side.png"
    assert _rc != 0
    capture graph describe kmplot
    assert _rc != 0
    _kmqa_expect, rc(198) ///
        cmd(kmplot, by(drug) export(`work'/side.png, replace) risksaving(`work'/r.dta, rep)) ///
        text("risksaving()")
    capture confirm file "`work'/side.png"
    assert _rc != 0
    capture graph describe kmplot
    assert _rc != 0
    * an unsafe export() path is also refused before drawing
    _kmqa_expect, rc(198) cmd(kmplot, by(drug) export(`work'/bad;x.png, replace)) text("export()")
    capture graph describe kmplot
    assert _rc != 0
    * the refused calls left the data as they were
    assert _N == 48
    assert "`: char _dta[st_bt]'" == "studytime"
}
_kmqa_record, name("F2 path errors precede the graph and the export") rc(`=_rc')

**## F3 saved files carry no source-dataset metadata
capture noisily {
    sysuse cancer, clear
    label data "Restricted source data"
    notes _dta: confidential note
    notes studytime: variable note
    label define srcdx 1 "secret code"
    char _dta[source_owner] "registry"
    quietly stset studytime, failure(died)
    kmplot, by(drug) risktable saving("`work'/c3", replace) risksaving("`work'/r3", replace) nodraw
    foreach f in c3 r3 {
        use "`work'/`f'", clear
        assert `"`: data label'"' == ""
        local dchars : char _dta[]
        assert `"`dchars'"' == ""
        foreach v of varlist _all {
            local vchars : char `v'[]
            assert `"`vchars'"' == ""
        }
        quietly label dir
        assert `"`r(names)'"' == ""
        * the file is not mistaken for stset data
        capture st_is 2 analysis
        assert _rc != 0
    }
    * the variables and their labels are kept
    use "`work'/c3", clear
    confirm variable group group_label time estimate se lower upper censor anchor
    assert `"`: variable label estimate'"' == "KM survival or cumulative failure estimate"
}
_kmqa_record, name("F3 saved files: no data label, notes, characteristics or value labels") rc(`=_rc')

**## F4 curve file row contract: one row per analysis record plus one anchor per group
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly count if _st == 1
    local nrec = r(N)
    quietly tab drug
    local ngrp = r(r)
    * two deaths at time 1 in one group: tied times repeat
    quietly count if studytime == 1 & died == 1 & drug == 1
    local ties1 = r(N)
    assert `ties1' == 2
    kmplot, by(drug) saving("`work'/c4", replace) nodraw
    use "`work'/c4", clear
    assert _N == `nrec' + `ngrp'
    quietly count if anchor == 1
    assert r(N) == `ngrp'
    quietly count if group == 1 & time == 1
    assert r(N) == `ties1'
}
_kmqa_record, name("F4 saving(): records plus anchors, tied times repeat (documented)") rc(`=_rc')

_kmqa_finish, suite("test_kmplot_saved_files")
