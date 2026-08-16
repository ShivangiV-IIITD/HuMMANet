\name{HuMMANet}
\alias{HuMMANet}
\alias{HuMMANetHub}
\alias{HuMMANet_resource_table}
\alias{HuMMANet_study_index}
\alias{HuMMANet_studies}
\alias{HuMMANet_available_modalities}
\alias{HuMMANet_load_modality}
\alias{HuMMANet_load_study}
\title{HuMMANet ExperimentHub Access Functions}
\description{
Helpers to discover and load HuMMANet paired microbiome-metabolome study
data, including matched metadata, metabolite profiles, species profiles,
and study-specific annotation resources. Published resources are retrieved
through Bioconductor \code{ExperimentHub}, with a local \code{extdata}
fallback available for development workflows.
}
\usage{
HuMMANet(
  studies = NULL,
  modalities = c(
    "MetadataProfile",
    "taxaAbundanceProfile",
    "OriginalMetaboliteProfile",
    "harmonizedMetaboliteProfile",
    "metaboliteIdentifierMapping",
    "microbialProducerAnnotations",
    "metaboliteDiseaseAssociations",
    "metabolitePathwayAnnotations",
    "drugBankSimilarityMatches",
    "drugCentralSimilarityMatches"
  ),
  extdata_dir = NULL,
  drop_missing = TRUE,
  localHub = FALSE
)

HuMMANetHub(localHub = FALSE)

HuMMANet_resource_table(localHub = FALSE, extdata_dir = NULL)

HuMMANet_study_index(extdata_dir = NULL, localHub = FALSE)

HuMMANet_studies(extdata_dir = NULL, localHub = FALSE)

HuMMANet_available_modalities(study, extdata_dir = NULL, localHub = FALSE)

HuMMANet_load_modality(
  study,
  modality = c(
    "MetadataProfile",
    "taxaAbundanceProfile",
    "OriginalMetaboliteProfile",
    "harmonizedMetaboliteProfile",
    "metaboliteIdentifierMapping",
    "microbialProducerAnnotations",
    "metaboliteDiseaseAssociations",
    "metabolitePathwayAnnotations",
    "drugBankSimilarityMatches",
    "drugCentralSimilarityMatches"
  ),
  extdata_dir = NULL,
  allow_missing = FALSE,
  localHub = FALSE
)

HuMMANet_load_study(
  study,
  modalities = c(
    "MetadataProfile",
    "taxaAbundanceProfile",
    "OriginalMetaboliteProfile",
    "harmonizedMetaboliteProfile",
    "metaboliteIdentifierMapping",
    "microbialProducerAnnotations",
    "metaboliteDiseaseAssociations",
    "metabolitePathwayAnnotations",
    "drugBankSimilarityMatches",
    "drugCentralSimilarityMatches"
  ),
  extdata_dir = NULL,
  drop_missing = TRUE,
  localHub = FALSE
)
}
\arguments{
  \item{studies}{Optional character vector of study identifiers. If \code{NULL},
  all indexed studies are loaded.}

  \item{modalities}{Character vector of modalities to load from
  \code{"MetadataProfile"}, \code{"taxaAbundanceProfile"},
  \code{"OriginalMetaboliteProfile"}, \code{"harmonizedMetaboliteProfile"},
  \code{"metaboliteIdentifierMapping"},
  \code{"microbialProducerAnnotations"},
  \code{"metaboliteDiseaseAssociations"},
  \code{"metabolitePathwayAnnotations"},
  \code{"drugBankSimilarityMatches"},
  \code{"drugCentralSimilarityMatches"}.}

  \item{extdata_dir}{Optional explicit path to a local development
  \code{extdata} directory.}

  \item{drop_missing}{If \code{TRUE}, missing modalities are omitted.}

  \item{localHub}{Logical scalar passed through to
  \code{ExperimentHub::ExperimentHub()}.}

  \item{study}{Study identifier, for example \code{"FranzosaE_2019"}.}

  \item{modality}{Single modality to load from the same set.}

  \item{allow_missing}{If \code{TRUE}, return \code{NULL} when modality is
  not present for the selected study.}
}
\value{
\itemize{
  \item \code{HuMMANetHub}: the HuMMANet subset of \code{ExperimentHub}.
  \item \code{HuMMANet_resource_table}: \code{data.frame} describing expected
  HuMMANet records and, when available, their published EH identifiers.
  \item \code{HuMMANet_study_index}: \code{data.frame} with one row per study.
  \item \code{HuMMANet_studies}: character vector of study identifiers.
  \item \code{HuMMANet_available_modalities}: character vector of available
  modalities.
  \item \code{HuMMANet_load_modality}: one modality table as a
  \code{data.frame}.
  \item \code{HuMMANet_load_study}: named list of modality tables for one
  study.
  \item \code{HuMMANet}: named list keyed by study.
}
}
\examples{
# Query the published HuMMANet ExperimentHub subset
\dontrun{
hub <- HuMMANetHub()
hub
}

# List studies
head(HuMMANet_studies())

# Load one study
\dontrun{
x <- HuMMANet_load_study("FranzosaE_2019")
names(x)

# Load selected studies and modalities
subset_data <- HuMMANet(
  studies = c("FranzosaE_2019", "DawkinsJ_2022"),
  modalities = c(
    "MetadataProfile",
    "OriginalMetaboliteProfile",
    "harmonizedMetaboliteProfile",
    "metabolitePathwayAnnotations"
  )
)
}
}
