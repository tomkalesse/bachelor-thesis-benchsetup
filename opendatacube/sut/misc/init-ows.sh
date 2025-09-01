#!/usr/bin/env bash
set -euo pipefail

# Download and install Miniconda if not already installed
if [ ! -d "$HOME/miniconda" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda
    rm miniconda.sh
fi

# Add conda to PATH
export PATH="$HOME/miniconda/bin:$PATH"
source "$HOME/miniconda/etc/profile.d/conda.sh"

# Make conda-forge the only source
conda config --add channels conda-forge
conda config --set channel_priority strict

# Create env without touching Anaconda's ToS-bound channels
conda create -y -n ows --override-channels -c conda-forge python=3.10 datacube pre_commit postgis

conda activate ows

# Install datacube-ows
pip install -q datacube-ows[all]

# Set up PostgreSQL database
pgdata=$(pwd)/.dbdata
if [ ! -d "${pgdata}" ]; then
    initdb -D "${pgdata}" --auth-host=md5 --encoding=UTF8 --username=ubuntu
fi

pg_ctl -D "${pgdata}" -l "${pgdata}/pg.log" start

# Wait for PostgreSQL to become available
sleep 3

# Create database and enable PostGIS
if ! psql -U ubuntu -lqt | cut -d \| -f 1 | grep -qw ows; then
    createdb ows -U ubuntu
    psql -U ubuntu -d ows -c "CREATE EXTENSION IF NOT EXISTS postgis;"
fi

# Set ODC environment variable
export ODC_DEFAULT_DB_URL=postgresql:///ows

# Initialize datacube
datacube system init

# Configure OWS
export DATACUBE_OWS_CFG=datacube_ows.ows_cfg_example.ows_cfg
datacube-ows-update --write-role ubuntu --schema

echo "Setup complete. You can now run the OWS server or queries."
