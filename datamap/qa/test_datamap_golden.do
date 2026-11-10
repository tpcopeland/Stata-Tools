clear all
set more off
version 16.0

* test_datamap_golden.do - Normalized golden-output tests for datamap
* Generated: 2026-05-15
* Tests: normalized full-file output equivalence
*
* 2026-11-10, datamap 2.0.0 (Phase 2): datadict and the text/JSON layouts are
* gone, so g1-g7 are regenerated as Markdown from `datamap` calls.  The
* 1.10.6 files (datamap text maps g1-g4, datadict dictionaries g5-g7) are
* frozen in golden/v1/ as the before-picture; nothing reads that directory.
* Case mapping (old call -> new call):
*   g1 datamap, single(test_small)                 -> same call, Markdown
*   g2 datamap, privacy/quality/missing/samples    -> same call, Markdown
*   g3 datamap, append (two calls)                 -> same calls, Markdown
*   g4 datamap, separate filelist (suffix _map)    -> same call, Markdown
*   g5 datadict, single, missing stats             -> datamap, single (Missing
*                                                     and Values are defaults)
*   g6 datadict, document options, date(2026-01-01)-> datamap, ..., docdate()
*   g7 datadict, separate filelist (_dictionary)   -> datamap, separate,
*                                                     suffix(_dictionary) and
*                                                     datadict's detail columns
* Regenerate with: global DATAMAP_UPDATE_GOLDEN 1, then run this file, then
* READ every file in golden/ before accepting it.
* 2026-11-10 (2.0.0 Phase 3, batch A): g2 and g4-g7 regenerated and read.  The
* test_cohort fixtures carry a dataset note, now printed in the header (F2,
* "- Dataset notes:"); date rows name their family ("double %td daily", U4);
* g2's detect section is "Structure (inferred)" and, under autodetect, has no
* binary line (it prints only for detect(binary)).  Nothing else moved; g1,
* g3 and the test_small files are byte-identical.
* 2026-11-10 (2.0.0 Phase 3, batch B): all ten regenerated and read; only g2
* moved: under quality, "### Candidates (not applied)" / "No placeholder
* candidates." follows the Flags (F5).  No golden has two datasets in one
* document, so none carries the Linkage section (F1; test_datamap_v200_link).

* 2026-11-10 (2.0.0 Phase 3 QA): g8 and g9 are new goldens for the Phase 3
* content that no earlier golden carries.  g8: one in-memory dataset with an
* xtset header and a dataset note, coded missing values (listed per code),
* text with numeric text and tokens, padded values, a date-text mask, every
* date family in the Type column, a strL, and quality's candidates (a declared
* 999, a 1960 date and a future date).  g9: two files in one document (the
* Linkage block: a long key against a str12 one, a label defined twice).  Both
* were read before being accepted; they pin layout, the dev suites pin values.
* 2026-11-10 (Phase 3 repair round 1): g9 regenerated; its only change is the
* Linkage intro sentence, now one space after each period (it had two).  Every
* other golden was byte-identical on regeneration.

* The documents have lines that end in a backtick (the Source and Data
* signature lines), and a Stata local holding such a line breaks the
* compound-quote closer ("too few quotes", r(132)), so both the normalizer and
* the comparison read and write the files in Mata and never hold a line in a
* macro.
mata:
void _golden_norm_mata(string scalar src, string scalar dst)
{
    string colvector L
    real scalar i, fh
    L = cat(src)
    for (i = 1; i <= rows(L); i++) {
        // the machine-specific source path
        if (substr(L[i], 1, 11) == "- Source: " + char(96)) L[i] = "- Source: <normalized>"
        // the run date, unless the golden pinned it with docdate()
        else if (regexm(L[i], "^[*][*]Last Updated:[*][*] ") & ///
                 L[i] != "**Last Updated:** 2026-01-01") L[i] = "**Last Updated:** <normalized>"
        // 2026-11-10 (Phase 3 QA): quality's "after <run date> (run date)"
        // candidate carries the day the test runs
        L[i] = regexr(L[i], "after [0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9] [(]run date[)]", "after <run date> (run date)")
    }
    unlink(dst)
    fh = fopen(dst, "w")
    for (i = 1; i <= rows(L); i++) fput(fh, L[i])
    fclose(fh)
}

