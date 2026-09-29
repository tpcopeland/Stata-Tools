*! _finegray_graph_text Version 1.3.7  2026/09/29
*! Inert, verbatim display and graph text for user-supplied labels
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass (returns through c_local)
*! Internal helper

/*
Syntax:
  _finegray_graph_text <macname> : `"<text>"'

Sets the caller's local <macname> to <text> with every character that SMCL
or Stata's macro expansion would act on written as an SMCL character code:

    {  ->  {c -(}      }  ->  {c )-}      `  ->  {c 96}
    $  ->  {c 36}      "  ->  {c 34}

A value label is user data and must be drawn exactly as written.  Stata's
graph commands pass option text through several layers of programs that
re-expand it as macro text, and both graph text and -display- interpret SMCL,
so macval() at the call site is not enough: a dollar sign followed by a
global's name was drawn as that global's contents, a `q' pair vanished, {bf:x} was drawn bold and an
unbalanced backtick stopped the graph with r(132).  The result holds none of
those characters, so it is inert under any number of further expansions and
inside any compound-quoted option, and the character codes render as the
original characters in graph text (legend, titles, notes, axis labels,
text boxes; also after graph save/use and graph combine) and in -display-.

The text is read from `0' by Mata, never expanded here.  The caller passes it
compound-quoted with macval(): _finegray_graph_text out : `"`macval(lbl)'"'
The result is for display sinks only; r(), e() and saved datasets keep the
raw text.
*/

program define _finegray_graph_text
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        * Split "<macname> : <text>" in Mata so the text is never expanded.
        * The text is everything after the first colon and one space; one
        * pair of outer compound (or plain) quotes is removed if present.
        mata: st_local("_fggt_p", strofreal(strpos(st_local("0"), ":")))
        if `_fggt_p' == 0 {
            display as error "_finegray_graph_text: syntax is <macname> : <text>"
            exit 198
        }
        mata: st_local("_fggt_name", strtrim(substr(st_local("0"), 1, `_fggt_p' - 1)))
        capture confirm name `_fggt_name'
        if _rc | `: word count `_fggt_name'' != 1 | ustrlen("`_fggt_name'") > 31 {
            display as error "_finegray_graph_text: syntax is <macname> : <text>"
            exit 198
        }
        mata: st_local("_fggt_txt", substr(st_local("0"), `_fggt_p' + 1, .))
        mata: st_local("_fggt_txt", substr(st_local("_fggt_txt"), ///
            1 + (substr(st_local("_fggt_txt"), 1, 1) == " "), .))
        mata: st_local("_fggt_q", strofreal( ///
            strlen(st_local("_fggt_txt")) >= 4 & ///
            substr(st_local("_fggt_txt"), 1, 2) == char(96) + char(34) & ///
            substr(st_local("_fggt_txt"), strlen(st_local("_fggt_txt")) - 1, 2) == char(34) + char(39) ///
            ? 2 : (strlen(st_local("_fggt_txt")) >= 2 & ///
            substr(st_local("_fggt_txt"), 1, 1) == char(34) & ///
            substr(st_local("_fggt_txt"), strlen(st_local("_fggt_txt")), 1) == char(34))))
        if `_fggt_q' {
            mata: st_local("_fggt_txt", substr(st_local("_fggt_txt"), `_fggt_q' + 1, ///
                strlen(st_local("_fggt_txt")) - 2 * `_fggt_q'))
        }
        * Braces first, with no placeholder characters (a placeholder would
        * turn a control character already in the text into a brace): every
        * { becomes {c -(}, then every } becomes {c )-}, which also rewrites
        * the closing brace the first pass wrote, so the one sequence that
        * produces, {c -({c )-}, is folded back to {c -(}.  Only the first
        * pass can create that sequence.  Backquote, $ and " go last: their
        * codes add braces but none of the three characters.
        mata: st_local("_fggt_out", ///
            subinstr(subinstr(subinstr( ///
            subinstr(subinstr(subinstr(st_local("_fggt_txt"), ///
            "{", "{c -(}"), "}", "{c )-}"), "{c -({c )-}", "{c -(}"), ///
            char(96), "{c 96}"), char(36), "{c 36}"), char(34), "{c 34}"))
        c_local `_fggt_name' `"`_fggt_out'"'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
