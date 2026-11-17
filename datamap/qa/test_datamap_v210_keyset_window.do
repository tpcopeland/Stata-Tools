clear all
set more off
version 16.0

* test_datamap_v210_keyset_window.do - datamap 2.1.0 keyset_window brief (F11)
* keyset() asof(mdate udate) / window(mstart mend udate): per master row the
*   using rows of its key on or before the date, or inside the window, counted
*   none / one / more, as-of ties, maxlag() staleness, the pairs -joinby- makes;
*   maxnone() maxmulti() maxties() maxstale() gates; masking; errors.
* reconcile(file, n ids() sum() by() expect() tol()): row, id and total
*   conservation against a saved checkpoint; masking; errors; frames.
* Every expected count is computed here by another route: -joinby- (with
* unmatched(master) or keep-if the window), collapse/contract and merge, or
* by hand; nothing is read back from the code under test.  Gate results are
* read from the ledger() file, console text from a log.

**# Bootstrap: targeted local reinstall
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "run this suite from the package qa/ directory"
    exit 198
}
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
local _ls0 = c(linesize)
local _dq0 `"$DATAMAP_DQ"'
set linesize 255
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

global KW_TC 0
global KW_PASS 0
global KW_FAIL 0
capture program drop _t
program define _t
    args rc msg
    global KW_TC = $KW_TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global KW_PASS = $KW_PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global KW_FAIL = $KW_FAIL + 1
    }
end

* one ledger row by family and label: r(n) r(st) r(obs) r(num) r(om) r(exp) r(mins)
capture program drop _row
program define _row, rclass
    args file fam label
    preserve
    quietly use `"`file'"', clear
    quietly keep if family == "`fam'" & label == `"`label'"'
    return scalar n = _N
    if _N == 1 {
        return local st = status[1]
        return local obs = observed[1]
        return local exp = expected[1]
        return local msg = message[1]
        return scalar num = observed_num[1]
        return scalar om = obs_masked[1]
        return scalar mins = minshown[1]
    }
    restore
end

