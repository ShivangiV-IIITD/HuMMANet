#!/usr/bin/env Rscript

MODALITY_PATTERNS <- c(
  metadata = "CuratedMetadata\\.csv$",
  species = "CuratedSpeciesProfile\\.csv$",
  metabolome = "CuratedMetabolome\\.csv$"
)

normalize_key <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(x))
}

portable_slug <- function(x) {
  slug <- tolower(gsub("[^A-Za-z0-9]+", "_", x))
  slug <- gsub("_+", "_", slug)
  slug <- gsub("^_|_$", "", slug)
  if (!nzchar(slug)) {
    slug <- "study"
  }
  slug
}

short_hash <- function(x) {
  ints <- utf8ToInt(x)
  mod <- 2147483629
  hash <- 0
  for (i in seq_along(ints)) {
    hash <- (hash * 131 + ints[[i]]) %% mod
  }
  sprintf("%08x", as.integer(hash))
}

make_unique_study_slugs <- function(studies, max_len = 24L) {
  used <- character(0)
  slugs <- character(length(studies))

  for (i in seq_along(studies)) {
    base <- portable_slug(studies[[i]])
    if (nchar(base) > max_len) {
      suffix <- short_hash(studies[[i]])
      prefix_len <- max(1L, max_len - nchar(suffix) - 1L)
      base <- paste0(substr(base, 1L, prefix_len), "_", suffix)
    }

    candidate <- base
    k <- 1L
    while (candidate %in% used) {
      suffix <- paste0(short_hash(studies[[i]]), "_", k)
      prefix_len <- max(1L, max_len - nchar(suffix) - 1L)
      candidate <- paste0(substr(base, 1L, prefix_len), "_", suffix)
      k <- k + 1L
    }

    used <- c(used, candidate)
    slugs[[i]] <- candidate
  }

  slugs
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

detect_study_files <- function(study_dir) {
  out <- setNames(rep(NA_character_, length(MODALITY_PATTERNS)), names(MODALITY_PATTERNS))

  for (modality in names(MODALITY_PATTERNS)) {
    files <- list.files(
      study_dir,
      pattern = MODALITY_PATTERNS[[modality]],
      full.names = TRUE,
      ignore.case = TRUE
    )
    files <- files[file.info(files)$isdir %in% FALSE]
    out[[modality]] <- choose_preferred_file(files, basename(study_dir))
  }

  out
}

normalize_first_column <- function(df) {
  if (ncol(df) == 0) {
    return(df)
  }

  first_name <- names(df)[1]
  first_values <- as.character(df[[1]])
  is_index_name <- first_name %in% c("", "X", "X.", "...1", "row.names")

  first_int <- suppressWarnings(as.integer(first_values))
  is_sequential_index <- !any(is.na(first_int)) &&
    length(first_int) == nrow(df) &&
    all(first_int == seq_len(nrow(df)))

  if (!is_index_name) {
    return(df)
  }

  if ("sample_id" %in% names(df)[-1]) {
    second_values <- as.character(df[["sample_id"]])
    same_as_sample_id <- length(second_values) == length(first_values) &&
      all(first_values == second_values)

    if (same_as_sample_id || is_sequential_index) {
      return(df[, -1, drop = FALSE])
    }

    names(df)[1] <- "sample_id"
    return(df)
  }

  if (is_sequential_index) {
    return(df[, -1, drop = FALSE])
  }

  names(df)[1] <- "sample_id"
  df
}

standardize_sample_id <- function(df, path) {
  if (ncol(df) == 0) {
    stop("No columns found in file: ", path)
  }

  if (!"sample_id" %in% names(df)) {
    names(df)[1] <- "sample_id"
  }

  df$sample_id <- trimws(as.character(df$sample_id))
  missing_id <- is.na(df$sample_id) | !nzchar(df$sample_id)
  if (any(missing_id)) {
    df$sample_id[missing_id] <- paste0("missing_sample_", seq_len(sum(missing_id)))
  }

  other_cols <- names(df)[names(df) != "sample_id"]
  df <- df[, c("sample_id", other_cols), drop = FALSE]

  if (anyDuplicated(df$sample_id)) {
    warning("Duplicate sample_id values detected in ", path, call. = FALSE)
  }

  df
}

read_curated_table <- function(path) {
  df <- utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  df <- normalize_first_column(df)
  df <- standardize_sample_id(df, path)
  df
}

write_csv_gz <- function(df, path) {
  con <- gzfile(path, open = "wt")
  on.exit(close(con), add = TRUE)
  utils::write.csv(df, con, row.names = FALSE, quote = TRUE, na = "")
}

format_study <- function(
  study_dir,
  output_root,
  study_slug = NULL,
  studies_subdir = "studies_tmp",
  verbose = TRUE
) {
  study <- basename(study_dir)
  if (is.null(study_slug)) {
    study_slug <- portable_slug(study)
  }

  files <- detect_study_files(study_dir)

  record <- data.frame(
    study = study,
    study_slug = study_slug,
    metadata_file = "",
    species_file = "",
    metabolome_file = "",
    n_metadata = NA_integer_,
    n_species = NA_integer_,
    n_metabolome = NA_integer_,
    has_metadata = FALSE,
    has_species = FALSE,
    has_metabolome = FALSE,
    metadata_source = "",
    species_source = "",
    metabolome_source = "",
    n_shared_available = NA_integer_,
    n_shared_all_modalities = NA_integer_,
    stringsAsFactors = FALSE
  )

  out_study_dir <- file.path(output_root, studies_subdir, study_slug)
  dir.create(out_study_dir, recursive = TRUE, showWarnings = FALSE)

  sample_sets <- list()
  for (modality in names(files)) {
    input <- files[[modality]]
    if (is.na(input) || !nzchar(input)) {
      next
    }

    if (verbose) {
      message("Formatting ", study, " [", modality, "]")
    }

    table <- read_curated_table(input)
    rel_path <- file.path("studies", study_slug, paste0(modality, ".csv.gz"))
    abs_path <- file.path(output_root, studies_subdir, study_slug, paste0(modality, ".csv.gz"))
    write_csv_gz(table, abs_path)

    record[[paste0(modality, "_file")]] <- rel_path
    record[[paste0("n_", modality)]] <- nrow(table)
    record[[paste0("has_", modality)]] <- TRUE
    record[[paste0(modality, "_source")]] <- normalizePath(input, mustWork = TRUE)
    sample_sets[[modality]] <- unique(table$sample_id)
  }

  has_any_modality <- any(
    unlist(record[1, c("has_metadata", "has_species", "has_metabolome")], use.names = FALSE)
  )
  if (!has_any_modality) {
    if (verbose) {
      message("Skipping ", study, " (no curated modality files found)")
    }
    unlink(out_study_dir, recursive = TRUE, force = TRUE)
    return(NULL)
  }

  if (length(sample_sets) == 0) {
    record$n_shared_available <- 0L
    record$n_shared_all_modalities <- NA_integer_
  } else if (length(sample_sets) == 1) {
    record$n_shared_available <- length(sample_sets[[1]])
    record$n_shared_all_modalities <- NA_integer_
  } else {
    record$n_shared_available <- length(Reduce(intersect, sample_sets))
    if (all(c("metadata", "species", "metabolome") %in% names(sample_sets))) {
      record$n_shared_all_modalities <- length(
        Reduce(intersect, sample_sets[c("metadata", "species", "metabolome")])
      )
    } else {
      record$n_shared_all_modalities <- NA_integer_
    }
  }

  record
}

format_all_studies <- function(
  source_dir = file.path("data", "processed_data"),
  output_dir = file.path("inst", "extdata"),
  verbose = TRUE
) {
  source_dir <- normalizePath(source_dir, mustWork = TRUE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  final_studies_dir <- file.path(output_dir, "studies")
  tmp_studies_dir <- file.path(output_dir, "studies_tmp")
  if (dir.exists(tmp_studies_dir)) {
    unlink(tmp_studies_dir, recursive = TRUE, force = TRUE)
  }
  dir.create(tmp_studies_dir, recursive = TRUE, showWarnings = FALSE)

  study_dirs <- list.dirs(source_dir, recursive = FALSE, full.names = TRUE)
  study_dirs <- study_dirs[file.info(study_dirs)$isdir %in% TRUE]
  study_dirs <- sort(study_dirs)

  if (length(study_dirs) == 0) {
    stop("No study directories found in: ", source_dir)
  }

  study_names <- basename(study_dirs)
  study_slugs <- make_unique_study_slugs(study_names)

  records <- Map(
    function(dir_path, slug) {
      format_study(
        study_dir = dir_path,
        output_root = output_dir,
        study_slug = slug,
        studies_subdir = "studies_tmp",
        verbose = verbose
      )
    },
    study_dirs,
    study_slugs
  )
  records <- Filter(Negate(is.null), records)
  if (length(records) == 0) {
    stop("No valid studies with curated modality files were found in: ", source_dir)
  }

  if (dir.exists(final_studies_dir)) {
    unlink(final_studies_dir, recursive = TRUE, force = TRUE)
  }
  renamed <- file.rename(tmp_studies_dir, final_studies_dir)
  if (!renamed) {
    stop("Could not finalize studies directory: ", final_studies_dir)
  }

  index <- do.call(rbind, records)
  index <- index[order(index$study), , drop = FALSE]

  index_path <- file.path(output_dir, "study_index.csv")
  utils::write.csv(index, index_path, row.names = FALSE, quote = TRUE)

  if (verbose) {
    message("Wrote index for ", nrow(index), " studies: ", normalizePath(index_path, mustWork = TRUE))
  }

  invisible(index)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  source_dir <- if (length(args) >= 1) args[[1]] else file.path("data", "processed_data")
  output_dir <- if (length(args) >= 2) args[[2]] else file.path("inst", "extdata")
  format_all_studies(source_dir = source_dir, output_dir = output_dir, verbose = TRUE)
}

if (sys.nframe() == 0) {
  main()
}
