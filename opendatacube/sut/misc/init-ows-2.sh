#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Variables (customize as needed)
# ==============================
ENV_NAME="ows"
DB_NAME="ows"
DB_USER="$(whoami)"          # owner of the DB
DB_PASSWORD="mysecretpassword"
DB_WRITER="ows_writer"
DB_WRITER_PASS="writerpass"
DB_READER="ows_reader"
DB_READER_PASS="readerpass"
WORKDIR="$HOME/datacube-ows"
PORT=8080

# ======================================
# Install dependencies and system tools
# ======================================
echo "=== Updating system and installing packages ==="
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip \
  postgresql postgresql-contrib postgis git build-essential libgdal-dev libhdf5-serial-dev libnetcdf-dev \
  gdal-bin hdf5-tools netcdf-bin

# ======================
# PostgreSQL + PostGIS
# ======================
echo "=== Setting up PostgreSQL and PostGIS ==="
# main DB user (your Linux user)
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH SUPERUSER;" || true
sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" || true
sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}" || true
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# OWS roles
sudo -u postgres psql -c "DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_WRITER}') THEN
      CREATE ROLE ${DB_WRITER} LOGIN PASSWORD '${DB_WRITER_PASS}';
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_READER}') THEN
      CREATE ROLE ${DB_READER} LOGIN PASSWORD '${DB_READER_PASS}';
   END IF;
END
\$\$;"

# =================================
# Clone datacube-ows and setup venv
# =================================
echo "=== Cloning datacube-ows and setting up virtualenv ==="
git clone https://github.com/opendatacube/datacube-ows.git "${WORKDIR}" || true
cd "${WORKDIR}"

python3 -m venv venv
source venv/bin/activate

echo "=== Installing datacube-ows and its dependencies ==="
pip install --upgrade pip
pip install -e ".[all]"

# ================================
# Initialize ODC + OWS schema
# ================================
echo "=== Initializing datacube system and OWS schema ==="
export ODC_DEFAULT_DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}"
datacube system init

# Use example config (requires real products indexed later!)
export DATACUBE_OWS_CFG=datacube_ows.ows_cfg_example.ows_cfg

# Setup schema with writer role
datacube-ows-update --schema --write-role "${DB_WRITER}"

# ===============================
# Launch OWS
# ===============================
echo "=== Launching OWS via gunicorn on port ${PORT} ==="

pip install gunicorn

# First test with Flask dev server (for debugging):
# python -m datacube_ows.wsgi

# Run with gunicorn (production-like, 4 workers)
ODC_DEFAULT_DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}" \
DATACUBE_OWS_CFG="datacube_ows.ows_cfg_example.ows_cfg" \
gunicorn -b 0.0.0.0:${PORT} -w 4 datacube_ows.wsgi:application
