*! check Version 1.0.3  13dec2025

*! Revision Author: Tim Copeland
*! Revised on  26 July 2020 at 12:11:00

*! Original Author: Michael N. Mitchell
*! Created on  5 May 2020 at 14:38:31

program define check, rclass
  version 14.0
  set varabbrev off
  syntax varlist(numeric), [SHORT]

  * Store stats for the last variable to return at the end
  local last_var : word `: word count `varlist'' of `varlist'

  * Validation: Check dataset has observations
  quietly count
  if r(N) == 0 {
    display as error "no observations in dataset"
    exit 2000
  }

  * Validation: Check for required external commands
  capture which mdesc
  if _rc {
    display as error "check requires the mdesc command"
    display as text "Install with: {stata ssc install mdesc:ssc install mdesc}"
    exit 199
  }
  capture which unique
  if _rc {
    display as error "check requires the unique command"
    display as text "Install with: {stata ssc install unique:ssc install unique}"
    exit 199
  }

  * Display full output (statistics + quality metrics)
  if "`short'" == "" {
*************************************************************************  
  * Part 0. Compute length of longest variable
  local max = 0
  foreach v of varlist `varlist' {
    local len = length("`v'")
    if (`len' > `max') {
      local max = `len'
    }
  }
  local maxlen = max(`max',7)  // At least 7 characters due to "Varname" 
  *************************************************************************  
  * Part 1. Compute Column Positions
  local col1 = 1
  local col2 = `col1' + `maxlen' + 1
  local colwidth = 10              
  local col3 = `col2' + `colwidth' + 1
  local col4 = `col3' + `colwidth' + 1
  local col5 = `col4' + `colwidth' 
  local col6 = `col5' + `colwidth' 
  local col7 = `col6' + `colwidth' 
  local col8 = `col7' + `colwidth' - 4
  local col9 = `col8' + `colwidth' - 4
  local col10 = `col9' + `colwidth' 
  local col11 = `col10' + `colwidth' 
  local col12 = `col11' + `colwidth' 
  local col13 = `col12' + `colwidth' 
  local col14 = `col13' + `colwidth' 
  local col15 = `col14' + `colwidth' 
  *************************************************************************  
  * Part 2. Display Column Headers
  display _col(`col1')      "Varname" _continue 
  display _col(`col2') %10s  "Obs"     _continue 
  display _col(`col3') %10s  "# Missing"     _continue 
  display _col(`col4') %10s  "% Missing"     _continue 
  display _col(`col5') %8s  "Unique"     _continue 
  display _col(`col6') %6s  "Type"     _continue 
  display _col(`col7') %6s  "Format"     _continue 
  display _col(`col8') %8s  "Mean"    _continue 
  display _col(`col9') %8s  "SD"      _continue 
  display _col(`col10') %8s  "Min"     _continue 
  display _col(`col11') %8s  "p25"     _continue 
  display _col(`col12') %8s  "Median"     _continue 
  display _col(`col13') %8s  "p75"     _continue 
  display _col(`col14') %8s  "Max"     _continue 
  display _col(`col15') %8s  "Variable Label"    
  *************************************************************************  
  * Part 3. Display each variable name, summary stats, and label
  foreach v of varlist `varlist' {
    display _col(`col1') "`v'"             _continue   // Disp varnamex
    quietly count if !missing(`v')                     // Calc N
    display _col(`col2') %10.0g `r(N)'      _continue   // Disp N
    quietly mdesc `v'                    // mdesc
    display _col(`col3') %10.0g `r(miss)'      _continue   // Disp # missing
    display _col(`col4') %10.4gc `r(percent)'      _continue   // Disp % missing
    quietly unique `v' if !missing(`v')                    // Calc Unique
    display _col(`col5') %8.0g `r(unique)'      _continue   // Disp Unique
    display _col(`col6') %6s "`:type `v''"     _continue   // Disp Type
    display _col(`col7') %6s "`:format `v''"      _continue   // Disp Format
    quietly summarize `v',d                              // Calc sum stats
    display _col(`col8') %8.3gc `r(mean)'   _continue   // Disp Mean
    display _col(`col9') %8.3gc `r(sd)'     _continue   // Disp SD      
    display _col(`col10') %8.0g `r(min)'    _continue   // Disp Min      
    display _col(`col11') %8.0g `r(p25)'    _continue   // Disp p25        
    display _col(`col12') %8.0g `r(p50)'    _continue   // Disp p50        
    display _col(`col13') %8.0g `r(p75)'    _continue   // Disp p75        
    display _col(`col14') %8.0g `r(max)'    _continue   // Disp Max     
    local varlab : variable label `v'                  // Make VarLab 
    display _col(`col15')       "`varlab'"              // Disp Varlab  
  }
}

else {
*************************************************************************  
  * Part 0. Compute length of longest variable
  local max = 0
  foreach v of varlist `varlist' {
    local len = length("`v'")
    if (`len' > `max') {
      local max = `len'
    }
  }
  local maxlen = max(`max',7)  // At least 7 characters due to "Varname" 
  *************************************************************************  
  * Part 1. Compute Column Positions
  local col1 = 1
  local col2 = `col1' + `maxlen'
  local colwidth = 12              
  local col3 = `col2' + `colwidth' + 1
  local col4 = `col3' + `colwidth' + 1
  local col5 = `col4' + `colwidth' 
  local col6 = `col5' + `colwidth' 
  local col7 = `col6' + `colwidth' 
  local col8 = `col7' + `colwidth' 
  local col9 = `col8' + `colwidth' 
  *************************************************************************  
  * Part 2. Display Column Headers
  display _col(`col1')      "Varname" _continue 
  display _col(`col2') %10s  "Obs"     _continue 
  display _col(`col3') %10s  "# Missing"     _continue 
  display _col(`col4') %10s  "% Missing"     _continue 
  display _col(`col5') %8s  "Unique"     _continue 
  display _col(`col6') %6s  "Type"     _continue 
  display _col(`col7') %6s  "Format"     _continue 
  display _col(`col8') %8s  "Variable Label"    
  *************************************************************************  
  * Part 3. Display each variable name, summary stats, and label
  foreach v of varlist `varlist' {
    display _col(`col1') "`v'"             _continue   // Disp varnamex
    quietly count if !missing(`v')                     // Calc N
    display _col(`col2') %10.0g `r(N)'      _continue   // Disp N
    quietly mdesc `v'                    // mdesc
    display _col(`col3') %10.0g `r(miss)'      _continue   // Disp # missing
    display _col(`col4') %10.4gc `r(percent)'      _continue   // Disp % missing
    quietly unique `v' if !missing(`v')                    // Calc Unique
    display _col(`col5') %8.0g `r(unique)'      _continue   // Disp Unique
    display _col(`col6') %6s "`:type `v''"     _continue   // Disp Type
    display _col(`col7') %6s "`:format `v''"      _continue   // Disp Format  
    local varlab : variable label `v'                  // Make VarLab
    display _col(`col8')       "`varlab'"              // Disp Varlab
  }

}

  * Return values for programmatic use
  return local varlist "`varlist'"
  return scalar nvars = wordcount("`varlist'")
  return local mode = cond("`short'" != "", "short", "full")

  * Return statistics for the last variable processed (for single-variable use)
  * Compute stats for the last variable
  quietly summarize `last_var', detail
  return scalar N = r(N)
  return scalar mean = r(mean)
  return scalar sd = r(sd)
  return scalar min = r(min)
  return scalar max = r(max)
  return scalar p25 = r(p25)
  return scalar p50 = r(p50)
  return scalar p75 = r(p75)

  quietly mdesc `last_var'
  return scalar nmissing = r(miss)

  quietly unique `last_var' if !missing(`last_var')
  return scalar unique = r(unique)
end