* lines of a text log that contain a needle
capture program drop _cnt
program define _cnt, rclass
    args file needle
    tempname fh
    local n = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`macval(needle)'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* as-of oracle on the master data in memory (id, mdate) against a using file:
* joinby with unmatched(master), then per master row the candidates, the
* latest candidate date and its rows.  r(none) r(one) r(more) r(ties) r(stale)
capture program drop _asof_oracle
program define _asof_oracle, rclass
    args ufile key md ud lag
    preserve
    quietly generate long _row = _n
    quietly joinby `key' using `"`ufile'"', unmatched(master)
    quietly generate byte _cand = !missing(`ud') & !missing(`md') & `ud' <= `md'
    quietly bysort _row: egen double _c = total(_cand)
    quietly generate double _ucand = cond(_cand, `ud', .)
    quietly bysort _row: egen double _L = max(_ucand)
    quietly generate byte _atL = _cand & `ud' == _L
    quietly bysort _row: egen double _t = total(_atL)
    quietly bysort _row: keep if _n == 1
    quietly count if _c == 0
    return scalar none = r(N)
    quietly count if _c == 1
    return scalar one = r(N)
    quietly count if _c > 1
    return scalar more = r(N)
    quietly count if _c >= 1 & _t > 1
    return scalar ties = r(N)
    if "`lag'" != "" {
        quietly count if _c >= 1 & (`md' - _L) > `lag'
        return scalar stale = r(N)
    }
    restore
end

* window oracle: joinby (all pairs), keep if the window holds, rows per master
* row merged back.  r(none) r(one) r(more) r(pairs) r(joinby)
capture program drop _win_oracle
program define _win_oracle, rclass
    args ufile key ms me ud
    preserve
    quietly generate long _row = _n
    tempfile base kept
    quietly save `"`base'"'
    quietly joinby `key' using `"`ufile'"'
    return scalar joinby = _N
    quietly keep if !missing(`ud') & !missing(`ms') & !missing(`me') & `ud' >= `ms' & `ud' <= `me'
    return scalar pairs = _N
    quietly contract _row, freq(_n_in)
    quietly save `"`kept'"'
    quietly use `"`base'"', clear
    quietly merge 1:1 _row using `"`kept'"', nogenerate
    quietly replace _n_in = 0 if missing(_n_in)
    quietly count if _n_in == 0
    return scalar none = r(N)
    quietly count if _n_in == 1
    return scalar one = r(N)
    quietly count if _n_in > 1
    return scalar more = r(N)
    restore
end

local W "`c(tmpdir)'/dm210ksw"
capture mkdir "`W'"

**# keyset() asof() and window()

**## T01 asof counts equal a joinby oracle (missing dates, ties, absent keys)
capture noisily {
    clear
    set seed 21011
    quietly set obs 400
    generate long id = ceil(runiform() * 60)
    generate double labdate = floor(runiform() * 100)
    quietly replace labdate = . in 1/5
    * exact-date ties: rows 6-40 appear twice
    quietly expand 2 in 6/40
    quietly save "`W'/u1.dta", replace
    clear
    quietly set obs 300
    * ids 61-70 have no file rows
    generate long id = ceil(runiform() * 70)
    generate double index = floor(runiform() * 120)
    quietly replace index = . in 1/4
    _asof_oracle "`W'/u1.dta" id index labdate 30
    local o_none = r(none)
    local o_one = r(one)
    local o_more = r(more)
    local o_ties = r(ties)
    local o_stale = r(stale)
    assert `o_none' + `o_one' + `o_more' == 300
    assert `o_ties' > 0 & `o_stale' > 0 & `o_none' > 4 & `o_more' > 0
    dataprobe, gatesonly keyset(id using "`W'/u1.dta", asof(index labdate) maxlag(30))
    assert r(keyset_link_none) == `o_none'
    assert r(keyset_link_one) == `o_one'
    assert r(keyset_link_more) == `o_more'
    assert r(keyset_link_ties) == `o_ties'
    assert r(keyset_link_stale) == `o_stale'
    assert missing(r(keyset_link_pairs))
    * no mode word: no key-set verdict, only the review item
    assert r(n_checks) == 0 & r(n_reviews) == 1 & r(n_violations) == 0
    * the data in memory are untouched
    assert _N == 300
}
_t `=_rc' "T01 asof(): none/one/more/ties/stale equal joinby+unmatched(master) per-row counts"

**## T02 window counts and joinby pairs equal a joinby + keep-if oracle
capture noisily {
    clear
    set seed 21012
    quietly set obs 500
    generate long id = ceil(runiform() * 50)
    generate double dispdate = floor(runiform() * 200)
    quietly replace dispdate = . in 1/3
    quietly expand 2 in 4/20
    quietly save "`W'/u2.dta", replace
    clear
    quietly set obs 250
    generate long id = ceil(runiform() * 55)
    generate double start = floor(runiform() * 180)
    generate double stop = start + floor(runiform() * 40)
    * inverted windows and missing bounds
    quietly replace stop = start - 5 in 1/10
    quietly replace start = . in 11/13
    quietly replace stop = . in 14/15
    _win_oracle "`W'/u2.dta" id start stop dispdate
    local o_none = r(none)
    local o_one = r(one)
    local o_more = r(more)
    local o_pairs = r(pairs)
    local o_jb = r(joinby)
    assert `o_none' + `o_one' + `o_more' == 250
    assert `o_more' > 0 & `o_jb' > `o_pairs'
    dataprobe, gatesonly keyset(id using "`W'/u2.dta", window(start stop dispdate))
    assert r(keyset_link_none) == `o_none'
    assert r(keyset_link_one) == `o_one'
    assert r(keyset_link_more) == `o_more'
    assert r(keyset_link_pairs) == `o_pairs'
    assert r(keyset_link_joinby) == `o_jb'
    assert missing(r(keyset_link_ties)) & missing(r(keyset_link_stale))
}
_t `=_rc' "T02 window(): none/one/more, pairs kept and joinby pairs equal joinby + keep-if-window"

**## T03 one-day window, a date named alike on both sides, missing keys are keys
capture noisily {
    clear
    quietly input id date
    1 10
    1 10
    1 20
    . 5
    . 30
    2 7
    end
    quietly save "`W'/u3.dta", replace
    clear
    quietly input id date
    1 10
    1 15
    1 25
    . 6
    . 4
    3 9
    end
    * by hand: asof(date date): id1@10 -> 2 rows at 10 (more, tied);
    * id1@15 -> more, tied; id1@25 -> 3 rows, latest 20 once (more);
    * .@6 -> 5 (one); .@4 -> none; 3@9 -> none
    dataprobe, gatesonly keyset(id using "`W'/u3.dta", asof(date date))
    assert r(keyset_link_none) == 2 & r(keyset_link_one) == 1 & r(keyset_link_more) == 3
    assert r(keyset_link_ties) == 2
    preserve
    rename date mdate
    _asof_oracle "`W'/u3.dta" id mdate date
    assert r(none) == 2 & r(one) == 1 & r(more) == 3 & r(ties) == 2
    restore
    * window(date date date): the one-day window [date, date]
    * id1@10 -> 2 rows (more); id1@15 -> 0; id1@25 -> 0; .@6 -> 0; .@4 -> 0; 3@9 -> 0
    dataprobe, gatesonly keyset(id using "`W'/u3.dta", window(date date date))
    assert r(keyset_link_none) == 5 & r(keyset_link_one) == 0 & r(keyset_link_more) == 1
    assert r(keyset_link_pairs) == 2
    * joinby pairs: id1 3x3 + missing 2x2 = 13 (joinby matches missing keys)
    assert r(keyset_link_joinby) == 13
    preserve
    rename date mdate
    quietly joinby id using "`W'/u3.dta"
    assert _N == 13
    restore
}
_t `=_rc' "T03 one-day window(d d u), same-name dates, missing key values link like joinby"

**## T04 records: a review row always, gate rows per threshold, verdict only with a mode
capture noisily {
    clear
    quietly input long id double labdate
    1 10
    2 10
    2 20
    3 10
    3 10
    end
    quietly save "`W'/u4.dta", replace
    clear
    quietly input long id double index
    1 15
    2 25
    3 15
    4 15
    end
    * by hand: id1 one; id2 more; id3 more and tied; id4 none (and absent)
    * shares: none .25, more .5, ties .25; stale (maxlag 7): id1 15-10=5 no,
    * id2 25-20=5 no, id3 5 no -> 0
    capture erase "`W'/l4.dta"
    dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) maxlag(7) ///
        maxnone(0.25) maxmulti(0.4) maxties(0.3) maxstale(0)) warn ledger("`W'/l4.dta")
    assert r(n_violations) == 1 & r(n_checks) == 1 & r(n_reviews) == 1
    assert "`r(failed_checks)'" == "keyset"
    _row "`W'/l4.dta" keyset "id asof(index labdate)"
    assert r(n) == 1 & "`r(st)'" == "review" & !missing(r(num)) & reldif(r(num), 0.25) < 1e-12
    assert "`r(obs)'" == "none 1 (25.0%); one 1 (25.0%); more 2 (50.0%); ties 1 (25.0%); older than 7 0 (0.0%)"
    * a share equal to its threshold passes
    _row "`W'/l4.dta" keyset "id asof(index labdate) maxnone"
    assert r(n) == 1 & "`r(st)'" == "pass" & "`r(exp)'" == "<= 25%"
    _row "`W'/l4.dta" keyset "id asof(index labdate) maxmulti"
    assert r(n) == 1 & "`r(st)'" == "warn" & !missing(r(num)) & reldif(r(num), 0.5) < 1e-12
    assert strpos(`"`r(msg)'"', "more 2 (50.0%) of 4 rows, expected <= 40%") > 0
    _row "`W'/l4.dta" keyset "id asof(index labdate) maxties"
    assert r(n) == 1 & "`r(st)'" == "pass"
    _row "`W'/l4.dta" keyset "id asof(index labdate) maxstale"
    assert r(n) == 1 & "`r(st)'" == "pass"
    * no verdict row without a mode word
    _row "`W'/l4.dta" keyset "id"
    assert r(n) == 0
    * with subset the key-set verdict runs: id 4 is not in the file
    capture erase "`W'/l4b.dta"
    dataprobe, gatesonly keyset(id using "`W'/u4.dta", subset asof(index labdate)) warn ledger("`W'/l4b.dta")
    assert r(n_violations) == 1
    _row "`W'/l4b.dta" keyset "id"
    assert r(n) == 1 & "`r(st)'" == "warn" & strpos("`r(exp)'", "subset") == 1
    * a failing gate halts without warn (exit 9)
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) maxnone(0.1))
    assert _rc == 9
}
_t `=_rc' "T04 ledger: review row, maxnone/maxmulti/maxties/maxstale gates (equal share passes), verdict only with a mode"

**## T05 masking (asof): partition secondary suppression, ties, no dates printed
capture noisily {
    * 100 master rows, one per key, index 01jun2020; keys 1-3 have no file
    * row (none 3), keys 4-10 one row (one 7), keys 11-100 two or more (90);
    * keys 11-12 have their latest date twice (ties 2)
    clear
    quietly set obs 100
    generate long id = _n
    generate double index = mdy(6, 1, 2020)
    format index %td
    quietly save "`W'/m5.dta", replace
    clear
    quietly set obs 97
    generate long id = _n + 3
    generate double labdate = mdy(1, 15, 2020)
    quietly expand 2 if id >= 11
    quietly bysort id: replace labdate = mdy(3, 10, 2020) if _n == 2
    quietly expand 2 if id <= 12 & labdate == mdy(3, 10, 2020)
    format labdate %td
    quietly save "`W'/u5.dta", replace
    use "`W'/m5.dta", clear
    _asof_oracle "`W'/u5.dta" id index labdate
    assert r(none) == 3 & r(one) == 7 & r(more) == 90 & r(ties) == 2
    capture erase "`W'/l5.dta"
    capture log close t05
    log using "`W'/t05.log", text replace name(t05)
    dataprobe, gatesonly keyset(id using "`W'/u5.dta", asof(index labdate) maxnone(0.5)) ///
        maskrare mincell(5) ledger("`W'/l5.dta")
    * log close clears r(): read it first.  Raw r() is unmasked
    assert r(keyset_link_none) == 3 & r(keyset_link_one) == 7 & r(keyset_link_ties) == 2
    log close t05
    _cnt "`W'/t05.log" "none <5 ([masked]), one [suppressed] ([masked]), more 90 (90.0%)"
    assert r(n) == 1
    _cnt "`W'/t05.log" "latest labdate tied: <5 ([masked])"
    assert r(n) == 1
    * no date, formatted or numeric, reaches the log
    foreach needle in "2020" "01jun" "15jan" "10mar" "22067" "21929" "21984" {
        _cnt "`W'/t05.log" "`needle'"
        assert r(n) == 0
    }
    _row "`W'/l5.dta" keyset "id asof(index labdate)"
    assert r(n) == 1 & r(om) == 1 & missing(r(num))
    assert strpos("`r(obs)'", "one [suppressed]") > 0 & strpos("`r(obs)'", " 7 ") == 0
    _row "`W'/l5.dta" keyset "id asof(index labdate) maxnone"
    assert r(n) == 1 & "`r(st)'" == "pass" & r(om) == 1 & missing(r(num))
    * minshown never names a count below the mask
    preserve
    quietly use "`W'/l5.dta", clear
    quietly count if minshown >= 1 & minshown < 5
    assert r(N) == 0
    restore
}
_t `=_rc' "T05 maskrare asof: a lone small cell withholds the next, ties masked, no date printed, ledger masked"

**## T06 masking (window): pair counts withheld beside a withheld count, shown otherwise
capture noisily {
    clear
    quietly set obs 100
    generate long id = _n
    generate double s = 0
    generate double e = 100
    quietly save "`W'/m6.dta", replace
    * every key has 2 file rows inside the window: none 0, one 0, more 100
    clear
    quietly set obs 100
    generate long id = _n
    generate double d = 50
    quietly expand 2
    quietly save "`W'/u6.dta", replace
    use "`W'/m6.dta", clear
    capture log close t06
    log using "`W'/t06.log", text replace name(t06)
    dataprobe, gatesonly keyset(id using "`W'/u6.dta", window(s e d)) maskrare mincell(5)
    log close t06
    _cnt "`W'/t06.log" "joinby id would create 200 pairs; 200 inside the window"
    assert r(n) == 1
    * three rows lose their file rows: none 3 (masked), so the pairs are withheld
    quietly replace s = 60 in 1/3
    capture log close t06
    log using "`W'/t06b.log", text replace name(t06)
    dataprobe, gatesonly keyset(id using "`W'/u6.dta", window(s e d)) maskrare mincell(5)
    local kn = r(keyset_link_none)
    local kp = r(keyset_link_pairs)
    log close t06
    assert `kn' == 3 & `kp' == 194
    _cnt "`W'/t06b.log" "joinby id would create [suppressed] pairs; [suppressed] inside the window"
    assert r(n) == 1
    _cnt "`W'/t06b.log" "194"
    assert r(n) == 0
}
_t `=_rc' "T06 maskrare window: pair counts shown when nothing is withheld, [suppressed] beside a small cell"

**## T07 edges: empty sample, all-missing dates on either side, one key
capture noisily {
    clear
    quietly input long id double d
    1 5
    1 6
    end
    quietly save "`W'/u7.dta", replace
    clear
    quietly input long id double m
    1 10
    1 2
    end
    * one key: m=10 -> 2 candidates; m=2 -> none
    dataprobe, gatesonly keyset(id using "`W'/u7.dta", asof(m d))
    assert r(keyset_link_none) == 1 & r(keyset_link_more) == 1 & r(keyset_link_one) == 0
    * all-missing master dates: every row none
    preserve
    quietly replace m = .
    dataprobe, gatesonly keyset(id using "`W'/u7.dta", asof(m d))
    assert r(keyset_link_none) == 2
    restore
    * empty sample: counts 0, a threshold fails closed
    capture erase "`W'/l7.dta"
    * (an empty sample runs its gates with snapshot(), as in 2.0.0)
    dataprobe if 0, gatesonly keyset(id using "`W'/u7.dta", asof(m d) maxnone(1)) warn ///
        ledger("`W'/l7.dta") snapshot(kw_s, replace)
    assert r(keyset_link_none) == 0 & r(keyset_link_one) == 0 & r(keyset_link_more) == 0
    assert r(n_violations) == 1
    local nv7 = r(n_violations)
    dataprobe if 0, gatesonly keyset(id using "`W'/u7.dta", window(m m d)) snapshot(kw_s, replace)
    assert r(keyset_link_none) == 0 & r(keyset_link_pairs) == 0 & r(keyset_link_joinby) == 0
    _row "`W'/l7.dta" keyset "id asof(m d) maxnone"
    assert r(n) == 1 & "`r(st)'" == "warn" & "`r(obs)'" == "no rows in memory"
    * all-missing file dates: nothing is ever a candidate
    preserve
    use "`W'/u7.dta", clear
    quietly replace d = .
    quietly save "`W'/u7b.dta", replace
    restore
    dataprobe, gatesonly keyset(id using "`W'/u7b.dta", window(m m d))
    assert r(keyset_link_none) == 2 & r(keyset_link_pairs) == 0 & r(keyset_link_joinby) == 4
}
_t `=_rc' "T07 edges: one key, all-missing master or file dates, empty sample fails a threshold closed"

**## T08 strL keys stop the link; hostile string keys link like joinby
capture noisily {
    clear
    quietly set obs 6
    generate str12 sid = ""
    quietly replace sid = "a" + char(34) + "b" in 1
    quietly replace sid = "c'd" in 2
    quietly replace sid = char(36) + "x" in 3
    quietly replace sid = char(96) + "y" in 4
    quietly replace sid = "{z}" in 5
    quietly replace sid = "" in 6
    generate double ud = _n
    quietly expand 2 in 1/2
    quietly save "`W'/u8.dta", replace
    clear
    quietly set obs 7
    generate str12 sid = ""
    quietly replace sid = "a" + char(34) + "b" in 1
    quietly replace sid = "c'd" in 2
    quietly replace sid = char(36) + "x" in 3
    quietly replace sid = char(96) + "y" in 4
    quietly replace sid = "{z}" in 5
    quietly replace sid = "" in 6
    quietly replace sid = "q" in 7
    generate double md = 10
    _asof_oracle "`W'/u8.dta" sid md ud
    local o_none = r(none)
    local o_one = r(one)
    local o_more = r(more)
    local o_ties = r(ties)
    assert `o_none' == 1 & `o_more' == 2 & `o_ties' == 2
    dataprobe, gatesonly keyset(sid using "`W'/u8.dta", asof(md ud))
    assert r(keyset_link_none) == `o_none' & r(keyset_link_one) == `o_one'
    assert r(keyset_link_more) == `o_more' & r(keyset_link_ties) == `o_ties'
    * a strL key: the entry fails before any count; the link is not run
    quietly generate strL lid = sid
    preserve
    use "`W'/u8.dta", clear
    quietly generate strL lid = sid
    quietly save "`W'/u8l.dta", replace
    restore
    capture log close t08
    log using "`W'/t08.log", text replace name(t08)
    capture noisily dataprobe, gatesonly keyset(lid using "`W'/u8l.dta", asof(md ud)) warn
    assert _rc == 0 & r(n_violations) == 1 & missing(r(keyset_link_none))
    log close t08
    _cnt "`W'/t08.log" "asof(): not run; the keys cannot be joined"
    assert r(n) == 1
}
_t `=_rc' "T08 hostile string keys (quote, apostrophe, dollar, backtick, braces, blank) match the oracle; a strL key stops the link"

**## T09 keyset() suboption errors
capture noisily {
    clear
    quietly input long id double index
    1 15
    end
    generate str5 sdate = "x"
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) window(index index labdate))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", window(index index labdate) maxties(0))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) maxstale(0.1))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) maxnone(1.5))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) maxlag(-2))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", subset equal asof(index labdate))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index id))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", maxnone(0.1))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index labdate) bogus(1))
    assert _rc == 198
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(sdate labdate))
    assert _rc == 109
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(nosuch labdate))
    assert _rc == 111
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", asof(index nosuch))
    assert _rc == 111
    * a string date in the file
    preserve
    use "`W'/u4.dta", clear
    quietly tostring labdate, replace
    quietly save "`W'/u9s.dta", replace
    restore
    capture dataprobe, gatesonly keyset(id using "`W'/u9s.dta", asof(index labdate))
    assert _rc == 109
    * the 1.x message and code for a bad mode word are unchanged
    capture dataprobe, gatesonly keyset(id using "`W'/u4.dta", sideways)
    assert _rc == 198
}
_t `=_rc' "T09 keyset() errors: arity, both links, asof-only options, ranges, two modes, key as date, types, names"

**## T10 checks() keyset row with a suboption; a quoted path with a space and a comma
capture noisily {
    clear
    quietly input long id double labdate
    1 10
    2 10
    end
    quietly save "`W'/u 10,a.dta", replace
    clear
    quietly input long id double index
    1 15
    2 5
    3 5
    end
    dataprobe, gatesonly keyset(id using "`W'/u 10,a.dta", asof(index labdate))
    assert r(keyset_link_none) == 2 & r(keyset_link_one) == 1
    preserve
    clear
    quietly set obs 1
    generate str12 gate = "keyset"
    generate str20 var = "id"
    generate str40 pattern = ""
    generate str244 values = "`W'/u 10,a.dta"
    generate str80 arg1 = "asof(index labdate) maxnone(0.5)"
    generate str10 arg2 = ""
    generate str8 kind = ""
    quietly save "`W'/chk10.dta", replace
    restore
    dataprobe, gatesonly checks("`W'/chk10.dta") warn
    assert r(keyset_link_none) == 2 & r(n_violations) == 1
}
_t `=_rc' "T10 checks() keyset row carries asof() and a threshold; quoted path with space and comma"

**# reconcile()

**## T11 rows, distinct ids and totals equal an independent count; expect eq/le/ge
capture noisily {
    clear
    set seed 21013
    quietly set obs 300
    generate long pid = ceil(runiform() * 120)
    quietly replace pid = . in 1/3
    generate double cost = round(runiform() * 1000, 0.01)
    quietly replace cost = . in 4/6
    generate int visits = ceil(runiform() * 5)
    quietly save "`W'/c11.dta", replace
    * oracle on the file: rows, distinct nonmissing pid, totals
    quietly count
    local fn = r(N)
    preserve
    quietly keep if !missing(pid)
    quietly contract pid
    local fi = _N
    restore
    quietly summarize cost, meanonly
    local fs = r(sum)
    * an exclusion step: drop 40 rows
    quietly drop if _n > 260
    quietly count
    local mn = r(N)
    preserve
    quietly keep if !missing(pid)
    quietly contract pid
    local mi = _N
    restore
    quietly summarize cost, meanonly
    local ms = r(sum)
    capture erase "`W'/l11.dta"
    dataprobe, gatesonly reconcile("`W'/c11.dta", n ids(pid) sum(cost visits) expect(le)) ledger("`W'/l11.dta")
    assert r(reconcile_rows_delta) == `mn' - `fn'
    assert r(reconcile_ids_delta) == `mi' - `fi'
    assert r(n_violations) == 0
    local dsum = `ms' - `fs'
    assert !missing(`dsum')
    _row "`W'/l11.dta" reconcile "c11 sum(cost)"
    assert r(n) == 1 & "`r(st)'" == "pass" & !missing(r(num)) & reldif(r(num), `dsum') < 1e-9
    _row "`W'/l11.dta" reconcile "c11 rows"
    assert r(n) == 1 & r(num) == -40
    * eq fails on the rows; ge fails too; le passes (above)
    capture dataprobe, gatesonly reconcile("`W'/c11.dta", n)
    assert _rc == 9
    capture dataprobe, gatesonly reconcile("`W'/c11.dta", expect(ge))
    assert _rc == 9
    * the full file reconciles with eq
    use "`W'/c11.dta", clear
    dataprobe, gatesonly reconcile("`W'/c11.dta", n ids(pid) sum(cost visits))
    assert r(n_violations) == 0 & r(reconcile_rows_delta) == 0 & r(reconcile_ids_delta) == 0
    * ge after adding rows
    quietly expand 2 in 1/5
    dataprobe, gatesonly reconcile("`W'/c11.dta", expect(ge))
    assert r(reconcile_rows_delta) == 5 & missing(r(reconcile_ids_delta))
}
_t `=_rc' "T11 reconcile(): rows/ids/sums against contract+summarize oracle; eq/le/ge verdicts"

**## T12 by(): failing groups equal a collapse+merge oracle, groups on one side only
capture noisily {
    clear
    set seed 21014
    quietly set obs 400
    generate byte region = ceil(runiform() * 6)
    label define reg 1 "North" 2 "South" 3 "East" 4 "West" 5 "Central" 6 "Islands"
    label values region reg
    generate long pid = ceil(runiform() * 150)
    generate double amt = ceil(runiform() * 100)
    quietly save "`W'/c12.dta", replace
    * memory: drop region 6 entirely, 10 rows of region 2, add a region 7 row
    quietly drop if region == 6
    quietly drop if region == 2 & _n <= 60
    quietly set obs `=_N + 1'
    quietly replace region = 7 in L
    quietly replace pid = 999 in L
    quietly replace amt = 5 in L
    * oracle: rows and totals per region on each side, merged; le fails where
    * memory exceeds the file
    preserve
    generate one = 1
    collapse (sum) mn = one ms = amt, by(region)
    tempfile mm
    quietly save `"`mm'"'
    use "`W'/c12.dta", clear
    generate one = 1
    collapse (sum) fn = one fs = amt, by(region)
    quietly merge 1:1 region using `"`mm'"', nogenerate
    foreach v in mn ms fn fs {
        quietly replace `v' = 0 if missing(`v')
    }
    local G = _N
    quietly count if mn != fn
    local o_eq_rows = r(N)
    quietly count if mn > fn
    local o_le_rows = r(N)
    quietly count if ms > fs
    local o_le_sum = r(N)
    restore
    assert `G' == 7 & `o_eq_rows' >= 3 & `o_le_rows' == 1
    capture erase "`W'/l12.dta"
    capture log close t12
    log using "`W'/t12.log", text replace name(t12)
    dataprobe, gatesonly reconcile("`W'/c12.dta", n sum(amt) by(region) expect(le)) warn ledger("`W'/l12.dta")
    log close t12
    _row "`W'/l12.dta" reconcile "c12 rows by(region)"
    assert r(n) == 1 & "`r(st)'" == "warn" & r(num) == `o_le_rows'
    assert "`r(obs)'" == "`o_le_rows' of `G' groups fail"
    _row "`W'/l12.dta" reconcile "c12 sum(amt) by(region)"
    assert r(n) == 1 & r(num) == `o_le_sum'
    * overall rows pass le; the failing group prints by its label
    _row "`W'/l12.dta" reconcile "c12 rows"
    assert r(n) == 1 & "`r(st)'" == "pass"
    _cnt "`W'/t12.log" "    7: rows 1 more; sum amt more"
    assert r(n) == 0
    _cnt "`W'/t12.log" "    7: rows 1 more; sum amt higher"
    assert r(n) == 1
    capture erase "`W'/l12b.dta"
    dataprobe, gatesonly reconcile("`W'/c12.dta", by(region)) warn ledger("`W'/l12b.dta")
    _row "`W'/l12b.dta" reconcile "c12 rows by(region)"
    assert r(n) == 1 & r(num) == `o_eq_rows'
    * ids() with by(): a person in two regions is one id overall; per group
    * the distinct pids of that group (contract on pid, and on region pid)
    preserve
    quietly contract pid
    local o_mi = _N
    restore
    preserve
    quietly contract region pid
    quietly contract region, freq(mi)
    tempfile mi
    quietly save `"`mi'"'
    use "`W'/c12.dta", clear
    quietly contract pid
    local o_fi = _N
    use "`W'/c12.dta", clear
    quietly contract region pid
    quietly contract region, freq(fi)
    quietly merge 1:1 region using `"`mi'"', nogenerate
    quietly replace mi = 0 if missing(mi)
    quietly replace fi = 0 if missing(fi)
    quietly count if mi != fi
    local o_eq_ids = r(N)
    restore
    capture erase "`W'/l12c.dta"
    dataprobe, gatesonly reconcile("`W'/c12.dta", ids(pid) by(region)) warn ledger("`W'/l12c.dta")
    assert r(reconcile_ids_delta) == `o_mi' - `o_fi'
    _row "`W'/l12c.dta" reconcile "c12 ids(pid) by(region)"
    assert r(n) == 1 & r(num) == `o_eq_ids'
}
_t `=_rc' "T12 reconcile by(): failing-group counts equal collapse+merge; one-sided groups count zero; labels print"

**## T13 tol(): a relative tolerance for totals only
capture noisily {
    clear
    quietly set obs 10
    generate double x = 1000
    generate long id = _n
    quietly save "`W'/c13.dta", replace
    * the total 10000 moves by 0.5 (5e-5 relative)
    quietly replace x = 1000.5 in 1
    dataprobe, gatesonly reconcile("`W'/c13.dta", sum(x) tol(1e-4))
    assert r(n_violations) == 0
    capture dataprobe, gatesonly reconcile("`W'/c13.dta", sum(x) tol(1e-5))
    assert _rc == 9
    capture dataprobe, gatesonly reconcile("`W'/c13.dta", sum(x))
    assert _rc == 9
    * le: memory above the file by less than tol passes
    dataprobe, gatesonly reconcile("`W'/c13.dta", sum(x) expect(le) tol(1e-4))
    assert r(n_violations) == 0
    * tol never loosens a count
    quietly drop in 10
    capture dataprobe, gatesonly reconcile("`W'/c13.dta", n ids(id) tol(0.5))
    assert _rc == 9
}
_t `=_rc' "T13 tol(): totals within tol x |file total| pass, outside fail; counts stay exact"

**## T14 masking: count triples, totals as relative differences, small groups unnamed
capture noisily {
    clear
    quietly set obs 100
    generate long id = _n
    generate byte g = cond(_n <= 50, 1, cond(_n <= 97, 2, 3))
    label define gg 1 "alpha" 2 "beta" 3 "gamma"
    label values g gg
    generate double inc = 100 + _n
    quietly save "`W'/c14.dta", replace
    * drop 3 rows of group beta: a small difference
    quietly drop if inlist(_n, 60, 61, 62)
    capture erase "`W'/l14.dta"
    capture log close t14
    log using "`W'/t14.log", text replace name(t14)
    dataprobe, gatesonly reconcile("`W'/c14.dta", n ids(id) sum(inc) by(g)) maskrare mincell(5) ///
        warn ledger("`W'/l14.dta")
    local rd = r(reconcile_rows_delta)
    log close t14
    assert `rd' == -3
    _cnt "`W'/t14.log" "rows: memory [suppressed], c14 [suppressed]; fewer in memory"
    assert r(n) == 1
    _cnt "`W'/t14.log" "sum(inc): relative difference [suppressed] (lower in memory)"
    assert r(n) == 1
    * the group line is a direction only; gamma (3 rows) is never named
    _cnt "`W'/t14.log" "    beta: rows fewer; ids fewer; sum inc lower"
    assert r(n) == 1
    _cnt "`W'/t14.log" "gamma"
    assert r(n) == 0
    foreach needle in " 100" " 97" "3 fewer" "-3" {
        _cnt "`W'/t14.log" "`needle'"
        assert r(n) == 0
    }
    _row "`W'/l14.dta" reconcile "c14 rows"
    assert r(n) == 1 & r(om) == 1 & missing(r(num))
    * a large difference prints; the total stays unprinted under the mask
    use "`W'/c14.dta", clear
    quietly drop if g == 1
    capture log close t14
    log using "`W'/t14b.log", text replace name(t14)
    capture erase "`W'/l14b.dta"
    dataprobe, gatesonly reconcile("`W'/c14.dta", n sum(inc)) maskrare mincell(5) warn ///
        ledger("`W'/l14b.dta")
    log close t14
    _cnt "`W'/t14b.log" "rows: memory 50, c14 100; 50 fewer in memory"
    assert r(n) == 1
    _cnt "`W'/t14b.log" "sum(inc): relative difference"
    assert r(n) == 1
    * 5050 + 100*100 = 15050 in the file: never printed under the mask
    _cnt "`W'/t14b.log" "15050"
    assert r(n) == 0
    * nor stored: the ledger's sum row holds no difference (with the printed
    * relative rate it would give the file's total); the printed row count does
    _row "`W'/l14b.dta" reconcile "c14 sum(inc)"
    assert r(n) == 1 & missing(r(num)) & r(om) == 0
    assert strpos(`"`r(obs)'"', "relative difference") == 1
    _row "`W'/l14b.dta" reconcile "c14 rows"
    assert r(n) == 1 & r(num) == -50 & r(om) == 0
    * without the mask the difference is stored: memory 51+..+100 = 3775 +
    * 50*100 = 8775, file 15050, difference -6275
    use "`W'/c14.dta", clear
    quietly drop if g == 1
    capture erase "`W'/l14e.dta"
    dataprobe, gatesonly reconcile("`W'/c14.dta", n sum(inc)) warn ledger("`W'/l14e.dta")
    _row "`W'/l14e.dta" reconcile "c14 sum(inc)"
    assert r(n) == 1 & r(num) == -6275 & r(om) == 0
    * a small group (3 rows) that fails is counted, not named; under the
    * mask the count of 1 prints as <5 (review 2026-11-17)
    use "`W'/c14.dta", clear
    quietly drop if g == 3 & _n == 100
    capture log close t14
    log using "`W'/t14c.log", text replace name(t14)
    dataprobe, gatesonly reconcile("`W'/c14.dta", n by(g)) maskrare mincell(5) warn
    log close t14
    _cnt "`W'/t14c.log" "groups with fewer than 5 rows on a side (not shown): <5 failing"
    assert r(n) == 1
    _cnt "`W'/t14c.log" "gamma"
    assert r(n) == 0
    * a group with 1..4 rows in the file but 5+ in memory is counted, not
    * named: gamma has 3 rows in the file and 30 in memory (difference 27,
    * which with the memory count would give the file's 3)
    use "`W'/c14.dta", clear
    quietly expand 10 if g == 3
    quietly count if g == 3
    assert r(N) == 30
    capture log close t14
    log using "`W'/t14d.log", text replace name(t14)
    dataprobe, gatesonly reconcile("`W'/c14.dta", n by(g)) maskrare mincell(5) warn
    log close t14
    _cnt "`W'/t14d.log" "groups with fewer than 5 rows on a side (not shown): <5 failing"
    assert r(n) == 1
    _cnt "`W'/t14d.log" "gamma"
    assert r(n) == 0
    _cnt "`W'/t14d.log" "rows 27"
    assert r(n) == 0
}
_t `=_rc' "T14 maskrare reconcile: small deltas withhold the triple, totals relative only, small groups counted not named"

**## T15 reconcile() errors
capture noisily {
    clear
    quietly input long id double x str3 s byte g
    1 1 "a" 1
    2 2 "b" 2
    end
    quietly save "`W'/c15.dta", replace
    capture dataprobe, gatesonly reconcile("`W'/nosuch.dta")
    assert _rc == 601
    generate double y = 1
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", sum(y))
    assert _rc == 111
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", sum(s))
    assert _rc == 109
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", expect(lt))
    assert _rc == 198
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", tol(-1))
    assert _rc == 198
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", ids(id x))
    assert _rc == 198
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", sum(x) by(x))
    assert _rc == 198
    capture dataprobe, gatesonly reconcile("`W'/c15.dta", bogus)
    assert _rc == 198
    capture dataprobe, gatesonly reconcile(, n)
    assert _rc == 198
    * a string in the file where memory has numbers
    preserve
    use "`W'/c15.dta", clear
    quietly tostring x g, replace
    quietly save "`W'/c15s.dta", replace
    restore
    capture dataprobe, gatesonly reconcile("`W'/c15s.dta", sum(x))
    assert _rc == 109
    capture dataprobe, gatesonly reconcile("`W'/c15s.dta", by(g))
    assert _rc == 106
    * a strL by() variable
    quietly generate strL ls = s
    preserve
    use "`W'/c15.dta", clear
    quietly generate strL ls = s
    quietly save "`W'/c15l.dta", replace
    restore
    capture dataprobe, gatesonly reconcile("`W'/c15l.dta", by(ls))
    assert _rc == 106
    * a file that is not a Stata dataset
    tempname fh
    file open `fh' using "`W'/c15.txt", write text replace
    file write `fh' "not a dataset" _n
    file close `fh'
    capture dataprobe, gatesonly reconcile("`W'/c15.txt")
    assert _rc != 0 & _rc != 9
}
_t `=_rc' "T15 reconcile() errors: 601 missing file, 111 missing var, 109 string total, 106 by() kind/strL, 198 spec"

**## T16 frames, data untouched, several entries, quoted paths
capture noisily {
    clear
    quietly set obs 20
    generate long id = _n
    generate double v = _n * 2
    quietly save "`W'/c 16,x.dta", replace
    quietly save "`W'/c16.dta", replace
    capture frame drop kw16
    frame create kw16
    frame kw16 {
        use "`W'/c16.dta", clear
        quietly drop in 1/2
        gsort -v
        quietly datasignature
        local sig0 "`r(datasignature)'"
        local first0 = id[1]
        quietly frames dir
        local nfr0 : word count `r(frames)'
        dataprobe, gatesonly reconcile("`W'/c 16,x.dta", n sum(v) expect(le) \ `W'/c16.dta, ids(id) expect(le)) ///
            warn
        assert r(n_violations) == 0 & r(reconcile_rows_delta) == -2 & r(reconcile_ids_delta) == -2
        quietly datasignature
        assert "`r(datasignature)'" == "`sig0'"
        assert id[1] == `first0'
        quietly frames dir
        assert `: word count `r(frames)'' == `nfr0'
    }
    assert c(frame) == "default"
    frame drop kw16
}
_t `=_rc' "T16 reconcile from a non-default frame: data, sort order and frames untouched; two entries, quoted path"

**## T17 reconcile edges: empty sample, all-missing ids, strL and hostile strings
capture noisily {
    clear
    quietly set obs 8
    generate str10 who = ""
    quietly replace who = "a" + char(34) + "b" in 1
    quietly replace who = "c'd" in 2
    quietly replace who = char(36) + "x" in 3
    quietly replace who = char(96) + "y" in 4
    quietly replace who = "{z}" in 5
    quietly replace who = "{z}" in 6
    generate strL lw = who
    generate long pid = .
    generate double x = 1
    quietly save "`W'/c17.dta", replace
    * empty sample: memory 0 rows; le passes, eq fails
    dataprobe if 0, gatesonly reconcile("`W'/c17.dta", n ids(pid) expect(le)) snapshot(kw_s, replace)
    assert r(reconcile_rows_delta) == -8 & r(reconcile_ids_delta) == 0
    capture dataprobe if 0, gatesonly reconcile("`W'/c17.dta", n) snapshot(kw_s, replace)
    assert _rc == 9
    * strL ids and hostile string groups: 5 distinct nonmissing values (the
    * two blanks are missing), 6 groups with the blank one
    dataprobe, gatesonly reconcile("`W'/c17.dta", ids(lw) by(who) sum(x))
    assert r(n_violations) == 0 & r(reconcile_ids_delta) == 0
    quietly drop in 3
    capture log close t17
    log using "`W'/t17.log", text replace name(t17)
    dataprobe, gatesonly reconcile("`W'/c17.dta", ids(lw) by(who)) warn
    assert r(reconcile_ids_delta) == -1
    log close t17
    _cnt "`W'/t17.log" "by(who): 6 groups, 1 failing"
    assert r(n) == 1
}
_t `=_rc' "T17 reconcile edges: empty sample, all-missing ids, strL ids, hostile group strings"

**## T18 calls without the new options are unchanged in r()
capture noisily {
    use "`W'/u4.dta", clear
    quietly duplicates drop id, force
    quietly save "`W'/u18.dta", replace
    dataprobe, gatesonly keyset(id using "`W'/u18.dta")
    assert r(keyset_matched) == 3 & "`r(keyset_merge)'" == "1:1"
    assert missing(r(keyset_link_none)) & missing(r(reconcile_rows_delta))
    assert "`r(checks_run)'" == "keyset"
}
_t `=_rc' "T18 keyset() without asof()/window() sets no link results and keeps its verdict"

**## T19 a by() variable in exclude(), or safe: failing groups named by number
capture noisily {
    use "`W'/c14.dta", clear
    * 20 rows of beta (group 2 of 3 in sort order) leave
    quietly drop if g == 2 & _n <= 70
    capture log close t19
    log using "`W'/t19.log", text replace name(t19)
    dataprobe, gatesonly reconcile("`W'/c14.dta", n by(g)) exclude(g) warn
    log close t19
    _cnt "`W'/t19.log" "    group 2: rows 20 fewer"
    assert r(n) == 1
    _cnt "`W'/t19.log" "beta"
    assert r(n) == 0
    capture log close t19
    log using "`W'/t19b.log", text replace name(t19)
    dataprobe, gatesonly reconcile("`W'/c14.dta", n by(g)) safe warn
    log close t19
    _cnt "`W'/t19b.log" "    group 2: rows 20 fewer"
    assert r(n) == 1
    _cnt "`W'/t19b.log" "beta"
    assert r(n) == 0
    * without either, the label names the group
    capture log close t19
    log using "`W'/t19c.log", text replace name(t19)
    dataprobe, gatesonly reconcile("`W'/c14.dta", n by(g)) warn
    log close t19
    _cnt "`W'/t19c.log" "    beta: rows 20 fewer"
    assert r(n) == 1
}
_t `=_rc' "T19 reconcile by(): a by() variable in exclude(), or safe, names failing groups by number"

**# Result
capture log close t05
capture log close t06
capture log close t08
capture log close t12
capture log close t14
capture log close t17
capture log close t19
capture frame drop kw16
capture frame drop kw_s
set linesize `_ls0'
if `"`_dq0'"' != "" global DATAMAP_DQ `"`_dq0'"'
local _tc = $KW_TC
local _tp = $KW_PASS
local _tf = $KW_FAIL
macro drop KW_TC KW_PASS KW_FAIL
display as text _newline "RESULT: test_datamap_v210_keyset_window tests=`_tc' pass=`_tp' fail=`_tf'"
if `_tf' > 0 exit 1
