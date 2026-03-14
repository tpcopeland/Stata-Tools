/*  demo_raincloud.do - Generate screenshots for raincloud package

    Produces 6 output types:
      1. Console output (return values) -> .smcl -> .png
      2. Basic raincloud by groups (graph) -> .png
      3. Vertical raincloud with mean (graph) -> .png
      4. Customized raincloud (graph) -> .png
      5. Mirror (split violin) (graph) -> .png
      6. Custom colors with mirror (graph) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "raincloud/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop raincloud
quietly run raincloud/raincloud.ado

* --- Setup data ---
sysuse auto, clear
label variable mpg "Miles per Gallon"
label variable price "Price (USD)"

* --- 1. Console output: over groups with return values ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily raincloud mpg, over(foreign) seed(2026)
noisily return list
noisily matrix list r(stats), format(%9.2f)
log close demo

* --- 2. Basic raincloud by groups ---
raincloud mpg, over(foreign) seed(2026) ///
    title("Distribution of Fuel Efficiency by Origin") ///
    name(basic, replace)
graph export "`pkg_dir'/raincloud_basic.png", name(basic) replace width(1200)
capture graph close basic

* --- 3. Vertical orientation with mean ---
raincloud price, over(foreign) vertical mean seed(2026) ///
    opacity(60) jitter(0.5) ///
    title("Price Distribution by Origin") ///
    name(vert_plot, replace)
graph export "`pkg_dir'/raincloud_vertical.png", name(vert_plot) replace width(1200)
capture graph close vert_plot

* --- 4. Customized: cloud + box only (no scatter) ---
raincloud mpg, over(rep78) norain seed(2026) ///
    opacity(40) cloudwidth(0.5) ///
    title("MPG by Repair Record") ///
    name(custom, replace)
graph export "`pkg_dir'/raincloud_custom.png", name(custom) replace width(1200)
capture graph close custom

* --- 5. Mirror (split violin) ---
raincloud mpg, over(foreign) mirror mean seed(2026) ///
    opacity(60) ///
    title("Split Violin: Fuel Efficiency by Origin") ///
    name(mirror_plot, replace)
graph export "`pkg_dir'/raincloud_mirror.png", name(mirror_plot) replace width(1200)
capture graph close mirror_plot

* --- 6. Custom colors with mirror ---
raincloud mpg, over(foreign) mirror norain seed(2026) ///
    colors(midblue cranberry) opacity(70) ///
    title("Custom Colors: Full Violin") ///
    name(colors_plot, replace)
graph export "`pkg_dir'/raincloud_colors.png", name(colors_plot) replace width(1200)
capture graph close colors_plot

* --- Cleanup ---
capture graph close _all
clear
