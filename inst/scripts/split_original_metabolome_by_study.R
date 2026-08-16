load_original_metabolome_list <- function(rdata_path) {
  env <- new.env(parent = emptyenv())
  load(rdata_path, envir = env)
  object_names <- ls(env)
  if (length(object_names) != 1L) {
    stop("Expected exactly one object in ", rdata_path)
  }

  obj <- get(object_names[[1]], envir = env)
  if (!is.list(obj)) {
    stop("Object in ", rdata_path, " is not a list")
  }

  obj
}

read_gz_csv <- function(path) {
  con <- gzfile(path, open = "rt")
  on.exit(close(con), add = TRUE)
  read.csv(con, check.names = FALSE, stringsAsFactors = FALSE)
}

write_gz_csv <- function(df, path) {
  con <- gzfile(path, open = "wt")
  on.exit(close(con), add = TRUE)
  utils::write.csv(df, con, row.names = FALSE, quote = TRUE)
}

choose_sample_column <- function(metadata, sample_names) {
  candidates <- intersect(c("sample_id", "sample_id.1"), colnames(metadata))
  if (length(candidates) == 0L) {
    stop("No sample_id column found in metadata")
  }

  counts <- vapply(
    candidates,
    function(col) sum(metadata[[col]] %in% sample_names, na.rm = TRUE),
    integer(1)
  )

  candidates[[which.max(counts)]]
}

split_original_metabolome_by_study <- function(
  rdata_path = "Before_HuMMANet_Original_metabolome_profile.RData",
  extdata_dir = "inst/extdata",
  export_dir = "Before_HuMMANet_by_study"
) {
  study_list <- load_original_metabolome_list(rdata_path)

  study_index_path <- file.path(extdata_dir, "study_index.csv")
  study_index <- read.csv(
    study_index_path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
  summary_rows <- vector("list", nrow(study_index))

  for (i in seq_len(nrow(study_index))) {
    study <- study_index$study[[i]]
    slug <- study_index$study_slug[[i]]
    list_name <- paste0(study, "_CuratedMetabolome")
    if (!list_name %in% names(study_list)) {
      stop("Missing study in original metabolome list: ", list_name)
    }

    study_df <- study_list[[list_name]]
    if (!is.data.frame(study_df) && !is.matrix(study_df)) {
      stop("Study entry is not a data.frame/matrix: ", list_name)
    }
    study_df <- as.data.frame(study_df, check.names = FALSE, stringsAsFactors = FALSE)

    sample_names <- rownames(study_df)
    if (is.null(sample_names)) {
      stop("Study entry has no row names: ", list_name)
    }

    metadata_path <- file.path(extdata_dir, study_index$MetadataProfile_file[[i]])
    metadata <- read_gz_csv(metadata_path)
    sample_col <- choose_sample_column(metadata, sample_names)
    matched_samples <- intersect(metadata[[sample_col]], sample_names)

    study_df <- study_df[matched_samples, , drop = FALSE]
    out_df <- data.frame(
      sample_id = rownames(study_df),
      study_df,
      check.names = FALSE,
      row.names = NULL
    )

    export_path <- file.path(export_dir, paste0(study, "_OriginalMetaboliteProfile.csv"))
    write.csv(out_df, export_path, row.names = FALSE, quote = TRUE)

    package_rel_path <- file.path("studies", slug, "OriginalMetaboliteProfile.csv.gz")
    package_abs_path <- file.path(extdata_dir, package_rel_path)
    dir.create(dirname(package_abs_path), recursive = TRUE, showWarnings = FALSE)
    write_gz_csv(out_df, package_abs_path)

    study_index$OriginalMetaboliteProfile_file[[i]] <- package_rel_path
    study_index$n_OriginalMetaboliteProfile[[i]] <- nrow(out_df)
    study_index$has_OriginalMetaboliteProfile[[i]] <- nrow(out_df) > 0L

    summary_rows[[i]] <- data.frame(
      study = study,
      study_slug = slug,
      source_entry = list_name,
      sample_column_used = sample_col,
      n_metadata_samples = nrow(metadata),
      n_matched_samples = nrow(out_df),
      n_profile_columns = ncol(out_df),
      export_file = basename(export_path),
      package_file = package_rel_path,
      stringsAsFactors = FALSE
    )
  }

  utils::write.csv(study_index, study_index_path, row.names = FALSE, quote = TRUE)

  summary_df <- do.call(rbind, summary_rows)
  summary_path <- file.path(export_dir, "split_summary.csv")
  write.csv(summary_df, summary_path, row.names = FALSE, quote = TRUE)

  invisible(summary_df)
}
