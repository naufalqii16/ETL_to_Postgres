import pandas as pd
import numpy as np

# Load source data
mobility = pd.read_csv("data/mobility.csv", parse_dates=["timestamp"])
billboards = pd.read_csv("data/billboard.csv")

# Configuration
n_logs = 1000
campaigns = [f"CMP{i:03d}" for i in range(1, 6)]

# Fokus ke billboard aktif
active_billboards = billboards[
    billboards["billboard_id"].isin([f"BB{i:03d}" for i in range(1, 91)])
]

# Generate campaign logs FROM mobility
sampled_events = mobility.sample(n=n_logs, random_state=42)

data_logs = []

for idx, row in sampled_events.iterrows():
    city = row["city"]

    # Billboard must be in the same city
    candidate_billboards = active_billboards[
        active_billboards["city"] == city
    ]

    # Skip if no billboard in that city
    if candidate_billboards.empty:
        continue

    billboard_id = np.random.choice(candidate_billboards["billboard_id"])

    data_logs.append({
        "log_id": f"CL{len(data_logs)+1:04d}",
        "campaign_id": np.random.choice(campaigns),
        "billboard_id": billboard_id,
        "device_id": row["device_id"],
        "exposure_time": row["timestamp"].strftime("%Y-%m-%d %H:%M:%S")
    })

# Save
df_logs = pd.DataFrame(data_logs).sort_values("exposure_time")
df_logs.to_csv("data/campaign_logs.csv", index=False)
