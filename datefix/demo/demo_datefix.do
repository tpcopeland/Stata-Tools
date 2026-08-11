/*  demo_datefix.do - String-to-date conversion demo

    Demonstrates datefix on various string date formats:
      1. Auto-detected ordering with multiple variables
      2. Explicit MDY ordering + custom display format
      3. Two-digit years with topyear()
      4. newvar() to preserve original string
      5. newvar() + drop to replace original
      6. Numeric variable passthrough
      7. DMY ordering

    Produces:
      - Console output -> console_output.log

    Author: Timothy P Copeland, Karolinska Institutet
*/

version 16.0
local _demo_varabbrev = c(varabbrev)
local _demo_linesize = c(linesize)
set varabbrev off
set linesize 120

**# Paths and local installation

local demo_dir "`c(pwd)'/datefix/demo"
capture mkdir "`demo_dir'"
capture ado uninstall datefix
quietly net install datefix, from("`c(pwd)'/datefix") replace

capture log close _all
log using "`demo_dir'/console_output.log", replace text name(demo) nomsg

**# Example 1: Auto-detect ordering with multiple variables

clear
input str25 visit_date str25 birth_date
"2024-03-15"    "1985/06/21"
"2024/01/10"    "1990-12-01"
"2023-11-28"    "1978/03/14"
"2024-07-04"    "2001/09/30"
"2023-09-01"    "1995/07/15"
end
noisily list, clean noobs
noisily datefix visit_date birth_date
noisily list, clean noobs

**# Example 2: Explicit MDY ordering and custom display format

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

**# Example 3: Two-digit years with topyear()

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

**# Example 4: Preserve the original string with newvar()

clear
input str20 raw_date
"2024-03-15"
"2024-01-10"
"2023-11-28"
end
noisily list, clean noobs
noisily datefix raw_date, newvar(clean_date) order(YMD)
noisily list, clean noobs

**# Example 5: Replace the original with newvar() and drop

clear
input str20 admit_str
"06/15/2024"
"01/22/2024"
"11/03/2023"
end
noisily list, clean noobs
noisily datefix admit_str, newvar(admit_date) drop order(MDY) df(%tdDD/NN/CCYY)
noisily list, clean noobs

**# Example 6: Numeric variable passthrough

clear
input double numdate
21915
22081
22280
end
noisily list, clean noobs
noisily datefix numdate
noisily list, clean noobs

**# Example 7: DMY ordering with abbreviated month format

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
clear
set linesize `_demo_linesize'
set varabbrev `_demo_varabbrev'
