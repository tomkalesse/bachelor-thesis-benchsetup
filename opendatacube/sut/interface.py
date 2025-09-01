from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
import numpy as np
from datacube import Datacube
import asyncio
import time

# --------------------
# Server setup
# --------------------
app = FastAPI()
dc = Datacube(app="odc_server_benchmark")

# --------------------
# Request schema
# --------------------
class TrajectoryPoint(BaseModel):
    time: str  # ISO format
    lat: float
    lon: float

class TrajectoryRequest(BaseModel):
    trajectory: list[TrajectoryPoint]
    query_type: str  # "point", "avg", "threshold"
    threshold: float = 1.0  # only used for threshold queries

# --------------------
# Query execution
# --------------------
def execute_query(traj_df: pd.DataFrame, query_type: str, threshold: float = 1.0):
    # load cube for the time range of this trajectory
    ds = dc.load(
        product="dwd_5min_rr",
        time=(traj_df["time"].min(), traj_df["time"].max())
    )
    values = []
    for _, row in traj_df.iterrows():
        sel = ds.sel(
            time=row["time"],
            lat=row["lat"],
            lon=row["lon"],
            method="nearest"
        )
        values.append(sel["precipitation"].item())  # adjust band name

    if query_type == "point":
        return values
    elif query_type == "avg":
        return float(np.mean(values))
    elif query_type == "threshold":
        count_above = np.sum(np.array(values) > threshold)
        duration_minutes = int(count_above * 5)  # assuming 5-min raster resolution
        return duration_minutes
    else:
        raise ValueError(f"Unknown query type: {query_type}")

# --------------------
# API endpoint
# --------------------
@app.post("/query")
async def query_odc(req: TrajectoryRequest):
    try:
        # convert to DataFrame
        traj_df = pd.DataFrame([{
            "time": pd.to_datetime(p.time),
            "lat": p.lat,
            "lon": p.lon
        } for p in req.trajectory])
        
        start_time = time.time()
        result = await asyncio.to_thread(
            execute_query, traj_df, req.query_type, req.threshold
        )
        end_time = time.time()
        return {
            "result": result,
            "latency_sec": end_time - start_time
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# pip install fastapi uvicorn datacube xarray pandas numpy
# uvicorn odc_server:app --host 0.0.0.0 --port 8000 --workers 4
#{
#  "trajectory": [
#    {"time": "2022-11-16T12:02", "lat": 52.531019, "lon": 13.339950},
#    {"time": "2022-11-16T12:08", "lat": 52.531204, "lon": 13.339946}
#  ],
#  "query_type": "avg"
#}