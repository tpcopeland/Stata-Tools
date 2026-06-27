/*  demo_fvgen.do - Demo output for fvgen

    The value proposition: native factor-variable notation makes table/export
    tools emit cryptic coefficient names and base/omitted "reference" rows;
    running the SAME regression on the variables fvgen materializes yields one
    clean, self-labeled row per coefficient. Both sides are the identical model
    (identical coefficients, SEs, R-squared) — only the row presentation differs.

    Produces:
      1. export_comparison.md - before/after markdown coefficient tables
                                (markdown-table export only; no console capture)

    Run from the repo root:
      stata-mp -b do fvgen/demo/demo_fvgen.do
*/

version 16.0
set varabbrev off
set linesize 120

* --- Paths ---
local pkg_dir "fvgen/demo"
capture mkdir "`pkg_dir'"
local out "`pkg_dir'/export_comparison.md"

* --- Install package from local source (as an installed user would have it) ---
capture ado uninstall fvgen
quietly net install fvgen, from("`c(pwd)'/fvgen") replace

**# Helper: append a markdown coefficient table from the active regression
* uselabels==1 renders each term via its variable label (the fvgen side);
* uselabels==0 renders the raw coefficient name (the native side's clutter).
capture program drop _fvgen_md_table
program define _fvgen_md_table
    args matname uselabels title
    file write mdout "**`title'**" _n _n
    file write mdout "| Term | Coef. | 95% CI | p |" _n
    file write mdout "|---|---:|:---:|---:|" _n
    local names : colfullnames `matname'
    local j 0
    foreach nm of local names {
        local ++j
        local b  = `matname'[1,`j']
        local p  = `matname'[4,`j']
        local lo = `matname'[5,`j']
        local hi = `matname'[6,`j']
        if "`nm'" == "_cons" {
            local lab "Intercept"
        }
        else if `uselabels' {
            * strip a leading omit operator (o./No.) so an omitted fvgen
            * variable still resolves to its label
            local cleannm = "`nm'"
            if regexm("`nm'", "^[0-9]*o\.(.+)$") local cleannm = regexs(1)
            local lab ""
            capture local lab : variable label `cleannm'
            if `"`lab'"' == "" local lab "`nm'"
        }
        else {
            local lab "`nm'"
        }
        if missing(`p') {
            file write mdout "| `lab' | _(base)_ |  |  |" _n
        }
        else {
            local bf  : display %8.0f `b'
            local lof : display %8.0f `lo'
            local hif : display %8.0f `hi'
            local pf  : display %5.3f `p'
            file write mdout "| `lab' | `=strtrim("`bf'")' | (`=strtrim("`lof'")', `=strtrim("`hif'")') | `=strtrim("`pf'")' |" _n
        }
    }
    file write mdout _n
end

**# Setup data
sysuse auto, clear
label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best"
label values rep78 rl

**# Markdown export
capture file close mdout
file open mdout using "`out'", write replace text
file write mdout "# fvgen export comparison" _n _n
file write mdout "Each pair below is the *same regression* — identical coefficients, standard errors, and R-squared. Native factor-variable notation makes export tools print cryptic coefficient names (`1.foreign#c.mpg`) and base/omitted reference rows; fvgen yields one clean, self-labeled row per coefficient, ready to drop straight into a manuscript table." _n _n

**## Example 1: categorical x continuous
file write mdout "## Example 1: `i.foreign##c.mpg`" _n _n
quietly regress price i.foreign##c.mpg
matrix RT = r(table)
_fvgen_md_table RT 0 "Before — regress price i.foreign##c.mpg"

fvgen i.foreign##c.mpg, replace
quietly regress price `r(allvars)'
matrix RT = r(table)
_fvgen_md_table RT 1 "After — fvgen i.foreign##c.mpg; regress price r(allvars)"

**## Example 2: categorical x categorical (more dramatic clutter)
file write mdout "## Example 2: `i.foreign##i.rep78`" _n _n
fvgen, drop          // tidy up the generated variables before the next model
quietly regress price i.foreign##i.rep78
matrix RT = r(table)
_fvgen_md_table RT 0 "Before — regress price i.foreign##i.rep78"

fvgen i.foreign##i.rep78, replace
quietly regress price `r(allvars)'
matrix RT = r(table)
_fvgen_md_table RT 1 "After — fvgen i.foreign##i.rep78; regress price r(allvars)"

file write mdout "_fvgen composes with the tabtools `regtab`/`table1_tc` export family and `esttab`/`collect`: the clean labels and the `fvgen_term`/`fvgen_role` provenance characteristics carry straight through to the rendered table._" _n
file close mdout

* --- Echo result + cleanup ---
type "`out'"
fvgen, drop
clear
