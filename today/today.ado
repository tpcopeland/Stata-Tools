*! today Version 1.0.1  2025/12/03
*! Author: Timothy P. Copeland

/*
    DESCRIPTION:
    'today' sets two global macros, $today and $today_time, containing the current date and time respectively.
    It offers flexible formatting options for both date and time components, making it convenient for incorporating
    the current date and time into Stata programs, logs, and output files.

    SYNTAX:
    today [, df(string) tsep(string) hm from(string) to(string)]

        df:         Specifies the output date format. Valid options are:
                        ymd:   Year-Month-Day (e.g., 2024_12_19) - Default
                        dmony: Day-MonthName-Year (e.g., 19 Dec 2024)
                        dmy:   Day/Month/Year (e.g., 19/12/2024)
                        mdy:   Month/Day/Year (e.g., 12/19/2024)

        tsep:       Specifies the separator for hours, minutes, and seconds in the time component.
                    The default is a period (":") (e.g., 14:30:45).

        hm:         Specifies that only hours and minutes should be included in the time, omitting seconds.
                    The time will be in HH.MM format (e.g., 14:30).

        from:    Specifies the source timezone in UTC format (e.g., UTC+7 or UTC-5).
                    Default is current time zone. Must be specified with to(string).

        to:      Specifies the target timezone in UTC format (e.g., UTC+7 or UTC-5).
                    Default is current time zone. Must be specified with from(string).
*/
program today, rclass
    version 14.0
    set varabbrev off
    syntax [, DF(string) TSep(string) HM FROM(string) TO(string)]
    quietly {
        // Default values
        local date_format "ymd" // Default: YYYY_MM_DD
        local time_separator ":"
        local include_seconds 1 // Include seconds by default
        local today = date("`c(current_date)'", "DMY")
        
        // Default timezone offsets
        local from_offset = 0
        local to_offset = 0
        // Check if only one of 'from' or 'to' is specified
		if ("`from'" != "" & "`to'" == "") | ("`from'" == "" & "`to'" != "") {
			noisily di in red "Error: Both 'from' and 'to' options must be specified together."
			exit 198
		}
		
        // Process timezone options
        if "`from'" != "" {
            if regexm("`from'", "^UTC([+-])([0-9]+)(:([0-9]+))?$") {
                local sign = regexs(1)
                local hours = regexs(2)
                local minutes = regexs(4)
                if "`minutes'" == "" local minutes = 0

                // Validate minutes
                if `minutes' >= 60 {
                    noisily di in red "Error: Invalid minutes in timezone: `minutes'"
                    exit 198
                }

                // Calculate offset in hours (fractional)
                local from_offset = `hours' + `minutes'/60
                if "`sign'" == "-" local from_offset = -`from_offset'

                // Validate timezone range
                if `from_offset' < -12 | `from_offset' > 14 {
                    noisily di in red "Error: Timezone offset must be between UTC-12 and UTC+14"
                    exit 198
                }
            }
            else {
                noisily di in red "Error: Invalid from format. Use UTC+X or UTC-X format (e.g., UTC+5, UTC-3:30)."
                exit 198
            }
        }
        
        if "`to'" != "" {
            if regexm("`to'", "^UTC([+-])([0-9]+)(:([0-9]+))?$") {
                local sign = regexs(1)
                local hours = regexs(2)
                local minutes = regexs(4)
                if "`minutes'" == "" local minutes = 0

                // Validate minutes
                if `minutes' >= 60 {
                    noisily di in red "Error: Invalid minutes in timezone: `minutes'"
                    exit 198
                }

                // Calculate offset in hours (fractional)
                local to_offset = `hours' + `minutes'/60
                if "`sign'" == "-" local to_offset = -`to_offset'

                // Validate timezone range
                if `to_offset' < -12 | `to_offset' > 14 {
                    noisily di in red "Error: Timezone offset must be between UTC-12 and UTC+14"
                    exit 198
                }
            }
            else {
                noisily di in red "Error: Invalid to format. Use UTC+X or UTC-X format (e.g., UTC+5, UTC-3:30)."
                exit 198
            }
        }
        
        // Process other options
        if "`df'" != "" {
            local date_format = "`df'"
        }
        if "`tsep'" != "" {
            local time_separator = "`tsep'"
        }
        if "`hm'" != "" {
            local include_seconds 0
        }
        
        // Parse the current time
        local hour = substr("`c(current_time)'", 1, 2)
        local minute = substr("`c(current_time)'", 4, 2)
        local second = substr("`c(current_time)'", 7, 2)
        
        // Calculate time difference and adjust
        local net_offset = `to_offset' - `from_offset'
        local new_hour = `hour' + `net_offset'

        // Handle day boundary crossings (can be multiple days)
        local days_adjust = floor(`new_hour' / 24)
        local new_hour = mod(`new_hour', 24)

        // Handle negative hours
        if `new_hour' < 0 {
            local new_hour = `new_hour' + 24
            local days_adjust = `days_adjust' - 1
        }
        
        // Adjust the date if necessary
        if `days_adjust' != 0 {
            local today = `today' + `days_adjust'
        }
        
        // Format the adjusted hour
        local hour = string(`new_hour', "%02.0f")
        
        // Parse the adjusted date
        local year = year(`today')
        local month = month(`today')
        local day = day(`today')
        
        // Format the date part based on the df option
        if lower("`date_format'") == "ymd" {
            local date_td = "`year'_`=string(`month', "%02.0f")'_`=string(`day', "%02.0f")'"
        }
        else if lower("`date_format'") == "dmony" {
            local month_name: word `month' of Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
            local date_td = "`day' `month_name' `year'"
        }
        else if lower("`date_format'") == "dmy" {
            local date_td = "`day'/`=string(`month', "%02.0f")'/`year'"
        }
        else if lower("`date_format'") == "mdy" {
            local date_td = "`=string(`month', "%02.0f")'/`=string(`day', "%02.0f")'/`year'"
        }
        else {
            noisily di in red "Error: Invalid date format specified in df option."
            exit 198
        }
        
        // Format the time part
        if `include_seconds' == 1 {
            local time_td = "`hour'`time_separator'`minute'`time_separator'`second'"
        }
        else {
            local time_td = "`hour'`time_separator'`minute'"
        }
        
        // Set the global macros
        global today = "`date_td'"
        global today_time = "`date_td' `time_td'"
        
        // Display confirmation messages
        noisily display in result "{bf:\$today} set to: " in input "$today"
        noisily display in result "{bf:\$today_time} set to: " in input "$today_time"
        if "`from'" != "" | "`to'" != "" {
            noisily display in result "Time converted from `from' to `to'"
        }
    }

    // Return values for programmatic use
    return local today "$today"
    return local today_time "$today_time"
end