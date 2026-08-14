load_after_hummanet_matrix <- function(rdata_path) {
  env <- new.env(parent = emptyenv())
  load(rdata_path, envir = env)
  object_names <- ls(env)
  if (length(object_names) != 1L) {
    stop("Expected exactly one object in ", rdata_path)
  }

  mat <- get(object_names[[1]], envir = env)
  if (!is.matrix(mat) && !is.data.frame(mat)) {
    stop("Object in ", rdata_path, " is not a matrix/data.frame")
  }

  as.matrix(mat)
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

ensure_after_hummanet_columns <- function(study_index) {
  defaults <- list(
    after_hummanet_file = "",
    n_after_hummanet = 0L,
    has_after_hummanet = FALSE
  )

  for (nm in names(defaults)) {
    if (!nm %in% colnames(study_index)) {
      study_index[[nm]] <- defaults[[nm]]
    }
  }

  study_index
}

split_after_hummanet_by_study <- function(
  rdata_path = "After_HuMANet.RData",
  extdata_dir = "inst/extdata",
  export_dir = "After_HuMMANet_by_study"
) {
  mat <- load_after_hummanet_matrix(rdata_path)
  sample_names <- rownames(mat)
  if (is.null(sample_names)) {
    stop("After_HuMANet matrix must have sample IDs in row names")
  }

  study_index_path <- file.path(extdata_dir, "study_index.csv")
  study_index <- read.csv(
    study_index_path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  study_index <- ensure_after_hummanet_columns(study_index)

  dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
  summary_rows <- vector("list", nrow(study_index))

  for (i in seq_len(nrow(study_index))) {
    study <- study_index$study[[i]]
    slug <- study_index$study_slug[[i]]
    metadata_path <- file.path(extdata_dir, study_index$metadata_file[[i]])
    metadata <- read_gz_csv(metadata_path)

    sample_col <- choose_sample_column(metadata, sample_names)
    matched_samples <- intersect(metadata[[sample_col]], sample_names)
    study_mat <- mat[matched_samples, , drop = FALSE]

    if (nrow(study_mat) > 0L) {
      keep_cols <- colSums(!is.na(study_mat)) > 0L
      study_mat <- study_mat[, keep_cols, drop = FALSE]
    }

    out_df <- data.frame(sample_id = rownames(study_mat), study_mat, check.names = FALSE)

    export_path <- file.path(export_dir, paste0(study, "_afterHuMMANet.csv"))
    write.csv(out_df, export_path, row.names = FALSE, quote = TRUE)

    package_rel_path <- file.path("studies", slug, "after_hummanet.csv.gz")
    package_abs_path <- file.path(extdata_dir, package_rel_path)
    dir.create(dirname(package_abs_path), recursive = TRUE, showWarnings = FALSE)
    write_gz_csv(out_df, package_abs_path)

    study_index$after_hummanet_file[[i]] <- package_rel_path
    study_index$n_after_hummanet[[i]] <- nrow(out_df)
    study_index$has_after_hummanet[[i]] <- nrow(out_df) > 0L

    summary_rows[[i]] <- data.frame(
      study = study,
      study_slug = slug,
      sample_column_used = sample_col,
      n_metadata_samples = nrow(metadata),
      n_matched_samples = nrow(study_mat),
      n_columns_retained = ncol(study_mat),
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
