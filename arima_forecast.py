import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import pmdarima as pm
from pmdarima.pipeline import Pipeline
from pmdarima.preprocessing import FourierFeaturizer

df = pd.read_csv("denver_temperature.csv", parse_dates=["time"])

train = df.iloc[:12]
test = df.iloc[12:]

print(f"Train: {train['time'].min().date()} to {train['time'].max().date()} ({len(train)} months)")
print(f"Test:  {test['time'].min().date()} to {test['time'].max().date()} ({len(test)} months)")


def fit_and_predict(train, test, use_fourier):
    steps = []
    if use_fourier:
        steps.append(("fourier", FourierFeaturizer(m=12, k=1)))
    steps.append(("arima", pm.AutoARIMA(seasonal=False, stepwise=True)))

    pipe = Pipeline(steps)
    pipe.fit(train["temp"])
    print(f"\n--- {'With' if use_fourier else 'Without'} Fourier ---")
    print(pipe.named_steps["arima"].summary())

    forecast, conf_int = pipe.predict(n_periods=len(test), return_conf_int=True)
    order = pipe.named_steps["arima"].model_.order
    return forecast, conf_int, order, pipe


forecast_plain, ci_plain, order_plain, pipe_plain = fit_and_predict(train, test, use_fourier=False)
forecast_fourier, ci_fourier, order_fourier, pipe_fourier = fit_and_predict(train, test, use_fourier=True)

# Extract Fourier features over the full date range
fourier_step = pipe_fourier.named_steps["fourier"]
_, exog_train = fourier_step.fit_transform(train["temp"])
_, exog_test = fourier_step.transform(test["temp"])
exog_all = pd.concat([exog_train, exog_test.iloc[: len(test)]], ignore_index=True)
all_times = df["time"]

fig, axes = plt.subplots(3, 1, figsize=(12, 11), sharex=True)

for ax, forecast, conf_int, title in [
    (axes[0], forecast_plain, ci_plain, f"Without Fourier — ARIMA{order_plain}"),
    (axes[1], forecast_fourier, ci_fourier, f"With Fourier (k=1, m=12) — ARIMA{order_fourier}"),
]:
    ax.plot(train["time"], train["temp"], color="steelblue", marker="o", linewidth=0.8, label="Train")
    ax.plot(test["time"], test["temp"], color="black", marker="o", linewidth=1.2, label="Actual")
    ax.plot(test["time"], forecast, color="tomato", marker="o", linewidth=1.2, label="Forecast")
    ax.fill_between(test["time"], conf_int[:, 0], conf_int[:, 1], color="tomato", alpha=0.2, label="95% CI")
    ax.axvline(test["time"].iloc[0], color="gray", linestyle="--", linewidth=0.8)
    ax.set_title(title)
    ax.set_ylabel("Temperature (°C)")
    ax.legend()

for col, color in zip(exog_all.columns, ["darkorange", "purple"]):
    axes[2].plot(all_times, exog_all[col], marker="o", linewidth=0.8, color=color, label=col)
axes[2].axvline(test["time"].iloc[0], color="gray", linestyle="--", linewidth=0.8)
axes[2].set_title("Fourier Exogenous Features (k=1, m=12)")
axes[2].set_ylabel("Value")
axes[2].set_xlabel("Date")
axes[2].legend()

fig.suptitle("Denver Temperature — ARIMA Forecast vs Actual (Monthly)", y=1.01)
fig.tight_layout()
plt.show()
