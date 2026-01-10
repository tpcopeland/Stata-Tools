/*******************************************************************************
* build_tc_schemes.do
*
* Builds the tc_schemes package by downloading scheme files from original
* sources and consolidating them into the tc_schemes directory.
*
* Run this do-file from the tc_schemes directory to populate it with all
* required .scheme and .style files.
*
* Sources:
*   - blindschemes (SSC) by Daniel Bischof
*   - blindschemes_fix (CGDev) by Mead Over
*   - schemepack (GitHub) by Asjad Naqvi
*
* Author: Timothy P Copeland
* Date: 2025-01-11
*******************************************************************************/

clear all
set more off

// Get the directory where this do-file lives
local tcdir = c(pwd)
display as text "Building tc_schemes in: `tcdir'"
display as text "{hline 70}"

// Create temporary directory for downloads
tempfile tempdir
local tempdir = substr("`tempdir'", 1, length("`tempdir'") - 12)
capture mkdir "`tempdir'/tc_temp"
local dldir "`tempdir'/tc_temp"

/*******************************************************************************
* STEP 1: Install blindschemes from SSC
*******************************************************************************/
display as text ""
display as result "STEP 1: Installing blindschemes from SSC..."

capture ssc install blindschemes, replace
if _rc != 0 {
    display as error "Warning: Could not install blindschemes from SSC"
    display as error "You may need to download manually"
}
else {
    display as text "  blindschemes installed successfully"
}

/*******************************************************************************
* STEP 2: Install blindschemes_fix from CGDev
*******************************************************************************/
display as text ""
display as result "STEP 2: Installing blindschemes_fix from CGDev..."

capture net install blindschemes_fix, from("http://digital.cgdev.org/doc/stata/MO/Misc") replace
if _rc != 0 {
    display as text "  Note: blindschemes_fix not available or already applied"
    display as text "  (This is OK - it may be integrated into current blindschemes)"
}
else {
    display as text "  blindschemes_fix installed successfully"
}

/*******************************************************************************
* STEP 3: Install schemepack from GitHub (more current than SSC)
*******************************************************************************/
display as text ""
display as result "STEP 3: Installing schemepack from GitHub..."

capture net install schemepack, from("https://raw.githubusercontent.com/asjadnaqvi/stata-schemepack/main/installation/") replace
if _rc != 0 {
    display as error "Warning: Could not install schemepack from GitHub"
    display as text "Trying SSC instead..."
    capture ssc install schemepack, replace
    if _rc != 0 {
        display as error "Could not install schemepack from SSC either"
    }
}
else {
    display as text "  schemepack installed successfully"
}

/*******************************************************************************
* STEP 4: Locate PLUS directory and copy scheme files
*******************************************************************************/
display as text ""
display as result "STEP 4: Copying scheme files to tc_schemes directory..."

// Find the PLUS directory
local plusdir = c(sysdir_plus)
display as text "  PLUS directory: `plusdir'"

// Copy blindschemes files
local blindschemes "plotplain plotplainblind plottig plottigblind"
foreach scheme of local blindschemes {
    capture copy "`plusdir's/scheme-`scheme'.scheme" "`tcdir'/scheme-`scheme'.scheme", replace
    if _rc == 0 {
        display as text "    Copied: scheme-`scheme'.scheme"
    }
    else {
        display as error "    Missing: scheme-`scheme'.scheme"
    }
}

// Copy blindschemes color styles
local colors "vermillion sky turquoise reddish sea orangebrown ananas"
local colors "`colors' plb1 plb2 plb3 plg1 plg2 plg3 plr1 plr2"
local colors "`colors' ply1 ply2 ply3 pll1 pll2 pll3"
foreach color of local colors {
    capture copy "`plusdir'c/color-`color'.style" "`tcdir'/color-`color'.style", replace
    if _rc == 0 {
        display as text "    Copied: color-`color'.style"
    }
}

// Copy schemepack files - series schemes
local palettes "tableau cividis viridis hue brbg piyg ptol jet w3d"
local prefixes "white black gg"
foreach palette of local palettes {
    foreach prefix of local prefixes {
        local scheme "`prefix'_`palette'"
        capture copy "`plusdir's/scheme-`scheme'.scheme" "`tcdir'/scheme-`scheme'.scheme", replace
        if _rc == 0 {
            display as text "    Copied: scheme-`scheme'.scheme"
        }
        else {
            display as error "    Missing: scheme-`scheme'.scheme"
        }
    }
}

// Copy schemepack standalone schemes
local standalone "tab1 tab2 tab3 cblind1 ukraine swift_red neon rainbow"
foreach scheme of local standalone {
    capture copy "`plusdir's/scheme-`scheme'.scheme" "`tcdir'/scheme-`scheme'.scheme", replace
    if _rc == 0 {
        display as text "    Copied: scheme-`scheme'.scheme"
    }
    else {
        display as error "    Missing: scheme-`scheme'.scheme"
    }
}

/*******************************************************************************
* STEP 5: Verify installation
*******************************************************************************/
display as text ""
display as result "STEP 5: Verifying tc_schemes installation..."
display as text "{hline 70}"

// Count scheme files
local schemefiles: dir "`tcdir'" files "scheme-*.scheme"
local n_schemes: word count `schemefiles'

// Count style files
local stylefiles: dir "`tcdir'" files "color-*.style"
local n_styles: word count `stylefiles'

display as text ""
display as text "Installation summary:"
display as result "  Scheme files:      `n_schemes'"
display as result "  Color style files: `n_styles'"
display as text ""

if `n_schemes' >= 35 {
    display as result "SUCCESS: tc_schemes package is ready!"
    display as text ""
    display as text "The package can now be installed with:"
    display as text {c -(}cmd:net install tc_schemes, from("`tcdir'"){c )-}
}
else {
    display as error "WARNING: Some scheme files may be missing"
    display as text "Expected ~39 scheme files, found `n_schemes'"
    display as text ""
    display as text "Check that blindschemes and schemepack installed correctly"
}

display as text ""
display as text "{hline 70}"
display as text "Build complete."
