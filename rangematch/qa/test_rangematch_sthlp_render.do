* test_rangematch_sthlp_render.do
* Help-file RENDER gate: what the Viewer prints, not what the source says.
*
* Every other suite in this lane probes source text or command behavior. Both
* axes are blind to a help file that is textually perfect and renders wrong, so
* the lane ran 47/47 green while rangematch.sthlp carried an error-severity
* synopt-width defect. Adding more source-text checks cannot close that gap;
* only measuring the rendered column can.
*
* Two render defects are gated here:
*   synopt_width       a {synopt} description wider than its Viewer column
*                      (80 - N for {synoptset N tabbed}) wraps and
*                      cascade-corrupts the GUI render from that row on.
*   punct_line_break   a source newline immediately after sentence-ending
*                      punctuation renders as a DOUBLE space, violating the
*                      single-space house rule. Rewrapping prose to fix
*                      synopt_width is exactly when this gets introduced, and a
*                      whitespace-normalized diff hides it by construction.
*
* Deliberately self-contained: a released package must run its own gates with
* nothing but Stata, so the SMCL measurement is implemented here in Mata rather
* than shelling out to an external linter that ships separately.

clear all
version 16.1

* This suite only inspects package files on disk; it never invokes rangematch.
* Uninstall anyway to keep every QA file uniform.
capture ado uninstall rangematch

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}

mata:
mata clear

// Approximate what the Viewer prints for an SMCL fragment: {cmd:x} contributes
// 1 character, not 8; {p_end} contributes none. Applied repeatedly to a fixed
// point so nested markup collapses fully.
string scalar _qa_smcl_text(string scalar s0)
{
    string scalar s, prev

    s = s0
    prev = ""
    while (prev != s) {
        prev = s
        // {opt met:hod()} -> method()   (the abbreviation colon is not printed)
        s = ustrregexra(s, "\{(opth|opt|cmdab)[ :] *([^{}]*)\}", "$2")
        // {helpb a:b} -> b              (only the label is printed)
        s = ustrregexra(s, "\{(helpb|help|browse|stata|view) +[^{}:]*:([^{}]*)\}", "$2")
        s = ustrregexra(s, "\{(helpb|help|browse|stata|view) +([^{}]*)\}", "$2")
        s = ustrregexra(s, "\{manlink +[^ {}]+ +([^{}]*)\}", "$1")
        // {it:x} / {cmd:x} / {bf:x} ... -> x
        s = ustrregexra(s,
            "\{(it|cmd|bf|text|input|error|result|res|hi|hilite|ul|sf|rm)[ :] *([^{}]*)\}",
            "$2")
        // {c -(} / {&Sigma} -> one printed character
        s = ustrregexra(s, "\{(c [^{}]*|&[A-Za-z]+)\}", "x")
        // every remaining directive ({p_end}, {...}, {synopt:} ...) prints nothing
        s = ustrregexra(s, "\{[^{}]*\}", "")
    }
    // The abbreviation colon inside {opt ...} is markup, not printed text.
    return(s)
}

// Return the description column of a {synopt:...} row, or "" if the line is
// not a synopt row. The label is brace-balanced, so the description is
// everything after the matching close of "{synopt:".
string scalar _qa_synopt_desc(string scalar line0)
{
    string scalar line, ch
    real scalar i, n, depth, start

    line = strtrim(line0)
    if (!ustrregexm(line, "^\{synopt *:")) return("")
    start = strpos(line, ":") + 1
    n = strlen(line)
    depth = 0
    for (i = start; i <= n; i++) {
        ch = substr(line, i, 1)
        if (ch == "{") depth++
        else if (ch == "}") {
            if (depth == 0) return(substr(line, i + 1, n - i))
            depth--
        }
    }
    return("")
}

// Does `line' open with INLINE markup (so it continues the paragraph) rather
// than a block-level paragraph directive (which starts a new one)? A
// continuation may legitimately begin with {opt ...} or {cmd:...}; skipping
// every line that starts with "{" would hide real breaks.
real scalar _qa_inline_open(string scalar line0)
{
    return(ustrregexm(strtrim(line0),
        "^\{(opth|opt|cmdab|it|cmd|bf|text|help|helpb|browse|stata|view|manlink|c |&)"))
}

