*! test_rangematch_doc_contract.do
*! Regression suite for the Phase-4 documentation-reality findings (RM-I11..I14).
*!
*! These tests exist because README prose drifted away from the parser without a
*! single suite going red: the README advertised a `sort' option the parser
*! rejects with rc=198, omitted ties(random)/seed() that the parser accepts,
*! claimed a single missing bound wildcard-matches every counterpart when it
*! only removes its own side's restriction, and pointed users at a demo that
*! `net install' does not deliver. Every check below runs the documented thing
*! rather than searching for it in the file.

clear all
set varabbrev off
version 16.1

* No `log using' here by design: under run_all.do this file is do'ed inside the
* runner's own unnamed log, and opening/closing one here would close the
* runner's. Standalone `stata-mp -b do' still produces test_*.log via batch
* mode. Suites in this package that need a log of their own use a named one.

local test_count = 0
local pass_count = 0
local fail_count = 0

* Relocatable bootstrap.
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local readme "`pkg_dir'/README.md"
capture confirm file "`readme'"
if _rc {
    display as error "README.md not found at `readme'"
    exit 601
}

**# Process-unique token for scratch paths
* Not runiformint(): Stata's RNG starts from a fixed default seed, so an
* unseeded "random" tag is byte-identical on every run and collides with the
* previous run's leftovers. A tempfile name carries the process id.
tempfile _tok_probe
mata: st_local("uniq", subinstr(pathbasename(st_local("_tok_probe")), ".", "_"))

**# Shared fixture (the README Quick Start data)
* Built with set obs/generate rather than `input': an `input' data block is
* terminated by `end', which would also terminate an enclosing program define.
tempfile master events

clear
set obs 2
generate str1 site = cond(_n == 1, "A", "B")
generate int id = _n
generate double event_date = cond(_n == 1, 21915, 21946)
format event_date %td
save "`master'", replace

clear
set obs 4
generate str1 site = cond(_n <= 2, "A", "B")
generate int eid = 100 + _n
generate double event_date = 21890
replace event_date = 21920 in 2
replace event_date = 21950 in 3
replace event_date = 21990 in 4
format event_date %td
save "`events'", replace

**# Extractors
* Parsing happens in Mata, not in Stata macros. The .ado syntax line carries
* id="keyvar low high"; in a Stata macro expression those embedded quotes
* unbalance the string literal and the scan dies r(132) instead of reading the
* option list. Mata handles the quotes as data. Quotes are written as char(34)
* throughout -- Mata has no backslash-quote escape, and using one silently
* voids the whole block.
mata:
mata clear

// Concatenate the .ado's syntax line and its continuations.
string scalar _rmdoc_ado_syntax(string scalar fn)
{
    string colvector L
    real scalar i, on
    string scalar out, s

    L = cat(fn)
    on = 0
    out = ""
    for (i = 1; i <= rows(L); i++) {
        s = strtrim(L[i])
        if (strpos(s, "syntax anything(name=interval") == 1) on = 1
        if (on) {
            out = out + " " + s
            if (strpos(s, "VERBOSE") > 0) on = 0
        }
    }
    return(out)
}

// Concatenate the fenced code blocks under the README's "## Syntax" heading.
string scalar _rmdoc_readme_syntax(string scalar fn)
{
    string colvector L
    real scalar i, seen, inblk
    string scalar out, s

    L = cat(fn)
    seen = 0
    inblk = 0
    out = ""
    for (i = 1; i <= rows(L); i++) {
        s = strtrim(L[i])
        if (s == "## Syntax") seen = 1
        if (seen & strpos(s, "## Positional") == 1) break
        if (seen) {
            if (strpos(s, "```") == 1) inblk = !inblk
            else if (inblk) out = out + " " + s
        }
    }
    return(out)
}

