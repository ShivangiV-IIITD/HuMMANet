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

  write_study <- function(study, slug, suffix) {
    studies_dir <- file.path(root, "studies", slug)
    dir.create(studies_dir, recursive = TRUE, showWarnings = FALSE)

    metadata <- data.frame(
      sample_id = c(paste0("S", suffix, "_1"), paste0("S", suffix, "_2")),
      group = c("A", "B"),
      stringsAsFactors = FALSE
    )
    taxa <- data.frame(
      sample_id = metadata$sample_id,
      taxon_a = c(0.1, 0.2),
      taxon_b = c(0.3, 0.4),
      stringsAsFactors = FALSE
    )
    original <- data.frame(
      sample_id = metadata$sample_id,
      metabolite_a = c(10, 12),
      metabolite_b = c(20, 25),
      stringsAsFactors = FALSE
    )
    harmonized <- data.frame(
      sample_id = metadata$sample_id,
      HMAN_001 = c(5, 6),
      HMAN_002 = c(7, 8),
      stringsAsFactors = FALSE
    )
    mapping <- data.frame(
      HuMANet_ID = c("HMAN_001", "HMAN_002"),
      Query_Name = c("HMAN_001", "HMAN_002"),
      Standardized_Name = c("Metabolite A", "Metabolite B"),
      HMDB_ID = c("HMDB00001", "HMDB00002"),
      stringsAsFactors = FALSE
    )
    pathway <- data.frame(
      HuMANet_ID = c("HMAN_001", "HMAN_002"),
      pathway_name = c("Pathway A", "Pathway B"),
      stringsAsFactors = FALSE
    )

    utils::write.csv(metadata, file.path(studies_dir, "MetadataProfile.csv"), row.names = FALSE)
    utils::write.csv(taxa, file.path(studies_dir, "taxaAbundanceProfile.csv"), row.names = FALSE)
    utils::write.csv(original, file.path(studies_dir, "OriginalMetaboliteProfile.csv"), row.names = FALSE)
    utils::write.csv(harmonized, file.path(studies_dir, "harmonizedMetaboliteProfile.csv"), row.names = FALSE)
    utils::write.csv(mapping, file.path(studies_dir, "metaboliteIdentifierMapping.csv"), row.names = FALSE)
    utils::write.csv(pathway, file.path(studies_dir, "metabolitePathwayAnnotations.csv"), row.names = FALSE)

    row <- data.frame(
      study = study,
      study_slug = slug,
      MetadataProfile_file = file.path("studies", slug, "MetadataProfile.csv"),
      taxaAbundanceProfile_file = file.path("studies", slug, "taxaAbundanceProfile.csv"),
      OriginalMetaboliteProfile_file = file.path("studies", slug, "OriginalMetaboliteProfile.csv"),
      harmonizedMetaboliteProfile_file = file.path("studies", slug, "harmonizedMetaboliteProfile.csv"),
      metaboliteIdentifierMapping_file = file.path("studies", slug, "metaboliteIdentifierMapping.csv"),
      microbialProducerAnnotations_file = "",
      metaboliteDiseaseAssociations_file = "",
      metabolitePathwayAnnotations_file = file.path("studies", slug, "metabolitePathwayAnnotations.csv"),
      drugBankSimilarityMatches_file = "",
      drugCentralSimilarityMatches_file = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )

    if (include_has_cols) {
      for (modality in c(
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
      )) {
        file_col <- paste0(modality, "_file")
        row[[paste0("has_", modality)]] <- nzchar(row[[file_col]][1])
      }
    }

    row
  }

  index <- do.call(
    rbind,
    list(
      write_study("MiniStudy_2026", "mini_study", "1"),
      write_study("MiniStudyB_2026", "mini_study_b", "2")
    )
  )

  utils::write.csv(
    index,
    file.path(root, "study_index.csv"),
    row.names = FALSE,
    na = ""
  )

  manifest <- data.frame(
    study = c(NA, "MiniStudy_2026", "MiniStudyB_2026"),
    study_slug = c(NA, "mini_study", "mini_study_b"),
    record_type = c("study_index", "study_bundle", "study_bundle"),
    title = c(
      "HuMMANet Study Index",
      "HuMMANet Study Bundle: MiniStudy_2026",
      "HuMMANet Study Bundle: MiniStudyB_2026"
    ),
    description = c("Index", "Bundle", "Bundle"),
    rdatapath = c(
      "HuMMANet/v1/study_index.rds",
      "HuMMANet/v1/studies/mini_study.rds",
      "HuMMANet/v1/studies/mini_study_b.rds"
    ),
    rdataclass = c("data.frame", "list", "list"),
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
