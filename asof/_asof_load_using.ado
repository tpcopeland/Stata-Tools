*! _asof_load_using Version 0.1.0  2026/08/12
*! Validate and prepare the asof event frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _asof_load_using, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , FRAME(name) ID(name) DATE(name) CARRY(string) ///
            REQUIRE(string) ORDER(name) EVENTKEY(name)

        capture confirm frame `frame'
        if _rc {
            display as error "event frame `frame' not found"
            exit 111
        }

        local checkvars `id' `date' `carry' `require'
        local seen ""
        foreach var of local checkvars {
            if !`: list var in seen' {
                capture frame `frame': confirm variable `var'
                if _rc {
                    display as error "variable `var' not found in using data"
                    exit 111
                }
                local seen `seen' `var'
            }
        }

        capture frame `frame': confirm numeric variable `date'
        if _rc {
            display as error "date() must name a numeric daily or %tc variable in using data; convert string dates with datefix first"
            exit 109
        }

        capture frame `frame': confirm numeric variable `id'
        if _rc == 0 local idtype "numeric"
        else {
            capture frame `frame': confirm string variable `id'
            if _rc {
                display as error "id() must be numeric or string in using data"
                exit 109
            }
            local idtype "string"
        }

        capture frame `frame': confirm new variable `order'
        if _rc {
            display as error "internal event-order variable collides with using data"
            exit 110
        }
        capture frame `frame': confirm new variable `eventkey'
        if _rc {
            display as error "internal event-key variable collides with using data"
            exit 110
        }

        frame `frame': quietly count
        local N_using = r(N)

        frame `frame': quietly generate long `order' = _n
        tempvar eligible
        frame `frame': quietly generate byte `eligible' = 1
        frame `frame': quietly markout `eligible' `id' `date' `require', strok
        frame `frame': quietly keep if `eligible'
        frame `frame': quietly drop `eligible'
        frame `frame': quietly sort `id' `date' `order'
        frame `frame': quietly generate long `eventkey' = _n

        frame `frame': quietly count
        local N_events = r(N)
        frame `frame': local datefmt : format `date'

        return scalar N_using = `N_using'
        return scalar N_events = `N_events'
        return local idtype "`idtype'"
        return local date_format "`datefmt'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
