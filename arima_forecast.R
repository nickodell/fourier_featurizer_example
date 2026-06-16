library(forecast)
library(lubridate)

# How many sine and cosine terms should be created?
# Results in 2*K extra exogenous terms
# Must be less than 2 / M - if k = 2 / M, it is
# equivalent to normal 
K <- 1

# Period of seasonality
M <- 12

# Monthly dataset of Denver temperature from the past 14 months.
# I used this dataset because it has strong seasonality.
# Data is from fetch_denver_temp.py.
df <- read.csv("denver_temperature.csv")
df$month <- as.Date(df$time)
df$time  <- NULL

train_df <- head(df, 12)
test_df  <- tail(df, 2)

start_train <- c(year(train_df$month[1]), month(train_df$month[1]))
ts_train    <- ts(train_df$temp, frequency = M, start = start_train)

start_test <- c(year(test_df$month[1]), month(test_df$month[1]))
ts_test    <- ts(test_df$temp, frequency = M, start = start_test)

cat(sprintf("Train: %s to %s (%d months)\n",
  train_df$month[1], tail(train_df$month, 1), nrow(train_df)))
cat(sprintf("Test:  %s to %s (%d months)\n",
  test_df$month[1], tail(test_df$month, 1), nrow(test_df)))


fit_and_forecast <- function(ts_train, use_fourier, h) {
  if (use_fourier) {
    xreg_train <- fourier(ts_train, K = K)
    xreg_test  <- fourier(ts_train, K = K, h = h)
    fit <- auto.arima(ts_train, xreg = xreg_train, seasonal = FALSE)
    fc  <- forecast(fit, xreg = xreg_test, h = h)
  } else {
    fit <- auto.arima(ts_train, seasonal = FALSE)
    fc  <- forecast(fit, h = h)
  }
  list(fit = fit, fc = fc)
}

cat("\n--- Without Fourier ---\n")
result_plain   <- fit_and_forecast(ts_train, use_fourier = FALSE, h = nrow(test_df))
print(summary(result_plain$fit))

cat("\n--- With Fourier ---\n")
result_fourier <- fit_and_forecast(ts_train, use_fourier = TRUE,  h = nrow(test_df))
print(summary(result_fourier$fit))

fmt_order <- function(fit) {
  o <- arimaorder(fit)
  sprintf("ARIMA(%d,%d,%d)", o["p"], o["d"], o["q"])
}

# Fourier features for full date range (train + test)
xreg_all  <- rbind(fourier(ts_train, K = K), fourier(ts_train, K = K, h = nrow(test_df)))
all_times <- df$month


par(mfrow = c(3, 1), mar = c(3, 4, 3, 1), oma = c(2, 0, 2, 0))

vline_x <- start_test[1] + (start_test[2] - 1) / M

for (entry in list(
  list(result = result_plain,   label = "Without Fourier"),
  list(result = result_fourier, label = sprintf("With Fourier (K=%d, m=%d)", K, M))
)) {
  fc    <- entry$result$fc
  title <- sprintf("%s — %s", entry$label, fmt_order(entry$result$fit))
  plot(fc, main = title, ylab = "Temperature (°C)", xlab = "")
  lines(ts_test, col = "black", lwd = 2, type = "o", pch = 19)
  abline(v = vline_x, col = "gray", lty = 2)
  legend("topleft", legend = c("Forecast", "Actual"),
         col = c("blue", "black"), lty = 1, lwd = 2, bty = "n")
}

colors <- palette.colors(ncol(xreg_all), palette = "tableau10")
plot(all_times, xreg_all[, 1], type = "o", col = colors[1], pch = 19, lwd = 0.8,
     ylim = range(xreg_all), main = sprintf("Fourier Exogenous Features (K=%d, m=%d)", K, M),
     ylab = "Value", xlab = "Date")
for (i in seq(2, ncol(xreg_all))) {
  lines(all_times, xreg_all[, i], type = "o", col = colors[i], pch = 19, lwd = 0.8)
}
abline(v = test_df$month[1], col = "gray", lty = 2)
legend("topright", legend = colnames(xreg_all),
       col = colors, lty = 1, pch = 19, bty = "n")

mtext("Denver Temperature — ARIMA Forecast vs Actual (Monthly)", outer = TRUE, cex = 1.2)
