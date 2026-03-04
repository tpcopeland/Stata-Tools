/*  demo_tabtools.do - Generate screenshots for tabtools

    Produces 6 output types:
      1. Console output (table1 display) -> .smcl
      2. Excel table (table1_tc output) -> table1.xlsx
      3. Excel table (regtab regression) -> regtab.xlsx
      4. Excel table (effecttab treatment effects) -> effecttab.xlsx
      5. Excel table (tablex collect table) -> tablex.xlsx
      6. Excel table (stratetab incidence rates) -> stratetab.xlsx
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "tabtools/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop table1_tc
capture program drop tablex
capture program drop regtab
capture program drop effecttab
capture program drop stratetab
capture program drop _tabtools_common
capture program drop _tabtools_validate_path
capture program drop _tabtools_col_letter
capture program drop _tabtools_build_col_letters
quietly run tabtools/_tabtools_common.ado
quietly run tabtools/table1_tc.ado
quietly run tabtools/tablex.ado
quietly run tabtools/regtab.ado
quietly run tabtools/effecttab.ado
quietly run tabtools/stratetab.ado

* --- Setup data ---
sysuse auto, clear

* Label foreign for nicer table display
label define origin_lbl 0 "Domestic" 1 "Foreign", replace
label values foreign origin_lbl

* --- 1. Console output: table1_tc descriptive table ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

noisily table1_tc, by(foreign) ///
    vars(price contn %9.0fc \ mpg contn %5.1f \ weight contn %9.0fc \ ///
         length contn %5.1f \ rep78 cat)

log close demo

* --- 2. Excel: table1_tc export ---
table1_tc, by(foreign) ///
    vars(price contn %9.0fc \ mpg contn %5.1f \ weight contn %9.0fc \ ///
         length contn %5.1f \ rep78 cat) ///
    title("Table 1. Characteristics by Vehicle Origin") ///
    excel("`pkg_dir'/table1.xlsx") sheet("Table 1")

* --- 3. Excel: regtab regression table ---
collect clear
collect: regress price mpg weight length foreign
regtab, xlsx("`pkg_dir'/regtab.xlsx") sheet("OLS") ///
    title("Table 2. OLS Regression") coef("Coef.") ///
    stats(n)

* --- 4. Excel: effecttab treatment effects ---
teffects ipw (price) (foreign mpg weight), ate
effecttab, xlsx("`pkg_dir'/effecttab.xlsx") sheet("ATE") ///
    effect("ATE") title("Table 3. Treatment Effects") clean

* --- 5. Excel: tablex collect table export ---
version 17
collect clear
table foreign, statistic(mean price mpg weight) nformat(%9.1f)
tablex using "`pkg_dir'/tablex.xlsx", sheet("Summary") ///
    title("Table 4. Summary by Origin") replace
version 16

* --- 6. Excel: stratetab incidence rate table ---
* Create synthetic strate output files
preserve
clear
input str20 drug_class _D _Y double(_Rate _Lower _Upper)
"SSRI"   45 12500 0.0036 0.0026 0.0048
"SNRI"   32  8200 0.0039 0.0027 0.0055
"TCA"    18  4100 0.0044 0.0026 0.0069
end
save "`pkg_dir'/strate_out1_exp1.dta", replace

clear
input str20 drug_class _D _Y double(_Rate _Lower _Upper)
"SSRI"   28 12500 0.0022 0.0015 0.0032
"SNRI"   21  8200 0.0026 0.0016 0.0039
"TCA"    14  4100 0.0034 0.0019 0.0058
end
save "`pkg_dir'/strate_out2_exp1.dta", replace
restore

stratetab, using("`pkg_dir'/strate_out1_exp1" "`pkg_dir'/strate_out2_exp1") ///
    xlsx("`pkg_dir'/stratetab.xlsx") outcomes(2) ///
    outlabels("Outcome A \ Outcome B") ///
    title("Table 5. Incidence Rates by Drug Class")

* Clean up temp strate files
capture erase "`pkg_dir'/strate_out1_exp1.dta"
capture erase "`pkg_dir'/strate_out2_exp1.dta"

* --- Cleanup ---
clear
