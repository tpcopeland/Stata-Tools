This directory will contain the .Rd help files for the tvtools R package.

The .Rd files are generated automatically from the roxygen2 documentation
comments in the R source files:
  - /home/user/Stata-Tools/tvtools-r/R/tvexpose.R
  - /home/user/Stata-Tools/tvtools-r/R/tvmerge.R
  - /home/user/Stata-Tools/tvtools-r/R/data.R

To generate the help files:

Method 1: Run the provided script
  cd /home/user/Stata-Tools/tvtools-r
  Rscript generate_docs.R

Method 2: Run from within R
  setwd("/home/user/Stata-Tools/tvtools-r")
  roxygen2::roxygenize()

Method 3: Run devtools::document()
  setwd("/home/user/Stata-Tools/tvtools-r")
  devtools::document()

After generation, the following help files will be created:
  - tvexpose.Rd     (help for tvexpose function)
  - tvmerge.Rd      (help for tvmerge function)
  - cohort.Rd       (help for cohort dataset)
  - hrt_exposure.Rd (help for hrt_exposure dataset)
  - dmt_exposure.Rd (help for dmt_exposure dataset)
