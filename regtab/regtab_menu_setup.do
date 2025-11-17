*! regtab_menu_setup.do - Add regtab dialog to Stata menus
*! Version 1.0 - 2025-11-17

/*
This file adds the regtab dialog to the Stata User menu.

To use:
1. Run this file once: do regtab_menu_setup.do
2. To make permanent, add these commands to your profile.do file

To remove:
  window menu clear

Then restart Stata.
*/

program define regtab_menu_setup
    version 17.0

    * Display current menu status
    display as text _n "regtab Menu Setup" _n "{hline 60}"

    * Check if command exists
    capture which regtab
    if _rc {
        display as error "Warning: regtab.ado not found in ado path"
        display as error "Make sure regtab is properly installed"
    }
    else {
        display as text "✓ regtab.ado found"
    }

    * Add submenu to User menu
    display as text _n "Adding menu items..."

    * Create submenu (use capture in case it already exists)
    capture window menu append submenu "stUser" "Tables"
    if _rc == 0 {
        display as text "✓ Created 'Tables' submenu"
    }
    else {
        display as text "  'Tables' submenu already exists"
    }

    * Add regtab dialog
    capture window menu append item "Tables" ///
        "Regression tables (regtab)" "db regtab"
    if _rc == 0 {
        display as text "✓ Added regtab dialog to menu"
    }

    * Refresh menus
    window menu refresh
    display as text "✓ Menu refreshed"

    * Instructions
    display as text _n "{hline 60}"
    display as text "SUCCESS! Menu item added."
    display as text _n "Access dialog via:"
    display as text "  User > Tables > Regression tables"
    display as text _n "To make this permanent (persist across Stata sessions):"
    display as text "1. Find your PERSONAL directory: type {cmd:sysdir}"
    display as text "2. Create or edit {cmd:profile.do} in that directory"
    display as text "3. Add these lines to profile.do:" _n
    display as input `"    capture window menu append submenu "stUser" "Tables""'
    display as input `"    window menu append item "Tables" "Regression tables (regtab)" "db regtab""'
    display as input `"    window menu refresh"'
    display as text _n "Then restart Stata. The menu will appear automatically."
    display as text _n "{hline 60}"
end

* Run the setup
regtab_menu_setup
