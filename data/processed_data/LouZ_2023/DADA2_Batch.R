#!/usr/bin/env Rscript

cat("+++++++++++ =========== Loading dada2 library =========== +++++++++++\n")
suppressPackageStartupMessages(library(dada2))

# Read command-line arguments
args <- commandArgs(trailingOnly = TRUE)
arg_len <- length(args)

# Show help if requested
if (arg_len == 1 && (args[1] == "-h" || args[1] == "--help")) {
  cat("
Usage:
  Single-End:
    Rscript dada2_pipeline.R <data_dir> single <pattern>

  Paired-End:
    Rscript dada2_pipeline.R <data_dir> paired <forward_pattern> <reverse_pattern>

Arguments:
  <data_dir>        Path to the directory containing FASTQ files
  <pattern>         Pattern for matching single-end FASTQ files (e.g., .*\\.fastq\\.gz$)
  <forward_pattern> Pattern for matching forward reads (e.g., .*_1.fastq.gz$)
  <reverse_pattern> Pattern for matching reverse reads (e.g., .*_2.fastq.gz$)

Examples:
  Rscript dada2_pipeline.R ./data single '.*\\.fastq\\.gz$'
  Rscript dada2_pipeline.R ./data paired '.*_1.fastq.gz$' '.*_2.fastq.gz$'
")
  quit(status = 0)
}

# Validate arguments
if (arg_len != 3 && arg_len != 4) {
  stop("Invalid usage. Use -h or --help for usage instructions.")
}

# Assign arguments
data_dir <- args[1]
run_type <- args[2]

# Set working directory
setwd(data_dir)
cat(paste0("+++++++++++ Working in Directory: ", data_dir, " +++++++++++\n"))

# Prepare filtered output path
filt_path <- file.path(data_dir, "filtered")
dir.create(filt_path, showWarnings = FALSE)
cat(paste0("+++++++++++ Created Output Directory: ", filt_path, " +++++++++++\n"))

# SINGLE-END LOGIC
if (arg_len == 3 && run_type == "single") {
  pattern <- args[3]
  fnFs <- list.files(pattern = pattern, full.names = TRUE)
  sample_names <- gsub(pattern, "", basename(fnFs))
  sample_names <- unique(sample_names)

  filtFs <- file.path(filt_path, paste0(sample_names, "_filt.fastq.gz"))
  names(filtFs) <- sample_names

  cat("+++++++++++ Filtering and Trimming (Single-End) +++++++++++\n")
  filterAndTrim(fnFs, filtFs, compress = TRUE, multithread = TRUE)

  cat("+++++++++++ Learning Error Rates +++++++++++\n")
  errF <- learnErrors(filtFs, multithread = TRUE)

  cat("+++++++++++ Sample Inference +++++++++++\n")
  dadaFs <- dada(filtFs, err = errF, multithread = TRUE)

  cat("+++++++++++ Creating ASV Table +++++++++++\n")
  seqtab <- makeSequenceTable(dadaFs)
  save.image(file.path(data_dir, "single_end_ASVs.RData"))

  fasta_lines <- sapply(seq_along(colnames(seqtab)), function(i) {
    paste0(">ASV", i, "\n", colnames(seqtab)[i])
  })
  writeLines(fasta_lines, file.path(data_dir, "single_end_ASVs.fasta"))

  cat("+++++++++++ Single-End Pipeline Complete +++++++++++\n")
}

# PAIRED-END LOGIC
if (arg_len == 4 && run_type == "paired") {
  forward_pattern <- args[3]
  reverse_pattern <- args[4]

  fnFs <- list.files(pattern = forward_pattern, full.names = TRUE)
  fnRs <- list.files(pattern = reverse_pattern, full.names = TRUE)
  sample_names <- gsub(forward_pattern, "", basename(fnFs))
  sample_names <- unique(sample_names)

  filtFs <- file.path(filt_path, paste0(sample_names, "_F_filt.fastq.gz"))
  filtRs <- file.path(filt_path, paste0(sample_names, "_R_filt.fastq.gz"))
  names(filtFs) <- sample_names
  names(filtRs) <- sample_names

  cat("+++++++++++ Filtering and Trimming (Paired-End) +++++++++++\n")
  filterAndTrim(fnFs, filtFs, fnRs, filtRs, compress = TRUE, multithread = TRUE)

  cat("+++++++++++ Learning Error Rates +++++++++++\n")
  errF <- learnErrors(filtFs, multithread = TRUE)
  errR <- learnErrors(filtRs, multithread = TRUE)

  cat("+++++++++++ Sample Inference +++++++++++\n")
  dadaFs <- dada(filtFs, err = errF, multithread = TRUE)
  dadaRs <- dada(filtRs, err = errR, multithread = TRUE)

  cat("+++++++++++ Merging Paired Reads +++++++++++\n")
  mergers <- mergePairs(dadaFs, filtFs, dadaRs, filtRs, verbose = TRUE)

  cat("+++++++++++ Creating ASV Table +++++++++++\n")
  seqtab <- makeSequenceTable(mergers)
  save.image(file.path(data_dir, "paired_end_ASVs.RData"))

  fasta_lines <- sapply(seq_along(colnames(seqtab)), function(i) {
    paste0(">ASV", i, "\n", colnames(seqtab)[i])
  })
  writeLines(fasta_lines, file.path(data_dir, "paired_end_ASVs.fasta"))

  cat("+++++++++++ Paired-End Pipeline Complete +++++++++++\n")
}
