args <- commandArgs(trailingOnly = TRUE)

root_dir <- if (length(args) >= 1L) {
  normalizePath(args[[1]], mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

zenodo_record_id <- if (length(args) >= 2L) {
  args[[2]]
} else {
  "22053943"
}

extdata_dir <- file.path(root_dir, "inst", "extdata")
manifest_path <- file.path(extdata_dir, "hub_manifest.csv")
metadata_path <- file.path(extdata_dir, "metadata.csv")

manifest <- utils::read.csv(
  manifest_path,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

base_url <- paste0("https://zenodo.org/records/", zenodo_record_id, "/files")

build_tags <- function(study, record_type) {
  if (identical(record_type, "study_index")) {
    return(paste(
      c(
        "ExperimentHub",
        "ExperimentData",
        "Microbiome",
        "Metabolome",
        "HuMMANet",
        "study_index"
      ),
      collapse = ","
    ))
  }

  paste(
    c(
      "ExperimentHub",
      "ExperimentData",
      "Microbiome",
      "Metabolome",
      "HuMMANet",
      "harmonizedMetaboliteProfile",
      "metaboliteIdentifierMapping",
      "microbialProducerAnnotations",
      "metaboliteDiseaseAssociations",
      "metabolitePathwayAnnotations",
      "drugBankSimilarityMatches",
      "drugCentralSimilarityMatches",
      study
    ),
    collapse = ","
  )
}

metadata <- data.frame(
  Title = manifest$title,
  Description = manifest$description,
  BiocVersion = "3.24",
  Genome = NA_character_,
  SourceType = "RDS",
  SourceUrl = paste0(base_url, "/", basename(manifest$local_path), "?download=1"),
  SourceVersion = "0.99.0",
  Species = "Homo sapiens",
  TaxonomyId = "9606",
  Coordinate_1_based = FALSE,
  DataProvider = "HuMMANet",
  Maintainer = "Nalin Arora <nalin21478@iiitd.ac.in>",
  RDataClass = manifest$rdataclass,
  DispatchClass = "RDS",
  Location_Prefix = base_url,
  RDataPath = basename(manifest$local_path),
  PreparerClass = "RDSFile",
  Tags = vapply(
    seq_len(nrow(manifest)),
    function(i) build_tags(manifest$study[[i]], manifest$record_type[[i]]),
    character(1)
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

utils::write.csv(
  metadata,
  metadata_path,
  row.names = FALSE,
  quote = TRUE,
  na = ""
)

message("Wrote metadata to: ", metadata_path)
message("Zenodo base URL: ", base_url)
