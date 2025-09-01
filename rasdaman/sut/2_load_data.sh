#!/usr/bin/env bash
set -euo pipefail

# URL of your release asset
URL_1="https://github.com/tomkalesse/bachelor-thesis-benchsetup/releases/download/dwd-epsg4326-5min-2022-geotiff-v1/dwd-geotiff-4326_H1.tar.gz"
URL_2="https://github.com/tomkalesse/bachelor-thesis-benchsetup/releases/download/dwd-epsg4326-5min-2022-geotiff-v1/dwd-geotiff-4326_H2.tar.gz"

ARCHIVE_NAME_1="dwd-geotiff-4326_H1.tar.gz"
ARCHIVE_NAME_2="dwd-geotiff-4326_H2.tar.gz"
OUTPUT_DIR="dwd-geotiff"

echo "Downloading archive..."
wget -c -O "$ARCHIVE_NAME_1" "$URL_1"
wget -c -O "$ARCHIVE_NAME_2" "$URL_2"

echo "Extracting into $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"
tar -I pigz -xf "$ARCHIVE_NAME_1" -C "$OUTPUT_DIR"
tar -I pigz -xf "$ARCHIVE_NAME_2" -C "$OUTPUT_DIR"

echo "Finished!"
du -sh "$OUTPUT_DIR"


