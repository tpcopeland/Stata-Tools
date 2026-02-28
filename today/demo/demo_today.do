/*  demo_today.do - Date/time global macro demo

    Demonstrates today with various formatting options:
      1. Default format (YMD)
      2. European/US date styles
      3. Time formatting with custom separators
      4. Timezone conversion

    Produces:
      - Console output -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "today/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop today
quietly run today/today.ado

* --- Begin console log ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* =====================================================================
* EXAMPLE 1: Default format (YYYY_MM_DD)
* =====================================================================

noisily display as text "EXAMPLE 1: Default format"

noisily today
noisily display `"  today      = $today"'
noisily display `"  today_time = $today_time"'

* =====================================================================
* EXAMPLE 2: European format (DD Mon YYYY)
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 2: European format (dmony)"

noisily today, df(dmony)
noisily display `"  today      = $today"'
noisily display `"  today_time = $today_time"'

* =====================================================================
* EXAMPLE 3: US format (MM/DD/YYYY)
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 3: US format (mdy)"

noisily today, df(mdy)
noisily display `"  today      = $today"'
noisily display `"  today_time = $today_time"'

* =====================================================================
* EXAMPLE 4: Hours and minutes only, dot separator
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 4: Hours:minutes only, dot separator"

noisily today, hm tsep(.)
noisily display `"  today_time = $today_time"'

* =====================================================================
* EXAMPLE 5: Using $today in file naming
* =====================================================================

noisily display _newline
noisily display as text "EXAMPLE 5: Practical file naming"

today
noisily display `"  Log file:    analysis_$today.log"'
noisily display `"  Export file:  results_$today.csv"'
noisily display `"  Timestamp:   $today_time"'

log close demo

* --- Cleanup ---
clear
