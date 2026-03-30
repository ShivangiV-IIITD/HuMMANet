# GutMicrobiomeMetabolomeCompendium

R package for the Gut-Microbiome–Metabolome-Compendium resource.

## Install

```r
install.packages("remotes")
remotes::install_github("Shivi-Verma29/Microbiome_Metabolome_Curated_Studies")
```

## Quick start

```r
library(GutMicrobiomeMetabolomeCompendium)

# list all studies
studies <- GMMC_studies()
length(studies)
head(studies)

# inspect full study index
idx <- GMMC_study_index()
head(idx[, c("study", "has_metadata", "has_species", "has_metabolome")])

# check available modalities for one study
GMMC_available_modalities("DawkinsJ_2022")

# load one modality
meta <- GMMC_load_modality("DawkinsJ_2022", "metadata")
dim(meta)

# load one full study
one_study <- GMMC_load_study("DawkinsJ_2022")
names(one_study)

# load selected studies and modalities
subset_data <- GutMicrobiomeMetabolomeCompendium(
  studies = c("DawkinsJ_2022", "FranzosaE_2019"),
  modalities = c("metadata", "metabolome")
)
names(subset_data)
```

