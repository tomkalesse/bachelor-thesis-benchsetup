#!/bin/bash

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y unzip curl parallel

process_csv() {
    if grep -E '[0-9]+#[0-9]+' "$1" > /dev/null; then
        echo "Truncating $1"
        perl -i -ne '$count++ if /[0-9]+#[0-9]+/; next if /[0-9]+#[0-9]+/ && $count == 2; print if $count >= 2' "$1"
    else
        echo "No truncation needed for $1"
    fi

    if [[ "$1" == *"_data.csv" ]]; then
        echo "File already has the suffix '_data.csv'. No need to rename."
        return 0
    else
        mv "$1" "${1}_data.csv"
    fi
}

export -f process_csv

DOWNLOAD_DIR="./simra"

# Downloading SimRa
sudo mkdir -p "$DOWNLOAD_DIR"
sudo chown "$USER":"$USER" "$DOWNLOAD_DIR"
# https://doi.org/10.14279/depositonce-16439
curl -L0 "https://depositonce.tu-berlin.de/bitstreams/0f94a3d4-c238-4e81-bf8e-579592b50ca8/download" --output "$DOWNLOAD_DIR/simra.zip"
unzip -o "$DOWNLOAD_DIR/simra.zip" -d "$DOWNLOAD_DIR"
rm "$DOWNLOAD_DIR/simra.zip"

echo "Processing SimRa ride files..."
sudo find "$DOWNLOAD_DIR/Berlin/Rides" -type f -name "VM2_*" | parallel process_csv {}

echo "DONE"

echo "Creating archives ..."
tar -czf "simra.tar.gz" -C "$(dirname "$DOWNLOAD_DIR/Berlin/Rides")" "$(basename "$DOWNLOAD_DIR/Berlin/Rides")"

echo "Done. Archives created:"
ls -lh "simra.tar.gz" "simra.tar.gz"