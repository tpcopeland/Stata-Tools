*! Exact examples from the four datamap help files and the README
*! Date: 2026-08-23
*! 2026-11-10 (datamap 2.0.0, Phase 2): datadict and format(json) are removed, so the
*! six datamap/datadict examples here are the calls the 2.0.0 documentation prints
*! (the migration targets): a default run (datamap.md), a named output, saving() for
*! the machine-readable table that replaces format(json), document options, and the
*! output name that replaces "datadict, missing stats".  Each also checks the written
*! file, not only that the command returned.
*! 2026-11-10 (Phase 5): the README is now tested from its own text.  Every fenced
*! stata block under Quick Start and Worked Examples is extracted at run time and
*! run verbatim in a scratch folder (12 blocks); the output blocks printed after an
*! example must appear in that example's log; the Quick Start table must be lines of
*! the file the Quick Start call writes; the Migrating from 1.x table (old forms stop
*! with their codes, replacements run) and the coding-agent snippet (its commands in
*! order under dataqa set agent) are run; and the README version, badge, date and
*! 2.0.0 history entry equal the datamap.ado header and the .pkg.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
local test_count = 0
local pass_count = 0
local fail_count = 0

* The examples write to the working directory under their default names.
* Each output is erased before its example runs, so a file left by an
* earlier run cannot satisfy confirm file, and again at the end.
local doc_outputs datamap.md auto_codebook.md auto_map.md auto_map.dta auto_dict.md auto_titled.md
foreach f of local doc_outputs {
    capture erase "`qa_dir'/`f'"
}

