*! table1_tc_menu_setup.do - Add table1_tc dialog to Stata menus
*! Version 1.0 - 2025-11-17

/*
This file adds the table1_tc dialog to the Stata User menu.

To use:
1. Run this file once: do table1_tc_menu_setup.do
2. To make permanent, add these commands to your profile.do file

To remove:
  window menu clear

Then restart Stata.
*/

program define table1_tc_menu_setup
    version 14.2

    * Display current menu status
    display as text _n "table1_tc Menu Setup" _n "{hline 60}"

    * Check if command exists
    capture which table1_tc
    if _rc {
        display as error "Warning: table1_tc.ado not found in ado path"
        display as error "Make sure table1_tc is properly installed"
    }
    else {
        display as text "✓ table1_tc.ado found"
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

    * Add table1_tc dialog
    capture window menu append item "Tables" ///
        "Table 1 - Baseline characteristics (table1_tc)" "db table1_tc"
    if _rc == 0 {
        display as text "✓ Added table1_tc dialog to menu"
    }

    * Refresh menus
    window menu refresh
    display as text "✓ Menu refreshed"

    * Instructions
    display as text _n "{hline 60}"
    display as text "SUCCESS! Menu item added."
    display as text _n "Access dialog via:"
    display as text "  User > Tables > Table 1 - Baseline characteristics"
    display as text _n "To make this permanent (persist across Stata sessions):"
    display as text "1. Find your PERSONAL directory: type {cmd:sysdir}"
    display as text "2. Create or edit {cmd:profile.do} in that directory"
    display as text "3. Add these lines to profile.do:" _n
    display as input `"    capture window menu append submenu "stUser" "Tables""'
    display as input `"    window menu append item "Tables" "Table 1 - Baseline characteristics (table1_tc)" "db table1_tc""'
    display as input `"    window menu refresh"'
    display as text _n "Then restart Stata. The menu will appear automatically."
    display as text _n "{hline 60}"
end

* Run the setup
table1_tc_menu_setup
