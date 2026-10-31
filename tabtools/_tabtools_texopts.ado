*! _tabtools_texopts Version 1.1.0  2026/10/31
*! Parse and validate texopts(), the LaTeX layout sub-options
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
    _tabtools_texopts `"<texopts() contents>"' [, session]

    Sub-options (all optional):
        none                 the default layout (alone); lets one command
                             set aside a session value
        captionleft          flush-left caption       (needs caption)
        captionbelow         caption under the table
        nocentering          no \centering
        placement(spec)      float placement, letters h t b p and !, or H
                             alone (H needs float); default htbp
        size(name)           tiny scriptsize footnotesize small normalsize
                             large: type size of the tabular
        fit                  shrink a table wider than the line to the line
                             width (needs graphicx); never enlarges
        landscape            the float on its own rotated page (needs
                             pdflscape)
        label(key)           \label key instead of tab:<file stem>
        preamble("line" ...) extra preamble lines, used when texdocument
                             creates the document
        docclass(class [opt ...])  \documentclass[opt,...]{class} for a
                             document texdocument creates; default article

    session refuses label(): one key on every table of a session is a
    multiply-defined label.

    Returns r(captionleft) r(captionbelow) r(nocentering) r(fit)
    r(landscape) (each 1 or 0), r(placement), r(size), r(label),
    r(npreamble) and r(preamble1)... (one line each), r(docclass),
    r(classopts) (comma-separated), r(packages) (packages the layout
    needs besides booktabs, space-separated).
*/

program define _tabtools_texopts, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken _spec 0 : 0
        syntax [, SESSION]
        local _valid "none captionleft captionbelow nocentering placement() size() fit landscape label() preamble() docclass()"
        local 0 `", `macval(_spec)'"'
        capture syntax [, none captionleft captionbelow nocentering ///
            placement(string) size(string) fit landscape label(string) ///
            preamble(string asis) docclass(string)]
        local _src = _rc
        * syntax files a no-prefixed option under its bare name (nocentering
        * in local centering, none in local ne) and also accepts that bare
        * name, recording nothing: read both words from the text instead.
        local _bad = ustrregexm(`"`macval(_spec)'"', "(^|[ ,])(centering|ne)([ ,]|$)")
        local none = cond(ustrregexm(`"`macval(_spec)'"', "(^|[ ,])none([ ,]|$)"), "none", "")
        if `_src' | `_bad' {
            noisily display as error `"texopts(): unknown or malformed sub-option in "`macval(_spec)'""'
            noisily display as error "valid sub-options: `_valid'"
            exit 198
        }
        * none: the default layout, for one command under a session value
        if "`none'" != "" & strtrim(`"`macval(_spec)'"') != "none" {
            noisily display as error "texopts(none) cannot be combined with other sub-options"
            exit 198
        }
        if "`none'" != "" & "`session'" != "" {
            noisily display as error "tabtools set texopts: use tabtools set texopts clear to remove the session layout"
            exit 198
        }

        local _packages ""
        if "`captionleft'" != "" local _packages "`_packages' caption"

        local placement = strtrim(`"`placement'"')
        if `"`placement'"' == "" local placement "htbp"
        * LaTeX takes the ! anywhere in the specifier (h!t), at most once
        if !ustrregexm(`"`placement'"', "^(H|[htbp!]*[htbp][htbp!]*)$") | ///
            strlen(`"`placement'"') - strlen(subinstr(`"`placement'"', "!", "", .)) > 1 {
            noisily display as error `"texopts(placement()): "`placement'" is not a float placement; use letters from h t b p with an optional !, or H alone"'
            exit 198
        }
        if "`placement'" == "H" local _packages "`_packages' float"

        local size = strtrim(`"`size'"')
        if `"`size'"' != "" & !inlist(`"`size'"', "tiny", "scriptsize", ///
            "footnotesize", "small", "normalsize", "large") {
            noisily display as error `"texopts(size()): "`size'" is not one of tiny, scriptsize, footnotesize, small, normalsize, large"'
            exit 198
        }

        if "`fit'" != "" local _packages "`_packages' graphicx"
        if "`landscape'" != "" local _packages "`_packages' pdflscape"

        local label = strtrim(`"`label'"')
        if `"`label'"' != "" {
            if "`session'" != "" {
                noisily display as error "tabtools set texopts: label() names one table; give it in that command's texopts() instead"
                exit 198
            }
            if !ustrregexm(`"`label'"', "^[A-Za-z0-9_:.-]+$") {
                noisily display as error `"texopts(label()): "`label'" may contain only letters, digits, _ : . and -"'
                exit 198
            }
        }

        * preamble(): each quoted string is one line, written as given. A
        * line may not start or end the document; that frame is tabtools'.
        local _np = 0
        local _rest `"`macval(preamble)'"'
        while `"`macval(_rest)'"' != "" {
            gettoken _line _rest : _rest
            local _line = strtrim(`"`macval(_line)'"')
            if `"`macval(_line)'"' == "" continue
            if strpos(`"`macval(_line)'"', "documentclass") | ///
                strpos(`"`macval(_line)'"', "{document}") {
                noisily display as error "texopts(preamble()): a line may not contain \documentclass, \begin{document} or \end{document}; tabtools writes those"
                exit 198
            }
            local ++_np
            local _pre`_np' `"`macval(_line)'"'
        }

        local _class "article"
        local _copts ""
        local docclass = strtrim(`"`docclass'"')
        if `"`docclass'"' != "" {
            gettoken _class _co : docclass
            if !ustrregexm(`"`_class'"', "^[A-Za-z][A-Za-z0-9-]*$") {
                noisily display as error `"texopts(docclass()): "`_class'" is not a document class name"'
                exit 198
            }
            foreach _o of local _co {
                if !ustrregexm(`"`_o'"', "^[A-Za-z0-9.=-]+$") {
                    noisily display as error `"texopts(docclass()): class option "`_o'" may contain only letters, digits, . = and -"'
                    exit 198
                }
                local _copts = cond("`_copts'" == "", "`_o'", "`_copts',`_o'")
            }
        }

        return local packages = strtrim("`_packages'")
        return local classopts "`_copts'"
        return local docclass "`_class'"
        return scalar npreamble = `_np'
        forvalues _i = 1/`_np' {
            return local preamble`_i' `"`macval(_pre`_i')'"'
        }
        return local label `"`label'"'
        return local size `"`size'"'
        return local placement `"`placement'"'
        * syntax files a no-prefixed option under the bare name: nocentering
        * arrives in local centering, never in local nocentering.
        return scalar nocentering = ("`centering'" == "nocentering")
        foreach _f in captionleft captionbelow fit landscape {
            return scalar `_f' = ("``_f''" != "")
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
