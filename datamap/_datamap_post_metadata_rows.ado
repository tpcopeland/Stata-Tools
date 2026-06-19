*! _datamap_post_metadata_rows Version 1.5.0  2026/06/19
*! Post common variable-metadata rows from a loaded dataset
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_post_metadata_rows, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    capture noisily {
        syntax, POSTName(name) CLASSifications(string) SOURCECommand(string) ///
            SOURCE(string) DSName(string) NVARS(integer) ///
            [OUtput(string) DSLabel(string) VARLIST(string) DATASIGnature(string)]

        local source = substr(`"`macval(source)'"', 1, 2045)
        local output = substr(`"`macval(output)'"', 1, 2045)
        local dslabel = substr(`"`macval(dslabel)'"', 1, 2045)
        foreach field in source output dslabel {
            local `field' = subinstr(`"`macval(`field')'"', char(96), "", .)
            local `field' = subinstr(`"`macval(`field')'"', char(34), "", .)
            local `field' = subinstr(`"`macval(`field')'"', char(39), "", .)
        }

        preserve
        local _restore_needed = 1
        quietly use `"`classifications'"', clear
        quietly count
        local C = r(N)
        local classvars ""
        forvalues i = 1/`C' {
            local vn = varname[`i']
            local classvars "`classvars' `vn'"
            local meta_class_`vn' = classification[`i']
            local meta_missing_`vn' = missing_n[`i']
            local meta_missing_pct_`vn' = missing_pct[`i']
            local meta_unique_`vn' = unique_vals[`i']
        }
        restore
        local _restore_needed = 0

        if `"`varlist'"' == "" local varlist "`classvars'"
        local obs = c(N)

        foreach vname of local varlist {
            capture confirm variable `vname', exact
            if _rc continue

            local vtype : type `vname'
            local vfmt : format `vname'
            local vlab : variable label `vname'
            local vallabname : value label `vname'
            local varclass "`meta_class_`vname''"
            if "`varclass'" == "" local varclass "unknown"

            local nmiss = `meta_missing_`vname''
            if missing(`nmiss') {
                quietly count if missing(`vname')
                local nmiss = r(N)
            }
            local pctmiss = `meta_missing_pct_`vname''
            if missing(`pctmiss') {
                local pctmiss = 0
                if `obs' > 0 local pctmiss = round(100 * `nmiss' / `obs', 0.1)
            }

            local nuniq = `meta_unique_`vname''
            local mean = .
            local sd = .
            local p50 = .
            local p25 = .
            local p75 = .
            local vmin = .
            local vmax = .

            capture confirm numeric variable `vname'
            local is_numeric = (_rc == 0)
            if `is_numeric' & "`varclass'" != "excluded" {
                quietly summarize `vname', detail
                if r(N) > 0 {
                    local mean = r(mean)
                    local sd = r(sd)
                    local p50 = r(p50)
                    local p25 = r(p25)
                    local p75 = r(p75)
                    local vmin = r(min)
                    local vmax = r(max)
                }
            }

            local notes ""
            local note0 : char `vname'[note0]
            if "`note0'" == "" local note0 0
            forvalues ni = 1/`note0' {
                local notei : char `vname'[note`ni']
                if `"`notei'"' != "" {
                    if `"`notes'"' == "" local notes `"`macval(notei)'"'
                    else local notes `"`macval(notes)'<br>`macval(notei)'"'
                }
            }
            local chars ""
            local allchars : char `vname'[]
            foreach cname of local allchars {
                if !regexm("`cname'", "^note[0-9]+$") {
                    local cval : char `vname'[`cname']
                    if `"`chars'"' == "" local chars `"`cname'=`macval(cval)'"'
                    else local chars `"`macval(chars)'<br>`cname'=`macval(cval)'"'
                }
            }

            local post_vlab = substr(`"`macval(vlab)'"', 1, 2045)
            local post_notes = substr(`"`macval(notes)'"', 1, 2045)
            local post_chars = substr(`"`macval(chars)'"', 1, 2045)
            local post_dsig = substr(`"`macval(datasignature)'"', 1, 2045)

            post `postname' (`"`sourcecommand'"') (`"`macval(source)'"') ///
                (`"`macval(output)'"') (`"`dsname'"') (`"`macval(dslabel)'"') ///
                (`"`vname'"') (`"`vtype'"') (`"`vfmt'"') (`"`vallabname'"') ///
                (`"`varclass'"') (`obs') (`nvars') (`nmiss') (`pctmiss') ///
                (`nuniq') (`"`macval(post_vlab)'"') (`"`macval(post_notes)'"') ///
                (`"`macval(post_chars)'"') (`mean') (`sd') (`p50') (`p25') ///
                (`p75') (`vmin') (`vmax') (`"`macval(post_dsig)'"')
        }
    }
    local rc = _rc
    if `_restore_needed' {
        capture restore
        local _restore_rc = _rc
        if !`rc' & `_restore_rc' local rc = `_restore_rc'
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
