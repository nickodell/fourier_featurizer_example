import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("denver_temperature.csv", parse_dates=["time"])

fig, ax = plt.subplots(figsize=(12, 5))
ax.plot(df["time"], df["temp"], linewidth=0.8, color="steelblue", label="Mean temp")
ax.fill_between(df["time"], df["tmin"], df["tmax"], alpha=0.2, color="steelblue", label="Min/max range")

ax.set_title("Denver Temperature Over Time")
ax.set_xlabel("Date")
ax.set_ylabel("Temperature (°C)")
ax.legend()
fig.tight_layout()
plt.savefig("denver_temperature.png", dpi=150)
plt.show()
