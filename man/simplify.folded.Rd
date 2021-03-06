% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/meta.R
\name{simplify.folded}
\alias{simplify.folded}
\title{Simplify Folded}
\usage{
\method{simplify}{folded}(x, ...)
}
\arguments{
\item{x}{folded}

\item{...}{passed arguments}
}
\value{
folded data.frame
}
\description{
Simplify folded. Per each combination of VARIABLE and META, find the minimum left subset of remaining columns necessary for uniquely distinguishing VALUE, setting other columns to NA. Then drop columns that are completely NA and remove duplicate records.
}
\examples{
library(magrittr)
library(dplyr)
data(events)
x <- events
x \%<>\% filter(CMT == 2) \%>\% select(-EVID,-CMT,-AMT)
x \%>\% fold(USUBJID,TIME, meta = list(DV ~ BLQ, DV ~ LLOQ), simplify = FALSE) \%>\% simplify
}
\seealso{
\code{\link{simplify}}
}
