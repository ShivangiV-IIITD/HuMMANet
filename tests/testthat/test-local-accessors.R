test_that("local extdata helpers resolve expected paths", {
  extdata_dir <- local_extdata_dir()

  expect_true(HuMMANet:::HuMMANet_local_data_available(extdata_dir))
  expect_equal(
    HuMMANet:::HuMMANet_normalize_extdata_dir(extdata_dir),
    normalizePath(extdata_dir, mustWork = TRUE)
  )
  expect_equal(
    HuMMANet:::HuMMANet_normalize_extdata_dir(extdata_dir, require_studies = TRUE),
    normalizePath(extdata_dir, mustWork = TRUE)
  )
})

test_that("local extdata helper errors on missing directories", {
  missing_dir <- file.path(tempdir(), "does-not-exist")

  expect_false(HuMMANet:::HuMMANet_local_data_available(missing_dir))
  expect_error(
    HuMMANet:::HuMMANet_normalize_extdata_dir(missing_dir),
    "Could not locate HuMMANet extdata"
  )
})

test_that("csv reader handles plain and gzipped files", {
  tmpdir <- tempdir()
  csv_path <- file.path(tmpdir, "plain.csv")
  gz_path <- file.path(tmpdir, "plain.csv.gz")
  dat <- data.frame(a = 1:2, b = c("x", "y"), stringsAsFactors = FALSE)

  utils::write.csv(dat, csv_path, row.names = FALSE)
  con <- gzfile(gz_path, open = "wt")
  utils::write.csv(dat, con, row.names = FALSE)
  close(con)

  expect_equal(HuMMANet:::HuMMANet_read_csv_any(csv_path), dat)
  expect_equal(HuMMANet:::HuMMANet_read_csv_any(gz_path), dat)
  expect_error(
    HuMMANet:::HuMMANet_read_csv_any(file.path(tmpdir, "missing.csv")),
    "File does not exist"
  )
})

test_that("public modality names are stable and valid", {
  modalities <- HuMMANet:::HuMMANet_public_modality_names()

  expect_length(modalities, 10L)
  expect_true(all(c(
    "MetadataProfile",
    "taxaAbundanceProfile",
    "OriginalMetaboliteProfile",
    "harmonizedMetaboliteProfile"
  ) %in% modalities))
  expect_equal(
    HuMMANet:::HuMMANet_normalize_modalities(c("MetadataProfile", "taxaAbundanceProfile")),
    c("MetadataProfile", "taxaAbundanceProfile")
  )
  expect_error(
    HuMMANet:::HuMMANet_normalize_modalities("metadata"),
    "'arg' should be one of"
  )
})

test_that("manifest and study index can be read locally", {
  extdata_dir <- local_extdata_dir()

  manifest <- HuMMANet:::HuMMANet_hub_manifest(extdata_dir)
  index <- HuMMANet:::HuMMANet_local_study_index(extdata_dir)
  row <- HuMMANet:::HuMMANet_manifest_row("study_index", extdata_dir = extdata_dir)

  expect_s3_class(manifest, "data.frame")
  expect_s3_class(index, "data.frame")
  expect_gt(nrow(manifest), 1L)
  expect_gt(nrow(index), 1L)
  expect_identical(row$record_type[[1]], "study_index")
  expect_error(
    HuMMANet:::HuMMANet_manifest_row("not_a_record", extdata_dir = extdata_dir),
    "HuMMANet manifest entry not found"
  )
})

test_that("study index and study listing work with local packaged data", {
  extdata_dir <- local_extdata_dir()
  index <- HuMMANet_study_index(extdata_dir = extdata_dir)
  studies <- HuMMANet_studies(extdata_dir = extdata_dir)

  expect_s3_class(index, "data.frame")
  expect_true(all(c(
    "study",
    "MetadataProfile_file",
    "taxaAbundanceProfile_file",
    "OriginalMetaboliteProfile_file",
    "harmonizedMetaboliteProfile_file"
  ) %in% names(index)))
  expect_equal(studies, unique(index$study))
  expect_gt(length(studies), 10L)
})

test_that("available modalities and local study loading work", {
  extdata_dir <- local_extdata_dir()
  study <- "WuY_2025"

  modalities <- HuMMANet_available_modalities(study, extdata_dir = extdata_dir)
  loaded <- HuMMANet_load_study(
    study,
    modalities = c("MetadataProfile", "OriginalMetaboliteProfile"),
    extdata_dir = extdata_dir
  )

  expect_true(all(c("MetadataProfile", "OriginalMetaboliteProfile") %in% modalities))
  expect_named(loaded, c("MetadataProfile", "OriginalMetaboliteProfile"))
  expect_s3_class(loaded$MetadataProfile, "data.frame")
  expect_s3_class(loaded$OriginalMetaboliteProfile, "data.frame")
  expect_gt(nrow(loaded$MetadataProfile), 0L)
  expect_gt(nrow(loaded$OriginalMetaboliteProfile), 0L)

  expect_error(
    HuMMANet_available_modalities("NoSuchStudy", extdata_dir = extdata_dir),
    "Unknown study"
  )
  expect_error(
    HuMMANet_load_study("NoSuchStudy", extdata_dir = extdata_dir),
    "Unknown study"
  )
})

test_that("single modality and top-level loader work with local packaged data", {
  extdata_dir <- local_extdata_dir()

  metadata_profile <- HuMMANet_load_modality(
    "WuY_2025",
    "MetadataProfile",
    extdata_dir = extdata_dir
  )
  subset_data <- HuMMANet(
    studies = c("WuY_2025", "DawkinsJ_2022"),
    modalities = c("MetadataProfile", "harmonizedMetaboliteProfile"),
    extdata_dir = extdata_dir
  )

  expect_s3_class(metadata_profile, "data.frame")
  expect_named(subset_data, c("WuY_2025", "DawkinsJ_2022"))
  expect_named(
    subset_data$WuY_2025,
    c("MetadataProfile", "harmonizedMetaboliteProfile")
  )

  expect_error(
    HuMMANet_load_modality("WuY_2025", "metadata", extdata_dir = extdata_dir),
    "'arg' should be one of"
  )
  expect_error(
    HuMMANet(studies = "NoSuchStudy", extdata_dir = extdata_dir),
    "Unknown study/studies"
  )
})
