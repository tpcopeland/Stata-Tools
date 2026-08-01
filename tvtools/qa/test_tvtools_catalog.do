*! test_tvtools_catalog.do
*! The tvtools catalog is rendered from one command table. These tests read the
*! rendering back and hold it against r(commands), so a command that reaches one
*! and not the other fails here rather than shipping.
*!
*! Why read the rendering at all: tvtools.ado used to hold three parallel copies
*! of the command set -- the category locals, ten hand-padded compact display
*! lines, and ten more in a detail subroutine. Nothing compared them, so the
*! copies drifted, and tvbuild's row shipped one column right of every other row
*! in both views. Asserting on r(commands) alone cannot see that class of defect;
*! only parsing what the user actually sees can.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvtools_catalog.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvtools catalog rendering -- $S_DATE $S_TIME"

* Where the captured renderings go: the private run workspace, never the qa/
* tree. A concurrent lane writing into qa/ is how a green suite starts reading
* someone else's output.
local cap_dir "$TVTOOLS_QA_RUN_DIR"


**# Helpers

* Capture one tvtools invocation to a text log and parse the rendering back.
*
* Returns:
*   r(rows)     - the command token from every rendered command row, in order
*   r(n_rows)   - how many command rows were parsed
*   r(desccols) - the 1-based column each row's description begins at
*   r(cmds)     - r(commands) from the same call
*   r(ncmds)    - r(n_commands) from the same call
*
* A command row is a line indented exactly two spaces whose first token is a
* name in the caller-supplied catalog. Two spaces, not "some indent": detail
* continuation lines are indented far deeper, and matching on the token alone
* would count a continuation line that happened to open with a command name.
* The catalog comes from the caller rather than from the package so that a
* command quietly dropped from tvtools.ado is still a name this parser hunts.
capture program drop _tvcat_render
program define _tvcat_render, rclass
    version 16.0
    syntax , CAPfile(string) CATalog(string) [OPTions(string)]

    * A NAMED capture log, opened alongside the suite's own. `log close _all'
    * here would close the suite log too, and every later display -- including
    * the RESULT line the runner parses -- would go to a file nobody reopened.
    * The leading capture-close covers a previous call that errored mid-render
    * and left this log open.
    capture log close tvcat
    quietly log using "`capfile'", replace text name(tvcat) nomsg
    if `"`options'"' == "" noisily tvtools
    else noisily tvtools, `options'

    * Captured immediately, BEFORE the log close: -log close- clears r(), so
    * reading r(commands) after it returns an empty macro and the drift test
    * silently compares the rendering against nothing.
    local cmds "`r(commands)'"
    local ncmds = r(n_commands)

    quietly log close tvcat

    local rows ""
    local desccols ""
    local n_rows = 0

    tempname fh
    file open `fh' using "`capfile'", read text
    file read `fh' line
    while r(eof) == 0 {
        local keep = 0
        if substr(`"`macval(line)'"', 1, 2) == "  " & ///
           substr(`"`macval(line)'"', 3, 1) != " " {
            * gettoken, not `word 1 of': a rendered line may hold characters
            * that would make the macro-list parser resplit it.
            local rest `"`macval(line)'"'
            gettoken first rest : rest
            local keep : list first in catalog
        }
        if `keep' {
            * The description column is the first non-blank character after the
            * name, measured on the raw line. A padding literal typed into the
            * source shows up here as a wrong number.
            local col = strpos(`"`macval(line)'"', "`first'") + strlen("`first'")
            local len = strlen(`"`macval(line)'"')
            while `col' <= `len' & substr(`"`macval(line)'"', `col', 1) == " " {
                local ++col
            }
            local rows "`rows' `first'"
            local desccols "`desccols' `col'"
            local ++n_rows
        }
        file read `fh' line
    }
    file close `fh'

    return local rows = strtrim(stritrim("`rows'"))
    return local desccols = strtrim(stritrim("`desccols'"))
    return scalar n_rows = `n_rows'
    return local cmds "`cmds'"
    return scalar ncmds = `ncmds'
end


* The catalog every parse is keyed to.
local catalog tvbuild tvspec tvexpose tvmerge tvevent tvage tvband tvsplit ///
    tvpanel tvdiagnose tvweight


**# ===== SECTION 1: compact view =====

* TEST 1.1: rendered set == returned set (all)
* The drift test. Set equality, not containment: neither a missing row nor an
* orphan row passes.
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_all.txt") catalog(`catalog')
    local rendered "`r(rows)'"
    local returned "`r(cmds)'"
    local only_rendered : list rendered - returned
    local only_returned : list returned - rendered
    assert "`only_rendered'" == ""
    assert "`only_returned'" == ""
    assert `: word count `rendered'' == 11
}
if _rc == 0 {
    display as result "  PASS 1.1: compact rendering and r(commands) are the same set"
    local ++pass_count
}
else {
    display as error "  FAIL 1.1: compact rendering and r(commands) are the same set (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* TEST 1.2: parsed row count == r(n_commands)
* Catches a count computed from the list while the rows are typed by hand --
* "Total commands: 11" printed above ten rows.
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_all.txt") catalog(`catalog')
    local n_rows = r(n_rows)
    local ncmds = r(ncmds)
    assert `n_rows' == `ncmds'
    assert `n_rows' == 11
}
if _rc == 0 {
    display as result "  PASS 1.2: compact row count equals r(n_commands)"
    local ++pass_count
}
else {
    display as error "  FAIL 1.2: compact row count equals r(n_commands) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* TEST 1.3: every description starts in the same column, and that column is the
* computed one. Equality alone would pass a renderer that padded every row to a
* wrong-but-consistent width, so the expected column is derived here from the
* longest rendered name exactly as the command derives it.
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_all.txt") catalog(`catalog')
    local rendered "`r(rows)'"
    local desccols "`r(desccols)'"
    local w = 0
    foreach c of local rendered {
        if strlen("`c'") > `w' local w = strlen("`c'")
    }
    local expected = `w' + 4
    foreach dc of local desccols {
        assert `dc' == `expected'
    }
    assert `: word count `desccols'' == 11
}
if _rc == 0 {
    display as result "  PASS 1.3: compact description column is uniform and computed"
    local ++pass_count
}
else {
    display as error "  FAIL 1.3: compact description column is uniform and computed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}


**# ===== SECTION 2: the same three checks per category =====

foreach cat in prep diag weight {
    local ++test_count
    capture noisily {
        _tvcat_render, capfile("`cap_dir'/cat_`cat'.txt") catalog(`catalog') ///
            options(category(`cat'))
        local rendered "`r(rows)'"
        local returned "`r(cmds)'"
        local desccols "`r(desccols)'"
        local n_rows = r(n_rows)
        local ncmds = r(ncmds)

        local only_rendered : list rendered - returned
        local only_returned : list returned - rendered
        assert "`only_rendered'" == ""
        assert "`only_returned'" == ""
        assert `n_rows' == `ncmds'
        assert `n_rows' > 0

        local w = 0
        foreach c of local rendered {
            if strlen("`c'") > `w' local w = strlen("`c'")
        }
        local expected = `w' + 4
        foreach dc of local desccols {
            assert `dc' == `expected'
        }
    }
    if _rc == 0 {
        display as result "  PASS 2 (`cat'): compact rendering, count, and column agree"
        local ++pass_count
    }
    else {
        display as error "  FAIL 2 (`cat'): compact rendering, count, and column agree (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.`cat'"
    }
}


