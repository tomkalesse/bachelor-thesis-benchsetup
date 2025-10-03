from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
from pandas import Timedelta
import numpy as np
from datacube import Datacube
import asyncio
import time
from typing import List

app = FastAPI()
dc = Datacube()

class TrajectoryRequest(BaseModel):
    trajectories: List[List[List]]  # list of trajectories, each trajectory = list of [time, lat, lon]
    query_type: str
    threshold: float = 1.0

def execute_query(traj_df: pd.DataFrame, query_type: str, threshold: float = 1.0):
    start = traj_df["time"].min() - Timedelta(minutes=5)
    end = traj_df["time"].max() + Timedelta(minutes=5)
    ds = dc.load(
        product="dwd_weather",
        time=(start, end),
        output_crs="EPSG:4326",
        resolution=(-0.01, 0.01)
    )
    values = []
    for _, row in traj_df.iterrows():
        sel = ds.sel(
            time=row["time"],
            latitude=row["lat"],
            longitude=row["lon"],
            method="nearest"
        )
        values.append(sel["rainfall_amount"].item())

    if query_type == "point":
        return values
    elif query_type == "avg":
        return float(np.mean(values))
    elif query_type == "threshold":
        count_above = np.sum(np.array(values) > threshold)
        duration_minutes = int(count_above * 5)  # assuming 5-min resolution
        return duration_minutes
    elif query_type == "mask":
        # return only trajectory points above threshold
        mask_points = traj_df[np.array(values) > threshold]
        return mask_points.to_dict(orient="records")
    else:
        raise ValueError(f"Unknown query type: {query_type}")


# --------------------
# API endpoint
# --------------------
@app.post("/query")
async def query_odc(req: TrajectoryRequest):
    try:
        results = []

        # iterate over all trajectories
        for traj in req.trajectories:
            # convert trajectory to DataFrame
            traj_df = pd.DataFrame(traj, columns=["time", "lat", "lon"])
            traj_df["time"] = pd.to_datetime(traj_df["time"])
            
            start_time = time.time()
            res = await asyncio.to_thread(
                execute_query, traj_df, req.query_type, req.threshold
            )
            end_time = time.time()

            results.append({
                "trajectory_result": res,
                "latency_sec": end_time - start_time
            })

        # if only one trajectory, unwrap
        if len(results) == 1:
            return results[0]
        return results

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# uvicorn api:app --host 0.0.0.0 --port 8000 --workers 4