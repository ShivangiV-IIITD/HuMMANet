\name{HuMMANet-package}
\alias{HuMMANet-package}
\alias{package-HuMMANet}
\title{HuMMANet: Paired Human Microbiome-Metabolome Study Data}
\description{
HuMMANet is a Bioconductor experiment data package that provides access to
curated paired human microbiome-metabolome studies. The package organizes
matched sample metadata, species abundance profiles, original and
harmonized metabolite profiles, and study-specific annotation resources
including metabolite identifier mappings, microbial producer annotations,
disease associations, pathway annotations, and drug similarity matches
through Bioconductor \code{ExperimentHub}.
}
\details{
Study resources are designed to support reproducible access to paired
species and metabolite data across studies through a consistent set of
functions. Each study is represented as a
\code{MultiAssayExperiment::MultiAssayExperiment} with matched sample
metadata stored in \code{colData()}, assay-level species and metabolite
profiles stored in \code{experiments()}, and long-form annotation tables
attached in \code{metadata()}. HuMMANet data can be discovered and
retrieved from Bioconductor \code{ExperimentHub} using convenience
accessors such as
\code{\link{HuMMANetHub}}, \code{\link{HuMMANet_studies}},
\code{\link{HuMMANet_study_index}}, \code{\link{HuMMANet_load_modality}},
and \code{\link{HuMMANet_load_study}}.
}
\value{
This help page documents the HuMMANet package as a whole and does not
return a value.
}
\seealso{
\code{\link{HuMMANet}}, \code{\link{HuMMANetHub}},
\code{\link{HuMMANet_resource_table}}, \code{\link{HuMMANet_study_index}},
\code{\link{HuMMANet_load_modality}}, \code{\link{HuMMANet_load_study}}
}
\keyword{package}
