#!/bin/bash

set -euo pipefail

DOWNLOAD_DIR="./simra"
OUTPUT_DIR="./processed"

# Dependencies
sudo apt-get update
sudo apt-get install -y unzip curl parallel gawk

mkdir -p "$DOWNLOAD_DIR" "$OUTPUT_DIR"

# Two archives (Oct 2021–Sep 2022, Oct 2022–Jul 2023)
ARCHIVES=(
  "https://depositonce.tu-berlin.de/bitstreams/fc9c417f-8a30-4dd5-8b14-6a7d027c2116/download"
  "https://depositonce.tu-berlin.de/bitstreams/da8dc2d3-0ba1-4081-86a3-9a95185ad366/download"
)

for url in "${ARCHIVES[@]}"; do
  zipfile="$DOWNLOAD_DIR/$(basename "$url").zip"
  if [ ! -f "$zipfile" ]; then
    echo "Downloading $url ..."
    curl -L "$url" --output "$zipfile"
    unzip -o "$zipfile" -d "$DOWNLOAD_DIR"
    rm "$zipfile"
  fi
done

process_csv() {
    infile="$1"
    outfile="$OUTPUT_DIR/$(basename "$infile")_2022.csv"

    echo 'timeStamp,lat,lon' > "$outfile"

    awk -F',' '
    NR > 1 && $1 != "" && $2 != "" {
        ts_ms = $6
        ts_sec = int(ts_ms / 1000)  # integer seconds
        cmd = "date -d @" ts_sec " +\"%Y-%m-%dT%H:%M:%S.%3N\""
        cmd | getline newts
        close(cmd)

        if (newts ~ /^2022-/) {
        print "\"" newts "\"," $1 "," $2
        }
    }
    ' "$infile" >> "$outfile"
}

export -f process_csv
export OUTPUT_DIR

echo "Processing SimRa ride files..."
# match files like VM2_* (with or without .csv)
find "$DOWNLOAD_DIR/Berlin/Rides/2022" -type f -name "VM2_*" | parallel process_csv {}

echo "Creating tar.gz archive..."
tar -czf simra_processed.tar.gz -C "$OUTPUT_DIR" .

echo "DONE → simra_processed.tar.gz"