**# ===== SECTION 3: detail view =====

* TEST 3.1: detail rendering and r(commands) are the same set, same count
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_detail.txt") catalog(`catalog') ///
        options(detail)
    local rendered "`r(rows)'"
    local returned "`r(cmds)'"
    local n_rows = r(n_rows)
    local ncmds = r(ncmds)
    local only_rendered : list rendered - returned
    local only_returned : list returned - rendered
    assert "`only_rendered'" == ""
    assert "`only_returned'" == ""
    assert `n_rows' == `ncmds'
    assert `n_rows' == 11
}
if _rc == 0 {
    display as result "  PASS 3.1: detail rendering and r(commands) are the same set"
    local ++pass_count
}
else {
    display as error "  FAIL 3.1: detail rendering and r(commands) are the same set (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* TEST 3.2: detail description column is uniform and computed
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_detail.txt") catalog(`catalog') ///
        options(detail)
    local rendered "`r(rows)'"
    local desccols "`r(desccols)'"
    local w = 0
    foreach c of local rendered {
        if strlen("`c'") > `w' local w = strlen("`c'")
    }
    local expected = `w' + 6
    foreach dc of local desccols {
        assert `dc' == `expected'
    }
    assert `: word count `desccols'' == 11
}
if _rc == 0 {
    display as result "  PASS 3.2: detail description column is uniform and computed"
    local ++pass_count
}
else {
    display as error "  FAIL 3.2: detail description column is uniform and computed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
}