void _qa_render_check(string scalar path)
{
    real scalar fh, cap, w, i, n, synoptset, nbad_w, nbad_p
    string scalar desc, head, nxt, last
    string colvector lines

    fh = fopen(path, "r")
    lines = J(0, 1, "")
    while ((head = fget(fh)) != J(0, 0, "")) lines = lines \ head
    fclose(fh)

    n = rows(lines)
    synoptset = 20          // Stata's default when no {synoptset} is declared
    nbad_w = 0
    nbad_p = 0

    for (i = 1; i <= n; i++) {
        if (ustrregexm(strtrim(lines[i]), "^\{synoptset +([0-9]+)")) {
            synoptset = strtoreal(ustrregexs(1))
        }

        // -- synopt_width --------------------------------------------------
        desc = _qa_synopt_desc(lines[i])
        if (desc != "") {
            cap = 80 - synoptset
            w = strlen(strtrim(_qa_smcl_text(desc)))
            if (w > cap) {
                printf("{err}[FAIL] %s:%f synopt description %f > %f cols\n",
                    pathbasename(path), i, w, cap)
                nbad_w++
            }
        }

        // -- punct_line_break ----------------------------------------------
        if (i < n) {
            nxt = lines[i + 1]
            if (strtrim(lines[i]) != "" & strtrim(nxt) != "") {
                if (!(substr(strtrim(nxt), 1, 1) == "{" & !_qa_inline_open(nxt))) {
                    head = strrtrim(lines[i])
                    if (substr(head, strlen(head) - 6, 7) != "{p_end}") {
                        // A trailing {...} does NOT suppress the double space.
                        if (substr(head, strlen(head) - 4, 5) == "{...}") {
                            head = strrtrim(substr(head, 1, strlen(head) - 5))
                        }
                        while (head != "" & substr(head, strlen(head), 1) == "}") {
                            head = substr(head, 1, strlen(head) - 1)
                        }
                        if (head != "") {
                            last = substr(head, strlen(head), 1)
                            if (strpos(".:;?!", last) > 0) {
                                printf("{err}[FAIL] %s:%f breaks after '%s'\n",
                                    pathbasename(path), i, last)
                                nbad_p++
                            }
                        }
                    }
                }
            }
        }
    }
    st_local("nbad_width", strofreal(nbad_w))
    st_local("nbad_punct", strofreal(nbad_p))
}
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# T1: every {synopt} description fits its Viewer column
* Red before this suite existed: r(N_master_key_missing) rendered 75 into a
* 58-column slot (synoptset 22), wrapping and corrupting the GUI render for
* every Stored Results row below it.
local ++test_count
capture noisily {
    mata: _qa_render_check("`pkg_dir'/rangematch.sthlp")
    assert `nbad_width' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T1 synopt descriptions fit the Viewer column"
}
else {
    local ++pass_count
    display as text "[ok] T1 synopt descriptions fit the Viewer column"
}

**# T2: no source line breaks immediately after sentence-ending punctuation
local ++test_count
capture noisily {
    assert `nbad_punct' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T2 no double-space renders from punctuation breaks"
}
else {
    local ++pass_count
    display as text "[ok] T2 no double-space renders from punctuation breaks"
}

**# T3: the gate has teeth -- a known-bad fragment must be caught
* Without this, T1/T2 pass vacuously if _qa_smcl_text or _qa_synopt_desc
* silently returns "" for every row. Both defects are planted and must fire.
local ++test_count
capture noisily {
    tempfile bad
    tempname fh
    file open `fh' using "`bad'", write text replace
    file write `fh' "{synoptset 22 tabbed}{...}" _n
    file write `fh' "{synopt:{cmd:r(x)}}" ///
        "this description is deliberately far too wide for a twenty-two column synoptset row{p_end}" _n
    file write `fh' "{pstd}" _n
    file write `fh' "A sentence that ends right here." _n
    file write `fh' "{cmd:continuation} of the same paragraph." _n
    file close `fh'
    mata: _qa_render_check("`bad'")
    assert `nbad_width' == 1
    assert `nbad_punct' == 1
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T3 gate detects planted render defects"
}
else {
    local ++pass_count
    display as text "[ok] T3 gate detects planted render defects"
}

**# T4: a clean fragment does NOT trip the gate (false-positive control)
* T3 proves the checks can fire; this proves they do not fire on everything.
local ++test_count
capture noisily {
    tempfile good
    tempname fh2
    file open `fh2' using "`good'", write text replace
    file write `fh2' "{synoptset 22 tabbed}{...}" _n
    file write `fh2' "{synopt:{cmd:r(x)}}a short description{p_end}" _n
    file write `fh2' "{pstd}" _n
    file write `fh2' "A sentence that wraps mid-clause and therefore does" _n
    file write `fh2' "not break after its punctuation.{p_end}" _n
    file close `fh2'
    mata: _qa_render_check("`good'")
    assert `nbad_width' == 0
    assert `nbad_punct' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T4 clean fragment does not trip the gate"
}
else {
    local ++pass_count
    display as text "[ok] T4 clean fragment does not trip the gate"
}

**# Summary
display as text _newline "test_rangematch_sthlp_render"
display as text "Tests:  `test_count'"
display as text "Passed: `pass_count'"
display as text "Failed: `fail_count'"
display "RESULT: test_rangematch_sthlp_render tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 exit 9
