---
title: "console_scripts"
---

## All eligible packages

```stata
.     noisily pkgtransfer, dofile("_all_packages.do")
```

```
Preparation of installation do file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  2

macros:
             r(dofile) : "_all_packages.do"
                 r(os) : "Unix"
      r(download_mode) : "script_only"
       r(package_list) : "demofixture pkgtransfer"
```

```stata
.     noisily type "_all_packages.do"
```

```
net install demofixture, replace from("https://example.org/stata/")
net install pkgtransfer, replace from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer/")
```

## limited() normalizes repeated package names

```stata
.     noisily pkgtransfer, limited(pkgtransfer pkgtransfer)
>         os(MacOSX) dofile("_limited_packages.do")
```

```
Preparation of installation do file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
             r(dofile) : "_limited_packages.do"
                 r(os) : "MacOSX"
      r(download_mode) : "script_only"
       r(package_list) : "pkgtransfer"
```

## skip() excludes an exact package name

```stata
.     noisily pkgtransfer, skip(demofixture)
>         dofile("_skip_packages.do")
```

```
Preparation of installation do file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
             r(dofile) : "_skip_packages.do"
                 r(os) : "Unix"
      r(download_mode) : "script_only"
       r(package_list) : "pkgtransfer"
```
