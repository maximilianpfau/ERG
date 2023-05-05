# This function extracts peaks from photopic ERG data.
library(tidyverse)

photPeakFinder <- function(data) {


  wave_data <- data %>%
    group_by(traceID) %>%
    nest() %>%
    mutate(spline_fit = map(data, ~ smooth.spline(x = .$time, y = .$meanSignal, spar=0.15) )) %>%
    mutate(smoothed = map(spline_fit, ~tibble(time = predict(., deriv=1)$x,
                                              smoothed = predict(.)$y,
                                              deriv1 = predict(., deriv=1)$y,
                                              deriv2 = predict(., deriv=2)$y ) ))


  wave_data_abs_slope_minima <- wave_data %>%
    unnest(smoothed) %>%
    filter(time >= 8 & time <= 75) %>%
    select(!data) %>%
    mutate(abs_slope = abs(deriv1)) %>%
    group_by(traceID) %>%
    mutate(avg_min_slope = slider::slide_dbl(abs_slope, .f=~min(.x), .before = 2, .after = 2,, .complete = TRUE))

  wave_data_abs_slope_minima <- wave_data_abs_slope_minima  %>%
    filter(abs_slope == avg_min_slope)


  bwave_data <- wave_data_abs_slope_minima %>%
    filter(time > 22) %>%
    filter(time < 50) %>%
    filter(smoothed == max(smoothed)) %>%
    select(traceID, time) %>%
    dplyr::rename(bwave_peak_time = time)

  awave_data <- wave_data_abs_slope_minima %>%
    left_join(., bwave_data) %>%
    filter(time < bwave_peak_time) %>%
    filter(smoothed == min(smoothed)) %>%
    select(traceID, time) %>%
    dplyr::rename(awave_peak_time = time)


  data <- data %>%
    left_join(., awave_data) %>%
    left_join(., bwave_data)

  # Extract amplitudes
  awave_amp <- data %>%
    filter(time == awave_peak_time) %>%
    select(traceID, meanSignal) %>%
    dplyr::rename(awave_amp = meanSignal)

  bwave_amp <- data %>%
    filter(time == bwave_peak_time) %>%
    select(traceID, meanSignal) %>%
    dplyr::rename(bwave_to_iso_amp = meanSignal)

  data <- data %>%
    left_join(., awave_amp) %>%
    left_join(., bwave_amp)

  return(data)
}



