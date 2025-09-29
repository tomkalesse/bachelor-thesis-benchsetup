#!/usr/bin/env bash
set -euo pipefail

sudo apt-get install libgdal-dev libhdf5-serial-dev libnetcdf-dev postgresql postgis python3
# gdal-bin

CONDA_DIR="$HOME/mambaforge"
if [ ! -d "$CONDA_DIR" ]; then
  echo "Installing Mambaforge to $CONDA_DIR..."
  curl -L "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" -o mambaforge.sh
  bash mambaforge.sh -b -p "$CONDA_DIR"
  rm mambaforge.sh
  source "$CONDA_DIR/etc/profile.d/conda.sh"
else
  echo "Mambaforge already installed at $CONDA_DIR"
fi

git clone https://github.com/opendatacube/datacube-core
cd datacube-core

mamba env create -f conda-environment.yml
conda activate cubeenv

# Creating postgess user matching the current user
sudo -u postgres createuser --superuser $USER
sudo -u postgres createdb datacube

# creating datacube.conf with user and password

datacube -v system init