// Write the README's Quick Start block and its Positional-Arguments Examples
// block, verbatim and in document order, into one runnable do-file. Extracting
// rather than transcribing is the point: a hand-copied sequence in this suite
// would keep passing after the README itself regressed.
void _rmdoc_write_examples(string scalar fn, string scalar outfn)
{
    string colvector L
    real scalar i, fh, mode, inblk, nblk
    string scalar s

    L = cat(fn)
    // fopen(..., "w") errors 602 if the file already exists.
    unlink(outfn)
    fh = fopen(outfn, "w")
    mode = 0                                   // 0 none, 1 Quick Start, 2 Positional
    inblk = 0
    nblk = 0
    for (i = 1; i <= rows(L); i++) {
        s = strtrim(L[i])
        if (s == "## Quick Start") {
            mode = 1
            nblk = 0
            continue
        }
        if (s == "## Positional Arguments") {
            mode = 2
            nblk = 0
            continue
        }
        if (mode == 0) continue
        if (strpos(s, "```") == 1) {
            if (inblk) {
                inblk = 0
                nblk++
                if (mode == 1) mode = 0        // Quick Start has one block
            }
            else if (nblk == 0) inblk = 1      // first block of the section only
            continue
        }
        if (inblk) fput(fh, L[i])
    }
    fclose(fh)
}

// Reduce a syntax fragment to a deduplicated list of bare option names.
string scalar _rmdoc_norm(string scalar raw0)
{
    string rowvector t
    string scalar out, x, raw
    real scalar i, p

    raw = raw0
    raw = subinstr(raw, char(34), " ")
    raw = subinstr(raw, "///", " ")
    raw = subinstr(raw, "[", " ")
    raw = subinstr(raw, "]", " ")
    raw = subinstr(raw, ",", " ")
    raw = subinstr(raw, "/", " ")
    t = tokens(raw)
    out = ""
    for (i = 1; i <= cols(t); i++) {
        x = t[i]
        p = strpos(x, "(")
        if (p > 0) x = substr(x, 1, p - 1)
        x = subinstr(x, ")", "")
        x = strlower(strtrim(x))
        if (x == "") continue
        if (strpos(x, "=")) continue          // anything()/id= descriptors
        if (!strpos(" " + out + " ", " " + x + " ")) out = out + " " + x
    }
    return(strtrim(out))
}
end

mata: st_local("accepted", _rmdoc_norm(_rmdoc_ado_syntax(st_local("pkg_dir") + "/rangematch.ado")))
if trim("`accepted'") == "" {
    display as error "extracted zero option tokens from the rangematch.ado syntax line"
    display as error "the extractor is broken; every comparison below would pass vacuously"
    exit 459
}

**# T1 (RM-I11): every option token advertised in the README syntax blocks is accepted
* Tokens are extracted structurally from the fenced blocks under "## Syntax",
* not looked up by name, so a newly invented option fails here.
local ++test_count
* Positional/placeholder words are not options and are excluded by name.
local noise "rangematch keyvar low high using filename_or_framename if in ulow uhigh filename options"
mata: st_local("advertised_all", _rmdoc_norm(_rmdoc_readme_syntax(st_local("readme"))))
local advertised ""
foreach tok of local advertised_all {
    if !strpos(" `noise' ", " `tok' ") local advertised "`advertised' `tok'"
}
capture noisily {
    if trim("`advertised'") == "" {
        display as error "extracted zero option tokens from the README syntax blocks"
        display as error "the extractor is broken; a vacuous pass here would hide every drift"
        exit 459
    }

    local unknown ""
    foreach tok of local advertised {
        if !strpos(" `accepted' ", " `tok' ") local unknown "`unknown' `tok'"
    }
    if trim("`unknown'") != "" {
        display as error "README advertises option(s) the parser does not accept:`unknown'"
        exit 198
    }
    display as text "  advertised tokens checked:`advertised'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: every README-advertised option token is accepted by the parser"
}
else {
    local ++fail_count
    display as error "FAIL: README advertises an option the parser rejects"
}

