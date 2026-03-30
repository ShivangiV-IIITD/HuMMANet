# curatedMicrobiomeMetabolomeData

This repository is now structured as an R package for curated human
microbiome-metabolome studies, inspired by the user workflow of
`curatedMetagenomicData`.

## What this package provides

- A normalized `inst/extdata` data layout for each study:
  - `metadata.csv.gz`
  - `species.csv.gz`
  - `metabolome.csv.gz`
- A study-level index at `inst/extdata/study_index.csv`
- R helpers to list studies and load study modalities

## Build normalized package data

From the repository root:

```bash
Rscript data-raw/format_study_data.R
```

This reads `data/processed_data/` and writes normalized files to
`inst/extdata/`.

## Install

```r
# if using remotes
remotes::install_github("Shivi-Verma29/Microbiome_Metabolome_Curated_Studies")
```

## Use

```r
library(curatedMicrobiomeMetabolomeData)

# Inspect studies
studies <- cmm_studies()
head(studies)

# Load one study (all available modalities)
one <- cmm_load_study("FranzosaE_2019")
names(one)

# Load one modality only
meta <- cmm_load_modality("FranzosaE_2019", "metadata")

# Load multiple studies
subset_data <- curatedMicrobiomeMetabolomeData(
  studies = c("FranzosaE_2019", "LifelinesDEEP_WGS"),
  modalities = c("metadata", "metabolome")
)
```

## Notes

- Raw source files remain in `data/processed_data/`.
- The formatter keeps file names and study boundaries deterministic and
  handles the common "first unnamed column as sample_id" CSV pattern.
