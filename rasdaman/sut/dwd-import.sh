#!/bin/bash

# Register RADOLAN CRS if not already present
CUSTOM_CRS="http://localhost:8080/def/crs/custom/0/radolan"
/opt/rasdaman/bin/crs-manager.sh --list | grep -q "$CUSTOM_CRS"

if [ $? -ne 0 ]; then
    echo "Registering custom RADOLAN CRS in Rasdaman..."
    echo "$CUSTOM_CRS" > /tmp/radolan.crs
    echo "+proj=stere +lat_0=90 +lat_ts=60 +lon_0=10 +a=6370040 +b=6370040 +units=m +no_defs" >> /tmp/radolan.crs
    sudo /opt/rasdaman/bin/crs-manager.sh --add /tmp/radolan.crs
    rm /tmp/radolan.crs
else
    echo "Custom RADOLAN CRS already registered."
fi

# Base URL
BASE_URL="https://opendata.dwd.de/climate_environment/CDC/grids_germany/5_minutes/radolan/reproc/2017_002/asc/2022"

# Target directories
DOWNLOAD_DIR="./dwd-asc"
GEOTIFF_DIR="./dwd-geotiff"

# Create directories
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$GEOTIFF_DIR"

# Array of filenames to download
declare -a MONTHS=(
    "YW2017.002_202201_asc.tar"
    "YW2017.002_202202_asc.tar"
    "YW2017.002_202203_asc.tar"
    "YW2017.002_202204_asc.tar"
    "YW2017.002_202205_asc.tar"
    "YW2017.002_202206_asc.tar"
    "YW2017.002_202207_asc.tar"
    "YW2017.002_202208_asc.tar"
    "YW2017.002_202209_asc.tar"
    "YW2017.002_202210_asc.tar"
    "YW2017.002_202211_asc.tar"
    "YW2017.002_202212_asc.tar"
)

# Download all TAR files
for file in "${MONTHS[@]}"; do
    URL="${BASE_URL}/${file}"
    TARGET="$DOWNLOAD_DIR/$file"

    echo "Downloading $URL ..."
    curl -L -o "$TARGET" "$URL"
done

# Extract all downloaded TAR files
echo "Extracting all .tar files ..."
for tar_file in "$DOWNLOAD_DIR"/*.tar; do
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
        gdal_translate \
        -of GTiff \
         -a_srs "+proj=stere +lat_0=90 +lat_ts=60 +lon_0=10 +a=6370040 +b=6370040 +units=m +no_defs" \
        "$asc_file" \
        "$out_tif"
    fi
done

# Permissions and import
echo "Adjusting permissions and importing into Rasdaman ..."
sudo chown -R rasdaman:rasdaman /home/ubuntu/dwd-geotiff
sudo chmod o+x /home/ubuntu
sudo /opt/rasdaman/bin/wcst_import.sh config.json

echo "✅ All done."