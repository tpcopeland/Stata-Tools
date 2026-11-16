*! _dataprobe_smallcells Version 2.1.0  2026/11/16
*! dataprobe smallcells(): no released count of 1 to m-1 in a results dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: countexp [countexp ...] [if exp]
//
// A publication gate for a results dataset (one row per released table cell
// or row).  Each countexp is a variable or an expression with no spaces (a
// parenthesised expression may contain spaces, as in (n1 - e1)), such as
// n1-e1.  On the rows in scope (the entry's if, within the call's if/in) no
// countexp may lie in 1 to m-1.  Zero, a value of m or more, and a missing
// value (a suppressed cell) pass.  A negative or non-integer value fails, as
// its own reason.  An expression that does not evaluate is an error, never a
// pass.  m is the threshold dataprobe resolved for the call (mincell(), the
// dataqa set default, or the maskrare default); it arrives as mcell().
//
// The message and the record never carry a value, only the number of table
// rows that fail, per countexp and reason, masked under maskrare.  A failed
// gate is an invariant: it never becomes a band.
//
// 2.1.0 (F7): countexp ... [if exp], [id(varname) by(varlist)
// margins[(strata|conditions)]].  Any of these suboptions makes the entry
// an audit of microdata (_dataprobe_sccells): each countexp is then a
// condition, 0 or 1 on every row in scope (anything else is r(459)), and a
// cell is the rows in scope where it is 1, within each by() stratum; with
// id() the cell's distinct id values are checked in the same pass.  A cell
// fails when its rows or its ids are 1 to m-1.  margins adds a second
// record, the margins audit.  The messages name the failing cells by
// condition and stratum, never by a count; a stratum whose rows or ids in
// scope are 1 to m-1 under maskrare, or every stratum when a by() variable
// is in exclude(), is named by its number, not its values.  safe(1) refuses
// a by() variable whose values safe would withhold.
program define _dataprobe_smallcells, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) MCELL(integer 0) ///
            SAFE(integer 0) EXCLuded(string)]
        if `mcell' < 1 {
            display as error "smallcells() needs a threshold: give mincell(#), or set one with dataqa set mincell(#)"
            exit 198
        }
        if `mcell' < 2 {
            display as error "smallcells() needs a threshold of 2 or more (resolved mincell/rare is `mcell'): a gate on counts in 1..`=`mcell'-1' tests nothing"
            exit 198
        }
        // ---- split the entry into countexps and an optional if ----
        local s = strtrim(`"`spec'"')
        // ---- 2.1.0 (F7): suboptions after a comma outside parentheses
        // and double quotes (no valid 2.0.0 entry has one) ----
        local _cm = 0
        local id ""
        local by ""
        local margins ""
        local subopts ""
        local _L0 = strlen(`"`s'"')
        local _dp = 0
        local _iq = 0
        local _cp = 0
        forvalues i = 1/`_L0' {
            if substr(`"`s'"', `i', 1) == char(34) local _iq = !`_iq'
            else if !`_iq' {
                if substr(`"`s'"', `i', 1) == "(" local ++_dp
                else if substr(`"`s'"', `i', 1) == ")" local --_dp
                else if substr(`"`s'"', `i', 1) == "," & `_dp' == 0 {
                    local _cp = `i'
                    continue, break
                }
            }
        }
        if `_cp' {
            local subopts = strtrim(substr(`"`s'"', `_cp' + 1, .))
            local s = strtrim(substr(`"`s'"', 1, `_cp' - 1))
            if `"`subopts'"' == "" {
                display as error "smallcells(): nothing after the comma; the suboptions are id(varname), by(varlist) and margins[(strata|conditions)]"
                exit 198
            }
            // a bare margins is margins(both)
            local _so ""
            local _r `"`subopts'"'
            while `"`_r'"' != "" {
                gettoken _t _r : _r, bind
                if regexm(`"`_t'"', "^mar(g|gi|gin|gins)?$") local _t "margins(both)"
                local _so `"`_so' `_t'"'
            }
            local 0 `", `_so'"'
            capture noisily syntax , [ID(varname) BY(varlist) MARgins(string)]
            if _rc {
                local _erc = _rc
                display as error "smallcells(): the suboptions are id(varname), by(varlist) and margins[(strata|conditions)]"
                exit `_erc'
            }
            local margins = strtrim(`"`margins'"')
            if `"`margins'"' != "" & !inlist(`"`margins'"', "both", "strata", "conditions") {
                display as error `"smallcells(): margins() takes strata or conditions, or nothing: `margins'"'
                exit 198
            }
            local by : list uniq by
            local _cm = 1
            // safe: a stratum is named by its values, so a by() variable
            // safe withholds (an identifier, a date, text holding a digit)
            // is refused, as dataprobe's own by() is
            if `safe' & "`by'" != "" {
                _datamap_idnames `by'
                local _bad "`r(names)'"
                foreach v of local by {
                    local _vf : format `v'
                    capture confirm string variable `v'
                    if !_rc {
                        quietly count if ustrregexm(`v', "\p{Nd}")
                        if r(N) local _bad "`_bad' `v'"
                    }
                    else if regexm("`_vf'", "^%-?(t|d)") local _bad "`_bad' `v'"
                }
                local _bad : list uniq _bad
                if "`_bad'" != "" {
                    display as error "safe: smallcells() by() would print the values of `_bad' (an identifier, a date, or text holding a digit) as stratum labels"
                    exit 198
                }
            }
        }
        local L = strlen(`"`s'"')
        local depth = 0
        local tok ""
        local nexp = 0
        local ifexp ""
        local done = 0
        forvalues i = 1/`=`L' + 1' {
            if `done' continue
            local atend = (`i' > `L')
            if !`atend' {
                if substr(`"`s'"', `i', 1) == "(" local ++depth
                if substr(`"`s'"', `i', 1) == ")" local --depth
                if `depth' < 0 {
                    display as error `"smallcells(): unbalanced parentheses in `spec'"'
                    exit 198
                }
            }
            local isblank = (!`atend' & substr(`"`s'"', `i', 1) == " " & `depth' == 0)
            if `atend' | `isblank' {
                if `depth' != 0 {
                    display as error `"smallcells(): unbalanced parentheses in `spec'"'
                    exit 198
                }
                if `"`tok'"' != "" {
                    if lower(`"`tok'"') == "if" {
                        local ifexp = strtrim(substr(`"`s'"', `i' + 1, .))
                        local done = 1
                    }
                    else {
                        local ++nexp
                        local ex`nexp' `"`tok'"'
                    }
                    local tok ""
                }
            }
            else local tok `"`tok'`=substr(`"`s'"', `i', 1)'"'
        }
        if `nexp' == 0 {
            display as error `"smallcells() spec must be "countexp [countexp ...] [if exp]": `spec'"'
            exit 198
        }
        if `done' & `"`ifexp'"' == "" {
            display as error "smallcells(): empty if condition"
            exit 198
        }
        // a relation of one cell is the cell itself, which the floor checks
        if "`margins'" == "strata" & `nexp' < 2 {
            display as error "smallcells(): margins(strata) needs two or more conditions (the cells of a stratum)"
            exit 198
        }
        if "`margins'" == "conditions" & "`by'" == "" {
            display as error "smallcells(): margins(conditions) needs by() (the strata of a condition)"
            exit 198
        }
        if "`margins'" == "both" & `nexp' < 2 & "`by'" == "" {
            display as error "smallcells(): margins needs two or more conditions or by()"
            exit 198
        }
        // ---- the variables the expressions read (kept by dataprobe) ----
        local full ""
        forvalues j = 1/`nexp' {
            local full `"`full' `ex`j''"'
        }
        local full `"`full' `ifexp'"'
        local rest `"`full'"'
        while regexm(`"`rest'"', "([A-Za-z_][A-Za-z0-9_]*)") {
            local w = regexs(1)
            local rest = substr(`"`rest'"', strpos(`"`rest'"', "`w'") + strlen("`w'"), .)
            capture confirm variable `w', exact
            if !_rc local vars "`vars' `w'"
        }
        local vars "`vars' `id' `by'"
        local vars : list uniq vars
        // ---- every expression must evaluate; checked on parse and on run ----
        tempvar sc
        quietly generate byte `sc' = 1
        if `"`ifexp'"' != "" {
            capture quietly replace `sc' = ((`ifexp') != 0)
            if _rc {
                local _erc = _rc
                display as error `"smallcells(): cannot evaluate condition if `ifexp'"'
                exit `_erc'
            }
        }
        forvalues j = 1/`nexp' {
            tempvar v`j'
            capture quietly generate double `v`j'' = (`ex`j'')
            if _rc {
                local _erc = _rc
                display as error `"smallcells(): cannot evaluate `ex`j''; a countexp is a variable or an expression with no spaces"'
                exit `_erc'
            }
            // a cell condition is 0 or 1: a count column (a results table)
            // or a flag with missing values is refused, never counted
            if `_cm' {
                quietly count if `sc' & !inlist(`v`j'', 0, 1)
                if r(N) {
                    display as error `"smallcells(): with id(), by() or margins each countexp is a condition, 0 or 1 on every row in scope; `ex`j'' is missing or takes another value on some rows (write the condition, as in x == 1)"'
                    exit 459
                }
            }
        }
        if "`parseonly'" == "" & !`_cm' {
            tempvar anyf
            quietly generate byte `anyf' = 0
            local pieces ""
            local mins = .
            local om = 0
            local m1 = `mcell' - 1
            forvalues j = 1/`nexp' {
                local v "`v`j''"
                quietly count if `sc' & !missing(`v') & `v' < 0
                local kneg = r(N)
                quietly count if `sc' & !missing(`v') & `v' >= 0 & abs(`v' - round(`v')) > 1e-8
                local kint = r(N)
                quietly count if `sc' & !missing(`v') & `v' >= 0 & abs(`v' - round(`v')) <= 1e-8 ///
                    & round(`v') >= 1 & round(`v') <= `m1'
                local ksm = r(N)
                quietly replace `anyf' = 1 if `sc' & !missing(`v') & (`v' < 0 | ///
                    abs(`v' - round(`v')) > 1e-8 | (round(`v') >= 1 & round(`v') <= `m1'))
                local why ""
                foreach r in ksm kneg kint {
                    if ``r'' == 0 continue
                    _dataprobe_mcount ``r'' `mask'
                    local rs "`r(s)'"
                    if r(masked) {
                        local om = 1
                        local anymask = 1
                    }
                    else local mins = min(`mins', ``r'')
                    local lab = cond("`r'" == "ksm", "small", ///
                        cond("`r'" == "kneg", "negative", "non-integer"))
                    local why "`why'`=cond("`why'" == "", "", ", ")'`rs' `lab'"
                }
                if "`why'" != "" local pieces `"`pieces'`=cond(`"`pieces'"' == "", "", "; ")'`ex`j'' (`why')"'
            }
            quietly count if `anyf'
            local nbad = r(N)
            local ok = (`nbad' == 0)
            if !`ok' local nfail = 1
            _dataprobe_mcount `nbad' `mask'
            local nbs "`r(s)'"
            local onum = r(num)
            if r(masked) {
                local om = 1
                local anymask = 1
            }
            else if `nbad' >= 1 local mins = min(`mins', `nbad')
            local vtxt `"`ex1'"'
            forvalues j = 2/`nexp' {
                local vtxt `"`vtxt' `ex`j''"'
            }
            if `"`ifexp'"' != "" local vtxt `"`vtxt' if `ifexp'"'
            if length(`"`vtxt'"') > 60 local vtxt = substr(`"`vtxt'"', 1, 57) + "..."
            local exptxt "no released count in 1..`m1' (m=`mcell')"
            if `ok' local msg `"`pfx'smallcells(`vtxt'): `exptxt'"'
            else local msg `"`pfx'smallcells(`vtxt'): `nbs' table rows fail, `pieces'; expected `exptxt'"'
            frame post `rf' ("smallcells") ("`kind'") (`ok') (`"`macval(vtxt)'"') (`"`macval(vtxt)'"') ///
                (`"`macval(grp)'"') ("`nbs' rows fail") (`onum') ("`exptxt'") ///
                (`nscope') (`"`macval(ifexp)'"') (`"`macval(msg)'"') (`mins') (`om')
        }
        if "`parseonly'" == "" & `_cm' {
            // ---- 2.1.0 (F7): cells counted on microdata ----
            local m1 = `mcell' - 1
            tempvar g
            if "`by'" != "" _dataprobe_sccells group `by', gen(`g')
            else quietly generate long `g' = 1
            local hl ""
            forvalues j = 1/`nexp' {
                tempvar h`j'
                quietly generate byte `h`j'' = (`sc' == 1 & `v`j'' == 1)
                local hl "`hl' `h`j''"
            }
            local _ido ""
            if "`id'" != "" local _ido "idvar(`id')"
            _dataprobe_sccells count, group(`g') hits(`hl') scope(`sc') mcell(`mcell') ///
                `_ido' margins(`margins') mask(`mask')
            local nbad = r(nbad)
            local nfl = r(nf)
            local nx = r(nx)
            local nxl = r(nxl)
            local wh "`r(wh)'"
            local need ""
            forvalues k = 1/`nfl' {
                foreach q in g j u {
                    local f`k'_`q' "`r(f`k'_`q')'"
                }
                local need "`need' `f`k'_g'"
            }
            forvalues k = 1/`nxl' {
                foreach q in t i p c {
                    local x`k'_`q' "`r(x`k'_`q')'"
                }
                if `x`k'_t' == 1 local need "`need' `x`k'_i'"
                else local need "`need' `x`k'_c'"
            }
            local need : list uniq need
            // the strata the messages name: by value (the ledger form of
            // _dataprobe_gtext), or by number when withheld
            if "`by'" != "" & "`need'" != "" {
                local _bx : list by & excluded
                if "`_bx'" == "" quietly _dataprobe_gtext `by', group(`g')
                foreach gg of local need {
                    if "`_bx'" != "" | `: list gg in wh' local sl`gg' "group `gg'"
                    else local sl`gg' `"`r(led`gg')'"'
                }
            }
            local vtxt `"`ex1'"'
            forvalues j = 2/`nexp' {
                local vtxt `"`vtxt' `ex`j''"'
            }
            if `"`ifexp'"' != "" local vtxt `"`vtxt' if `ifexp'"'
            local vtxt `"`vtxt', `subopts'"'
            if length(`"`vtxt'"') > 60 local vtxt = substr(`"`vtxt'"', 1, 57) + "..."
            // the floor: one record, as a results table's
            local unit = cond("`id'" != "", "rows or ids", "rows")
            local exptxt "no cell of 1..`m1' `unit' (m=`mcell')"
            local ok = (`nbad' == 0)
            if !`ok' local nfail = 1
            _dataprobe_mcount `nbad' `mask'
            local nbs "`r(s)'"
            local onum = r(num)
            local om = r(masked)
            if `om' local anymask = 1
            local mins = .
            if !`om' & `nbad' >= 1 local mins = `nbad'
            local pieces ""
            forvalues k = 1/`nfl' {
                local jj = `f`k'_j'
                local pc `"`ex`jj''"'
                if "`by'" != "" local pc `"`pc' in `sl`f`k'_g''"'
                local pieces `"`pieces'`=cond(`k' == 1, "", ", ")'`pc' (`f`k'_u')"'
            }
            if `nbad' > `nfl' local pieces `"`pieces', and more"'
            if `ok' local msg `"`pfx'smallcells(`vtxt'): `exptxt'"'
            else local msg `"`pfx'smallcells(`vtxt'): `nbs' cells fail, `pieces'; expected `exptxt'"'
            frame post `rf' ("smallcells") ("`kind'") (`ok') (`"`macval(vtxt)'"') (`"`macval(vtxt)'"') ///
                (`"`macval(grp)'"') ("`nbs' cells fail") (`onum') ("`exptxt'") ///
                (`nscope') (`"`macval(ifexp)'"') (`"`macval(msg)'"') (`mins') (`om')
            // the margins audit: a second record
            if "`margins'" != "" {
                local exp2 "no small cell recoverable from a margin (m=`mcell')"
                local ok2 = (`nx' == 0)
                if !`ok2' local nfail = 1
                _dataprobe_mcount `nx' `mask'
                local nxs "`r(s)'"
                local onum2 = r(num)
                local om2 = r(masked)
                if `om2' local anymask = 1
                local mins2 = .
                if !`om2' & `nx' >= 1 local mins2 = `nx'
                local xp ""
                forvalues k = 1/`nxl' {
                    local pn : word `x`k'_p' of single singletons smallsum pinned narrowed
                    // under the mask a pattern beyond single tells what the
                    // hidden cells hold (singletons: each is 1; pinned: each
                    // is fixed; smallsum, narrowed: their total or range),
                    // so it prints as exposed; single says only that one
                    // cell is small, which the floor record says already
                    if `mask' > 0 & `x`k'_p' > 1 local pn "exposed"
                    local cs ""
                    if `x`k'_t' == 1 {
                        if "`by'" == "" local rel "total"
                        else local rel `"`sl`x`k'_i''"'
                        foreach jj of local x`k'_c {
                            local cs `"`cs'`=cond(`"`cs'"' == "", "", ", ")'`ex`jj''"'
                        }
                    }
                    else {
                        local jj = `x`k'_i'
                        local rel `"`ex`jj''"'
                        foreach gg of local x`k'_c {
                            local cs `"`cs'`=cond(`"`cs'"' == "", "", ", ")'`sl`gg''"'
                        }
                    }
                    local xp `"`xp'`=cond(`k' == 1, "", "; ")'`rel': `pn' (`cs')"'
                }
                if `nx' > `nxl' local xp `"`xp'; and more"'
                local lab2 `"`vtxt' [margins]"'
                if `ok2' local msg2 `"`pfx'smallcells(`vtxt') margins: `exp2'"'
                else local msg2 `"`pfx'smallcells(`vtxt') margins: `nxs' exposed, `xp'; expected `exp2'"'
                frame post `rf' ("smallcells") ("`kind'") (`ok2') (`"`macval(lab2)'"') (`"`macval(vtxt)'"') ///
                    (`"`macval(grp)'"') ("`nxs' margins exposed") (`onum2') ("`exp2'") ///
                    (`nscope') (`"`macval(ifexp)'"') (`"`macval(msg2)'"') (`mins2') (`om2')
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar isgate = 1
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
