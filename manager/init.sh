#!/bin/bash
set -e

# -- Analysis Environment Setup --
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip
pip3 install --break-system-packages pandas matplotlib
echo "Setup complete!"
