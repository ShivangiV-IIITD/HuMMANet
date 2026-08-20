# HuMMANet

## Overview

`HuMMANet` is designed as a Bioconductor data resource for paired human
microbiome-metabolome studies. The package brings together study-level species
profiles, metabolite profiles, matched sample metadata, and study-specific
annotation resources in a consistent interface with data accessible through
`ExperimentHub`.

The motivation for `HuMMANet` is to make paired species and metabolite datasets
easier to discover, load, and analyze across studies without requiring users to
manually reconcile sample identifiers, metabolite annotations, or study-level
resource formats. By packaging these resources in a Bioconductor-friendly form,
`HuMMANet` supports reproducible downstream analyses of microbiome-metabolome
relationships, cross-study comparisons, and annotation-driven interpretation of
metabolite features.

Each study bundle can include the following modalities:

- `MetadataProfile`: sample-level study metadata, such as sample identifiers,
  subject annotations, clinical covariates, time points, body site labels, and
  other variables needed to interpret the matched omics tables.
- `taxaAbundanceProfile`: the microbial feature abundance table for a study,
  with samples aligned to the study metadata and columns corresponding to taxa
  or other curated microbial features.
- `OriginalMetaboliteProfile`: the original curated metabolomics matrix before
  HuMMANet harmonization, preserving the study-specific metabolite feature space
  used in the source publication.
- `harmonizedMetaboliteProfile`: the HuMMANet-processed metabolite matrix after
  harmonization across studies, enabling more consistent cross-study metabolite
  comparisons.
- `metaboliteIdentifierMapping`: study-specific metabolite identifier mapping
  tables linking HuMMANet metabolite identifiers to database resources such as
  HMDB, PubChem, KEGG, ChEBI, structural descriptors, and standardized names.
- `microbialProducerAnnotations`: annotations connecting metabolites to
  potential microbial producers or species-level producer evidence curated for
  the study metabolites.
- `metaboliteDiseaseAssociations`: curated links between study metabolites and
  disease annotations.
- `metabolitePathwayAnnotations`: curated pathway-level annotations for the
  metabolites represented in a study.
- `drugBankSimilarityMatches`: DrugBank similarity matches for study
  metabolites or mapped structures.
- `drugCentralSimilarityMatches`: DrugCentral similarity matches for study
  metabolites or mapped structures.

## Install

Install from Bioconductor:

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("HuMMANet")
```

Install the development version from GitHub:

```r
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("ShivangiV-IIITD/HuMMANet")
```

## Quick start

```r
library(HuMMANet)
library(MultiAssayExperiment)
library(SummarizedExperiment)

# inspect the HuMMANet ExperimentHub subset
hub <- HuMMANetHub()
hub

# list all studies
studies <- HuMMANet_studies()
length(studies)
head(studies)

# inspect the indexed study metadata
idx <- HuMMANet_study_index()
head(
  idx[, c(
    "study",
    "has_MetadataProfile",
    "has_taxaAbundanceProfile",
    "has_OriginalMetaboliteProfile",
    "has_harmonizedMetaboliteProfile"
  )]
)

# check available modalities for one study
HuMMANet_available_modalities("DawkinsJ_2022")

# load one modality
metadata_profile <- HuMMANet_load_modality(
  "DawkinsJ_2022",
  "MetadataProfile"
)
dim(metadata_profile)

# load one full study
one_study <- HuMMANet_load_study("DawkinsJ_2022")
class(one_study)
names(experiments(one_study))
nrow(colData(one_study))

# load the harmonized metabolite profile for one study
harmonized_profile <- HuMMANet_load_modality(
  "DawkinsJ_2022",
  "harmonizedMetaboliteProfile"
)
class(harmonized_profile)
dim(assay(harmonized_profile))

# load an annotation table attached to the study object
pathway_annotations <- HuMMANet_load_modality(
  "DawkinsJ_2022",
  "metabolitePathwayAnnotations"
)
dim(pathway_annotations)

# load selected studies and modalities
subset_data <- HuMMANet(
  studies = c("DawkinsJ_2022", "FranzosaE_2019"),
  modalities = c("MetadataProfile", "OriginalMetaboliteProfile")
)
names(subset_data)
class(subset_data[[1]])
```
