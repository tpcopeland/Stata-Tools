/*  demo_fvgen.do - Demo output for fvgen

    The value proposition: native factor-variable notation makes table/export
    tools emit cryptic coefficient names and base/omitted "reference" rows;
    running the SAME regression on the variables fvgen materializes yields one
    clean, self-labeled row per coefficient. Full-rank designs reproduce the
    same coefficient basis. With empty cells, Stata may omit different columns;
    the fitted values and fit remain equivalent even when coefficients differ.

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
local mkdir_rc = _rc
if !inlist(`mkdir_rc', 0, 693) exit `mkdir_rc'
local out "`pkg_dir'/export_comparison.md"

* --- Install package from local source (as an installed user would have it) ---
ado dir fvgen
capture ado uninstall fvgen
local uninstall_rc = _rc
if !inlist(`uninstall_rc', 0, 111) exit `uninstall_rc'
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
            local label_rc = _rc
            if `label_rc' local lab ""
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
file write mdout "Each pair below spans the same model space. Full-rank designs reproduce the same coefficients, standard errors, and fit. With empty cells or other exact collinearity, Stata may choose a different omitted-column basis, so individual coefficients can differ even though fitted values and fit agree. Native factor-variable notation makes export tools print cryptic coefficient names (`1.foreign#c.mpg`) and base/omitted reference rows; fvgen yields one clean, self-labeled row per coefficient, ready to drop straight into a manuscript table." _n _n

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
tempvar native_hat flat_hat fit_delta
quietly predict double `native_hat', xb
local native_r2 = e(r2)
_fvgen_md_table RT 0 "Before — regress price i.foreign##i.rep78"

fvgen i.foreign##i.rep78, replace
quietly regress price `r(allvars)'
matrix RT = r(table)
quietly predict double `flat_hat', xb
local flat_r2 = e(r2)
quietly gen double `fit_delta' = abs(`native_hat' - `flat_hat')
quietly summarize `fit_delta', meanonly
local max_fit_delta = r(max)
_fvgen_md_table RT 1 "After — fvgen i.foreign##i.rep78; regress price r(allvars)"

local native_r2_text : display %9.7f `native_r2'
local flat_r2_text : display %9.7f `flat_r2'
local max_fit_text : display %9.3e `max_fit_delta'
file write mdout "This example has empty interaction cells, so the two equivalent fits use different omitted-column bases. Native R-squared: `=strtrim("`native_r2_text'")'; flattened R-squared: `=strtrim("`flat_r2_text'")'; maximum absolute fitted-value difference: `=strtrim("`max_fit_text'")'." _n _n

file write mdout "_fvgen composes with the tabtools `regtab`/`table1_tc` export family and `esttab`/`collect`: the clean labels and the `fvgen_term`/`fvgen_role` provenance characteristics carry straight through to the rendered table._" _n
file close mdout

* --- Echo result + cleanup ---
type "`out'"
fvgen, drop
clear
