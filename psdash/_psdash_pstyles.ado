*! _psdash_pstyles Version 1.9.0  2026/10/29
*! Series plot-style order for arms, groups, and strategies under a scheme
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: sclass
*! Internal helper

* Series take the scheme's own order p1, p2, p3, ... when p1 and p2 are far
* apart (CIE76 colour difference >= 30), so categorical schemes such as
* white_tableau or s2color give blue/orange/green or navy/maroon. Sequential
* schemes (viridis, cividis, ukraine, piyg, ...) put p2 next to p1, so there
* the order is p1, p6, p2, p3, p4, p5, p7, ... and the second series stays
* distinguishable. s(order) lists 15 style numbers; series j uses word
* mod(j - 1, 15) + 1. Callers run this inside r-class commands after posting
* results, so r() is held and restored and the answer travels in s().
program define _psdash_pstyles, sclass
    version 16.0
    syntax [, SCHeme(string) GRAPHopts(string asis)]
    tempname rhold
    _return hold `rhold'

    local order "1 6 2 3 4 5 7 8 9 10 11 12 13 14 15"
    local de = .
    local sch `"`scheme'"'
    * a scheme given inside graphoptions() is the one the graph will use
    if `"`sch'"' == "" & regexm(`"`graphopts'"', "(^|[ ,])sch(e|em|eme)?[(] *([^ )]+) *[)]") {
        local sch = regexs(3)
    }
    if `"`sch'"' == "" local sch "`c(scheme)'"

    * Resolve the two colours through a throwaway graph, which turns named
    * colours (navy, maroon, ...) into RGB triples.
    tempname g
    capture twoway (scatteri 0 0, pstyle(p1)) (scatteri 0 0, pstyle(p2)), ///
        scheme(`sch') nodraw name(`g')
    if !_rc {
        local c1 "`.`g'.plotregion1.plot1.style.line.color.setting'"
        local c2 "`.`g'.plotregion1.plot2.style.line.color.setting'"
        graph drop `g'
    }

    local ok = 1
    forvalues k = 1/2 {
        if `: word count `c`k''' != 3 local ok = 0
        else {
            forvalues i = 1/3 {
                local v : word `i' of `c`k''
                capture confirm number `v'
                if _rc local ok = 0
            }
        }
    }

    if `ok' {
        forvalues k = 1/2 {
            * sRGB -> linear -> XYZ (D65) -> CIELAB
            forvalues i = 1/3 {
                local v : word `i' of `c`k''
                local v = `v' / 255
                local lin`i' = cond(`v' <= 0.04045, `v' / 12.92, ((`v' + 0.055) / 1.055)^2.4)
            }
            local X = (0.4124 * `lin1' + 0.3576 * `lin2' + 0.1805 * `lin3') / 0.95047
            local Y = 0.2126 * `lin1' + 0.7152 * `lin2' + 0.0722 * `lin3'
            local Z = (0.0193 * `lin1' + 0.1192 * `lin2' + 0.9505 * `lin3') / 1.08883
            foreach t in X Y Z {
                local f`t' = cond(``t'' > 0.008856, ``t''^(1/3), 7.787 * ``t'' + 16 / 116)
            }
            local L`k' = 116 * `fY' - 16
            local a`k' = 500 * (`fX' - `fY')
            local b`k' = 200 * (`fY' - `fZ')
        }
        local de = sqrt((`L1' - `L2')^2 + (`a1' - `a2')^2 + (`b1' - `b2')^2)
        if `de' >= 30 local order "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"
    }

    _return restore `rhold'
    sreturn local order "`order'"
    sreturn local de12 "`de'"
end
