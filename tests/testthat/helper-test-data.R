local_extdata_dir <- function() {
  candidates <- c(
    system.file("extdata", package = "HuMMANet"),
    file.path(testthat::test_path("..", ".."), "inst", "extdata"),
    file.path(getwd(), "inst", "extdata")
  )
  candidates <- unique(candidates[nzchar(candidates)])
  hits <- candidates[dir.exists(candidates)]

  if (length(hits) == 0) {
    stop("Could not find inst/extdata for tests.")
  }

  normalizePath(hits[[1]], mustWork = TRUE)
}

make_minimal_extdata <- function(include_has_cols = TRUE) {
  root <- file.path(tempdir(), paste0("hummanet-test-", as.integer(stats::runif(1, 1, 1e8))))
  dir.create(root, recursive = TRUE, showWarnings = FALSE)

  studies_dir <- file.path(root, "studies", "mini_study")
  dir.create(studies_dir, recursive = TRUE, showWarnings = FALSE)

  metadata <- data.frame(
    sample_id = c("S1", "S2"),
    group = c("A", "B"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(
    metadata,
    file.path(studies_dir, "MetadataProfile.csv"),
    row.names = FALSE
  )

  if (include_has_cols) {
    index <- data.frame(
      study = "MiniStudy_2026",
      study_slug = "mini_study",
      MetadataProfile_file = "studies/mini_study/MetadataProfile.csv",
      n_MetadataProfile = 2L,
      has_MetadataProfile = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  } else {
    index <- data.frame(
      study = "MiniStudy_2026",
      study_slug = "mini_study",
      MetadataProfile_file = "studies/mini_study/MetadataProfile.csv",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }

  utils::write.csv(
    index,
    file.path(root, "study_index.csv"),
    row.names = FALSE,
    na = ""
  )

  manifest <- data.frame(
    study = c(NA, "MiniStudy_2026"),
    study_slug = c(NA, "mini_study"),
    record_type = c("study_index", "study_bundle"),
    title = c("HuMMANet Study Index", "HuMMANet Study Bundle: MiniStudy_2026"),
    description = c("Index", "Bundle"),
    rdatapath = c("HuMMANet/v1/study_index.rds", "HuMMANet/v1/studies/mini_study.rds"),
    rdataclass = c("data.frame", "list"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  utils::write.csv(
    manifest,
    file.path(root, "hub_manifest.csv"),
    row.names = FALSE,
    na = ""
  )

  root
}
