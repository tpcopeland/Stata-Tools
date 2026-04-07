/*  demo_datefix.do - String-to-date conversion demo (v1.0.2)

    Demonstrates datefix on various string date formats:
      1. Auto-detected ordering with multiple variables
      2. Explicit MDY ordering + custom display format
      3. Two-digit years with topyear()
      4. newvar() to preserve original string
      5. newvar() + drop to replace original
      6. Numeric variable passthrough
      7. DMY ordering

    Produces:
      - Console output -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "datefix/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop datefix
quietly run datefix/datefix.ado

* --- Begin console log ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* =====================================================================
* EXAMPLE 1: Basic conversion with auto-detected ordering
* =====================================================================

noisily display as text "EXAMPLE 1: Auto-detect ordering (multiple variables)"

clear
input str25 visit_date str25 birth_date
"2024-03-15"    "1985/06/21"
"2024/01/10"    "1990-12-01"
"2023-11-28"    "1978/03/14"
"2024-07-04"    "2001/09/30"
"2023-09-01"    "1995/07/15"
end

noisily list, clean noobs

* Convert both at once — datefix auto-detects ordering
noisily datefix visit_date birth_date
noisily list, clean noobs

* =====================================================================
* EXAMPLE 2: Explicit MDY ordering + custom display format
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 2: MDY ordering + Month DD, CCYY format"

clear
input str20 enrollment
"03/15/2024"
"01/10/2024"
"11/28/2023"
"07/04/2024"
"09/01/2023"
end

noisily list, clean noobs

noisily datefix enrollment, order(MDY) df(%tdMonth_DD,_CCYY)
noisily list, clean noobs

* =====================================================================
* EXAMPLE 3: Two-digit years with topyear()
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 3: Two-digit years with topyear(2025)"

clear
input str15 founding_date
"15/06/89"
"01/03/95"
"22/11/78"
"07/08/01"
"30/12/65"
end

noisily list, clean noobs

noisily datefix founding_date, order(DMY) topyear(2025)
noisily list, clean noobs

* =====================================================================
* EXAMPLE 4: newvar() to preserve original string
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 4: Preserve original with newvar()"

clear
input str20 raw_date
"2024-03-15"
"2024-01-10"
"2023-11-28"
end

noisily list, clean noobs

noisily datefix raw_date, newvar(clean_date) order(YMD)
noisily list, clean noobs

* =====================================================================
* EXAMPLE 5: newvar() + drop to replace original
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 5: Replace original with newvar() + drop"

clear
input str20 admit_str
"06/15/2024"
"01/22/2024"
"11/03/2023"
end

noisily list, clean noobs

noisily datefix admit_str, newvar(admit_date) drop order(MDY) df(%tdDD/NN/CCYY)
noisily list, clean noobs

* =====================================================================
* EXAMPLE 6: Numeric variable — apply date format
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 6: Numeric variable passthrough"

clear
input double numdate
21915
22081
22280
end

noisily list, clean noobs

* Numeric variables just get the date format applied
noisily datefix numdate
noisily list, clean noobs

* =====================================================================
* EXAMPLE 7: DMY ordering with abbreviated month format
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 7: DMY ordering + abbreviated month format"

clear
input str20 event_date
"25/12/2023"
"14/02/2024"
"01/01/2025"
end

noisily list, clean noobs

noisily datefix event_date, order(DMY) df(%tdDD_Mon._CCYY)
noisily list, clean noobs

log close demo

* --- Cleanup ---
clear
