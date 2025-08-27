#!/usr/bin/env bash
set -euo pipefail

# Variables (must match what you used in your install script)
PYTHON_VERSION="3"              # system default python
ENV_NAME="ows"
DB_NAME="ows"
DB_USER="$(whoami)"
WORKDIR="$HOME/datacube-ows"

echo "=== Stopping any running OWS processes ==="
pkill -f "gunicorn.*datacube_ows" || true

echo "=== Dropping PostgreSQL database and user ==="
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};"
sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};"

echo "=== Removing datacube-ows working directory ==="
rm -rf "${WORKDIR}"

echo "=== Removing Python virtual environment if exists ==="
rm -rf "${WORKDIR}/venv"
rm -rf "${HOME}/${ENV_NAME}"

echo "=== Optional: uninstall system packages (skip if you want to keep them) ==="
# Uncomment if you want a really clean slate
# sudo apt-get remove --purge -y python${PYTHON_VERSION} python${PYTHON_VERSION}-venv python3-pip \
#   postgresql postgresql-contrib postgis git build-essential libgdal-dev libhdf5-dev libnetcdf-dev \
#   gdal-bin hdf5-tools netcdf-bin
# sudo apt-get autoremove -y
# sudo apt-get clean

echo "=== Cleanup complete. You can now re-run your init script ==="
