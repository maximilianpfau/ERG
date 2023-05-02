# This function averages traces.
library(tidyverse)

avgTraces <- function(data) {

  data <- data %>%
    left_join(.,
              plyr::ddply(., c('DOE', 'recording', 'time'), summarize,
                       meanSignal = mean(signal - .fitted) )) %>%
    mutate(time = as.numeric(time))

  return(data)
}