// 0 = identical and nonempty; otherwise the first differing line number
// (rows+1 when one file is a prefix of the other; -1 when both are empty)
real scalar _golden_cmp_mata(string scalar expfile, string scalar actfile)
{
    string colvector E, A
    real scalar i, n
    E = cat(expfile)
    A = cat(actfile)
    if (rows(E) == 0 & rows(A) == 0) return(-1)
    n = min((rows(E), rows(A)))
    for (i = 1; i <= n; i++) {
        if (E[i] != A[i]) {
            st_local("exp_line", E[i])
            st_local("act_line", A[i])
            return(i)
        }
    }
    if (rows(E) != rows(A)) {
        st_local("exp_line", (rows(E) >= i ? E[i] : "<EOF>"))
        st_local("act_line", (rows(A) >= i ? A[i] : "<EOF>"))
        return(i)
    }
    return(0)
}
end

capture program drop _golden_normalize
program define _golden_normalize
    version 16.0
    syntax using/ , Saving(string)
    mata: _golden_norm_mata(st_local("using"), st_local("saving"))
end

capture program drop _golden_compare
program define _golden_compare
    version 16.0
    syntax , Expected(string) Actual(string) Name(string)

    local exp_line ""
    local act_line ""
    mata: st_numscalar("__golden_rc", _golden_cmp_mata(st_local("expected"), st_local("actual")))
    local diff = scalar(__golden_rc)
    scalar drop __golden_rc
    if `diff' == -1 {
        noisily display as error `"Golden is empty: `name'"'
        exit 9
    }
    if `diff' > 0 {
        noisily display as error `"Golden mismatch: `name'"'
        noisily display as error "Line `diff'"
        mata: printf("Expected: %s\n", st_local("exp_line"))
        mata: printf("Actual:   %s\n", st_local("act_line"))
        exit 9
    }
end

capture program drop _golden_check
program define _golden_check
    version 16.0
    syntax , Name(string) Raw(string) Norm(string) Expected(string)

    _golden_normalize using `"`raw'"', saving(`"`norm'"')

    if `"$DATAMAP_UPDATE_GOLDEN"' == "1" {
        copy `"`norm'"' `"`expected'"', replace
        noisily display as result `"  UPDATED: `name'"'
    }
    else {
        _golden_compare, expected(`"`expected'"') actual(`"`norm'"') name(`"`name'"')
        noisily display as result `"  PASS: `name'"'
    }
end

* ============================================================
* Setup
* ============================================================

local qa_dir     "`c(pwd)'"
local pkg_dir    "`qa_dir'/.."
local data_dir   "`qa_dir'/data"
local golden_dir "`qa_dir'/golden"

capture mkdir "`golden_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

tempname tmpstub
local tmp_dir "`c(tmpdir)'/datamap_golden_`tmpstub'"
capture mkdir "`tmp_dir'"

local test_count 0

* ============================================================
* Golden cases g1-g7 (all Markdown, all datamap)
* ============================================================

local ++test_count
local raw  "`tmp_dir'/g1_datamap_default.md"
local norm "`tmp_dir'/g1_datamap_default.norm.md"
quietly datamap, single("`data_dir'/test_small") output("`raw'")
_golden_check, name("G1 datamap single default") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g1_datamap_default.md")

local ++test_count
local raw  "`tmp_dir'/g2_datamap_full.md"
local norm "`tmp_dir'/g2_datamap_full.norm.md"
quietly datamap, single("`data_dir'/test_cohort_miss") output("`raw'") ///
    exclude(id name) datesafe autodetect quality missing(pattern) samples(3)
_golden_check, name("G2 full datamap privacy quality missing samples") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g2_datamap_full.md")

