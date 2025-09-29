#!/usr/bin/env bash
set -euo pipefail

mv dwd-product.yml ./datacube-core/dwd-product.yml
mv dwd-dataset.py ./datacube-core/dwd-dataset.py

cd datacube-core

# Import DWD product
datacube product add dwd-product.yml

# Create dataset definitions
python3 dwd-dataset.py

# Import DWD datasets
find ./datasets-yaml/ -name "*.yaml" | xargs -n 100 -P 4 datacube dataset add
