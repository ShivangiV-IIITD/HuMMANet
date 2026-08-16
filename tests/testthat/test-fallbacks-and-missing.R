test_that("missing modality behavior is handled correctly", {
  fake_bundle <- list(
    MetadataProfile = data.frame(sample_id = "S1", stringsAsFactors = FALSE),
    taxaAbundanceProfile = NULL
  )

  testthat::local_mocked_bindings(
    HuMMANet_load_hub_record = function(...) fake_bundle,
    .package = "HuMMANet"
  )

  loaded_drop <- HuMMANet_load_study(
    "MiniStudy_2026",
    modalities = c("MetadataProfile", "taxaAbundanceProfile"),
    drop_missing = TRUE
  )
  loaded_keep <- HuMMANet_load_study(
    "MiniStudy_2026",
    modalities = c("MetadataProfile", "taxaAbundanceProfile"),
    drop_missing = FALSE
  )

  expect_named(loaded_drop, "MetadataProfile")
  expect_named(loaded_keep, c("MetadataProfile", "taxaAbundanceProfile"))
  expect_null(loaded_keep$taxaAbundanceProfile)

  testthat::local_mocked_bindings(
    HuMMANet_load_study = function(...) list(),
    .package = "HuMMANet"
  )

  expect_null(HuMMANet_load_modality(
    "MiniStudy_2026",
    "taxaAbundanceProfile",
    allow_missing = TRUE
  ))
  expect_error(
    HuMMANet_load_modality(
      "MiniStudy_2026",
      "taxaAbundanceProfile",
      allow_missing = FALSE
    ),
    "No taxaAbundanceProfile data available"
  )
})

test_that("available modalities can be inferred from file columns when has columns are absent", {
  extdata_dir <- make_minimal_extdata(include_has_cols = FALSE)

  modalities <- HuMMANet_available_modalities(
    "MiniStudy_2026",
    extdata_dir = extdata_dir
  )

  expect_identical(modalities, "MetadataProfile")
})

test_that("resource table and default accessors fall back to local resources", {
  extdata_dir <- local_extdata_dir()

  testthat::local_mocked_bindings(
    HuMMANet_load_hub_record = function(...) stop("hub unavailable"),
    HuMMANet_fetch_hub = function(...) stop("hub unavailable"),
    HuMMANet_extdata_candidates = function() extdata_dir,
    .package = "HuMMANet"
  )

  resource_table <- HuMMANet_resource_table(extdata_dir = extdata_dir)
  index <- HuMMANet_study_index()
  study_data <- HuMMANet_load_study(
    "WuY_2025",
    modalities = "MetadataProfile"
  )

  expect_s3_class(resource_table, "data.frame")
  expect_true("title" %in% names(resource_table))
  expect_s3_class(index, "data.frame")
  expect_named(study_data, "MetadataProfile")
})
