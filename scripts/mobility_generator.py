import pandas as pd
import numpy as np
from datetime import datetime, timedelta

n_rows = 4000
n_devices = 95

cities = {
    "Jakarta": {"lat": (-6.3, -6.1), "lon": (106.7, 106.9)},
    "Surabaya": {"lat": (-7.3, -7.2), "lon": (112.7, 112.8)},
    "Bandung": {"lat": (-6.9, -6.8), "lon": (107.5, 107.7)},
    "Medan": {"lat": (3.5, 3.7), "lon": (98.6, 98.7)},
    "Makassar": {"lat": (-5.2, -5.1), "lon": (119.4, 119.5)},
}

device_ids = [f"D{i:03d}" for i in range(1, n_devices + 1)]

# Date range: Jan – Mar 2026
start_date = datetime(2026, 1, 1)
end_date = datetime(2026, 3, 31)
total_seconds = int((end_date - start_date).total_seconds())

# Assign HOME CITY per device
device_home_city = {
    device: np.random.choice(list(cities.keys()))
    for device in device_ids
}

# Generate mobility events
data = []

for i in range(1, n_rows + 1):
    device = np.random.choice(device_ids)

    # Device stays in its home city
    city = device_home_city[device]
    coords = cities[city]

    # Slight movement within city
    lat = round(np.random.uniform(*coords["lat"]), 5)
    lon = round(np.random.uniform(*coords["lon"]), 5)

    # Random timestamp across 3 months
    random_offset = np.random.randint(0, total_seconds)
    timestamp = start_date + timedelta(seconds=random_offset)

    data.append({
        "event_id": f"EV{i:05d}",
        "device_id": device,
        "timestamp": timestamp.strftime("%Y-%m-%d %H:%M:%S"),
        "latitude": lat,
        "longitude": lon,
        "city": city
    })

# Save
df_events = pd.DataFrame(data).sort_values("timestamp")
df_events.to_csv("../data/mobility.csv", index=False)
