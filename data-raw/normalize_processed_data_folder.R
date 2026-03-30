#!/usr/bin/env Rscript

# Normalize data/processed_data so each study folder keeps only:
# - CuratedMetadata.csv
# - CuratedSpeciesProfile.csv
# - CuratedMetabolome.csv

normalize_key <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(x))
}

choose_preferred_file <- function(paths, study_name) {
  if (length(paths) == 0) {
    return(NA_character_)
  }
  if (length(paths) == 1) {
    return(paths[[1]])
  }

  study_key <- normalize_key(study_name)
  base_names <- basename(paths)
  base_keys <- normalize_key(base_names)

  score <- integer(length(paths))
  score <- score + ifelse(grepl(study_key, base_keys, fixed = TRUE), 100L, 0L)
  score <- score + ifelse(
    grepl("serum|fecal|stool|plasma|targeted|untargeted", tolower(base_names)),
    10L,
    0L
  )
  score <- score + nchar(base_names)

  paths[order(-score, base_names)][1]
}

find_curated_source <- function(study_dir, pattern, study_name) {
  files <- list.files(
    study_dir,
    pattern = pattern,
    full.names = TRUE,
    ignore.case = TRUE
  )
  files <- files[file.info(files)$isdir %in% FALSE]
  choose_preferred_file(files, study_name = study_name)
}

normalize_one_study <- function(study_dir, dry_run = FALSE, verbose = TRUE) {
  study_name <- basename(study_dir)

  sources <- c(
    CuratedMetadata.csv = find_curated_source(study_dir, "CuratedMetadata\\.csv$", study_name),
    CuratedSpeciesProfile.csv = find_curated_source(study_dir, "CuratedSpeciesProfile\\.csv$", study_name),
    CuratedMetabolome.csv = find_curated_source(study_dir, "CuratedMetabolome\\.csv$", study_name)
  )

  keep_targets <- character(0)

  for (target_name in names(sources)) {
    src <- sources[[target_name]]
    if (is.na(src) || !nzchar(src) || !file.exists(src)) {
      next
    }

    target <- file.path(study_dir, target_name)
    if (!dry_run) {
      ok <- file.copy(src, target, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)
      if (!ok) {
        stop("Failed to write target file: ", target)
      }
    }
    keep_targets <- c(keep_targets, normalizePath(target, mustWork = FALSE))
  }

  all_entries <- list.files(study_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  all_entries_norm <- normalizePath(all_entries, mustWork = FALSE)
  delete_entries <- all_entries[!(all_entries_norm %in% keep_targets)]

  if (verbose) {
    message(
      "Study ", study_name, ": keep ", length(keep_targets),
      " canonical files, delete ", length(delete_entries), " extra entries"
    )
  }

  if (!dry_run && length(delete_entries) > 0) {
    unlink(delete_entries, recursive = TRUE, force = TRUE)
  }

  list(
    study = study_name,
    kept = basename(keep_targets),
    deleted_n = length(delete_entries),
    has_metadata = "CuratedMetadata.csv" %in% basename(keep_targets),
    has_species = "CuratedSpeciesProfile.csv" %in% basename(keep_targets),
    has_metabolome = "CuratedMetabolome.csv" %in% basename(keep_targets)
  )
}

normalize_processed_data <- function(base_dir = file.path("data", "processed_data"), dry_run = FALSE) {
  base_dir <- normalizePath(base_dir, mustWork = TRUE)
  study_dirs <- list.dirs(base_dir, full.names = TRUE, recursive = FALSE)
  study_dirs <- study_dirs[file.info(study_dirs)$isdir %in% TRUE]
  study_dirs <- sort(study_dirs)

  if (length(study_dirs) == 0) {
    stop("No study directories found in ", base_dir)
  }

  results <- lapply(study_dirs, normalize_one_study, dry_run = dry_run, verbose = TRUE)

  res_df <- data.frame(
    study = vapply(results, `[[`, character(1), "study"),
    has_metadata = vapply(results, `[[`, logical(1), "has_metadata"),
    has_species = vapply(results, `[[`, logical(1), "has_species"),
    has_metabolome = vapply(results, `[[`, logical(1), "has_metabolome"),
    deleted_entries = vapply(results, `[[`, integer(1), "deleted_n"),
    stringsAsFactors = FALSE
  )

  message(
    "Summary: studies=", nrow(res_df),
    ", with metadata=", sum(res_df$has_metadata),
    ", with species=", sum(res_df$has_species),
    ", with metabolome=", sum(res_df$has_metabolome),
    ", total deleted entries=", sum(res_df$deleted_entries)
  )

  invisible(res_df)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  base_dir <- if (length(args) >= 1) args[[1]] else file.path("data", "processed_data")
  dry_run <- if (length(args) >= 2) tolower(args[[2]]) %in% c("1", "true", "yes", "dry-run") else FALSE
  normalize_processed_data(base_dir = base_dir, dry_run = dry_run)
}

if (sys.nframe() == 0) {
  main()
}

