# Internal helper: locate package extdata from install or source checkout.
HuMMANet_extdata_candidates <- function() {
  installed <- system.file("extdata", package = "HuMMANet")
  checkout <- file.path(getwd(), "inst", "extdata")
  unique(c(installed, checkout))
}

# Internal helper: resolve extdata directory.
HuMMANet_normalize_extdata_dir <- function(
  extdata_dir = NULL,
  require_studies = FALSE
) {
  candidates <- if (!is.null(extdata_dir)) {
    extdata_dir
  } else {
    HuMMANet_extdata_candidates()
  }

  for (candidate in candidates) {
    if (!nzchar(candidate) || !dir.exists(candidate)) {
      next
    }

    if (require_studies && !dir.exists(file.path(candidate, "studies"))) {
      next
    }

    return(normalizePath(candidate, mustWork = TRUE))
  }

  details <- if (require_studies) {
    " with a local 'studies/' directory"
  } else {
    ""
  }

  stop(
    "Could not locate HuMMANet extdata", details, ". ",
    "For development, pass `extdata_dir` explicitly. ",
    "For installed packages, use the ExperimentHub-backed accessors."
  )
}

# Internal helper: detect whether the local study bundle is available.
HuMMANet_local_data_available <- function(extdata_dir = NULL) {
  tryCatch({
    path <- HuMMANet_normalize_extdata_dir(
      extdata_dir = extdata_dir,
      require_studies = TRUE
    )
    file.exists(file.path(path, "study_index.csv"))
  }, error = function(...) FALSE)
}