* 2026-11-10: g3 first pinned the second call's section as "## 1.
* test_single" (numbering restarted at 1: duplicate heading and anchor;
* Phase 2 review note 6).  Fixed the same day (append continues from the
* file's last "## <n>. " heading): g3 regenerated and read, the only change
* "## 2. test_single".  g2 regenerated the same day for the pattern fix
* (complementary suppression now also holds against the Missing column:
* `+++`, `..+` and Complete rows withheld; age 10 - `..+` 6 no longer gives
* the suppressed `.++` 4).
* 2026-11-10 (repair round 2): g4, g5, g6 and g7 (test_cohort) regenerated
* and diffed against the previous goldens: the one change in each is id's
* "range=1.00-100" -> "range=1.00-100.00" (both ends of a pair now print
* with one number of decimals).  The Missing-cell mincell rule changed no
* golden: no golden variable has 1-4 missing or 1-4 nonmissing rows.

local ++test_count
local raw  "`tmp_dir'/g3_datamap_append.md"
local norm "`tmp_dir'/g3_datamap_append.norm.md"
quietly datamap, single("`data_dir'/test_small") output("`raw'")
quietly datamap, single("`data_dir'/test_single") output("`raw'") append
_golden_check, name("G3 datamap append two calls") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g3_datamap_append.md")

local sep_dir "`tmp_dir'/separate_datamap"
capture mkdir "`sep_dir'"
capture erase "`sep_dir'/test_cohort.dta"
capture erase "`sep_dir'/test_small.dta"
copy "`data_dir'/test_cohort.dta" "`sep_dir'/test_cohort.dta"
copy "`data_dir'/test_small.dta" "`sep_dir'/test_small.dta"
quietly datamap, filelist("`sep_dir'/test_cohort" "`sep_dir'/test_small") separate

local ++test_count
local raw  "`sep_dir'/test_cohort_map.md"
local norm "`tmp_dir'/g4_datamap_separate_test_cohort.norm.md"
_golden_check, name("G4 datamap separate filelist test_cohort") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g4_datamap_separate_test_cohort_map.md")

local ++test_count
local raw  "`sep_dir'/test_small_map.md"
local norm "`tmp_dir'/g4_datamap_separate_test_small.norm.md"
_golden_check, name("G4 datamap separate filelist test_small") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g4_datamap_separate_test_small_map.md")

* 2026-11-10, datamap 2.0.0 Phase 1 (percent-denominator rule): a category's
* share is of every row, missing ones included, from the collector's levels
* frame, as datamap's text map always printed.  g5 and g6 carry that rule:
* region (6 of 100 missing) reads "1 North: 21 (21.0%)" where 1.10.6 datadict
* read "(21; 22.3%)" (of the 94 nonmissing).

local ++test_count
local raw  "`tmp_dir'/g5_datamap_basic.md"
local norm "`tmp_dir'/g5_datamap_basic.norm.md"
quietly datamap, single("`data_dir'/test_cohort_miss") output("`raw'")
_golden_check, name("G5 basic datamap single (Missing and Values defaults)") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g5_datamap_basic.md")

local ++test_count
local raw  "`tmp_dir'/g6_datamap_document.md"
local norm "`tmp_dir'/g6_datamap_document.norm.md"
quietly datamap, single("`data_dir'/test_cohort_miss") output("`raw'") ///
    title("MS Cohort") subtitle("Golden data dictionary") ///
    version("2.0") author("Timothy P Copeland, Karolinska Institutet") ///
    docdate("2026-01-01") notes("Golden notes for refactor safety.") ///
    changelog("v2.0: Golden harness baseline")
_golden_check, name("G6 full datamap document options explicit docdate") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g6_datamap_document.md")

local sep_dd_dir "`tmp_dir'/separate_dictionary"
capture mkdir "`sep_dd_dir'"
capture erase "`sep_dd_dir'/test_cohort.dta"
capture erase "`sep_dd_dir'/test_small.dta"
copy "`data_dir'/test_cohort.dta" "`sep_dd_dir'/test_cohort.dta"
copy "`data_dir'/test_small.dta" "`sep_dd_dir'/test_small.dta"
quietly datamap, filelist("`sep_dd_dir'/test_cohort" "`sep_dd_dir'/test_small") ///
    separate suffix(_dictionary) ///
    columns(variable label type format vallabel missing values notes chars)

local ++test_count
local raw  "`sep_dd_dir'/test_cohort_dictionary.md"
local norm "`tmp_dir'/g7_datamap_separate_test_cohort.norm.md"
_golden_check, name("G7 datamap separate suffix and detail columns test_cohort") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g7_datamap_separate_test_cohort_dictionary.md")

local ++test_count
local raw  "`sep_dd_dir'/test_small_dictionary.md"
local norm "`tmp_dir'/g7_datamap_separate_test_small.norm.md"
_golden_check, name("G7 datamap separate suffix and detail columns test_small") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g7_datamap_separate_test_small_dictionary.md")

* ============================================================
* Golden cases g8-g9 (Phase 3 content)
* ============================================================

* g8: everything built in memory, no random numbers
clear
quietly set obs 120
generate int firm = ceil(_n / 6)
generate int year = 2000 + mod(_n - 1, 6)
format year %ty
generate byte edu = 1 + mod(_n, 3)
quietly replace edu = . in 1/9
quietly replace edu = .a in 10/27
quietly replace edu = .b in 28/33
label define edul 1 "Primary" 2 "Secondary" 3 "Tertiary" .a "Refused" .b "Not asked"
label values edu edul
generate double bmi = 20 + mod(_n, 19) / 2
quietly replace bmi = 999 in 1/12
generate str8 income_s = string(1000 + _n)
quietly replace income_s = "NA" in 1/14
quietly replace income_s = "na" in 15/22
quietly replace income_s = " " + income_s in 40/49
generate str10 dstr = "2020-03-" + string(10 + mod(_n, 15))
generate str6 sex = cond(mod(_n, 2), "Male", "Female")
generate long admit = mdy(1, 1, 2015) + _n
quietly replace admit = mdy(1, 1, 1960) in 1/6
quietly replace admit = mdy(6, 1, 2090) in 7/13
format admit %td
generate double stamp = clock("2015-01-01 08:00", "YMDhm") + _n * 3600000
format stamp %tc
generate int mo = ym(2015, 1) + _n
format mo %tm
generate strL memo = "memo " + string(mod(_n, 4))
notes: golden note for the state header
xtset firm year

local ++test_count
local raw  "`tmp_dir'/g8_datamap_content.md"
local norm "`tmp_dir'/g8_datamap_content.norm.md"
quietly datamap, output("`raw'") quality placeholders(999) autodetect
_golden_check, name("G8 datamap Phase 3 content (state, codes, strings, types, candidates)") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g8_datamap_content.md")

* g9: two files in one document
clear
quietly set obs 12
generate long id = _n
generate byte sex = 1 + mod(_n, 2)
label define sexl 1 "Male" 2 "Female"
label values sex sexl
generate byte grp = 1 + mod(_n, 3)
label define grpl 1 "a" 2 "b" 3 "c"
label values grp grpl
quietly save "`tmp_dir'/g9_person.dta", replace
clear
quietly set obs 36
generate str6 id = string(ceil(_n / 3))
generate byte sex = 1 + mod(_n, 2)
label define sexl 1 "Female" 2 "Male"
label values sex sexl
generate byte grp = 1 + mod(_n, 3)
label define grpl 1 "a" 2 "b" 3 "c"
label values grp grpl
generate int drug = mod(_n, 7)
quietly save "`tmp_dir'/g9_rx.dta", replace

local ++test_count
local raw  "`tmp_dir'/g9_datamap_linkage.md"
local norm "`tmp_dir'/g9_datamap_linkage.norm.md"
quietly datamap, filelist("`tmp_dir'/g9_person" "`tmp_dir'/g9_rx") output("`raw'")
_golden_check, name("G9 datamap two files with the Linkage block") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g9_datamap_linkage.md")

* ============================================================
* Cleanup and summary
* ============================================================

foreach f in g1_datamap_default g2_datamap_full g3_datamap_append ///
    g5_datamap_basic g6_datamap_document g8_datamap_content g9_datamap_linkage {
    capture erase "`tmp_dir'/`f'.md"
    capture erase "`tmp_dir'/`f'.norm.md"
}
foreach f in g4_datamap_separate_test_cohort g4_datamap_separate_test_small ///
    g7_datamap_separate_test_cohort g7_datamap_separate_test_small {
    capture erase "`tmp_dir'/`f'.norm.md"
}
foreach f in test_cohort.dta test_small.dta test_cohort_map.md test_small_map.md {
    capture erase "`sep_dir'/`f'"
}
foreach f in test_cohort.dta test_small.dta test_cohort_dictionary.md ///
    test_small_dictionary.md {
    capture erase "`sep_dd_dir'/`f'"
}
capture erase "`tmp_dir'/g9_person.dta"
capture erase "`tmp_dir'/g9_rx.dta"
capture rmdir "`sep_dir'"
capture rmdir "`sep_dd_dir'"
capture rmdir "`tmp_dir'"

display as result "Golden-output tests passed: `test_count'"
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_golden tests=`test_count' pass=`test_count' fail=0"
exit 0
