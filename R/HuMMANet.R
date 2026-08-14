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
  hub[hub$package == "HuMMANet"]
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
HuMMANet_load_study_local <- function(
  study,
  modalities = c("metadata", "species", "metabolome", "after_hummanet"),
  extdata_dir = NULL,
  drop_missing = TRUE
) {
  modalities <- match.arg(
    modalities,
    choices = c("metadata", "species", "metabolome", "after_hummanet"),
    several.ok = TRUE
  )

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

    if (!nzchar(rel_path)) {
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

#' HuMMANet ExperimentHub Records
#'
#' Return the `ExperimentHub` subset associated with `HuMMANet`.
#'
#' @param localHub Logical scalar passed to `ExperimentHub::ExperimentHub()`.
#'
#' @return An `ExperimentHub` subset filtered to `package == "HuMMANet"`.
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

  HuMMANet_local_study_index(extdata_dir = extdata_dir)
}

#' List Available Studies
#'
#' @inheritParams HuMMANet_study_index
#'
#' @return Character vector of study identifiers.
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
#' @return Character vector chosen from `metadata`, `species`, `metabolome`,
#'   `after_hummanet`.
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

  modalities <- c("metadata", "species", "metabolome")
  if ("has_after_hummanet" %in% colnames(row)) {
    modalities <- c(modalities, "after_hummanet")
  }
  flags <- vapply(
    modalities,
    function(x) isTRUE(row[[paste0("has_", x)]][1]),
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
#' @return Named list of `data.frame` objects.
#' @export
HuMMANet_load_study <- function(
  study,
  modalities = c("metadata", "species", "metabolome", "after_hummanet"),
  extdata_dir = NULL,
  drop_missing = TRUE,
  localHub = FALSE
) {
  modalities <- match.arg(
    modalities,
    choices = c("metadata", "species", "metabolome", "after_hummanet"),
    several.ok = TRUE
  )

  if (!is.null(extdata_dir)) {
    return(HuMMANet_load_study_local(
      study = study,
      modalities = modalities,
      extdata_dir = extdata_dir,
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
    if (!HuMMANet_local_data_available()) {
      stop(
        "Study ", study, " is not available locally and no published ",
        "HuMMANet ExperimentHub resource could be retrieved."
      )
    }

    return(HuMMANet_load_study_local(
      study = study,
      modalities = modalities,
      extdata_dir = extdata_dir,
      drop_missing = drop_missing
    ))
  }

  loaded <- bundle[modalities]
  if (drop_missing) {
    loaded <- loaded[!vapply(loaded, is.null, logical(1))]
  }

  loaded
}

#' Load a Single Modality for One Study
#'
#' @inheritParams HuMMANet_load_study
#' @param modality One of `metadata`, `species`, `metabolome`,
#'   `after_hummanet`.
#' @param allow_missing If `TRUE`, return `NULL` when modality is missing.
#'
#' @return A `data.frame` or `NULL` if missing and `allow_missing = TRUE`.
#' @export
HuMMANet_load_modality <- function(
  study,
  modality = c("metadata", "species", "metabolome", "after_hummanet"),
  extdata_dir = NULL,
  allow_missing = FALSE,
  localHub = FALSE
) {
  modality <- match.arg(modality)

  study_data <- HuMMANet_load_study(
    study = study,
    modalities = modality,
    extdata_dir = extdata_dir,
    drop_missing = allow_missing,
    localHub = localHub
  )

  if (!modality %in% names(study_data)) {
    if (allow_missing) {
      return(NULL)
    }
    stop("No ", modality, " data available for study ", study)
  }

  study_data[[modality]]
}

#' HuMMANet Accessor
#'
#' Main convenience loader for HuMMANet data.
#'
#' @inheritParams HuMMANet_load_study
#' @param studies Optional character vector of studies to load. Defaults to all.
#'
#' @return Named list keyed by study, where each element is a modality list.
#' @export
HuMMANet <- function(
  studies = NULL,
  modalities = c("metadata", "species", "metabolome", "after_hummanet"),
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
