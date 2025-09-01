#!/bin/bash

# ONLY BERLIN

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y parallel pigz gdal-bin zip
parallel --citation <<<"will cite"

# Base URL
BASE_URL="https://opendata.dwd.de/climate_environment/CDC/grids_germany/5_minutes/radolan/reproc/2017_002/asc/2022"

# Target directories
DOWNLOAD_DIR="./dwd-asc"
GEOTIFF_DIR="./dwd-geotiff"
OUTPUT_DIR="./dwd-geotiff-epsg4326"

# Create directories
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$GEOTIFF_DIR"
mkdir -p "$OUTPUT_DIR"

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
    rm "$tar_file"  # Remove the tar file after extraction
done

# Extract all daily .tar.gz files inside
echo "Extracting daily .tar.gz files ..."
ls "$DOWNLOAD_DIR"/*.tar.gz | parallel -j 8 'tar -xzf {} -C '"$DOWNLOAD_DIR"' && rm {}'

# Convert .asc files to GeoTIFF
echo "Converting .asc files to GeoTIFF ..."
find "$DOWNLOAD_DIR" -name "*.asc" -print0 | parallel -0 -j 8 '
    asc_file="{}"
    base_name=$(basename "$asc_file" .asc)
    datepart=$(echo "$base_name" | cut -d"_" -f3 | cut -c1-8)
    tmp_tif="'"$GEOTIFF_DIR"'/${base_name}_radolan.tif"
    out_tif="'"$OUTPUT_DIR"'/${base_name}.tif"

    echo "Step 1: Assign RADOLAN CRS to $asc_file -> $tmp_tif"
    gdal_translate -of GTiff \
        -a_srs "+proj=stere +lat_0=90 +lat_ts=60 +lon_0=10 +a=6370040 +b=6370040 +units=m +no_defs" \
        "$asc_file" "$tmp_tif"

    echo "Step 2: Reproject $tmp_tif -> $out_tif (EPSG:4326)"
    gdalwarp -overwrite \
        -s_srs "+proj=stere +lat_0=90 +lat_ts=60 +lon_0=10 +a=6370040 +b=6370040 +units=m +no_defs" \
        -t_srs EPSG:4326 \
        -te 13.08835 52.33826 13.76116 52.67551 \
        -r near \
        -dstnodata -9 \
        -tr 0.01 0.01 \
        "$tmp_tif" "$out_tif"
    
    rm "$tmp_tif"
    rm "$asc_file"
'

echo "Creating archives ..."
tar -czf "${OUTPUT_DIR}.tar.gz" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")"

echo "Done. Archives created:"
ls -lh "${OUTPUT_DIR}.tar.gz" "${OUTPUT_DIR}.tar.gz"