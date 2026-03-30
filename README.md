# curatedMicrobiomeMetabolomeData

R package for the Gut-Microbiome–Metabolome-Compendium resource.

## Install

```r
install.packages("remotes")
remotes::install_github("Shivi-Verma29/Microbiome_Metabolome_Curated_Studies")
```

## Quick start

```r
library(curatedMicrobiomeMetabolomeData)

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
subset_data <- curatedMicrobiomeMetabolomeData(
  studies = c("DawkinsJ_2022", "FranzosaE_2019"),
  modalities = c("metadata", "metabolome")
)
names(subset_data)
```

## Data structure

Each study can contain up to three tables:

- `metadata`
- `species`
- `metabolome`

Internally these are stored in `inst/extdata/studies/<study_slug>/` as gzipped
CSV files, and indexed by `inst/extdata/study_index.csv`.

## Main functions

- `GMMC_study_index()`: returns the study-level index table.
- `GMMC_studies()`: returns study names.
- `GMMC_available_modalities(study)`: returns available modalities for a study.
- `GMMC_load_modality(study, modality)`: loads one table as a `data.frame`.
- `GMMC_load_study(study)`: loads all available tables for one study.
- `curatedMicrobiomeMetabolomeData(studies, modalities)`: loads a multi-study
  named list.

## Using from a local checkout

If you are running from a cloned repository without installing:

```r
ext_dir <- file.path(getwd(), "inst", "extdata")
idx <- GMMC_study_index(extdata_dir = ext_dir)
```
