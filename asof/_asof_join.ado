*! _asof_join Version 0.1.0  2026/08/12
*! Run the Mata as-of scan over prepared key and event frames
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _asof_join, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , KEYFRAME(name) EVENTFRAME(name) ID(name) ANCHOR(name) ///
            DATE(name) ORDER(name) PICK(name) IDTYPE(string) ///
            DIRection(string) SELect(string) TIES(string) ///
            WINLOW(string) WINHIGH(string) SCALE(real) ///
            [RANGELOW(name) RANGEHIGH(name)]

        capture confirm frame `keyframe'
        if _rc exit 111
        capture confirm frame `eventframe'
        if _rc exit 111

        frame `keyframe': quietly generate double `pick' = .
        capture findfile _asof_mata.ado
        if _rc {
            display as error "_asof_mata.ado not found; reinstall asof"
            exit 111
        }
        * discard does not clear Mata; reload so an in-session package update
        * cannot retain an older scan implementation.
        run "`r(fn)'"

        tempname stats
        mata: st_matrix("`stats'", _asof_scan("`keyframe'", "`eventframe'", ///
            "`id'", "`anchor'", "`rangelow'", "`rangehigh'", "`date'", ///
            "`order'", "`pick'", "`idtype'", "`direction'", "`select'", ///
            "`ties'", strtoreal("`winlow'"), strtoreal("`winhigh'"), `scale'))

        local err = `stats'[1,3]
        if `err' {
            if `err' == 459 {
                display as error "eligible records are tied and ties(error) was specified"
            }
            exit `err'
        }

        return scalar N_eligible = `stats'[1,1]
        return scalar N_ties = `stats'[1,2]
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
