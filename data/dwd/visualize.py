import rasterio
from rasterio.enums import Resampling
import numpy as np
from matplotlib import cm
from PIL import Image
import folium

tiff_file = "./dwd-geotiff/dwd-geotiff-epsg4326/YW_2017.002_20221230_2025.tif"
png_file = "rain_overlay.png"

with rasterio.open(tiff_file) as src:
    # Scale factor: e.g., 2 = double the resolution
    scale_factor = 2
    new_height = int(src.height * scale_factor)
    new_width = int(src.width * scale_factor)

    data = src.read(
        1,
        out_shape=(new_height, new_width),
        resampling=Resampling.bilinear
    ).astype(float)

    # Compute new bounds to match resized data
    bounds = src.bounds

# Mask invalid values
data[data < 0] = np.nan

# Normalize
data_min, data_max = np.nanmin(data), np.nanmax(data)
if data_max - data_min == 0:
    data_norm = np.zeros_like(data)
else:
    data_norm = (data - data_min) / (data_max - data_min)

# Apply colormap
cmap = cm.get_cmap("Blues")
rgba_img = (cmap(data_norm) * 255).astype(np.uint8)

# Make pixels without rain fully transparent
min_alpha = 80      # minimum opacity for light rain
max_alpha = 200     # maximum opacity for heavy rain

alpha_channel = np.where(
    np.isnan(data) | (data==0),
    0,  # fully transparent where no rain
    (min_alpha + data_norm * (max_alpha - min_alpha)).astype(np.uint8)
)
rgba_img[..., 3] = alpha_channel

# Save PNG with transparency
Image.fromarray(rgba_img).save(png_file)

m = folium.Map(location=[52.52, 13.40], zoom_start=11, tiles="cartodbpositron")

folium.raster_layers.ImageOverlay(
    image=png_file,
    bounds=[[bounds.bottom, bounds.left], [bounds.top, bounds.right]],
    opacity=1.0,  # full opacity, actual transparency is in alpha channel
    name="Rainfall"
).add_to(m)

folium.LayerControl().add_to(m)
m.save("dwd.html")
print("Map saved to dwd.html")

