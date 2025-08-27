#!/bin/bash
set -e

# -- Analysis Environment Setup --
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install pandas matplotlib
echo "✅ Setup complete!"
