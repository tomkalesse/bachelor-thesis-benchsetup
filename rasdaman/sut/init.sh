#!/usr/bin/env bash
wget -O - https://download.rasdaman.org/packages/rasdaman.gpg | sudo apt-key add -
. /etc/os-release
echo "deb [arch=amd64] https://download.rasdaman.org/packages/deb $VERSION_CODENAME stable" \
| sudo tee /etc/apt/sources.list.d/rasdaman.list
sudo apt-get update
sudo apt-get -o Dpkg::Options::="--force-confdef" install -y rasdaman
source /etc/profile.d/rasdaman.sh
rasql -q 'select c from RAS_COLLECTIONNAMES as c' --out string