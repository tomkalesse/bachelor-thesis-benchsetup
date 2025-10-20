#!/usr/bin/env bash

sudo apt-get update
sudo apt-get install -y pigz

wget -O - https://download.rasdaman.org/packages/rasdaman.gpg | sudo apt-key add -
. /etc/os-release
echo "deb [arch=amd64] https://download.rasdaman.org/packages/deb $VERSION_CODENAME stable" \
| sudo tee /etc/apt/sources.list.d/rasdaman.list
sudo apt-get update
sudo apt-get -o Dpkg::Options::="--force-confdef" install -y rasdaman
source /etc/profile.d/rasdaman.sh
rasql -q 'select c from RAS_COLLECTIONNAMES as c' --out string

FILE="/opt/rasdaman/etc/petascope.properties"
BACKUP="${FILE}.bak.$(date +%F_%T)"
cp "$FILE" "$BACKUP"
echo "Backup created at $BACKUP"
sed -i \
    -e 's/^authentication_type=.*/authentication_type=/' \
    -e 's/^rasdaman_user=.*/rasdaman_user=rasguest/' \
    -e 's/^rasdaman_pass=.*/rasdaman_pass=rasguest/' \
    "$FILE"

echo "Restarting rasdaman..."
sudo systemctl restart rasdaman
echo "Rasdaman restarted successfully"
exit 0