**# T8 (RM-I18): every option the parser accepts is advertised in the README
* T1 is only half the contract. It proves the README advertises nothing fake --
* soundness. It cannot see an option the parser accepts that the README's
* syntax block has DROPPED or never gained, because a token that is absent from
* the README is absent from T1's loop.
*
* That is the gap RM-I18 names from the other side: release_integrity searched
* the README for option text ANYWHERE in the file, so an accurate Options table
* masked a stale syntax block. Comparing the two extracted SETS in both
* directions closes it -- the syntax block must be the parser's surface, not a
* subset of it that happens to overlap the prose.
local ++test_count
* The .ado side carries grammar the README side does not: the `syntax' keyword
* itself, the `anything(name=... )' declaration, its `asis' modifier, and the
* `0' argument marker. They are parser scaffolding, not user-facing options, so
* they are excluded BY NAME -- a short, explicit list, so that a genuinely new
* option can never be waved through as scaffolding.
local ado_noise "syntax anything asis 0"
capture noisily {
    local undocumented ""
    foreach tok of local accepted {
        * Positional/grammar tokens from the syntax line are not options.
        if strpos(" `noise' ", " `tok' ") continue
        if strpos(" `ado_noise' ", " `tok' ") continue
        if !strpos(" `advertised' ", " `tok' ") local undocumented "`undocumented' `tok'"
    }
    if trim("`undocumented'") != "" {
        display as error "parser accepts option(s) the README syntax blocks do not advertise:`undocumented'"
        display as error "the README syntax block must be the parser's surface, not a subset of it"
        exit 198
    }
    display as text "  accepted tokens checked:`accepted'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: every parser-accepted option is advertised in the README syntax blocks"
}
else {
    local ++fail_count
    display as error "FAIL: the README syntax blocks omit an option the parser accepts"
}

**# T2 (RM-I11): the specific token that was wrong -- `sort' is rejected
* Pins the defect itself: the README advertised `sort', the parser exits 198.
local ++test_count
capture noisily {
    use "`master'", clear
    generate double lo = event_date - 14
    generate double hi = event_date + 14
    capture rangematch event_date lo hi using "`events'", sort
    if _rc != 198 {
        display as error "expected rc=198 for the once-advertised sort option; got rc=`=_rc'"
        exit 459
    }
    * ...and the README must not advertise it anywhere in its syntax blocks.
    if strpos(" `advertised' ", " sort ") {
        display as error "README syntax blocks still advertise the sort option"
        exit 459
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: sort is rejected (198) and no longer advertised"
}
else {
    local ++fail_count
    display as error "FAIL: sort option contract"
}

**# T3 (RM-I11): ties(random)/seed() are accepted and are advertised
local ++test_count
capture noisily {
    use "`master'", clear
    generate double lo = event_date - 40
    generate double hi = event_date + 40
    rangematch event_date lo hi using "`events'", nearest(both) ties(random) seed(12345)
    if !strpos(" `advertised' ", " seed ") {
        display as error "README syntax blocks omit seed()"
        exit 459
    }
    if !strpos(" `advertised' ", " ties ") {
        display as error "README syntax blocks omit ties()"
        exit 459
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: ties(random)/seed() run and are advertised"
}
else {
    local ++fail_count
    display as error "FAIL: ties(random)/seed() contract"
}

**# T4 (RM-I11): the overlap diagram runs as written (one comma before options)
* The published diagram once carried a comma after [if] [in] and a second
* comma opening the option list; executing it literally returned 198.
local ++test_count
capture noisily {
    clear
    input int id double lo double hi
    1 100 110
    2 200 210
    end
    tempfile omaster
    save "`omaster'", replace

    clear
    input int id double ulo double uhigh
    1 105 115
    2 300 310
    end
    tempfile ousing
    save "`ousing'", replace

    use "`omaster'", clear
    rangematch lo hi using "`ousing'" , overlap(ulo uhigh) by(id) unmatched(none)
    if _N != 1 {
        display as error "overlap-mode diagram produced `=_N' rows; expected 1"
        exit 459
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: overlap-mode syntax diagram runs as written"
}
else {
    local ++fail_count
    display as error "FAIL: overlap-mode syntax diagram"
}

**# T5 (RM-I12): the three README positional examples run verbatim, in sequence
* The audit's rule: do not silently repair the examples inside the test. Each
* block below is the README text as displayed, including its `use ..., clear'.
local ++test_count
capture noisily {
    local extracted "`c(tmpdir)'/rm_readme_examples_`uniq'.do"
    mata: _rmdoc_write_examples(st_local("readme"), st_local("extracted"))

    * The extractor must actually find the blocks. An empty or truncated file
    * would `do' cleanly and report a green that proves nothing.
    capture confirm file "`extracted'"
    if _rc {
        display as error "extraction produced no file at `extracted'"
        exit 459
    }
    tempname efh
    local nlines = 0
    local saw_rangematch = 0
    file open `efh' using "`extracted'", read text
    file read `efh' eline
    while r(eof) == 0 {
        local ++nlines
        if strpos(`"`eline'"', "rangematch ") local ++saw_rangematch
        file read `efh' eline
    }
    file close `efh'
    if `nlines' < 20 | `saw_rangematch' < 4 {
        display as error "extracted `nlines' lines and `saw_rangematch' rangematch calls from the README"
        display as error "expected the Quick Start block plus three positional examples"
        exit 459
    }

    capture frame drop matches
    do "`extracted'"
    erase "`extracted'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: README Quick Start + positional examples run verbatim, in sequence"
}
else {
    local ++fail_count
    display as error "FAIL: the README sequence does not run as displayed (rc=`=_rc')"
}

