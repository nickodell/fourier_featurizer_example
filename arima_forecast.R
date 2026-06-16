library(forecast)
library(lubridate)

df <- read.csv("denver_temperature.csv")
df$month <- as.Date(df$time)
df$time  <- NULL

train_df <- head(df, 12)
test_df  <- tail(df, 2)

start_train <- c(year(train_df$month[1]), month(train_df$month[1]))
ts_train    <- ts(train_df$temp, frequency = 12, start = start_train)

start_test <- c(year(test_df$month[1]), month(test_df$month[1]))
ts_test    <- ts(test_df$temp, frequency = 12, start = start_test)

cat(sprintf("Train: %s to %s (%d months)\n",
  train_df$month[1], tail(train_df$month, 1), nrow(train_df)))
cat(sprintf("Test:  %s to %s (%d months)\n",
  test_df$month[1], tail(test_df$month, 1), nrow(test_df)))


fit_and_forecast <- function(ts_train, use_fourier, h) {
  if (use_fourier) {
    xreg_train <- fourier(ts_train, K = 1)
    xreg_test  <- fourier(ts_train, K = 1, h = h)
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
xreg_all  <- rbind(fourier(ts_train, K = 1), fourier(ts_train, K = 1, h = nrow(test_df)))
all_times <- df$month


par(mfrow = c(3, 1), mar = c(3, 4, 3, 1), oma = c(2, 0, 2, 0))

vline_x <- start_test[1] + (start_test[2] - 1) / 12

for (entry in list(
  list(result = result_plain,   label = "Without Fourier"),
  list(result = result_fourier, label = "With Fourier (K=1, m=12)")
)) {
  fc    <- entry$result$fc
  title <- sprintf("%s — %s", entry$label, fmt_order(entry$result$fit))
  plot(fc, main = title, ylab = "Temperature (°C)", xlab = "")
  lines(ts_test, col = "black", lwd = 2, type = "o", pch = 19)
  abline(v = vline_x, col = "gray", lty = 2)
  legend("topleft", legend = c("Forecast", "Actual"),
         col = c("blue", "black"), lty = 1, lwd = 2, bty = "n")
}

plot(all_times, xreg_all[, 1], type = "o", col = "darkorange", pch = 19, lwd = 0.8,
     ylim = range(xreg_all), main = "Fourier Exogenous Features (K=1, m=12)",
     ylab = "Value", xlab = "Date")
lines(all_times, xreg_all[, 2], type = "o", col = "purple", pch = 19, lwd = 0.8)
abline(v = test_df$month[1], col = "gray", lty = 2)
legend("topright", legend = colnames(xreg_all),
       col = c("darkorange", "purple"), lty = 1, pch = 19, bty = "n")

mtext("Denver Temperature — ARIMA Forecast vs Actual (Monthly)", outer = TRUE, cex = 1.2)
