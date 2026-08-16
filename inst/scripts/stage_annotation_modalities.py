from __future__ import annotations

import gzip
import importlib.util
import json
from pathlib import Path
import csv

import pandas as pd


ROOT = Path("/Users/nalinarora/Desktop/Microbiome_Metabolome_Curated_Studies")
STUDY_INDEX_PATH = ROOT / "inst" / "extdata" / "study_index.csv"
ANNOTATION_OUTPUT_DIR = ROOT / "study_annotation_outputs"
EXTDATA_STUDIES_DIR = ROOT / "inst" / "extdata" / "studies"
SPLIT_SCRIPT_PATH = ROOT / "inst" / "scripts" / "split_annotation_workbooks_by_study.py"

ANNOTATION_FILE_MAP = {
    "metaboliteIdentifierMapping": "mapped.csv",
    "microbialProducerAnnotations": "species.csv",
    "metaboliteDiseaseAssociations": "disease.csv",
    "metabolitePathwayAnnotations": "pathways.csv",
    "drugBankSimilarityMatches": "drugbank_hits.csv",
    "drugCentralSimilarityMatches": "drugcentral_hits.csv",
}


def load_split_module():
    spec = importlib.util.spec_from_file_location("split_annotations", SPLIT_SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def ensure_annotation_outputs() -> None:
    splitmod = load_split_module()
    splitmod.OUTPUT_DIR = ANNOTATION_OUTPUT_DIR
    ANNOTATION_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    studies_df = splitmod.active_studies()
    mapped_counts = len(list(ANNOTATION_OUTPUT_DIR.glob("*/mapped.csv")))
    species_counts = len(list(ANNOTATION_OUTPUT_DIR.glob("*/species.csv")))
    disease_counts = len(list(ANNOTATION_OUTPUT_DIR.glob("*/disease.csv")))
    pathways_counts = len(list(ANNOTATION_OUTPUT_DIR.glob("*/pathways.csv")))
    expected = len(studies_df)

    if min(mapped_counts, species_counts, disease_counts, pathways_counts) == expected:
        return

    mapped_outputs, _ = splitmod.create_mapped_outputs(
        pd.ExcelFile(splitmod.MAPPED_WORKBOOK_PATH).parse("mapped"),
        studies_df,
    )
    splitmod.create_multi_value_outputs_streaming(
        splitmod.MAPPED_WORKBOOK_PATH,
        studies_df,
        mapped_outputs,
        sheets=["species", "disease", "pathways"],
    )


def gzip_copy(src: Path, dest: Path) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    rows = 0
    with src.open("rt", encoding="utf-8", newline="") as in_handle:
        reader = csv.reader(in_handle)
        next(reader, None)
        for _ in reader:
            rows += 1
        in_handle.seek(0)
        with gzip.open(dest, "wt", encoding="utf-8", newline="") as out_handle:
            out_handle.write(in_handle.read())
    return int(rows)


def stage_annotation_files() -> dict[str, dict[str, int]]:
    study_index = pd.read_csv(STUDY_INDEX_PATH)
    summary: dict[str, dict[str, int]] = {}

    for modality in ANNOTATION_FILE_MAP:
        study_index[f"{modality}_file"] = ""
        study_index[f"n_{modality}"] = 0
        study_index[f"has_{modality}"] = False

    for row in study_index.itertuples(index=False):
        study = row.study
        slug = row.study_slug
        study_dir = ANNOTATION_OUTPUT_DIR / study
        package_dir = EXTDATA_STUDIES_DIR / slug
        summary[study] = {}

        for modality, src_name in ANNOTATION_FILE_MAP.items():
            src_path = study_dir / src_name
            if not src_path.exists():
                raise FileNotFoundError(f"Missing annotation file for {study}: {src_path}")

            dest_name = f"{modality}.csv.gz"
            dest_rel = Path("studies") / slug / dest_name
            dest_path = ROOT / "inst" / "extdata" / dest_rel
            n_rows = gzip_copy(src_path, dest_path)

            mask = study_index["study"] == study
            study_index.loc[mask, f"{modality}_file"] = dest_rel.as_posix()
            study_index.loc[mask, f"n_{modality}"] = n_rows
            study_index.loc[mask, f"has_{modality}"] = n_rows > 0
            summary[study][modality] = n_rows

    study_index.to_csv(STUDY_INDEX_PATH, index=False)
    return summary


def main() -> None:
    ensure_annotation_outputs()
    summary = stage_annotation_files()
    report = {
        "n_studies": len(summary),
        "modalities": list(ANNOTATION_FILE_MAP),
        "example": next(iter(summary.items())),
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
