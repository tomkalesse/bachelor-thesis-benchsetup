#!/usr/bin/env bash
set -euo pipefail

# Variables (customize as needed)
ENV_NAME="ows"
DB_NAME="ows"
DB_USER="$(whoami)"
DB_PASSWORD="mysecretpassword"
WORKDIR="$HOME/datacube-ows"

echo "=== Updating system and installing packages ==="
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip \
  postgresql postgresql-contrib postgis git build-essential libgdal-dev libhdf5-serial-dev libnetcdf-dev \
  gdal-bin hdf5-tools netcdf-bin

echo "=== Setting up PostgreSQL and PostGIS ==="
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH SUPERUSER;" || true
sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" || true
sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}"
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

echo "=== Cloning datacube-ows and setting up virtualenv ==="
git clone https://github.com/opendatacube/datacube-ows.git "${WORKDIR}"
cd "${WORKDIR}"

python3 -m venv venv
source venv/bin/activate

echo "=== Installing datacube-ows and its dependencies ==="
pip install --upgrade pip
pip install -e ".[all]"

echo "=== Initializing datacube system and OWS schema ==="
export ODC_DEFAULT_DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}"
datacube system init
export DATACUBE_OWS_CFG=datacube_ows.ows_cfg_example.ows_cfg
datacube-ows-update --write-role "${DB_USER}" --schema

echo "=== Launching OWS via Flask dev server (for benchmarking) ==="
# Install gunicorn if not already
pip install gunicorn

# Run with multiple workers (adjust to CPU count for benchmarking)
gunicorn -b 0.0.0.0:8080 -w 4 "datacube_ows.wsgi:application"
