# tvtools Installation Guide

Complete instructions for installing and configuring tvtools for Stata.

---

## Quick Start

### Method 1: Using net install (Recommended)

If tvtools is available from a web repository:

```stata
net from [repository-url]
net install tvtools
```

After installation completes, Stata will display setup instructions. The package includes:
- All command and dialog files
- Help documentation
- Menu setup script (`tvtools_menu_setup.do`)
- This installation guide

**Optional menu integration:**
```stata
do tvtools_menu_setup.do
```

### Method 2: Manual Installation

Copy these files to your Stata PERSONAL or PLUS directory:
- `tvexpose.ado`
- `tvexpose.dlg`
- `tvexpose.sthlp`
- `tvmerge.ado`
- `tvmerge.dlg`
- `tvmerge.sthlp`
- `tvevent.ado`
- `tvevent.dlg`
- `tvevent.sthlp`
- `tvtools_menu_setup.do` (optional, for menu integration)
- `INSTALLATION.md` (optional, this file)

**Find your directories:**
```stata
sysdir
```

Look for:
- **PERSONAL:** Your personal ado directory (recommended for custom packages)
- **PLUS:** User-installed packages from SSC (alternative location)

---

## Verify Installation

```stata
which tvexpose
which tvmerge
which tvevent
```

All three should display the file paths. If you see "command not found," the files are not in your ado path.

---

## Access Dialogs

**Immediate access (no configuration required):**
```stata
db tvexpose
db tvmerge
db tvevent
```

**Add to menus (optional, see below):**
Run the menu setup script for dropdown menu access.

---

## Detailed Installation

### Method 1: Manual Installation (All Platforms)

#### Step 1: Locate Your PERSONAL Directory

1. In Stata, type:
   ```stata
   sysdir
   ```

2. Note the path shown for **PERSONAL**

3. Navigate to this directory:
   - **Windows:** Usually `C:\Users\[YourName]\ado\personal\`
   - **Mac:** Usually `/Users/[YourName]/Library/Application Support/Stata/ado/personal/`
   - **Linux:** Usually `~/ado/personal/`

4. If the directory doesn't exist, create it

#### Step 2: Copy Files

Copy all 9 tvtools files to the PERSONAL directory:
```
tvexpose.ado
tvexpose.dlg
tvexpose.sthlp
tvmerge.ado
tvmerge.dlg
tvmerge.sthlp
tvevent.ado
tvevent.dlg
tvevent.sthlp
```

#### Step 3: Verify

Restart Stata (or type `discard` to reload ado files), then:
```stata
which tvexpose
which tvmerge
which tvevent
help tvexpose
help tvmerge
help tvevent
```

All commands should work without errors.

---

## Menu Integration (Optional)

By default, the dialogs are NOT in Stata menus. Users must either use `db` commands or add menu integration.

### Option A: Temporary Menu Setup (Current Session Only)

Run the provided setup script:
```stata
do tvtools_menu_setup.do
```

This adds menu items for the current session. They will disappear when you restart Stata.

### Option B: Permanent Menu Setup (Persists Across Sessions)

#### Step 1: Locate or Create profile.do

1. Find your PERSONAL directory:
   ```stata
   sysdir
   ```

2. Navigate to that directory

3. Check if `profile.do` exists
   - If yes: Edit it
   - If no: Create a new file named `profile.do`

#### Step 2: Add Menu Commands

Add these lines to your `profile.do`:

```stata
* tvtools menu integration
capture window menu append submenu "stUser" "Time-varying exposures"
window menu append item "Time-varying exposures" "Create exposure variables (tvexpose)" "db tvexpose"
window menu append item "Time-varying exposures" "Merge TV datasets (tvmerge)" "db tvmerge"
window menu append item "Time-varying exposures" "Add events to TV datasets (tvevent)" "db tvevent"
window menu refresh
```

**Note:** The `capture` on the first line prevents errors if the submenu already exists.

#### Step 3: Restart Stata

Close and reopen Stata. The menus will now appear automatically.

#### Step 4: Access Via Menus

Navigate to: **User > Time-varying exposures**

You'll see:
- Create exposure variables (tvexpose)
- Merge TV datasets (tvmerge)
- Add events to TV datasets (tvevent)

---

## Accessing the Dialogs

### Method 1: Command Line (Always Available)

```stata
db tvexpose
db tvmerge
db tvevent
```

This works immediately after installation, no menu setup required.

### Method 2: Dropdown Menus (After Setup)

If you completed the menu integration steps above:

1. Click **User** in the Stata menu bar
2. Hover over **Time-varying exposures**
3. Click your desired dialog

---

## Troubleshooting

### "command tvexpose not found"

**Cause:** Files not in ado path

**Solution:**
1. Verify files are in PERSONAL or PLUS directory
2. Run `which tvexpose` to check location
3. Try `discard` to reload ado files
4. Restart Stata

### "file tvexpose.dlg not found"

**Cause:** .dlg file not in same directory as .ado file

**Solution:**
1. Ensure all 9 files are in the same directory
2. Check that .dlg files were copied (not just .ado files)
3. Run `which tvexpose` to see where Stata found the .ado file
4. Verify .dlg file is in that same directory

### Dialog opens but shows errors

**Cause:** Missing required fields or incorrect syntax in .dlg file

**Solution:**
1. Re-download and replace the .dlg files
2. Check for file corruption during transfer
3. Ensure you're using Stata 16.0 or later

### Menus don't appear after profile.do edit

**Cause:** profile.do not running or syntax error

**Solutions:**
1. Restart Stata (closing and reopening)
2. Check profile.do for syntax errors:
   ```stata
   do "$HOME/ado/personal/profile.do"
   ```
   (adjust path as needed)
3. Look for error messages during Stata startup
4. Try running the menu commands manually to verify they work

### Menu items appear but clicking does nothing

**Cause:** Incorrect `db` command syntax in menu

**Solution:**
1. Verify menu syntax exactly matches installation instructions
2. Test dialogs directly: `db tvexpose`, `db tvmerge`, and `db tvevent`
3. If direct commands work but menus don't, recreate menu items:
   ```stata
   window menu clear
   * Then re-run menu setup commands
   ```

### "cannot find help file"

**Cause:** .sthlp files not installed

**Solution:**
1. Verify all 9 files were copied (including .sthlp files)
2. .sthlp files must be in same directory as .ado files
3. Check filenames are exactly: `tvexpose.sthlp`, `tvmerge.sthlp`, and `tvevent.sthlp`

---

## Uninstallation

### Remove Files

Delete from your PERSONAL directory:
```
tvexpose.ado
tvexpose.dlg
tvexpose.sthlp
tvmerge.ado
tvmerge.dlg
tvmerge.sthlp
tvevent.ado
tvevent.dlg
tvevent.sthlp
```

### Remove Menus (if configured)

#### Temporary:
```stata
window menu clear
```

#### Permanent:
1. Open your `profile.do` file
2. Remove or comment out the tvtools menu commands
3. Restart Stata

---

## Testing Your Installation

Run these commands to verify everything works:

```stata
* Test command availability
which tvexpose
which tvmerge
which tvevent

