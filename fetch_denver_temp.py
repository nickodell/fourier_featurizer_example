from datetime import date
import meteostat as ms
import pandas as pd

POINT = ms.Point(39.7392, -104.9903, 1609)
START = date(2021, 6, 16)
END = date(2026, 6, 16)

stations = ms.stations.nearby(POINT, limit=4)
ts = ms.daily(stations, START, END)
df = ms.interpolate(ts, POINT).fetch()
df = df.reset_index()
df = df[["time", "temp"]]

# Aggregate to monthly
df = df.sort_values("time").set_index("time")
df = df["temp"].resample("MS").mean().reset_index()

# Drop the current partial month, then keep the last 14 complete months
today = pd.Timestamp.today().normalize()
current_month_start = today.replace(day=1)
df = df[df["time"] < current_month_start]
df = df.tail(14).reset_index(drop=True)

df.to_csv("denver_temperature.csv", index=False)
print(f"Wrote {len(df)} rows to denver_temperature.csv")
print(df)
