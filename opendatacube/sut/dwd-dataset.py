import os
import uuid
import yaml
import rasterio
from datetime import datetime

input_dir = "/home/ubuntu/dwd-geotiff/dwd-geotiff-epsg4326"
output_dir = "./datasets-yaml"
os.makedirs(output_dir, exist_ok=True)

for fname in os.listdir(input_dir):
    if not fname.endswith(".tif"):
        continue
    
    tif_path = os.path.join(input_dir, fname)
    with rasterio.open(tif_path) as src:
        transform = src.transform
        width = src.width
        height = src.height
        bounds = src.bounds

    date_str = fname.split("_")[2] + fname.split("_")[3].split(".")[0]
    dt = datetime.strptime(date_str, "%Y%m%d%H%M").isoformat() + "Z"

    geometry = {
        "type": "Polygon",
        "coordinates": [[
            [bounds.left, bounds.top],
            [bounds.right, bounds.top],
            [bounds.right, bounds.bottom],
            [bounds.left, bounds.bottom],
            [bounds.left, bounds.top],
        ]]
    }

    dataset = {
        "id": str(uuid.uuid4()),
        "$schema": "https://schemas.opendatacube.org/dataset",
        "product": {"name": "dwd_weather"},
        "format": "GeoTIFF",
        "product_type": "weather_raster",
        "crs": "EPSG:4326",
        "geometry": geometry,
        "grids": {
            "default": {
                "shape": [height, width],
                "transform": list(transform)
            }
        },
        "measurements": {
            "rainfall_amount": {
                "path": os.path.join(input_dir, fname)
            }
        },
        "properties": {
            "datetime": dt,
            "eo:platform": "DWD",
            "eo:instrument": "WeatherSensor",
            "odc:processing_datetime": datetime.utcnow().isoformat() + "Z",
            "odc:file_format": "GeoTIFF",
            "odc:region_code": fname.split("_")[1],
            "dea:dataset_maturity": "final",
            "odc:product_family": "ard"
        },
        "lineage": {}
    }

    yaml_path = os.path.join(output_dir, fname.replace(".tif", ".yaml"))
    with open(yaml_path, "w") as f:
        yaml.dump(dataset, f, sort_keys=False)

print("Dataset YAMLs generated in", output_dir)
