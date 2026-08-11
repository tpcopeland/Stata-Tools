---
title: "console_local_bundle"
---

## Build an offline bundle from installed PLUS files

```stata
.     noisily pkgtransfer, download(local) limited(pkgtransfer)
>         os(Windows) dofile("_offline_install.do")
>         zipfile("_offline_bundle.zip")
```

```
Starting file copy (2 files) from local directory...
Copying OS-specific plugins from online...
Preparation of installation do file and package ZIP file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
            r(zipfile) : "_offline_bundle.zip"
             r(dofile) : "_offline_install.do"
                 r(os) : "Windows"
      r(download_mode) : "local"
       r(package_list) : "pkgtransfer"
```