* Test help files
help tvexpose
help tvmerge
help tvevent

* Test dialogs
db tvexpose
db tvmerge
db tvevent

* Test actual commands (requires data)
* See documentation for full examples
```

---

## File Checklist

After installation, you should have:

**Required files (must be in same directory):**
- ✓ tvexpose.ado - Command program
- ✓ tvexpose.dlg - Dialog definition
- ✓ tvexpose.sthlp - Help documentation
- ✓ tvmerge.ado - Command program
- ✓ tvmerge.dlg - Dialog definition
- ✓ tvmerge.sthlp - Help documentation
- ✓ tvevent.ado - Command program
- ✓ tvevent.dlg - Dialog definition
- ✓ tvevent.sthlp - Help documentation

**Optional files (for reference, not required for operation):**
- tvexpose_dialog.md - Extended documentation
- tvmerge_dialog.md - Extended documentation
- INSTALLATION.md - This file
- tvtools_menu_setup.do - Menu setup helper

---

## Platform-Specific Notes

### Windows

- Default PERSONAL path: `C:\Users\[YourName]\ado\personal\`
- File paths use backslashes: `\`
- Edit profile.do with any text editor (Notepad, Notepad++, etc.)

### macOS

- Default PERSONAL path: `/Users/[YourName]/Library/Application Support/Stata/ado/personal/`
- Library folder may be hidden; use Finder > Go > Go to Folder
- File paths use forward slashes: `/`
- Edit profile.do with TextEdit, VS Code, or any text editor

### Linux

- Default PERSONAL path: `~/ado/personal/`
- File paths use forward slashes: `/`
- Edit profile.do with any text editor (nano, vim, gedit, etc.)
- Ensure files have read permissions: `chmod 644 *.ado *.dlg *.sthlp`

---

## Getting Help

### Command documentation:
```stata
help tvexpose
help tvmerge
help tvevent
```

### Extended dialog documentation:
- See `tvexpose_dialog.md`
- See `tvmerge_dialog.md`

### Common issues:
- Check this INSTALLATION.md troubleshooting section
- Verify all 9 files are installed in the correct location
- Ensure Stata 16.0 or later

---

## Version Requirements

- **Stata Version:** 16.0 or later
- **Operating Systems:** Windows, macOS, Linux (all supported)
- **Required files:** 9 total (3 per command: .ado, .dlg, .sthlp)

---

## Summary

**Minimum installation:**
1. Copy 9 files to PERSONAL directory
2. Use dialogs via: `db tvexpose`, `db tvmerge`, and `db tvevent`

**Full installation with menus:**
1. Copy 9 files to PERSONAL directory
2. Add menu commands to profile.do
3. Restart Stata
4. Access via User menu

Both approaches provide full functionality. Menu integration is optional for convenience.
