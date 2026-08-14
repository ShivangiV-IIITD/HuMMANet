# HuMMANet

Bioconductor-style access package for curated human microbiome-metabolome
study bundles distributed through `ExperimentHub`.

## Install

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("HuMMANet")
```

## Quick start

```r
library(HuMMANet)

# inspect the HuMMANet ExperimentHub subset
hub <- HuMMANetHub()
hub

# list all studies
studies <- HuMMANet_studies()
length(studies)
head(studies)

# inspect the indexed study metadata
idx <- HuMMANet_study_index()
head(idx[, c("study", "has_metadata", "has_species", "has_metabolome")])

# check available modalities for one study
HuMMANet_available_modalities("DawkinsJ_2022")

# load one modality
meta <- HuMMANet_load_modality("DawkinsJ_2022", "metadata")
dim(meta)

# load one full study
one_study <- HuMMANet_load_study("DawkinsJ_2022")
names(one_study)

# load the HuMMANet-processed profile for one study
after_hummanet <- HuMMANet_load_modality("DawkinsJ_2022", "after_hummanet")
dim(after_hummanet)

# load selected studies and modalities
subset_data <- HuMMANet(
  studies = c("DawkinsJ_2022", "FranzosaE_2019"),
  modalities = c("metadata", "metabolome")
)
names(subset_data)
```

## Local development

The repository keeps the raw csv studies locally for preparing hub resources,
including per-study `after_hummanet` tables. The built package excludes
`inst/extdata/studies/`. To stage the per-study `after_hummanet` files and the
ExperimentHub `.rds` bundles plus metadata template, run:

```r
source("inst/scripts/split_after_hummanet_by_study.R")
split_after_hummanet_by_study()

source("inst/scripts/make-experimenthub-resources.R")
build_hummanet_experimenthub_resources()
```
