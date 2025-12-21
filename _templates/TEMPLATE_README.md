# TEMPLATE

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Brief one-line description of what the command does.

## Description

`TEMPLATE` provides a more detailed description of what the command does. This section explains:

- The problem the command solves
- Key features and capabilities
- When and why users would use this command

This section can be multiple paragraphs for complex commands, or omitted entirely for simple commands where the one-liner is sufficient.

## Dependencies

**Required:**
- **dependency_name** - Install with: `ssc install dependency_name`

**Optional:**
- **optional_dependency** - Only needed for specific features

*Note: Omit this entire section if the command has no dependencies.*

## Installation

```stata
net install TEMPLATE, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/TEMPLATE")
```

## Syntax

```stata
TEMPLATE varlist [if] [in] [, options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| **required_option(varname)** | *(required)* | Description of the required option |
| **optional_option** | off | Description of the optional option |
| **generate(newvar)** | TEMPLATE_result | Name for output variable |
| **replace** | off | Allow replacing existing variables |

## Examples

### Example 1: Basic usage

```stata
sysuse auto, clear
TEMPLATE price mpg
```

### Example 2: With options

```stata
sysuse auto, clear
TEMPLATE price mpg, optional_option generate(result)
```

### Example 3: Using if/in conditions

```stata
sysuse auto, clear
TEMPLATE price mpg if foreign == 0, generate(result)
```

## Stored Results

`TEMPLATE` stores the following in `r()`:

**Scalars:**

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations |

**Macros:**

| Result | Description |
|--------|-------------|
| `r(varlist)` | Variables specified |

**Matrices:**

| Result | Description |
|--------|-------------|
| `r(results)` | Matrix of results |

*Note: Omit the Stored Results section if the command stores nothing.*

## Requirements

- Stata 16.0 or higher

## Version History

- **Version 1.0.1** (DD Month YYYY): Description of changes
- **Version 1.0.0** (DD Month YYYY): Initial release

*Note: Use "## Version" instead of "## Version History" if there's only one version.*

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help related_command` - Description
- [External resource](https://example.com) - Description

*Note: Omit the See Also section if there are no related commands.*
