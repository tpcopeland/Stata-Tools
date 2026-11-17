*! test_review_2026_11_17_datamap.do  2026/11/17
*! datamap: fixes from the 2026-11-17 external review (slice B: datamap.ado,
*! _datamap_* helpers, datamap.sthlp)
*! Author: Timothy P Copeland, Karolinska Institutet
*
*   F7   datesafe alone withholds the levels of text forced into
*        categorical() when a value holds a digit (exact date strings)
*   F19  that row reads "frequencies withheld (datesafe)", not "more than
*        maxfreq()", under datesafe and under safe
*   F8   detect(survival): a date-formatted time variable forced into
*        continuous() prints no range under datesafe, and its range in the
*        date format without it
*   F9   panelid(): the rows without an identifier, and rows per unit, are
*        withheld when either margin is below mincell(); shown otherwise
*   F25  detect(survey): an all-missing (or 0-observation) weight reads "no
*        nonmissing values", never "range . to ."
*   F20  a $name in output(), suffix(), filelist() or a config() output key
*        is refused (r(198)) by the path guard, never expanded
*   F21  a typed columns() overrides config() compact = yes, and a typed
*        compact overrides config() columns
*   F20b the same for outdir(), directory(), single(), and config() keys
*        that hold variable names (exclude, datevars)
*   L1   separate: a.dta and ./a.dta are one output and collide (r(198))
*   L1b  separate: d/a.dta and d//a.dta collide too
*   L2   saving() to an unwritable path stops before the report is written
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_review_2026_11_17_datamap.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_r1117"
capture mkdir "`W'"
capture mkdir "`W'/plus"
capture mkdir "`W'/personal"
mata: assert(direxists(st_local("W") + "/plus"))
sysdir set PLUS "`W'/plus"
sysdir set PERSONAL "`W'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
macro drop DATAMAP_DQ
* bait: a wrongly expanded global R1117 shows up as EXPANDED
global R1117 "EXPANDED"
global TC 0
global PASS 0
global FAIL 0
capture program drop _ft
program define _ft
    args rc desc
    global TC = $TC + 1
    if `rc' == 0 {
        global PASS = $PASS + 1
        display as result "PASS: `desc'"
    }
    else {
        global FAIL = $FAIL + 1
        display as error "FAIL (rc `rc'): `desc'"
    }
end

**# Helpers

