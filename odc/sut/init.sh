#!/usr/bin/env bash
set -euo pipefail

# Install necessary packages
sudo apt-get update
sudo apt-get install -y libgdal-dev libhdf5-serial-dev libnetcdf-dev postgresql postgis python3

# Define variables
CONDA_DIR="$HOME/mambaforge"
DC_CONF_DIR="$HOME/.datacube"
DC_CONF_FILE="$DC_CONF_DIR/datacube.conf"
DC_DB_USER="$USER"
DC_DB_PASS="supersecurepassword"
DC_DB_NAME="datacube"

# Install Mambaforge
if [ ! -d "$CONDA_DIR" ]; then
  echo "Installing Mambaforge to $CONDA_DIR..."
  curl -L "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" -o mambaforge.sh
  bash mambaforge.sh -b -p "$CONDA_DIR"
  rm mambaforge.sh
  source "$CONDA_DIR/etc/profile.d/conda.sh"
else
  rm -rf "$CONDA_DIR"
  echo "Installing Mambaforge to $CONDA_DIR..."
  curl -L "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" -o mambaforge.sh
  bash mambaforge.sh -b -p "$CONDA_DIR"
  rm mambaforge.sh
  source "$CONDA_DIR/etc/profile.d/conda.sh"
fi

# Clone and set up datacube
git clone https://github.com/opendatacube/datacube-core
cd datacube-core
mamba env create -f conda-environment.yml -y
conda activate cubeenv

# Set up PostgreSQL
echo "Creating PostgreSQL user and database..."
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT
      FROM   pg_catalog.pg_user
      WHERE  usename = '${DC_DB_USER}') THEN

      CREATE USER ${DC_DB_USER} WITH PASSWORD '${DC_DB_PASS}' SUPERUSER;
   END IF;
END
\$do\$;

CREATE DATABASE ${DC_DB_NAME} OWNER ${DC_DB_USER};
EOF

# Ensure the datacube config directory exists
mkdir -p "$DC_CONF_DIR"

# Create datacube.conf
cat > "$DC_CONF_FILE" <<EOF
[production]
index_driver: default
db_database: ${DC_DB_NAME}
db_hostname:
db_username: ${DC_DB_USER}
db_password: ${DC_DB_PASS}

[default]
alias: production

[test]
index_driver: default
db_database: datacube_test

[migration]
index_driver: postgis
db_url: postgresql://username:password@server.domain:5444/mydb

[null]
index_driver: null

[local_memory]
index_driver: memory
EOF

echo "datacube.conf created at $DC_CONF_FILE"

# Initialize the datacube
datacube -v system init
