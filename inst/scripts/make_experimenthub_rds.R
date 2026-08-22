args <- commandArgs(trailingOnly = TRUE)

root_dir <- if (length(args) >= 1L) {
  normalizePath(args[[1]], mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

extdata_dir <- file.path(root_dir, "inst", "extdata")
study_index_csv <- file.path(extdata_dir, "study_index.csv")
manifest_csv <- file.path(extdata_dir, "hub_manifest.csv")
output_dir <- file.path(root_dir, "HuMMANet", "v1")
studies_output_dir <- file.path(output_dir, "studies")

dir.create(studies_output_dir, recursive = TRUE, showWarnings = FALSE)

read_csv_any <- function(path) {
  if (!file.exists(path)) {
    stop("Missing input file: ", path)
  }

  con <- if (grepl("\\.gz$", path, ignore.case = TRUE)) {
    gzfile(path, open = "rt")
  } else {
    file(path, open = "rt")
  }
  on.exit(close(con), add = TRUE)

  utils::read.csv(
    con,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

study_index <- utils::read.csv(
  study_index_csv,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
manifest <- utils::read.csv(
  manifest_csv,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

saveRDS(study_index, file.path(output_dir, "study_index.rds"), version = 2)

modalities <- c(
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
)

study_rows <- manifest[manifest$record_type == "study_bundle", , drop = FALSE]

for (i in seq_len(nrow(study_rows))) {
  study <- study_rows$study[[i]]
  slug <- study_rows$study_slug[[i]]

  index_row <- study_index[study_index$study == study, , drop = FALSE]
  if (nrow(index_row) != 1L) {
    stop("Expected exactly one study_index row for study: ", study)
  }

  bundle <- setNames(vector("list", length(modalities)), modalities)

  for (modality in modalities) {
    file_col <- paste0(modality, "_file")
    rel_path <- index_row[[file_col]][1]

    if (is.na(rel_path) || !nzchar(rel_path)) {
      bundle[[modality]] <- NULL
      next
    }

    bundle[[modality]] <- read_csv_any(file.path(extdata_dir, rel_path))
  }

  saveRDS(
    bundle,
    file = file.path(studies_output_dir, paste0(slug, ".rds")),
    version = 2
  )
}

message("Wrote study index to: ", file.path(output_dir, "study_index.rds"))
message("Wrote ", nrow(study_rows), " study bundles to: ", studies_output_dir)
