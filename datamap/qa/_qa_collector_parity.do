*! _qa_collector_parity.do Version 1.0.0  2026/11/09
*! saving() parity fixture: one deterministic dataset and ten saving() runs
*! 2026-11-10 (datamap 2.0.0): datadict and format(json) are removed, so the five
*! datadict runs (dd1-dd5) and the JSON run (dm6) left this file.  The fixtures
*! qa/data/test_saving_v1106_{datamap,dataprobe}.dta are still the 1.10.6 values
*! for dm1-dm5, dm7, dm8 and dp1.  test_saving_v1106_datadict.dta (the 1.10.6
*! datadict tables) was removed in Phase 3 QA: nothing read it.
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Load from a suite with: do "`qa_dir'/_qa_collector_parity.do"
*
* The 1.10.6 fixtures qa/data/test_saving_v1106_{datamap,dataprobe}.dta
* (values) and test_saving_v1106_schema.dta (column names, types, formats)
* were made by running _qacp_run with datamap 1.10.6 (2026-11-09, datamap
* 2.0.0 plan, Phase 1); test_datamap_v200_collector.do runs it with the code
* under test and compares.  Change nothing here without remaking the fixtures
* from 1.10.6: the comparison is only meaningful while both runs read this file.
*
* API
*   _qacp_data
*       40 rows, no random numbers: a labelled byte with .a and . and a label
*       holding a quote, a backtick and a dollar sign; a float with fractional
*       levels; a double with a note and a characteristic holding the same
*       characters; a three-valued byte; %td and %tc dates; a string with an
*       embedded quote, a backtick, a dollar sign and one ""; free text; a
*       rare flag (3 of 40); an identifier-like long; hostile variable and
*       data labels.
*   _qacp_run
*       In the current directory: saves par_in.dta and par_in2.dta (rows
*       1-25, tc dropped, another label), runs every configuration and
*       leaves dm1.dta-dm5.dta, dm7.dta, dm8.dta and dp1.dta, all with
*       relative names, so the source and output columns do not depend on
*       where the directory is.  r(datamap) and r(dataprobe) list the
*       configuration names.

capture program drop _qacp_data
program define _qacp_data
    version 16.0
    clear
    quietly set obs 40
    gen long id = _n
    gen byte grp = 1 + mod(_n, 4)
    label define grpL 1 "Alpha" 3 "Gamma" 4 "Delta" .a "Refused", replace
    mata: st_vlmodify("grpL", 2, "Beta " + char(34) + "q" + char(34) + " " + char(96) + "t" + char(39) + " " + char(36) + "x")
    label values grp grpL
    quietly replace grp = .a in 1/3
    quietly replace grp = . in 4
    gen float fx = mod(_n, 3) / 10
    gen double inc = 1000 + _n * 37.5
    quietly replace inc = . in 5/6
    mata: st_global("inc[note1]", "Income note " + char(34) + "q" + char(34) + " " + char(96) + "t" + char(39) + " " + char(36) + "d <b>|pipe")
    mata: st_global("inc[note0]", "1")
    mata: st_global("inc[source]", "Register " + char(34) + "A" + char(34) + " | <x>")
    gen byte tri = mod(_n, 3)
    gen int dt = mdy(1, 1, 2020) + _n * 7
    format dt %td
    gen double tc = clock("2020-01-01 08:00", "YMD hm") + _n * 3600000
    format tc %tc
    gen str8 sc = cond(mod(_n, 5) == 0, "say " + char(34) + "hi" + char(34), cond(mod(_n, 5) == 1, "a" + char(96) + "b", "z" + char(36) + "x"))
    quietly replace sc = "" in 7
    gen str20 freetext = "row " + string(_n)
    gen byte rare = (_n <= 3)
    gen long pnr = 1000000 + _n
    mata: st_varlabel("inc", "Income " + char(34) + "SEK" + char(34) + " " + char(96) + "x" + char(39))
    label var grp "Group (labelled)"
    label var dt "Visit date"
    mata: stata("label data " + char(96) + char(34) + "Fixture " + char(34) + "data" + char(34) + " label" + char(34) + char(39))
end

capture program drop _qacp_run
program define _qacp_run, rclass
    version 16.0
    _qacp_data
    quietly save par_in.dta, replace
    preserve
    quietly keep in 1/25
    drop tc
    label data "second file"
    quietly save par_in2.dta, replace
    restore
    * datamap: memory, privacy options, mincell(0), two files, separate,
    * compact, the text-only sections
    quietly datamap, output(dm1.txt) saving(dm1, replace)
    quietly datamap, output(dm2.txt) datesafe nostats exclude(pnr) categorical(sc) continuous(tri) saving(dm2, replace) mincell(5)
    quietly datamap, output(dm3.txt) mincell(0) categorical(sc) saving(dm3, replace)
    quietly datamap, filelist(par_in par_in2) output(dm4.txt) saving(dm4, replace)
    quietly datamap, filelist(par_in par_in2) separate saving(dm5, replace)
    quietly datamap, output(dm7.txt) compact saving(dm7, replace)
    quietly datamap, output(dm8.txt) detect(binary) quality missing(pattern) samples(2) categorical(sc) saving(dm8, replace)
    * dataprobe's saving() posts its rows through the same row poster
    quietly dataprobe, saving(dp1.dta, replace)
    return local datamap "dm1 dm2 dm3 dm4 dm5 dm7 dm8"
    return local dataprobe "dp1"
end
