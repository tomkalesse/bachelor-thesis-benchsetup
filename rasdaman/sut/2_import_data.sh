#!/usr/bin/env bash
echo "Adjusting permissions and importing into Rasdaman ..."
sudo chown -R rasdaman:rasdaman /home/ubuntu/dwd-geotiff
sudo chmod o+x /home/ubuntu
sudo /opt/rasdaman/bin/wcst_import.sh dwd-config-epsg.json

echo "All done."