**# T6 (RM-I13): missing-bound semantics -- one side open is NOT a wildcard
* Discriminating fixture: using keys straddle the stated bound, so a row that
* wildcard-matched everything and a row that respects the live bound return
* different counts. A fixture with only in-range keys could not tell them apart.
local ++test_count
capture noisily {
    clear
    input int uid double k
    1 1
    2 10
    end
    tempfile ukeys
    save "`ukeys'", replace

    * lower-only missing: [., 5] must match k=1 and not k=10
    clear
    input int id double lo double hi
    1 . 5
    end
    rangematch k lo hi using "`ukeys'", unmatched(none) keepusing(k)
    if _N != 1 {
        display as error "[., 5] matched `=_N' rows; expected exactly 1 (k=1)"
        exit 459
    }
    if k[1] != 1 {
        display as error "[., 5] matched k=`=k[1]'; expected k=1"
        exit 459
    }

    * upper-only missing: [5, .] must match k=10 and not k=1
    clear
    input int id double lo double hi
    1 5 .
    end
    rangematch k lo hi using "`ukeys'", unmatched(none) keepusing(k)
    if _N != 1 {
        display as error "[5, .] matched `=_N' rows; expected exactly 1 (k=10)"
        exit 459
    }
    if k[1] != 10 {
        display as error "[5, .] matched k=`=k[1]'; expected k=10"
        exit 459
    }

    * both missing: fully open, matches every counterpart
    clear
    input int id double lo double hi
    1 . .
    end
    rangematch k lo hi using "`ukeys'", unmatched(none) keepusing(k)
    if _N != 2 {
        display as error "[., .] matched `=_N' rows; expected 2 (fully open)"
        exit 459
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: missing-bound semantics pinned (lower-only, upper-only, both)"
}
else {
    local ++fail_count
    display as error "FAIL: missing-bound semantics"
}

**# T7 (RM-I14): the demo is repository-only; the benchmark is retrievable
* The README once told installed users to run demo/demo_rangematch.do. Prove
* what install actually delivers rather than trusting the manifest text.
local ++test_count
capture noisily {
    local sandbox "`c(tmpdir)'/rm_i14_`uniq'"
    capture mkdir "`sandbox'"
    capture mkdir "`sandbox'/plus"
    capture mkdir "`sandbox'/work"

    local keep_plus "`c(sysdir_plus)'"
    local keep_pwd "`c(pwd)'"
    sysdir set PLUS "`sandbox'/plus"
    cd "`sandbox'/work"

    quietly net install rangematch, from("`pkg_dir'") replace

    * net install must not deliver the demo...
    capture findfile demo_rangematch.do
    local demo_installed = (_rc == 0)

    * ...and net get must deliver the benchmark into the working directory.
    capture quietly net get rangematch, from("`pkg_dir'") replace
    local netget_rc = _rc
    capture confirm file "bench_rangematch.do"
    local bench_here = (_rc == 0)
    capture confirm file "demo_rangematch.do"
    local demo_gotten = (_rc == 0)

    sysdir set PLUS "`keep_plus'"
    cd "`keep_pwd'"

    if `demo_installed' {
        display as error "demo_rangematch.do resolved after net install; README's maintainer-only framing is now wrong"
        exit 459
    }
    if `netget_rc' != 0 {
        display as error "net get failed with rc=`netget_rc'"
        exit 459
    }
    if !`bench_here' {
        display as error "net get did not deliver bench_rangematch.do; README tells users it will"
        exit 459
    }
    if `demo_gotten' {
        display as error "net get delivered the demo; README says it does not"
        exit 459
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: demo is repository-only; net get delivers bench_rangematch.do"
}
else {
    local ++fail_count
    display as error "FAIL: demo/benchmark distribution contract"
}

**# Summary
display as text "tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "RESULT: rangematch_doc_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
