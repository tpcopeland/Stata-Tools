# massdesas

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Batch convert SAS datasets to Stata format.

## Description

`massdesas` recursively converts all SAS dataset files (.sas7bdat) to Stata format (.dta) within a specified directory and all its subdirectories. This command is designed to streamline the process of converting large collections of SAS files to Stata format, which would otherwise require manual conversion of each file.

The command scans the specified directory tree, identifies all .sas7bdat files, and converts each one to a .dta file in the same location with the same filename (but .dta extension). This preserves the original directory structure while making all datasets accessible in Stata.

**Warning:** When using the `erase` option, the original .sas7bdat files will be permanently deleted after successful conversion. Ensure you have backups before using this option.

## Dependencies

**Required:**
- **filelist** command - Install with: `ssc install filelist`
- **fs** command - Install with: `ssc install fs`
- Stata's built-in `import sas` (available in Stata 14+)

Ensure all dependencies are properly installed before using `massdesas`.

## Installation

```stata
net install massdesas, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/massdesas")
```

## Syntax

```stata
massdesas [, directory(directory_name) erase lower]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `directory(directory_name)` | current working directory | Specifies the root directory containing the .sas7bdat files. The command will search this directory and all its subdirectories for SAS dataset files to convert. |
| `erase` | not erased | Specifies that the original .sas7bdat files should be deleted after successful conversion to .dta format. **Use with caution** as the deletion is permanent. It is recommended to test the conversion on a small sample first and verify the .dta files are readable before using this option on your full dataset collection. Files are only deleted if conversion was successful. |
| `lower` | original case preserved | Specifies that all variable names in the converted .dta files should be converted to lowercase. This is useful for ensuring consistency in variable naming conventions, as SAS variable names can be case-sensitive while Stata variable names are typically lowercase by convention. |

## Examples

### Example 1: Convert All SAS Files in Current Directory

```stata
massdesas
```

This converts all .sas7bdat files in the current working directory and its subdirectories.

### Example 2: Convert All SAS Files in Specific Directory

```stata
massdesas, directory("C:/Data/SAS_Files")
```

### Example 3: Convert with Lowercase Variable Names

```stata
massdesas, directory("C:/Data/SAS_Files") lower
```

This ensures all variable names in the converted files are lowercase, following Stata conventions.

### Example 4: Convert and Delete Original SAS Files (Use with Caution!)

```stata
massdesas, directory("C:/Data/SAS_Files") erase
```

**Warning:** This permanently deletes the original .sas7bdat files after conversion.

### Example 5: Complete Workflow - Test Before Erasing

```stata
* First, test on a backup copy
massdesas, directory("C:/Data/SAS_Files_Backup") lower

* Verify conversion was successful by opening some files
use "C:/Data/SAS_Files_Backup/dataset1.dta", clear
describe

* If successful, run on actual data
massdesas, directory("C:/Data/SAS_Files") lower erase
```

This demonstrates the recommended workflow: test on a backup first, verify the conversion, then run on your actual data.

### Example 6: Convert Files in Nested Directory Structure

```stata
* Directory structure:
* C:/Project/
*   ├── Raw/
*   │   ├── baseline.sas7bdat
*   │   └── followup.sas7bdat
*   └── Derived/
*       └── analysis.sas7bdat

massdesas, directory("C:/Project") lower

* Results in:
* C:/Project/Raw/baseline.dta
* C:/Project/Raw/followup.dta
* C:/Project/Derived/analysis.dta
```

This example shows how `massdesas` preserves the directory structure while converting all SAS files throughout the tree.

### Example 7: Full Conversion with All Options

```stata
massdesas, directory("C:/data/sas_files") lower erase
```

Convert all SAS files to Stata format with lowercase variable names and remove the original SAS files after successful conversion.

## Remarks

### Processing Behavior

- The command processes files sequentially, so conversion of large directory trees with many SAS files may take considerable time
- Progress is displayed as each file is converted
- If a conversion fails for any file, `massdesas` will display an error message for that file and continue processing remaining files
- When using the `erase` option, files are only deleted if conversion was successful

### Best Practices

1. **Always test first**: Run the conversion on a backup copy of your data before using the `erase` option
2. **Verify conversions**: Open and check several converted .dta files to ensure the conversion preserved your data correctly
3. **Check variable names**: If using the `lower` option, verify that lowercase variable names don't create conflicts
4. **Monitor progress**: For large directory trees, monitor the conversion progress to ensure it completes successfully
5. **Keep backups**: Maintain backups of your original SAS files, especially when using the `erase` option

## Requirements

- Stata 14.0 or higher
- `filelist` command (install via: `ssc install filelist`)
- `fs` command (install via: `ssc install fs`)

## Version History

- **Version 1.0.3** (5 December 2025): Minor updates
- **Version 1.0.1** (3 December 2025): Bug fixes and documentation updates
  - Fixed syntax error in path separator replacement
  - Corrected dependency documentation
  - Updated version compatibility declaration
- **Version 1.0.0** (2 December 2025): GitHub publication release
- **Version 1.0** (24 July 2020): Initial release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help import sas` - Stata's built-in SAS file import command
- `ssc describe filelist` - File listing utility
- `ssc describe fs` - File system utilities

## Getting Help

For more detailed information, you can access the Stata help file:
```stata
help massdesas
```