* datamap.sthlp: the self-contained getting-started examples (2.0.0 forms).
do "`qa_dir'/_qa_md.do"
foreach mode in default named saving titled dict {
    local ++test_count
    capture noisily {
        sysuse auto, clear
        if "`mode'" == "default" datamap
        if "`mode'" == "named" datamap, output(auto_codebook.md)
        if "`mode'" == "saving" datamap, output(auto_map.md) saving(auto_map.dta, replace)
        if "`mode'" == "titled" datamap, title("Auto Dataset") author("Timothy P Copeland, Karolinska Institutet") output(auto_titled.md)
        if "`mode'" == "dict" datamap, output(auto_dict.md) columns(variable label type format vallabel missing values)
        assert !missing(r(nvars))
        assert r(nfiles) == 1 & r(nobs) == _N & r(nvars) > 0
        local f = cond("`mode'" == "default", "datamap.md", ///
            cond("`mode'" == "named", "auto_codebook.md", ///
            cond("`mode'" == "saving", "auto_map.md", ///
            cond("`mode'" == "titled", "auto_titled.md", "auto_dict.md"))))
        confirm file "`qa_dir'/`f'"
        * the file is the document: one row per auto variable, the label of price in it
        qa_md_rows using "`qa_dir'/`f'"
        assert r(n) == 12
        qa_md_contains using "`qa_dir'/`f'", needle("| Price |")
        assert !missing(r(n))
        assert r(n) >= 1
        if "`mode'" == "saving" {
            confirm file "`qa_dir'/auto_map.dta"
            preserve
            use "`qa_dir'/auto_map.dta", clear
            assert _N == 12
            restore
        }
        if "`mode'" == "titled" {
            qa_md_contains using "`qa_dir'/`f'", needle("# Auto Dataset") exact
            assert r(n) == 1
            qa_md_contains using "`qa_dir'/`f'", needle("**Author:** Timothy P Copeland, Karolinska Institutet") exact
            assert r(n) == 1
        }
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

* datamvp.sthlp: basic and generated-indicator examples exactly as printed.
local ++test_count
capture noisily {
    sysuse auto, clear
    datamvp
    assert !missing(r(N_patterns))
    assert r(N) == _N & r(N_patterns) > 0
    datamvp, generate(m)
    tab m_pattern
    confirm variable m_pattern
}
if _rc == 0 local ++pass_count
else local ++fail_count

* dataprobe.sthlp: basic in-memory profile exactly as printed.
local ++test_count
capture noisily {
    sysuse auto, clear
    dataprobe
    assert r(N) == _N & r(n_checks) == 0
    assert r(n_string) == 1
    assert !missing(r(n_string))
    assert !missing(r(n_continuous), r(n_categorical), r(n_date), r(n_string))
    assert r(n_continuous) + r(n_categorical) + r(n_date) + r(n_string) > 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

* dataprobe.sthlp (1.8.0): the gate, band, statistic, review, ledger, and
* version examples exactly as printed.
local ++test_count
capture noisily {
    sysuse auto, clear
    dataprobe, gatesonly expectn(74) isid(make) notmissing(price mpg) inrange(price weight 0 . \ mpg 10 50)
    assert r(n_violations) == 0 & r(n_checks) == 4
    dataprobe, gatesonly isid(make) rule("heavy": weight > 1500) bands(expectn(70 80) stat(mean mpg 18 25 \ median price 4000 6000)) bandwarn maskrare
    assert r(n_violations) == 0 & r(maskrare) == 1
    dataprobe, gatesonly stat(sum foreign 22 22 \ distinct rep78 5 5 \ mean mpg 20 30 if foreign)
    assert r(n_violations) == 0
    dataprobe, gatesonly review("cheap": price < 4000) complete(rep78 mpg) groupstat(mean price mpg, by(foreign))
    assert r(n_reviews) == 4 & r(n_checks) == 0
    tempfile ledger
    dataprobe, gatesonly isid(make) name(auto_cars) ledger("`ledger'", run(demo))
    assert r(ledger_seq) == 1 & "`r(dataset)'" == "auto_cars"
    capture dataprobe, minversion(1.8.0)
    assert _rc == 0
    dataprobe, rare(5) mincell(5) maskrare show(flagged)
}
if _rc == 0 local ++pass_count
else local ++fail_count

* dataqa.sthlp: the example sequence exactly as printed.
local ++test_count
capture noisily {
    tempfile ledger
    dataqa set maskrare mincell(5) ledger("`ledger'") run(demo)
    sysuse auto, clear
    dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)
    sysuse lifeexp, clear
    dataprobe, gatesonly isid(country) name(lifeexp)
    dataqa report
    assert r(n_datasets) == 2 & r(n_failed) == 0
    dataqa assert, expect(auto_cars lifeexp)
    tempfile release
    dataqa export, saving("`release'") replace
    assert !missing(r(N)) & r(N) >= 1
    dataqa set clear
    assert `"$DATAMAP_DQ"' == ""
}
if _rc == 0 local ++pass_count
else local ++fail_count
macro drop DATAMAP_DQ

* datamvp.sthlp (1.8.0) and README example 10.
local ++test_count
capture noisily {
    sysuse auto, clear
    datamvp price mpg rep78 headroom, maskrare percent bytable(foreign)
    assert r(mincell) == 5 & rowsof(r(miss_by)) == 1
    datamvp price mpg rep78 headroom, top(3)
    assert r(N_patterns_pooled) == 0
    tempfile ledger
    dataqa set maskrare mincell(5) ledger("`ledger'") run(demo)
    sysuse auto, clear
    dataprobe, gatesonly isid(make) rule("heavy": weight > 1500) bands(expectn(70 80) stat(mean mpg 18 25)) name(auto_cars)
    dataqa report
    dataqa assert, expect(auto_cars)
    dataqa set clear
}
if _rc == 0 local ++pass_count
else local ++fail_count
macro drop DATAMAP_DQ

* ---------------------------------------------------------------------------
* README.md (2.0.0, Phase 5).  Every fenced stata block under Quick Start and
* Worked Examples runs verbatim, each in its own scratch folder with its log
* open; the fenced output blocks that follow a stata block must appear in that
* block's log, the Quick Start table must appear in the file the Quick Start
* call writes, and no stata block may call a removed command.  The blocks are
* extracted by Mata at run time, so editing an example in the README changes
* what is tested; no example is copied into this file.
* ---------------------------------------------------------------------------
mata:
void _qa_rd_put(string scalar f, string scalar line, real scalar append)
{
    real scalar fh
    fh = fopen(f, append ? "a" : "w")
    fput(fh, line)
    fclose(fh)
}

real scalar _qa_rd_extract(string scalar readme, string scalar outdir)
{
    real scalar fh, i, n, infence, fl, collect, curblk, isout
    string scalar line, h2, h3, info, fence, bt, stem
    string colvector L
    bt = char(96)
    fh = fopen(readme, "r")
    L = J(0, 1, "")
    while ((line = fget(fh)) != J(0, 0, "")) L = L \ line
    fclose(fh)
    h2 = ""
    h3 = ""
    infence = 0
    n = 0
    curblk = 0
    collect = 0
    isout = 0
    fence = ""
    for (i = 1; i <= rows(L); i++) {
        line = L[i]
        if (!infence) {
            if (substr(line, 1, 3) == bt + bt + bt) {
                fl = 3
                while (substr(line, fl + 1, 1) == bt) fl++
                fence = substr(line, 1, fl)
                info = strtrim(substr(line, fl + 1, .))
                infence = 1
                collect = 0
                isout = 0
                if (info == "stata" & (h2 == "Quick Start" | h2 == "Worked Examples")) {
                    collect = 1
                    n++
                    curblk = n
                    st_local("hd" + strofreal(n), (h3 == "" ? h2 : h3))
                    stem = outdir + "/blk_" + sprintf("%03.0f", n)
                    _qa_rd_put(stem + ".do", "* README block " + strofreal(n), 0)
                }
                else if (info == "" & curblk > 0) isout = 1
                continue
            }
            if (substr(line, 1, 4) == "### ") {
                h3 = substr(line, 5, .)
                curblk = 0
            }
            else if (substr(line, 1, 3) == "## ") {
                h2 = substr(line, 4, .)
                h3 = ""
                curblk = 0
            }
        }
        else {
            if (strtrim(line) == fence) {
                infence = 0
                continue
            }
            stem = outdir + "/blk_" + sprintf("%03.0f", curblk)
            if (collect) _qa_rd_put(stem + ".do", line, 1)
            else if (isout) _qa_rd_put(stem + ".out", line, 1)
        }
    }
    return(n)
}

// how many of the first n block files hold needle
real scalar _qa_rd_grep(string scalar outdir, real scalar n, string scalar needle)
{
    real scalar i, fh, hits, found
    string scalar line
    hits = 0
    for (i = 1; i <= n; i++) {
        fh = fopen(outdir + "/blk_" + sprintf("%03.0f", i) + ".do", "r")
        found = 0
        while ((line = fget(fh)) != J(0, 0, "")) {
            if (strpos(line, needle) > 0) found = 1
        }
        fclose(fh)
        hits = hits + found
    }
    return(hits)
}

// the lines of outfile (trimmed, blanks skipped) that no line of logfile holds
real scalar _qa_rd_missing_lines(string scalar outfile, string scalar logfile)
{
    real scalar fh, i, j, miss, found
    string scalar line
    string colvector O, G
    O = J(0, 1, "")
    G = J(0, 1, "")
    fh = fopen(outfile, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strtrim(line) != "") O = O \ strtrim(line)
    }
    fclose(fh)
    fh = fopen(logfile, "r")
    while ((line = fget(fh)) != J(0, 0, "")) G = G \ strtrim(line)
    fclose(fh)
    miss = 0
    st_local("rd_first_missing", "")
    for (i = 1; i <= rows(O); i++) {
        found = 0
        for (j = 1; j <= rows(G); j++) {
            if (strpos(G[j], O[i]) > 0) {
                found = 1
                break
            }
        }
        if (!found) {
            miss++
            if (miss == 1) st_local("rd_first_missing", O[i])
        }
    }
    return(miss)
}

// the table rows between the demo-output markers named tag that the
// document file does not hold as a line
real scalar _qa_rd_table_missing(string scalar readme, string scalar tag, string scalar mdfile)
{
    real scalar fh, i, inblk, miss, ntab
    string scalar line, bt
    string colvector L, M
    L = J(0, 1, "")
    M = J(0, 1, "")
    fh = fopen(readme, "r")
    inblk = 0
    ntab = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, "<!-- demo-output:start " + tag + " -->") == 1) inblk = 1
        else if (strpos(line, "<!-- demo-output:end " + tag + " -->") == 1) inblk = 0
        else if (inblk & substr(line, 1, 1) == "|") L = L \ line
    }
    fclose(fh)
    fh = fopen(mdfile, "r")
    while ((line = fget(fh)) != J(0, 0, "")) M = M \ line
    fclose(fh)
    miss = 0
    for (i = 1; i <= rows(L); i++) {
        if (!any(M :== L[i])) miss++
    }
    st_local("rd_table_rows", strofreal(rows(L)))
    return(miss)
}

