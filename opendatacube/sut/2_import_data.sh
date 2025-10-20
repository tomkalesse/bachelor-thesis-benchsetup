#!/usr/bin/env bash
set -euo pipefail

mv dwd-product.yml ./datacube-core/dwd-product.yml
mv dwd-dataset.py ./datacube-core/dwd-dataset.py

cd datacube-core

datacube product add dwd-product.yml
python3 dwd-dataset.py

find ./datasets-yaml/ -name "*.yaml" | xargs -n 100 -P 4 datacube dataset add
