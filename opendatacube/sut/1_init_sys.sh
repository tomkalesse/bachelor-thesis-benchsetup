#!/usr/bin/env bash
set -euo pipefail

DC_DB_USER="$USER"
DC_DB_PASS="supersecurepassword"
DC_DB_NAME="datacube"

sudo apt-get update
sudo apt-get install -y \
  python3 python3-pip python3-venv \
  libpq-dev python3-dev \
  libgdal-dev libhdf5-serial-dev libnetcdf-dev \
  postgresql postgresql-contrib postgis \
  gdal-bin git curl 

export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

if [ ! -d "datacube-core" ]; then
  git clone https://github.com/opendatacube/datacube-core
fi

if [ -f "datacube.conf" ]; then
  mkdir -p ./datacube-core
  mv datacube.conf ./datacube-core/datacube.conf
  mv api.py ./datacube-core/api.py
fi

cd datacube-core

pip3 install --break-system-packages --ignore-installed -e .
pip3 install --break-system-packages psycopg2-binary odc-stac odc-loader rasterio xarray pandas numpy fastapi uvicorn

sudo systemctl enable postgresql
sudo systemctl start postgresql

sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${DC_DB_USER}') THEN
      CREATE USER ${DC_DB_USER} WITH PASSWORD '${DC_DB_PASS}' SUPERUSER;
   END IF;
END
\$do\$;

CREATE DATABASE ${DC_DB_NAME} OWNER ${DC_DB_USER};
EOF

datacube -v system init
echo "Open Data Cube installed globally and initialized."

uvicorn api:app --host 0.0.0.0 --port 8080 --workers 8 &
echo "ODC API started on port 8080."