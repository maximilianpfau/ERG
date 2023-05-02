# This function extracts peaks from scotopic ERG data.
library(tidyverse)

scotPeakFinder <- function(data) {

  # b-wave data
  bwave <- data %>%
    group_by(traceID) %>%
    nest() %>%
    mutate(spline_fit = map(data, ~ smooth.spline(x = .$time, y = .$meanSignal, spar=0.7) )) %>%
    mutate(smoothed = map(spline_fit, ~tibble(time = predict(., deriv=1)$x,
                                              smoothed = predict(.)$y,
                                              deriv1 = predict(., deriv=1)$y,
                                              deriv2 = predict(., deriv=2)$y) ))

  slope_max <- bwave  %>%
    unnest(smoothed) %>%
    filter(time >= 5 & time <= 90) %>%
    group_by(traceID) %>%
    filter(deriv1 == max(deriv1)) %>%
    dplyr::rename(time_of_slope_max = time) %>%
    select(traceID, time_of_slope_max)

  leading_bwave_edge <- bwave %>%
    left_join(., slope_max) %>%
    select(!data) %>%
    unnest(smoothed) %>%
    filter(time < time_of_slope_max) %>%
    group_by(traceID) %>%
    filter(deriv2 == max(deriv2)) %>%
    dplyr::rename(time_of_bwave_edge = time) %>%
    select(traceID, time_of_bwave_edge)

  bwave_abs_slope_minima <- bwave %>%
    select(!data) %>%
    unnest(smoothed) %>%
    mutate(abs_slope = abs(deriv1)) %>%
    group_by(traceID) %>%
    mutate(avg_min_slope = slider::slide_dbl(abs_slope, .f=~min(.x), .before = 2, .after = 2,, .complete = TRUE)) %>%
    filter(abs_slope == avg_min_slope)


  # a-wave data (less smoothing)
  awave <- data %>%
    group_by(traceID) %>%
    nest() %>%
    mutate(spline_fit = map(data, ~ smooth.spline(x = .$time, y = .$meanSignal, spar=0.15) )) %>%
    mutate(smoothed = map(spline_fit, ~tibble(time = predict(., deriv=1)$x,
                                              smoothed = predict(.)$y,
                                              deriv1 = predict(., deriv=1)$y) ))

  awave_abs_slope_minima <- awave  %>%
    select(!data) %>%
    unnest(smoothed) %>%
    mutate(abs_slope = abs(deriv1)) %>%
    group_by(traceID) %>%
    mutate(avg_min_slope = slider::slide_dbl(abs_slope, .f=~min(.x), .before = 2, .after = 2,, .complete = TRUE)) %>%
    filter(abs_slope == avg_min_slope)


  # Extract the peaks
  awave_data <- awave_abs_slope_minima %>%
    left_join(., slope_max) %>%
    left_join(., leading_bwave_edge) %>%
    mutate(dist_to_peak_slope = abs(time_of_slope_max - time)) %>%
    filter(time > 5) %>%
    filter(time < time_of_slope_max - 2) %>%
    filter(time > time_of_bwave_edge - 10) %>%
    group_by(traceID) %>%
    filter(smoothed == min(smoothed)) %>%
    select(traceID, time) %>%
    dplyr::rename(awave_peak_time = time)


  bwave_data <- bwave_abs_slope_minima %>%
    left_join(., slope_max) %>%
    filter(time > time_of_slope_max + 5) %>%
    mutate(dist_to_peak_slope = abs(time_of_slope_max - time)) %>%
    group_by(traceID) %>%
    filter(smoothed == max(smoothed)) %>%
    select(traceID, time) %>%
    dplyr::rename(bwave_peak_time = time)

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

