import pandas as pd
import numpy as np

# Configuration for 250 rows
n_rows = 100
cities = {
    "Jakarta": {"lat": (-6.3, -6.1), "lon": (106.7, 106.9), "base_cost": 2500000},
    "Surabaya": {"lat": (-7.3, -7.2), "lon": (112.7, 112.8), "base_cost": 1800000},
    "Bandung": {"lat": (-6.9, -6.8), "lon": (107.5, 107.7), "base_cost": 1600000},
    "Medan": {"lat": (3.5, 3.7), "lon": (98.6, 98.7), "base_cost": 1500000},
    "Makassar": {"lat": (-5.2, -5.1), "lon": (119.4, 119.5), "base_cost": 1400000},
    "Semarang": {"lat": (-7.1, -6.9), "lon": (110.3, 110.5), "base_cost": 1300000},
    "Yogyakarta": {"lat": (-7.9, -7.7), "lon": (110.3, 110.5), "base_cost": 1400000}
}

sizes = ["Small", "Medium", "Large"]
size_multipliers = {"Small": 0.6, "Medium": 1.0, "Large": 1.5}

data = []

for i in range(1, n_rows + 1):
    city = np.random.choice(list(cities.keys()))
    coords = cities[city]
    
    lat = np.round(np.random.uniform(coords["lat"][0], coords["lat"][1]), 4)
    lon = np.round(np.random.uniform(coords["lon"][0], coords["lon"][1]), 4)
    
    size = np.random.choice(sizes)
    traffic_score = np.random.randint(40, 100)
    
    # Logic: Cost depends on City Base + Size Multiplier + Traffic Score Multiplier
    traffic_mult = traffic_score / 70
    base_cost = coords["base_cost"] * size_multipliers[size] * traffic_mult
    daily_cost = int(np.round(base_cost, -4)) # Round to nearest 10k
    
    data.append({
        "billboard_id": f"BB{i:03d}",
        "billboard_name": f"{city} {np.random.choice(['Street', 'Avenue', 'Junction', 'Point', 'Center'])} {chr(65 + (i % 26))}",
        "city": city,
        "latitude": lat,
        "longitude": lon,
        "size": size,
        "daily_cost": daily_cost,
        "traffic_score": traffic_score
    })

df = pd.DataFrame(data)
df.to_csv('../data/billboard.csv', index=False)