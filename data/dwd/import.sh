#!/usr/bin/env bash
set -euo pipefail

# URL of your release asset
URL="https://github.com/tomkalesse/bachelor-thesis-benchsetup/releases/download/dwd-epsg4326-5min-2022-berlin-geotiff-v0/dwd-geotiff-epsg4326.tar.gz"

ARCHIVE_NAME="dwd-geotiff-4326.tar.gz"
OUTPUT_DIR="dwd-geotiff"

echo "Downloading archive..."
wget -c -O "$ARCHIVE_NAME" "$URL"

echo "Extracting into $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"
tar -I pigz -xf "$ARCHIVE_NAME" -C "$OUTPUT_DIR"

echo "Finished!"
du -sh "$OUTPUT_DIR"