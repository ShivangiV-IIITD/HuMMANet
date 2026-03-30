\name{curatedMicrobiomeMetabolomeData}
\alias{curatedMicrobiomeMetabolomeData}
\alias{cmm_study_index}
\alias{cmm_studies}
\alias{cmm_available_modalities}
\alias{cmm_load_modality}
\alias{cmm_load_study}
\title{Curated Microbiome-Metabolome Data Access Functions}
\description{
Helpers to discover and load curated microbiome-metabolome study data
packaged under \code{inst/extdata}.
}
\usage{
curatedMicrobiomeMetabolomeData(
  studies = NULL,
  modalities = c("metadata", "species", "metabolome"),
  extdata_dir = NULL,
  drop_missing = TRUE
)

cmm_study_index(extdata_dir = NULL)

cmm_studies(extdata_dir = NULL)

cmm_available_modalities(study, extdata_dir = NULL)

cmm_load_modality(
  study,
  modality = c("metadata", "species", "metabolome"),
  extdata_dir = NULL,
  allow_missing = FALSE
)

cmm_load_study(
  study,
  modalities = c("metadata", "species", "metabolome"),
  extdata_dir = NULL,
  drop_missing = TRUE
)
}
\arguments{
  \item{studies}{Optional character vector of study identifiers. If \code{NULL},
  all indexed studies are loaded.}

  \item{modalities}{Character vector of modalities to load from
  \code{"metadata"}, \code{"species"}, \code{"metabolome"}.}

  \item{extdata_dir}{Optional explicit path to the package
  \code{extdata} directory.}

  \item{drop_missing}{If \code{TRUE}, missing modalities are omitted.}

  \item{study}{Study identifier, for example \code{"FranzosaE_2019"}.}

  \item{modality}{Single modality to load.}

  \item{allow_missing}{If \code{TRUE}, return \code{NULL} when modality is
  not present for the selected study.}
}
\value{
\itemize{
  \item \code{cmm_study_index}: \code{data.frame} with one row per study.
  \item \code{cmm_studies}: character vector of study identifiers.
  \item \code{cmm_available_modalities}: character vector of available modalities.
  \item \code{cmm_load_modality}: one modality table as a \code{data.frame}.
  \item \code{cmm_load_study}: named list of modality tables for one study.
  \item \code{curatedMicrobiomeMetabolomeData}: named list keyed by study.
}
}
\examples{
# List studies
head(cmm_studies())

# Load one study
x <- cmm_load_study("FranzosaE_2019")
names(x)

# Load selected studies and modalities
subset_data <- curatedMicrobiomeMetabolomeData(
  studies = c("FranzosaE_2019", "LifelinesDEEP_WGS"),
  modalities = c("metadata", "metabolome")
)
}

