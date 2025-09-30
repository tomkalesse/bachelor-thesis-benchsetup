#!/usr/bin/env bash
set -euo pipefail

# URL of your release asset
URL="https://github.com/tomkalesse/bachelor-thesis-benchsetup/releases/download/simra-2022-berlin-csv-v0/simra.tar.gz"

ARCHIVE_NAME="simra.tar.gz"
OUTPUT_DIR="simra"

echo "Downloading archive..."
wget -c -O "$ARCHIVE_NAME" "$URL"

echo "Extracting into $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"
tar -xzf "$ARCHIVE_NAME" -C "$OUTPUT_DIR"

echo "Finished!"
du -sh "$OUTPUT_DIR"