test_that("missing modality behavior is handled correctly", {
  fake_bundle <- list(
    MetadataProfile = data.frame(sample_id = "S1", stringsAsFactors = FALSE),
    taxaAbundanceProfile = data.frame(sample_id = "S1", taxon_a = 1, stringsAsFactors = FALSE),
    OriginalMetaboliteProfile = data.frame(sample_id = "S1", metabolite_a = 2, stringsAsFactors = FALSE),
    harmonizedMetaboliteProfile = data.frame(sample_id = "S1", metabolite_h = 3, stringsAsFactors = FALSE),
    metabolitePathwayAnnotations = NULL
  )

  testthat::local_mocked_bindings(
    HuMMANet_load_hub_record = function(...) fake_bundle,
    .package = "HuMMANet"
  )

  loaded_drop <- HuMMANet_load_study(
    "MiniStudy_2026",
    modalities = c("MetadataProfile", "metabolitePathwayAnnotations"),
    drop_missing = TRUE
  )
  loaded_keep <- HuMMANet_load_study(
    "MiniStudy_2026",
    modalities = c("MetadataProfile", "metabolitePathwayAnnotations"),
    drop_missing = FALSE
  )

  expect_s4_class(loaded_drop, "MultiAssayExperiment")
  expect_s4_class(loaded_keep, "MultiAssayExperiment")
  expect_null(S4Vectors::metadata(loaded_drop)$metabolitePathwayAnnotations)
  expect_null(S4Vectors::metadata(loaded_keep)$metabolitePathwayAnnotations)

  testthat::local_mocked_bindings(
    HuMMANet_load_study = function(...) {
      dummy_se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(
          abundance = matrix(
            1,
            nrow = 1,
            ncol = 1,
            dimnames = list("feature1", "S1")
          )
        ),
        colData = S4Vectors::DataFrame(
          data.frame(sample_id = "S1", row.names = "S1")
        )
      )
      mae <- MultiAssayExperiment::MultiAssayExperiment(
        experiments = list(OriginalMetaboliteProfile = dummy_se),
        colData = S4Vectors::DataFrame(
          data.frame(sample_id = "S1", row.names = "S1")
        )
      )
      mae
    },
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
  expect_s4_class(study_data, "MultiAssayExperiment")
})