// the first line of file that starts with prefix ("" when none)
string scalar _qa_rd_firstline(string scalar f)
{
    real scalar fh
    string scalar line
    fh = fopen(f, "r")
    line = fget(fh)
    fclose(fh)
    if (line == J(0, 0, "")) return("")
    return(line)
}

// remove a folder tree made by this suite
void _qa_rd_rmtree(string scalar d)
{
    string colvector fs, ds
    real scalar i
    if (!direxists(d)) return
    fs = dir(d, "files", "*", 1)
    for (i = 1; i <= rows(fs); i++) unlink(fs[i])
    ds = dir(d, "dirs", "*", 1)
    for (i = 1; i <= rows(ds); i++) _qa_rd_rmtree(ds[i])
    rmdir(d)
}
// the example commands of a help file: every {cmd:. ...} or {stata "...":. ...}
// line between {title:Examples} and the next {marker}, one command per line
real scalar _qa_hx_extract(string scalar sthlp, string scalar outdo)
{
    real scalar fh, n, inex, k
    string scalar line, cmd, bt, pre
    bt = char(96)
    fh = fopen(sthlp, "r")
    inex = 0
    n = 0
    st_local("hx_badbrace", "0")
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, "{title:Examples}") > 0) {
            inex = 1
            continue
        }
        if (inex & substr(line, 1, 8) == "{marker ") break
        if (!inex) continue
        cmd = ""
        pre = "{phang2}{cmd:. "
        if (substr(line, 1, strlen(pre)) == pre & substr(line, -8, 8) == "}{p_end}") {
            cmd = substr(line, strlen(pre) + 1, strlen(line) - strlen(pre) - 8)
        }
        else if (substr(line, 1, 15) == "{phang2}{stata ") {
            k = strpos(line, char(34) + ":. ")
            if (k > 0) cmd = substr(line, 17, k - 17)
        }
        if (cmd == "") continue
        if (strpos(cmd, "{c ") > 0 | strpos(cmd, "{it:") > 0 | strpos(cmd, "{bf:") > 0) st_local("hx_badbrace", "1")
        n++
        _qa_rd_put(outdo, cmd, (n > 1))
    }
    fclose(fh)
    return(n)
}

