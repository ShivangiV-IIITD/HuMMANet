build_hummanet_experimenthub_resources <- function(
  source_extdata_dir = "inst/extdata",
  output_dir = "experimenthub",
  location_prefix = "https://example.org/HuMMANet",
  source_url = "https://github.com/Shivi-Verma29/HuMMANet",
  maintainer = "Nalin Arora <nalin21478@iiitd.ac.in>",
  bioc_version = "devel"
) {
  source_extdata_dir <- normalizePath(source_extdata_dir, mustWork = TRUE)
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  index <- utils::read.csv(
    file.path(source_extdata_dir, "study_index.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  resource_root <- file.path(output_dir, "HuMMANet", "v1")
  studies_dir <- file.path(resource_root, "studies")
  dir.create(studies_dir, recursive = TRUE, showWarnings = FALSE)

  index_resource <- index
  index_path <- file.path(resource_root, "study_index.rds")
  saveRDS(index_resource, index_path)

  manifest_rows <- list(
    data.frame(
      study = "ALL",
      study_slug = "study_index",
      record_type = "study_index",
      title = "HuMMANet Study Index",
      description = paste(
        "Study-level availability table for the HuMMANet",
        "ExperimentHub resources."
      ),
      local_path = file.path("HuMMANet", "v1", "study_index.rds"),
      rdataclass = "data.frame",
      stringsAsFactors = FALSE
    )
  )

  metadata_rows <- list(
    data.frame(
      title = "HuMMANet Study Index",
      description = paste(
        "Study-level availability table for the HuMMANet",
        "ExperimentHub resources."
      ),
      biocversion = bioc_version,
      genome = "NA",
      sourcetype = "RDS",
      sourceurl = source_url,
      sourceversion = "0.1.0",
      species = "Homo sapiens",
      taxonomyid = "9606",
      coordinate_1_based = FALSE,
      dataprovider = "HuMMANet",
      maintainer = maintainer,
      rdataclass = "data.frame",
      dispatchclass = "RDS",
      location_prefix = location_prefix,
      rdatapath = file.path("HuMMANet", "v1", "study_index.rds"),
      preparerclass = "RDSFile",
      tags = "ExperimentHub,ExperimentData,Microbiome,Metabolome",
      stringsAsFactors = FALSE
    )
  )

  for (i in seq_len(nrow(index))) {
    row <- index[i, , drop = FALSE]
    study <- row$study[[1]]
    slug <- row$study_slug[[1]]

    bundle <- list(study = study)
    for (modality in c("metadata", "species", "metabolome")) {
      rel_path <- row[[paste0(modality, "_file")]][1]
      bundle[[modality]] <- if (nzchar(rel_path)) {
        read_hummanet_csv_any(file.path(source_extdata_dir, rel_path))
      } else {
        NULL
      }
    }

    bundle_path <- file.path(studies_dir, paste0(slug, ".rds"))
    saveRDS(bundle, bundle_path)

    manifest_rows[[length(manifest_rows) + 1L]] <- data.frame(
      study = study,
      study_slug = slug,
      record_type = "study_bundle",
      title = paste("HuMMANet Study Bundle:", study),
      description = paste(
        "Curated metadata, species, and metabolome tables",
        "for the HuMMANet study", study, "."
      ),
      local_path = file.path("HuMMANet", "v1", "studies", paste0(slug, ".rds")),
      rdataclass = "list",
      stringsAsFactors = FALSE
    )

    metadata_rows[[length(metadata_rows) + 1L]] <- data.frame(
      title = paste("HuMMANet Study Bundle:", study),
      description = paste(
        "Curated metadata, species, and metabolome tables",
        "for the HuMMANet study", study, "."
      ),
      biocversion = bioc_version,
      genome = "NA",
      sourcetype = "RDS",
      sourceurl = source_url,
      sourceversion = "0.1.0",
      species = "Homo sapiens",
      taxonomyid = "9606",
      coordinate_1_based = FALSE,
      dataprovider = "HuMMANet",
      maintainer = maintainer,
      rdataclass = "list",
      dispatchclass = "RDS",
      location_prefix = location_prefix,
      rdatapath = file.path("HuMMANet", "v1", "studies", paste0(slug, ".rds")),
      preparerclass = "RDSFile",
      tags = paste(
        c("ExperimentHub", "ExperimentData", "Microbiome", "Metabolome", study),
        collapse = ","
      ),
      stringsAsFactors = FALSE
    )
  }

  manifest <- do.call(rbind, manifest_rows)
  metadata <- do.call(rbind, metadata_rows)

  utils::write.csv(
    manifest,
    file = file.path(source_extdata_dir, "hub_manifest.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    metadata,
    file = file.path(source_extdata_dir, "metadata.csv"),
    row.names = FALSE
  )

  invisible(list(
    manifest = manifest,
    metadata = metadata,
    resource_root = resource_root
  ))
}

read_hummanet_csv_any <- function(path) {
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
