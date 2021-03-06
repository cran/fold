% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/meta.R
\name{distill.data.frame}
\alias{distill.data.frame}
\title{Distill a Data Frame}
\usage{
\method{distill}{data.frame}(x, mission, parent = character(0), ...)
}
\arguments{
\item{x}{object}

\item{mission}{character}

\item{parent}{character}

\item{...}{passed arguments}
}
\description{
Distills a data.frame with respect to a variable.  Recovers everything known about the variable, recursively mining metadata.
}
\seealso{
\code{\link{distill}}
}
\keyword{internal}
