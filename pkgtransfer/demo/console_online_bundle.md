---
title: "console_online_bundle"
---

## Download a fresh offline bundle from the recorded source URL

```stata
.     noisily pkgtransfer, download(online) limited(pkgtransfer)
>         os(MacOSX) dofile("_online_bundle_install.do")
>         zipfile("_online_bundle.zip")
```

```
Starting download of 1 packages...
Progress: 1/1 packages (100%)
Preparation of installation do file and package ZIP file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
            r(zipfile) : "_online_bundle.zip"
             r(dofile) : "_online_bundle_install.do"
                 r(os) : "MacOSX"
      r(download_mode) : "online"
       r(package_list) : "pkgtransfer"
```
