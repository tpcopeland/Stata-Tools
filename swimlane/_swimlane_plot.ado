*! _swimlane_plot Version 0.1.0  2026/06/29
*! Render canonical swimlane frames
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define _swimlane_plot, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _orig_frame = c(frame)
    local _changed_frame = 0
    local _restore_needed = 0

    capture noisily {
        syntax , CANONframe(name) MODE(string) GRAPHName(name) ///
            [BARWidth(real 0.6) ///
             LANEType(string) ///
             LABELPolicy(string) ///
             LABELEvery(integer 0) ///
             MARKers(string) ///
             CONTinuation(string) ///
             PLOTHeight(real -1) ///
             NOYLabels ///
             BYPlot ///
             PANELCols(integer 0) ///
             BLOCKPlot ///
             BYLayout(string) ///
             COLORBYPlot ///
             REFLine(numlist) ///
             COLors(string) ///
             PALette(string) ///
             MSYMbols(string) ///
             MSIZe(string) ///
             TItle(string asis) ///
             SUBtitle(string asis) ///
             NOTE(string asis) ///
             XTItle(string asis) ///
             YTItle(string asis) ///
             LEGend(string asis) ///
             SCHeme(string) ///
             SAVing(string asis) ///
             GRAPHReplace ///
             NOGraph ///
             TIMEfmt(string) ///
             BARLabel(string) ///
             ADDPlotstub(name) ///
             TWOWAYopts(string asis)]

        frame change `canonframe'
        local _changed_frame = 1

        if "`lanetype'" == "" local lanetype "bar"
        if "`labelpolicy'" == "" {
            if "`noylabels'" != "" local labelpolicy "none"
            else local labelpolicy "all"
        }
        if "`markers'" == "" local markers "full"
        if "`continuation'" == "" local continuation "arrow"

        local colorlist "`colors'"
        local use_scheme_colors = 0
        if "`colorlist'" == "" {
            if "`palette'" == "colorblind" {
                local colorlist ///
                    "navy dkorange teal cranberry forest_green purple sienna gs6"
            }
            else if "`palette'" == "mono" {
                local colorlist "black gs4 gs8 gs12 gs6 gs10"
            }
            else if "`palette'" == "scheme" {
                local use_scheme_colors = 1
            }
            else {
                local colorlist ///
                    "navy cranberry forest_green dkorange purple teal maroon olive gold sienna emidblue eltgreen"
            }
        }
        local symbols "`msymbols'"
        if "`symbols'" == "" local symbols "circle diamond triangle square plus X"
        if "`msize'" == "" {
            if "`markers'" == "minimal" local msize "tiny"
            else local msize "medium"
        }

        * Event markers draw their colors AFTER the bar colors so a marker
        * never matches the bar it sits on. Bars consume the first
        * `n_barcolors' palette slots; events start at the next slot.
        local n_barcolors = 1

        quietly summarize start if rowtype == "bar", meanonly
        local xmin = r(min)
        quietly summarize stop if rowtype == "bar", meanonly
        local xmax = r(max)
        local xpad = (`xmax' - `xmin') * 0.02
        if `xpad' <= 0 | missing(`xpad') local xpad = 0.1
        tempvar xtip
        gen double `xtip' = stop + `xpad' if rowtype == "bar"

        local plotlist ""
        local legend_order ""
        local plot_i = 0

        if "`mode'" == "state" {
            quietly levelsof series_k if rowtype == "bar", local(barlevels)
            local n_barcolors : word count `barlevels'
            foreach k of local barlevels {
                local ++plot_i
                local col : word `k' of `colorlist'
                if "`col'" == "" local col "gs`=mod(`k',14)'"
                quietly levelsof series if rowtype == "bar" & series_k == `k', ///
                    local(_lab) clean
                local lab "`_lab'"
                if "`lanetype'" == "line" {
                    local barstyle "lwidth(thin)"
                    if !`use_scheme_colors' {
                        local barstyle "`barstyle' lcolor(`col')"
                    }
                    local plotlist `"`plotlist' (pcspike lane start lane stop if rowtype == "bar" & series_k == `k', `barstyle')"'
                }
                else {
                    local barstyle ""
                    if !`use_scheme_colors' {
                        local barstyle "color(`col'%70) lcolor(`col')"
                    }
                    local plotlist `"`plotlist' (rbar start stop lane if rowtype == "bar" & series_k == `k', horizontal barwidth(`barwidth') `barstyle')"'
                }
                local legend_order `"`legend_order' `plot_i' `"`lab'"'"'
            }
        }
        else if "`colorbyplot'" != "" {
            quietly levelsof series_k if rowtype == "bar", local(barlevels)
            local n_barcolors : word count `barlevels'
            foreach k of local barlevels {
                local ++plot_i
                local col : word `k' of `colorlist'
                if "`col'" == "" local col "gs`=mod(`k',14)'"
                quietly levelsof series if rowtype == "bar" & series_k == `k', ///
                    local(_lab) clean
                local lab "`_lab'"
                if "`lanetype'" == "line" {
                    local barstyle "lwidth(thin)"
                    if !`use_scheme_colors' {
                        local barstyle "`barstyle' lcolor(`col')"
                    }
                    local plotlist `"`plotlist' (pcspike lane start lane stop if rowtype == "bar" & series_k == `k', `barstyle')"'
                }
                else {
                    local barstyle ""
                    if !`use_scheme_colors' {
                        local barstyle "color(`col'%70) lcolor(`col')"
                    }
                    local plotlist `"`plotlist' (rbar start stop lane if rowtype == "bar" & series_k == `k', horizontal barwidth(`barwidth') `barstyle')"'
                }
                local legend_order `"`legend_order' `plot_i' `"`lab'"'"'
            }
        }
        else {
            local barstyle "color(navy%65) lcolor(navy)"
            if `use_scheme_colors' local barstyle ""
            else if "`colorlist'" != "" {
                local col : word 1 of `colorlist'
                local barstyle "color(`col'%65) lcolor(`col')"
            }
            local ++plot_i
            if "`lanetype'" == "line" {
                local barstyle "lwidth(thin)"
                if !`use_scheme_colors' {
                    local col : word 1 of `colorlist'
                    local barstyle "`barstyle' lcolor(`col')"
                }
                local plotlist `"`plotlist' (pcspike lane start lane stop if rowtype == "bar", `barstyle')"'
            }
            else {
                local plotlist `"`plotlist' (rbar start stop lane if rowtype == "bar", horizontal barwidth(`barwidth') `barstyle')"'
            }
        }

        quietly levelsof series_k if rowtype == "interval", local(intervallevels)
        local n_intervalcolors : word count `intervallevels'
        foreach k of local intervallevels {
            local ++plot_i
            local _ci = `n_barcolors' + `k'
            local col : word `_ci' of `colorlist'
            if "`col'" == "" local col "gs`=mod(`_ci',14)'"
            quietly levelsof series if rowtype == "interval" & ///
                series_k == `k', local(_ilab) clean
            local ilab "`_ilab'"
            local intervalstyle "lwidth(thick)"
            if !`use_scheme_colors' {
                local intervalstyle "`intervalstyle' lcolor(`col')"
            }
            local plotlist `"`plotlist' (pcspike lane start lane stop if rowtype == "interval" & series_k == `k', `intervalstyle')"'
            local legend_order `"`legend_order' `plot_i' `"`ilab'"'"'
        }

        * Event markers render for wide, long, and stset inputs in either mode.
        if "`markers'" != "none" {
            quietly levelsof series_k if rowtype == "event", local(eventlevels)
            foreach k of local eventlevels {
                local ++plot_i
                local _ci = `n_barcolors' + `n_intervalcolors' + `k'
                local col : word `_ci' of `colorlist'
                if "`col'" == "" local col "black"
                local sym : word `k' of `symbols'
                if "`sym'" == "" local sym "circle"
                if "`markers'" == "minimal" local sym "pipe"
                quietly levelsof series if rowtype == "event" & series_k == `k', ///
                    local(_elab) clean
                local elab "`_elab'"
                local eventstyle ///
                    "msymbol(`sym') mlwidth(vthin) msize(`msize')"
                if !`use_scheme_colors' {
                    local eventstyle ///
                        "`eventstyle' mcolor(`col') mlcolor(white)"
                }
                local plotlist `"`plotlist' (scatter lane xpoint if rowtype == "event" & series_k == `k', `eventstyle')"'
                local legend_order `"`legend_order' `plot_i' `"`elab'"'"'
            }
        }

        quietly count if rowtype == "censor"
        if r(N) > 0 & "`markers'" != "none" {
            local ++plot_i
            local censor_size "`msize'"
            if "`markers'" == "minimal" local censor_size "tiny"
            local plotlist `"`plotlist' (scatter lane xpoint if rowtype == "censor", msymbol(Oh) mcolor(gs4) mlwidth(medthick) msize(`censor_size'))"'
            local legend_order `"`legend_order' `plot_i' "Censored""'
        }

        quietly count if rowtype == "bar" & ongoing == 1
        if r(N) > 0 & "`continuation'" == "arrow" {
            local ++plot_i
            local plotlist `"`plotlist' (pcarrow lane stop lane `xtip' if rowtype == "bar" & ongoing == 1, mcolor(gs6) lcolor(gs6) msize(small))"'
        }
        else if r(N) > 0 & "`continuation'" == "cap" {
            local ++plot_i
            local plotlist `"`plotlist' (scatter lane stop if rowtype == "bar" & ongoing == 1, msymbol(pipe) mcolor(gs6) msize(tiny))"'
        }

        * Minimal tick so zero-width bars (event-only subjects) keep a visible
        * lane even when the span collapses to a point.
        quietly count if rowtype == "bar" & start == stop & !missing(start)
        if r(N) > 0 {
            local ++plot_i
            local plotlist `"`plotlist' (scatter lane start if rowtype == "bar" & start == stop & !missing(start), msymbol(pipe) mcolor(gs6) msize(`msize'))"'
        }

        if "`barlabel'" == "duration" {
            tempvar __sw_barlab __sw_blx
            gen str20 `__sw_barlab' = string(duration, "%9.0g") ///
                if rowtype == "bar" & !missing(duration)
            * Anchor labels just past the bar end, and past the arrow cap for
            * ongoing bars so the value never sits on top of the arrow.
            gen double `__sw_blx' = stop if rowtype == "bar"
            replace `__sw_blx' = `xtip' if rowtype == "bar" & ongoing == 1
            local ++plot_i
            local plotlist `"`plotlist' (scatter lane `__sw_blx' if rowtype == "bar" & !missing(duration), msymbol(none) mlabel(`__sw_barlab') mlabposition(3) mlabsize(small) mlabcolor(gs6))"'
        }

        if `"`xtitle'"' == "" local xtitle "Time"
        if `"`ytitle'"' == "" local ytitle "Subject"

        local ylabelopt "ylabel(none)"
        local labelmarginopt ""
        local blocklineopt ""
        if "`blockplot'" != "" {
            preserve
            local _restore_needed = 1
            keep if rowtype == "bar" & seg == 1
            sort rank
            local _block_lines ""
            if _N > 1 {
                forvalues _bi = 2/`=_N' {
                    if block_start[`_bi'] == 1 {
                        local _block_y = lane[`_bi'] + 0.5
                        local _block_lines "`_block_lines' `_block_y'"
                    }
                }
            }
            restore
            local _restore_needed = 0
            if strtrim("`_block_lines'") != "" {
                local blocklineopt ///
                    "yline(`_block_lines', lcolor(gs12) lpattern(solid))"
            }
            local ++plot_i
            local plotlist `"`plotlist' (scatter lane stop if rowtype == "bar" & seg == 1 & block_start == 1, msymbol(none) mlabel(blocklab) mlabposition(11) mlabsize(vsmall) mlabcolor(gs4))"'
        }
        if "`labelpolicy'" != "none" & ///
            !("`byplot'" != "" & "`bylayout'" == "compact") {
            preserve
            local _restore_needed = 1
            keep if rowtype == "bar"
            sort lane seg
            by lane: keep if _n == 1
            if "`labelpolicy'" == "every" {
                keep if mod(rank - 1, `labelevery') == 0
            }
            else if "`labelpolicy'" == "selected" {
                keep if label_selected == 1
            }
            else if "`labelpolicy'" == "every_selected" {
                keep if mod(rank - 1, `labelevery') == 0 | ///
                    label_selected == 1
            }
            sort lane
            local yspec ""
            forvalues _i = 1/`=_N' {
                local l = lane[`_i']
                local _ylab = label[`_i']
                local yspec `"`yspec' `l' `"`_ylab'"'"'
            }
            restore
            local _restore_needed = 0
            if `"`yspec'"' != "" {
                local ylabelopt `"ylabel(`yspec', angle(0) labsize(small))"'
            }
        }
        else if "`labelpolicy'" != "none" & "`byplot'" != "" & ///
            "`bylayout'" == "compact" {
            tempvar __sw_label_tag __sw_label_len
            egen byte `__sw_label_tag' = tag(id) if rowtype == "bar"
            if "`labelpolicy'" == "every" {
                replace `__sw_label_tag' = 0 if ///
                    mod(rank - 1, `labelevery') != 0
            }
            else if "`labelpolicy'" == "selected" {
                replace `__sw_label_tag' = 0 if label_selected != 1
            }
            else if "`labelpolicy'" == "every_selected" {
                replace `__sw_label_tag' = 0 if ///
                    mod(rank - 1, `labelevery') != 0 & label_selected != 1
            }
            gen long `__sw_label_len' = ustrlen(label) ///
                if `__sw_label_tag' == 1
            quietly summarize `__sw_label_len', meanonly
            if r(N) > 0 {
                local __sw_label_margin = ceil(1.5 * r(max))
                if `__sw_label_margin' < 10 local __sw_label_margin = 10
                if `__sw_label_margin' > 30 local __sw_label_margin = 30
                local ++plot_i
                local plotlist `"`plotlist' (scatter lane start if `__sw_label_tag' == 1, msymbol(none) mlabel(label) mlabposition(9) mlabsize(vsmall) mlabcolor(gs4))"'
                local labelmarginopt ///
                    "plotregion(margin(l+`__sw_label_margin'))"
            }
        }

        if "`addplotstub'" != "" {
            local addplot `"${`addplotstub'}"'
            local plotlist `"`plotlist' `addplot'"'
        }

        local graphopts `"`ylabelopt' `labelmarginopt' `blocklineopt' xtitle(`xtitle') ytitle(`ytitle')"'
        if "`graphreplace'" != "" {
            local graphopts `"`graphopts' name(`graphname', replace)"'
        }
        else {
            local graphopts `"`graphopts' name(`graphname')"'
        }
        if "`timefmt'" != "" {
            local graphopts ///
                `"`graphopts' xlabel(, format(`timefmt') angle(45) labsize(small))"'
        }
        if "`refline'" != "" {
            local graphopts `"`graphopts' xline(`refline', lpattern(dash) lcolor(gs8))"'
        }
        if "`byplot'" == "" {
            if `"`title'"' != "" local graphopts `"`graphopts' title(`title')"'
            if `"`subtitle'"' != "" local graphopts `"`graphopts' subtitle(`subtitle')"'
            if `"`note'"' != "" local graphopts `"`graphopts' note(`note')"'
        }
        if "`scheme'" != "" local graphopts `"`graphopts' scheme(`scheme')"'
        if `"`saving'"' != "" local graphopts `"`graphopts' saving(`saving')"'
        if `"`legend'"' != "" {
            * Merge user legend options with the generated label order so
            * positioning (e.g. legend(pos(6))) does not discard the series
            * labels. A user-supplied order()/off keeps full control.
            local _leglow = lower(`"`legend'"')
            if strpos(`"`_leglow'"', "order") | strpos(`"`_leglow'"', "off") ///
                | `"`legend_order'"' == "" {
                local graphopts `"`graphopts' legend(`legend')"'
            }
            else {
                local graphopts `"`graphopts' legend(order(`legend_order') `legend')"'
            }
        }
        else if `"`legend_order'"' != "" {
            local graphopts `"`graphopts' legend(order(`legend_order'))"'
        }
        else {
            local graphopts `"`graphopts' legend(off)"'
        }
        if "`byplot'" != "" {
            local _byopts ""
            if `"`title'"' != "" local _byopts `"`_byopts' title(`title')"'
            if `"`subtitle'"' != "" local _byopts `"`_byopts' subtitle(`subtitle')"'
            if `"`note'"' != "" local _byopts `"`_byopts' note(`note')"'
            else local _byopts `"`_byopts' note("")"'
            if "`bylayout'" == "compact" {
                local _byopts `"`_byopts' yrescale"'
            }
            if `panelcols' > 0 {
                local _byopts `"`_byopts' cols(`panelcols')"'
            }
            local graphopts `"`graphopts' by(group, `_byopts')"'
        }
        if `plotheight' > 0 {
            local graphopts `"`graphopts' ysize(`plotheight')"'
        }
        if `"`twowayopts'"' != "" local graphopts `"`graphopts' `twowayopts'"'

        local cmdline `"twoway `plotlist', `graphopts'"'
        return local cmdline `"`cmdline'"'

        if "`nograph'" == "" {
            twoway `plotlist', `graphopts'
            return local graphname "`graphname'"
        }
    }
    local rc = _rc
    if `_restore_needed' capture restore
    if `_changed_frame' capture frame change `_orig_frame'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
