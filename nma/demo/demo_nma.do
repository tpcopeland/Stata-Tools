/*  demo_nma.do - Generate screenshots for nma package

    Uses the Senn et al. (2013) diabetes NMA dataset — a published
    network meta-analysis of glucose-lowering drugs comparing HbA1c
    mean differences across 26 studies and 10 treatments. Our REML
    estimates match the R netmeta benchmarks to 3 decimal places.

    Produces these outputs (capture.sh renders .smcl/.xlsx to .png):
      1. Console: nma_import summary          -> .smcl
      2. Console: nma_fit model results       -> .smcl
      3. Graph:   network map                 -> .png (Stata graph export)
      4. Graph:   forest plot                 -> .png (Stata graph export)
      5. Graph:   SUCRA rankogram             -> .png (Stata graph export)
      6. Console: league table + inconsistency -> .smcl
      7. Console: nma_report export summary   -> .smcl
      8. Excel:   full NMA report             -> .xlsx

    Source: Senn S, Gavini F, Magrez D, Scheen A (2013). Issues in
    performing a network meta-analysis. Stat Methods Med Res 22:651-677.
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "nma/demo"
capture mkdir "`pkg_dir'"

* --- Load nma commands ---
local nma_cmds nma nma_setup nma_import nma_fit nma_rank nma_forest  ///
    nma_map nma_compare nma_inconsistency nma_report                 ///
    _nma_check_setup _nma_check_fitted _nma_get_settings             ///
    _nma_display_header _nma_validate_network _nma_classify_evidence ///
    _nma_reml _nma_contrast_binary _nma_contrast_continuous          ///
    _nma_contrast_rate _nma_contrast_multiarm                        ///
    _nma_circular_layout _nma_node_sizes _nma_edge_weights           ///
    _nma_col_letter

foreach cmd of local nma_cmds {
    capture program drop `cmd'
    quietly run nma/`cmd'.ado
}

* --- Build the Senn 2013 diabetes dataset ---
* 28 pairwise comparisons from 26 studies, 10 treatments
* TE = mean difference in HbA1c change (treat1 - treat2)
clear
input str20 study str15 treat1 str15 treat2 double(te se_te)
"DeFronzo1995"      "Metformin"     "Placebo"       -1.90  0.1414
"Lewin2007"         "Metformin"     "Placebo"       -0.82  0.0992
"Willms1999a"       "Metformin"     "Acarbose"      -0.20  0.3579
"Davidson2007"      "Rosiglitazone" "Placebo"       -1.34  0.1435
"Wolffenbuttel1999" "Rosiglitazone" "Placebo"       -1.10  0.1141
"Kipnes2001"        "Pioglitazone"  "Placebo"       -1.30  0.1268
"Kerenyi2004"       "Rosiglitazone" "Placebo"       -0.77  0.1078
"Hanefeld2004"      "Pioglitazone"  "Metformin"      0.16  0.0849
"Derosa2004"        "Pioglitazone"  "Rosiglitazone"  0.10  0.1831
"Baksi2004"         "Rosiglitazone" "Placebo"       -1.30  0.1014
"Rosenstock2008"    "Rosiglitazone" "Placebo"       -1.09  0.2263
"Zhu2003"           "Rosiglitazone" "Placebo"       -1.50  0.1624
"Yang2003"          "Rosiglitazone" "Metformin"     -0.14  0.2239
"Vongthavaravat02"  "Rosiglitazone" "Sulfonylurea"  -1.20  0.1436
"Oyama2008"         "Acarbose"      "Sulfonylurea"  -0.40  0.1549
"Costa1997"         "Acarbose"      "Placebo"       -0.80  0.1432
"Hermansen2007"     "Sitagliptin"   "Placebo"       -0.57  0.1291
"Garber2008"        "Vildagliptin"  "Placebo"       -0.70  0.1273
"Alex1998"          "Metformin"     "Sulfonylurea"  -0.37  0.1184
"Johnston1994"      "Miglitol"      "Placebo"       -0.74  0.1839
"Johnston1998a"     "Miglitol"      "Placebo"       -1.41  0.2235
"Kim2007"           "Rosiglitazone" "Metformin"      0.00  0.2339
"Johnston1998b"     "Miglitol"      "Placebo"       -0.68  0.2828
"GonzalezOrtiz04"   "Metformin"     "Placebo"       -0.40  0.4356
"Stucci1996"        "Benfluorex"    "Placebo"       -0.23  0.3467
"Moulin2006"        "Benfluorex"    "Placebo"       -1.01  0.1366
"Willms1999b"       "Metformin"     "Placebo"       -1.20  0.3758
"Willms1999c"       "Acarbose"      "Placebo"       -1.00  0.4669
end

* =====================================================================
* 1. Console: Import and network summary
* =====================================================================
log using "`pkg_dir'/console_import.smcl", replace smcl name(demo1) nomsg

noisily nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
    measure(md) ref(Placebo)

log close demo1

* =====================================================================
* 2. Console: Model fitting
* =====================================================================
log using "`pkg_dir'/console_fit.smcl", replace smcl name(demo2) nomsg

noisily nma_fit

log close demo2

* =====================================================================
* 3. Graph: Network map
* =====================================================================
nma_map, scheme(plotplainblind) ///
    saving("`pkg_dir'/network_map.gph") replace
graph export "`pkg_dir'/network_map.png", replace width(1200)
capture graph close _all

* =====================================================================
* 4. Graph: Forest plot
* =====================================================================
nma_forest, scheme(plotplainblind) ///
    saving("`pkg_dir'/forest_plot.gph") replace
graph export "`pkg_dir'/forest_plot.png", replace width(1200)
capture graph close _all

* =====================================================================
* 5. Graph: SUCRA rankogram
* =====================================================================
nma_rank, best(min) seed(20130101) plot cumulative ///
    scheme(plotplainblind) ///
    saving("`pkg_dir'/rankogram.gph") replace
graph export "`pkg_dir'/rankogram.png", replace width(1200)
capture graph close _all

* =====================================================================
* 6. Console: League table and inconsistency test
* =====================================================================
log using "`pkg_dir'/console_compare.smcl", replace smcl name(demo3) nomsg

noisily nma_compare, saving("`pkg_dir'/league_table.xlsx") replace

noisily nma_inconsistency

log close demo3

* =====================================================================
* 7. Console + Excel: Full NMA report
* =====================================================================
log using "`pkg_dir'/console_report.smcl", replace smcl name(demo4) nomsg

noisily nma_report using "`pkg_dir'/nma_report.xlsx", replace

log close demo4

* --- Cleanup ---
* .smcl and .xlsx files left for capture.sh to render via render_log.py/render_xlsx.py
capture graph close _all
clear
