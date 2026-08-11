---
title: "console_restore"
---

## Restore the original online source after offline installation

```stata
.     noisily pkgtransfer, restore
```

```
Restoring installation pathways to online sources...
Installation pathways restored!
```

```stata
.     noisily return list
```

```
macros:
                 r(os) : "Unix"
      r(download_mode) : "restore"
```

```stata
.     noisily type "`destination_plus'/stata.trk"
```

```
* 00000001
*! version 1.0.0
* Do not erase or edit this file
* It is used by Stata to track the ado and help
* files you have installed.
S https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer
N pkgtransfer.pkg
D 11 Aug 2026
U 1
d pkgtransfer feature demo
f p/pkgtransfer.ado
f p/pkgtransfer.sthlp
e
```