// ex.cmds (one command per line) to ex.do: each command under capture, its
// return code appended to the local hx_rcs
void _qa_hx_wrap(string scalar cmds, string scalar outdo)
{
    real scalar fh, n
    string scalar line, bt
    bt = char(96)
    fh = fopen(cmds, "r")
    n = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        n++
        _qa_rd_put(outdo, "capture noisily " + line, (n > 1))
        _qa_rd_put(outdo, "global hx_rcs " + char(34) + char(36) + "hx_rcs " + bt + "=_rc'" + char(34), 1)
    }
    fclose(fh)
}

string scalar _qa_hx_line(string scalar cmds, real scalar i)
{
    real scalar fh, n
    string scalar line, out
    fh = fopen(cmds, "r")
    n = 0
    out = ""
    while ((line = fget(fh)) != J(0, 0, "")) {
        n++
        if (n == i) out = line
    }
    fclose(fh)
    return(out)
}
end

tempfile rdbase
local rdwork "`rdbase'_rd"
mkdir "`rdwork'"
local readme "`pkg_dir'/README.md"
mata: st_numscalar("rd_n", _qa_rd_extract(st_local("readme"), st_local("rdwork")))
local rd_n = scalar(rd_n)

* the extractor found the examples: Quick Start plus the eleven Worked Examples
local ++test_count
capture noisily {
    assert `rd_n' == 12
}
if _rc == 0 local ++pass_count
else local ++fail_count

* no example calls a removed command or option
local ++test_count
capture noisily {
    foreach needle in "datadict" "format(json)" "format(text)" "noguidance" "datevars(" {
        mata: st_numscalar("rd_hit", _qa_rd_grep(st_local("rdwork"), `rd_n', st_local("needle")))
        assert scalar(rd_hit) == 0
    }
}
if _rc == 0 local ++pass_count
else local ++fail_count

