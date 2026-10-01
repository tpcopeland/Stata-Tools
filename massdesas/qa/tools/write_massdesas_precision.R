# Independent real SAS numeric source for massdesas precision QA.
# Author: Timothy P Copeland, Karolinska Institutet
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1)
if (!requireNamespace("haven", quietly=TRUE)) stop("Install required R package haven")
values <- c(.12345678912345, .999999981, 1.2345678912345e-12, 1234567891234.5)
haven::write_sas(data.frame(ID=seq_along(values),Precise=values),args[[1]])
stopifnot(identical(as.double(haven::read_sas(args[[1]])$Precise),values))
