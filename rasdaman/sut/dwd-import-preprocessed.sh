#!/usr/bin/env bash
set -euo pipefail

# URL of your release asset
URL="https://github.com/tomkalesse/bachelor-thesis-benchsetup/releases/download/dwd-radlon-5min-2022-geotiff-v1/dwd-geotiff.tar.gz"

# Output paths
ARCHIVE_NAME="dwd-geotiff.tar.gz"
OUTPUT_DIR="dwd-geotiff"

# -----------------------------
# 1. Download
# -----------------------------
echo "📥 Downloading archive..."
wget -c -O "$ARCHIVE_NAME" "$URL"

# -----------------------------
# 2. Extract
# -----------------------------
echo "📦 Extracting into $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"
tar -I pigz -xf "$ARCHIVE_NAME" -C "$OUTPUT_DIR"

# -----------------------------
# 3. Done
# -----------------------------
echo "✅ Finished!"
du -sh "$OUTPUT_DIR"