forvalues i = 1/`rd_n' {
    local ++test_count
    local blk : display %03.0f `i'
    local hd "`hd`i''"
    local wd "`rdwork'/w`blk'"
    capture noisily {
        mkdir "`wd'"
        quietly cd "`wd'"
        set linesize 255
        capture log close _qa_rd
        quietly log using "`wd'/blk.log", text replace name(_qa_rd)
        capture noisily do "`rdwork'/blk_`blk'.do"
        local rc_blk = _rc
        capture quietly log close _qa_rd
        quietly cd "`qa_dir'"
        macro drop DATAMAP_DQ
        assert `rc_blk' == 0

        * the output blocks printed after the example are what the example prints
        capture confirm file "`rdwork'/blk_`blk'.out"
        if _rc == 0 {
            mata: st_numscalar("rd_miss", _qa_rd_missing_lines(st_local("rdwork") + "/blk_" + st_local("blk") + ".out", st_local("wd") + "/blk.log"))
            if scalar(rd_miss) != 0 display as error `"README output line not in the log: `rd_first_missing'"'
            assert scalar(rd_miss) == 0
        }

        if "`hd'" == "Quick Start" {
            confirm file "`wd'/auto_map.md"
            qa_md_rows using "`wd'/auto_map.md"
            assert r(n) == 12
            mata: st_numscalar("rd_miss", _qa_rd_table_missing(st_local("readme"), "quickstart", st_local("wd") + "/auto_map.md"))
            assert `rd_table_rows' == 14
            if scalar(rd_miss) != 0 display as error "Quick Start table rows not in the file the call writes: " scalar(rd_miss)
            assert scalar(rd_miss) == 0
        }
        if strpos("`hd'", "Withhold identifiers") {
            local f "`wd'/person_map.md"
            local bt = char(96)
            qa_md_contains using "`f'", needle("45 (11.3%): . 15, .a Refused 18, .b Not asked 12")
            assert r(n) == 1
            qa_md_contains using "`f'", needle("| `bt'lopnr`bt' |  | long | 0 (0.0%) | excluded (structure only) |") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("float %td daily")
            assert r(n) == 2
            qa_md_contains using "`f'", needle("- `bt'bmi`bt': 999: 26 rows") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("- `bt'exit`bt': after ")
            assert r(n) == 1
            qa_md_contains using "`f'", needle("(run date): 7 rows")
            assert r(n) == 1
        }
        if strpos("`hd'", "Save the variable-level table") {
            confirm file "`wd'/auto_meta.dta"
            confirm file "`wd'/auto_meta.csv"
            quietly describe using "`wd'/auto_meta.dta"
            assert r(k) == 37 & r(N) == 12
            foreach v in variable storage_type missing unique key missing_codes candidates {
                confirm variable `v'
            }
            assert _N == 12
        }
        if strpos("`hd'", "publishable document") {
            local f "`wd'/auto_dictionary.md"
            local bt = char(96)
            qa_md_contains using "`f'", needle("# Auto data dictionary") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("**Author:** Timothy P Copeland, Karolinska Institutet") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("## Notes") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("## Change Log") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("**Last Updated:** 2026-11-10") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("| Variable | Label | Type | Format | Value label | Missing | Values/Statistics |") exact
            assert r(n) == 1
        }
        if strpos("`hd'", "saved dataset") {
            qa_md_rows using "`wd'/auto_from_file.md"
            assert r(n) == 12
        }
        if strpos("`hd'", "Linkage block") {
            local f "`wd'/linked.md"
            local bt = char(96)
            qa_md_contains using "`f'", needle("| `bt'lopnr`bt' | person, rx | person long; rx str12 | person yes; rx no | cannot merge: numeric and string | type conflict: numeric in person; string in rx |") exact
            assert r(n) == 1
            qa_md_contains using "`f'", needle("3. [Linkage](#linkage)") exact
            assert r(n) == 1
        }
        if strpos("`hd'", "write the gates as code") {
            confirm file "`wd'/auto_gates.do"
            qa_md_contains using "`wd'/auto_gates.do", needle("dataprobe, gatesonly ///") exact
            assert r(n) == 1
        }
    }
    local rc_all = _rc
    capture quietly cd "`qa_dir'"
    capture log close _qa_rd
    if `rc_all' == 0 local ++pass_count
    else {
        display as error "README example `i' (`hd') failed"
        local ++fail_count
    }
}

