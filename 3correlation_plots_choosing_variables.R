# install.packages("corrplot")
library(corrplot)
library(ggplot2)

climate_land_use <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_occurence_thinned.csv")
drop <- c("bio1", "bio5", "bio6", "bio12", "bio13", "bio14", "bio7", "gsl", "mean_forest_combined", "diff_forest_combined", 
          "mean_urban_combined", "diff_urban_combined", "mean_mining_combined", "diff_mining_combined", "mean_wetland_combined", "diff_wetland_combined")
climate_land_use <- climate_land_use[,(names(climate_land_use) %in% drop)]

data <- cor(climate_land_use)

p <- corrplot.mixed(data,
               lower = "number", 
               upper = "circle",
               tl.col = "black")
dev.off()
plot(p)



climate_data <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_occurence_thinned.csv")

drop <- c("latitude", "longitude", "row_identifier", "focal","bio5", "bio13", "bio14", "gsl", "mean_forest_combined", "diff_forest_combined", 
          "mean_urban_combined", "diff_urban_combined", "mean_mining_combined", "diff_mining_combined", "mean_wetland_combined", "diff_wetland_combined")
climate_data <- climate_data[,(names(climate_data) %in% drop)]
write.csv(climate_data, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/initial_training_data.csv")


