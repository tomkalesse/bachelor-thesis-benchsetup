#!/usr/bin/env bash

# DWD
set -euo pipefail

URL="https://opendata.dwd.de/climate_environment/CDC/grids_germany/5_minutes/radolan/reproc/2017_002/netCDF/2022/YW2017.002_2022_netcdf.tar.gz"
FILENAME=$(basename "$URL")
TARGET_DIR="./data/dwd/"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo "→ Downloading $FILENAME ..."
# -C -  = resume if partially downloaded
# -f    = fail on HTTP errors
# -L    = follow redirects
curl -fL -C - -o "$FILENAME" "$URL"

echo "→ Extracting $FILENAME ..."
tar -xzvf "$FILENAME"

echo "✓ Done. NetCDF files are in: $TARGET_DIR"


URL="https://opendata.dwd.de/climate_environment/CDC/grids_germany/5_minutes/radolan/reproc/2017_002/asc/2022/YW2017.002_202201_asc.tar"

# sudo apt install netcdf-bin
# ncdump -h your_file.nc
# with output create product definition

datacube product add dwd-defintion.yaml
datacube dataset add --auto /path/to/dwd/*.nc


python3 dwd_dataset.py ./radklim_yw_2022/2022/11 -o ./radklim_yw_2022/docs/


# Simra

datacube product add simra-defintion.yaml
datacube dataset add --auto /path/to/rides/*.csv