* TEST 3.3: detail view, per category
foreach cat in prep diag weight {
    local ++test_count
    capture noisily {
        _tvcat_render, capfile("`cap_dir'/cat_detail_`cat'.txt") ///
            catalog(`catalog') options(detail category(`cat'))
        local rendered "`r(rows)'"
        local returned "`r(cmds)'"
        local n_rows = r(n_rows)
        local ncmds = r(ncmds)
        local only_rendered : list rendered - returned
        local only_returned : list returned - rendered
        assert "`only_rendered'" == ""
        assert "`only_returned'" == ""
        assert `n_rows' == `ncmds'
        * Without this, a parse that found nothing would compare two empty sets
        * and a count of zero against a count of zero, and pass.
        assert `n_rows' > 0
    }
    if _rc == 0 {
        display as result "  PASS 3.3 (`cat'): detail rendering matches r(commands)"
        local ++pass_count
    }
    else {
        display as error "  FAIL 3.3 (`cat'): detail rendering matches r(commands) (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.3.`cat'"
    }
}


**# ===== SECTION 4: list view =====

* TEST 4.1: list rendering and r(commands) are the same set
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_list.txt") catalog(`catalog') ///
        options(list)
    local rendered "`r(rows)'"
    local returned "`r(cmds)'"
    local n_rows = r(n_rows)
    local ncmds = r(ncmds)
    local only_rendered : list rendered - returned
    local only_returned : list returned - rendered
    assert "`only_rendered'" == ""
    assert "`only_returned'" == ""
    assert `n_rows' == `ncmds'
    assert `n_rows' == 11
}
if _rc == 0 {
    display as result "  PASS 4.1: list rendering and r(commands) are the same set"
    local ++pass_count
}
else {
    display as error "  FAIL 4.1: list rendering and r(commands) are the same set (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}


**# ===== SECTION 5: regression pins =====

* TEST 5.1: tvbuild's description column equals tvexpose's, in both views.
* This is the shipped defect stated as a test. It fails against the pre-f64ba8f
* source, where tvbuild's entry carried one extra space in each display block.
local ++test_count
capture noisily {
    foreach view in "" "detail" {
        _tvcat_render, capfile("`cap_dir'/cat_pin.txt") catalog(`catalog') ///
            options(`view')
        local rendered "`r(rows)'"
        local desccols "`r(desccols)'"
        local pb : list posof "tvbuild" in rendered
        local px : list posof "tvexpose" in rendered
        assert `pb' > 0 & `px' > 0
        local cb : word `pb' of `desccols'
        local cx : word `px' of `desccols'
        assert `cb' == `cx'
    }
}
if _rc == 0 {
    display as result "  PASS 5.1: tvbuild's column equals tvexpose's in both views"
    local ++pass_count
}
else {
    display as error "  FAIL 5.1: tvbuild's column equals tvexpose's in both views (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* TEST 5.2: the compact, detail, and list views describe the SAME command set.
* The three renderings were separately maintained; nothing required them to
* agree, and one of them shipped disagreeing with the others.
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_v1.txt") catalog(`catalog')
    local compact "`r(rows)'"
    _tvcat_render, capfile("`cap_dir'/cat_v2.txt") catalog(`catalog') ///
        options(detail)
    local detailed "`r(rows)'"
    _tvcat_render, capfile("`cap_dir'/cat_v3.txt") catalog(`catalog') ///
        options(list)
    local listed "`r(rows)'"
    local d1 : list compact - detailed
    local d2 : list detailed - compact
    local d3 : list compact - listed
    local d4 : list listed - compact
    assert "`d1'`d2'`d3'`d4'" == ""
}
if _rc == 0 {
    display as result "  PASS 5.2: compact, detail, and list views agree on the command set"
    local ++pass_count
}
else {
    display as error "  FAIL 5.2: compact, detail, and list views agree on the command set (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* TEST 5.3: every rendered command is one the package actually ships.
* A blurb left behind for a removed command renders a row for a command that no
* longer exists; r(commands) alone would not notice.
local ++test_count
capture noisily {
    _tvcat_render, capfile("`cap_dir'/cat_ship.txt") catalog(`catalog')
    local rendered "`r(rows)'"
    foreach c of local rendered {
        capture which `c'
        local which_rc = _rc
        assert `which_rc' == 0
    }
}
if _rc == 0 {
    display as result "  PASS 5.3: every rendered command resolves on the adopath"
    local ++pass_count
}
else {
    display as error "  FAIL 5.3: every rendered command resolves on the adopath (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.3"
}


* ===== Summary =====
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA catalog rendering Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvtools_catalog tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