* The four help files: every example line runs, in order, in a scratch folder
* (the dataqa pipeline example names $working, $output and $dt; they are set here)
* The one example line that halts by design: the dataqa baseline line ("a
* dataset that vanished halts, unless it is optional") gives r(9).  It is
* allowed to give 9 or 0; every other command line must give 0.
local hx_allow_dataqa `"dataqa assert, run(rerun) baseline(demo) optional(lifeexp)"'
local hx_allow_dataqa_rc 9
local hx_allow_datamap ""
local hx_allow_datamap_rc 0
local hx_allow_dataprobe ""
local hx_allow_dataprobe_rc 0
local hx_allow_datamvp ""
local hx_allow_datamvp_rc 0
foreach hf in datamap dataprobe dataqa datamvp {
    local ++test_count
    capture noisily {
        tempfile hbase
        local hwd "`hbase'_help_`hf'"
        mkdir "`hwd'"
        mata: st_numscalar("hx_n", _qa_hx_extract("`pkg_dir'/`hf'.sthlp", st_local("hwd") + "/ex.cmds"))
        display as text "help examples of `hf'.sthlp: " scalar(hx_n) " command lines"
        assert scalar(hx_n) >= 5
        assert "`hx_badbrace'" == "0"
        mata: _qa_hx_wrap(st_local("hwd") + "/ex.cmds", st_local("hwd") + "/ex.do")
        quietly cd "`hwd'"
        global working "."
        global output "."
        global dt "20261110"
        global hx_rcs ""
        capture noisily do ex.do
        local hx_rcs "$hx_rcs"
        macro drop hx_rcs
        local rc_hx = _rc
        quietly cd "`qa_dir'"
        macro drop working output dt qa_synth qa_baseline DATAMAP_DQ
        capture log close qa
        assert `rc_hx' == 0
        assert `: word count `hx_rcs'' == scalar(hx_n)
        local hx_bad = 0
        forvalues k = 1/`=scalar(hx_n)' {
            local hrc : word `k' of `hx_rcs'
            if `hrc' != 0 {
                mata: st_local("hcmd", _qa_hx_line(st_local("hwd") + "/ex.cmds", `k'))
                local ok = 0
                if `"`hx_allow_`hf''"' != "" & `"`hcmd'"' == `"`hx_allow_`hf''"' & `hrc' == `hx_allow_`hf'_rc' local ok = 1
                if !`ok' {
                    display as error `"help example of `hf'.sthlp stopped with r(`hrc'): `hcmd'"'
                    local ++hx_bad
                }
            }
        }
        assert `hx_bad' == 0
    }
    local rc_all = _rc
    capture quietly cd "`qa_dir'"
    if `rc_all' == 0 local ++pass_count
    else {
        display as error "help examples of `hf'.sthlp failed"
        local ++fail_count
    }
}