* _rv_has file needle: local _has 1 when file holds needle (literal; {bq}
* stands for a backtick), else 0
capture program drop _rv_has
program define _rv_has
    args f needle
    mata: st_local("_h", strofreal(strpos(invtokens(cat(st_local("f"))', char(10)), subinstr(st_local("needle"), "{bq}", char(96))) > 0))
    c_local _has `_h'
end

local D "`W'/d"
capture mkdir "`D'"
cd "`D'"

**# F7 / F19 datesafe and safe: text forced categorical with digits

capture noisily {
    clear
    quietly set obs 30
    generate str12 dstr = cond(_n <= 10, "2020-01-15", cond(_n <= 20, "2020-01-16", "2020-01-17"))
    generate str12 grp = cond(_n <= 10, "g1", cond(_n <= 20, "g2", "g3"))
    generate str12 nod = cond(_n <= 10, "a", cond(_n <= 20, "b", "c"))
    datamap, categorical(dstr grp nod) datesafe output("f7.md")
    _rv_has "f7.md" "2020-01-1"
    assert `_has' == 0
    _rv_has "f7.md" `"| {bq}dstr{bq} |  | str12 | 0 (0.0%) | 3 distinct; frequencies withheld (datesafe) |"'
    assert `_has' == 1
    _rv_has "f7.md" `"| {bq}grp{bq} |  | str12 | 0 (0.0%) | 3 distinct; frequencies withheld (datesafe) |"'
    assert `_has' == 1
    * text without a digit still lists its levels
    _rv_has "f7.md" `""a": 10 (33.3%)<br>"b": 10 (33.3%)<br>"c": 10 (33.3%)"'
    assert `_has' == 1
    * without datesafe the levels are listed, as before
    datamap, categorical(dstr) output("f7n.md")
    _rv_has "f7n.md" `""2020-01-15": 10 (33.3%)"'
    assert `_has' == 1
}
_ft `=_rc' "F7 datesafe withholds the levels of digit-holding text forced into categorical(); digit-free text and the default still list them"

capture noisily {
    clear
    quietly set obs 30
    generate str12 dstr = cond(_n <= 10, "2020-01-15", cond(_n <= 20, "2020-01-16", "2020-01-17"))
    generate str12 grp = cond(_n <= 10, "g1", cond(_n <= 20, "g2", "g3"))
    datamap, categorical(dstr grp) safe output("f19.md")
    _rv_has "f19.md" "more than maxfreq"
    assert `_has' == 0
    _rv_has "f19.md" `"| {bq}grp{bq} |  | str12 | 0 (0.0%) | 3 distinct; frequencies withheld (datesafe) |"'
    assert `_has' == 1
    * a genuine maxfreq() overflow keeps its own message
    datamap, categorical(grp) maxfreq(2) output("f19m.md")
    _rv_has "f19m.md" "3 distinct; frequencies not listed (more than maxfreq(2))"
    assert `_has' == 1
}
_ft `=_rc' "F19 withheld levels read 'frequencies withheld (datesafe)' under safe; a real maxfreq() overflow keeps 'more than maxfreq(#)'"

**# F8 detect(survival): a %td time variable forced into continuous()

capture noisily {
    clear
    quietly set obs 30
    generate double followuptime = 21915 + _n
    format followuptime %td
    generate byte died = mod(_n, 2)
    datamap, continuous(followuptime) datesafe detect(survival) output("f8.md")
    _rv_has "f8.md" "- Survival time variables: {bq}followuptime{bq}"
    assert `_has' == 1
    _rv_has "f8.md" "range: "
    assert `_has' == 0
    _rv_has "f8.md" "21916"
    assert `_has' == 0
    _rv_has "f8.md" "2020/01/02"
    assert `_has' == 0
    datamap, continuous(followuptime) detect(survival) output("f8n.md")
    _rv_has "f8n.md" "  - {bq}followuptime{bq} range: 2020/01/02 to 2020/01/31"
    assert `_has' == 1
    _rv_has "f8n.md" "range: 21916 to 21945"
    assert `_has' == 0
}
_ft `=_rc' "F8 survival range of a date-formatted continuous() time: none under datesafe, the date format without it"

**# F9 panelid(): the missing-identifier margin under mincell()

capture noisily {
    clear
    quietly set obs 20
    generate id = ceil(_n / 2)
    quietly replace id = . in 1/2
    datamap, panelid(id) mincell(5) output("f9.md")
    _rv_has "f9.md" "- Panel: identifier {bq}id{bq}; 9 units; 20 rows (missing identifier: suppressed (<5 in a cell)); rows per unit withheld"
    assert `_has' == 1
    _rv_has "f9.md" "with a missing identifier"
    assert `_has' == 0
    _rv_has "f9.md" "rows per unit"
    assert `_has' == 1
    _rv_has "f9.md" "2.0 rows per unit"
    assert `_has' == 0
    * both margins at or above mincell(): shown as before
    quietly replace id = . in 1/6
    datamap, panelid(id) mincell(5) output("f9s.md")
    _rv_has "f9s.md" "- Panel: identifier {bq}id{bq}; 7 units; 20 rows (6 with a missing identifier); 2.0 rows per unit"
    assert `_has' == 1
    * mincell(0): no masking
    quietly replace id = ceil(_n / 2)
    quietly replace id = . in 1/2
    datamap, panelid(id) mincell(0) output("f9z.md")
    _rv_has "f9z.md" "(2 with a missing identifier); 2.0 rows per unit"
    assert `_has' == 1
}
_ft `=_rc' "F9 panelid(): missing-identifier count and rows per unit withheld below mincell(); shown at or above it and under mincell(0)"

**# F25 detect(survey): a weight with no nonmissing values

capture noisily {
    clear
    quietly set obs 10
    generate wgt = .
    generate x = _n
    datamap, detect(survey) output("f25.md")
    _rv_has "f25.md" "- Survey weight {bq}wgt{bq}: no nonmissing values"
    assert `_has' == 1
    _rv_has "f25.md" "range . to ."
    assert `_has' == 0
    clear
    quietly set obs 0
    generate wgt = .
    datamap, detect(survey) output("f25b.md")
    _rv_has "f25b.md" "- Survey weight {bq}wgt{bq}: no nonmissing values"
    assert `_has' == 1
    * a weight with values keeps its range
    clear
    quietly set obs 10
    generate wgt = _n
    datamap, detect(survey) output("f25c.md")
    _rv_has "f25c.md" "- Survey weight {bq}wgt{bq}: range 1 to 10; mean "
    assert `_has' == 1
}
_ft `=_rc' "F25 an all-missing or 0-observation survey weight reads 'no nonmissing values'; a weight with values keeps its range"

**# F20 path options holding $name are refused, never expanded

capture noisily {
    sysuse auto, clear
    mata: st_local("p", "out_" + char(36) + "R1117.md")
    capture noisily datamap, output(`"`macval(p)'"')
    assert _rc == 198
    capture confirm file "out_EXPANDED.md"
    assert _rc == 601
    * config() output key
    tempname fh
    file open `fh' using "cfg_o.txt", write text replace
    file write `fh' "output = cfg_" _char(36) "R1117.md" _n
    file close `fh'
    capture noisily datamap, config("cfg_o.txt")
    assert _rc == 198
    capture confirm file "cfg_EXPANDED.md"
    assert _rc == 601
    * suffix() under separate
    mata: st_local("sx", "_" + char(36) + "R1117")
    capture noisily datamap, separate suffix(`"`macval(sx)'"')
    assert _rc == 198
    capture confirm file "memory_EXPANDED.md"
    assert _rc == 601
    * filelist() name
    quietly save "EXPANDED.dta", replace
    mata: st_local("fl", char(36) + "R1117.dta")
    capture noisily datamap, filelist(`"`macval(fl)'"') output("f20f.md")
    assert _rc == 198
    capture confirm file "f20f.md"
    assert _rc == 601
    * a clean path is unaffected
    datamap, output("f20ok.md")
    capture confirm file "f20ok.md"
    assert _rc == 0
}
_ft `=_rc' "F20 a dollar name in output(), config() output, suffix() or filelist() stops r(198); no expanded file is written"

**# F21 columns() and compact: the typed one overrides config()

capture noisily {
    sysuse auto, clear
    tempname fh
    file open `fh' using "cfg_c.txt", write text replace
    file write `fh' "compact = yes" _n
    file close `fh'
    datamap, config("cfg_c.txt") columns(variable label) output("f21.md")
    _rv_has "f21.md" "| Variable | Label |"
    assert `_has' == 1
    _rv_has "f21.md" "| Variable | Type |"
    assert `_has' == 0
    file open `fh' using "cfg_c2.txt", write text replace
    file write `fh' "columns = variable label" _n
    file close `fh'
    datamap, config("cfg_c2.txt") compact output("f21b.md")
    _rv_has "f21b.md" "| Variable | Type | Label | Missing | Unique |"
    assert `_has' == 1
    * config() alone still applies its compact key
    datamap, config("cfg_c.txt") output("f21c.md")
    _rv_has "f21c.md" "| Variable | Type | Label | Missing | Unique |"
    assert `_has' == 1
    * both typed: still refused
    capture noisily datamap, compact columns(variable) output("f21d.md")
    assert _rc == 198
}
_ft `=_rc' "F21 typed columns() overrides config() compact and typed compact overrides config() columns; both typed still r(198)"

**# L1 separate: ./ does not hide a collision

capture noisily {
    sysuse auto, clear
    quietly save "la.dta", replace
    capture erase "la_map.md"
    capture noisily datamap, filelist("la.dta ./la.dta") separate
    assert _rc == 198
    capture confirm file "la_map.md"
    assert _rc == 601
}
_ft `=_rc' "L1 separate: la.dta and ./la.dta collide (r(198)) before any file is written"

**# F20b outdir(), directory(), single() and config() name keys holding $name

* the expanded target exists each time, so an expansion would run at rc 0
capture noisily {
    sysuse auto, clear
    capture mkdir "dd"
    quietly save "dd/aa.dta", replace
    quietly save "dd/aaEXPANDED.dta", replace
    capture mkdir "ddEXPANDED"
    quietly save "ddEXPANDED/bb.dta", replace
    capture mkdir "od_EXPANDED"
    capture erase "od_EXPANDED/aa_map.md"
    mata: st_local("s", "od_" + char(36) + "R1117")
    capture noisily datamap, directory("dd") outdir(`"`macval(s)'"') separate
    assert _rc == 198
    capture confirm file "od_EXPANDED/aa_map.md"
    assert _rc == 601
    capture noisily datamap, filelist("dd/aa") outdir(`"`macval(s)'"') separate
    assert _rc == 198
    capture confirm file "od_EXPANDED/aa_map.md"
    assert _rc == 601
    mata: st_local("s", "dd" + char(36) + "R1117")
    capture erase "f20d.md"
    capture noisily datamap, directory(`"`macval(s)'"') output("f20d.md")
    assert _rc == 198
    capture confirm file "f20d.md"
    assert _rc == 601
    mata: st_local("s", "dd/aa" + char(36) + "R1117")
    capture erase "f20s.md"
    capture noisily datamap, single(`"`macval(s)'"') output("f20s.md")
    assert _rc == 198
    capture confirm file "f20s.md"
    assert _rc == 601
    * config(): a variable-name key holding $ is refused, not expanded
    sysuse auto, clear
    generate EXPANDED = 1
    tempname fh
    file open `fh' using "cfg_x.txt", write text replace
    file write `fh' "exclude = " _char(36) "R1117 make" _n
    file close `fh'
    capture erase "f20x.md"
    capture noisily datamap, config("cfg_x.txt") output("f20x.md")
    assert _rc == 198
    capture confirm file "f20x.md"
    assert _rc == 601
    file open `fh' using "cfg_y.txt", write text replace
    file write `fh' "datevars = " _char(36) "R1117" _n
    file close `fh'
    capture noisily datamap, config("cfg_y.txt") output("f20x.md")
    assert _rc == 198
    * clean outdir(), directory(), single() and exclude still work
    capture mkdir "od_ok"
    datamap, directory("dd") outdir("od_ok") separate
    capture confirm file "od_ok/aa_map.md"
    assert _rc == 0
    datamap, single("dd/aa") output("f20s_ok.md")
    capture confirm file "f20s_ok.md"
    assert _rc == 0
    file open `fh' using "cfg_z.txt", write text replace
    file write `fh' "exclude = make" _n
    file close `fh'
    sysuse auto, clear
    datamap, config("cfg_z.txt") output("f20z.md")
    _rv_has "f20z.md" "1 excluded ({bq}make{bq})"
    assert `_has' == 1
    _rv_has "f20z.md" "| str18 | 0 (0.0%) | excluded (structure only) |"
    assert `_has' == 1
}
_ft `=_rc' "F20b a dollar name in outdir(), directory(), single() or a config() exclude/datevars key stops r(198); no expanded path is read or written"

**# L1b separate: a repeated slash does not hide a collision

capture noisily {
    sysuse auto, clear
    capture mkdir "ld"
    quietly save "ld/la.dta", replace
    capture erase "ld/la_map.md"
    capture noisily datamap, filelist("ld/la ld//la") separate
    assert _rc == 198
    capture confirm file "ld/la_map.md"
    assert _rc == 601
    capture noisily datamap, filelist("ld/la") separate
    assert _rc == 0
    capture confirm file "ld/la_map.md"
    assert _rc == 0
}
_ft `=_rc' "L1b separate: ld/la and ld//la collide (r(198)) before any file is written; one path still writes"

**# L2 saving() to an unwritable path fails before the report

capture noisily {
    sysuse auto, clear
    capture erase "l2.md"
    capture noisily datamap, output("l2.md") saving("nodir_r1117/meta.dta", replace)
    assert _rc == 603
    capture confirm file "l2.md"
    assert _rc == 601
    capture noisily datamap, output("l2.md") saving("nodir_r1117/meta.dta", replace csv)
    assert _rc == 603
    capture confirm file "l2.md"
    assert _rc == 601
    * a writable saving() still writes both
    datamap, output("l2.md") saving("l2meta.dta", replace csv)
    confirm file "l2.md"
    confirm file "l2meta.dta"
    confirm file "l2meta.csv"
}
_ft `=_rc' "L2 an unwritable saving() path stops r(603) before output() is written; a writable one writes report and metadata"

**# Cleanup

cd "`qa_dir'"
macro drop DATAMAP_DQ
macro drop R1117
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_review_2026_11_17_datamap tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
