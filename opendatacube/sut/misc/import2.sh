#!/bin/bash

# Variables
URL="https://opendata.dwd.de/climate_environment/CDC/grids_germany/5_minutes/radolan/reproc/2017_002/asc/2022/YW2017.002_202201_asc.tar"
DOWNLOAD_DIR="./dwd-asc"
TAR_FILE="$DOWNLOAD_DIR/YW2017.002_202201_asc.tar"
GEOTIFF_DIR="$DOWNLOAD_DIR/geotiff"

# Create directories
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$GEOTIFF_DIR"

# Download the tar file
echo "Downloading $URL ..."
curl -L -o "$TAR_FILE" "$URL"

# Extract the tar file
echo "Extracting $TAR_FILE ..."
tar -xf "$TAR_FILE" -C "$DOWNLOAD_DIR"

for tar_file in "$DOWNLOAD_DIR"/*.tar.gz; do
    echo "Extracting $tar_file ..."
    tar -xf "$tar_file" -C "$DOWNLOAD_DIR"
done

# Convert .asc files to GeoTIFF
echo "Converting .asc files to GeoTIFF ..."
for asc_file in "$DOWNLOAD_DIR"/*.asc; do
    echo "Processing $asc_file ..."
    if [ -f "$asc_file" ]; then
        base_name=$(basename "$asc_file" .asc)
        out_tif="$GEOTIFF_DIR/${base_name}.tif"
        
        echo "Converting $asc_file -> $out_tif"
        
        # Set the projection info (you need to adjust if necessary)
        gdal_translate -of GTiff -a_srs EPSG:31467 "$asc_file" "$out_tif"
    fi
done

echo "Conversion complete. GeoTIFFs are in $GEOTIFF_DIR"
