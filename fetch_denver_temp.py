from datetime import date
import meteostat as ms

POINT = ms.Point(39.7392, -104.9903, 1609)
START = date(2021, 6, 16)
END = date(2026, 6, 16)

stations = ms.stations.nearby(POINT, limit=4)
ts = ms.daily(stations, START, END)
df = ms.interpolate(ts, POINT).fetch()
df = df[["time", "temp"]]

df.to_csv("denver_temperature.csv")
print(f"Wrote {len(df)} rows to denver_temperature.csv")
print(df.head())
