sudo apt-get install postgis

git clone https://github.com/opendatacube/datacube-ows

cp datacube-ows/datacube_ows/ows_cfg_example.py datacube-ows/datacube_ows/ows_local_cfg.py
DATACUBE_OWS_CFG=ows_local_cfg.ows_cfg

pip install -e .[all]

python3 setup.py install