# Internal helper: read csv/csv.gz with stable defaults.
HuMMANet_read_csv_any <- function(path) {
  if (!file.exists(path)) {
    stop("File does not exist: ", path)
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

# Internal helper: public HuMMANet modality names.
HuMMANet_public_modality_names <- function() {
  c(
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
}

# Internal helper: validate and normalize modality names.
HuMMANet_normalize_modalities <- function(modalities) {
  match.arg(
    modalities,
    choices = HuMMANet_public_modality_names(),
    several.ok = TRUE
  )
}

# Internal helper: read the packaged hub manifest.
HuMMANet_hub_manifest <- function(extdata_dir = NULL) {
  extdata_dir <- HuMMANet_normalize_extdata_dir(extdata_dir, require_studies = FALSE)
  manifest_path <- file.path(extdata_dir, "hub_manifest.csv")
  if (!file.exists(manifest_path)) {
    stop("Missing HuMMANet hub manifest: ", manifest_path)
  }

  utils::read.csv(
    manifest_path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# Internal helper: read packaged ExperimentHub-style metadata table.
HuMMANet_metadata_table <- function(extdata_dir = NULL) {
  extdata_dir <- HuMMANet_normalize_extdata_dir(extdata_dir, require_studies = FALSE)
  metadata_path <- file.path(extdata_dir, "metadata.csv")
  if (!file.exists(metadata_path)) {
    stop("Missing HuMMANet metadata table: ", metadata_path)
  }

  utils::read.csv(
    metadata_path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# Internal helper: find a manifest row for a study or shared record.
HuMMANet_manifest_row <- function(record_type, study = NULL, extdata_dir = NULL) {
  manifest <- HuMMANet_hub_manifest(extdata_dir = extdata_dir)
  keep <- manifest$record_type == record_type
  if (!is.null(study)) {
    keep <- keep & manifest$study == study
  }

  row <- manifest[keep, , drop = FALSE]
  if (nrow(row) == 0) {
    target <- if (is.null(study)) record_type else paste0(record_type, " for ", study)
    stop("HuMMANet manifest entry not found: ", target)
  }

  row[1, , drop = FALSE]
}

# Internal helper: return the HuMMANet subset of ExperimentHub.
HuMMANet_fetch_hub <- function(localHub = FALSE) {
  if (!requireNamespace("ExperimentHub", quietly = TRUE)) {
    stop(
      "Package 'ExperimentHub' is required for HuMMANet hub access. ",
      "Install it with `BiocManager::install(\"ExperimentHub\")`."
    )
  }

  hub <- ExperimentHub::ExperimentHub(localHub = localHub)
  hub_cols <- colnames(as.data.frame(S4Vectors::mcols(hub)))
  package_col <- intersect(c("Package", "package"), hub_cols)

  if (length(package_col) == 0) {
    stop(
      "Could not find a package metadata column in the current ",
      "ExperimentHub resource table."
    )
  }

  hub[hub[[package_col[[1]]]] == "HuMMANet"]
}

# Internal helper: load one ExperimentHub record by its manifest title.
HuMMANet_load_hub_record <- function(record_type, study = NULL, localHub = FALSE) {
  row <- HuMMANet_manifest_row(record_type = record_type, study = study)
  hub <- HuMMANet_fetch_hub(localHub = localHub)
  matches <- hub[hub$title == row$title[[1]]]

  if (length(matches) == 0) {
    target <- if (is.null(study)) record_type else paste0(record_type, " for ", study)
    stop(
      "HuMMANet ExperimentHub record not found: ", target, ". ",
      "Have the HuMMANet resources been published yet?"
    )
  }

  matches[[1]]
}

# Internal helper: read one RDS bundle directly from SourceUrl metadata.
HuMMANet_load_remote_record <- function(record_type, study = NULL, extdata_dir = NULL) {
  manifest_row <- HuMMANet_manifest_row(
    record_type = record_type,
    study = study,
    extdata_dir = extdata_dir
  )
  metadata <- HuMMANet_metadata_table(extdata_dir = extdata_dir)
  metadata_row <- metadata[metadata$Title == manifest_row$title[[1]], , drop = FALSE]

  if (nrow(metadata_row) == 0) {
    target <- if (is.null(study)) record_type else paste0(record_type, " for ", study)
    stop("HuMMANet metadata entry not found: ", target)
  }

  source_url <- metadata_row$SourceUrl[[1]]
  if (is.na(source_url) || !nzchar(source_url)) {
    target <- if (is.null(study)) record_type else paste0(record_type, " for ", study)
    stop("No SourceUrl available for HuMMANet metadata entry: ", target)
  }

  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  utils::download.file(source_url, destfile = tmp, mode = "wb", quiet = TRUE)
  readRDS(tmp)
}

# Internal helper: read the local study index.
HuMMANet_local_study_index <- function(extdata_dir = NULL) {
  extdata_dir <- HuMMANet_normalize_extdata_dir(
    extdata_dir = extdata_dir,
    require_studies = FALSE
  )
  index_path <- file.path(extdata_dir, "study_index.csv")
  if (!file.exists(index_path)) {
    stop("Missing study index: ", index_path)
  }

  utils::read.csv(
    index_path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# Internal helper: load a local study bundle from csv files.
HuMMANet_load_study_tables_local <- function(
  study,
  modalities = HuMMANet_public_modality_names(),
  extdata_dir = NULL,
  drop_missing = TRUE
) {
  modalities <- HuMMANet_normalize_modalities(modalities)

  extdata_dir <- HuMMANet_normalize_extdata_dir(
    extdata_dir = extdata_dir,
    require_studies = TRUE
  )
  index <- HuMMANet_local_study_index(extdata_dir = extdata_dir)
  row <- index[index$study == study, , drop = FALSE]
  if (nrow(row) == 0) {
    stop("Unknown study: ", study)
  }

  loaded <- stats::setNames(vector("list", length(modalities)), modalities)
  for (modality in modalities) {
    file_col <- paste0(modality, "_file")
    rel_path <- row[[file_col]][1]

    if (is.na(rel_path) || !nzchar(rel_path)) {
      loaded[[modality]] <- NULL
      next
    }

    loaded[[modality]] <- HuMMANet_read_csv_any(file.path(extdata_dir, rel_path))
  }

  if (drop_missing) {
    loaded <- loaded[!vapply(loaded, is.null, logical(1))]
  }

  loaded
}

# Internal helper: normalize a sample metadata table to DataFrame.
HuMMANet_metadata_coldata <- function(metadata_df) {
  if (!"sample_id" %in% colnames(metadata_df)) {
    stop("MetadataProfile must contain a 'sample_id' column.")
  }

  sample_ids <- as.character(metadata_df$sample_id)
  keep <- !is.na(sample_ids) & nzchar(sample_ids)
  metadata_df <- metadata_df[keep, , drop = FALSE]
  sample_ids <- sample_ids[keep]
  rownames(metadata_df) <- sample_ids

  S4Vectors::DataFrame(metadata_df, row.names = sample_ids)
}

# Internal helper: convert sample x feature table to feature x sample matrix.
HuMMANet_assay_matrix <- function(table_df, sample_ids) {
  if (!"sample_id" %in% colnames(table_df)) {
    stop("Assay table must contain a 'sample_id' column.")
  }

  table_sample_ids <- as.character(table_df$sample_id)
  keep <- !is.na(table_sample_ids) & nzchar(table_sample_ids)
  table_df <- table_df[keep, , drop = FALSE]
  table_sample_ids <- table_sample_ids[keep]

  shared_ids <- intersect(sample_ids, table_sample_ids)
  if (length(shared_ids) == 0) {
    stop("No shared sample IDs found between metadata and assay table.")
  }

  sample_order <- match(shared_ids, table_sample_ids)
  feature_df <- table_df[sample_order, setdiff(colnames(table_df), "sample_id"), drop = FALSE]
  assay_mat <- t(as.matrix(feature_df))
  storage.mode(assay_mat) <- "numeric"
  colnames(assay_mat) <- shared_ids
  rownames(assay_mat) <- colnames(feature_df)
  assay_mat
}

# Internal helper: build basic rowData for a feature vector.
HuMMANet_basic_rowdata <- function(feature_ids, column = "feature_id") {
  rowdata <- data.frame(
    feature_ids,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  colnames(rowdata) <- column
  rownames(rowdata) <- feature_ids
  S4Vectors::DataFrame(rowdata, row.names = feature_ids)
}

# Internal helper: build identifier mapping rowData for harmonized metabolites.
HuMMANet_harmonized_rowdata <- function(feature_ids, mapping_df = NULL) {
  if (is.null(mapping_df)) {
    return(HuMMANet_basic_rowdata(feature_ids, column = "feature_id"))
  }

  keys <- if ("Query_Name" %in% colnames(mapping_df)) {
    as.character(mapping_df$Query_Name)
  } else {
    rep(NA_character_, nrow(mapping_df))
  }

  row_idx <- match(feature_ids, keys)
  matched <- mapping_df[row_idx, , drop = FALSE]
  matched$feature_id <- feature_ids
  rownames(matched) <- feature_ids
  S4Vectors::DataFrame(matched, row.names = feature_ids)
}

# Internal helper: construct one SummarizedExperiment assay.
HuMMANet_build_se <- function(
  table_df,
  coldata,
  assay_name,
  rowdata = NULL,
  rowdata_column = "feature_id"
) {
  sample_ids <- rownames(coldata)
  assay_mat <- HuMMANet_assay_matrix(table_df, sample_ids = sample_ids)
  shared_ids <- colnames(assay_mat)
  coldata <- coldata[shared_ids, , drop = FALSE]

  if (is.null(rowdata)) {
    rowdata <- HuMMANet_basic_rowdata(
      rownames(assay_mat),
      column = rowdata_column
    )
  } else {
    rowdata <- rowdata[rownames(assay_mat), , drop = FALSE]
  }

  SummarizedExperiment::SummarizedExperiment(
    assays = stats::setNames(list(assay_mat), assay_name),
    rowData = rowdata,
    colData = coldata
  )
}

# Internal helper: identify the three assay modalities stored in MAE.
HuMMANet_core_experiment_names <- function() {
  c(
    "taxaAbundanceProfile",
    "OriginalMetaboliteProfile",
    "harmonizedMetaboliteProfile"
  )
}

# Internal helper: identify the long-form annotation modalities.
HuMMANet_annotation_modality_names <- function() {
  setdiff(
    HuMMANet_public_modality_names(),
    c("MetadataProfile", HuMMANet_core_experiment_names())
  )
}

# Internal helper: build a study-level MultiAssayExperiment from raw tables.
HuMMANet_build_study_mae <- function(
  tables,
  modalities = HuMMANet_public_modality_names(),
  drop_missing = TRUE
) {
  metadata_df <- tables[["MetadataProfile"]]
  if (is.null(metadata_df)) {
    stop("MetadataProfile is required to build a study MultiAssayExperiment.")
  }

  coldata <- HuMMANet_metadata_coldata(metadata_df)
  experiments <- list()
  requested_core <- intersect(modalities, HuMMANet_core_experiment_names())
  if (length(requested_core) == 0) {
    requested_core <- intersect(names(tables), HuMMANet_core_experiment_names())
  }

  if ("taxaAbundanceProfile" %in% requested_core &&
      !is.null(tables[["taxaAbundanceProfile"]])) {
    experiments[["taxaAbundanceProfile"]] <- HuMMANet_build_se(
      tables[["taxaAbundanceProfile"]],
      coldata = coldata,
      assay_name = "abundance",
      rowdata_column = "taxon_id"
    )
  }

  if ("OriginalMetaboliteProfile" %in% requested_core &&
      !is.null(tables[["OriginalMetaboliteProfile"]])) {
    experiments[["OriginalMetaboliteProfile"]] <- HuMMANet_build_se(
      tables[["OriginalMetaboliteProfile"]],
      coldata = coldata,
      assay_name = "abundance",
      rowdata_column = "metabolite_id"
    )
  }

  if ("harmonizedMetaboliteProfile" %in% requested_core &&
      !is.null(tables[["harmonizedMetaboliteProfile"]])) {
    harm_table <- tables[["harmonizedMetaboliteProfile"]]
    feature_ids <- setdiff(colnames(harm_table), "sample_id")
    harm_rowdata <- HuMMANet_harmonized_rowdata(
      feature_ids,
      mapping_df = tables[["metaboliteIdentifierMapping"]]
    )
    experiments[["harmonizedMetaboliteProfile"]] <- HuMMANet_build_se(
      harm_table,
      coldata = coldata,
      assay_name = "abundance",
      rowdata = harm_rowdata
    )
  }

  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = experiments,
    colData = coldata
  )

  annotation_names <- intersect(modalities, HuMMANet_annotation_modality_names())
  mae_metadata <- S4Vectors::metadata(mae)
  for (name in annotation_names) {
    value <- tables[[name]]
    if (is.null(value) && drop_missing) {
      next
    }
    mae_metadata[[name]] <- value
  }

  S4Vectors::metadata(mae) <- mae_metadata
  mae
}

#' HuMMANet ExperimentHub Records
#'
#' Return the `ExperimentHub` subset associated with `HuMMANet`.
#'
#' @param localHub Logical scalar passed to `ExperimentHub::ExperimentHub()`.
#'
#' @return An `ExperimentHub` subset filtered to `package == "HuMMANet"`.
#' @examples
#' if (interactive()) {
#'   hub <- HuMMANetHub(localHub = TRUE)
#'   hub
#' }
#' @export
HuMMANetHub <- function(localHub = FALSE) {
  HuMMANet_fetch_hub(localHub = localHub)
}

#' HuMMANet Resource Table
#'
#' Inspect the expected HuMMANet ExperimentHub resources.
#'
#' @param localHub Logical scalar passed to `ExperimentHub::ExperimentHub()`.
#' @param extdata_dir Optional explicit path to a local development `extdata`
#'   directory.
#'
#' @return A `data.frame` describing the HuMMANet records.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' tbl <- HuMMANet_resource_table(extdata_dir = extdata_dir)
#' head(tbl[, c("title", "record_type")])
#' @export
HuMMANet_resource_table <- function(localHub = FALSE, extdata_dir = NULL) {
  manifest <- HuMMANet_hub_manifest(extdata_dir = extdata_dir)

  hub_table <- tryCatch({
    hub <- HuMMANet_fetch_hub(localHub = localHub)
    if (length(hub) == 0) {
      return(NULL)
    }

    meta <- as.data.frame(S4Vectors::mcols(hub), stringsAsFactors = FALSE)
    meta$record_id <- names(hub)
    meta$title <- as.character(meta$title)
    meta[, c(
      "record_id", "title", "description", "rdataclass",
      "species", "taxonomyid", "sourceurl", "sourcetype"
    )]
  }, error = function(...) NULL)

  if (is.null(hub_table)) {
    return(manifest)
  }

  merge(
    manifest,
    hub_table,
    by = "title",
    all.x = TRUE,
    sort = FALSE
  )
}

#' Study Index for HuMMANet
#'
#' Read the HuMMANet study index. By default this uses the `ExperimentHub`
#' resource when available and falls back to the packaged `study_index.csv`.
#'
#' @param extdata_dir Optional explicit path to a local development `extdata`
#'   directory.
#' @param localHub Logical scalar passed to `ExperimentHub::ExperimentHub()`
#'   when hub access is used.
#'
#' @return A `data.frame` with one row per study and modality file metadata.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' idx <- HuMMANet_study_index(extdata_dir = extdata_dir)
#' head(idx[, c("study", "study_slug")])
#' @export
HuMMANet_study_index <- function(extdata_dir = NULL, localHub = FALSE) {
  if (!is.null(extdata_dir)) {
    return(HuMMANet_local_study_index(extdata_dir = extdata_dir))
  }

  hub_index <- tryCatch({
    HuMMANet_load_hub_record(
      record_type = "study_index",
      localHub = localHub
    )
  }, error = function(...) NULL)

  if (!is.null(hub_index)) {
    return(hub_index)
  }

  remote_index <- tryCatch({
    HuMMANet_load_remote_record(record_type = "study_index", extdata_dir = extdata_dir)
  }, error = function(...) NULL)

  if (!is.null(remote_index)) {
    return(remote_index)
  }

  HuMMANet_local_study_index(extdata_dir = extdata_dir)
}

#' List Available Studies
#'
#' @inheritParams HuMMANet_study_index
#'
#' @return Character vector of study identifiers.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' head(HuMMANet_studies(extdata_dir = extdata_dir))
#' @export
HuMMANet_studies <- function(extdata_dir = NULL, localHub = FALSE) {
  unique(HuMMANet_study_index(
    extdata_dir = extdata_dir,
    localHub = localHub
  )$study)
}

#' List Available Modalities for a Study
#'
#' @inheritParams HuMMANet_study_index
#' @param study Study identifier (for example `"FranzosaE_2019"`).
#'
#' @return Character vector of public HuMMANet modality names.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' if (dir.exists(file.path(extdata_dir, "studies"))) {
#'   HuMMANet_available_modalities("WuY_2025", extdata_dir = extdata_dir)
#' }
#' @export
HuMMANet_available_modalities <- function(
  study,
  extdata_dir = NULL,
  localHub = FALSE
) {
  index <- HuMMANet_study_index(
    extdata_dir = extdata_dir,
    localHub = localHub
  )
  row <- index[index$study == study, , drop = FALSE]
  if (nrow(row) == 0) {
    stop("Unknown study: ", study)
  }

  modalities <- HuMMANet_public_modality_names()
  flags <- vapply(
    modalities,
    function(x) {
      has_col <- paste0("has_", x)
      if (has_col %in% colnames(row)) {
        return(isTRUE(row[[has_col]][1]))
      }

      file_col <- paste0(x, "_file")
      if (file_col %in% colnames(row)) {
        value <- row[[file_col]][1]
        return(!is.na(value) && nzchar(value))
      }

      FALSE
    },
    logical(1)
  )

  modalities[flags]
}

#' Load Curated Data for One Study
#'
#' Load one study from the HuMMANet `ExperimentHub` resources. For local
#' development you may pass `extdata_dir` to read directly from csv files.
#'
#' @inheritParams HuMMANet_study_index
#' @param study Study identifier.
#' @param modalities Character vector of modalities to load.
#' @param drop_missing If `TRUE`, missing modalities are omitted from output.
#'
#' @return A study-level `MultiAssayExperiment`.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' if (dir.exists(file.path(extdata_dir, "studies"))) {
#'   x <- HuMMANet_load_study(
#'     "WuY_2025",
#'     modalities = c("MetadataProfile", "harmonizedMetaboliteProfile"),
#'     extdata_dir = extdata_dir
#'   )
#'   class(x)
#'   names(MultiAssayExperiment::experiments(x))
#' }
#' @export
HuMMANet_load_study <- function(
  study,
  modalities = HuMMANet_public_modality_names(),
  extdata_dir = NULL,
  drop_missing = TRUE,
  localHub = FALSE
) {
  modalities <- HuMMANet_normalize_modalities(modalities)
  staged_modalities <- unique(c(
    "MetadataProfile",
    HuMMANet_core_experiment_names(),
    intersect(modalities, HuMMANet_annotation_modality_names())
  ))

  if (!is.null(extdata_dir)) {
    tables <- HuMMANet_load_study_tables_local(
      study = study,
      modalities = staged_modalities,
      extdata_dir = extdata_dir,
      drop_missing = FALSE
    )
    return(HuMMANet_build_study_mae(
      tables = tables,
      modalities = modalities,
      drop_missing = drop_missing
    ))
  }

  bundle <- tryCatch({
    HuMMANet_load_hub_record(
      record_type = "study_bundle",
      study = study,
      localHub = localHub
    )
  }, error = function(...) NULL)

  if (is.null(bundle)) {
    bundle <- tryCatch({
      HuMMANet_load_remote_record(
        record_type = "study_bundle",
        study = study,
        extdata_dir = extdata_dir
      )
    }, error = function(...) NULL)
  }

  if (is.null(bundle)) {
    if (!HuMMANet_local_data_available()) {
      stop(
        "Study ", study, " is not available locally and no published ",
        "HuMMANet ExperimentHub or remote source resource could be retrieved."
      )
    }

    tables <- HuMMANet_load_study_tables_local(
      study = study,
      modalities = staged_modalities,
      extdata_dir = extdata_dir,
      drop_missing = FALSE
    )
    return(HuMMANet_build_study_mae(
      tables = tables,
      modalities = modalities,
      drop_missing = drop_missing
    ))
  }

  if (inherits(bundle, "MultiAssayExperiment")) {
    return(bundle)
  }

  if (is.list(bundle)) {
    return(HuMMANet_build_study_mae(
      tables = bundle,
      modalities = modalities,
      drop_missing = drop_missing
    ))
  }

  stop(
    "Unsupported HuMMANet study bundle class: ",
    paste(class(bundle), collapse = "/")
  )
}

#' Load a Single Modality for One Study
#'
#' @inheritParams HuMMANet_load_study
#' @param modality One public HuMMANet modality name.
#' @param allow_missing If `TRUE`, return `NULL` when modality is missing.
#'
#' @return A `DataFrame`, `SummarizedExperiment`, annotation `data.frame`, or
#'   `NULL` if missing and `allow_missing = TRUE`.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' if (dir.exists(file.path(extdata_dir, "studies"))) {
#'   md <- HuMMANet_load_modality(
#'     "WuY_2025",
#'     "MetadataProfile",
#'     extdata_dir = extdata_dir
#'   )
#'   dim(md)
#' }
#' @export
HuMMANet_load_modality <- function(
  study,
  modality = HuMMANet_public_modality_names(),
  extdata_dir = NULL,
  allow_missing = FALSE,
  localHub = FALSE
) {
  modality <- match.arg(modality)

  study_data <- HuMMANet_load_study(
    study = study,
    modalities = unique(c("MetadataProfile", modality)),
    extdata_dir = extdata_dir,
    drop_missing = TRUE,
    localHub = localHub
  )

  if (identical(modality, "MetadataProfile")) {
    return(as.data.frame(SummarizedExperiment::colData(study_data)))
  }

  if (modality %in% names(MultiAssayExperiment::experiments(study_data))) {
    return(MultiAssayExperiment::experiments(study_data)[[modality]])
  }

  value <- S4Vectors::metadata(study_data)[[modality]]
  if (is.null(value) && !allow_missing) {
    stop("No ", modality, " data available for study ", study)
  }

  value
}

#' HuMMANet Accessor
#'
#' Main convenience loader for HuMMANet data.
#'
#' @inheritParams HuMMANet_load_study
#' @param studies Optional character vector of studies to load. Defaults to all.
#'
#' @return Named list keyed by study, where each element is a
#'   `MultiAssayExperiment`.
#' @examples
#' extdata_dir <- system.file("extdata", package = "HuMMANet")
#' if (dir.exists(file.path(extdata_dir, "studies"))) {
#'   out <- HuMMANet(
#'     studies = "WuY_2025",
#'     modalities = c("MetadataProfile", "OriginalMetaboliteProfile"),
#'     extdata_dir = extdata_dir
#'   )
#'   names(out)
#' }
#' @export
HuMMANet <- function(
  studies = NULL,
  modalities = HuMMANet_public_modality_names(),
  extdata_dir = NULL,
  drop_missing = TRUE,
  localHub = FALSE
) {
  index <- HuMMANet_study_index(
    extdata_dir = extdata_dir,
    localHub = localHub
  )
  all_studies <- unique(index$study)

  if (is.null(studies)) {
    studies <- all_studies
  }

  unknown <- setdiff(studies, all_studies)
  if (length(unknown) > 0) {
    stop("Unknown study/studies: ", paste(unknown, collapse = ", "))
  }

  out <- stats::setNames(vector("list", length(studies)), studies)
  for (study in studies) {
    out[[study]] <- HuMMANet_load_study(
      study = study,
      modalities = modalities,
      extdata_dir = extdata_dir,
      drop_missing = drop_missing,
      localHub = localHub
    )
  }

  out
}
