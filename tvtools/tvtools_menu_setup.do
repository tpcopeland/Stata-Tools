*! tvtools_menu_setup.do - Add tvtools dialogs to Stata menus
*! Version 1.0 - 2025-11-17

/*
This file adds tvtools dialogs to the Stata User menu.

To use:
1. Run this file once: do tvtools_menu_setup.do
2. To make permanent, add these commands to your profile.do file

To remove:
  window menu clear

Then restart Stata.
*/

program define tvtools_menu_setup
    version 16.0

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

    * Create submenu (use capture in case it already exists)
    capture window menu append submenu "stUser" "Time-varying exposures"
    if _rc == 0 {
        display as text "✓ Created 'Time-varying exposures' submenu"
    }
    else {
        display as text "  'Time-varying exposures' submenu already exists"
    }

    * Add tvexpose dialog
    capture window menu append item "Time-varying exposures" ///
        "Create exposure variables (tvexpose)" "db tvexpose"
    if _rc == 0 {
        display as text "✓ Added tvexpose dialog to menu"
    }

    * Add tvmerge dialog
    capture window menu append item "Time-varying exposures" ///
        "Merge TV datasets (tvmerge)" "db tvmerge"
    if _rc == 0 {
        display as text "✓ Added tvmerge dialog to menu"
    }

    * Add tvevent dialog
    capture window menu append item "Time-varying exposures" ///
        "Add events to TV datasets (tvevent)" "db tvevent"
    if _rc == 0 {
        display as text "✓ Added tvevent dialog to menu"
    }

    * Refresh menus
    window menu refresh
    display as text "✓ Menu refreshed"

    * Instructions
    display as text _n "{hline 60}"
    display as text "SUCCESS! Menu items added."
    display as text _n "Access dialogs via:"
    display as text "  User > Time-varying exposures > Create exposure variables"
    display as text "  User > Time-varying exposures > Merge TV datasets"
    display as text "  User > Time-varying exposures > Add events to TV datasets"
    display as text _n "To make this permanent (persist across Stata sessions):"
    display as text "1. Find your PERSONAL directory: type {cmd:sysdir}"
    display as text "2. Create or edit {cmd:profile.do} in that directory"
    display as text "3. Add these lines to profile.do:" _n
    display as input `"    capture window menu append submenu "stUser" "Time-varying exposures""'
    display as input `"    window menu append item "Time-varying exposures" "Create exposure variables (tvexpose)" "db tvexpose""'
    display as input `"    window menu append item "Time-varying exposures" "Merge TV datasets (tvmerge)" "db tvmerge""'
    display as input `"    window menu append item "Time-varying exposures" "Add events to TV datasets (tvevent)" "db tvevent""'
    display as input `"    window menu refresh"'
    display as text _n "Then restart Stata. The menus will appear automatically."
    display as text _n "{hline 60}"
end

* Run the setup
tvtools_menu_setup
