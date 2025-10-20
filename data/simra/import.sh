#!/usr/bin/env bash
set -euo pipefail

URL="https://github.com/tomkalesse/bachelor-thesis-benchsetup/releases/download/simra-2022-berlin-csv-v0/simra.tar.gz"

ARCHIVE_NAME="simra.tar.gz"
OUTPUT_DIR="simra"

echo "Downloading archive..."
wget -c -O "$ARCHIVE_NAME" "$URL"

echo "Extracting into $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"
tar -xzf "$ARCHIVE_NAME" -C "$OUTPUT_DIR"

# Remove empty CSV files (only header)
find "$OUTPUT_DIR" -type f -name "*.csv" -exec awk 'NR>1{exit 1}' {} \; -delete

echo "Finished!"
du -sh "$OUTPUT_DIR"