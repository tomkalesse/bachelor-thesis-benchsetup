#!/usr/bin/env python3
"""
Script to prepare dataset documents for DWD RADKLIM NetCDF files
"""

import os
import yaml
import uuid
from datetime import datetime, timezone
import xarray as xr
from pathlib import Path
import argparse

def create_dataset_doc(nc_file_path, output_dir=None):
    """Create a dataset document for a NetCDF file"""
    
    nc_path = Path(nc_file_path)
    if output_dir is None:
        output_dir = nc_path.parent
    else:
        output_dir = Path(output_dir)
        # Create output directory if it doesn't exist
        output_dir.mkdir(parents=True, exist_ok=True)
    
    # Open the NetCDF file to extract metadata
    ds = None
    try:
        # Try netcdf4 backend first
        ds = xr.open_dataset(nc_file_path, engine='netcdf4')
    except ImportError:
        try:
            # Fallback to h5netcdf
            ds = xr.open_dataset(nc_file_path, engine='h5netcdf')
        except ImportError:
            raise ImportError("Please install either 'netcdf4' or 'h5netcdf': pip install netcdf4")
    
    try:
        # Extract time bounds
        time_values = ds.time.values
        start_time = str(time_values[0])[:19] + 'Z'  # First timestamp
        end_time = str(time_values[-1])[:19] + 'Z'   # Last timestamp
        
        # Extract spatial bounds (convert from projected to geographic if needed)
        x_min, x_max = float(ds.x.min()), float(ds.x.max())
        y_min, y_max = float(ds.y.min()), float(ds.y.max())
        
        # For geographic bounds, we'll use the lat/lon arrays
        lat_min, lat_max = float(ds.lat.min()), float(ds.lat.max())
        lon_min, lon_max = float(ds.lon.min()), float(ds.lon.max())
        
        # Generate unique ID
        dataset_id = str(uuid.uuid4())
        
        # Create dataset document
        dataset_doc = {
            'id': dataset_id,
            'product': {
                'name': 'dwd_radklim_yw',
                'version': '2017.002',
                'short_name': 'RADKLIM_YW'
            },
            'crs': 'PROJCRS["Stereographic_North_Pole",BASEGEOGCRS["GCS_unnamed ellipse",DATUM["D_unknown",ELLIPSOID["Unknown",6370040,0,LENGTHUNIT["metre",1]]],PRIMEM["Greenwich",0,ANGLEUNIT["Degree",0.0174532925199433]]],CONVERSION["unnamed",METHOD["Polar Stereographic (variant B)"],PARAMETER["Latitude of standard parallel",60,ANGLEUNIT["Degree",0.0174532925199433]],PARAMETER["Longitude of origin",10,ANGLEUNIT["Degree",0.0174532925199433]],PARAMETER["False easting",0,LENGTHUNIT["metre",1000]],PARAMETER["False northing",0,LENGTHUNIT["metre",1000]]],CS[Cartesian,2],AXIS["x",south,MERIDIAN[90,ANGLEUNIT["degree",0.0174532925199433]],ORDER[1],LENGTHUNIT["metre",1000]],AXIS["y",south,MERIDIAN[180,ANGLEUNIT["degree",0.0174532925199433]],ORDER[2],LENGTHUNIT["metre",1000]]]',
            'grids': {
                'default': {
                    'shape': [1100, 900],  # y, x from your ncdump
                    'transform': [
                        1000.0, 0.0, x_min,  # pixel width, rotation, x offset
                        0.0, -1000.0, y_max, # rotation, pixel height (negative), y offset
                        0.0, 0.0, 1.0        # homogeneous coordinates
                    ]
                }
            },
            'measurements': {
                'rainfall_amount': {
                    'path': str(nc_path.absolute()),
                    'layer': 'RR'
                }
            },
            'lineage': {
                'source_datasets': {}
            },
            'extent': {
                'coord': {
                    'll': {'lat': lat_min, 'lon': lon_min},
                    'lr': {'lat': lat_min, 'lon': lon_max},
                    'ul': {'lat': lat_max, 'lon': lon_min},
                    'ur': {'lat': lat_max, 'lon': lon_max}
                },
                'from_dt': start_time,
                'to_dt': end_time,
                'center_dt': start_time
            },
            'format': {
                'name': 'NetCDF'
            },
            'creation_dt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ'),
            'label': nc_path.stem
        }
        
        # Write dataset document
        output_file = output_dir / f"{nc_path.stem}_dataset.yaml"
        with open(output_file, 'w') as f:
            yaml.dump(dataset_doc, f, default_flow_style=False)
        
        print(f"Created dataset document: {output_file}")
        return output_file
        
    finally:
        # Always close the dataset
        if ds is not None:
            ds.close()

def main():
    parser = argparse.ArgumentParser(description='Create ODC dataset documents for DWD RADKLIM NetCDF files')
    parser.add_argument('input_path', help='NetCDF file or directory containing NetCDF files')
    parser.add_argument('-o', '--output-dir', help='Output directory for dataset documents')
    
    args = parser.parse_args()
    
    input_path = Path(args.input_path)
    
    if input_path.is_file():
        # Single file
        create_dataset_doc(input_path, args.output_dir)
    elif input_path.is_dir():
        # Directory - process all .nc files
        nc_files = list(input_path.glob('*.nc'))
        if not nc_files:
            print(f"No .nc files found in {input_path}")
            return
        
        print(f"Found {len(nc_files)} NetCDF files")
        for nc_file in nc_files:
            try:
                create_dataset_doc(nc_file, args.output_dir)
            except Exception as e:
                print(f"Error processing {nc_file}: {e}")
    else:
        print(f"Input path {input_path} does not exist")

if __name__ == '__main__':
    main()