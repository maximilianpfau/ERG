
# This function performs linear de-trending using pre-stimulus data.
library(tidyverse)

detrend <- function(data) {

  dataFitted <- data %>%
    select(traceID, time, signal) %>%
    filter() %>%
    group_by(traceID) %>%
    nest() %>%
    mutate(fit = map(data, ~(lm(signal ~ time, data=subset(., .$time <= 0) )) ) )

  newDf = tibble(time=seq(min(data$time),max(data$time),.5))

  dataFitted <- dataFitted %>%
    mutate(augmented = map(fit, ~ broom::augment(., newdata=newDf)) ) %>%
    unnest(augmented)

  data <- data %>%
    left_join(., dataFitted[,c('traceID','time','.fitted')])

  return(data)
}