* Migrating from 1.x: every old form stops with the documented code, every
* replacement runs and does what the table says
local ++test_count
capture noisily {
    tempfile mbase
    local mwd "`mbase'_mig"
    mkdir "`mwd'"
    quietly cd "`mwd'"
    sysuse auto, clear
    capture datadict, output(x.md)
    assert _rc == 199
    foreach o in "format(json)" "format(text)" "noguidance" "datevars(price)" ///
        "stats" "detail" "datasignature" "missing" "date(2026-01-01)" {
        capture datamap, output(x.md) `o'
        assert _rc == 198
        capture confirm file x.md
        assert _rc != 0
    }
    capture datamap, output(x.md) saving(m, replace foo)
    assert _rc == 198
    capture datamap, compact columns(variable label) output(x.md)
    assert _rc == 198
    capture datamap, append title("t") output(x.md)
    assert _rc == 198
    capture datamap, append separate
    assert _rc == 198
    file open fh using cfgf.txt, write replace
    file write fh "format = json" _n
    file close fh
    capture datamap, config(cfgf.txt) output(x.md)
    assert _rc == 198
    file open fh using cfgm.txt, write replace
    file write fh "missing = yes" _n
    file close fh
    capture datamap, config(cfgm.txt) output(x.md)
    assert _rc == 198
    * the replacements
    datamap, output(d.md)
    assert "`r(format)'" == "" & r(nobs) == 74 & r(nvars) == 12
    datamap, output(d.md) columns(variable label type format vallabel missing values notes chars)
    datamap, output(d.md) docdate("2026-01-01")
    datamap, output(d.txt)
    mata: st_local("first", _qa_rd_firstline("d.txt"))
    assert "`first'" == "## 1. Data in memory"
    datamap, output(d.md) date(price)
    assert "`r(date_vars)'" == "price"
    file open fh using cfgd.txt, write replace
    file write fh "datevars = price" _n "docdate = 2026-05-05" _n
    file close fh
    datamap, config(cfgd.txt) output(d.md)
    assert "`r(date_vars)'" == "price"
    * two datasets and separate: r(nobs) unset, r(output) unset under separate
    mkdir in
    mkdir out
    save in/a.dta, replace
    save in/b.dta, replace
    datamap, directory(in) output(c.md)
    assert r(nfiles) == 2 & missing(r(nobs)) & "`r(output)'" == "c.md"
    datamap, directory(in) separate outdir(out) suffix(_dictionary)
    assert "`r(output)'" == ""
    assert wordcount(subinstr("`r(outputs)'", ";", " ", .)) == 2
    assert strpos(";`r(outputs)';", ";out/a_dictionary.md;") > 0 & strpos(";`r(outputs)';", ";out/b_dictionary.md;") > 0
    confirm file out/a_dictionary.md
    capture datamap, directory(in) separate outdir(nosuchfolder)
    assert _rc != 0
    datamap, directory(in) separate outdir(out)
    confirm file out/a_map.md
    confirm file out/b_map.md
    quietly cd "`qa_dir'"
}
local rc_mig = _rc
capture quietly cd "`qa_dir'"
if `rc_mig' == 0 local ++pass_count
else local ++fail_count

* Using datamap with a coding agent: the CLAUDE.md snippet's commands, in
* order, under the session preset, and the snippet names each of them
local ++test_count
capture noisily {
    tempfile abase
    local awd "`abase'_agent"
    mkdir "`awd'"
    quietly cd "`awd'"
    sysuse auto, clear
    preserve
    keep make foreign
    save auto_make.dta, replace
    restore
    * the README names each command twice: in the table and in the snippet
    local bt = char(96)
    foreach c in "datamap, output(map.md)" "dataprobe, diff(prev) snapshot(prev, replace) gatesonly" ///
        "quietly dataprobe, snapshot(prev)" "dataprobe, gatesonly keyset(<key> using <file>.dta)" ///
        "dataprobe, brief" "dataqa set agent" "dataqa set clear" {
        qa_md_contains using "`readme'", needle("`bt'`c'`bt'")
        assert !missing(r(n))
        assert r(n) >= 1
    }
    qa_md_contains using "`readme'", needle("`bt'dataprobe, diff(prev) snapshot(prev, replace) gatesonly`bt'")
    assert !missing(r(n))
    assert r(n) >= 2
    dataqa set agent
    assert strpos(`"$DATAMAP_DQ"', "safe") > 0
    datamap, output(map.md)
    assert r(safe) == 1
    qa_md_contains using map.md, needle("make")
    quietly dataprobe, snapshot(prev)
    assert "`r(snapshot)'" == "prev"
    tostring rep78, replace
    replace price = . in 1/10
    dataprobe, diff(prev) snapshot(prev, replace) gatesonly
    assert r(diff_n_lines) == 2 & "`r(diff_changed_vars)'" == "price rep78"
    dataprobe, diff(prev) snapshot(prev, replace) gatesonly
    assert r(diff_n_lines) == 0
    dataprobe, gatesonly keyset(make using auto_make.dta)
    assert r(keyset_matched) == 74 & "`r(keyset_merge)'" == "1:1"
    dataprobe, brief
    assert r(safe) == 1
    dataqa set clear
    assert `"$DATAMAP_DQ"' == ""
    quietly cd "`qa_dir'"
}
local rc_ag = _rc
capture quietly cd "`qa_dir'"
macro drop DATAMAP_DQ
if `rc_ag' == 0 local ++pass_count
else local ++fail_count

* README is current: the version line, the badge, and the date match the code
local ++test_count
capture noisily {
    mata: st_local("rd_head", _qa_rd_firstline("`pkg_dir'/datamap.ado"))
    assert regexm(`"`rd_head'"', "^\*! datamap Version ([0-9]+\.[0-9]+\.[0-9]+)  ([0-9]+)/([0-9]+)/([0-9]+)")
    local ver = regexs(1)
    local dd = regexs(2) + regexs(3) + regexs(4)
    local dash = regexs(2) + "-" + regexs(3) + "-" + regexs(4)
    qa_md_contains using "`readme'", needle("**Version `ver'** | `dash'") exact
    assert r(n) == 1
    qa_md_contains using "`readme'", needle("badge/version-`ver'-1a5f91")
    assert r(n) == 1
    qa_md_contains using "`pkg_dir'/datamap.pkg", needle("d Distribution-Date: `dd'") exact
    assert r(n) == 1
    qa_md_contains using "`readme'", needle("### `ver' (`dash')") exact
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

mata: _qa_rd_rmtree(st_local("rdwork"))

foreach f of local doc_outputs {
    capture erase "`qa_dir'/`f'"
}

display "RESULT: test_datamap_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
