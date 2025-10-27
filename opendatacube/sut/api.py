# DISCLAIMER:
# I used Claude Sonnet 4 for optimization and suggestions when it comes to concurrency / performance / threading in python


from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
from pandas import Timedelta
import numpy as np
from datacube import Datacube
import asyncio
import time
from typing import List
from concurrent.futures import ThreadPoolExecutor
import threading

app = FastAPI()
_thread_local = threading.local()
executor = ThreadPoolExecutor(max_workers=8)

def get_datacube():
    if not hasattr(_thread_local, 'dc'):
        _thread_local.dc = Datacube()
    return _thread_local.dc

class TrajectoryRequest(BaseModel):
    trajectories: List[List[List]]
    query_type: str
    threshold: float = 1.0

def get_dataset_with_spatial_bounds(start_time_str: str, end_time_str: str, traj_df: pd.DataFrame):
    dc = get_datacube()
    start = pd.to_datetime(start_time_str)
    end = pd.to_datetime(end_time_str)
    
    buffer_degrees = 0.02
    min_lat = traj_df["lat"].min() - buffer_degrees
    max_lat = traj_df["lat"].max() + buffer_degrees
    min_lon = traj_df["lon"].min() - buffer_degrees
    max_lon = traj_df["lon"].max() + buffer_degrees
    
    return dc.load(
        product="dwd_weather",
        time=(start, end),
        latitude=(min_lat, max_lat),
        longitude=(min_lon, max_lon),
        output_crs="EPSG:4326",
        resolution=(-0.01, 0.01)
    )

def execute_query(traj_df: pd.DataFrame, query_type: str, threshold: float = 1.0):
    start = traj_df["time"].min() - Timedelta(minutes=5)
    end = traj_df["time"].max() + Timedelta(minutes=5)

    ds = get_dataset_with_spatial_bounds(start.isoformat(), end.isoformat(), traj_df)

    times = traj_df["time"].values
    lats = traj_df["lat"].values
    lons = traj_df["lon"].values
    
    values = np.full(len(traj_df), np.nan)
    
    try:
        if len(traj_df) <= 100:
            for i, (t, lat, lon) in enumerate(zip(times, lats, lons)):
                try:
                    sel = ds.sel(
                        time=pd.to_datetime(t),
                        latitude=lat,
                        longitude=lon,
                        method="nearest"
                    )
                    values[i] = sel["rainfall_amount"].item()
                except (KeyError, IndexError):
                    values[i] = 0.0
        else:
            chunk_size = 50
            for i in range(0, len(traj_df), chunk_size):
                chunk_end = min(i + chunk_size, len(traj_df))
                for j in range(i, chunk_end):
                    try:
                        sel = ds.sel(
                            time=pd.to_datetime(times[j]),
                            latitude=lats[j],
                            longitude=lons[j],
                            method="nearest"
                        )
                        values[j] = sel["rainfall_amount"].item()
                    except (KeyError, IndexError):
                        values[j] = 0.0
    except Exception as e:
        for i, (_, row) in enumerate(traj_df.iterrows()):
            try:
                sel = ds.sel(
                    time=row["time"],
                    latitude=row["lat"],
                    longitude=row["lon"],
                    method="nearest"
                )
                values[i] = sel["rainfall_amount"].item()
            except (KeyError, IndexError):
                values[i] = 0.0

    valid_values = values[~np.isnan(values)]
    
    if len(valid_values) == 0:
        if query_type in ["sum", "avg", "threshold", "fraction"]:
            return 0.0
        elif query_type == "mask":
            return []
    
    if query_type == "sum":
        return float(np.sum(valid_values))
    elif query_type == "avg":
        return float(np.mean(valid_values))
    elif query_type == "threshold":
        count_above = int(np.sum(valid_values > threshold))
        return count_above
    elif query_type == "mask":
        mask = values > threshold
        mask_points = traj_df[mask]
        return mask_points.to_dict(orient="records")
    elif query_type == "fraction":
        fraction_above = float(np.sum(valid_values > threshold) / len(valid_values))
        return fraction_above
    else:
        raise ValueError(f"Unknown query type: {query_type}")

async def process_single_trajectory(traj: List[List], query_type: str, threshold: float):
    try:
        traj_df = pd.DataFrame(traj, columns=["time", "lat", "lon"])
        traj_df["time"] = pd.to_datetime(traj_df["time"])
        
        start_time = time.time()
        
        loop = asyncio.get_event_loop()
        res = await loop.run_in_executor(
            executor, 
            execute_query, 
            traj_df, 
            query_type, 
            threshold
        )
        
        end_time = time.time()
        
        return {
            "trajectory_result": res,
            "latency_sec": end_time - start_time
        }
    except Exception as e:
        return {
            "trajectory_result": None,
            "latency_sec": 0.0,
            "error": str(e)
        }

@app.post("/query")
async def query_odc(req: TrajectoryRequest):
    try:
        tasks = [
            process_single_trajectory(traj, req.query_type, req.threshold)
            for traj in req.trajectories
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)

        processed_results = []
        for result in results:
            if isinstance(result, Exception):
                processed_results.append({
                    "trajectory_result": None,
                    "latency_sec": 0.0,
                    "error": str(result)
                })
            else:
                processed_results.append(result)
        
        if len(processed_results) == 1:
            return processed_results[0]
        return processed_results

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.on_event("shutdown")
async def shutdown_event():
    executor.shutdown(wait=True)

# uvicorn api:app --host 0.0.0.0 --port 8080 --workers 8