* _qa_v230_helpers.do - shared assertion helpers for the 2.3.0 rendering/session suites
*
* Workbook facts are read back with openpyxl (tools/xlsx_facts.py), never
* through the Mata xl() writer under test. Text sinks (CSV, Markdown) are read
* with Mata cat(), one element per line. Every helper exits 9 on a failed
* assertion, naming what it looked for.
*
* Requires globals V230_TOOL (path of tools/xlsx_facts.py) and V230_RES (a
* scratch file for the facts).

* Read the layout facts of sheet `sheet' of `book' into $V230_RES.
capture program drop _v_facts
program define _v_facts
    version 17.0
    args book sheet
    capture erase "$V230_RES"
    shell python3 "$V230_TOOL" "`book'" "`sheet'" "$V230_RES"
    confirm file "$V230_RES"
end

* Every cell in `cells' carries fact "`kind' <cell> `style'" exactly once.
capture program drop _v_has
program define _v_has
    version 17.0
    args kind style cells
    foreach c of local cells {
        local want = strtrim("`kind' `c' `style'")
        mata: st_local("_n", strofreal(sum(cat("$V230_RES") :== st_local("want"))))
        if `_n' != 1 {
            display as error "missing fact: `want'"
            exit 9
        }
    }
end

* No cell in `cells' carries any `kind' fact.
capture program drop _v_none
program define _v_none
    version 17.0
    args kind cells
    foreach c of local cells {
        local pre "`kind' `c'"
        mata: _f = cat("$V230_RES"); st_local("_n", strofreal(sum((_f :== st_local("pre")) :| ///
            (substr(_f, 1, strlen(st_local("pre")) + 1) :== st_local("pre") + " "))))
        if `_n' != 0 {
            display as error "unexpected fact: `pre'"
            exit 9
        }
    }
end

* Cell `cell' holds exactly `text' (fact "value <cell> <text>").
capture program drop _v_value
program define _v_value
    version 17.0
    gettoken cell 0 : 0
    gettoken text 0 : 0
    local want `"value `cell' `text'"'
    mata: st_local("_n", strofreal(sum(cat("$V230_RES") :== st_local("want"))))
    if `_n' != 1 {
        display as error `"missing fact: `want'"'
        exit 9
    }
end

* Cell `cell' is empty (no value fact).
capture program drop _v_empty
program define _v_empty
    version 17.0
    args cell
    _v_none value "`cell'"
end

* Number of `kind' facts on the sheet, in r(n).
capture program drop _v_count
program define _v_count, rclass
    version 17.0
    args kind
    mata: _f = cat("$V230_RES"); st_local("_n", strofreal(sum(substr(_f, 1, ///
        strlen("`kind'") + 1) :== "`kind' ")))
    return scalar n = `_n'
end

* Text file `file' has line `text' exactly `times' times (default: at least once).
capture program drop _v_line
program define _v_line
    version 17.0
    gettoken file 0 : 0
    gettoken text 0 : 0
    gettoken times 0 : 0
    mata: st_local("_n", strofreal(sum(cat(st_local("file")) :== st_local("text"))))
    if "`times'" == "" {
        if `_n' < 1 {
            display as error `"missing line in `file': `text'"'
            exit 9
        }
    }
    else if `_n' != `times' {
        display as error `"line in `file' found `_n' times, expected `times': `text'"'
        exit 9
    }
end

* Number of lines of text file `file' matching regular expression `re', in r(n).
capture program drop _v_grep
program define _v_grep, rclass
    version 17.0
    gettoken file 0 : 0
    gettoken re 0 : 0
    mata: _f = cat(st_local("file")); _k = 0; ///
        for (_i = 1; _i <= rows(_f); _i++) _k = _k + ustrregexm(_f[_i], st_local("re")); ///
        st_local("_n", strofreal(_k))
    return scalar n = `_n'
end
