import os
import pandas as pd
import folium
from tqdm import tqdm 

DATA_DIR = "./simra"

m = folium.Map(location=[52.52, 13.40], zoom_start=11, tiles="cartodbpositron")

for file in tqdm(os.listdir(DATA_DIR)):
    if file.endswith(".csv"):
        path = os.path.join(DATA_DIR, file)
        df = pd.read_csv(path)

        if {"lat", "lon"}.issubset(df.columns):
            coords = df[["lat", "lon"]].dropna().values.tolist()
            if len(coords) > 1:
                folium.PolyLine(
                    coords,
                    color="blue",
                    weight=1,
                    opacity=0.3
                ).add_to(m)

m.save("simra.html")
print("Map saved to simra.html")
