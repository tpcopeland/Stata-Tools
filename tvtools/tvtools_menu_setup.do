*! tvtools_menu_setup.do - Add tvtools dialogs to Stata menus
*! Version 1.0 - 2025-11-17

/*
This file adds tvtools dialogs to the Stata User menu.

To use:
1. Run this file once: do tvtools_menu_setup.do
2. To make permanent, add these commands to your profile.do file

To remove the persistent entries, delete only the tvtools menu lines from
profile.do and restart Stata. Do not use window menu clear, which removes
unrelated user menu additions too.
*/

capture program drop tvtools_menu_setup
program define tvtools_menu_setup
    version 16.0

    * Stata exposes no API to inspect or remove individual user-menu items.
    * A session marker therefore prevents a second invocation from appending
    * duplicate items. Restart Stata (or clear this global deliberately) to
    * retry after a partial GUI failure.
    if "$TVTOOLS_MENU_SETUP_DONE" == "1" {
        display as text "tvtools menu setup already attempted in this Stata session; no items appended"
        exit
    }
    global TVTOOLS_MENU_SETUP_DONE "1"

    * Display current menu status
    display as text _n "tvtools Menu Setup" _n "{hline 60}"

    * Check if commands exist
    capture which tvexpose
    if _rc {
        display as error "Warning: tvexpose.ado not found in ado path"
        display as error "Make sure tvtools is properly installed"
    }
    else {
        display as text "✓ tvexpose.ado found"
    }

    capture which tvmerge
    if _rc {
        display as error "Warning: tvmerge.ado not found in ado path"
        display as error "Make sure tvtools is properly installed"
    }
    else {
        display as text "✓ tvmerge.ado found"
    }

    capture which tvevent
    if _rc {
        display as error "Warning: tvevent.ado not found in ado path"
        display as error "Make sure tvtools is properly installed"
    }
    else {
        display as text "✓ tvevent.ado found"
    }

    * Add submenu to User menu
    display as text _n "Adding menu items..."

    * Every GUI operation is captured so the setup remains safe in batch/headless
    * Stata and when entries already exist. Report the exact rc rather than
    * assuming every failure means "duplicate".
    capture window menu append submenu "stUser" "Time-varying exposures"
    local submenu_rc = _rc
    if `submenu_rc' == 0 {
        display as text "✓ Created 'Time-varying exposures' submenu"
    }
    else {
        display as text "  Submenu not added (window menu rc=`submenu_rc')"
    }

    * Add tvexpose dialog
    capture window menu append item "Time-varying exposures" ///
        "Create exposure variables (tvexpose)" "db tvexpose"
    local expose_rc = _rc
    if `expose_rc' == 0 {
        display as text "✓ Added tvexpose dialog to menu"
    }
    else display as text "  tvexpose item not added (window menu rc=`expose_rc')"

    * Add tvmerge dialog
    capture window menu append item "Time-varying exposures" ///
        "Merge TV datasets (tvmerge)" "db tvmerge"
    local merge_rc = _rc
    if `merge_rc' == 0 {
        display as text "✓ Added tvmerge dialog to menu"
    }
    else display as text "  tvmerge item not added (window menu rc=`merge_rc')"

    * Add tvevent dialog
    capture window menu append item "Time-varying exposures" ///
        "Add events to TV datasets (tvevent)" "db tvevent"
    local event_rc = _rc
    if `event_rc' == 0 {
        display as text "✓ Added tvevent dialog to menu"
    }
    else display as text "  tvevent item not added (window menu rc=`event_rc')"

    * Refresh menus
    capture window menu refresh
    local refresh_rc = _rc
    if `refresh_rc' == 0 display as text "✓ Menu refreshed"
    else display as text "  Menu refresh unavailable (window menu rc=`refresh_rc')"

    * Instructions
    display as text _n "{hline 60}"
    display as text "Menu setup finished without altering unrelated menu entries."
    display as text _n "Access dialogs via:"
    display as text "  User > Time-varying exposures > Create exposure variables"
    display as text "  User > Time-varying exposures > Merge TV datasets"
    display as text "  User > Time-varying exposures > Add events to TV datasets"
    display as text _n "To make this permanent (persist across Stata sessions):"
    display as text "1. Find your PERSONAL directory: type {cmd:sysdir}"
    display as text "2. Create or edit {cmd:profile.do} in that directory"
    display as text "3. Add these lines to profile.do:" _n
    display as input `"    capture window menu append submenu "stUser" "Time-varying exposures""'
    display as input `"    capture window menu append item "Time-varying exposures" "Create exposure variables (tvexpose)" "db tvexpose""'
    display as input `"    capture window menu append item "Time-varying exposures" "Merge TV datasets (tvmerge)" "db tvmerge""'
    display as input `"    capture window menu append item "Time-varying exposures" "Add events to TV datasets (tvevent)" "db tvevent""'
    display as input `"    capture window menu refresh"'
    display as text _n "Then restart Stata. The menus will appear automatically."
    display as text _n "{hline 60}"
end

* Run the setup
tvtools_menu_setup
